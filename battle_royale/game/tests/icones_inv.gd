extends Node
## Abre o inventário (TAB) com todas as armas/itens na mochila e salva captura.
func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	Game.test_mode = true
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	await _f(20)
	m.br_bag.base_rows = 12
	m.br_bag.base_kg = 500.0
	m.br_bag.backpack_id = "backpack_large"
	for id in ["m249", "m107", "uzi", "mosin", "ak47", "m4", "glock", "usp", "reddot", "acog", "vest", "grenade", "ammo_762", "ammo_9mm", "ammo_556", "ammo_127"]:
		var r := m.br_bag.add_item(id, 20 if id.begins_with("ammo") else 1, Vector2i(-1, -1), {"mag": 10})
		print("add ", id, " -> ", r)
	await _f(10)
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_TAB; ev.pressed = true
	m._unhandled_input(ev)
	await _f(30)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("inventario.png"))
	print("INVCAP ok visible=", m.br_ui.visible)
	get_tree().quit()
