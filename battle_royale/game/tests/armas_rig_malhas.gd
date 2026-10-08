extends SceneTree
## AABB de cada malha do rig no espaço do osso Main (cm), pose Idle t=0 (skin manual pelo 1º osso de cada vértice).
func _init() -> void:
	var cena: Node3D = load(OS.get_cmdline_user_args()[0]).instantiate()
	root.add_child(cena)
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ap.get_animation_list():
		if "|idle|" in String(a).to_lower():
			ap.play(a)
	ap.seek(0.0, true)
	await process_frame
	var inv := sk.get_bone_global_pose(sk.find_bone("Main_j")).affine_inverse()
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var skin := mi.skin
		if skin == null:
			continue
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs = arr[Mesh.ARRAY_BONES]
			var nb: int = bs.size() / maxi(vs.size(), 1)
			for i in vs.size():
				var bind_i: int = bs[i * nb]
				var bone := skin.get_bind_bone(bind_i)
				if bone < 0:
					bone = sk.find_bone(skin.get_bind_name(bind_i))
				var p := inv * sk.get_bone_global_pose(bone) * skin.get_bind_pose(bind_i) * vs[i]
				lo = lo.min(p)
				hi = hi.max(p)
		print("AABB ", mi.name, " lo=", lo.snappedf(0.1), " hi=", hi.snappedf(0.1))
	quit()
