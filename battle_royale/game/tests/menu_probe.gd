extends Node
## Inspeciona o Doberman do pack (apoio a ui/menu_stage.gd).
func _ready() -> void:
	var n: Node3D = (load("res://assets/models/atualizacao/menu/Doberman.fbx") as PackedScene).instantiate()
	add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		print("PROBE mesh ", m.name, " aabb=", m.get_aabb(), " gscale=", m.global_transform.basis.get_scale(), " surf=", m.mesh.get_surface_count(), " mat=", m.mesh.surface_get_material(0).resource_name if m.mesh.surface_get_material(0) else "-")
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		print("PROBE anims ", (ap as AnimationPlayer).get_animation_list())
	print("PROBE root scale ", n.scale, " children ", n.get_children())
	get_tree().quit()
