extends RefCounted
## Etapa AMBIENTE: passeio por pontos de interesse; capturas, desempenho por lugar e nível de áudio por lugar.
const U := preload("res://tests/playtest/pt_util.gd")


static func _ponto_bom(c, x: float, z: float) -> Vector3:
	var h: float = c.terr.height_world(x, z)
	for r in [0.0, 6.0, 12.0, 20.0, 30.0]:
		for k in (1 if r == 0.0 else 8):
			var a := TAU * float(k) / 8.0
			var px: float = x + cos(a) * r
			var pz: float = z + sin(a) * r
			var ht: float = c.terr.height_world(px, pz)
			var hf: float = c.chao_em(px, pz, ht + 40.0)
			if absf(hf - ht) < 0.5 and ht > 0.8 and U.livre(c, Vector3(px, hf, pz), Vector3.FORWARD, 8.0) > 5.0:
				return Vector3(px, hf, pz)
	return Vector3(x, h + 1.0, z)


static func run(c) -> void:
	c.comeca_etapa("ambiente", 110.0)
	var s: Soldier = c.s
	var R := {"pontos": []}
	c.metricas["ambiente"] = R
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	c.solta_entradas()
	c.limpa_zumbis()
	var pois: Array = c.ilha.layout.pois
	# seleção espalhada (farthest-first) a partir do spawn
	var cand: Array = []
	for p in pois:
		cand.append({"nome": String(p.get("nome", p.get("id", "?"))), "pos": Vector2(float(p.centro[0]), -float(p.centro[1]))})
	var escolhidos: Array = []
	var ref := [Vector2(s.global_position.x, s.global_position.z)]
	while escolhidos.size() < 7 and not cand.is_empty():
		var best := -1
		var bd := -1.0
		for i in cand.size():
			var dm := INF
			for r in ref:
				dm = minf(dm, (cand[i].pos as Vector2).distance_to(r))
			if dm > bd:
				bd = dm
				best = i
		escolhidos.append(cand[best])
		ref.append(cand[best].pos)
		cand.remove_at(best)
	c.inicia_gravacao("ambiente", ["Master", "Music"])
	for ch in escolhidos:
		if not c.vivo():
			break
		var pos: Vector3 = _ponto_bom(c, ch.pos.x, ch.pos.y)
		c.teleporta(pos + Vector3.UP * 0.2, 0.0)
		await c.seg(1.2)
		var i_q: int = (c.quadros["ambiente"] as Array).size()
		var i_b: int = c.bus_amostras.size()
		var i_e: int = c.audio_ev.size()
		var f1: String = await c.shot("poi_%s_a" % ch.nome)
		await c.seg(1.8)
		s.yaw = PI
		await c.seg(0.8)
		var f2: String = await c.shot("poi_%s_b" % ch.nome)
		var qs: Array = (c.quadros["ambiente"] as Array).slice(i_q)
		var soma := 0.0
		var mx := 0.0
		for q in qs:
			soma += float(q)
			mx = maxf(mx, float(q))
		var mp: Array = []
		var mu: Array = []
		for a in c.bus_amostras.slice(i_b):
			mp.append(float(a.db.get("Master", -80.0)))
			mu.append(float(a.db.get("Music", -80.0)))
		var amb: AudioStreamPlayer = Audio._ambient
		var linha := {"nome": ch.nome, "pos": U.v3(pos), "capturas": [f1, f2], "terreno_y": snappedf(c.terr.height_world(pos.x, pos.z), 0.1),
			"fps_medio": snappedf(1000.0 / (soma / maxf(qs.size(), 1)), 0.1), "quadro_max_ms": snappedf(mx, 0.1),
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"primitivas": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"objetos_render": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"nos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"pico_master_medio_db": snappedf(_media(mp), 0.1), "pico_music_medio_db": snappedf(_media(mu), 0.1),
			"ambiente_tocando": amb.playing, "ambiente_db": amb.volume_db, "eventos_audio": c.audio_ev.size() - i_e}
		R["pontos"].append(linha)
		if linha.fps_medio < 24.0:
			c.achado("FPS_BAIXO_" + str(ch.nome).validate_filename(), "alto", "FPS médio %.1f em '%s' (%d draw calls)" % [linha.fps_medio, ch.nome, linha.draw_calls], linha, f1, "Desempenho")
	c.para_gravacao("ambiente")
	var ms: Array = R.pontos.map(func(p): return p.pico_music_medio_db)
	if not ms.is_empty():
		var lo := 99.0
		var hi := -99.0
		for v in ms:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		R["variacao_music_entre_lugares_db"] = snappedf(hi - lo, 0.1)
		if hi - lo < 1.5:
			c.achado("AMBIENTE_PLANO_ENTRE_LUGARES", "medio", "O ambiente sonoro é praticamente idêntico em %d lugares distintos (variação %.1f dB): mesmo loop em todo o mapa" % [ms.size(), hi - lo],
				{"pico_music_db_por_lugar": R.pontos.map(func(p): return [p.nome, p.pico_music_medio_db]), "variacao_db": hi - lo}, "", "Áudio ambiente")
	R["quadros"] = c.resumo_quadros("ambiente")
	c.termina_etapa()


static func _media(a: Array) -> float:
	if a.is_empty():
		return -80.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()
