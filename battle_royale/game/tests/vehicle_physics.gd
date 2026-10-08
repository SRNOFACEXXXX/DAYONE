extends Node
## Real island vehicle integration: existing spawn, mass, spring contact, steering,
## propulsion, visual wheel roll and a stable exit. No mocked vehicle scene.

var failures := 0

func check(ok: bool, label: String) -> void:
	print("VEHICLE_CHECK ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _ready() -> void:
	Game.test_mode = true
	var island: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(island)
	await island.map_ready
	for _i in 180:
		await get_tree().physics_frame
	await _check_terrain_collision_matches_surface(island)
	var terrain := island.get("terrain") as IlhaTerrain
	var vehicles := get_tree().get_nodes_in_group("drivable_vehicle")
	check(vehicles.size() >= 10, "existing map cars converted (%d)" % vehicles.size())
	var max_spawn_error := 0.0
	for i in mini(vehicles.size(), 20):
		var spawned := vehicles[i] as DrivableVehicle
		var ground_y: float = terrain.height_world(spawned.global_position.x, spawned.global_position.z)
		max_spawn_error = maxf(max_spawn_error, absf(spawned.global_position.y - ground_y))
	check(max_spawn_error < .03, "all car spawns align with terrain (max %.3f m)" % max_spawn_error)
	if vehicles.is_empty():
		get_tree().quit(1)
		return
	var car := vehicles[0] as DrivableVehicle
	check(is_equal_approx(car.mass, DrivableVehicle.MASS_KG), "vehicle has realistic mass")
	check(car.freeze, "parked car is static and cannot be pushed by player")
	check(car.get_node_or_null("ChassisCollision") != null, "chassis collision exists")
	var wheels := car.get_children().filter(func(n): return n is VehicleWheel3D)
	check(wheels.size() == 4, "four physical suspension wheels")
	check(car.global_basis.y.dot(Vector3.UP) > .7, "chassis settles upright")
	# VehicleWheel3D.position é reescrito pela física a cada passo: é a altura do
	# CUBO (ancoragem 0,51 m menos o comprimento atual da mola), não a ancoragem.
	# Carregada pelo peso do carro a mola fica entre rest_length-travel e rest_length.
	var fl_wheel := car.get_node("FrontLeft") as VehicleWheel3D
	var ride_height: float = fl_wheel.position.y
	var hub_rest := .51 - fl_wheel.wheel_rest_length
	check(ride_height > hub_rest - fl_wheel.suspension_travel and ride_height < hub_rest + fl_wheel.suspension_travel,
		"loaded wheel hub within suspension travel at sedan ride height (%.2f m, rest %.2f)" % [ride_height, hub_rest])

	var s := Soldier.new()
	s.name = "VehicleTestDriver"
	add_child(s)
	s.global_position = car.global_position + car.global_basis.x * 2.0
	check(car.enter_vehicle(s), "driver enters existing car")
	check(not car.freeze, "vehicle becomes dynamic only with driver")
	for _i in 30:
		await get_tree().physics_frame
	var contacts := wheels.filter(func(w): return (w as VehicleWheel3D).is_in_contact()).size()
	check(contacts >= 2, "springs carry chassis when driving (%d contacts)" % contacts)
	var wheel_visual := car.get_node("FrontLeft/OriginalWheelVisual") as MeshInstance3D
	var front_left := car.get_node("FrontLeft") as VehicleWheel3D
	var visual_center := wheel_visual.global_transform * wheel_visual.get_aabb().get_center()
	var physical_hub := front_left.get_contact_point() + front_left.get_contact_normal() * front_left.wheel_radius
	check(front_left.is_in_contact() and visual_center.distance_to(physical_hub) < .02,
		"visual tire stays centered on suspension hub (error %.3f m)" % visual_center.distance_to(physical_hub))
	var roll_before := wheel_visual.global_basis
	var start := car.global_position
	Input.action_press("move_forward")
	var peak_speed := 0.0
	for _i in 240:
		await get_tree().physics_frame
		peak_speed = maxf(peak_speed, car.linear_velocity.length())
	Input.action_release("move_forward")
	var travel := car.global_position.distance_to(start)
	check(travel > 4.0, "engine moves weighted car (%.1f m)" % travel)
	# Pico, não a velocidade final: o percurso reto pode terminar em cenário (casa/cerca).
	check(peak_speed > 8.0, "vehicle gains speed (peak %.1f m/s)" % peak_speed)
	check(not wheel_visual.global_basis.is_equal_approx(roll_before), "wheel visual rolls while driving")
	var driver_camera := Camera3D.new()
	add_child(driver_camera)
	car.first_person_camera = true
	car.update_camera(driver_camera, 1.0 / 60.0)
	var expected_driver_eye := car.get_global_transform_interpolated() * Vector3(.42, 1.12, -.28)
	check(driver_camera.global_position.distance_to(expected_driver_eye) < .02,
		"first-person camera stays with driver at high speed")
	Input.action_press("move_right")
	for _i in 45:
		await get_tree().physics_frame
	Input.action_release("move_right")
	check(absf(car.steering) > deg_to_rad(3.0), "front axle steers with input")
	check((car.get_node("FrontLeft") as VehicleWheel3D).use_as_steering and not (car.get_node("RearLeft") as VehicleWheel3D).use_as_steering, "steering limited to front wheels")
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	for _i in 20:
		await get_tree().physics_frame
	car.exit_vehicle()
	check(car.driver == null and not s.external_motion, "driver exits and regains movement")
	check(car.freeze, "vehicle parks immediately on exit")
	print("VEHICLE_RESULT failures=", failures, " travel_m=", snappedf(travel,.1), " contacts=", contacts, " ride_height_m=", snappedf(ride_height,.01))
	get_tree().quit(0 if failures == 0 else 1)


func _check_terrain_collision_matches_surface(island: Node3D) -> void:
	var terrain := island.get("terrain") as IlhaTerrain
	var terrain_body := terrain.get_node("TerrenoColisao") as StaticBody3D
	var saved_layer := terrain_body.collision_layer
	const TEST_LAYER := 1 << 19
	terrain_body.collision_layer = TEST_LAYER
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = island.get_world_3d().direct_space_state
	var max_error := 0.0
	var hits := 0
	for i in 24:
		var x := -520.0 + float(i % 6) * 37.0 + IlhaTerrain.STEP * .72
		var z := -470.0 + float(i / 6) * 41.0 + IlhaTerrain.STEP * .28
		var expected_y := terrain.height_world(x, z)
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(x, expected_y + 200.0, z), Vector3(x, expected_y - 200.0, z), TEST_LAYER)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			hits += 1
			max_error = maxf(max_error, absf(float(hit.position.y) - expected_y))
	terrain_body.collision_layer = saved_layer
	await get_tree().physics_frame
	check(hits >= 20 and max_error < .03,
		"terrain collision matches rendered surface (%d rays, max %.3f m)" % [hits, max_error])
