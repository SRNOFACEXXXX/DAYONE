extends Node3D
## Vitrine dos itens de assets/models/itens (gerados por tools/blender/gerar_itens.py): grade no chão com luz do dia,
## uma foto geral e uma por grupo. Confere escala (régua de 1 m e um boneco de 1,8 m) e aparência. --out=<pasta>
const DIR := "res://assets/models/itens/"


func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment = e
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	sol.shadow_enabled = true
	add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.42, 0.55, 0.3)
	chao.material_override = cm
	add_child(chao)
	var arqs: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".glb"):
			arqs.append(f)
	arqs.sort()
	var col := 7
	for i in arqs.size():
		var n: Node3D = load(DIR + arqs[i]).instantiate()
		n.position = Vector3((i % col) * 1.1 - 3.3, 0, int(i / col) * 1.1 - 1.6)
		add_child(n)
		var l := Label3D.new()
		l.text = arqs[i].get_basename()
		l.font_size = 28
		l.pixel_size = 0.004
		l.position = n.position + Vector3(0, 0.02, 0.38)
		l.rotation_degrees = Vector3(-90, 0, 0)
		add_child(l)
	# régua de 1 m e boneco de 1,8 m para escala
	var regua := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 0.02, 0.02)
	regua.mesh = bm
	regua.position = Vector3(-3.3, 0.01, -2.4)
	add_child(regua)
	var boneco := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.height = 1.8
	cap.radius = 0.25
	boneco.mesh = cap
	boneco.position = Vector3(4.6, 0.9, 0)
	add_child(boneco)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 50
	for v in [["geral", Vector3(0.3, 5.2, 4.6), Vector3(0.3, 0, 0.2)], ["perto_a", Vector3(-1.6, 1.5, 0.9), Vector3(-1.6, 0.1, -1.0)],
			["perto_b", Vector3(1.8, 1.5, 0.9), Vector3(1.8, 0.1, -1.0)], ["perto_c", Vector3(-1.0, 1.5, 3.1), Vector3(-1.0, 0.1, 1.2)],
			["perto_d", Vector3(2.0, 1.5, 3.1), Vector3(2.0, 0.1, 1.2)]]:
		cam.global_position = v[1]
		cam.look_at(v[2])
		for k in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
	print("VITRINE_OK itens=%d" % arqs.size())
	get_tree().quit()
