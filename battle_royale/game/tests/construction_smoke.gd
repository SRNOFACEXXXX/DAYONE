extends Node
## Integration test: performs real world raycasts, previews and placements.

class MockMatch extends Node3D:
	var hud: CanvasLayer = CanvasLayer.new()
	var local_player: Soldier = Soldier.new()
	var br_bag: BRInventory = BRInventory.new()
	var br_ui: Control


func _ready() -> void:
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var m := MockMatch.new()
	add_child(m)
	m.add_child(m.hud)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#91b7cf")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d8dfce")
	environment.ambient_light_energy = .8
	world_environment.environment = environment
	m.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	m.add_child(sun)
	m.add_child(_make_ground())
	m.local_player.position = Vector3(0, 0, 8)
	m.local_player.external_motion = true
	m.local_player.controller = PlayerController.new()
	m.add_child(m.local_player)
	var camera := Camera3D.new()
	m.add_child(camera)
	camera.current = true
	(m.local_player.controller as PlayerController).camera = camera
	var build := ConstructionSystem.new()
	m.add_child(build)
	build.setup(m)

	# UI entry point: B opens the wheel, Enter selects foundation.
	var open := InputEventKey.new()
	open.pressed = true
	open.physical_keycode = KEY_B
	assert(build.handle_input(open), "B must open construction wheel")
	await get_tree().process_frame
	assert(build.wheel_open and build.wheel_ui.visible, "construction wheel must be visible")
	var accept := InputEventKey.new()
	accept.pressed = true
	accept.physical_keycode = KEY_ENTER
	assert(build.handle_input(accept), "Enter must select the foundation")
	assert(build.current_piece == 0)
	assert(build.construction_mode, "selecting a piece must enable the construction HUD/mode")
	assert(build.wheel_ui.visible and not build.wheel_open, "the wheel should close while the construction HUD stays visible")

	# 2x2 floor footprint: all four foundations go through the actual camera ray.
	for point in [Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 4), Vector3(4, 0, 4)]:
		assert(await _place_from_ray(build, camera, 0, point, 0, "foundation %s" % point))
	# The overlap rule must reject occupying the exact same foundation volume.
	build.current_piece = 0
	assert(build._overlaps_constructed(Vector3(0, 0, 0), build.PIECES[0]), "duplicate foundation volume must be blocked")

	# Two wall modules along every edge. Targets land on foundation tops; snapping
	# maps them to the shared 4 m sockets, so adjacent ends meet without gaps.
	var walls := [
		[4, Vector3(0, .24, -1.8), 0, "front door"],
		[2, Vector3(4, .24, -1.8), 0, "front wall"],
		[3, Vector3(0, .24, 5.8), 0, "back window"],
		[2, Vector3(4, .24, 5.8), 0, "back wall"],
		[3, Vector3(-1.8, .24, 0), 1, "left window"],
		[2, Vector3(-1.8, .24, 4), 1, "left wall"],
		[2, Vector3(5.8, .24, 0), 1, "right wall A"],
		[2, Vector3(5.8, .24, 4), 1, "right wall B"],
	]
	for data in walls:
		assert(await _place_from_ray(build, camera, int(data[0]), data[1], int(data[2]), String(data[3])))
	# F alignment takes the aim point on a wall and attaches the next 4 m wall
	# exactly to its end, keeping the wall's orientation and elevation.
	build.current_piece = 2
	build.yaw_step = 0
	build._build_preview_mesh()
	await _aim_from(camera, Vector3(5.8, 1.8, -8), Vector3(5.8, 1.8, -2.08))
	build._update_candidate()
	assert(build.candidate_valid, "F snap should accept an aimed wall endpoint")
	assert(build.candidate_transform.origin.distance_to(Vector3(8, .24, -2)) < .06, "next wall must share the exact 4 m end socket")
	await _aim_from(camera, Vector3(5.8, 8, -2.08), Vector3(5.8, 3.24, -2.08), Vector3.FORWARD)
	build._update_candidate()
	assert(build.candidate_valid, "aiming at a wall top should support the next aligned story")
	assert(build.candidate_transform.origin.distance_to(Vector3(4, 3.24, -2)) < .06, "upper wall must align with the lower wall footprint")
	# A 2x2 roof snaps to the actual wall top (y=3.24 m), not another 3 m above it.
	for data in [[Vector3(-1.5, 3.24, -2.0), 0, 0, 0], [Vector3(4, 3.24, -2.0), 0, 4, 0], [Vector3(0, 3.24, 5.95), 0, 0, 4], [Vector3(4, 3.24, 5.95), 0, 4, 4]]:
		var target: Vector3 = data[0]
		assert(await _place_from_ray(build, camera, 5, target, int(data[1]), "roof %s" % target, Vector3(float(data[2]), 3.24, float(data[3]))))
	# Aiming upward at a roof underside places the next panel flush beneath it.
	build.current_piece = 5
	build._build_preview_mesh()
	await _aim_from(camera, Vector3(1.5, 1.2, 1.5), Vector3(1.5, 3.24, 1.5), Vector3.FORWARD)
	build._update_candidate()
	assert(build.candidate_valid, "roof must be placeable while aiming from below")
	assert(absf(build.candidate_transform.origin.y - 3.06) < .03, "under-roof snap should touch the ceiling without penetrating")

	# Reproduce the reported failure in a real two-storey 2x2 build. The first
	# roof becomes the upper floor, then we build the second-storey walls and
	# ceiling through the same camera-ray placement path used by gameplay.
	for point in [Vector3(0, 3.42, 0), Vector3(4, 3.42, 0), Vector3(0, 3.42, 4), Vector3(4, 3.42, 4)]:
		assert(await _place_from_ray(build, camera, 1, point, 0, "upper floor %s" % point, Vector3(point.x, 3.42, point.z)))
	var upper_walls := [
		[2, Vector3(0, 3.58, -1.8), 0, "upper front A"], [2, Vector3(4, 3.58, -1.8), 0, "upper front B"],
		[2, Vector3(0, 3.58, 5.8), 0, "upper back A"], [2, Vector3(4, 3.58, 5.8), 0, "upper back B"],
		[2, Vector3(-1.8, 3.58, 0), 1, "upper left A"], [2, Vector3(-1.8, 3.58, 4), 1, "upper left B"],
		[2, Vector3(5.8, 3.58, 0), 1, "upper right A"], [2, Vector3(5.8, 3.58, 4), 1, "upper right B"],
	]
	for data in upper_walls:
		assert(await _place_from_ray(build, camera, int(data[0]), data[1], int(data[2]), String(data[3])))
	# Place a second-level ceiling while aiming at the top face of the upper
	# walls; use the inner edge so the actual vertical ray hits the wall top.
	for data in [[Vector3(0, 6.58, -1.95), Vector3(0, 6.58, 0)], [Vector3(4, 6.58, -1.95), Vector3(4, 6.58, 0)], [Vector3(0, 6.58, 5.95), Vector3(0, 6.58, 4)], [Vector3(4, 6.58, 5.95), Vector3(4, 6.58, 4)]]:
		assert(await _place_from_ray(build, camera, 1, data[0], 0, "second-storey ceiling %s" % data[0], data[1]))
	build.current_piece = 5
	build.align_to_piece = true
	build.notice_time = 0.0
	build._build_preview_mesh()
	var roof_frames := [
		[Vector3(-1.2, 4.1, -1.2), Vector3(1.0, 6.66, 1.0)],
		[Vector3(1.2, 4.1, -1.2), Vector3(-1.0, 6.66, 1.0)],
		[Vector3(1.2, 4.1, 1.2), Vector3(-1.0, 6.66, -1.0)],
		[Vector3(-1.2, 4.1, 1.2), Vector3(1.0, 6.66, -1.0)],
	]
	for i in roof_frames.size():
		await _aim_from(camera, roof_frames[i][0], roof_frames[i][1])
		build._update_candidate()
		var ray_result: Dictionary = _cast_construction_ray(build, camera)
		assert(not ray_result.is_empty(), "two-storey roof frame %d must hit an actual construction surface" % i)
		assert(build.candidate_valid, "roof from inside the second storey must be green in frame %d; hit=%s normal=%s candidate=%s" % [i, ray_result.position, ray_result.normal, build.candidate_transform.origin])
		assert(absf(build.candidate_transform.origin.y - 6.40) < .03, "second-storey roof should sit flush against ceiling underside")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var frame_path := OS.get_environment("TEMP").path_join("construction_roof_below_%02d.png" % i)
			get_viewport().get_texture().get_image().save_png(frame_path)
			print("ROOF_BELOW_FRAME=%s hit=%s normal=%s ghost=%s" % [frame_path, ray_result.position, ray_result.normal, build.candidate_transform.origin])
		if i == 3:
			assert(build.place_current(), "a valid second-storey roof preview must place successfully")

	var parts := get_tree().get_nodes_in_group("player_constructed")
	assert(parts.size() == 33, "two-storey 2x2 house should have 33 modules, found %d" % parts.size())
	assert(build._material_count("wood") == 0 and build._material_count("stone") == 0, "free test mode must place with empty inventory")
	for node in parts:
		assert((node as Node3D).find_child("BuildCollision", true, false) is StaticBody3D, "each module needs collision")
	_assert_wall_socket_continuity(parts)

	# The door is a real leaf with matching physics; E toggles it and clears the doorway.
	var door: ConstructionSystem.ConstructionDoor
	for node in get_tree().get_nodes_in_group("construction_doors"):
		door = node as ConstructionSystem.ConstructionDoor
		break
	assert(door != null, "door module must create an operable leaf")
	m.local_player.global_position = Vector3(0, 0, -1)
	assert(_press_key(build, KEY_E), "E interaction should find nearby built door")
	await get_tree().create_timer(.45).timeout
	assert(door.opened and door.panel_collision.disabled, "open door must clear its collision from the passage")
	m.local_player.external_motion = false
	m.local_player.global_position = Vector3(0, .24, -3)
	m.local_player.yaw = PI
	m.local_player.in_move = Vector2(0, 1)
	for frame in 60:
		if m.local_player.global_position.z > -1.4:
			m.local_player.in_move = Vector2.ZERO
		await get_tree().physics_frame
	assert(m.local_player.global_position.z > -1.5 and m.local_player.is_on_floor(), "Soldier capsule must pass through the open doorway")
	m.local_player.external_motion = true
	m.local_player.in_move = Vector2.ZERO
	m.local_player.global_position = Vector3(0, 0, -1)
	assert(_press_key(build, KEY_E), "E interaction should close the open door")
	await get_tree().create_timer(.45).timeout
	assert(not door.opened and not door.panel_collision.disabled, "closed door must block the opening")

	# Three connected 2 m stair modules; each upper socket is the next lower socket.
	assert(await _place_from_ray(build, camera, 6, Vector3(20, 0, 20), 0, "stair 1"))
	var stairs := get_tree().get_nodes_in_group("player_constructed").filter(func(n): return String(n.get_meta("construction_id", "")) == "stairs")
	assert(stairs.size() == 1)
	for i in 2:
		var previous: Node3D = stairs[i]
		var target := previous.global_position + previous.global_basis * Vector3(0, 1.35, -.875)
		assert(await _place_from_ray(build, camera, 6, target, 0, "stair %d" % (i + 2)))
		stairs = get_tree().get_nodes_in_group("player_constructed").filter(func(n): return String(n.get_meta("construction_id", "")) == "stairs")
		assert(stairs.size() == i + 2)
	for i in range(stairs.size() - 1):
		var lower: Node3D = stairs[i]
		var upper: Node3D = stairs[i + 1]
		var socket := lower.global_position + lower.global_basis * Vector3(0, 1.5, -2)
		assert(socket.distance_to(upper.global_position) < .02, "stair end sockets must join; gap at segment %d" % i)
	assert(stairs[2].global_position.y - stairs[0].global_position.y > 2.99, "3 stairs must gain 3 m of elevation")
	# Exercise the game's real Soldier capsule and step-up solver across all 24 treads.
	m.local_player.external_motion = false
	m.local_player.global_position = Vector3(20, 0, 22.5)
	m.local_player.yaw = 0.0
	m.local_player.in_move = Vector2(0, 1)
	for frame in 180:
		if m.local_player.global_position.z < 16.8:
			m.local_player.in_move = Vector2.ZERO
		await get_tree().physics_frame
	m.local_player.in_move = Vector2.ZERO
	assert(m.local_player.global_position.z < 16.8 and m.local_player.global_position.z > 14.8 and m.local_player.global_position.y > 4.3 and m.local_player.is_on_floor(),
		"Soldier capsule must climb the connected 3-piece staircase; ended at %s" % m.local_player.global_position)

	# X removes the aimed user-built object; G exits the whole construction mode.
	m.local_player.external_motion = true
	await _aim_from(camera, Vector3(0, 1.2, -8), Vector3(0, 1.2, -2.08))
	assert(_press_key(build, KEY_X), "X should be handled while construction mode is active")
	await get_tree().process_frame
	assert(not is_instance_valid(door), "aimed built door must be removed")
	assert(_press_key(build, KEY_F), "F should toggle piece alignment")
	assert(not build.align_to_piece, "F should switch to regular grid mode")
	assert(_press_key(build, KEY_G), "G should exit construction mode")
	assert(not build.construction_mode and build.current_piece == -1 and not build.preview_root.visible, "G must close build mode and hide preview")

	build.current_piece = -1
	build.set_process(false)
	build.preview_root.visible = false
	camera.global_position = Vector3(9, 2.7, -10)
	camera.look_at(Vector3(2, 1.35, 2), Vector3.UP)
	print("CONSTRUCTION_INTEGRATION_OK two_storey_house=2x2 modules=33 wall_snap=4m second_storey_roof_from_below=ok stairs=3_contiguous door=passable delete=ok exit=G")
	if DisplayServer.get_name() != "headless":
		build.construction_mode = true
		build.current_piece = 5
		build.candidate_valid = true
		build.wheel_open = true
		build.wheel_ui.visible = true
		build.wheel_ui.queue_redraw()
		await RenderingServer.frame_post_draw
		var screenshot_path := OS.get_environment("TEMP").path_join("construction_radial_menu.png")
		get_viewport().get_texture().get_image().save_png(screenshot_path)
		print("CONSTRUCTION_RADIAL_MENU_SCREENSHOT=" + screenshot_path)
	m.local_player.controller.free()
	m.local_player.free()
	m.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _place_from_ray(build: ConstructionSystem, camera: Camera3D, piece_id: int, target: Vector3, rotation_step: int, label: String, expected: Variant = null) -> bool:
	build.current_piece = piece_id
	build.yaw_step = rotation_step
	build._build_preview_mesh()
	await _aim(camera, target)
	build._update_candidate()
	assert(build.candidate_valid, "%s: actual placement ray rejected target %s" % [label, target])
	if expected is Vector3:
		assert(build.candidate_transform.origin.distance_to(expected) < .06, "%s: expected snapped anchor %s, got %s" % [label, expected, build.candidate_transform.origin])
	return build.place_current()


