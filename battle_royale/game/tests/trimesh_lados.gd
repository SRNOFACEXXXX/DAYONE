extends Node
## Auditoria: quantos ConcavePolygonShape3D (trimesh) do mundo só colidem pelo lado da normal (backface_collision=false).
## Corpo que chega pelo outro lado ATRAVESSA a parede/cerca (parece "player atravessa muros e cercas").
func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	for i in 60:
		await get_tree().process_frame
	var por_grupo := {}
	var total := 0
	var one_sided := 0
	var vistos := {}
	for n in m.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape is ConcavePolygonShape3D:
			var sh: ConcavePolygonShape3D = cs.shape
			total += 1
			var raiz := String(m.get_path_to(cs)).split("/")
			var chave := "/".join(raiz.slice(0, 2))
			if not por_grupo.has(chave):
				por_grupo[chave] = [0, 0]
			por_grupo[chave][0] += 1
			if not sh.backface_collision:
				one_sided += 1
				if one_sided <= 14:
					print("   um_lado: ", m.get_path_to(cs))
				por_grupo[chave][1] += 1
	print("TRIMESH total=%d de_um_lado=%d" % [total, one_sided])
	for k in por_grupo:
		print("  ", k, " trimesh=", por_grupo[k][0], " de_um_lado=", por_grupo[k][1])
	get_tree().quit()
