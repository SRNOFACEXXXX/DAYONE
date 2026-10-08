extends RefCounted
## Etapa COMBATE: cada arma atira 10 tiros num alvo (zumbi-manequim a 30 m), mede acerto, recuo, cadência, flash, sons e recarga.
const U := preload("res://tests/playtest/pt_util.gd")
const ARMAS := ["ak47", "m4", "glock", "usp", "mosin", "m107", "m249", "uzi"]
const DIST := 30.0


static func _achar_posto(c) -> Dictionary:
	var base: Vector3 = c.s.global_position
	# procura posto a até 250 m do spawn com 45 m livres numa direção e chão plano
	var melhor := {}
	var melhor_l := -1.0
	for r in [0.0, 40.0, 80.0, 120.0, 160.0, 220.0]:
		for k in 8:
			var a := TAU * float(k) / 8.0
			var x: float = base.x + cos(a) * r
			var z: float = base.z + sin(a) * r
			var p := Vector3(x, c.chao_em(x, z, 80.0), z)
			if p.y < 1.0:
				continue
			var bd: Dictionary = U.melhor_direcao(c, p, 50.0)
			var d: Vector3 = bd.dir
			var alvo := p + d * DIST
			var dy := absf(c.chao_em(alvo.x, alvo.z, 80.0) - p.y)
			if bd.livre > melhor_l and bd.livre >= 44.0 and dy < 2.0:
				melhor_l = bd.livre
				melhor = {"pos": p, "dir": d, "livre": bd.livre}
		if melhor_l >= 49.0:
			break
	return melhor


static func _ids(c, i0: int) -> Array:
	var r: Array = []
	for k in range(i0, c.audio_ev.size()):
		r.append(c.audio_ev[k])
	return r


