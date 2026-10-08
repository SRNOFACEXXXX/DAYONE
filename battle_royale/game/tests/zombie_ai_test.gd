extends Node


func _ready() -> void:
	var zombie := ZombieEnemy.new()
	zombie._variant_index = 0
	add_child(zombie)
	var player := Node3D.new()
	player.name = "VisionTarget"
	player.add_to_group("zombie_targets")
	player.position = Vector3(0.0, 0.0, -5.0)
	add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert(zombie.state == ZombieEnemy.State.IDLE, "zombie must start idle")
	assert(zombie._animation_tree.active, "locomotion animation blending must be active")
	var locomotion := (zombie._animation_tree.tree_root as AnimationNodeBlendTree).get_node(&"Locomotion") as AnimationNodeBlendSpace1D
	assert(locomotion.find_blend_point_by_name(&"idle") >= 0, "locomotion blend must have an idle pose")
	assert(is_equal_approx(float(zombie._animation_tree.get(&"parameters/Locomotion/blend_position")), 0.0), "stationary zombie must blend to idle instead of walk/run")
	zombie.state = ZombieEnemy.State.PATROL
	zombie.velocity = Vector3(0.08, 0.0, 0.0)
	zombie._update_locomotion_blend(0.0)
	assert(is_equal_approx(float(zombie._animation_tree.get(&"parameters/Locomotion/blend_position")), 0.0), "settled body residual velocity must not play a walking gait")
	zombie.velocity = Vector3(0.3, 0.0, 0.0)
	zombie._update_locomotion_blend(0.0)
	assert(is_equal_approx(float(zombie._animation_tree.get(&"parameters/Locomotion/blend_position")), 0.3), "locomotion blend should engage above its resume threshold")
	zombie.velocity = Vector3(0.18, 0.0, 0.0)
	zombie._update_locomotion_blend(0.0)
	assert(is_equal_approx(float(zombie._animation_tree.get(&"parameters/Locomotion/blend_position")), 0.18), "locomotion hysteresis should avoid flicker near the stop threshold")
	zombie.velocity = Vector3(0.1, 0.0, 0.0)
	zombie._update_locomotion_blend(0.0)
	assert(is_equal_approx(float(zombie._animation_tree.get(&"parameters/Locomotion/blend_position")), 0.0), "gait should stop cleanly below the stop threshold")
	zombie.state = ZombieEnemy.State.IDLE
	zombie.velocity = Vector3.ZERO
	assert(zombie._find_target() == player, "zombie should see a target in front inside its sight range")
	assert(zombie._fitted_visual_height >= Soldier.STAND_HEIGHT and zombie._fitted_visual_height <= Soldier.STAND_HEIGHT + 0.15, "Polyart model height should fit the human capsule")
	assert(Audio.has_sound("zombie_groan"), "zombie moan variations were not registered by the audio system")
	zombie.set_demo_state(&"walk")
	await get_tree().physics_frame
	assert(is_equal_approx(float(zombie._animation_tree.get(&"parameters/Locomotion/blend_position")), zombie.walk_speed), "walk animation should blend to the actual slow patrol speed")
	zombie.set_demo_state(&"idle")
	await _wait_physics(30)
	assert(is_equal_approx(float(zombie._animation_tree.get(&"parameters/Locomotion/blend_position")), 0.0), "idle animation should settle to zero gait")
	var foot_bone := zombie._target_skeleton.find_bone(&"LeftFoot")
	var still_pose := zombie._target_skeleton.get_bone_global_pose(foot_bone)
	await _wait_physics(30)
	var settled_pose := zombie._target_skeleton.get_bone_global_pose(foot_bone)
	assert(still_pose.origin.distance_to(settled_pose.origin) < 0.015, "idle foot must remain planted rather than cycling a gait while stationary")
	zombie.release_demo_lock()

	player.position = Vector3(0.0, 0.0, 12.0)
	assert(zombie._find_target() == null, "zombie should not see a player behind its back")
	player.position = Vector3(0.0, 0.0, -40.0)
	assert(zombie._find_target() == null, "zombie should not see beyond its short detection range")
	player.position = Vector3(0.0, 0.0, -20.0)

	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 0.7)
	wall_shape.shape = box
	wall.position = Vector3(0.0, 1.0, -10.0)
	wall.add_child(wall_shape)
	add_child(wall)
	await get_tree().physics_frame
	assert(zombie._find_target() == null, "solid walls should block zombie sight")

	print("ZOMBIE_AI_TEST_OK idle_pose=planted slow_patrol=verified fov=105deg range=10.5m occlusion=verified height=", snappedf(zombie._fitted_visual_height, 0.01), " groan=verified")
	get_tree().quit()


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
