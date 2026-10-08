extends Node
## DESEMPENHO 2 — triagem barata: partida real (0 bots, sem vsync, 1024x768), jogador andando em círculo de 12 m no
## nascimento. Mede 4 s por configuração: quadro, física, GPU, draws, prims. A/B por sistema (desliga e religa).
## Uso: godot --path game res://tests/perf_d2.tscn -- [--itens=a,b,c] [--seg=4]
## Saída: linhas D2_* e D2_JSON {...} (também raw/triagem/perf_d2_<tag>.json).

var R := {}
var m: BRMatch
var s: Soldier
var seg := 4.0


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	seg = float(Game.test_args.get("seg", "4"))
	DisplayServer.window_set_size(Vector2i(1024, 768))
	get_tree().create_timer(190.0, true, false, true).timeout.connect(func() -> void: print("D2_TIMEOUT ", JSON.stringify(R)); get_tree().quit(2))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	s = m.local_player
	for i in 60:
		await get_tree().process_frame
	var ilha: Node = m.ilha
	var zd := ilha.get_node_or_null("ZombieDirector")
	R["zumbis"] = zd.get_child_count() if zd else 0
	R["casa_trimesh_tris"] = CasaPacote._colisao.get_faces().size() / 3 if CasaPacote._colisao else -1
	R["casa_formas"] = CasaPacote._colisao.get_class() if CasaPacote._colisao else ""
	R["casas"] = get_tree().get_nodes_in_group("casa_pacote").size()
	R["veiculos"] = get_tree().get_nodes_in_group("drivable_vehicle").size()
	var blk := ilha.get_node_or_null("Blockout")
	var cont_blk := {"static": 0, "shapes": 0, "malhas": 0, "trimesh": 0, "trimesh_tris": 0}
	if blk:
		for n in blk.find_children("*", "", true, false):
			if n is StaticBody3D: cont_blk.static += 1
			elif n is CollisionShape3D:
				cont_blk.shapes += 1
				if (n as CollisionShape3D).shape is ConcavePolygonShape3D:
					cont_blk.trimesh += 1
					cont_blk.trimesh_tris += ((n as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size() / 3
			elif n is MeshInstance3D: cont_blk.malhas += 1
	R["blockout"] = cont_blk
	var veg := ilha.get_node_or_null("Vegetacao")
	var filhos := []
	for c in ilha.get_children():
		filhos.append(String(c.name))
	R["filhos_ilha"] = filhos
	R["msaa"] = get_viewport().msaa_3d
	R["janela"] = str(DisplayServer.window_get_size())
	R["escala3d"] = get_viewport().scaling_3d_scale
	R["vegetacao_mmi"] = veg.find_children("*", "MultiMeshInstance3D", true, false).size() if veg else 0
	await _medir("aquecimento")
	R["base"] = await _medir("base")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../raw/triagem/perf_d2_%s.png" % String(Game.test_args.get("tag", "tri"))))
	var itens := String(Game.test_args.get("itens", "zumbi_off,zumbi_ia_off,zumbi_anim_off,veiculos_off,blockout_col_off,blockout_vis_off,moveis_vis_off,veg_vis_off,veg_sombra_off,capim_off,detalhes_vis_off,sol_sombra_off")).split(",")
	var ab := {}
	for it in itens:
		var desfazer: Callable = _aplicar(it)
		if desfazer.is_null():
			continue
		ab[it] = await _medir(it)
		desfazer.call()
	R["ab"] = ab
	if Game.test_args.has("percepcao"):
		R["percepcao"] = await _teste_percepcao()
	if Game.test_args.has("ataque"):
		R["ataque"] = await _teste_ataque()
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("perf_d2_%s.json" % String(Game.test_args.get("tag", "tri"))), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("D2_JSON ", JSON.stringify(R))
	get_tree().quit()


func _aplicar(it: String) -> Callable:
	var ilha: Node = m.ilha
	var zd := ilha.get_node_or_null("ZombieDirector")
	var blk := ilha.get_node_or_null("Blockout")
	var veg := ilha.get_node_or_null("Vegetacao")
	if it.begins_with("esconder_"):
		var no := ilha.get_node_or_null(it.trim_prefix("esconder_"))
		if no == null or not no is Node3D: return Callable()
		no.visible = false
		return func() -> void: no.visible = true
	match it:
		"msaa_off":
			var vp2 := get_viewport()
			var a2 := vp2.msaa_3d
			vp2.msaa_3d = Viewport.MSAA_DISABLED
			return func() -> void: vp2.msaa_3d = a2
		"escala_meia":
			var vp := get_viewport()
			var antes := vp.scaling_3d_scale
			vp.scaling_3d_scale = 0.5
			return func() -> void: vp.scaling_3d_scale = antes
		"zumbi_off":
			if zd == null: return Callable()
			zd.process_mode = Node.PROCESS_MODE_DISABLED
			zd.visible = false
			var camadas := {}
			for z in zd.get_children():
				camadas[z] = z.collision_layer
				z.collision_layer = 0
			return func() -> void:
				zd.process_mode = Node.PROCESS_MODE_INHERIT
				zd.visible = true
				for z in camadas: z.collision_layer = camadas[z]
		"zumbi_ia_off":
			if zd == null: return Callable()
			for z in zd.get_children(): z.set_physics_process(false)
			return func() -> void:
				for z in zd.get_children(): z.set_physics_process(true)
		"zumbi_anim_off":
			if zd == null: return Callable()
			var nos: Array = zd.find_children("*", "AnimationMixer", true, false) + zd.find_children("*", "SkeletonModifier3D", true, false)
			for n in nos: n.set("active", false)
			return func() -> void:
				for n in nos: n.set("active", true)
		"veiculos_off":
			var vs := get_tree().get_nodes_in_group("drivable_vehicle")
			for v in vs: (v as Node).process_mode = Node.PROCESS_MODE_DISABLED
			return func() -> void:
				for v in vs: (v as Node).process_mode = Node.PROCESS_MODE_INHERIT
		"blockout_col_off":
			if blk == null: return Callable()
			var fs: Array = []
			for n in blk.find_children("*", "CollisionShape3D", true, false):
				if not n.disabled and not _e_chao(n):
					fs.append(n)
					n.disabled = true
			return func() -> void:
				for n in fs: n.disabled = false
		"blockout_vis_off":
			if blk == null: return Callable()
			blk.visible = false
			return func() -> void: blk.visible = true
		"moveis_vis_off":
			if blk == null: return Callable()
			var ms: Array = []
			for mi in blk.find_children("*", "GeometryInstance3D", true, false):
				var me: Mesh = (mi as MeshInstance3D).mesh if mi is MeshInstance3D else null
				if String(mi.name).begins_with("Movel") or (me and String(me.resource_path).contains("interiores")) or String(mi.get_parent().name).begins_with("Movel"):
					if mi.visible:
						ms.append(mi)
						mi.visible = false
			R["moveis_malhas"] = ms.size()
			return func() -> void:
				for n in ms: n.visible = true
		"veg_vis_off":
			if veg == null: return Callable()
			veg.visible = false
			return func() -> void: veg.visible = true
		"veg_sombra_off":
			if veg == null: return Callable()
			var antes := {}
			for g in veg.find_children("*", "GeometryInstance3D", true, false):
				antes[g] = g.cast_shadow
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return func() -> void:
				for g in antes: g.cast_shadow = antes[g]
		"capim_off":
			var c := ilha.get_node_or_null("Capim")
			if c == null: return Callable()
			c.visible = false
			return func() -> void: c.visible = true
		"detalhes_vis_off":
			var d := ilha.get_node_or_null("Detalhes")
			if d == null: return Callable()
			d.visible = false
			return func() -> void: d.visible = true
		"sol_sombra_off":
			var ls: Array = []
			for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
				if l.shadow_enabled:
					ls.append(l)
					l.shadow_enabled = false
			return func() -> void:
				for l in ls: l.shadow_enabled = true
	return Callable()


## Prova: distribuição de LOD dos zumbis e um zumbi colocado a 3 m na frente do jogador acha, persegue e ataca.
func _teste_ataque() -> Dictionary:
	var zd := m.ilha.get_node_or_null("ZombieDirector")
	var r := {}
	if zd == null or zd.get_child_count() == 0:
		return {"erro": "sem zumbis"}
	var lods := [0, 0, 0]
	for z in zd.get_children():
		lods[clampi(int(z.lod), 0, 2)] += 1
	r["lods_0_1_2"] = lods
	r["jogador_alvo"] = s.is_in_group("zombie_targets")
	# o zumbi mais longe (dormindo) é trazido para perto: precisa acordar (LOD 0) e atacar
	var longe: ZombieEnemy = null
	var dmax := -1.0
	for z in zd.get_children():
		var d := (z as Node3D).global_position.distance_to(s.global_position)
		if d > dmax and (z as ZombieEnemy).state != ZombieEnemy.State.DEAD:
			dmax = d
			longe = z
	r["lod_antes"] = longe.lod
	r["dist_antes_m"] = snappedf(dmax, 0.1)
	var golpes := [0]
	longe.attacked.connect(func(alvo, dano): if alvo == s: golpes[0] += 1)
	var vida0 := s.health
	var frente := -s.global_basis.z
	frente.y = 0
	longe.global_position = s.global_position + frente.normalized() * 3.0 + Vector3.UP * 0.2
	longe.rotation.y = atan2(frente.x, frente.z)   # olhando para o jogador
	longe.call("_set_state", ZombieEnemy.State.IDLE)   # parado de frente (em patrulha ele vira para o destino e não vê)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var q := PhysicsRayQueryParameters3D.create(longe.global_position + Vector3.UP * 1.35, s.global_position + Vector3.UP * 1.15)
	q.exclude = [longe.get_rid()]
	var hit := longe.get_world_3d().direct_space_state.intersect_ray(q)
	r["raio_bate_em"] = str(hit.get("collider").get_path()) if not hit.is_empty() else "nada"
	r["ve_jogador_t0"] = longe._can_see_target(s)
	var to := s.global_position - longe.global_position
	to.y = 0
	r["dot_frente"] = snappedf((-longe.global_basis.z).normalized().dot(to.normalized()), 0.01)
	var t0 := Time.get_ticks_msec()
	var t_golpe := -1
	while Time.get_ticks_msec() - t0 < 8000:
		await get_tree().physics_frame
		if golpes[0] > 0 and t_golpe < 0:
			t_golpe = Time.get_ticks_msec() - t0
	r["lod_depois"] = longe.lod
	r["estado"] = String(ZombieEnemy.State.keys()[longe.state])
	r["golpes_8s"] = golpes[0]
	r["ms_ate_1o_golpe"] = t_golpe
	r["vida_jogador"] = [vida0, s.health]
	r["ok"] = golpes[0] > 0 and longe.lod == 0
	print("D2_ATAQUE ", r)
	return r


## Percepção (pedido do QA): A) zumbi em PATROL 6 m ATRÁS do jogador parado -> ataca em <= 4 s (ouve passos);
## B) zumbi parado a 25 m, de costas, ouve um tiro (Audio.emitir_barulho com raio de pistola) -> chega e ataca.
## Também mede a física durante os cenários.
func _teste_percepcao() -> Dictionary:
	var zd := m.ilha.get_node_or_null("ZombieDirector")
	var r := {}
	var livres: Array = []
	for z in zd.get_children():
		if (z as ZombieEnemy).state != ZombieEnemy.State.DEAD and z.global_position.distance_to(s.global_position) > 200.0:
			livres.append(z)
	# o nascimento fica no adro elevado (4 m acima da rua): leva o jogador para um chão aberto e plano perto dali
	r["jogador_em"] = str(await _chao_aberto())
	r["A_atras_6m"] = await _cenario(livres[0], 6.0, false, 4.0)
	await get_tree().create_timer(0.5).timeout
	r["B_tiro_25m"] = await _cenario(livres[1], 25.0, true, 20.0)
	r["ok"] = bool(r.A_atras_6m.ok) and bool(r.B_tiro_25m.ok)
	print("D2_PERCEPCAO ", r)
	return r


func _chao_aberto() -> Vector3:
	var space := s.get_world_3d().direct_space_state
	var terr: Node = m.ilha.terrain
	var c := s.global_position
	var tras := Vector3(sin(s.yaw), 0.0, cos(s.yaw))
	for raio in [15.0, 30.0, 45.0, 60.0, 80.0, 100.0, 130.0, 160.0, 200.0]:
		for k in 16:
			var a := TAU * k / 16.0
			var p: Vector3 = c + Vector3(cos(a), 0, sin(a)) * raio
			p.y = terr.height_world(p.x, p.z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 3.0, 1))
			if hit.is_empty() or not (hit.collider is Node and terr.is_ancestor_of(hit.collider)):
				continue
			var livre := true
			for d in [6.5, 25.0]:   # caminho livre e plano até 6,5 m e 25 m atrás do jogador
				var q: Vector3 = p + tras * d
				q.y = terr.height_world(q.x, q.z)
				if absf(q.y - p.y) > 1.2:
					livre = false
				for h in [0.35, 1.0]:
					if not space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * h, q + Vector3.UP * h, 1)).is_empty():
						livre = false
			if livre:
				s.global_position = p + Vector3.UP * 0.1
				s.reset_physics_interpolation()
				for i in 20:
					await get_tree().physics_frame
				return s.global_position
	return s.global_position


