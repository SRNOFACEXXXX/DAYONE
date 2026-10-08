extends SceneTree
func _init() -> void:
	for w in ["ak47", "m4", "pistol", "mosin"]:
		var sc: Node = load("res://assets/models/weapons/%s_fp.tscn" % w).instantiate()
		get_root().add_child(sc)
		print("=== ", w)
		_dump(sc, 0)
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var aabb := mi.get_aabb()
		extra = " skin=%s aabb=%s" % [mi.skin != null, aabb]
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		var names := []
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		extra = " bones=" + str(names)
	if n is AnimationPlayer:
		extra = " anims=" + str((n as AnimationPlayer).get_animation_list())
	if n is Node3D:
		extra += " pos=%s" % (n as Node3D).position
	print("  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_dump(c, d + 1)
