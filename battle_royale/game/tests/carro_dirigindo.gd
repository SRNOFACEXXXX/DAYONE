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


## Trecho plano (amplitude do quadrado de 60 m) e sem obstáculo à frente (raio de 60 m) para cada direção.
func _achar_trecho(terrain: IlhaTerrain, space: PhysicsDirectSpaceState3D, centro: Vector3) -> Dictionary:
	var melhor := {"pos": centro, "yaw": 0.0, "amp": INF}
	for ix in range(-10, 11):
		for iz in range(-10, 11):
			var x := centro.x + ix * 15.0
			var z := centro.z + iz * 15.0
			var h0 := terrain.height_world(x, z)
			if h0 < 1.5:
				continue
			var lo := INF
			var hi := -INF
			for sx in range(-5, 6):
				for sz in range(-5, 6):
					var h := terrain.height_world(x + sx * 6.0, z + sz * 6.0)
					lo = minf(lo, h)
					hi = maxf(hi, h)
			var amp := hi - lo
			if amp >= 0.6 or amp >= float(melhor.amp):
				continue
			for yaw_deg in [0.0, 90.0, 180.0, 270.0]:
				var yaw := deg_to_rad(yaw_deg)
				var frente := Basis(Vector3.UP, yaw).z
				var a := Vector3(x, h0 + 0.8, z)
				var q := PhysicsRayQueryParameters3D.create(a, a + frente * 60.0, LAYER_WORLD)
				var hit := space.intersect_ray(q)
				if hit.is_empty() or float(hit.normal.y) > 0.5:
					melhor = {"pos": Vector3(x, h0, z), "yaw": yaw, "amp": amp}
					break
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
	for f in frames:
		await get_tree().physics_frame
		_medir()
		if f % 60 == 59:
			seg += 1
			print("CARRO fase=%s t=%ds km/h=%.1f marcha=%d rpm=%d vida=%.1f rolagem_max=%.1f deriva_max=%.1f up_min=%.2f" % [
				nome, seg, _kmh(), _marcha(), _rpm(), _vida(), _seg_roll, _seg_slip, _car.global_basis.y.dot(Vector3.UP)])
			_seg_roll = 0.0
			_seg_slip = 0.0
			await _shot("%02d_%s_%ds" % [seg, nome, seg])
		if limite >= 0.0 and f > 30:
			var k := _kmh()
			if (abaixo and k < limite) or (not abaixo and k > limite):
				print("CARRO fase=%s condicao_atingida em %d quadros (km/h=%.1f)" % [nome, f, k])
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
	_trecho_amp = float(trecho.amp)
	var pos: Vector3 = trecho.pos
	print("CARRO trecho pos=(%.1f, %.1f, %.1f) yaw=%.0f amplitude=%.2f m" % [pos.x, pos.y, pos.z, rad_to_deg(float(trecho.yaw)), _trecho_amp])
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
	for i in 32:
		await get_tree().physics_frame
	print("CARRO entrou=%s" % (_car.driver == _player))
	var hud := get_tree().root.find_child("VeiculoHud", true, false) as Control
	print("CARRO contatos_roda=%d" % _car.get_children().filter(func(n): return n is VehicleWheel3D and n.is_in_contact()).size())
	if hud:
		print("CARRO hud_pos=(%.0f, %.0f) tamanho=(%.0f, %.0f) viewport=%s" % [hud.global_position.x, hud.global_position.y, hud.size.x, hud.size.y, str(get_viewport().get_visible_rect().size)])
	await _fase("acelera", 300, ["move_forward"])
	await _fase("reduz_50", 240, ["move_back"], "abaixo:50")
	await _fase("curva_D", 120, ["move_right"])
	await _fase("drift_freio_mao", 120, ["jump", "move_left"])
	await _fase("freia", 480, ["move_back"], "abaixo:3")
	print("CARRO_RESULT vmax_kmh=%.1f marcha_max=%d rpm_max=%d rolagem_max=%.1f up_min=%.3f deriva_max=%.1f vida_min=%.1f vida_final=%.1f trecho_amp=%.2f" % [
		_max_kmh, _max_marcha, _max_rpm, _max_roll, _min_up, _max_slip, _vida_min, _vida(), _trecho_amp])
	get_tree().quit()
