extends Node3D
## Isolated regression check for the visual gait response; no BR island construction.

var out_dir := ""

func _ready() -> void:
	Game.test_args["construcao_livre"] = "1"   # teste da mecânica de encaixe, não do custo em toras
	Game.test_mode = true
	out_dir = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9bb4c8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8b99d")
	env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor.add_child(floor_shape)
	add_child(floor)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	ground.position.y = -0.02
	ground.layers = 2
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("8b7958")
	ground.material_override = ground_mat
	add_child(ground)
	var s := Soldier.new()
	s.team = 0
	add_child(s)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.85, 3.6)
	s.add_child(camera)
	camera.look_at(s.global_position + Vector3(0.0, 0.95, 0.0))
	camera.cull_mask = 2  # BodyModel intentionally renders on the third-person-only layer.
	camera.current = true
	var body := BodyModel.new()
	s.add_child(body)
	s.body_model = body
	body.setup(s)
	await _physics_frames(3)
	assert(s.is_on_floor(), "soldado de teste precisa iniciar no chão")
	s.in_move = Vector2(0.0, 1.0)
	await _physics_frames(6)
	var start_speed := body._anim_velocity.length()
	await _photo("arranque")
	await _physics_frames(50)
	var run_speed := body._anim_velocity.length()
	var upper_leg := body.skeleton.find_bone("LeftUpLeg")
	var foot_bone := body.skeleton.find_bone("LeftFoot")
	var blend: Vector2 = body.tree.get("parameters/stand_src/blend_position")
	var thigh_pose := body.skeleton.get_bone_pose_rotation(upper_leg)
	var foot_pose := body.skeleton.get_bone_pose_rotation(foot_bone)
	print("ANIM_TREE active=%s blend=%s thigh=%s foot=%s" % [body.tree.active, blend, thigh_pose, foot_pose])
	assert(body.tree.active and blend.y > 0.9, "árvore deve selecionar o ciclo de corrida")
	assert(absf(thigh_pose.dot(Quaternion.IDENTITY)) < 0.99, "clipe deve mover o quadril/pernas, não só o parâmetro")
	await _photo("corrida")
	s.in_move = Vector2.ZERO
	await _physics_frames(5)
	var brake_tail := body._anim_velocity.length()
	await _photo("freio")
	await _physics_frames(55)
	var idle_speed := body._anim_velocity.length()
	await _photo("repouso")
	print("LOCOMOCAO start_0.1s=%.2f run=%.2f brake_0.08s=%.2f idle=%.2f" % [start_speed, run_speed, brake_tail, idle_speed])
	assert(start_speed > 0.1 and start_speed < run_speed, "arrancada visual progressiva")
	assert(brake_tail > 0.2 and brake_tail < run_speed, "freio visual preserva a passada")
	assert(idle_speed < 0.05, "passada conclui e entra em repouso")
	get_tree().quit()


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _photo(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("locomocao_%s.png" % name))
