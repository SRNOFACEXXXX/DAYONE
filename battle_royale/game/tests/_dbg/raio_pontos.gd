extends Node
const PONTOS := [Vector2(-67, 36), Vector2(-64, 36), Vector2(-61, 36), Vector2(-70, 36)]
func _ready() -> void:
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	for i in 5:
		await get_tree().physics_frame
	var ss := scene.get_world_3d().direct_space_state
	var t: IlhaTerrain = scene.terrain
	for p: Vector2 in PONTOS:
		var linha := []
		for h: float in [0.4, 0.9, 1.3]:
			var y := t.height_world(p.x, p.y) + h
			var res := []
			for d: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0)]:
				var o := Vector3(p.x, y, p.y) - d * 2.0
				var hit := ss.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 4.0, 1))
				res.append(("%.2f" % o.distance_to(hit.position)) if not hit.is_empty() else "-")
			linha.append("h%.1f=%s" % [h, str(res)])
		var sp := SphereShape3D.new(); sp.radius = 1.0
		var pq := PhysicsShapeQueryParameters3D.new(); pq.shape = sp; pq.collision_mask = 1
		pq.transform = Transform3D(Basis(), Vector3(p.x, t.height_world(p.x, p.y) + 1.0, p.y))
		print("PONTO (%.0f,%.0f) %s formas_perto=%d" % [p.x, p.y, " ".join(linha), ss.intersect_shape(pq, 32).size()])
	var det = scene.get_node("Detalhes")
	print("PONTO formas_detalhes=%d" % det._formas.size())
	get_tree().quit()
