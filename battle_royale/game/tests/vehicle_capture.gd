extends Node

func _ready() -> void:
	Game.test_mode = true
	var island: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(island)
	await island.map_ready
	for _i in 150:
		await get_tree().physics_frame
	var target := Vector3(340, island.terrain.height_world(340,-199), -199)
	var car: DrivableVehicle
	var distance := INF
	for node in get_tree().get_nodes_in_group("drivable_vehicle"):
		var candidate := node as DrivableVehicle
		var d := candidate.global_position.distance_to(target)
		if d < distance:
			car = candidate
			distance = d
	car.steering = deg_to_rad(24)
	for _i in 25:
		await get_tree().physics_frame
	var old := get_viewport().get_camera_3d()
	if old:
		old.current = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 56
	var front := car.global_basis.z.normalized()
	var side := car.global_basis.x.normalized()
	camera.global_position = car.global_position - front * 6.2 + side * 4.4 + Vector3.UP * 2.15
	camera.look_at(car.global_position + Vector3.UP * .75)
	for _i in 15:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := String(Game.test_args.get("out", OS.get_user_data_dir()))
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out.path_join("veiculo_fisico.png"))
	print("VEHICLE_CAPTURE car=", car.display_name(), " pos=", car.global_position, " wheels=4 steering_deg=24")
	get_tree().quit()
