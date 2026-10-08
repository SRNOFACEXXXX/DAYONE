extends Node3D

const ANIMATION_SCENE := "res://assets/models/zombies/free_animated_pack/scene.gltf"
const OUT := "res://../raw/free_zombie_reference/walk_compare"

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
	box.size = Vector3(8, 0.2, 6)
	floor.mesh = box
	floor.position.y = -0.1
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.7, 5.4)
	camera.fov = 55
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	var source_root := (load(ANIMATION_SCENE) as PackedScene).instantiate() as Node3D
	source_root.name = "NativeAnimationSource"
	source_root.position.x = -1.0
	source_root.rotation.y = PI
	source_root.scale = Vector3.ONE * 0.45
	add_child(source_root)
	var source_anim := source_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var target := ZombieEnemy.new()
	target.position.x = 1.0
	target.set("_variant_index", 0)
	target.set("_demo_locked", true)
	add_child(target)
	await get_tree().process_frame
	var target_anim := target.get("_animation_player") as AnimationPlayer
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color.WHITE)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(label)
	assert(source_anim and source_anim.has_animation(&"WALK"))
	assert(target_anim and target_anim.has_animation(&"walk"))
	var duration := target_anim.get_animation(&"walk").length
	print("WALK_COMPARE_DURATION ", duration, " source=", source_anim.get_animation(&"WALK").length)
	for frame_index in 60:
		var time := duration * float(frame_index) / 60.0
		source_anim.play(&"WALK")
		source_anim.seek(time, true)
		target_anim.play(&"walk")
		target_anim.seek(time, true)
		label.text = "ORIGINAL PACK (left)                 POLYART RETARGET (right)   %02d/60" % (frame_index + 1)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image:
			image.save_png(ProjectSettings.globalize_path(OUT.path_join("frame_%03d.png" % frame_index)))
	print("WALK_COMPARE_CAPTURED_60 ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()
