extends Node
## Triagem barata de custo do mapa na partida (0 bots, sem vsync, 1024x768): contagem de nós por grupo e A/B
## (desliga colisão e/ou esconde cada grupo) medindo quadro, física e draws. Jogador anda em círculo na Vila.
## Saída: linhas TRI_* e TRI_JSON {...}.

var R := {}


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var s: Soldier = m.local_player
	for i in 90:
		await get_tree().process_frame
	var ilha: Node = m.ilha
	var grupos := {}
	for c in ilha.get_children():
		grupos[String(c.name)] = [c]
	var det := ilha.get_node_or_null("Detalhes")
	if det:
		var novas: Array = det.get_children().filter(func(n): return n.has_meta("atualizacao"))
		var pontes := det.get_node_or_null("Pontes")
		if pontes:
			novas.append(pontes)
		grupos["cenario_atualizacao"] = novas
	# móveis do pack interiores (filhos dos prédios do Blockout)
	var moveis: Array = []
	var blk := ilha.get_node_or_null("Blockout")
	if blk:
		for mi in blk.find_children("*", "MeshInstance3D", true, false):
			var me: Mesh = (mi as MeshInstance3D).mesh
			if me and (String(me.resource_path).contains("interiores") or String(mi.name).begins_with("Movel")):
				moveis.append(mi)
	grupos["moveis_interiores(malhas)"] = moveis
	grupos["Veiculos"] = ilha.find_children("*", "VehicleBody3D", true, false)
	print("TRI_VEICULOS ", grupos["Veiculos"].size())
	var cont := {}
	for g in grupos:
		var nos := 0
		var sb := 0
		var cs := 0
		var mi := 0
		for raiz in grupos[g]:
			var todos: Array = [raiz] + (raiz as Node).find_children("*", "", true, false)
			nos += todos.size()
			for n in todos:
				if n is StaticBody3D: sb += 1
				elif n is CollisionShape3D: cs += 1
				elif n is MeshInstance3D: mi += 1
		cont[g] = {"nos": nos, "static": sb, "shapes": cs, "malhas": mi}
		print("TRI_CONT %-28s nos=%6d static=%5d shapes=%5d malhas=%5d" % [g, nos, sb, cs, mi])
	R["contagem"] = cont
	R["nos_total"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	await _medir(m, s, "aquecimento")
	R["base"] = await _medir(m, s, "base")
	var ab := {}
	for g in (String(Game.test_args.get("grupos", "ZombieDirector,cenario_atualizacao,Detalhes,Vegetacao,Blockout,Coberturas"))).split(","):
		if not grupos.has(g):
			continue
		var formas: Array = []
		var vis: Array = []
		for raiz in grupos[g]:
			var todos: Array = [raiz] + (raiz as Node).find_children("*", "", true, false)
			for n in todos:
				if n is CollisionShape3D and not n.disabled:
					formas.append(n)
				if n is Node3D and n.visible and (n == raiz):
					vis.append(n)
		for f in formas:
			f.disabled = true
		var sem_col := await _medir(m, s, g + "_sem_colisao")
		for n in vis:
			n.visible = false
		var sem_tudo := await _medir(m, s, g + "_sem_colisao_e_visual")
		for f in formas:
			f.disabled = false
		for n in vis:
			n.visible = true
		ab[g] = {"sem_colisao": sem_col, "sem_colisao_e_visual": sem_tudo, "shapes": formas.size()}
	R["ab"] = ab
	print("TRI_JSON ", JSON.stringify(R))
	get_tree().quit()


func _medir(m: Node, s: Soldier, nome: String) -> Dictionary:
	var c := Vector3(BRMatch.SPAWN_JOGADOR.x, 0, -BRMatch.SPAWN_JOGADOR.y)
	for i in 15:
		await get_tree().process_frame
	# só mede com a GPU livre: espera até não haver outro Godot além deste (console + janela)
	for tent in 120:
		var saida: Array = []
		OS.execute("tasklist", ["/FI", "IMAGENAME eq Godot*", "/NH"], saida)
		var k := String(saida[0] if saida.size() > 0 else "").countn("godot")
		if k <= 2:
			break
		if tent == 0:
			print("TRI_ESPERA outros Godot rodando (%d processos)" % k)
		await get_tree().create_timer(2.0).timeout
	for i in 10:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var n := 0
	var fis := 0.0
	var pior := 0.0
	var ult := t0
	while Time.get_ticks_usec() - t0 < 4000000:
		# anda em círculo de 12 m em volta do nascimento (corpo real, física real)
		var ang := (Time.get_ticks_usec() - t0) / 4000000.0 * TAU
		var alvo := c + Vector3(cos(ang), 0, sin(ang)) * 12.0
		var d := alvo - s.global_position
		d.y = 0
		s.yaw = atan2(-d.x, -d.z)
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		pior = maxf(pior, (agora - ult) / 1000.0)
		ult = agora
		fis += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	var r := {"ms": snappedf(ms, 0.01), "fisica_ms": snappedf(fis / n, 0.01), "pior_ms": snappedf(pior, 0.1),
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"prims": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
	print("TRI_MED %-40s %s" % [nome, r])
	return r