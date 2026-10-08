extends Node
## FPS do jogador em pé (partida real, 0 bots, sem vsync, 1024x768) em pontos fixos do Quartel e da Pista.
## Uso: --path game res://tests/mundo_fps.tscn -- --out=<pasta>   (captura cada vista + linha FPS_MUNDO)

const PONTOS := [
	# [nome, x, y (design), olhar_x, olhar_y]
	["quartel_portao", 232.0, 292.0, 330.0, 305.0],
	["quartel_patio", 318.0, 285.0, 392.0, 335.0],
	["quartel_garagem", 360.0, 270.0, 260.0, 250.0],
	["pista_hangar", 315.0, -258.0, 360.0, -300.0],
	["pista_centro", 340.0, -300.0, 300.0, -237.0],
	["pista_cabeceira", 250.0, -320.0, 330.0, -285.0],
	["vila_caicara", -395.0, -290.0, -340.0, -340.0],
	["usina", -230.0, 270.0, -300.0, 320.0],
	["fazenda", -60.0, -320.0, -120.0, -290.0],
	["morro", -320.0, 30.0, -320.0, 75.0],
]


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var out: String = Game.test_args.get("out", "")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var s: Soldier = m.local_player
	var t: IlhaTerrain = m.ilha.terrain
	for i in 60:
		await get_tree().process_frame
	for p in PONTOS:
		var x: float = p[1]
		var z: float = -float(p[2])
		s.global_position = Vector3(x, t.height_world(x, z) + 0.3, z)
		var d := Vector2(float(p[3]) - x, -float(p[4]) - z)
		s.yaw = atan2(-d.x, -d.y)
		s.pitch = 0.0
		s.velocity = Vector3.ZERO
		s.reset_physics_interpolation()
		for i in 45:
			await get_tree().process_frame
		await _medir(String(p[0]))
		if out != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("fps_%s.png" % p[0]))
		if Game.test_args.has("ab"):
			# A/B na mesma execução: esconde as peças de maps/ilha/cenario_atualizacao.json (meta "atualizacao")
			var novas := m.ilha.find_children("*", "Node3D", true, false).filter(func(n): return n.has_meta("atualizacao"))
			for n in novas:
				n.visible = false
			for i in 20:
				await get_tree().process_frame
			await _medir(String(p[0]) + "_sem_pecas_novas")
			for n in novas:
				n.visible = true
	get_tree().quit()


func _medir(nome: String) -> void:
	var t0 := Time.get_ticks_usec()
	var n := 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		n += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("FPS_MUNDO %s %.1f ms %.0f fps draws=%d prims=%d" % [nome, ms, 1000.0 / ms,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
