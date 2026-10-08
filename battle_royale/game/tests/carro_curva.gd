extends Node
## Mede se o carro GIRA ao esterçar (yaw da carroceria), não só se as rodas viram. Roda igual na versão antiga
## (só usa API que já existia). Saída: CURVA kmh=<v> giro_graus=<g> em 2 s para esquerda e direita.
const LAYER_WORLD := 1
var _car: DrivableVehicle


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



func _yaw() -> float:
	var f := _car.global_basis.z
	return atan2(f.x, f.z)


func _segurar(teclas: Array, frames: int) -> void:
	for t in teclas:
		Input.action_press(t)
	for i in frames:
		await get_tree().physics_frame
	for t in teclas:
		Input.action_release(t)


func _curva(alvo_kmh: float, tecla: String) -> void:
	# acelera em linha reta até a velocidade alvo, depois mantém acelerador leve + vira 2 s
	var t0 := Engine.get_physics_frames()
	Input.action_press("move_forward")
	while _car.linear_velocity.length() * 3.6 < alvo_kmh and Engine.get_physics_frames() - t0 < 600:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var y0 := _yaw()
	var v0 := _car.linear_velocity.length() * 3.6
	var acc := 0.0
	var ultimo := y0
	Input.action_press(tecla)
	for i in 120:
		if i % 3 == 0:
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		await get_tree().physics_frame
		var y := _yaw()
		acc += wrapf(y - ultimo, -PI, PI)
		ultimo = y
	Input.action_release(tecla)
	Input.action_release("move_forward")
	print("CURVA alvo=%.0f kmh_ini=%.1f kmh_fim=%.1f tecla=%s giro_graus=%.1f esterco=%.2f" % [alvo_kmh, v0, _car.linear_velocity.length() * 3.6, tecla, rad_to_deg(acc), _car.steering])
	await _segurar(["move_back"], 150)


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	var player := m.local_player
	var terrain: IlhaTerrain = m.ilha.get("terrain")
	_car = get_tree().get_nodes_in_group("drivable_vehicle")[0] as DrivableVehicle
	var trecho := _achar_trecho(terrain, m.get_world_3d().direct_space_state, _car.global_position)
	var pos: Vector3 = trecho.pos
	if Game.test_args.has("sem_aderencia") and "aderencia_lateral" in _car:
		_car.set("aderencia_lateral", 0.0)
	_car.freeze = false
	_car.sleeping = false
	_car.global_transform = Transform3D(Basis(Vector3.UP, float(trecho.yaw)), pos + Vector3.UP * 0.9)
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO
	for i in 90:
		await get_tree().physics_frame
	player.global_position = _car.global_position + _car.global_basis.x * 2.0
	await get_tree().physics_frame
	await _segurar(["use"], 48)
	for i in 32:
		await get_tree().physics_frame
	print("CURVA entrou=%s livre=%.0f" % [_car.driver == player, float(trecho.livre)])
	for alvo in [15.0, 35.0]:
		for tecla in ["move_left", "move_right"]:
			await _curva(alvo, tecla)
	print("CURVA_FIM")
	get_tree().quit()
