extends Node3D
## Vitrine genérica: --dir=res://assets/models/predios --names=a,b,c --gap=10 --out=<pasta>. Duas fotos: frente e 3/4.

func _ready() -> void:
	var a := Game.test_args
	var out: String = a.get("out", OS.get_user_data_dir())
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
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 80); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.42, 0.18); ground.material_override = gm; add_child(ground)
	var names: PackedStringArray = String(a.get("names", "")).split(",")
	var gap := float(a.get("gap", "10"))
	var x := -gap * (names.size() - 1) * 0.5
	for n in names:
		var sc: Node3D = load("%s/%s.glb" % [a.get("dir", "res://assets/models/predios"), n]).instantiate()
		add_child(sc)
		sc.position = Vector3(x, 0, 0)
		x += gap
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	var w := gap * names.size()
	for view in [["frente", Vector3(0, 3.5, w * 0.75), Vector3(0, 2.5, 0)], ["tres_quartos", Vector3(w * 0.45, w * 0.35, w * 0.55), Vector3(0, 1.5, 0)]]:
		cam.position = view[1]
		cam.look_at(view[2])
		for i in 15:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("lab_%s.png" % view[0]))
	get_tree().quit()