static func _arma(c, arma: String, dummy: ZombieEnemy, alvo_pt: Vector3) -> Dictionary:
	var s: Soldier = c.s
	var R := {"arma": arma}
	if not U.equipa(c, arma):
		R["erro"] = "não equipou"
		return R
	await c.seg(1.6)   # saque
	var ws := s.current()
	if ws == null or String(ws.def.id) != arma:
		R["erro"] = "arma atual = %s" % (String(ws.def.id) if ws else "nenhuma")
		c.achado("ARMA_NAO_EQUIPA_" + arma, "alto", "Não conseguiu equipar %s" % arma, R, "", "Armas")
		return R
	var def: WeaponDef = ws.def
	R["def"] = {"auto": def.automatic, "mag": def.mag_size, "intervalo_s": def.fire_interval, "reload_s": def.reload_time, "dano": def.damage, "vel_bala": def.muzzle_velocity}
	R["tem_perfil_TiroSom"] = TiroSom.PERFIS.has(def.id)
	R["fire_sound_def"] = def.fire_sound
	dummy.health = 1 << 40
	alvo_pt = dummy.global_position + Vector3.UP * 1.1
	c.olha(alvo_pt)
	await c.fq(8)
	var i_ev: int = c.audio_ev.size()
	var hits := {"head": 0, "body": 0}
	var hit_cb := func(zone: StringName, _a: int, _att: Node3D) -> void: hits[String(zone)] = int(hits.get(String(zone), 0)) + 1
	dummy.hit_taken.connect(hit_cb)
	var disp: Array = [0]
	var t_disp: Array = []
	var fcb := func(_d: WeaponDef) -> void:
		disp[0] += 1
		t_disp.append(c.tempo())
	s.fired.connect(fcb)
	var impactos: Array = []
	var icb := func(info: Dictionary) -> void:
		if impactos.size() < 12:
			var z = info.get("zombie")
			impactos.append({"dist": snappedf(float(info.get("dist", -1.0)), 0.1), "pos": U.v3(info.pos), "tipo": "zumbi" if z != null else str(info.get("surface", "mundo")),
				"dy_vs_alvo": snappedf(info.pos.y - alvo_pt.y, 0.01), "dxz_vs_alvo": snappedf(Vector2(info.pos.x - alvo_pt.x, info.pos.z - alvo_pt.z).length(), 0.01)})
	s.bala_impacto.connect(icb)
	var flash := 0
	var flash_frames := 0
	var ant := false
	var punch_max := Vector2.ZERO
	var vm: Object = c.pc.viewmodel
	var t0: float = c.tempo()
	var rec_t := -1.0
	var rec_ini: Array = []
	var guard := 0
	var semi_fase := 0
	var shot_foto := false
	while disp[0] < 10 and c.vivo() and guard < 2400:
		guard += 1
		c.olha(alvo_pt)
		if ws.mag <= 0:
			Input.action_release("fire")
			# recarga forçada (carregador pequeno): mede aqui
			var t_r: float = c.tempo()
			Input.action_press("reload")
			await c.fq(3)
			Input.action_release("reload")
			var g2 := 0
			while s.is_reloading() and g2 < 900 and c.vivo():
				await c.fq(1)
				g2 += 1
			rec_ini.append(snappedf(c.tempo() - t_r, 0.01))
			continue
		if def.automatic:
			Input.action_press("fire")
		else:
			semi_fase += 1
			if semi_fase % 4 < 2:
				Input.action_press("fire")
			else:
				Input.action_release("fire")
		await c.fq(1)
		var vis: bool = vm._flash.visible if vm and vm.get("_flash") else false
		if vis:
			flash_frames += 1
			if not ant:
				flash += 1
		ant = vis
		punch_max.x = maxf(punch_max.x, absf(s.aim_punch.x))
		punch_max.y = maxf(punch_max.y, absf(s.aim_punch.y))
		if disp[0] >= 3 and not shot_foto:
			shot_foto = true
			c.shot("tiro_" + arma)
	Input.action_release("fire")
	await c.seg(0.6)
	var t_fim: float = c.tempo()
	s.fired.disconnect(fcb)
	s.bala_impacto.disconnect(icb)
	dummy.hit_taken.disconnect(hit_cb)
	R["impactos_amostra"] = impactos
	R["alvo_deriva_m"] = snappedf(dummy.global_position.distance_to(alvo_pt - Vector3.UP * 1.1), 0.01)
	var rq := PhysicsRayQueryParameters3D.create(s.eye_position(), alvo_pt, 1)
	var rh: Dictionary = c.ilha.get_world_3d().direct_space_state.intersect_ray(rq)
	R["obstaculo_entre_olho_e_alvo"] = (str(rh.collider.name) + " a " + str(snappedf(s.eye_position().distance_to(rh.position), 0.1)) + " m") if not rh.is_empty() else ""
	R["tiros_disparados"] = disp[0]
	R["acertos_cabeca"] = hits.head
	R["acertos_corpo"] = hits.body
	R["acertos"] = int(hits.head) + int(hits.body)
	R["precisao_pct"] = snappedf(100.0 * float(R.acertos) / maxf(disp[0], 1), 0.1)
	R["flashes"] = flash
	R["flash_quadros_total"] = flash_frames
	R["recuo_max_graus"] = {"yaw": snappedf(punch_max.x, 0.01), "pitch": snappedf(punch_max.y, 0.01)}
	R["duracao_rajada_s"] = snappedf((t_disp[t_disp.size() - 1] - t_disp[0]) if t_disp.size() > 1 else 0.0, 0.01)
	var ints: Array = []
	for k in range(1, t_disp.size()):
		ints.append(t_disp[k] - t_disp[k - 1])
	if not ints.is_empty():
		var so := 0.0
		for x in ints:
			so += x
		R["intervalo_medido_s"] = snappedf(so / ints.size(), 0.001)
	R["recargas_durante_rajada_s"] = rec_ini
	# sons da rajada
	var ev := _ids(c, i_ev)
	var por_id := {}
	var arqs := {}
	var seq_ident := 0
	var ult_arq := ""
	for e in ev:
		por_id[e.id] = int(por_id.get(e.id, 0)) + 1
		if e.has("arquivo"):
			arqs[e.arquivo] = true
		if String(e.id) == String(def.fire_sound) or String(e.id).ends_with("_perto") or String(e.id).contains("_fire"):
			if e.get("arquivo", "") == ult_arq and ult_arq != "":
				seq_ident += 1
			ult_arq = e.get("arquivo", "")
	R["sons_por_id"] = por_id
	R["arquivos_distintos"] = arqs.size()
	R["disparos_com_mesmo_arquivo_em_sequencia"] = seq_ident
	var faltando := []
	for e in ev:
		if e.tipo == "faltando":
			faltando.append(e.id)
	R["sons_faltando"] = faltando
	# recarga explícita (se ainda há o que carregar)
	if ws.mag < def.mag_size and ws.reserve > 0 and c.vivo():
		var ir: int = c.audio_ev.size()
		var t_r2: float = c.tempo()
		var rf: Array = [-1.0]
		var rcb := func(_d: WeaponDef) -> void: rf[0] = c.tempo()
		s.reload_finished.connect(rcb)
		Input.action_press("reload")
		await c.fq(3)
		Input.action_release("reload")
		var iniciou := s.is_reloading()
		var g3 := 0
		while s.is_reloading() and g3 < 1200 and c.vivo():
			await c.fq(1)
			g3 += 1
		s.reload_finished.disconnect(rcb)
		var evr := _ids(c, ir)
		R["recarga"] = {"iniciou": iniciou, "tempo_s": snappedf((rf[0] - t_r2) if rf[0] > 0 else -1.0, 0.01), "def_reload_time": def.reload_time,
			"ids_som": evr.map(func(e): return e.id), "mag_depois": ws.mag}
		if not iniciou:
			c.achado("RECARGA_FALHOU_" + arma, "alto", "%s: R não iniciou recarga" % arma, R["recarga"], "", "Armas")
		if iniciou and evr.filter(func(e): return String(e.id).begins_with("reload")).is_empty():
			c.achado("RECARGA_SEM_SOM_" + arma, "alto", "%s: recarga sem nenhum som de recarga" % arma, R["recarga"], "", "Áudio armas")
	# achados
	if R.tiros_disparados < 10:
		c.achado("TIROS_INCOMPLETOS_" + arma, "medio", "%s: só %d de 10 tiros disparados" % [arma, R.tiros_disparados], R, "", "Armas")
	if R.precisao_pct < 50.0:
		c.achado("PRECISAO_BAIXA_" + arma, "medio", "%s: só %d/%d tiros acertaram o alvo a 30 m com mira perfeita (%.0f%%)" % [arma, R.acertos, R.tiros_disparados, R.precisao_pct],
			{"acertos": R.acertos, "tiros": R.tiros_disparados, "vel_bala": def.muzzle_velocity}, "", "Armas")
	if flash == 0 and R.tiros_disparados > 0:
		c.achado("SEM_FLASH_" + arma, "medio", "%s: nenhum flash de boca em %d tiros" % [arma, R.tiros_disparados], {"flash_quadros": flash_frames}, "", "Armas")
	if not R["tem_perfil_TiroSom"]:
		c.achado("SEM_PERFIL_TIROSOM_" + arma, "alto", "%s sem perfil em TiroSom.PERFIS (sem camadas/cauda)" % arma, {"id": arma}, "", "Áudio armas")
	if not faltando.is_empty():
		c.achado("SOM_ARMA_FALTANDO_" + arma, "alto", "%s pede sons inexistentes: %s" % [arma, ",".join(faltando.slice(0, 6))], {"ids": faltando}, "", "Áudio armas")
	var tem_cauda := false
	for id in por_id:
		if String(id).ends_with("cauda"):
			tem_cauda = true
	R["tem_cauda"] = tem_cauda
	if not tem_cauda:
		c.achado("ARMA_SEM_CAUDA_" + arma, "alto", "%s: nenhuma cauda/eco tocou durante 10 tiros" % arma, {"ids": por_id}, "", "Áudio armas")
	if seq_ident >= 3:
		c.achado("SOM_REPETIDO_" + arma, "medio", "%s: mesmo arquivo de tiro tocou %d vezes seguidas (sem variação)" % [arma, seq_ident], {"arquivos": arqs.keys()}, "", "Áudio armas")
	return R


