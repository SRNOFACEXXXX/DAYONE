extends Node
## Zona do BR acelerada (time_scale 25): imprime raio/centro/dano/HP ao longo da partida e fotografa a parede.
## Uso: --chao --out=<pasta>


func _ready() -> void:
	Game.test_mode = true
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	var s: Soldier = m.local_player
	print("ZONA final=%s fases=%d" % [m.zona_final, m.zona_fases.size()])
	for e in m.zona_fases:
		print("  t=%4.0f..%4.0f..%4.0f c=%s r=%.0f dano=%.0f" % [e[0], e[1], e[2], e[3], e[4], e[5]])
	# jogador olhando para o centro da próxima zona (vê a parede quando ela passa)
	# acelera só o relógio da partida (time_scale alto quebra a câmera/física com dt gigante)
	var foto := false
	var ult := -100.0
	var real0 := Time.get_ticks_msec()
	while m.clock < m.zona_fases[-1][2] + 10.0 and s.alive and Time.get_ticks_msec() - real0 < 150000:
		await get_tree().process_frame
		m.clock += 0.35
		m._zona_tick += 0.35
		if m.clock - ult >= 30.0:
			ult = m.clock
			print("  %5.0f s r=%.0f c=%s dano=%.0f fora=%s hp=%d prox=%.0f" % [m.clock, m.zona_r, m.zona_c, m.zona_dano, m.fora_da_zona(s.global_position), s.health, m.phase_left])
		if not foto and m.zona_r < 420.0:
			foto = true
			var d := m.zona_c - Vector2(s.global_position.x, s.global_position.z)
			s.yaw = atan2(-d.x, -d.y)
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("br_zona.png"))
	print("ZONA fim clock=%.0f vivo=%s hp=%d fase_final_r=%.0f" % [m.clock, s.alive, s.health, m.zona_r])
	get_tree().quit()