func _cenario(z: ZombieEnemy, dist: float, tiro: bool, limite: float) -> Dictionary:
	s.health = 100
	var tras := Vector3(sin(s.yaw), 0.0, cos(s.yaw))   # atrás do jogador (frente = -Z girado pelo yaw)
	tras.y = 0
	tras = tras.normalized()
	var space := s.get_world_3d().direct_space_state
	var dirs: Array = []
	for k in 16:
		dirs.append(tras.rotated(Vector3.UP, (k / 2 + 1) * 0.35 * (1 if k % 2 == 0 else -1)) if k > 0 else tras)
	var pos := s.global_position + tras * dist
	for d in dirs:
		var p: Vector3 = s.global_position + (d as Vector3) * dist
		p.y = m.ilha.terrain.height_world(p.x, p.z)
		var q := PhysicsRayQueryParameters3D.create(s.global_position + Vector3.UP * 1.0, p + Vector3.UP * 1.0, 1, [s.get_rid()])
		var q2 := PhysicsRayQueryParameters3D.create(s.global_position + Vector3.UP * 0.35, p + Vector3.UP * 0.35, 1, [s.get_rid()])
		if Game.test_args.has("caminho_livre") and not space.intersect_ray(q2).is_empty():
			continue
		if space.intersect_ray(q).is_empty() and absf(p.y - s.global_position.y) < 2.0 and (d as Vector3).dot(tras) > 0.3:
			pos = p
			break
	z.global_position = pos + Vector3.UP * 0.1
	var fora := pos - s.global_position
	z.rotation.y = atan2(-fora.x, -fora.z)   # de costas para o jogador (olha para longe)
	z.reset_physics_interpolation()
	if tiro:
		z.call("_set_state", ZombieEnemy.State.IDLE)
		z.begin_roaming(30.0)
	else:
		z.call("_set_state", ZombieEnemy.State.PATROL)
	var golpes := [0]
	var cb := func(alvo, _dano): if alvo == s: golpes[0] += 1
	z.attacked.connect(cb)
	await get_tree().physics_frame
	if tiro:
		Audio.emitir_barulho(s.global_position, 400.0, s)   # raio da glock em tiro_som.gd
	var t0 := Time.get_ticks_msec()
	var t_golpe := -1.0
	var fis := 0.0
	var n := 0
	var estados := []
	var dmin := INF
	while Time.get_ticks_msec() - t0 < int(limite * 1000.0):
		await get_tree().process_frame
		fis += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
		dmin = minf(dmin, z.global_position.distance_to(s.global_position))
		var e := String(ZombieEnemy.State.keys()[z.state])
		if estados.is_empty() or estados[-1] != e:
			estados.append(e)
		if golpes[0] > 0:
			t_golpe = (Time.get_ticks_msec() - t0) / 1000.0
			break
	z.attacked.disconnect(cb)
	var diag := {"z": str(z.global_position.snappedf(0.1)), "s": str(s.global_position.snappedf(0.1)), "chao": z.is_on_floor()}
	for h in [0.3, 0.8, 1.3, 1.9]:
		var qq := PhysicsRayQueryParameters3D.create(z.global_position + Vector3.UP * h, s.global_position + Vector3.UP * h, 0xFFFFFFFF, [z.get_rid()])
		var hh := space.intersect_ray(qq)
		diag["h%.1f" % h] = (String(hh.collider.name) + "@" + str((hh.position as Vector3).distance_to(z.global_position)).left(4)) if not hh.is_empty() else "livre"

	var res := {"dist_m": snappedf(pos.distance_to(s.global_position), 0.1), "atras_dot": snappedf((pos - s.global_position).normalized().dot(tras), 0.01), "dist_final_m": snappedf(z.global_position.distance_to(s.global_position), 0.1), "dist_min_m": snappedf(dmin, 0.1),
		"s_ate_golpe": snappedf(t_golpe, 0.01), "estados": estados, "lod": z.lod, "diag": diag, "fisica_ms": snappedf(fis / maxf(1, n), 0.01), "ok": t_golpe > 0.0 and t_golpe <= limite}
	z.global_position += Vector3(0, 0, 400)   # tira da cena para o próximo cenário
	z.call("_set_state", ZombieEnemy.State.IDLE)
	z.target = null
	return res


