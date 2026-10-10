extends Node
## Direção no jogo real: leva um carro a um trecho plano e livre da ilha, entra, acelera 5 s, reduz a
## 50 km/h, faz curva com D, drift com freio de mão (espaço) + A, e freia até parar (S).
## Imprime números a cada segundo e salva PNGs em --out=<pasta>. Funciona com a versão antiga do carro (sem marcha/vida).

const TECLAS := ["move_forward", "move_back", "move_left", "move_right", "jump"]
const LAYER_WORLD := 1

var _out := ""
var _car: DrivableVehicle
var _player: Soldier
var _seg_roll := 0.0
var _seg_slip := 0.0
var _max_kmh := 0.0
var _max_marcha := 0
var _max_rpm := 0
var _max_roll := 0.0
var _min_up := 1.0
var _max_slip := 0.0
var _vida_min := 100.0
var _trecho_amp := 0.0


func _shot(nome: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(nome + ".png"))


func _marcha() -> int:
	return _car.marcha_atual() if _car.has_method("marcha_atual") else 0


func _rpm() -> int:
	return _car.rpm_hud() if _car.has_method("rpm_hud") else 0


func _vida() -> float:
	return _car.vida if "vida" in _car else 100.0


func _roll_deg() -> float:
	var right := _car.global_basis.x.normalized()
	var up := _car.global_basis.y.normalized()
	return rad_to_deg(atan2(-right.dot(Vector3.UP), up.dot(Vector3.UP)))


func _slip_deg() -> float:
	var v := _car.linear_velocity
	var flat := Vector3(v.x, 0.0, v.z)
	if flat.length() < 1.0:
		return 0.0
	var fwd := _car.global_basis.z
	var fwd_flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	return rad_to_deg(flat.normalized().angle_to(fwd_flat))


func _kmh() -> float:
	return _car.linear_velocity.length() * 3.6


## Melhor trecho: maior distância livre à frente (sem obstáculo e sem água, até 150 m) menos a
## amplitude do relevo (quadrado de 60 m). Direções: 0, 90, 180, 270 graus.
func _achar_trecho(terrain: IlhaTerrain, space: PhysicsDirectSpaceState3D, centro: Vector3) -> Dictionary:
	var melhor := {"pos": centro, "yaw": 0.0, "amp": 99.0, "livre": -1.0}
	var melhor_score := -INF
	for ix in range(-20, 21):
		for iz in range(-20, 21):
			var x := centro.x + ix * 15.0
			var z := centro.z + iz * 15.0
			var h0 := terrain.height_world(x, z)
			if h0 < 2.5:
				continue
			var lo := INF
			var hi := -INF
			for sx in range(-5, 6):
				for sz in range(-5, 6):
					var h := terrain.height_world(x + sx * 6.0, z + sz * 6.0)
					lo = minf(lo, h)
					hi = maxf(hi, h)
			var amp := hi - lo
			if amp >= 1.5:
				continue
			for yaw_deg in [0.0, 90.0, 180.0, 270.0]:
				var yaw := deg_to_rad(yaw_deg)
				var frente := Basis(Vector3.UP, yaw).z
				var a := Vector3(x, h0 + 0.8, z)
				var lado := Basis(Vector3.UP, yaw).x
				var livre := 150.0
				# três raios (esquerda, centro, direita) para cobrir a largura do carro
				# alturas: 0,35 m (postes/cercas baixas) e 0,9 m (troncos e carros)
				for off in [-2.0, 0.0, 2.0]:
					for hh in [-0.45, 0.1]:
						var o: Vector3 = a + lado * float(off) + Vector3.UP * float(hh)
						var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + frente * 150.0, LAYER_WORLD))
						if not hit.is_empty() and float(hit.normal.y) <= 0.5:
							livre = minf(livre, o.distance_to(hit.position))
				for k in range(1, 16):
					var p := a + frente * (k * 10.0)
					if terrain.height_world(p.x, p.z) < 2.0:
						livre = minf(livre, k * 10.0)
						break
				var score := livre - 20.0 * amp
				if score > melhor_score:
					melhor_score = score
					melhor = {"pos": Vector3(x, h0, z), "yaw": yaw, "amp": amp, "livre": livre}
	return melhor


func _soltar() -> void:
	for t in TECLAS:
		Input.action_release(t)


func _medir() -> void:
	_max_kmh = maxf(_max_kmh, _kmh())
	_max_marcha = maxi(_max_marcha, _marcha())
	_max_rpm = maxi(_max_rpm, _rpm())
	var roll := absf(_roll_deg())
	_max_roll = maxf(_max_roll, roll)
	_seg_roll = maxf(_seg_roll, roll)
	_min_up = minf(_min_up, _car.global_basis.y.dot(Vector3.UP))
	var slip := _slip_deg()
	_max_slip = maxf(_max_slip, slip)
	_seg_slip = maxf(_seg_slip, slip)
	_vida_min = minf(_vida_min, _vida())


