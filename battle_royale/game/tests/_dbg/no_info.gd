extends Node
func _pr(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var ab := (n as MeshInstance3D).get_aabb()
		extra = " mesh aabb=%s pos=%s" % [ab.size, (n as Node3D).position]
	if n is Skeleton3D:
		extra = " bones=%d" % (n as Skeleton3D).get_bone_count()
	print("NO ", "  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_pr(c, d + 1)
func _ready() -> void:
	var p: String = Game.test_args.get("glb", "res://assets/models/weapons/fp_bracos.glb")
	var n: Node = (load(p) as PackedScene).instantiate()
	_pr(n, 0)
	get_tree().quit()
