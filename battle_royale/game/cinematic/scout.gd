extends Node
## Reconhecimento de câmeras: lê raw/trailer/scout.json (lista de {n, pos:[x,h,z], look:[x,h,z], fov, hora, clima}) onde h = metros acima do chão
## naquele ponto, e salva raw/trailer/scout/<n>.png. Uso: godot --path game res://cinematic/scout.tscn
func _ready() -> void:
	get_tree().create_timer(280.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	m.hud.root.visible = false
	m.local_player.visible = false
	Clima.congelado = true
	var raiz := ProjectSettings.globalize_path("res://").path_join("../raw/trailer")
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string(raiz.path_join("scout.json")))
	DirAccess.make_dir_recursive_absolute(raiz.path_join("scout"))
	var cam := Camera3D.new()
	cam.top_level = true
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	for i in 60:
		await get_tree().process_frame
	var hora_ant := -1.0
	for v in lista:
		var h := float(v.get("hora", 17.5))
		if h != hora_ant:
			Clima.set_hora(h)
			hora_ant = h
		Clima.forcar_clima(int(v.get("clima", 1)), true)
		var p: Array = v.pos
		var l: Array = v.look
		var pp := Vector3(float(p[0]), 0.0, float(p[2]))
		pp.y = m.ilha.terrain.height_world(pp.x, pp.z) + float(p[1])
		var ll := Vector3(float(l[0]), 0.0, float(l[2]))
		ll.y = m.ilha.terrain.height_world(ll.x, ll.z) + float(l[1])
		cam.global_position = pp
		cam.look_at(ll, Vector3.UP)
		cam.fov = float(v.get("fov", 60.0))
		for k in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(raiz.path_join("scout").path_join(str(v.n) + ".png"))
	print("SCOUT_FIM")
	get_tree().quit()