## parar_quando: "" sem condição, "abaixo:X" ou "acima:X" (km/h).
func _fase(nome: String, frames: int, teclas: Array, parar_quando := "") -> void:
	_soltar()
	for t in teclas:
		Input.action_press(t)
	_seg_roll = 0.0
	_seg_slip = 0.0
	var seg := 0
	var limite := -1.0
	var abaixo := true
	if parar_quando != "":
		var partes := parar_quando.split(":")
		abaixo = partes[0] == "abaixo"
		limite = float(partes[1])
	var t0 := Engine.get_physics_frames()
	var f := 0
	while Engine.get_physics_frames() - t0 < frames:
		await get_tree().physics_frame
		f += 1
		_medir()
		# tempo de física real (as capturas consomem quadros fora do laço)
		var seg_atual := int((Engine.get_physics_frames() - t0) / 60)
		if seg_atual > seg:
			seg = seg_atual
			print("CARRO fase=%s t=%ds km/h=%.1f marcha=%d rpm=%d vida=%.1f rolagem_max=%.1f deriva_max=%.1f up_min=%.2f" % [
				nome, seg, _kmh(), _marcha(), _rpm(), _vida(), _seg_roll, _seg_slip, _car.global_basis.y.dot(Vector3.UP)])
			_seg_roll = 0.0
			_seg_slip = 0.0
			if limite < 0.0:
				await _shot("%02d_%s_%ds" % [seg, nome, seg])
		if limite >= 0.0 and f > 30:
			var k := _kmh()
			if (abaixo and k < limite) or (not abaixo and k > limite):
				print("CARRO fase=%s condicao_atingida em %.2f s (km/h=%.1f)" % [nome, (Engine.get_physics_frames() - t0) / 60.0, k])
				break
	_soltar()


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	_out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	_player = m.local_player
	var terrain: IlhaTerrain = m.ilha.get("terrain")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_car = get_tree().get_nodes_in_group("drivable_vehicle")[0] as DrivableVehicle
	var trecho := _achar_trecho(terrain, m.get_world_3d().direct_space_state, _car.global_position)
	var pos: Vector3 = trecho.pos
	_car.freeze = false
	_car.sleeping = false
	_car.global_transform = Transform3D(Basis(Vector3.UP, float(trecho.yaw)), pos + Vector3.UP * 0.9)
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO
	_car.reset_physics_interpolation()
	for i in 90:
		await get_tree().physics_frame
	_player.global_position = _car.global_position + _car.global_basis.x * 2.0
	_player.reset_physics_interpolation()
	await get_tree().physics_frame
	Input.action_press("use")
	for i in 48:
		await get_tree().physics_frame
	Input.action_release("use")
	for i in 60:
		await get_tree().physics_frame
	var pc := _player.controller as PlayerController
	print("CAMERA no carro=%s primeira_pessoa=%s" % [pc.active_vehicle != null, _car.first_person_camera])
	_car.abastecer(60.0)
	if not _car.first_person_camera:
		_car.toggle_camera()
	for i in 30:
		await get_tree().process_frame
	Input.action_press("move_forward")
	var rel_pos: Array = []
	var rel_rot: Array = []
	var carpos: Array = []
	var cam := pc.camera
	var n := 0
	var t_ini := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_ini < 4500:
		await RenderingServer.frame_pre_draw   # depois de todos os _process: câmera e carro do mesmo quadro
		var xf := _car.get_global_transform_interpolated()
		var rel := xf.affine_inverse() * cam.global_transform
		rel_pos.append(rel.origin)
		rel_rot.append(rel.basis.get_rotation_quaternion())
		carpos.append(xf.origin)
		n += 1
		if n % 40 == 0:
			print("CAMERA n=%d kmh=%.0f vida=%.0f" % [n, _kmh(), _vida()])
	await _shot("fp_fim")
	Input.action_release("move_forward")
	# jitter do próprio carro: aceleração (2ª diferença) da posição interpolada, em m/quadro
	var jit := 0.0
	for k in range(2, carpos.size()):
		jit += ((carpos[k] as Vector3) - 2.0 * (carpos[k - 1] as Vector3) + (carpos[k - 2] as Vector3)).length()
	print("CAMERA jitter_carro_medio=%.4f m/quadro² quadros=%d" % [jit / maxf(1.0, carpos.size() - 2), carpos.size()])
	var dpos := 0.0
	var drot := 0.0
	var maxdpos := 0.0
	var maxdrot := 0.0
	for i in range(1, rel_pos.size()):
		var a: float = (rel_pos[i] - rel_pos[i - 1]).length()
		var b: float = rad_to_deg((rel_rot[i - 1] as Quaternion).angle_to(rel_rot[i] as Quaternion))
		dpos += a
		drot += b
		maxdpos = maxf(maxdpos, a)
		maxdrot = maxf(maxdrot, b)
	print("CAMERA var_pos media=%.4f m max=%.4f m  var_rot media=%.3f° max=%.3f°  kmh=%.0f" % [dpos / (rel_pos.size() - 1), maxdpos, drot / (rel_pos.size() - 1), maxdrot, _kmh()])
	print("CAMERA_FIM")
	get_tree().quit()
