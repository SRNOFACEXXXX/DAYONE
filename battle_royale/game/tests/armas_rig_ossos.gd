extends SceneTree
## Ossos Mag*/mãos no espaço do osso Main ao longo da animação de recarga (cm). Uso: -s ... -- <rig.glb> [anim]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cena: Node3D = load(args[0]).instantiate()
	root.add_child(cena)
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	print("ANIMS ", ap.get_animation_list())
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		print("MESH ", m.name)
	var alvo := args[1] if args.size() > 1 else "reload"
	var nome := ""
	for a in ap.get_animation_list():
		var low := String(a).to_lower()
		if low.ends_with(alvo) or ("|" + alvo) in low:
			nome = a
	if nome == "":
		for a in ap.get_animation_list():
			if alvo in String(a).to_lower() and not "empty" in String(a).to_lower():
				nome = a
	print("USANDO ", nome)
	ap.play(nome)
	var L := ap.current_animation_length
	var mb := sk.find_bone("Main_j")
	for f in [0.0, 0.15, 0.25, 0.35, 0.5, 0.6, 0.75, 0.9]:
		ap.seek(f * L, true)
		await process_frame
		var main := sk.get_bone_global_pose(mb)
		var linha := "T %.2f" % f
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if n.begins_with("Mag") or n == "LeftHand" or n == "LeftHandMiddle1" or n == "RightHand":
				linha += " | %s %s" % [n, str((main.affine_inverse() * sk.get_bone_global_pose(i).origin).snappedf(0.1))]
		print(linha)
	quit()
