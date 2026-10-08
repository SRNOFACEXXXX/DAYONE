extends Node
## Painel F10: godmode (dano ignorado), voar e spawn a 10 passos no piso.
func _ready() -> void:
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	for i in 20:
		await get_tree().process_frame
	var f10 := InputEventKey.new(); f10.physical_keycode = KEY_F10; f10.pressed = true
	m._unhandled_input(f10)
	await get_tree().process_frame
	assert(m.admin.visible and not m.hud.root.visible)
	s.godmode = true
	s.take_damage(50.0, null, null, "chest", Vector3.DOWN)
	assert(s.health == 100, "godmode")
	s.godmode = false
	m.admin._spawnar("m107")
	for i in 5:
		await get_tree().process_frame
	var novo: BRDrop
	for n in get_tree().get_nodes_in_group("loot"):
		if n is BRDrop:
			novo = n
	assert(novo != null)
	var d := Vector2(novo.global_position.x - s.global_position.x, novo.global_position.z - s.global_position.z).length()
	var h: float = m.ilha.terrain.height_world(novo.global_position.x, novo.global_position.z)
	print("ADMIN spawn dist=%.2f y=%.2f chao=%.2f nome=%s" % [d, novo.global_position.y, h, novo.nome])
	assert(absf(d - 7.5) < 0.6 and novo.global_position.y > h - 0.1 and novo.global_position.y < h + 3.0)
	s.fly_admin = true
	s.in_move = Vector2(0, 1)
	var y0 := s.global_position.y
	s.in_jump = true
	for i in 60:
		await get_tree().physics_frame
	print("ADMIN voo dy=%.2f" % (s.global_position.y - y0))
	assert(s.global_position.y > y0 + 1.0, "voando sobe")
	m.admin.close()
	print("ADMIN OK")
	get_tree().quit()
