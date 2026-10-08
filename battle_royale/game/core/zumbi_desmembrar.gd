extends SkeletonModifier3D
## Some com membros do zumbi (cabeça estourada, braço/perna arrancados): roda DEPOIS da cópia de pose (zombie_pose_copy) e
## encolhe o osso (e, por herança, os filhos) a quase zero. Os pedaços que voam são de fx/pedacos.gd.

var ocultos: PackedInt32Array = []


func ocultar(osso: int) -> void:
	if osso >= 0 and not ocultos.has(osso):
		ocultos.append(osso)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in ocultos:
		var p := sk.get_bone_global_pose(i)
		p.basis = p.basis.scaled_local(Vector3(0.001, 0.001, 0.001))
		sk.set_bone_global_pose(i, p)
