extends Node
## Lista o desnível do terreno sob cada casa do pacote (saia de concreto = hmax - hmin) e a altura do degrau da porta.
func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var linhas: Array = []
	for c in get_tree().get_nodes_in_group("casa_pacote"):
		var n := c as Node3D
		var hmax := -INF
		var hmin := INF
		for a in [-6.0, 0.0, 6.0]:
			for b in [-6.0, 0.0, 6.0]:
				var p := Vector2(a, b).rotated(-n.rotation.y)
				var h: float = m.ilha.terrain.height_world(n.global_position.x + p.x, n.global_position.z + p.y)
				hmax = maxf(hmax, h)
				hmin = minf(hmin, h)
		var porta := n.to_global(Vector3(-2.05, 0, 7.0))
		var hp: float = m.ilha.terrain.height_world(porta.x, porta.z)
		linhas.append([hmax - hmin, hmax - hp, n.name, n.global_position, n.rotation.y])
	linhas.sort_custom(func(a, b): return a[0] > b[0])
	var n_ruim := 0
	for l in linhas:
		if l[0] > 0.9 or l[1] > 0.5:
			n_ruim += 1
		print("CASA desnivel=%.2f degrau_porta=%.2f %s %s" % [l[0], l[1], l[2], l[3]])
	print("CASAS total=%d ruins=%d" % [linhas.size(), n_ruim])
	get_tree().quit()
