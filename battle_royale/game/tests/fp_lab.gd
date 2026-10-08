extends Node3D
## Vitrine dos braços FP (fora da câmera de 1ª pessoa): --weapon=ak47 --out=<pasta>. Fotos de 3 ângulos com os materiais nativos.

func _ready() -> void:
	Game.test_mode = true
	var out: String = Game.test_args.get("out", "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/fp_lab")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, -30, 0); add_child(sun)
	var w: String = Game.test_args.get("weapon", "ak47")
	var sc: Node3D = load("res://assets/models/weapons/%s_fp.tscn" % w).instantiate()
	add_child(sc)
	var vm := ViewModel.new()
	var maos := "res://assets/models/weapons/maos_%s.glb" % w
	if ResourceLoader.exists(maos):
		var sk := sc.find_child("Skeleton3D", true, false)
		for c in sk.get_children():
			if c is MeshInstance3D:
				c.visible = false
		sc.find_child("Arma", true, false).add_child(load(maos).instantiate())
	elif Game.test_args.get("swap", "1") == "1":
		vm._swap_arms(sc)
	var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("idle"):
		ap.play("idle")
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 40
	for v in [["tras", Vector3(0.0, 0.35, 0.9)], ["cima", Vector3(0.3, 1.0, 0.1)], ["lado", Vector3(1.0, 0.2, -0.6)]]:
		cam.position = v[1]
		cam.look_at(Vector3(0.05, 0, -0.45), Vector3.UP if v[0] != "cima" else Vector3.FORWARD)
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [w, v[0]]))
	get_tree().quit()
