extends "res://tests/props_andar.gd"
## Terceira pessoa de verdade: o soldado anda (input real) contra fardo, cerca, pedra e árvore e a captura sai da câmera do jogo.
## Imprime o recuo do modelo em relação à cápsula (modelo "à frente" do corpo = parece atravessar). --out=<pasta>
var out_dir := ""


func _shot2(nome: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(nome + ".png"))


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["audit_props"] = true
	Game.test_args["denso"] = true
	out_dir = Game.test_args.get("out", OS.get_user_data_dir())
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for i in 30:
		await get_tree().physics_frame
	det = m.ilha.get_node("Detalhes")
	var s: Soldier = m.local_player
	s.godmode = true
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	var pc := s.controller as PlayerController
	pc._prefer_third_person = true
	pc._set_third_person(true)
	var tipos: Array = String(Game.test_args["tipos"]).split(",") if Game.test_args.has("tipos") else ["cobertura/fardo_feno_x3", "cenario/natureza/cerca_madeira", "cenario/pedras/pedra_04", "cenario/natureza/carvalho"]
	for t in tipos:
		var alvos := _escolher(t, 1)
		if alvos.is_empty():
			print("TERCEIRA %s sem alvo" % t)
			continue
		var al: Dictionary = alvos[0]
		var d: Vector3 = al.d
		s.global_position = al.ini
		s.velocity = Vector3.ZERO
		s.yaw = atan2(-d.x, -d.z)
		s.pitch = deg_to_rad(-15.0)
		s.reset_physics_interpolation()
		await get_tree().create_timer(0.5).timeout
		Input.action_press("move_forward")
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			await get_tree().physics_frame
		Input.action_release("move_forward")
		for i in 20:
			await get_tree().physics_frame
		var bm: Node3D = s.body_model
		var off := Vector3.ZERO
		if bm != null:
			off = bm.global_position - s.global_position
			off.y = 0.0
		var frente := off.dot(d)
		print("TERCEIRA %s prog=%.2f modelo_a_frente_da_capsula=%.2f m  (|off|=%.2f)" % [t, (s.global_position - al.ini).dot(d), frente, off.length()])
		await _shot2(t.get_file())
		# agora PULANDO contra a peça (mantle): termina em cima dela ou do outro lado, nunca equilibrado em trilho fino
		for k in 4:
			s.global_position = al.ini
			s.velocity = Vector3.ZERO
			s.reset_physics_interpolation()
			await get_tree().create_timer(0.4).timeout
			Input.action_press("move_forward")
			var t1 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t1 < 2500:
				Input.action_press("jump")
				await get_tree().physics_frame
				Input.action_release("jump")
				await get_tree().physics_frame
			Input.action_release("move_forward")
			for i in 40:
				await get_tree().physics_frame
			var dy: float = s.global_position.y - al.ini.y
			var pr: float = (s.global_position - al.ini).dot(d)
			print("PULO %s try=%d dy=%.2f prog=%.2f no_chao=%s %s" % [t, k, dy, pr, s.is_on_floor(), "EM_CIMA?" if dy > 0.35 else "ok"])
	print("TERCEIRA_FIM")
	get_tree().quit()
