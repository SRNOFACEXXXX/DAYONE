extends RefCounted
## Etapa ZUMBI: 3 zumbis a 25 m; atira em um (corpo e cabeça), mede morte, cadáver (altura do chão / flutuando), sons, perseguição e dano.
const U := preload("res://tests/playtest/pt_util.gd")
const ESTADOS := ["IDLE", "PATROL", "ALERT", "INVESTIGATE", "CHASE", "ATTACK", "DEAD"]


static func _nome(z) -> String:
	return String(ZombieEnemy.State.keys()[z.state])


## Ponto mais baixo da malha com skinning calculado na CPU (pose atual). Devolve {y_min, n_vertices} ou {} se falhar.
static func malha_mais_baixa(z: Node3D) -> Dictionary:
	var ymin := INF
	var n := 0
	for mi in z.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var sk: Skeleton3D = m.get_node_or_null(m.skeleton) as Skeleton3D
		var skin: Skin = m.skin
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if vs.is_empty():
				continue
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if sk == null or bones == null or weights == null or (bones as PackedInt32Array).is_empty():
				for v in vs:
					ymin = minf(ymin, (m.global_transform * v).y)
					n += 1
				continue
			var stride := (bones as PackedInt32Array).size() / vs.size()
			# matriz de skinning por osso do skin (ou do esqueleto, se não houver skin)
			var nb := skin.get_bind_count() if skin else sk.get_bone_count()
			var mats: Array[Transform3D] = []
			for b in nb:
				var bi := b
				var bind := Transform3D.IDENTITY
				if skin:
					bi = skin.get_bind_bone(b)
					if bi < 0:
						bi = sk.find_bone(skin.get_bind_name(b))
					bind = skin.get_bind_pose(b)
				else:
					bind = sk.get_bone_global_rest(b).affine_inverse()
				if bi < 0:
					mats.append(Transform3D.IDENTITY)
				else:
					mats.append(sk.get_bone_global_pose(bi) * bind)
			var gt := sk.global_transform
			for i in vs.size():
				var acc := Vector3.ZERO
				var ws := 0.0
				for k in stride:
					var w: float = weights[i * stride + k]
					if w <= 0.0:
						continue
					var bidx: int = bones[i * stride + k]
					if bidx >= mats.size():
						continue
					acc += (mats[bidx] * vs[i]) * w
					ws += w
				if ws <= 0.0:
					acc = vs[i]
				else:
					acc /= ws
				ymin = minf(ymin, (gt * acc).y)
				n += 1
	if ymin == INF:
		return {}
	return {"y_min": ymin, "n_vertices": n}


static func _chao_cadaver(c, z: Node3D) -> float:
	return c.chao_em(z.global_position.x, z.global_position.z, z.global_position.y + 3.0)


static func _foto_cadaver(c, z: Node3D, tag: String, chao: float) -> Array:
	var cam := Camera3D.new()
	c.m.add_child(cam)
	var centro := Vector3(z.global_position.x, chao + 0.25, z.global_position.z)
	var lado: Vector3 = z.global_basis.x.normalized()
	cam.global_position = centro + lado * 3.4 + Vector3(0, 0.1, 0)
	cam.look_at(centro, Vector3.UP)
	cam.fov = 50.0
	cam.make_current()
	await c.pq(3)
	var f1: String = await c.shot(tag)
	# plano vermelho translúcido no nível do chão físico: mostra a folga entre o corpo e o chão
	var mk := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.0, 5.0)
	mk.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.1, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mk.material_override = mat
	c.m.add_child(mk)
	mk.global_position = Vector3(z.global_position.x, chao + 0.003, z.global_position.z)
	await c.pq(3)
	var f2: String = await c.shot(tag + "_plano_chao")
	mk.queue_free()
	cam.queue_free()
	c.pc.camera.make_current()
	await c.pq(1)
	return [f1, f2]


