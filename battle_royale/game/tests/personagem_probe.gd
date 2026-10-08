extends SceneTree
## Sonda: ossos, animações e malhas de um glb (uso: -s res://tests/personagem_probe.gd -- res://...glb)
func _init() -> void:
	var p := OS.get_cmdline_user_args()[0]
	var cena: Node3D = load(p).instantiate()
	root.add_child(cena)
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var s := ""
	for i in sk.get_bone_count():
		s += "%d:%s(%d) " % [i, sk.get_bone_name(i), sk.get_bone_parent(i)]
	print("SK_PATH ", cena.get_path_to(sk), " xform ", sk.global_transform, " scale_root ", cena.scale)
	print("BONES ", s)
	var hi := sk.find_bone("Head")
	var hr := sk.find_bone("RightHand")
	if hi >= 0:
		print("HEAD_REST ", sk.get_bone_global_rest(hi).origin, " RHAND ", sk.get_bone_global_rest(hr).origin if hr >= 0 else Vector3.ZERO)
	for bn in ["RightHand", "RightHandProp", "RightHandMiddle1", "LeftHand", "LeftHandProp", "LeftHandMiddle1"]:
		var bi := sk.find_bone(bn)
		print("REST ", bn, " ", sk.get_bone_global_rest(bi).origin, " local ", sk.get_bone_rest(bi).origin)
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	var a := ""
	for n in ap.get_animation_list():
		var an := ap.get_animation(n)
		a += "%s[%.2fs,%d] " % [n, an.length, an.get_track_count()]
	print("ANIMS ", a)
	var an0 := ap.get_animation(ap.get_animation_list()[0])
	var tr := ""
	for i in mini(an0.get_track_count(), 6):
		tr += str(an0.track_get_path(i)) + " "
	print("TRACKS0 ", tr)
	var m := ""
	for mi in cena.find_children("*", "MeshInstance3D", true, false):
		m += mi.name + " "
	print("MESHES ", m)
	quit()
