extends SceneTree
## Sonda: materiais e vértices das malhas do personagem (dayone) x soldado.
func _init() -> void:
	for p in ["res://assets/models/atualizacao/player/dayone_base.glb", "res://assets/models/characters/soldado.glb"]:
		var cena: Node3D = load(p).instantiate()
		var tot := 0
		for mi in cena.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			var v := 0
			var mats := ""
			for si in m.get_surface_count():
				v += (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var mat := m.surface_get_material(si)
				if mat is BaseMaterial3D:
					var b := mat as BaseMaterial3D
					mats += "[%s tr=%d cull=%d sh=%d tex=%s np=%s] " % [mat.resource_name, b.transparency, b.cull_mode, b.shading_mode, str(b.albedo_texture.get_size()) if b.albedo_texture else "-", str(b.next_pass != null)]
				else:
					mats += "[%s] " % [mat]
			tot += v
			if mi.name in ["Body_010", "Outerwear_036", "Pants_010", "Male_emotion_usual_001", "Hairstyle_male_010", "Gloves_014", "Shoe_Slippers_005"] or p.ends_with("soldado.glb"):
				print(p.get_file(), " ", mi.name, " v=", v, " surf=", m.get_surface_count(), " ", mats)
		print(p.get_file(), " TOTAL v=", tot)
		cena.free()
	quit()