static func _mede_cadaver(c, z: ZombieEnemy, rotulo: String) -> Dictionary:
	var R := {"rotulo": rotulo}
	var amostras: Array = []
	var t0: float = c.tempo()
	for tt in [0.4, 1.2, 2.5, 4.0]:
		while c.tempo() - t0 < tt and c.vivo():
			await c.fq(2)
		var mb := malha_mais_baixa(z)
		var ch := _chao_cadaver(c, z)
		if mb.is_empty():
			amostras.append({"t": tt, "erro": "sem malha"})
			continue
		var ht: float = c.terr.height_world(z.global_position.x, z.global_position.z)
		amostras.append({"t": tt, "malha_min_y": snappedf(mb.y_min, 0.001), "chao_y": snappedf(ch, 0.001), "terreno_y": snappedf(ht, 0.001),
			"folga_m": snappedf(mb.y_min - ch, 0.001), "folga_terreno_m": snappedf(mb.y_min - ht, 0.001),
			"origem_acima_chao_m": snappedf(z.global_position.y - ch, 0.001), "n_vertices": mb.n_vertices})
	R["amostras"] = amostras
	var ult: Dictionary = amostras[amostras.size() - 1] if not amostras.is_empty() else {}
	R["folga_final_m"] = ult.get("folga_m", null)
	var chao_f: float = _chao_cadaver(c, z)
	var fs: Array = await _foto_cadaver(c, z, "cadaver_" + rotulo, chao_f)
	var f: String = fs[0]
	R["captura"] = f
	R["captura_com_plano_do_chao"] = fs[1]
	if ult.has("folga_m") and float(ult.folga_m) > 0.05:
		c.achado("ZUMBI_FLUTUANDO_" + rotulo, "critico", "Cadáver flutua: parte mais baixa da malha %.0f cm acima do chão (limite 5 cm) %.1f s após morrer" % [float(ult.folga_m) * 100.0, ult.t],
			{"folga_m": ult.folga_m, "amostras": amostras}, f, "Zumbis visual")
	elif ult.has("folga_m") and float(ult.folga_m) < -0.15:
		c.achado("ZUMBI_ENTERRADO_" + rotulo, "alto", "Cadáver enterrado no chão (%.0f cm abaixo)" % (-float(ult.folga_m) * 100.0), {"folga_m": ult.folga_m}, f, "Zumbis visual")
	return R


