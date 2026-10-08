extends Node3D

const OUT := "res://../raw/free_zombie_reference/godot_captures"
const WALK_SEQUENCE := "res://../raw/free_zombie_reference/zombie_walk_60"
const CLIPS := [&"idle", &"walk", &"run", &"attack", &"neck_bite", &"scream", &"death"]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8db3c4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.9
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var floor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.2, 6)
	floor.mesh = box
	floor.position.y = -0.1
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(1.55, 1.2, 2.05)
	add_child(camera)
	camera.look_at(Vector3(0, 0.82, 0))
	camera.current = true
	var actor := ZombieEnemy.new()
	actor.set("_variant_index", 0)
	actor.set("_demo_locked", true)
	add_child(actor)
	await get_tree().process_frame
	var anim := actor.get("_animation_player") as AnimationPlayer
	var target_skeleton := actor.get("_target_skeleton") as Skeleton3D
	print("TEST_ACTOR_TRANSFORM ", actor.global_transform)
	print("TEST_VISUAL_TRANSFORM ", (actor.get_node("VisualRoot") as Node3D).global_transform)
	print("TEST_TARGET_TRANSFORM ", target_skeleton.global_transform if target_skeleton else "NONE")
	if target_skeleton:
		for mesh_node in target_skeleton.find_children("*", "MeshInstance3D", true, false):
			print("TEST_TARGET_MESH ", mesh_node.name, " visible=", mesh_node.visible, " transform=", mesh_node.global_transform, " aabb=", mesh_node.get_aabb())
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(label)
	if anim == null or target_skeleton == null:
		push_error("Zombie preview could not build Polyart rig")
		get_tree().quit(2)
		return
	print("TEST_ZOMBIE_CLIPS ", anim.get_animation_list())
	print("TEST_TARGET_BONES ", target_skeleton.get_bone_count())
	for clip in CLIPS:
		if not anim.has_animation(clip):
			push_error("Missing preview clip: " + String(clip))
			continue
		var clip_animation := anim.get_animation(clip)
		for sample in 3:
			var sample_time := minf(clip_animation.length * (0.18 + sample * 0.28), clip_animation.length - 0.01)
			anim.play(clip)
			anim.seek(sample_time, true)
			await get_tree().process_frame
			await get_tree().process_frame
			label.text = String(clip) + "  %.2fs" % sample_time
			var tracked := []
			for bone_name in [&"Head", &"LeftHand", &"RightHand", &"LeftFoot", &"RightFoot"]:
				var index := target_skeleton.find_bone(bone_name)
				if index >= 0:
					tracked.append(Vector3(target_skeleton.get_bone_global_pose(index).origin).snapped(Vector3(0.01, 0.01, 0.01)))
			print("TEST_POSE ", clip, " frame=", sample, " ", tracked)
			if DisplayServer.get_name() != "headless":
				var image := get_viewport().get_texture().get_image()
				if image != null:
					image.save_png(ProjectSettings.globalize_path(OUT.path_join("%s_%02d.png" % [String(clip), sample])))
	for variant_index in range(1, 10):
		var variant_actor := ZombieEnemy.new()
		variant_actor.set("_variant_index", variant_index)
		add_child(variant_actor)
		await get_tree().process_frame
		var variant_skeleton := variant_actor.get("_target_skeleton") as Skeleton3D
		var variant_meshes := variant_skeleton.find_children("*", "MeshInstance3D", true, false) if variant_skeleton else []
		if variant_skeleton == null or variant_meshes.is_empty():
			push_error("Polyart variant %d failed to attach to animation rig" % variant_index)
		else:
			print("TEST_VARIANT_OK ", variant_index, " bones=", variant_skeleton.get_bone_count(), " meshes=", variant_meshes.size(), " scale=", variant_skeleton.global_basis.get_scale())
		variant_actor.queue_free()
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WALK_SEQUENCE))
		var walk_animation := anim.get_animation(&"walk")
		print("TEST_WALK_60_BEGIN duration=", walk_animation.length)
		for frame_index in 60:
			anim.play(&"walk")
			anim.seek(walk_animation.length * float(frame_index) / 60.0, true)
			label.text = "WALK  %02d / 60  •  %.2f s" % [frame_index + 1, walk_animation.length * float(frame_index) / 60.0]
			await RenderingServer.frame_post_draw
			var walk_image := get_viewport().get_texture().get_image()
			if walk_image != null:
				var path := ProjectSettings.globalize_path(WALK_SEQUENCE.path_join("frame_%03d.png" % frame_index))
				walk_image.save_png(path)
		print("TEST_WALK_60_DONE ", ProjectSettings.globalize_path(WALK_SEQUENCE))
	print("POLYART_LIVE_RETARGET_PREVIEW_DONE")
	get_tree().quit()
