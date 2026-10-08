extends Node3D
## Animation and AI validation harness. Captures sequential PNGs through every
## imported clip, then runs assertions against the real detection/attack/death flow.

const ZOMBIE_SCENE := preload("res://core/zombie.tscn")
const MODEL_SCENE := "res://assets/models/zombies/polyart_pack/variants/zombie_00.tscn"
const CAPTURE_DIR := "res://../raw/zombie_studio"
const SEQUENCE_DIR := CAPTURE_DIR + "/sequence"
const FPS := 12.0

var zombie: ZombieEnemy
var camera: Camera3D
var hud: Label
var sequence_frame := 0
var attack_count := 0
var assertions_ok := true


func _ready() -> void:
	Game.test_mode = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SEQUENCE_DIR))
	_clear_sequence()
	_setup_stage()
	await _capture_target_bind_pose()
	_spawn_staged_zombie()
	await get_tree().process_frame
	await get_tree().physics_frame
	print("ZOMBIE_STUDIO_RIG_READY scary_animation_skeleton=", zombie._source_skeleton != null, " polyart_mesh_skeleton=", zombie._target_skeleton != null)
	assert(zombie._animation_player != null, "Scary Zombie Pack AnimationPlayer must load")
	assert(zombie._target_skeleton != null, "Polyart zombie mesh must load")
	for clip_name in [&"idle", &"walk", &"scream", &"run", &"attack", &"death", &"neck_bite", &"crawl", &"bite", &"bite_alt", &"dying", &"running_crawl"]:
		assert(zombie._animation_player.has_animation(clip_name), "missing Scary clip: " + String(clip_name))
	for bone_name in [&"Hips", &"Spine", &"Chest", &"Neck", &"LeftUpperArm", &"RightUpperArm", &"LeftUpperLeg", &"RightUpperLeg"]:
		assert(zombie._target_skeleton.find_bone(bone_name) >= 0, "Polyart humanoid bone is unmapped: " + String(bone_name))
	if DisplayServer.get_name() != "headless":
		for clip_name in [&"idle", &"walk", &"scream", &"run", &"attack", &"death", &"neck_bite", &"crawl", &"bite", &"bite_alt", &"dying", &"running_crawl"]:
			await _capture_clip(clip_name)
	else:
		print("ZOMBIE_STUDIO_CAPTURE_SKIPPED headless renderer has no frame_post_draw")
	await _run_ai_assertions()
	print("ZOMBIE_STUDIO_OK frames=", sequence_frame, " dir=", ProjectSettings.globalize_path(SEQUENCE_DIR))
	get_tree().quit(0 if assertions_ok else 1)


func _setup_stage() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91afbd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4dfcf")
	environment.ambient_light_energy = 0.85
	environment_node.environment = environment
	add_child(environment_node)
	var floor := StaticBody3D.new()
	floor.name = "StudioFloor"
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(24.0, 0.24, 20.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("6e765d")
	box.material = floor_material
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.12
	floor.add_child(floor_mesh)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = box.size
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.12
	floor.add_child(floor_shape)
	add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	sun.light_energy = 1.25
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2.0, 3.0, 3.5)
	fill.light_color = Color("bcd8ed")
	fill.light_energy = 1.1
	fill.omni_range = 12.0
	add_child(fill)
	camera = Camera3D.new()
	camera.name = "StudioCamera"
	camera.position = Vector3(1.5, 1.75, -3.25)
	camera.fov = 39.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24.0, 20.0)
	hud.add_theme_color_override("font_color", Color("fff2d4"))
	hud.add_theme_color_override("font_shadow_color", Color("182228", 0.92))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_theme_font_size_override("font_size", 21)
	layer.add_child(hud)


func _spawn_staged_zombie() -> void:
	zombie = ZOMBIE_SCENE.instantiate() as ZombieEnemy
	zombie.name = "StageZombie"
	zombie.position = Vector3.ZERO
	add_child(zombie)