static func run(c) -> void:
	c.comeca_etapa("zumbi", 150.0)
	var s: Soldier = c.s
	var R := {}
	c.metricas["zumbi"] = R
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	c.solta_entradas()
	c.limpa_zumbis()
	s.health = 100
	U.equipa(c, "ak47")
	await c.seg(1.8)
	# posto: spawn do jogo; zumbis a 25 m em arco à frente com visada livre
	var base := s.global_position
	var bd: Dictionary = U.melhor_direcao(c, base, 60.0)
	var dir: Vector3 = bd.dir
	s.yaw = U.yaw_de(dir)
	s.pitch = 0.0
	var zs: Array = []
	var ang_list := [0.0, -0.45, 0.45, -0.8, 0.8, -0.2, 0.2, -1.1, 1.1, -1.5, 1.5]
	for a in ang_list:
		if zs.size() >= 3:
			break
		var d2 := dir.rotated(Vector3.UP, a)
		var pos := base + d2 * 25.0
		if U.livre(c, base, d2, 25.0, 1.4) < 20.0:
			continue
		if absf(c.chao_em(pos.x, pos.z, base.y + 20.0) - base.y) > 3.0:
			continue
		var z: ZombieEnemy = c.cria_zumbi(pos, U.yaw_de(-d2))
		z.begin_roaming(0.3)
		zs.append(z)
	R["zumbis_criados"] = zs.size()
	if zs.size() < 3:
		c.achado("ZUMBI_SEM_ESPACO", "baixo", "Só %d zumbis puderam ser colocados a 25 m com visada livre" % zs.size(), {}, "", "Zumbis IA")
	if zs.is_empty():
		c.termina_etapa()
		return
	await c.fq(30)
	# observadores
	var log_estados: Array = []
	var transicoes: Array = []
	var t0: float = c.tempo()
	var i_ev0: int = c.audio_ev.size()
	var primeira := {}
	for z in zs:
		var zz: ZombieEnemy = z
		var cb := func(nome: StringName) -> void:
			var d := Vector2(zz.global_position.x - s.global_position.x, zz.global_position.z - s.global_position.z).length() if is_instance_valid(zz) else -1.0
			transicoes.append({"t": snappedf(c.tempo() - t0, 0.01), "zumbi": zz.name, "estado": String(nome), "dist_m": snappedf(d, 0.1), "i_audio": c.audio_ev.size()})
			if not primeira.has(String(nome) + zz.name):
				primeira[String(nome) + zz.name] = true
				if String(nome) in ["alert", "chase", "attack", "dead"] and transicoes.size() < 14:
					c.shot("zumbi_%s_%s" % [String(nome), zz.name])
		zz.state_changed.connect(cb)
	var danos: Array = []
	var dcb := func(amount: int, _att: Variant, _dir: Vector3) -> void: danos.append({"t": snappedf(c.tempo() - t0, 0.01), "dano": amount})
	s.damaged.connect(dcb)
	var ataques: Array = []
	for z in zs:
		var zz2: ZombieEnemy = z
		zz2.attacked.connect(func(_t: Node3D, dmg: int) -> void: ataques.append({"t": snappedf(c.tempo() - t0, 0.01), "zumbi": zz2.name, "dano": dmg}))
	c.shot("zumbis_a_25m")
	# 1) 2 s observando (sem atirar)
	await c.seg(2.0)
	var alvo: ZombieEnemy = zs[0]
	R["estado_alvo_antes_do_tiro"] = _nome(alvo)
	# 2) um tiro no corpo
	c.olha(alvo.global_position + Vector3.UP * 1.0)
	await c.fq(6)
	var hit_info := {}
	var hcb := func(zone: StringName, amount: int, _a: Node3D) -> void: hit_info[String(zone)] = amount
	alvo.hit_taken.connect(hcb)
	var tiros_corpo := 0
	while not hit_info.has("body") and tiros_corpo < 4 and c.vivo() and alvo.state != ZombieEnemy.State.DEAD:
		var m0: int = s.current().mag
		var tries := 0
		while s.current().mag == m0 and tries < 60 and c.vivo():
			tries += 1
			c.olha(alvo.global_position + Vector3.UP * 1.0)
			Input.action_press("fire")
			await c.fq(2)
			Input.action_release("fire")
			await c.fq(2)
		tiros_corpo += 1
		await c.seg(0.5)   # tempo de voo da bala
	R["tiro_corpo"] = {"hit": hit_info.duplicate(), "tiros_ate_acertar": tiros_corpo, "vida_alvo": alvo.health, "estado": _nome(alvo)}
	if hit_info.is_empty():
		c.achado("ZUMBI_TIRO_CORPO_NAO_ACERTOU", "medio", "Tiro no corpo a 25 m (mira perfeita) não acertou o zumbi", R["tiro_corpo"], "", "Zumbis IA")
	# 3) cabeças até morrer
	var tiros_cabeca := 0
	var t_morte := -1.0
	var tg: float = c.tempo()
	while alvo.state != ZombieEnemy.State.DEAD and tiros_cabeca < 8 and c.vivo():
		c.olha(alvo.global_position + Vector3.UP * 1.72)
		await c.fq(4)
		Input.action_press("fire")
		await c.fq(2)
		Input.action_release("fire")
		tiros_cabeca += 1
		await c.seg(0.5)
	if alvo.state == ZombieEnemy.State.DEAD:
		t_morte = c.tempo() - tg
	alvo.hit_taken.disconnect(hcb)
	R["tiro_cabeca"] = {"hit": hit_info.duplicate(), "tiros_ate_morrer": tiros_cabeca, "morreu": alvo.state == ZombieEnemy.State.DEAD, "mortes_emitidas": alvo.mortes_emitidas}
	if alvo.state != ZombieEnemy.State.DEAD:
		c.achado("ZUMBI_NAO_MORRE", "alto", "Zumbi não morreu após %d tiros de cabeça de AK" % tiros_cabeca, R["tiro_cabeca"], "", "Zumbis IA")
	else:
		R["cadaver_alvo"] = await _mede_cadaver(c, alvo, "alvo")
	# 4) perseguição e ataque (resto): observa até 14 s
	var obs_t: float = c.tempo()
	var min_d := 999.0
	var vel_chase: Array = []
	var ultd := {}
	while c.vivo() and c.tempo() - obs_t < 14.0:
		await c.seg(0.5)
		for z in zs:
			if not is_instance_valid(z) or z == alvo:
				continue
			var zz3: ZombieEnemy = z
			var d3 := Vector2(zz3.global_position.x - s.global_position.x, zz3.global_position.z - s.global_position.z).length()
			min_d = minf(min_d, d3)
			if ultd.has(zz3.name) and zz3.state == ZombieEnemy.State.CHASE:
				vel_chase.append((float(ultd[zz3.name]) - d3) / 0.5)
			ultd[zz3.name] = d3
		log_estados.append({"t": snappedf(c.tempo() - t0, 0.1), "estados": zs.map(func(z): return _nome(z) if is_instance_valid(z) else "?"), "hp_jogador": s.health})
		if s.health < 45:
			break
		if not ataques.is_empty() and ataques.size() >= 3:
			break
	R["perseguicao"] = {"menor_distancia_m": snappedf(min_d, 0.1), "vel_aproximacao_media": snappedf(_media(vel_chase), 0.01),
		"vel_aproximacao_max": snappedf(_max(vel_chase), 0.01), "log": log_estados}
	R["transicoes"] = transicoes
	R["ataques"] = ataques
	R["danos_ao_jogador"] = danos
	R["hp_jogador_final"] = s.health
	c.shot("zumbis_perto")
	# 5) mata os restantes (cabeça) para medir mais cadáveres
	var n_extra := 0
	for z in zs:
		if z == alvo or not is_instance_valid(z) or not c.vivo():
			continue
		var zz4: ZombieEnemy = z
		var g := 0
		while zz4.state != ZombieEnemy.State.DEAD and g < 12 and c.vivo():
			g += 1
			s.health = maxi(s.health, 60)
			c.olha(zz4.global_position + Vector3.UP * 1.72)
			await c.fq(3)
			Input.action_press("fire")
			await c.fq(2)
			Input.action_release("fire")
			await c.seg(0.45)
		if zz4.state == ZombieEnemy.State.DEAD and n_extra < 1:
			n_extra += 1
			R["cadaver_extra"] = await _mede_cadaver(c, zz4, "extra")
	s.damaged.disconnect(dcb)
	# --- sons de zumbi durante a etapa
	var ev_z: Array = []
	for k in range(i_ev0, c.audio_ev.size()):
		var e: Dictionary = c.audio_ev[k]
		if String(e.id).begins_with("zombie") or String(e.id).contains("groan") or String(e.id).contains("scream") or String(e.id).contains("zumbi"):
			ev_z.append(e)
	R["eventos_som_zumbi"] = ev_z.size()
	R["tem_zombie_groan"] = Audio.has_sound("zombie_groan")
	var por_estado := {}
	for tr in transicoes:
		var nome := String(tr.estado)
		var teve := false
		for e in c.audio_ev:
			if e.t >= float(tr.t) + t0 - 0.2 and e.t <= float(tr.t) + t0 + 1.5 and (String(e.id).begins_with("zombie") or String(e.id).contains("groan")):
				teve = true
		por_estado[nome] = int(por_estado.get(nome, 0)) + (1 if teve else 0)
	R["transicoes_com_som_de_zumbi"] = por_estado
	var estados_vistos := {}
	for tr in transicoes:
		estados_vistos[String(tr.estado)] = true
	for est in ["alert", "chase", "attack", "dead"]:
		if estados_vistos.has(est) and int(por_estado.get(est, 0)) == 0:
			c.achado("ZUMBI_MUDO_" + est.to_upper(), "critico" if est in ["alert", "attack"] else "alto",
				"Zumbi entrou em %s sem emitir som nenhum (zombie_groan existe? %s)" % [est.to_upper(), str(Audio.has_sound("zombie_groan"))],
				{"estado": est, "tem_zombie_groan": Audio.has_sound("zombie_groan"), "eventos_som_zumbi": ev_z.size()}, "", "Zumbis áudio")
	# --- IA/dano
	if not estados_vistos.has("chase"):
		c.achado("ZUMBI_NAO_PERSEGUE", "alto", "Nenhum zumbi entrou em CHASE após tiro a 25 m", {"transicoes": transicoes.slice(0, 8)}, "", "Zumbis IA")
	if estados_vistos.has("chase") and min_d > 3.0 and ataques.is_empty():
		c.achado("ZUMBI_NAO_CHEGA", "medio", "Zumbis perseguiram mas só chegaram a %.1f m em 14 s (sem ataque)" % min_d, R["perseguicao"], "", "Zumbis IA")
	if not ataques.is_empty() and danos.is_empty():
		c.achado("ZUMBI_ATAQUE_SEM_DANO", "alto", "Zumbi atacou %d vezes e o jogador não levou dano" % ataques.size(), {"ataques": ataques}, "", "Zumbis IA")
	R["quadros"] = c.resumo_quadros("zumbi")
	c.limpa_zumbis()
	s.health = 100
	c.solta_entradas()
	c.termina_etapa()


static func _media(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()


static func _max(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m
