extends SceneTree
func _init() -> void:
	for w in ["m107", "m4", "ak47", "uzi"]:
		var n: Node3D = load("res://assets/models/weapons/wf/%s.glb" % w).instantiate()
		root.add_child(n)
		for g in n.find_children("*", "MeshInstance3D", true, false):
			var mi := g as MeshInstance3D
			print(w, " ", mi.name, " surf=", mi.mesh.get_surface_count(), " ", mi.get_aabb())
	quit()
