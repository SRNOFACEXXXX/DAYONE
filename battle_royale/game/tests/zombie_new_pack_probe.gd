extends SceneTree
func _initialize() -> void:
	call_deferred("_probe")
func _probe() -> void:
	var packed := load("res://assets/models/zombies/free_animated_pack/scene.gltf") as PackedScene
	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	for node in root.find_children("*", "", true, false):
		print("NODE ",root.get_path_to(node)," type=",node.get_class())
		if node is AnimationPlayer:
			print("PLAYER_PATH ",root.get_path_to(node)," ANIMS ",(node as AnimationPlayer).get_animation_list())
		if node is Skeleton3D:
			print("SKELETON_PATH ",root.get_path_to(node)," bones=",(node as Skeleton3D).get_bone_count())
	quit()
