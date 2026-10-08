extends Node
## Captura em 3ª pessoa: mãos vazias, faca, pistola, rifle. Saída: raw/triagem/maos3p_*.png
func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	var s: Soldier = m.local_player
	var pc := s.controller as PlayerController
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	await _f(40)
	m.br_bag.add_item("backpack_medium")
	m.br_bag.equip_backpack(int(m.br_bag.items[0].uid))
	pc._prefer_third_person = true
	pc._set_third_person(true)
	var y: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s.global_position = Vector3(-345.0, y + 0.1, 352.0)
	s.yaw = deg_to_rad(40.0)
	s.pitch = 0.0
	s.reset_physics_interpolation()
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	for caso in ["vazio", "glock", "m4"]:
		for sl in s.inventory.keys():
			s.remove_slot(sl)
		if caso != "vazio":
			var bag: BRInventory = m.br_bag
			for it in bag.items.duplicate():
				if String(BRInventory.definition(String(it.id)).get("kind", "")) == "weapon":
					bag.remove_item(int(it.uid))
			bag.add_item(caso, 1, Vector2i(-1, -1), {"mag": 30})
			for it in bag.items:
				if String(it.id) == caso:
					m._equip_br_weapon(int(it.uid))
		await _f(90)
		# câmera de captura: de frente e ao lado do corpo
		var cam := Camera3D.new()
		s.get_parent().add_child(cam)
		var fwd := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
		var centro := s.global_position + Vector3(0, 1.1, 0)
		for v in [["frente", fwd * 2.6 + Vector3(0, 0.3, 0)], ["lado", Vector3(fwd.z, 0, -fwd.x) * 2.6 + Vector3(0, 0.2, 0)]]:
			cam.global_position = centro + v[1]
			cam.look_at(centro)
			cam.make_current()
			await _f(4)
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out.path_join("maos3p_%s_%s.png" % [caso, v[0]]))
		cam.queue_free()
		pc.camera.make_current()
	print("MAOS3P_FIM")
	get_tree().quit()


func _f(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
