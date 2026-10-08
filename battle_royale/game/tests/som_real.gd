extends Node
## SOM NO JOGO REAL (ilha completa): zumbi (alerta, rosnado correndo, ataque, ferido, morte) e carro (motor ligando, rotação, desligando).
## Usa Audio.espiao para registrar tudo que o jogo manda tocar e AudioServer para medir o nível real na saída (Master).
## Uso: godot --path game res://tests/som_real.tscn -> SOM_REAL_OK / SOM_REAL_FALHOU (janela real, áudio ligado)
var m: BRMatch
var s: Soldier
var eventos: Dictionary = {}
var falhas: Array = []
var pico_master := -80.0


func espiar(tipo: String, id: String, _p, _o) -> void:
	eventos["%s:%s" % [tipo, id]] = int(eventos.get("%s:%s" % [tipo, id], 0)) + 1


func _ready() -> void:
	get_tree().create_timer(160.0).timeout.connect(func() -> void: print("SOM_REAL_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	Audio.espiao = espiar
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	s = m.local_player
	s.godmode = true
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	await _f(60)
	await _zumbi()
	await _carro()
	print("EVENTOS ", JSON.stringify(eventos))
	print("PICO_MASTER_DB %.1f" % pico_master)
	for id in ["zombie_alert", "zombie_attack", "zombie_hurt", "zombie_die", "zombie_run"]:
		if int(eventos.get("play_at:" + id, 0)) == 0:
			falhas.append("sem " + id)
	print("SOM_REAL_OK" if falhas.is_empty() else "SOM_REAL_FALHOU %s" % str(falhas))
	get_tree().quit(0 if falhas.is_empty() else 1)


func _zumbi() -> void:
	var base := Vector3(-345.0, 0.0, 352.0)
	var y: float = m.ilha.terrain.height_world(base.x, base.z)
	s.global_position = Vector3(base.x, y + 0.1, base.z)
	s.yaw = deg_to_rad(40.0)
	s.reset_physics_interpolation()
	var dir := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	var z: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
	m.ilha.get_node("ZombieDirector").add_child(z)
	var zp: Vector3 = base + dir * 14.0
	zp.y = m.ilha.terrain.height_world(zp.x, zp.z) + 0.05
	z.global_position = zp
	z.add_to_group("zombie_targets")
	await _f(30)
	z.target = s
	z._set_state(ZombieEnemy.State.ALERT)
	for i in 16:
		await get_tree().create_timer(0.5).timeout
		_medir()
		if i == 8:
			z.receive_damage(20, s, &"body")
	z.receive_damage(100, s, &"head")
	for i in 6:
		await get_tree().create_timer(0.4).timeout
		_medir()


func _carro() -> void:
	var melhor: DrivableVehicle = null
	var dmin := 1e9
	for c in get_tree().get_nodes_in_group("drivable_vehicle"):
		var d: float = (c as Node3D).global_position.distance_to(s.global_position)
		if d < dmin:
			dmin = d
			melhor = c
	if melhor == null:
		falhas.append("nenhum carro na ilha")
		return
	s.global_position = melhor.global_position + melhor.global_basis.x * 2.2 + Vector3.UP * 0.5
	await _f(20)
	var ok := melhor.enter_vehicle(s)
	print("CARRO entrou=", ok, " dist_inicial=", snappedf(dmin, 0.1))
	if not ok:
		falhas.append("não entrou no carro")
		return
	var vmax := 0.0
	Input.action_press("move_forward")
	for i in 14:
		await get_tree().create_timer(0.5).timeout
		_medir()
		vmax = maxf(vmax, melhor.linear_velocity.length())
		var mot: Array = melhor._mot
		var linha := []
		for p in mot:
			linha.append("%.2f/%.0fdB%s" % [(p as AudioStreamPlayer3D).pitch_scale, (p as AudioStreamPlayer3D).volume_db, "*" if (p as AudioStreamPlayer3D).playing else ""])
		print("MOTOR t=%.1f v=%.1f m/s rpm=%.2f layers=%s" % [i * 0.5, melhor.linear_velocity.length(), melhor._rpm, " ".join(linha)])
	Input.action_release("move_forward")
	print("CARRO vmax=%.1f m/s" % vmax)
	if vmax < 3.0:
		falhas.append("carro não andou")
	var tocando := 0
	for p in melhor._mot:
		tocando += 1 if (p as AudioStreamPlayer3D).playing else 0
	if tocando == 0:
		falhas.append("motor mudo com o carro andando")
	melhor.exit_vehicle()
	await get_tree().create_timer(1.2).timeout
	for p in melhor._mot:
		if (p as AudioStreamPlayer3D).playing:
			falhas.append("motor não desligou ao sair")
			break


func _medir() -> void:
	var b := AudioServer.get_bus_index("Master")
	pico_master = maxf(pico_master, maxf(AudioServer.get_bus_peak_volume_left_db(b, 0), AudioServer.get_bus_peak_volume_right_db(b, 0)))


func _f(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
