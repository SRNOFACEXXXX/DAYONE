extends Node
## Fundo do menu (ui/menu_stage.gd): capturas em 1024x768 e 1280x720 + FPS medido sem vsync.
## Uso: godot --path game res://tests/menu_fundo.tscn -- --v=1
var out := ""


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: print("MENU_FUNDO_TIMEOUT"); get_tree().quit(2))
	Game.test_args["modo"] = "antes"
	var v := String(Game.test_args.get("v", "1"))
	out = ProjectSettings.globalize_path("res://").path_join("../raw/menu")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_tree().current_scene = null
	var tc := Time.get_ticks_usec()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	# 1ª abertura: tempo de cada um dos primeiros 60 quadros (carga dos glb x compilação de shader)
	var prim: Array = []
	var tl0 := Time.get_ticks_usec()
	for q in 60:
		await get_tree().process_frame
		var tn := Time.get_ticks_usec()
		prim.append(snappedf((tn - tl0) / 1000.0, 0.1))
		tl0 = tn
	print("MENU_FUNDO_ABERTURA ms_ate_q60=%.0f quadros=%s" % [(Time.get_ticks_usec() - tc) / 1000.0, str(prim)])
	var res := {}
	for tam in [Vector2i(1024, 768), Vector2i(1280, 720)]:
		get_window().size = tam
		await get_tree().create_timer(2.5).timeout
		var menu := get_tree().current_scene
		await RenderingServer.frame_post_draw
		var nome := "fundo_v%s_%dx%d" % [v, tam.x, tam.y]
		get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))
		var st: MenuStage = menu.stage
		st.viewport.get_texture().get_image().save_png(out.path_join(nome + "_cena.png"))
		# FPS: 10 s parado, sem vsync; média, p99 e pior quadro
		var dts: Array[float] = []
		var t0 := Time.get_ticks_usec()
		var tl := t0
		while Time.get_ticks_usec() - t0 < 10000000:
			await get_tree().process_frame
			var tn := Time.get_ticks_usec()
			dts.append((tn - tl) / 1000.0)
			tl = tn
		dts.remove_at(0)
		var soma := 0.0
		for d in dts:
			soma += d
		var ord := dts.duplicate()
		ord.sort()
		var media := 1000.0 / (soma / dts.size())
		var p99: float = ord[int(ord.size() * 0.99)]
		var mx: float = ord[-1]
		res["%dx%d" % [tam.x, tam.y]] = {"fps": snappedf(media, 0.1), "p99_ms": snappedf(p99, 0.1), "max_ms": snappedf(mx, 0.1)}
		print("MENU_FUNDO_FPS %dx%d media=%.1f p99=%.1fms max=%.1fms capim=%d draw=%d prim=%d" % [tam.x, tam.y, media, p99, mx, st.n_capim,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	if Game.test_args.has("criador"):
		get_tree().current_scene.abrir_criador()
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("fundo_v%s_criador.png" % v))
	print("MENU_FUNDO_OK ", JSON.stringify(res))
	get_tree().quit(0)
