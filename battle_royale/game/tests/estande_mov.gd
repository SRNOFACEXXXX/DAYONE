extends Node
## Gate de movimentação no percurso do estande (docs/criteria/ESTANDE_CRITERIOS.md V1–V4). Anda com o input real
## (move_forward/jump/sprint) e confere se o jogador chegou ao outro lado. Captura o meio de cada travessia.
## Uso: --path game res://tests/estande_mov.tscn -- --out=raw/mov_01

var out := ""
var m: EstandeMatch
var s: Soldier
var falhas: Array[String] = []


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func() -> void:
		push_error("MOV_TIMEOUT")
		get_tree().quit(2))
	Game.test_mode = true
	out = Game.test_args.get("out", "user://mov")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/estande_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	s = m.local_player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(20)
	# [nome, início, alvo(z < alvo_z), y mínimo no fim, segundos, pular?]
	var x0 := -12.0
	var ex := -19.0
	await _travessia("V1_porta", Vector3(x0, 0.05, -4.2), -7.2, -1.0, 2.0, false)
	await _travessia("V2_mureta_1m", Vector3(x0, 0.05, -10.4), -12.8, -1.0, 2.5, true)
	await _travessia("V2_muro_1m5", Vector3(x0, 0.05, -16.4), -18.8, -1.0, 3.0, true)
	await _travessia("V2_cerca_1m1", Vector3(x0, 0.05, -22.4), -24.8, -1.0, 3.0, true)
	await _travessia("V2_caixote_0m8", Vector3(x0, 0.05, -27.2), -29.0, 0.7, 2.5, true)
	await _travessia("V3_escada", Vector3(ex, 0.05, -4.6), -10.0, 1.7, 3.5, false)
	await _travessia("V3_rampa_25", Vector3(ex, 0.05, -12.8), -18.8, 1.7, 3.5, false)
	print("MOV_RESULTADO falhas=%d" % falhas.size())
	for f in falhas:
		print("  FALHA ", f)
	get_tree().quit(0 if falhas.is_empty() else 1)


func _travessia(nome: String, de: Vector3, alvo_z: float, y_min: float, segundos: float, pular: bool) -> void:
	if "_mantle_on" in s:
		s.set("_mantle_on", false)   # não teleporta no meio de uma escalada da travessia anterior
	await _frames(5)
	s.global_position = de
	s.velocity = Vector3.ZERO
	s.yaw = 0.0
	s.pitch = deg_to_rad(-8.0)
	s.reset_physics_interpolation()
	await _frames(10)
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_msec()
	var foto := false
	var chegou := false
	while Time.get_ticks_msec() - t0 < segundos * 1000.0:
		if pular:
			if Input.is_action_pressed("jump"):
				Input.action_release("jump")
			else:
				Input.action_press("jump")
		await get_tree().physics_frame
		if not foto and Time.get_ticks_msec() - t0 > segundos * 350.0:
			foto = true
			await _foto(nome)
		if s.global_position.z < alvo_z and s.global_position.y >= y_min:
			chegou = true
			break
	Input.action_release("move_forward")
	Input.action_release("jump")
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	print("MOV %s chegou=%s em %.2f s pos=%s" % [nome, chegou, dt, s.global_position])
	if not chegou:
		falhas.append("%s: parou em %s" % [nome, s.global_position])
	await _frames(10)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % nome))
