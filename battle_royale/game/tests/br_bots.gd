extends Node
## Partida com bots em tempo real: o jogador salta logo e fica parado; imprime a cada 10 s quantos vivos,
## estados (avião/queda/chão), quantos têm arma primária, abates e FPS. Uso: --bots=11 --out=<pasta> [--segundos=180]


func _ready() -> void:
	Game.test_mode = true
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	# A cena de combate monta mapa, soldados e HUD assincronamente.
	# Não use local_player antes do sinal emitido ao final desse preparo.
	await m.match_initialized
	var s: Soldier = m.local_player
	assert(s != null, "BRMatch deve fornecer o jogador observador após match_initialized")
	m.killfeed.connect(func(e: Dictionary) -> void:
		print("MORTE %s -> %s (%s) t=%.0f" % [e.killer, e.victim, e.weapon, m.clock]))
	for b: Soldier in m.soldiers:
		b.died.connect(func(v: Soldier, _k, _d, _h, _w) -> void:
			print("   morto %s em %s estado=%s" % [v.display_name, v.global_position, m.estado.get(v)]))
	s.health = 1000000   # observador: não morre (a partida segue entre os bots)
	var dur := float(Game.test_args.get("segundos", "180"))
	var t0 := Time.get_ticks_msec()
	var prox := 0.0
	var foto := 0
	while (Time.get_ticks_msec() - t0) / 1000.0 < dur and m.phase != Match.Phase.MATCH_END:
		await get_tree().process_frame
		if m.estado.get(s) == "aviao" and m.pode_saltar():
			m.saltar(s)
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if el >= prox:
			prox += 10.0
			var cont := {}
			var vivos := 0
			var prim := 0
			var abates := 0
			for b: Soldier in m.soldiers:
				if b.alive:
					vivos += 1
					cont[m.estado.get(b, "?")] = cont.get(m.estado.get(b, "?"), 0) + 1
				if b.inventory.has(WeaponDef.Slot.PRIMARY):
					prim += 1
				abates += b.kills
			print("BOTS %3.0f s vivos=%d %s primaria=%d abates=%d fps=%d zona_r=%.0f proc=%.1fms fis=%.1fms draws=%d" % [el, vivos, cont, prim, abates, Engine.get_frames_per_second(), m.zona_r,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
			for b: Soldier in m.soldiers:
				if b == s:
					continue
				var brain := b.controller as BRBotBrain
				var alvo := brain.target.display_name if brain and brain.target else "-"
				var arma := String(b.current_def().id) if b.current_def() else "-"
				var estado_bot: String = m.estado.get(b, "?")
				print("   BOT %s estado=%s alvo=%s arma=%s tiros=%d pos=%s" % [b.display_name, estado_bot, alvo, arma, int(b.shots_fired), b.global_position])
		if foto < 3 and el > 60.0 + foto * 40.0:
			# foto de um bot vivo em terra, vista do jogador virado para ele
			for b: Soldier in m.soldiers:
				if b != s and b.alive and m.estado.get(b) == "chao":
					# chega a 7 m do bot, do lado de onde ele está olhando
					var fw := -Basis(Vector3.UP, b.yaw).z
					s.global_position = b.global_position + fw * 7.0 + Vector3.UP * 0.3
					s.reset_physics_interpolation()
					var d := b.global_position + Vector3.UP * 1.0 - s.global_position - Vector3.UP * 1.6
					if d.length() < 150.0:
						s.yaw = atan2(-d.x, -d.z)
						s.pitch = atan2(d.y, Vector2(d.x, d.z).length())
						for k in 6:
							await get_tree().process_frame
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(out.path_join("br_bots_%d.png" % foto))
						break
			foto += 1
	print("BOTS fim fase=%d vivos=%d jogador_vivo=%s" % [m.phase, m.soldiers.filter(func(b): return b.alive).size(), s.alive])
	get_tree().quit()
