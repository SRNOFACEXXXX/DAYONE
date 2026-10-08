extends RefCounted
## Etapa SPAWN: mede onde o jogo põe o jogador (inicial + 10 respawns) e se o ponto é bom. Só mede; não corrige.
const U := preload("res://tests/playtest/pt_util.gd")


static func medir(c, rotulo: String) -> Dictionary:
	var s: Soldier = c.s
	var p := s.global_position
	var space = c.ilha.get_world_3d().direct_space_state
	var r := {"rotulo": rotulo, "pos": U.v3(p), "yaw_graus": snappedf(rad_to_deg(s.yaw), 0.1)}
	var ruim: Array = []
	# --- chão e declive (terreno + física)
	var h0: float = c.terr.height_world(p.x, p.z)
	var gx: float = (c.terr.height_world(p.x + 1.5, p.z) - c.terr.height_world(p.x - 1.5, p.z)) / 3.0
	var gz: float = (c.terr.height_world(p.x, p.z + 1.5) - c.terr.height_world(p.x, p.z - 1.5)) / 3.0
	var decl_terr := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
	var he: float = c.chao_em(p.x + 1.0, p.z, p.y + 3.0)
	var hw: float = c.chao_em(p.x - 1.0, p.z, p.y + 3.0)
	var hn: float = c.chao_em(p.x, p.z - 1.0, p.y + 3.0)
	var hs: float = c.chao_em(p.x, p.z + 1.0, p.y + 3.0)
	var decl_fis := rad_to_deg(atan(sqrt(pow((he - hw) / 2.0, 2) + pow((hs - hn) / 2.0, 2))))
	var chao: float = c.chao_sob(p)
	r["altura_terreno"] = snappedf(h0, 0.01)
	r["altura_chao_fisico"] = snappedf(chao, 0.01)
	r["pe_acima_do_chao_m"] = snappedf(p.y - chao, 0.01)
	r["declive_terreno_graus"] = snappedf(decl_terr, 0.1)
	r["declive_fisico_graus"] = snappedf(decl_fis, 0.1)
	r["chao_fisico_acima_do_terreno_m"] = snappedf(chao - h0, 0.01)
	if chao - h0 > 1.0:
		ruim.append("sobre telhado/prop: chão físico %.1f m acima do terreno" % (chao - h0))
	var decl := maxf(decl_terr, decl_fis)
	r["declive_graus"] = snappedf(decl, 0.1)
	if decl > 10.0:
		ruim.append("declive %.1f graus (> 10)" % decl)
	# planicidade num raio de 5 m
	var dmax := 0.0
	for i in 8:
		var a := TAU * float(i) / 8.0
		var hh: float = c.chao_em(p.x + cos(a) * 5.0, p.z + sin(a) * 5.0, p.y + 8.0)
		dmax = maxf(dmax, absf(hh - chao))
	r["variacao_altura_raio5m"] = snappedf(dmax, 0.01)
	# --- dentro de geometria / interior
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	var pq := PhysicsShapeQueryParameters3D.new()
	pq.shape = cap
	pq.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.0)
	pq.collision_mask = 1
	var res: Array = space.intersect_shape(pq, 16)
	var dentro: Array = []
	for d in res:
		var col: Object = d.collider
		var nome := String(col.name) if col is Node else str(col)
		if nome == "TerrenoColisao":
			continue
		dentro.append(nome + ":" + (col as Object).get_class())
	r["colisores_na_capsula"] = dentro
	if not dentro.is_empty():
		ruim.append("dentro de geometria (%s)" % ", ".join(dentro.slice(0, 3)))
	var teto := 99.0
	var qu := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.8, p + Vector3.UP * 8.0, 1)
	var hu: Dictionary = space.intersect_ray(qu)
	if not hu.is_empty():
		teto = hu.position.y - (p.y + 1.8)
	r["teto_acima_m"] = snappedf(teto, 0.1)
	# --- visão em 8 direções
	var vis: Array = []
	var fechadas := 0
	for i in 8:
		var a := TAU * float(i) / 8.0
		var l: float = U.livre(c, p, Vector3(sin(a), 0, cos(a)), 40.0, 1.6)
		vis.append(snappedf(l, 0.1))
		if l < 3.0:
			fechadas += 1
	r["visao_8dir_m"] = vis
	r["direcoes_fechadas_lt3m"] = fechadas
	r["interior_provavel"] = teto < 4.0 and fechadas >= 4
	if r["interior_provavel"]:
		ruim.append("interior/encurralado (teto %.1f m, %d dir. fechadas)" % [teto, fechadas])
	if fechadas >= 6:
		ruim.append("encurralado (%d de 8 direções a < 3 m)" % fechadas)
	# --- água
	var nivel: float = c.ilha.nivel_agua_em(p.x, p.z)
	r["nivel_agua"] = nivel
	r["na_agua"] = chao < nivel - 0.02
	if r["na_agua"]:
		ruim.append("na água")
	var dagua := 999.0
	for rr in range(3, 240, 3):
		for k in 16:
			var a := TAU * float(k) / 16.0
			var x: float = p.x + cos(a) * rr
			var z: float = p.z + sin(a) * rr
			if c.terr.height_world(x, z) < c.ilha.nivel_agua_em(x, z) - 0.05:
				dagua = minf(dagua, float(rr))
		if dagua < 999.0:
			break
	r["dist_agua_mar_represa_m"] = dagua if dagua < 999.0 else -1.0
	var lay: Dictionary = c.ilha.layout
	var drio := 999.0
	for tr in lay.agua.rio.trechos:
		drio = minf(drio, U.dist_polilinha(p, tr.pontos) - float(tr.largura_m) * 0.5)
	r["dist_rio_m"] = snappedf(drio, 0.1)
	if drio < 6.0:
		ruim.append("beira do rio (%.1f m)" % drio)
	var dest := 999.0
	var dest_nome := ""
	for e in lay.estradas:
		var d: float = U.dist_polilinha(p, e.pontos) - float(e.largura_m) * 0.5
		if d < dest:
			dest = d
			dest_nome = String(e.nome)
	r["dist_estrada_m"] = snappedf(dest, 0.1)
	r["estrada_mais_proxima"] = dest_nome
	var dcasa := 999.0
	var casa_nome := ""
	for poi in lay.pois + lay.get("marcos", []):
		for pr in poi.get("predios", []):
			var q := Vector2(float(pr.pos[0]), -float(pr.pos[1]))
			var d := Vector2(p.x, p.z).distance_to(q) - float(pr.tamanho_m[0]) * 0.5
			if d < dcasa:
				dcasa = d
				casa_nome = "%s %s" % [pr.get("tipo", ""), pr.get("id", "")]
	r["dist_construcao_m"] = snappedf(dcasa, 0.1)
	r["construcao_mais_proxima"] = casa_nome
	# --- zumbis
	var dz := 999.0
	var n15 := 0
	var n30 := 0
	var lista: Array = []
	for z in c.zumbis():
		if (z as ZombieEnemy).state == ZombieEnemy.State.DEAD:
			continue
		var d := Vector2(p.x, p.z).distance_to(Vector2(z.global_position.x, z.global_position.z))
		dz = minf(dz, d)
		if d < 15.0:
			n15 += 1
		if d < 30.0:
			n30 += 1
		lista.append([snappedf(d, 0.1), String(ZombieEnemy.State.keys()[z.state])])
	lista.sort()
	r["zumbi_mais_proximo_m"] = snappedf(dz, 0.1) if dz < 999.0 else -1.0
	r["zumbis_lt15m"] = n15
	r["zumbis_lt30m"] = n30
	r["zumbis_proximos"] = lista.slice(0, 4)
	if n15 > 0:
		ruim.append("%d zumbi(s) a < 15 m (mais perto %.1f m)" % [n15, dz])
	if absf(p.y - chao) > 0.35:
		ruim.append("pé a %.2f m do chão (flutuando/enterrado)" % (p.y - chao))
	r["ruim"] = ruim
	r["bom"] = ruim.is_empty()
	return r


