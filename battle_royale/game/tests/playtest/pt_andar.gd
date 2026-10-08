extends RefCounted
## Etapa ANDAR: caminhada de 60 m com detecção de travamento, sprint, pulo, agachar, olhar (mouse), ADS, tiro e recarga da arma
## equipada, passos por superfície. Tudo pelo InputMap (Input.action_press) e Input.parse_input_event (mouse).
const U := preload("res://tests/playtest/pt_util.gd")


static func _mouse(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(dx, dy)
	e.position = Vector2(512, 384)
	Input.parse_input_event(e)


static func _ids_desde(c, i0: int, prefixo := "") -> Array:
	var r: Array = []
	for k in range(i0, c.audio_ev.size()):
		var e: Dictionary = c.audio_ev[k]
		if prefixo == "" or String(e.id).begins_with(prefixo):
			r.append(e)
	return r


static func _caminha(c, dist_alvo: float, max_s: float, rotulo: String, sprint := false) -> Dictionary:
	var s: Soldier = c.s
	var p0 := s.global_position
	var ult := p0
	var t_ini: float = c.tempo()
	var travou := 0
	var win_t := 0.0
	var win_p := p0
	var vmax := 0.0
	var ymin := p0.y
	var ymax := p0.y
	var soma_v := 0.0
	var n := 0
	var tot := 0.0
	var i_ev: int = c.audio_ev.size()
	var passos_sig := [0]
	var cb := func(_sup: String) -> void: passos_sig[0] += 1
	s.footstep.connect(cb)
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var shot_prox := 0.0
	while c.vivo() and c.tempo() - t_ini < max_s and tot < dist_alvo:
		await c.fq(1)
		var p := s.global_position
		tot += Vector2(p.x - ult.x, p.z - ult.z).length()
		ult = p
		var v := s.horizontal_speed()
		vmax = maxf(vmax, v)
		soma_v += v
		n += 1
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
		win_t += dt
		if win_t >= 1.5:
			var moveu := Vector2(p.x - win_p.x, p.z - win_p.z).length()
			if moveu < 0.4:
				travou += 1
				var f: String = ""
				if travou <= 4:
					f = await c.shot("travado_%s" % rotulo)
				c.achado("ANDAR_TRAVADO", "alto", "Jogador travou andando (%s): %.2f m em 1,5 s com W pressionado" % [rotulo, moveu],
					{"pos": U.v3(p), "moveu_m": snappedf(moveu, 0.01), "velocidade": snappedf(v, 0.01), "yaw_graus": snappedf(rad_to_deg(s.yaw), 1.0)}, f, "Movimento")
				# recuperação: escolhe a melhor direção livre que não seja a bloqueada
				var bloq := s.yaw
				var melhor_y := bloq + deg_to_rad(90.0)
				var bestl := -1.0
				for kk in 12:
					var yy: float = bloq + deg_to_rad(60.0 + 20.0 * kk)
					var l2: float = U.livre(c, p, Vector3(-sin(yy), 0, -cos(yy)), 30.0, 1.0)
					if l2 > bestl:
						bestl = l2
						melhor_y = yy
				s.yaw = melhor_y
				if travou >= 7:
					break
			win_t = 0.0
			win_p = p
		if c.tempo() - shot_prox > 4.0:
			shot_prox = c.tempo()
			c.shot("andando_%s" % rotulo)
	Input.action_release("move_forward")
	if sprint:
		Input.action_release("sprint")
	s.footstep.disconnect(cb)
	var dur: float = c.tempo() - t_ini
	return {"distancia_m": snappedf(tot, 0.1), "duracao_s": snappedf(dur, 0.01), "vel_media": snappedf(soma_v / maxf(n, 1), 0.01),
		"vel_max": snappedf(vmax, 0.01), "travamentos": travou, "variacao_altura": snappedf(ymax - ymin, 0.01),
		"passos_sinal": passos_sig[0], "passos_audio": _ids_desde(c, i_ev, "step_").size(), "i_ev": i_ev}


static func run(c) -> void:
	c.comeca_etapa("andar", 150.0)
	var s: Soldier = c.s
	var R := {}
	c.metricas["andar"] = R
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	c.pc._prefer_third_person = false
	c.pc._set_third_person(false)
	c.solta_entradas()
	var p_spawn := s.global_position
	var pp: Dictionary = U.ponto_plano(c, p_spawn)
	if pp.is_empty():
		pp = {"pos": p_spawn, "dir": U.melhor_direcao(c, p_spawn).dir, "livre": 0.0, "raio_busca": -1.0}
	c.teleporta(pp.pos + Vector3.UP * 0.2, U.yaw_de(pp.dir))
	R["inicio"] = {"pos": U.v3(pp.pos), "dir": U.v3(pp.dir), "livre_m": snappedf(pp.livre, 0.1), "distancia_do_spawn_m": snappedf(pp.pos.distance_to(p_spawn), 0.1),
		"nota": "o spawn real fica sobre um telhado (ver etapa spawn); a caminhada parte do chão firme mais próximo com 60 m livres"}
	await c.fq(40)
	c.shot("inicio")
	# 1) andar 60 m
	R["caminhada_60m"] = await _caminha(c, 60.0, 40.0, "60m")
	var cm: Dictionary = R["caminhada_60m"]
	if cm.distancia_m < 55.0:
		c.achado("ANDAR_NAO_CHEGOU", "alto", "Não completou 60 m andando (%.1f m em %.1f s)" % [cm.distancia_m, cm.duracao_s], cm, "", "Movimento")
	var ci: int = cm.i_ev
	var passos := []
	for e in _ids_desde(c, ci, "step_"):
		passos.append(e)
	R["passos_na_caminhada"] = {"eventos": passos.size(), "por_metro": snappedf(passos.size() / maxf(cm.distancia_m, 1.0), 0.001),
		"esperado_por_metro": snappedf(1.0 / 2.05, 0.001)}
	# 2) sprint
	R["sprint_4s"] = await _caminha(c, 999.0, 4.0, "sprint", true)
	R["razao_sprint_vs_andar"] = snappedf(float(R["sprint_4s"].vel_media) / maxf(float(cm.vel_media), 0.01), 3)
	# 3) pulo
	c.solta_entradas()
	await c.fq(20)
	var y0 := s.global_position.y
	var i_j: int = c.audio_ev.size()
	var pous: Array = [0]
	var cb := func(_i: float) -> void: pous[0] += 1
	s.landed.connect(cb)
	Input.action_press("jump")
	await c.fq(3)
	Input.action_release("jump")
	var ymax := y0
	var ar := 0
	var vy0 := s.velocity.y
	for i in 120:
		await c.fq(1)
		ymax = maxf(ymax, s.global_position.y)
		if not s.is_on_floor():
			ar += 1
		elif i > 5:
			break
	s.landed.disconnect(cb)
	R["pulo"] = {"altura_m": snappedf(ymax - y0, 0.01), "tempo_no_ar_s": snappedf(ar / 64.0, 0.01), "pousou_sinal": pous[0],
		"sons": _ids_desde(c, i_j).map(func(e): return e.id)}
	c.shot("pulo_pos")
	if ymax - y0 < 0.3:
		c.achado("PULO_NAO_SOBE", "medio", "Pulo não saiu do chão (%.2f m)" % (ymax - y0), R["pulo"], "", "Movimento")
	# 4) agachar
	var eye0 := s.eye_position().y
	Input.action_press("crouch")
	await c.seg(1.0)
	var eye1 := s.eye_position().y
	var cr := s.crouch
	c.shot("agachado")
	Input.action_release("crouch")
	await c.seg(0.8)
	R["agachar"] = {"olho_em_pe": snappedf(eye0, 0.01), "olho_agachado": snappedf(eye1, 0.01), "crouch_0a1": snappedf(cr, 0.01)}
	if eye0 - eye1 < 0.25:
		c.achado("AGACHAR_FRACO", "baixo", "Agachar quase não baixa a câmera (%.2f m)" % (eye0 - eye1), R["agachar"], "", "Movimento")
	# 5) olhar ao redor (mouse real, 360 graus)
	var yaw0 := s.yaw
	var pit0 := s.pitch
	var sens_graus := Settings.sensitivity * 0.022
	var contagem := 360.0 / sens_graus
	for i in 30:
		_mouse(contagem / 30.0, 0.0)
		await c.fq(1)
	var giro := rad_to_deg(s.yaw - yaw0)
	var esc := absf(giro) / 360.0
	for i in 10:
		_mouse(0.0, -40.0)
		await c.fq(1)
	c.shot("olhando_cima")
	var cima := rad_to_deg(s.pitch - pit0)
	for i in 10:
		_mouse(0.0, 40.0)
		await c.fq(1)
	s.pitch = 0.0
	R["olhar"] = {"giro_pedido_graus": 360.0, "giro_obtido_graus": snappedf(giro, 0.1), "escala_obtida_sobre_pedida": snappedf(esc, 0.001), "pitch_obtido_graus": snappedf(cima, 0.1),
		"mouse_mode": int(Input.mouse_mode), "sensibilidade": Settings.sensitivity,
		"nota": "relativo do mouse é escalado pelo stretch canvas_items (1280/1024 = 1,25 na janela 1024x768); a escala é do motor, não bug"}
	if esc < 0.5 or giro > 0.0:
		c.achado("OLHAR_MOUSE_NAO_GIRA", "alto", "Mouse emulado girou %.0f graus (esperado ~-360 a -450): olhar não responde" % giro, R["olhar"], "", "Movimento")
	# 6) ADS
	var ads_max := 0.0
	var t_ads := -1.0
	var t0: float = c.tempo()
	Input.action_press("alt_fire")
	for i in 90:
		await c.fq(1)
		ads_max = maxf(ads_max, c.pc._ads_amount)
		if t_ads < 0.0 and c.pc._ads_amount > 0.9:
			t_ads = c.tempo() - t0
	c.shot("ads")
	Input.action_release("alt_fire")
	await c.seg(0.5)
	R["ads"] = {"ads_max": snappedf(ads_max, 0.01), "tempo_ate_90pct_s": snappedf(t_ads, 0.01), "aim_amount": snappedf(s.aim_amount, 0.01),
		"arma": String(s.current_def().id) if s.current_def() else ""}
	# 7) tiro e recarga da arma equipada
	var ws := s.current()
	if ws and ws.def.is_gun():
		var mag0 := ws.mag
		var i_t: int = c.audio_ev.size()
		var flash := 0
		var ant := false
		var vm: Object = c.pc.viewmodel
		var rec_max := 0.0
		for k in 4:
			Input.action_press("fire")
			for f in 6:
				await c.fq(1)
				var vis: bool = vm._flash.visible if vm and vm.get("_flash") else false
				if vis and not ant:
					flash += 1
				ant = vis
				rec_max = maxf(rec_max, absf(s.aim_punch.y))
			Input.action_release("fire")
			await c.seg(0.3)
		var tiros := mag0 - ws.mag
		c.shot("tiro")
		R["tiro_equipada"] = {"arma": String(ws.def.id), "tiros": tiros, "flashes": flash, "recuo_max_graus": snappedf(rec_max, 0.01),
			"ids_som": _ids_desde(c, i_t).map(func(e): return e.id)}
		# recarga
		var rec0: float = c.tempo()
		var rid: int = c.audio_ev.size()
		Input.action_press("reload")
		await c.fq(3)
		Input.action_release("reload")
		var iniciou := s.is_reloading()
		var guard := 0
		while s.is_reloading() and guard < 600 and c.vivo():
			await c.fq(1)
			guard += 1
		R["recarga_equipada"] = {"iniciou": iniciou, "tempo_s": snappedf(c.tempo() - rec0, 0.01), "def_reload_time": ws.def.reload_time,
			"carregador_depois": ws.mag, "ids_som": _ids_desde(c, rid).map(func(e): return e.id)}
		c.shot("recarregou")
		if not iniciou:
			c.achado("RECARGA_NAO_INICIA", "alto", "Tecla R não iniciou recarga", R["recarga_equipada"], "", "Armas")
	c.solta_entradas()
	# 8) passos por superfície: descobre superfícies reais varrendo a ilha com raios
	var pontos := _superficies(c)
	R["superficies_na_ilha"] = pontos.map(func(q): return q.superficie)
	var vis_sup := {}
	var sup_res: Array = []
	for q in pontos:
		if not c.vivo():
			break
		var pos: Vector3 = q.pos
		c.teleporta(pos + Vector3.UP * 0.2, U.yaw_de(q.dir))
		await c.fq(40)
		var sup: String = s.surface_below()
		var id := "step_" + sup
		var tem: bool = Audio.has_sound(id)
		var res := await _caminha(c, 8.0, 7.0, "sup_" + sup)
		var tevt := 0
		var arqs := {}
		for e in _ids_desde(c, int(res.i_ev), "step_"):
			tevt += 1
			arqs[e.arquivo] = true
		var linha := {"superficie_meta": q.superficie, "superficie_sob_pe": sup, "id_pedido": id, "tem_arquivo": tem, "distancia_m": res.distancia_m,
			"vel_media": res.vel_media, "passos_audio": tevt, "passos_sinal": res.passos_sinal, "arquivos_distintos": arqs.size(), "pos": U.v3(pos)}
		sup_res.append(linha)
		var f2: String = await c.shot("superficie_" + sup)
		linha["captura"] = f2
		if not tem:
			c.achado("PASSO_SEM_ARQUIVO_" + sup, "alto", "Superfície '%s' pede %s mas não existe (cai em step_stone)" % [sup, id], linha, f2, "Passos")
		if res.distancia_m > 3.0 and tevt == 0:
			c.achado("PASSOS_MUDOS_" + sup, "critico", "Andou %.1f m sobre '%s' e não tocou nenhum passo" % [res.distancia_m, sup], linha, f2, "Passos")
		vis_sup[sup] = true
	R["passos_por_superficie"] = sup_res
	R["superficies_visitadas"] = vis_sup.keys()
	if vis_sup.size() <= 1:
		c.achado("PASSOS_SUPERFICIE_UNICA", "medio", "Só %d superfície(s) distinta(s) de passo encontrada(s) na ilha (%s): areia/grama/madeira/terra não variam" % [vis_sup.size(), ",".join(vis_sup.keys())],
			{"superficies": vis_sup.keys(), "regra": "Soldier.surface_below() lê meta 'surface' do colisor; terreno sem meta cai em 'stone'"}, "", "Passos")
	c.solta_entradas()
	R["quadros"] = c.resumo_quadros("andar")
	c.termina_etapa()


## Varre a ilha (grade de 30 m) com raios e devolve 1 ponto por superfície distinta (meta "surface" do colisor), perto do spawn.
static func _superficies(c) -> Array:
	var space = c.ilha.get_world_3d().direct_space_state
	var achados := {}
	var centro: Vector3 = c.s.global_position
	var cands: Array = []
	for gx in range(-420, 421, 30):
		for gz in range(-420, 421, 30):
			var x: float = centro.x + gx
			var z: float = centro.z + gz
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -10.0, z), 1)
			var h: Dictionary = space.intersect_ray(q)
			if h.is_empty():
				continue
			var col: Object = h.collider
			var sup := str(col.get_meta("surface", "stone")) if col else "stone"
			if h.position.y < 0.3:
				continue
			cands.append([Vector2(x, z).distance_to(Vector2(centro.x, centro.z)), sup, h.position])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var res: Array = []
	for cd in cands:
		if achados.has(cd[1]) or res.size() >= 5:
			continue
		var pos: Vector3 = cd[2]
		var bd: Dictionary = U.melhor_direcao(c, pos, 20.0)
		if float(bd.livre) < 9.0:
			continue
		achados[cd[1]] = true
		res.append({"superficie": cd[1], "pos": pos, "dir": bd.dir})
	return res
