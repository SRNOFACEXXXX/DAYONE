extends RefCounted
## Etapa ÁGUA: vai até a praia, entra, nada 5 s, mergulha, mede fôlego/estado e sons (splash), volta.
const U := preload("res://tests/playtest/pt_util.gd")


static func _praia(c, perto: Vector3) -> Array:
	var terr: IlhaTerrain = c.terr
	var melhor: Array = []
	var md := INF
	for r in range(40, 560, 6):
		for col in range(40, 560, 6):
			var x := -600.0 + col * 2.0
			var z := -600.0 + r * 2.0
			var h := terr.height_world(x, z)
			if h < 0.4 or h > 0.9:
				continue
			var d0 := Vector2(x, z).distance_to(Vector2(perto.x, perto.z))
			if d0 >= md:
				continue
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var bom := true
				var ant := h
				for k in range(1, 31):
					var p := Vector2(x, z) + d * 2.0 * k
					var hh := terr.height_world(p.x, p.y)
					if hh > ant + 0.05 or absf(hh - ant) > 0.9:
						bom = false
						break
					ant = hh
				if bom and ant < -2.5:
					var tras := Vector2(x, z) - d * 8.0
					if terr.height_world(tras.x, tras.y) > 0.5:
						md = d0
						melhor = [Vector2(x, z), d]
						break
	return melhor


static func run(c) -> void:
	c.comeca_etapa("agua", 90.0)
	var s: Soldier = c.s
	var R := {}
	c.metricas["agua"] = R
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	c.solta_entradas()
	c.limpa_zumbis()
	var spawn := s.global_position
	var pr := _praia(c, spawn)
	if pr.is_empty():
		c.achado("SEM_PRAIA", "medio", "Não achou praia com declive suave até a água", {}, "", "Água")
		c.termina_etapa()
		return
	var p0: Vector2 = pr[0]
	var d: Vector2 = pr[1]
	R["praia"] = {"pos": [snappedf(p0.x, 0.1), snappedf(p0.y, 0.1)], "dist_do_spawn_m": snappedf(Vector2(spawn.x, spawn.z).distance_to(p0), 1.0)}
	var ini := Vector3(p0.x - d.x * 4.0, 0.0, p0.y - d.y * 4.0)
	ini.y = c.chao_em(ini.x, ini.z, 40.0) + 0.1
	c.teleporta(ini, U.yaw_de(Vector3(d.x, 0, d.y)))
	await c.fq(40)
	c.shot("praia")
	var i0: int = c.audio_ev.size()
	var passos_sig: Array = [0]
	var cb := func(_sup: String) -> void: passos_sig[0] += 1
	s.footstep.connect(cb)
	Input.action_press("move_forward")
	var n := 0
	var t_in: float = c.tempo()
	while not s.nadando and n < 900 and c.vivo():
		await c.fq(1)
		n += 1
	var entrou := s.nadando
	R["entrada"] = {"nadou": entrou, "tempo_s": snappedf(c.tempo() - t_in, 0.1), "y_pes": snappedf(s.global_position.y, 0.01), "nivel_agua": snappedf(s.agua_y, 0.01)}
	if not entrou:
		Input.action_release("move_forward")
		c.achado("AGUA_NAO_NADA", "alto", "Caminhou 14 s rumo à água e nunca passou a nadar", R["entrada"], "", "Água")
		s.footstep.disconnect(cb)
		c.termina_etapa()
		return
	var passos_antes: int = passos_sig[0]
	await c.seg(1.0)
	c.shot("nadando")
	var v_ac := 0.0
	var vn := 0
	var folego_ini := s.folego
	for i in 5:
		await c.seg(1.0)
		v_ac += s.horizontal_speed()
		vn += 1
	R["nado_5s"] = {"vel_media": snappedf(v_ac / maxf(vn, 1), 0.01), "olho_acima_da_agua_m": snappedf(s.eye_position().y - s.agua_y, 0.01),
		"folego_ini": snappedf(folego_ini, 0.1), "folego_fim": snappedf(s.folego, 0.1), "passos_em_terra_antes_de_nadar": passos_antes,
		"passos_nadando": int(passos_sig[0]) - passos_antes}
	Input.action_release("move_forward")
	# mergulha 3 s
	Input.action_press("crouch")
	var q := 0
	while not s.submerso and q < 200 and c.vivo():
		await c.fq(1)
		q += 1
	var f0 := s.folego
	await c.seg(2.0)
	c.shot("submerso")
	R["mergulho"] = {"submergiu": s.submerso, "folego_cai_em_2s": snappedf(f0 - s.folego, 0.2), "hp": s.health}
	Input.action_release("crouch")
	Input.action_press("jump")
	await c.seg(1.2)
	Input.action_release("jump")
	s.footstep.disconnect(cb)
	var ev = c.audio_ev.slice(i0)
	var ids := {}
	for e in ev:
		ids[e.id] = int(ids.get(e.id, 0)) + 1
	R["sons"] = ids
	R["tem_splash"] = Audio.has_sound("splash")
	if not ids.has("splash"):
		c.achado("AGUA_SEM_SPLASH", "alto", "Entrar na água não toca som algum (código pede 'splash', existe arquivo? %s)" % str(Audio.has_sound("splash")),
			{"ids_tocados": ids, "tem_arquivo_splash": Audio.has_sound("splash")}, "", "Água")
	var nada_ids := ids.keys().filter(func(k): return String(k).contains("swim") or String(k).contains("water") or String(k).contains("nado"))
	if nada_ids.is_empty():
		c.achado("AGUA_SEM_SOM_NADO", "medio", "Nadar 5 s sem nenhum som de nado/água em loop ou braçada", {"ids": ids}, "", "Água")
	if int(R["nado_5s"].passos_nadando) > 0:
		c.achado("AGUA_PASSOS_NADANDO", "medio", "%d eventos de passo enquanto nadava" % R["nado_5s"].passos_nadando, R["nado_5s"], "", "Passos")
	# volta à praia
	var r := 0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	while s.nadando and r < 1200 and c.vivo():
		var alvo := Vector2(ini.x, ini.z) - Vector2(s.global_position.x, s.global_position.z)
		s.yaw = atan2(-alvo.x, -alvo.y)
		await c.fq(1)
		r += 1
	c.solta_entradas()
	R["volta"] = {"saiu_da_agua": not s.nadando, "tempo_s": snappedf(r / 64.0, 0.1)}
	if s.nadando:
		c.achado("AGUA_NAO_SAI", "alto", "Não conseguiu sair da água em 19 s", R["volta"], "", "Água")
	s.health = 100
	R["quadros"] = c.resumo_quadros("agua")
	c.termina_etapa()
