extends Node
## Teste do retarget Mixamo -> personagem: toca cada animação no herói e salva 3 quadros de cada em raw/trailer/mx/<nome>_<k>.png
func _ready() -> void:
	get_tree().create_timer(250.0).timeout.connect(func() -> void: get_tree().quit(2))
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
	var s: Soldier = m.local_player
	var pc := s.controller as PlayerController
	pc.set_process(false)
	pc.set_physics_process(false)
	pc._set_third_person(true)
	pc.camera.current = false
	s.godmode = true
	for sl in s.inventory.keys():
		s.remove_slot(sl)
	Clima.congelado = true
	Clima.set_hora(15.0)
	Clima.forcar_clima(0, true)
	var p := Vector3(-340.0, 0.0, 330.0)
	p.y = m.ilha.terrain.height_world(p.x, p.z) + 0.1
	s.global_position = p
	s.yaw = PI
	s.reset_physics_interpolation()
	var cam := Camera3D.new()
	cam.top_level = true
	cam.fov = 45.0
	add_child(cam)
	cam.make_current()
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/trailer/mx")
	DirAccess.make_dir_recursive_absolute(out)
	for i in 90:
		await get_tree().process_frame
	var bm: BodyModel = s.body_model
	for nome in ["Shooting_Arrow", "Prone_Left_Turn", "Rifle_Run", "Rifle_Aiming_Idle", "Walk_Forward", "Shooting"]:
		MxRetarget.tocar(bm, nome)
		for f in 4:
			await get_tree().process_frame
		var dur := MxRetarget.duracao(bm)
		print("MX ", nome, " dur=", snappedf(dur, 0.01))
		for k in 3:
			MxRetarget.seek(bm, minf(dur * (0.1 + 0.4 * k), dur - 0.05))
			for f in 3:
				await get_tree().process_frame
			var c := s.global_position + Vector3(0, 1.0, 0)
			cam.global_position = c + Vector3(3.0, 0.5, -3.2) if nome != "Prone_Left_Turn" else c + Vector3(2.4, 1.6, -2.6)
			cam.look_at(c + Vector3(0, -0.1 if nome == "Prone_Left_Turn" else 0.2, 0))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d.png" % [nome, k]))
		MxRetarget.parar(bm)
	print("MX_FIM")
	get_tree().quit()
