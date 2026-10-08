extends Node
## Diagnóstico de custo por categoria na partida BR (no chão, no adro da Capela, com bots):
## mede 2 s de base e com cada categoria escondida. Uso: --chao --bots=11


func _ready() -> void:
	Game.test_mode = true
	BodyModel.SOLDIER_FOR_ALL = Game.test_args.get("soldado", "1") == "1"   # --soldado=0 compara com os modelos antigos por time
	DisplayServer.window_set_size(Vector2i(1024, 768))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	s.health = 1000000
	for b: Soldier in m.soldiers:
		b.health = 1000000
		if b != s:   # bots espalhados em volta, a 20–60 m (como num POI disputado)
			var i := m.soldiers.find(b)
			b.global_position = s.global_position + Vector3(cos(i * 0.9) * (20 + i * 4), 2.0, sin(i * 0.9) * (20 + i * 4))
	s.yaw = deg_to_rad(90.0)
	for i in 120:
		await get_tree().process_frame
	var bots: Array = m.soldiers.filter(func(b): return b != s)
	for b: Soldier in bots:
		b.controller.set_physics_process(false)
		b.in_fire = false
		b.in_move = Vector2.ZERO
	await _medir("bots_parados")
	m.hud.visible = false
	await _medir("parados_sem_hud")
	m.hud.visible = true
	m.hud.get_node(".").set_process(false)
	await _medir("hud_sem_process")
	m.hud.set_process(true)
	for c in m.hud.find_children("*", "Control", true, false):
		if c is Radar:
			c.visible = false
	await _medir("sem_radar")
	for c in m.hud.find_children("*", "Control", true, false):
		if c is Radar:
			c.visible = true
	for b: Soldier in bots:
		b.set_physics_process(false)
	await _medir("sem_fisica_bot")
	for b: Soldier in bots:
		b.set_physics_process(true)
		b.body_model.set_process(false) if b.body_model else null
	await _medir("sem_corpo_proc")
	for b: Soldier in bots:
		if b.body_model:
			b.body_model.set_process(true)
		b.visible = false
	await _medir("bots_ocultos")
	for b: Soldier in bots:
		b.visible = true
		b.controller.set_physics_process(true)
	await _medir("bots_ativos")
	m.hud.visible = false
	await _medir("ativos_sem_hud")
	print("FILHOS ilha: ", m.ilha.get_children().map(func(n): return n.name))
	get_tree().quit()


func _medir(nome: String) -> void:
	for i in 20:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var n := 0
	while Time.get_ticks_usec() - t0 < 2000000:
		await get_tree().process_frame
		n += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("CUSTO %-16s %5.1f ms (%3.0f fps) draws=%d" % [nome, ms, 1000.0 / ms, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
