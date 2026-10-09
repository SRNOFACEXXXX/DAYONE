extends Node3D
func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-50, -35, 0); add_child(sol)
	if Game.test_args.has("plano"):
		var ch := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); ch.mesh = pm
		add_child(ch)
	var x := -6.0
	for p in ["res://assets/models/atualizacao/mundo/Deer_001.glb", "res://assets/models/animais/cervo.glb", "res://assets/models/animais/cachorro.glb", "res://assets/models/animais/galinha.glb"]:
		var n: Node3D = load(p).instantiate()
		if Game.test_args.has("animal") and not p.contains("atualizacao"):
			var a = load("res://core/animal.gd").new()
			a.configurar(p.get_file().get_basename(), null)
			a.set_physics_process(false)
			n.free()
			n = a
		add_child(n)
		n.position = Vector3(x, 0, 0)
		x += 3.0
		var mi := n.find_children("*", "MeshInstance3D", true, false)
		print("GLB %s malhas=%d" % [p.get_file(), mi.size()])
		for m in mi:
			var mm := m as MeshInstance3D
			print("   %s skin=%s mat=%s sup=%d" % [mm.name, mm.skin != null, mm.mesh.surface_get_material(0), mm.mesh.get_surface_count()])
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	cam.global_position = Vector3(0, 1.6, 9); cam.look_at(Vector3(0, 0.8, 0))
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("glb.png"))
	get_tree().quit()
