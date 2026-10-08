extends Node
func _ready() -> void:
	Game.test_mode = true
	Game.test_args["audit_props"] = true
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	for i in 20:
		await get_tree().physics_frame
	print("DBG layer=%d mask=%d estado=%s ext=%s frozen=%s locked? alive=%s mode=%d" % [s.collision_layer, s.collision_mask, m.estado.get(s), s.external_motion, s.frozen, s.alive, s.motion_mode])
	for c in s.get_children():
		if c is CollisionShape3D:
			print("DBG shape ", c.name, " disabled=", c.disabled, " ", c.shape)
	var det = m.ilha.get_node("Detalhes")
	var a = null
	for x in det.auditoria:
		if x.tipo == "barril":
			a = x
			break
	var c: Vector3 = a.pos
	print('DBG terreno=', m.ilha.terrain.height_world(c.x, c.z), ' spawn=', s.global_position)
	var dd := m.get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(c + Vector3(2, 10, 0), c + Vector3(2, -20, 0), 1)
	print('DBG raio_baixo=', dd.intersect_ray(rq))
	s.global_position = c + Vector3(2.0, 0.2, 0)
	print('DBG logo apos set y=', s.global_position.y)
	for i in 6:
		print('DBG f%d y=%.2f vy=%.2f floor=%s' % [i, s.global_position.y, s.velocity.y, s.is_on_floor()])
		await get_tree().physics_frame
	var col := KinematicCollision3D.new()
	print("DBG test_move=", s.test_move(s.global_transform, Vector3(-4, 0, 0), col), " pos=", s.global_position, " barril=", c)
	var d := m.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(c + Vector3(3, 0.6, 0), c + Vector3(-3, 0.6, 0), 1)
	print("DBG ray=", d.intersect_ray(q))
	get_tree().quit()
