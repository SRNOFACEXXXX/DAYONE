extends Node
func _ready() -> void:
	Game.test_args["audit_props"] = true
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	for i in 5:
		await get_tree().physics_frame
	var ss := scene.get_world_3d().direct_space_state
	var t: IlhaTerrain = scene.terrain
	var veg = scene.get_node("Vegetacao")
	var n := 0
	for a in veg.auditoria:
		var tipo := String(a.tipo)
		if not tipo.contains("|"):
			continue
		n += 1
		if n > 12:
			break
		var p: Vector3 = a.pos
		var linha := []
		for h in [0.5, 1.0, 1.5]:
			var acertos := 0
			var dmin := 99.0
			for k in 8:
				var ang := TAU * k / 8.0
				var d := Vector3(sin(ang), 0, cos(ang))
				var o := Vector3(p.x, t.height_world(p.x, p.z) + h, p.z) - d * 4.0
				var q := PhysicsRayQueryParameters3D.create(o, o + d * 8.0, 1)
				var hit := ss.intersect_ray(q)
				if not hit.is_empty():
					acertos += 1
					dmin = minf(dmin, Vector2(hit.position.x - p.x, hit.position.z - p.z).length())
			linha.append("h%.1f:%d/8 dist_centro=%.2f" % [h, acertos, dmin])
		print("TRONCO_RAIO %s pos=(%.0f,%.0f) %s" % [tipo, p.x, p.z, " ".join(linha)])
	get_tree().quit()
