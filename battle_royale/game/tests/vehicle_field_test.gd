extends Node3D
## Visual test track for wheel centering, suspension travel, and driver-camera placement.

const CAPTURE_DIR := "res://../raw/vehicle_field_test"
const SEQUENCE_DIR := "res://../raw/vehicle_field_test/sequence"

var car: DrivableVehicle
var camera: Camera3D
var test_driver: Soldier
var terrain: IlhaTerrain


func _ready() -> void:
	Game.test_mode = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_setup_lighting()
	await _setup_track()
	_spawn_car()
	await _wait_physics(36)
	assert(car.freeze, "parked vehicle should freeze only after suspension preload")
	var parked_base: MeshInstance3D
	for item in car.find_children("*", "MeshInstance3D", true, false):
		if "base" in String(item.name).to_lower():
			parked_base = item as MeshInstance3D
			break
	var parked_clearance := _world_mesh_clearance(parked_base) if parked_base else NAN
	print("PARKED_CLEARANCE_M ", snappedf(parked_clearance, .01), " spawn=", car.global_position)
	assert(parked_base != null and parked_clearance > .10,
			"settled parked chassis must keep clearance above real island terrain")
	test_driver.global_position = car.global_position + car.global_basis.x * 2.0
	await _capture_entry_sequence()
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	print("VEHICLE_FIELD_TEST_DONE ", ProjectSettings.globalize_path(CAPTURE_DIR))
	get_tree().quit()


func _setup_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("87b9dc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e6f1")
	env.ambient_light_energy = 1.0
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.1
	add_child(sun)
	camera = Camera3D.new()
	camera.name = "TestCamera"
	camera.fov = 56.0
	camera.current = true
	add_child(camera)


func _setup_track() -> void:
	# Usa a malha e a HeightMapShape3D reais da ilha, sem os 12 mil objetos de
	# vegetação que travam o teste completo. A posição inicial coincide com o
	# spawn normal do mapa e a suspensão testa as ondulações reais do heightmap.
	terrain = IlhaTerrain.new()
	terrain.name = "TerrenoRealDaIlha"
	add_child(terrain)
	await terrain.terrain_ready


func _spawn_car() -> void:
	var model := (load("res://assets/models/cenario/carros/carro_sedan_aberto.fbx") as PackedScene).instantiate()
	add_child(model)
	car = DrivableVehicle.create_from_model(model, "cenario/carros/carro_sedan_aberto")
	car.global_position = Vector3(-300, terrain.height_world(-300, -300), -300)
	car.reset_physics_interpolation()
	test_driver = Soldier.new()
	test_driver.name = "FieldTestDriver"
	add_child(test_driver)