func _capture_target_bind_pose() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var model_scene := load(MODEL_SCENE) as PackedScene
	if model_scene == null:
		return
	var bind_pose := model_scene.instantiate()
	bind_pose.name = "BindPoseReference"
	bind_pose.rotation.y = PI
	add_child(bind_pose)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(CAPTURE_DIR.path_join("target_bind_pose.png"))
	get_viewport().get_texture().get_image().save_png(path)
	bind_pose.queue_free()
	await get_tree().process_frame


func _print_limb_hierarchy() -> void:
	var skeleton := zombie._target_skeleton
	for bone_name in [&"Hips", &"Spine", &"Chest", &"LeftUpperArm", &"RightUpperArm", &"LeftUpperLeg", &"RightUpperLeg"]:
		var index := skeleton.find_bone(bone_name)
		var parent := skeleton.get_bone_parent(index)
		print("POLYART_RIG bone=", bone_name, " parent=", skeleton.get_bone_name(parent) if parent >= 0 else &"<root>", " rest=", skeleton.get_bone_global_rest(index).origin)


func _capture_clip(clip_name: StringName) -> void:
	zombie.set_demo_state(clip_name)
	var duration := zombie._animation_length(clip_name)
	var sample_count := maxi(2, int(ceil(duration * FPS)))
	for sample in sample_count:
		hud.text = "ESTÚDIO DE ZUMBIS  /  %s\nQuadro %03d  •  %0.1f s" % [String(clip_name).to_upper(), sequence_frame, float(sample) / FPS]
		await get_tree().create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path(SEQUENCE_DIR.path_join("frame_%03d.png" % sequence_frame))
		var error := image.save_png(path)
		assert(error == OK, "failed to save frame: " + path)
		sequence_frame += 1
	await get_tree().create_timer(0.22).timeout


func _run_ai_assertions() -> void:
	zombie.queue_free()
	await get_tree().process_frame
	var ai := ZOMBIE_SCENE.instantiate() as ZombieEnemy
	ai.name = "AIZombie"
	ai.position = Vector3(-4.5, 0.0, 0.0)
	ai.rotation.y = -PI * 0.5
	add_child(ai)
	var player := Node3D.new()
	player.name = "TestPlayer"
	player.add_to_group("zombie_targets")
	player.position = Vector3(25.0, 0.0, 0.0)
	add_child(player)
	ai.attacked.connect(func(_target: Node3D, _damage: int) -> void: attack_count += 1)
	await _wait_physics(3)
	_assert(ai.state == ZombieEnemy.State.IDLE, "distant player should not trigger alert")
	player.position = Vector3(3.5, 0.0, 0.0)
	await _wait_physics(20)
	_assert(ai.state == ZombieEnemy.State.ALERT, "entering detection radius should trigger scream")
	await _wait_physics(int(ceil(ai._animation_length(&"scream") * 64.0)) + 4)
	_assert(ai.state == ZombieEnemy.State.CHASE, "scream should transition to chase")
	player.position = ai.global_position + Vector3(0.0, 0.0, -1.0)
	await _wait_physics(80)
	_assert(ai.state in [ZombieEnemy.State.ATTACK, ZombieEnemy.State.CHASE], "zombie should approach target and attack")
	_assert(attack_count > 0, "attack animation must apply damage")
	ai.kill()
	await get_tree().process_frame
	_assert(ai.state == ZombieEnemy.State.DEAD and ai.health == 0, "lethal damage should play death state once")
	var prior_attacks := attack_count
	ai.receive_damage(100)
	_assert(attack_count == prior_attacks, "dead zombie must stop interacting")
	ai.queue_free()
	player.queue_free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	assertions_ok = false
	push_error("ZOMBIE_STUDIO_ASSERT: " + message)


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _clear_sequence() -> void:
	var path := ProjectSettings.globalize_path(SEQUENCE_DIR)
	for file_name in DirAccess.get_files_at(path):
		if file_name.begins_with("frame_") and file_name.ends_with(".png"):
			DirAccess.remove_absolute(path.path_join(file_name))