func _e_chao(n: Node) -> bool:
	return false


func _medir(nome: String) -> Dictionary:
	var c := Vector3(BRMatch.SPAWN_JOGADOR.x, 0, -BRMatch.SPAWN_JOGADOR.y)
	for i in 10:
		await get_tree().process_frame
	for tent in (0 if Game.test_args.has("sem_espera") else 120):
		var saida: Array = []
		OS.execute("tasklist", ["/FI", "IMAGENAME eq Godot*", "/NH"], saida)
		var k := String(saida[0] if saida.size() > 0 else "").countn("godot")
		if k <= 2:
			break
		if tent == 0:
			print("D2_ESPERA outros Godot rodando (%d processos)" % k)
		await get_tree().create_timer(2.0).timeout
	for i in 8:
		await get_tree().process_frame
	var vr := get_viewport().get_viewport_rid()
	var t0 := Time.get_ticks_usec()
	var n := 0
	var fis := 0.0
	var gpu := 0.0
	var pior := 0.0
	var ult := t0
	var draws := 0
	var prims := 0
	while Time.get_ticks_usec() - t0 < int(seg * 1e6):
		var ang := (Time.get_ticks_usec() - t0) / (seg * 1e6) * TAU
		var alvo := c + Vector3(cos(ang), 0, sin(ang)) * 12.0
		var d := alvo - s.global_position
		d.y = 0
		s.yaw = atan2(-d.x, -d.z)
		Input.action_press("move_forward")
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		pior = maxf(pior, (agora - ult) / 1000.0)
		ult = agora
		fis += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vr)
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	Input.action_release("move_forward")
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	var r := {"ms": snappedf(ms, 0.01), "fisica_ms": snappedf(fis / n, 0.01), "gpu_ms": snappedf(gpu / n, 0.01), "pior_ms": snappedf(pior, 0.1),
		"draws": draws / n, "prims": prims / n}
	print("D2_MED %-22s %s" % [nome, r])
	return r
