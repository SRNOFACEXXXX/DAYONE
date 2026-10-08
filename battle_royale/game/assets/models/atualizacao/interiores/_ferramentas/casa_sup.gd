extends SceneTree
func _init() -> void:
	var sc: Node3D = (load("res://assets/models/cenario/casas/casa_demo.glb") as PackedScene).instantiate()
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var no: Node = m
		while no != null and no != sc:
			xf = (no as Node3D).transform * xf
			no = no.get_parent()
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var up := 0.0; var dn := 0.0; var vt := 0.0
			for t in range(0, ix.size() - 2, 3):
				var a := xf * vs[ix[t]]; var b := xf * vs[ix[t+1]]; var c := xf * vs[ix[t+2]]
				var cr := (b - a).cross(c - a)
				var ar := cr.length() * 0.5
				var ny := cr.normalized().y
				if ny > 0.6: up += ar
				elif ny < -0.6: dn += ar
				else: vt += ar
			var mat := m.mesh.surface_get_material(si)
			print("%s | %s | up=%.1f dn=%.1f vert=%.1f | v=%d aabb=%s" % [m.name, mat.resource_name if mat else "-", up, dn, vt, vs.size(), str(xf * m.mesh.get_aabb())])
	quit()