static func _redisparar_zumbis(c, quantos: int) -> void:
	var zd: Node = c.ilha.get_node_or_null("ZombieDirector")
	if zd == null:
		return
	c.limpa_zumbis()
	zd.opening_count = quantos
	zd.setup(c.terr, c.s, c.ilha._zombie_settlement_centers())


static func run(c) -> void:
	c.comeca_etapa("spawn", 90.0)
	var R := {}
	c.metricas["spawn"] = R
	R["constante_SPAWN_JOGADOR_layout"] = [BRMatch.SPAWN_JOGADOR.x, BRMatch.SPAWN_JOGADOR.y]
	R["onde_o_jogo_spawna"] = "BRMatch.start_round/respawn: posição FIXA Vector2(-338,-348) (layout; mundo x=-338, z=+348), yaw 90 graus; respawn() usa o mesmo ponto (jogador sem aleatoriedade); spawns_for() devolve []; bots usam pontos_saque aleatórios."
	# 1) estado inicial como o jogo deixou (zumbis do diretor, emulando o fluxo real)
	await c.pq(3)
	var ini := medir(c, "inicial")
	R["inicial"] = ini
	var f := ""
	for k in 4:
		c.s.yaw = deg_to_rad(90.0 + 90.0 * k)
		await c.pq(2)
		f = await c.shot("spawn_dir%d" % (k * 90))
		if k == 0:
			ini["captura"] = f
	c.s.yaw = deg_to_rad(90.0)
	c.ev("spawn_inicial", {"ruim": ini.ruim})
	# 2) observa 6 s: zumbis percebem o jogador parado?
	var obs: Array = []
	var hp0: int = c.s.health
	for k in 6:
		await c.seg(1.0)
		var est := {}
		for z in c.zumbis():
			var nm := String(ZombieEnemy.State.keys()[z.state])
			est[nm] = int(est.get(nm, 0)) + 1
		obs.append(est)
	R["zumbis_6s_estados"] = obs
	R["dano_jogador_parado_6s"] = hp0 - c.s.health
	if hp0 - c.s.health > 0:
		c.achado("SPAWN_DANO_IMEDIATO", "alto", "Jogador leva dano nos primeiros 6 s parado no spawn", {"dano": hp0 - c.s.health}, "", "Spawn")
	# 3) 10 respawns (zumbis re-sorteados como numa partida nova: só os 2 de perto)
	var lista: Array = []
	var posicoes := {}
	for i in 10:
		if not c.vivo():
			break
		c.s.health = 100
		c.m.respawn(c.s)
		_redisparar_zumbis(c, 2)
		await c.fq(40)
		var r := medir(c, "respawn_%d" % (i + 1))
		lista.append(r)
		posicoes[str(r.pos[0]) + "," + str(r.pos[2])] = true
		if i == 0 or i == 5 or not r.bom:
			r["captura"] = await c.shot("respawn%d" % (i + 1))
	R["respawns"] = lista
	R["posicoes_distintas_nos_10_respawns"] = posicoes.size()
	var ruins := 0
	var causas := {}
	for r in lista + [ini]:
		if not r.bom:
			ruins += 1
		for t in r.ruim:
			var k := String(t).split(" (")[0].split(" a <")[0]
			causas[k] = int(causas.get(k, 0)) + 1
	R["spawns_ruins_de_11"] = ruins
	R["causas"] = causas
	if not ini.bom:
		c.achado("SPAWN_INICIAL_RUIM", "alto", "Spawn inicial reprovado: %s" % "; ".join(ini.ruim), {"pos": ini.pos, "ruim": ini.ruim, "declive": ini.declive_graus, "zumbi_mais_proximo_m": ini.zumbi_mais_proximo_m}, String(ini.get("captura", "")), "Spawn")
	if posicoes.size() == 1:
		c.achado("SPAWN_FIXO", "medio", "O jogador sempre nasce/renasce no MESMO ponto (10 respawns, 1 posição)", {"pos": lista[0].pos if not lista.is_empty() else ini.pos}, "", "Spawn")
	if ruins >= 3:
		c.achado("SPAWN_MUITOS_RUINS", "alto", "%d de %d medições de spawn reprovadas" % [ruins, lista.size() + 1], {"causas": causas}, "", "Spawn")
	# volta ao spawn limpo e remove os zumbis (as outras etapas partem de um mundo sem horda)
	c.limpa_zumbis()
	c.s.health = 100
	c.m.respawn(c.s)
	await c.fq(30)
	c.termina_etapa()
