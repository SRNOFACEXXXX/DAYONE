extends Node3D
## Vitrine da vegetação: todos os modelos de assets/models/veg lado a lado, com a luz da ilha. --out=<pasta>

func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.5)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-34, -35, 0); sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.86, 0.68); sun.shadow_enabled = true; add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 40); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.42, 0.18); ground.material_override = gm; add_child(ground)
	var x := -24.0
	for n in ["coqueiro", "arvore_mata_a", "arvore_mata_b", "bananeira", "arbusto", "capim_alto", "pedra_pequena"]:
		var sc: Node3D = load("res://assets/models/veg/%s.glb" % n).instantiate()
		add_child(sc)
		sc.position = Vector3(x, 0, 0)
		x += 8.5 if n.begins_with("arvore") or n == "coqueiro" else 5.0
	var cam := Camera3D.new(); add_child(cam)
	cam.position = Vector3(-2, 7, 26); cam.look_at(Vector3(-2, 6, 0)); cam.current = true
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("veg_lineup.png"))
	get_tree().quit()
