extends Node
## Reconhecimento para a cinemática: lista as portas de casas da Vila e tira uma aérea e vistas rasteiras de cada candidata.
## Uso: godot --path game res://tests/cine_scout.tscn  -> raw/cine/scout_*.png + lista no console
var m: BRMatch


func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	m.hud.root.visible = false
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/cine")
	DirAccess.make_dir_recursive_absolute(out)
	Clima.set_hora(17.6)
	Clima.congelado = true
	await _f(60)
	var centro := Vector3(-370.0, 0.0, 350.0)
	var portas: Array = []
	for p in get_tree().get_nodes_in_group("porta"):
		var n := p as Node3D
		if Vector2(n.global_position.x - centro.x, n.global_position.z - centro.z).length() < 110.0:
			portas.append(n)
	print("PORTAS na vila: ", portas.size())
	var i := 0
	for n in portas:
		var fwd: Vector3 = n.global_basis.z
		print("  porta %d pos=(%.1f, %.1f, %.1f) frente(+Z)=(%.2f, %.2f)" % [i, n.global_position.x, n.global_position.y, n.global_position.z, fwd.x, fwd.z])
		i += 1
	var cam := Camera3D.new()
	cam.top_level = true
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 150.0
	cam.global_position = Vector3(-365.0, 200.0, 350.0)
	cam.look_at(Vector3(-365.0, 0.0, 350.0), Vector3(0, 0, -1))
	await _f(15)
	await _foto(out, "mapa_topo")
	get_tree().quit()


func _foto(out: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))


func _f(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
