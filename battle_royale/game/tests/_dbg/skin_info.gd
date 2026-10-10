extends Node3D
func _ready() -> void:
	var n: Node3D = load("res://assets/models/animais/cervo.glb").instantiate()
	add_child(n)
	var sk := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi := n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	print("SKIN raiz_node=%s sk_pos=%s sk_xf=%s mi_xf=%s" % [n.name, sk.position, sk.transform, mi.transform])
	var skin := mi.skin
	for i in skin.get_bind_count():
		var nome := skin.get_bind_name(i)
		var bi := sk.find_bone(nome)
		var rest_g := sk.get_bone_global_rest(bi)
		var bind_inv := skin.get_bind_pose(i).affine_inverse()
		print("SKIN %s rest_global=%s bind_inverso=%s" % [nome, rest_g.origin.snapped(Vector3.ONE * 0.01), bind_inv.origin.snapped(Vector3.ONE * 0.01)])
	get_tree().quit()
