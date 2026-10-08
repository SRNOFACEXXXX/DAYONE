extends SceneTree
func _init() -> void:
	var cena: Node3D = load(OS.get_cmdline_user_args()[0]).instantiate()
	root.add_child(cena)
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var s := ""
	for i in sk.get_bone_count():
		if "Left" in sk.get_bone_name(i) and not ("Thumb" in sk.get_bone_name(i) or "Index" in sk.get_bone_name(i) or "Ring" in sk.get_bone_name(i) or "Pinky" in sk.get_bone_name(i) or "Middle" in sk.get_bone_name(i)):
			s += sk.get_bone_name(i) + "(" + str(sk.get_bone_parent(i)) + ") "
	print("BONES ", s)
	quit()
