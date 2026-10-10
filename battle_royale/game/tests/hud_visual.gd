extends Node
## Capturas da HUD nova no jogo real: barra de fôlego (correndo) e painel do carro (dirigindo). --out=<pasta>


func _shot(out: String, nome: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))
	print("CAPTURA ", nome)


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	var player := m.local_player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _shot(out, "01_parado")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 150:
		await get_tree().physics_frame
	await _shot(out, "02_correndo_folego")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var car := get_tree().get_nodes_in_group("drivable_vehicle")[0] as DrivableVehicle
	player.global_position = car.global_position + car.global_basis.x * 2.0
	player.reset_physics_interpolation()
	await get_tree().physics_frame
	Input.action_press("use")
	for i in 48:
		await get_tree().physics_frame
	Input.action_release("use")
	for i in 32:
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for i in 150:
		await get_tree().physics_frame
	await _shot(out, "03_carro_dirigindo")
	print("HUD_VISUAL km/h=", car.speed_kmh(), " marcha=", car.marcha_atual(), " rpm=", car.rpm_hud(), " vida=", car.vida_frac())
	Input.action_release("move_forward")
	get_tree().quit()
