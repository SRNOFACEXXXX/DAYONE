extends SceneTree
func _init() -> void:
	var n: Node = load("res://assets/models/weapons/wf/ak47_fp.tscn").instantiate()
	root.add_child(n)
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			print("MAT ", mi.get_path(), " ", i, " ", m.albedo_color if m else "-", " tex=", m.albedo_texture if m else "-", " emis=", m.emission_enabled if m else "-", " ", m.emission if m else "")
	quit()
