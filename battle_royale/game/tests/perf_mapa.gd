extends Node
## Custo por parte do mapa na partida (spawn da Vila, arma na mão): mede 2 s com tudo e com cada filho da ilha escondido.
func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 90:
		await get_tree().process_frame
	await _medir(m, "tudo")
	for v in get_tree().root.find_children("*", "SubViewport", true, false):
		print("SUBVIEWPORT ", v.get_path(), " update=", (v as SubViewport).render_target_update_mode, " size=", (v as SubViewport).size, " visivel_pai=", (v.get_parent() as CanvasItem).is_visible_in_tree() if v.get_parent() is CanvasItem else "?")
		(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	await _medir(m, "sem_subviewports")
	if Game.test_args.has("partida"):
		var pc := m.local_player.controller as PlayerController
		var alvos := {"HUD": m.hud, "Caixas": m.br_loot_root, "Viewmodel": pc.viewmodel, "Capim": m.ilha.get_node_or_null("Capim"),
			"Vegetacao": m.ilha.get_node_or_null("Vegetacao"), "Detalhes": m.ilha.get_node_or_null("Detalhes"), "Blockout": m.ilha.get_node_or_null("Blockout")}
		for k in alvos:
			var n = alvos[k]
			if n == null:
				continue
			n.visible = false
			await _medir(m, "sem_" + k)
			n.visible = true
		get_tree().quit()
		return
	if Game.test_args.has("so_cpu"):
		for c in m.get_children() + m.ilha.get_children():
			if c == m.ilha:
				continue
			var antes := c.process_mode
			c.process_mode = Node.PROCESS_MODE_DISABLED
			await _medir(m, "sem_proc_" + String(c.name))
			c.process_mode = antes
		get_tree().quit()
		return
	for c in m.ilha.get_children():
		if c is Node3D and (c as Node3D).visible:
			(c as Node3D).visible = false
			await _medir(m, "sem_" + String(c.name))
			(c as Node3D).visible = true
	get_tree().quit()


func _medir(m: Node, nome: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var n := 0
	while Time.get_ticks_usec() - t0 < 1500000:
		await get_tree().process_frame
		n += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("CPU %s process=%.2f ms physics=%.2f ms objetos=%d nos=%d fisica_ativos=%d" % [nome, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	print("MAPA %-24s %5.1f ms (%3.0f fps) draws=%d prims=%d" % [nome, ms, 1000.0 / ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
