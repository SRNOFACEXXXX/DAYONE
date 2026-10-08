extends Node3D

class FlatTestTerrain extends Node3D:
	func height_world(_x: float, _z: float) -> float:
		return 0.0


func _ready() -> void:
	Game.test_mode = true
	var terrain := FlatTestTerrain.new()
	var player := Node3D.new()
	player.name = "TestPlayer"
	player.add_to_group("zombie_targets")
	var player_shape := CollisionShape3D.new()
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.35
	player_capsule.height = 1.8
	player_shape.shape = player_capsule
	player_shape.position.y = 0.9
	player.add_child(player_shape)
	add_child(terrain)
	add_child(player)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(1000.0, 0.2, 1000.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	terrain.add_child(floor_body)
	var director := ZombieDirector.new()
	director.opening_count = 20
	director.nearby_count = 2
	director.inner_radius = 7.0
	director.outer_radius = 9.0
	add_child(director)
	var settlements: Array[Vector3] = [Vector3.ZERO, Vector3(60, 0, 0), Vector3(120, 0, 0), Vector3(180, 0, 0), Vector3(240, 0, 0)]
	director.setup(terrain, player, settlements)
	await get_tree().process_frame
	var spawned := director.get_children().filter(func(node: Node) -> bool: return node is ZombieEnemy)
	assert(spawned.size() == 20, "expected the opening horde to populate settlements and create a nearby encounter")
	var nearby := 0
	var settlement_coverage: Dictionary = {}
	for node in spawned:
		var zombie := node as ZombieEnemy
		var distance := Vector2(zombie.global_position.x - player.global_position.x, zombie.global_position.z - player.global_position.z).length()
		if distance <= 10.0:
			nearby += 1
		else:
			var city := int(round(zombie.global_position.x / 60.0))
			settlement_coverage[city] = int(settlement_coverage.get(city, 0)) + 1
		if distance > 10.0:
			assert(zombie.target == null, "distant settlement zombies should not be given the player as a magic target")
			assert(zombie.state == ZombieEnemy.State.IDLE, "distant zombie should begin idle, not running")
		else:
			assert(zombie.state in [ZombieEnemy.State.IDLE, ZombieEnemy.State.ALERT], "nearby zombie should perceive and react to the player")
		assert(zombie._target_skeleton != null, "spawned zombie is missing its Polyart skeleton")
		assert(zombie.walk_speed <= 0.65, "roaming gait should be a slow walk")
	assert(nearby == 2, "two zombies should start close enough to engage the player immediately")
	assert(settlement_coverage.size() >= 4, "zombies should be distributed across multiple settlements, not one start-area ring")
	var first := spawned[0] as ZombieEnemy
	for _frame in 150:
		await get_tree().physics_frame
	assert(first.target == player, "nearby zombie should acquire the player through its sight cone")
	assert(first.state in [ZombieEnemy.State.ALERT, ZombieEnemy.State.CHASE, ZombieEnemy.State.ATTACK], "nearby zombie should leave idle and react to the player")
	print("ZOMBIE_SPAWN_TEST_OK count=20 nearby=2 settlements=", settlement_coverage.size(), " sight=acquired threat=active slow_patrol=verified polyart=verified")
	get_tree().quit()
