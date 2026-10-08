extends Node
## Interiores do pack "props interiores": capturas de 4 cômodos da casa do pacote (CasaPacote_n), FPS por vista (vsync off,
## 3 s cada), contagem de móveis lootáveis (BRMovel) no mapa inteiro e por casa. Uso: -- --out=<pasta> [--n=0]
var out := ""
func _ready() -> void:
	Game.test_mode = true
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	var corpo := m.ilha.find_child("CasaPacote_%s" % Game.test_args.get("n", "0"), true, false) as Node3D
	assert(corpo != null, "casa do pacote não encontrada")
	var movs := get_tree().get_nodes_in_group("loot").filter(func(n): return n is BRMovel)
	var na_casa := movs.filter(func(n): return n.get_parent() == corpo)
	var tipos := {}
	for mv in movs:
		tipos[mv.tipo] = int(tipos.get(mv.tipo, 0)) + 1
	print("LOOTAVEIS total=%d casa=%d tipos=%s" % [movs.size(), na_casa.size(), JSON.stringify(tipos)])
	var pc := s.controller as PlayerController
	pc._prefer_third_person = false
	pc._set_third_person(false)
	for nm in ["PortaFrente", "PortaCozinha", "PortaLeste"]:
		var p := corpo.get_node_or_null(nm) as PortaCasa
		if p:
			p.alternar()
	await get_tree().create_timer(0.8).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var soma := 0.0
	var vistas := [["cozinha", Vector2(-2.0, 0.6), 90.0], ["sala", Vector2(-0.4, -0.7), -75.0],
			["quarto_ne", Vector2(0.4, -2.6), 0.0], ["quarto_se", Vector2(2.2, 0.8), 180.0]]
	for v in vistas:
		var loc: Vector2 = v[1]
		var gp := corpo.to_global(Vector3(loc.x, 0.1, loc.y))
		var h: float = m.ilha.terrain.height_world(gp.x, gp.z)
		s.global_position = Vector3(gp.x, maxf(gp.y, h) + 0.1, gp.z)
		s.velocity = Vector3.ZERO
		s.yaw = corpo.rotation.y + deg_to_rad(float(v[2]))
		s.pitch = deg_to_rad(-12.0)
		s.reset_physics_interpolation()
		await get_tree().create_timer(1.0).timeout
		var t0 := Time.get_ticks_usec()
		var n := 0
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			n += 1
		var fps := n / ((Time.get_ticks_usec() - t0) / 1000000.0)
		soma += fps
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
		print("VISTA %s %.1f fps draws=%d" % [v[0], fps, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("FPS_MEDIO %.1f" % (soma / vistas.size()))
	get_tree().quit()
