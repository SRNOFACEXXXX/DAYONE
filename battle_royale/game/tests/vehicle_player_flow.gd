extends Node
## Player/controller integration on the complete survival scene.

func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var match_scene: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(match_scene)
	await match_scene.match_initialized
	while match_scene.br_loot_root == null:
		await get_tree().process_frame
	var cars := get_tree().get_nodes_in_group("drivable_vehicle")
	assert(cars.size() >= 10)
	var car := cars[0] as DrivableVehicle
	var player := match_scene.local_player
	var controller := player.controller as PlayerController
	player.global_position = car.global_position + car.global_basis.x * 2.0
	player.reset_physics_interpolation()
	await get_tree().physics_frame
	print("VEHICLE_ENTRY_DEBUG distance=", player.global_position.distance_to(car.global_position), " speed=", car.linear_velocity.length(), " can_enter=", car.can_enter(player))
	Input.action_press("use")
	for _i in 48:
		await get_tree().physics_frame
	Input.action_release("use")
	for _i in 32:
		await get_tree().physics_frame
	assert(controller.active_vehicle == car)
	assert(player.external_motion and player.collision_layer == 0)
	Input.action_press("move_forward")
	for _i in 90:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	assert(car.linear_velocity.length() > .5)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	for _i in 10:
		await get_tree().physics_frame
	Input.action_press("use")
	for _i in 48:
		await get_tree().physics_frame
	Input.action_release("use")
	for _i in 30:
		await get_tree().physics_frame
	assert(controller.active_vehicle == null)
	assert(not player.external_motion and player.collision_layer == Soldier.LAYER_SOLDIER)
	assert(player.visible)
	print("VEHICLE_PLAYER_FLOW OK cars=", cars.size())
	get_tree().quit()
