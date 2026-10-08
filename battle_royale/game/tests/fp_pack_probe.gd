extends SceneTree
## Imprime pose do osso da câmera e da arma (Main_j) no Idle, relativo à câmera, e AABB das malhas no espaço do Main_j.
func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://assets/models/fp/m4_lp.glb"
	var cena: Node3D = load(path).instantiate()
	root.add_child(cena)
	await process_frame
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	var idle := ""
	for a in ap.get_animation_list():
		if "idle" in String(a).to_lower():
			idle = a
	ap.play(idle)
	ap.seek(0.0, true)
	await process_frame
	var cb := -1
	var mb := -1
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if "camera" in n.to_lower(): cb = i
		if n.begins_with("Main"): mb = i
	var cam := sk.get_bone_global_pose(cb)
	var main := sk.get_bone_global_pose(mb)
	print("SKEL_XF ", sk.global_transform)
	print("CAM ", cam)
	print("MAIN ", main)
	print("MAIN_IN_CAM ", cam.affine_inverse() * main)
	for mi in cena.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var arrs := m.mesh.surface_get_arrays(0)
		print("MESH ", m.name, " surf=", m.mesh.get_surface_count(), " aabb=", m.get_aabb(), " skin=", m.skin != null)
	quit()
