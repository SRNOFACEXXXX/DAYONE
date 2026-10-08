extends SceneTree
func _init() -> void:
	for w in ["ak47", "m4", "pistol", "pistol_ct"]:
		var sc: Node = load("res://assets/models/weapons/%s_fp.tscn" % w).instantiate()
		var arma := sc.find_child("Arma", true, false) as MeshInstance3D
		var lo := {}
		var hi := {}
		var wx := {}
		var vs: Array = []
		for m in [arma] + arma.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var t := arma.global_transform.affine_inverse() * mi.global_transform if mi != arma else Transform3D.IDENTITY
			for s in mi.mesh.get_surface_count():
				for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					vs.append(t * v)
		for v: Vector3 in vs:
			var k := int(floor(v.z * 50.0))  # fatias de 2 cm
			lo[k] = minf(lo.get(k, 9.0), v.y)
			hi[k] = maxf(hi.get(k, -9.0), v.y)
			wx[k] = maxf(wx.get(k, 0.0), absf(v.x))
		var ks := lo.keys(); ks.sort()
		print("=== ", w, " (z cm: y_min..y_max, meia largura x)")
		var l := []
		for k in ks:
			l.append("%d:%.0f..%.0f|%.0f" % [k * 2, lo[k] * 100, hi[k] * 100, wx[k] * 100])
		print(" ".join(l))
		sc.free()
	quit()
