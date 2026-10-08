extends SceneTree
## Posição dos ossos das mãos (RightHand, LeftHand) no espaço do osso Main no Idle (cm).
func _init() -> void:
	var cena: Node3D = load(OS.get_cmdline_user_args()[0]).instantiate()
	root.add_child(cena)
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ap.get_animation_list():
		if "idle" in String(a).to_lower():
			ap.play(a)
	ap.seek(0.0, true)
	await process_frame
	var mb := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i) == "Main_j":
			mb = i
	var main := sk.get_bone_global_pose(mb)
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if (n.contains("Hand") and not n.contains("Thumb") and not n.contains("Index") and not n.contains("Ring") and not n.contains("Pinky") and not n.contains("Middle2") and not n.contains("Middle3") and not n.contains("Middle4")) or n.begins_with("Mag1"):
			print("OSSO ", n, " ", main.affine_inverse() * sk.get_bone_global_pose(i).origin)
	quit()