func _aim(camera: Camera3D, target: Vector3) -> void:
	camera.global_position = target + Vector3(0, 7, 0)
	camera.look_at(target, Vector3.FORWARD)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _aim_from(camera: Camera3D, origin: Vector3, target: Vector3, up: Vector3 = Vector3.UP) -> void:
	camera.global_position = origin
	var direction := (target - origin).normalized()
	var safe_up := up
	if absf(direction.dot(safe_up.normalized())) > .98:
		safe_up = Vector3.FORWARD
	camera.look_at(target, safe_up)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _cast_construction_ray(build: ConstructionSystem, camera: Camera3D) -> Dictionary:
	var player: Soldier = build.match_ref.local_player
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * build.MAX_REACH, Soldier.LAYER_WORLD, [player.get_rid()])
	query.collide_with_areas = false
	return build.match_ref.get_world_3d().direct_space_state.intersect_ray(query)


func _press_key(build: ConstructionSystem, key: Key) -> bool:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = key
	return build.handle_input(event)


func _assert_wall_socket_continuity(parts: Array) -> void:
	var edge_groups := {"front": [], "back": [], "left": [], "right": []}
	for node in parts:
		var root := node as Node3D
		var id := String(root.get_meta("construction_id", ""))
		if id not in ["wall", "window", "door"]:
			continue
		if root.global_position.y > .3:
			continue
		if absf(root.global_position.z + 2) < .02: edge_groups.front.append(root)
		elif absf(root.global_position.z - 6) < .02: edge_groups.back.append(root)
		elif absf(root.global_position.x + 2) < .02: edge_groups.left.append(root)
		elif absf(root.global_position.x - 6) < .02: edge_groups.right.append(root)
	for edge in edge_groups:
		assert(edge_groups[edge].size() == 2, "%s wall edge should have two snapped modules" % edge)
		var a: Node3D = edge_groups[edge][0]
		var b: Node3D = edge_groups[edge][1]
		var axis := Vector3.RIGHT if edge in ["front", "back"] else Vector3.LEFT
		var a_end := a.global_position + a.global_basis * axis * 2.0
		var b_start := b.global_position - b.global_basis * axis * 2.0
		assert(a_end.distance_to(b_start) < .02, "%s wall modules must share exact endpoints" % edge)


func _make_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	ground.name = "SandboxGround"
	ground.collision_layer = Soldier.LAYER_WORLD
	ground.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, .2, 100)
	collision.shape = shape
	ground.add_child(collision)
	ground.position.y = -.1
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#608b38")
	mesh.material_override = material
	ground.add_child(mesh)
	return ground
