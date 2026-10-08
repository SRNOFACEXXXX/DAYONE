extends Node3D
## Root of a weapon model scene. Palette textures must be sampled without blending between swatches.


func _ready() -> void:
	_fix(self)


func _fix(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in (mi.mesh.get_surface_count() if mi.mesh else 0):
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				mi.set_surface_override_material(i, d)
	for c in n.get_children():
		_fix(c)
