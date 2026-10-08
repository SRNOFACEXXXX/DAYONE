extends Node
## Capturas do menu DAYONE e do criador de personagem em raw/menu/.
## Uso: godot --path game res://tests/menu_captura.tscn [-- --pecas=1]
var out := ""


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: print("MENU_CAPTURA_TIMEOUT"); get_tree().quit(2))
	Game.test_args["modo"] = "captura"
	out = ProjectSettings.globalize_path("res://").path_join("../raw/menu")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	await get_tree().create_timer(2.5).timeout
	var menu := get_tree().current_scene
	await _shot("menu_dayone.png")
	menu.abrir_criador()
	await get_tree().create_timer(1.0).timeout
	await _shot("criador.png")
	var c: CriadorPersonagem = menu.criador
	c.girar(160.0)
	await get_tree().create_timer(0.5).timeout
	await _shot("criador_costas.png")
	c.girar(-160.0)
	seed(7)
	c.aleatorio()
	await get_tree().create_timer(0.5).timeout
	await _shot("criador_aleatorio.png")
	if Game.test_args.has("pecas"):
		for s in CriadorPersonagem.SLOTS:
			for i in (s[2] as Array).size():
				c.escolha[s[0]] = i
				c._aplicar()
				await get_tree().create_timer(0.25).timeout
				await _shot("pecas/%s_%d.png" % [s[0], i])
			c.escolha[s[0]] = 0
		for i in CriadorPersonagem.TONS.size():
			c.escolha["pele"] = i
			c._aplicar()
			await get_tree().create_timer(0.25).timeout
			await _shot("pecas/pele_%d.png" % i)
	print("AQUEC ", Loading.aquecimento_progresso(), " feito=", Loading.aquecido, " ms=", Loading.aquecimento_ms)
	print("MENU_CAPTURA_OK ", out)
	get_tree().quit(0)


func _shot(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out.path_join(nome)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	img.save_png(p)
