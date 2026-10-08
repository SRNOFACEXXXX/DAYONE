extends SceneTree
## Perfil de um modelo wf (m; -Z boca): malhas, AABB e, por fatia de 1 cm em z, min/max de y e centro x.
## Uso: godot --headless --path game -s res://tests/armas_rig_perfil.gd -- res://assets/models/weapons/wf/ak47.glb
func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var cena: Node3D = load(path).instantiate()
	root.add_child(cena)
	await process_frame
	var pts: Array[Vector3] = []
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := cena.global_transform.affine_inverse() * mi.global_transform
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var usados := {}
			for i in idx:
				usados[i] = true
			for i in vs.size():
				if idx.size() > 0 and not usados.has(i):
					continue
				var p := t * vs[i]
				pts.append(p)
				lo = lo.min(p)
				hi = hi.max(p)
		print("MALHA ", cena.get_path_to(mi), " lo=", lo, " hi=", hi)
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	print("TOTAL lo=", lo, " hi=", hi)
	var z := lo.z
	while z < hi.z:
		var ymn := 1e9
		var ymx := -1e9
		var xmn := 1e9
		var xmx := -1e9
		for p in pts:
			if p.z >= z and p.z < z + 0.01:
				ymn = minf(ymn, p.y); ymx = maxf(ymx, p.y); xmn = minf(xmn, p.x); xmx = maxf(xmx, p.x)
		if ymx > -1e8:
			print("Z %6.3f  y %6.3f..%6.3f  x %6.3f..%6.3f" % [z, ymn, ymx, xmn, xmx])
		z += 0.01
	quit()
