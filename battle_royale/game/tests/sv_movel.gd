extends Node
## Saque em móvel: segurar E 1 s (barra circular) abre um móvel lootável da primeira casa; confere mochila/mensagem.
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
	var movs := get_tree().get_nodes_in_group("loot").filter(func(n): return n is BRMovel)
	print("MOVEIS lootaveis=", movs.size())
	assert(movs.size() > 50, "devem existir dezenas de móveis lootáveis")
	var mv: BRMovel = movs[0]
	var alvo := mv.global_position
	s.global_position = alvo + Vector3(0, -0.3, 1.2)
	s.reset_physics_interpolation()
	s.yaw = 0.0
	s.pitch = 0.0
	for k in 8:
		await get_tree().process_frame
	var d := (alvo - s.eye_position())
	s.yaw = atan2(-d.x, -d.z)
	s.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await get_tree().create_timer(0.4).timeout
	print("alvo=", m._nearby_loot(), " esperado=", mv, " tipo=", mv.tipo)
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_E; ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.55).timeout
	await _foto("circular")
	print("progresso meio=%.2f" % (m.hold_circle.progresso if m.hold_circle else -1.0))
	assert(m.hold_circle and m.hold_circle.progresso > 0.3, "barra circular deve estar enchendo")
	await get_tree().create_timer(0.8).timeout
	var ev2 := InputEventKey.new(); ev2.physical_keycode = KEY_E; ev2.pressed = false
	Input.parse_input_event(ev2)
	print("aberto=", mv.aberto, " itens_mochila=", m.br_bag.items.size())
	assert(mv.aberto, "móvel deve abrir após 1 s segurando E")
	await _foto("aberto")
	print("SVMOVEL OK")
	get_tree().quit()
func _foto(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("mv_%s.png" % n))
