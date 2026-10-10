extends Node
func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["sem_stamina"] = "1"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	for i in 10:
		await get_tree().physics_frame
	var p: Soldier = m.local_player
	var terr: IlhaTerrain = m.ilha.terrain
	var ss := m.get_world_3d().direct_space_state
	for alvo: Vector3 in [Vector3(284, 0, -358), Vector3(310, 0, -222), Vector3(100, 0, -530)]:
		alvo.y = terr.height_world(alvo.x, alvo.z)
		# o que existe ali (raio vertical de cima)
		var sp := SphereShape3D.new(); sp.radius = 0.5
		var pq := PhysicsShapeQueryParameters3D.new(); pq.shape = sp; pq.collision_mask = 0xFFFFFFFF
		pq.transform = Transform3D(Basis(), alvo + Vector3.UP * 1.0)
		var res := ss.intersect_shape(pq, 8)
		var nomes := []
		for r in res:
			var co: Object = r.collider
			nomes.append("%s(layer=%d)" % [co.name if co is Node else str(co), co.collision_layer if "collision_layer" in co else -1])
		print("DBG alvo=%s colisores=%s" % [alvo, nomes])
		for ang: float in [0.0, PI * 0.5]:
			var dir := Vector3(sin(ang), 0, cos(ang))
			var ini := alvo - dir * 3.0
			ini.y = terr.height_world(ini.x, ini.z)
			p.global_position = ini + Vector3.UP * 0.1
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			Input.action_press("move_forward")
			for i in 90:
				p.yaw = atan2(-dir.x, -dir.z)
				await get_tree().physics_frame
				if i % 10 == 0:
					var cols := []
					for k in p.get_slide_collision_count():
						var c := p.get_slide_collision(k)
						cols.append(str((c.get_collider() as Node).name if c.get_collider() is Node else "?"))
					print("DBG  i=%d pos=%s avanco=%.2f vel=%s mantle=%s cols=%s" % [i, p.global_position.snapped(Vector3.ONE*0.01), (p.global_position - ini).dot(dir), p.velocity.snapped(Vector3.ONE*0.1), str(p.get("_mantle_ativo") if "_mantle_ativo" in p else "-"), cols])
			Input.action_release("move_forward")
	get_tree().quit()
