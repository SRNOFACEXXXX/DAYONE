extends Node

var attack_count := 0


func _ready() -> void:
	Game.test_mode = true
	var island := (load("res://maps/ilha/ilha.tscn") as PackedScene).instantiate()
	add_child(island)
	await island.map_ready
	var player := island.get_node("Explorador") as Node3D
	var director := island.get_node("ZombieDirector") as ZombieDirector
	var local_zombies: Array[ZombieEnemy] = []
	var initial_positions: Dictionary = {}
	var all_zombies := director.get_children().filter(func(node: Node) -> bool: return node is ZombieEnemy)
	assert(all_zombies.size() == 20, "the actual island should spawn the configured zombie population")
	for child in director.get_children():
		if child is ZombieEnemy and child._flat_distance_to(player) <= 10.0:
			local_zombies.append(child)
			initial_positions[child] = child.global_position
	assert(local_zombies.size() == 2, "the real island map should start with two nearby zombies")
	for zombie in local_zombies:
		assert(absf(zombie.global_position.y - player.global_position.y) <= 1.4, "nearby zombies must spawn at ground level beside the player")
	var visible_count := 0
	for zombie in local_zombies:
		if zombie._can_see_target(player):
			visible_count += 1
		zombie.attacked.connect(_on_zombie_attacked)
	print("ISLAND_ZOMBIE_PERCEPTION nearby=", local_zombies.size(), " clear_sight_at_spawn=", visible_count)
	for frame in 900:
		await get_tree().physics_frame
		if frame % 120 == 119:
			for zombie in local_zombies:
				print("ISLAND_ZOMBIE_FRAME t=", (frame + 1) / 60, " state=", ZombieEnemy.State.keys()[zombie.state], " pos=", zombie.global_position, " vel=", zombie.velocity, " distance=", zombie._flat_distance_to(player), " collisions=", zombie.get_slide_collision_count(), " target=", zombie.target)
	var hunting := 0
	var max_approach := 0.0
	for zombie in local_zombies:
		if zombie.state in [ZombieEnemy.State.ALERT, ZombieEnemy.State.CHASE, ZombieEnemy.State.ATTACK]:
			hunting += 1
		max_approach = maxf(max_approach, _flat_distance(initial_positions[zombie], player.global_position) - _flat_distance(zombie.global_position, player.global_position))
	print("ISLAND_ZOMBIE_RESULT states=", local_zombies.map(func(z: ZombieEnemy) -> String: return String(ZombieEnemy.State.keys()[z.state])), " hunting=", hunting, " damage_events=", attack_count, " player_health=", player.get("health"))
	for zombie in local_zombies:
		print("ISLAND_ZOMBIE_TRACE pos=", zombie.global_position, " player=", player.global_position, " distance=", zombie._flat_distance_to(player), " velocity=", zombie.velocity, " target=", zombie.target, " stuck=", zombie._stuck_time)
	assert(visible_count > 0, "at least one nearby spawn must have actual unobstructed sight in the real island geometry")
	assert(hunting > 0, "the island encounter should leave idle and pursue")
	assert(max_approach > 3.0, "a nearby zombie must actually move toward the player on the real island")
	assert(attack_count > 0, "a nearby island zombie should reach the player and attack")
	assert(int(player.get("health")) < 100, "attacks on the real island must reduce player health")
	get_tree().quit(0)


func _on_zombie_attacked(_target: Node3D, _damage: int) -> void:
	attack_count += 1


func _flat_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()
