extends Node3D
## Vista de candidatos: todos os .fbx/.glb de res://assets/_cand lado a lado, rotulados, normalizados para 1 m. --out=<pasta>
var DIR: String = "res://assets/_cand"


func _ready() -> void:
	DIR = Game.test_args.get("dir", DIR)
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.62, 0.74)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.7
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var sol := DirectionalLight3D.new(); sol.light_energy = 0.9; sol.rotation_degrees = Vector3(-55, -25, 0); add_child(sol)
	var nomes: Array = []
	for f in DirAccess.get_files_at(DIR):
		var f2: String = f.trim_suffix(".import")
		if (f2.ends_with(".fbx") or f2.ends_with(".glb")) and not nomes.has(f2):
			nomes.append(f2)
	nomes.sort()
	var cols := 6
	for i in nomes.size():
		var n: Node3D = load(DIR + "/" + nomes[i]).instantiate()
		add_child(n)
		var ab := AABB()
		var primeiro := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			ab = b if primeiro else ab.merge(b)
			primeiro = false
		var maior := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		var k := 1.0 / maxf(maior, 0.001)
		n.scale = Vector3.ONE * k
		n.position = Vector3((i % cols) * 1.4, -(i / cols) * 1.5, 0) - ab.get_center() * k
		var l := Label3D.new()
		l.text = "%s\n%.2fx%.2fx%.2f" % [nomes[i].get_basename(), ab.size.x, ab.size.y, ab.size.z]
		l.font_size = 40
		l.pixel_size = 0.004
		l.position = Vector3((i % cols) * 1.4, -(i / cols) * 1.5 - 0.7, 0)
		add_child(l)
		print("CAND %s tamanho=%s" % [nomes[i], ab.size])
	var cam := Camera3D.new()
	cam.position = Vector3(cols * 1.4 / 2.0 - 0.7, -0.75 * ((nomes.size() - 1) / cols), 3.2 if Game.test_args.has("perto") else (8.5 if nomes.size() > 12 else 5.2))
	add_child(cam)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.position += Vector3(0, 0.0, 0.0) if Game.test_args.has("alto") else Vector3.ZERO
	cam.make_current()
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("cand.png"))
	get_tree().quit()