static func run(c) -> void:
	c.comeca_etapa("combate", 220.0)
	var R := {}
	c.metricas["combate"] = R
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	c.solta_entradas()
	c.limpa_zumbis()
	var posto := _achar_posto(c)
	if posto.is_empty():
		c.achado("COMBATE_SEM_POSTO", "medio", "Não achou trecho livre de 45 m para o alvo", {}, "", "Armas")
		c.termina_etapa()
		return
	var p: Vector3 = posto.pos
	var d: Vector3 = posto.dir
	c.teleporta(p + Vector3.UP * 0.2, U.yaw_de(d))
	var ap := p + d * DIST
	var dummy: ZombieEnemy = c.cria_zumbi(ap, U.yaw_de(-d))
	dummy.max_health = 100000          # o dano é fração de max_health; health enorme = o manequim nunca morre
	dummy.health = 1 << 40
	await c.fq(20)
	dummy.set_demo_state(&"idle")
	var alvo_pt := dummy.global_position + Vector3.UP * 1.1
	R["posto"] = {"pos": U.v3(p), "alvo": U.v3(dummy.global_position), "dist_m": snappedf(p.distance_to(dummy.global_position), 0.1)}
	await c.pq(3)
	c.shot("alvo_30m")
	R["armas"] = {}
	for a in ARMAS:
		if not c.vivo():
			break
		c.log_("arma %s" % a)
		R["armas"][a] = await _arma(c, a, dummy, alvo_pt)
		if is_instance_valid(dummy):
			dummy.health = 1 << 40
		await c.seg(0.5)
	if is_instance_valid(dummy):
		dummy.queue_free()
	c.solta_entradas()
	R["quadros"] = c.resumo_quadros("combate")
	c.termina_etapa()
