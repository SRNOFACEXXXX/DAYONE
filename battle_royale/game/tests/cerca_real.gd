extends Node
## Cerca de ripas do mapa: acha um segmento "cenario/natureza/cerca_madeira" real, anda até ele e tenta atravessar/pular.
func _ready() -> void:
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	var det := m.ilha.get_node("Detalhes")
	var alvo: Node3D = null
	for c in det.get_children():
		if c is Node3D and c.name.contains("cerca_madeira") and m.ilha.terrain.height_world(c.global_position.x, c.global_position.z) > 3.0:
			alvo = c
			break
	assert(alvo != null, "sem cerca")
	var b := alvo.global_transform.basis
	var normal := b.z.normalized()           # perpendicular ao comprimento (+X local)
	var de := alvo.global_position + normal * 3.0 + b.x * 1.0
	s.global_position = Vector3(de.x, m.ilha.terrain.height_world(de.x, de.z) + 0.2, de.z)
	s.yaw = atan2(normal.x, normal.z)        # olhando para a cerca (-normal)
	s.pitch = 0.0
	s.reset_physics_interpolation()
	await get_tree().create_timer(0.8).timeout
	var antes := s.global_position
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_msec()
	var atravessou := false
	while Time.get_ticks_msec() - t0 < 4000:
		if int((Time.get_ticks_msec() - t0) / 250) % 2 == 0:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await get_tree().physics_frame
		if (s.global_position - alvo.global_position).dot(normal) < -1.2:
			atravessou = true
			break
	Input.action_release("move_forward")
	Input.action_release("jump")
	print("CERCA %s atravessou=%s em %.1f s" % [alvo.name, atravessou, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0 if atravessou else 1)
