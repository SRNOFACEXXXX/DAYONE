extends SceneTree
func _init() -> void:
	var n: Node3D = load(OS.get_cmdline_user_args()[0]).instantiate()
	root.add_child(n)
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		print("AABB ", mi.name, " ", mi.global_transform * mi.get_aabb())
	quit()