func _capture_entry_sequence() -> void:
	# Recreate the exact transition that looks wrong in-game: parked/frozen car,
	# player entry unfreezes it, suspension takes load, then throttle crosses bumps.
	Input.action_release("move_forward")
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	test_driver.global_position = car.global_position + car.global_basis.x * 2.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SEQUENCE_DIR))
	assert(car.enter_vehicle(test_driver), "driver must reactivate suspension from parked state")
	var wheel := car.get_node("FrontLeft") as VehicleWheel3D
	var visual := wheel.get_node("OriginalWheelVisual") as MeshInstance3D
	var body_mesh: MeshInstance3D
	for item in car.find_children("*", "MeshInstance3D", true, false):
		if "base" in String(item.name).to_lower():
			body_mesh = item as MeshInstance3D
			break
	print("ENTRY_FILM_START settled_y=", snappedf(car.global_position.y, .01),
		" body_clearance=", snappedf(_world_mesh_clearance(body_mesh) if body_mesh else NAN, .01),
		" wheel_contacts=", _contact_count())
	var captured := 0
	var max_hub_error := 0.0
	var min_body_bottom := INF
	var min_tire_clearance := INF
	var max_roll_deg := 0.0
	var max_speed_kmh := 0
	var steering_phase_start := -1
	var steering_phase := 0
	var track_space := get_world_3d().direct_space_state
	# Não misturar quadros de execuções anteriores no GIF do teste.
	var sequence_path := ProjectSettings.globalize_path(SEQUENCE_DIR)
	for old_frame in DirAccess.get_files_at(sequence_path):
		if old_frame.begins_with("frame_") and old_frame.ends_with(".png"):
			DirAccess.remove_absolute(sequence_path.path_join(old_frame))
	for physics_frame in 240:
		await get_tree().physics_frame
		if physics_frame == 32:
			Input.action_press("move_forward")
		# Inicia o slalom assim que chega a velocidade de rua e inverte o esterço
		# com o carro ainda em movimento; a própria velocidade limita o ângulo.
		if steering_phase == 0 and car.speed_kmh() >= 35:
			steering_phase = 1
			steering_phase_start = physics_frame
			Input.action_press("move_right")
		if steering_phase == 1 and physics_frame - steering_phase_start >= 36:
			steering_phase = 2
			steering_phase_start = physics_frame
			Input.action_release("move_right")
			Input.action_press("move_left")
		if steering_phase == 2 and physics_frame - steering_phase_start >= 36:
			steering_phase = 3
			Input.action_release("move_left")
		if car.speed_kmh() > 50.0:
			Input.action_release("move_forward")
		max_speed_kmh = maxi(max_speed_kmh, car.speed_kmh())
		var local_right := car.global_basis.x.normalized()
		var local_up := car.global_basis.y.normalized()
		var roll_deg := rad_to_deg(atan2(-local_right.dot(Vector3.UP), local_up.dot(Vector3.UP)))
		max_roll_deg = maxf(max_roll_deg, absf(roll_deg))
		if physics_frame < 24 or physics_frame % 4 != 0:
			continue
		var car_xf := car.get_global_transform_interpolated()
		var focus := car_xf * Vector3(0, .76, 0)
		camera.global_position = car_xf * Vector3(5.8, 2.0, .15)
		camera.look_at(focus, Vector3.UP)
		# Sincroniza com o mesmo alpha de interpolação usado no frame que será gravado.
		car.call("_sync_wheel_visuals", 0.0)
		var center := visual.global_transform * visual.get_aabb().get_center()
		var hub := wheel.get_contact_point() + wheel.get_contact_normal() * (wheel.wheel_radius + DrivableVehicle.VISUAL_TIRE_CLEARANCE)
		var render_xf := car.get_global_transform_interpolated()
		var render_hub := render_xf * (car.global_transform.affine_inverse() * hub)
		var gap_to_hub := center.distance_to(render_hub) if wheel.is_in_contact() else -1.0
		var body_bottom := _world_mesh_clearance(body_mesh) if body_mesh else NAN
		if wheel.is_in_contact():
			max_hub_error = maxf(max_hub_error, gap_to_hub)
		min_body_bottom = minf(min_body_bottom, body_bottom)
		if wheel.is_in_contact():
			var tire_side := 1.0 if wheel.position.x > 0.0 else -1.0
			var probe := center + render_xf.basis.x * tire_side * .19
			var ray := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * .5,
				probe - Vector3.UP * .75, 1, [car.get_rid()])
			var surface := track_space.intersect_ray(ray)
			if not surface.is_empty():
				var clearance := center.y - wheel.wheel_radius - float(surface.position.y)
				min_tire_clearance = minf(min_tire_clearance, clearance)
		await _capture("sequence/frame_%03d.png" % captured)
		captured += 1
	assert(captured >= 50, "entry and steering test should capture >=50 frames")
	assert(max_hub_error < .03, "interpolated tire hub must stay aligned in the movie (%.3f m)" % max_hub_error)
	assert(min_body_bottom > -.05, "chassis must not pass through the island terrain (%.3f m)" % min_body_bottom)
	assert(min_tire_clearance > -.002, "tire mesh must not penetrate island surface (%.3f m)" % min_tire_clearance)
	assert(max_speed_kmh >= 20, "stability maneuver must reach useful speed (%d km/h)" % max_speed_kmh)
	assert(max_roll_deg < 32.0, "sedan should stay upright through alternating steering (%.1f deg roll)" % max_roll_deg)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("move_left")
	print("ENTRY_FILM_DONE frames=", captured, " max_hub_error_m=", snappedf(max_hub_error, .003),
		" min_body_clearance_m=", snappedf(min_body_bottom, .03), " min_tire_clearance_m=",
		snappedf(min_tire_clearance, .003), " peak_speed_kmh=", max_speed_kmh,
		" max_roll_deg=", snappedf(max_roll_deg, .1), " dir=", ProjectSettings.globalize_path(SEQUENCE_DIR))


func _world_mesh_clearance(mesh: MeshInstance3D) -> float:
	if mesh == null or mesh.mesh == null:
		return NAN
	var aabb := mesh.get_aabb()
	var lowest := INF
	for x in [aabb.position.x, aabb.end.x]:
		for y in [aabb.position.y, aabb.end.y]:
			for z in [aabb.position.z, aabb.end.z]:
				var corner := mesh.global_transform * Vector3(x, y, z)
				lowest = minf(lowest, corner.y - terrain.height_world(corner.x, corner.z))
	return lowest


func _contact_count() -> int:
	var count := 0
	for item in car.get_children():
		if item is VehicleWheel3D and (item as VehicleWheel3D).is_in_contact():
			count += 1
	return count


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(CAPTURE_DIR).path_join(name)
	get_viewport().get_texture().get_image().save_png(path)
