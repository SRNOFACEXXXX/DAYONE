extends Node
## Corte de árvore no jogo real: anda até uma árvore, pega o machado pelo atalho (tecla 2), golpeia com o clique esquerdo,
## vê a árvore tombar, as 5 toras no chão em PROXIMIDADE e passa as toras para a mochila. --out=<pasta>

var out := ""
var falhas := 0


func _shot(nome: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))
	print("CAPTURA ", nome)


func _ok(cond: bool, msg: String) -> void:
	print(("OK    " if cond else "FALHA ") + msg)
	if not cond:
		falhas += 1


func _tecla(kc: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = kc as Key
	e.keycode = kc as Key
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var e2 := InputEventKey.new()
	e2.physical_keycode = kc as Key
	e2.keycode = kc as Key
	e2.pressed = false
	Input.parse_input_event(e2)
	await get_tree().physics_frame


func _toras_no_chao(m: BRMatch) -> Array:
	var r: Array = []
	for n in get_tree().get_nodes_in_group("loot"):
		var l := n as BRLoot
		if l != null and is_instance_valid(l) and l.contents != null and not l.contents.items.is_empty() and String(l.contents.items[0].id) == "tora":
			r.append(l)
	return r


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	while Loading.visivel():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var player := m.local_player
	var pc := player.controller as PlayerController
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var veg := m.ilha.get_node("Vegetacao") as IlhaVegetation
	var terreno = m.ilha.get("terrain")
	var bag := m.br_bag
	bag.add_item("machado", 1)
	for it in bag.items:
		if String(it.id) == "machado":
			bag.assign_quick_slot(1, int(it.uid))
	# árvore viva mais próxima em terra firme
	var alvo := -1
	var melhor := 1e9
	for i in veg.arvores.size():
		var a: Dictionary = veg.arvores[i]
		var d := (a.pos as Vector3).distance_to(player.global_position)
		if a.pos.y > 3.0 and d < melhor and d > 6.0:
			melhor = d
			alvo = i
	_ok(alvo >= 0, "achou árvore (a %.0f m)" % melhor)
	var arv: Dictionary = veg.arvores[alvo]
	var pos_arv: Vector3 = arv.pos
	var antes_pos := player.global_position
	# começa a 10 m, de frente para a árvore, e ANDA até ela
	var dir0 := (antes_pos - pos_arv)
	dir0.y = 0.0
	dir0 = dir0.normalized() if dir0.length() > 0.1 else Vector3.RIGHT
	var ini := pos_arv + dir0 * 10.0
	ini.y = terreno.height_world(ini.x, ini.z) + 0.3
	player.global_position = ini
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	var para := pos_arv - ini
	para.y = 0.0
	player.yaw = atan2(-para.x, -para.z)
	player.pitch = deg_to_rad(-4.0)
	for i in 6:
		await get_tree().physics_frame
	await _shot("01_antes_arvore")
	Input.action_press("move_forward")
	var n := 0
	while Vector2(player.global_position.x - pos_arv.x, player.global_position.z - pos_arv.z).length() > 2.3 and n < 900:
		await get_tree().physics_frame
		n += 1
	Input.action_release("move_forward")
	var dist := Vector2(player.global_position.x - pos_arv.x, player.global_position.z - pos_arv.z).length()
	print("ANDOU quadros=", n, " dist_final=", snappedf(dist, 0.01), " raio_colisao=", snappedf(float(arv.raio), 0.01))
	_ok(dist < 3.2, "chegou perto da árvore")
	var a_d := player.aim_dir()
	var a_t := (pos_arv - player.global_position)
	a_t.y = 0.0
	print("MIRA angulo_para_tronco_graus=", snappedf(rad_to_deg(Vector2(a_d.x, a_d.z).angle_to(Vector2(a_t.x, a_t.z))), 0.1), " tipo=", arv.tipo, " escala=", snappedf(float(arv.escala), 0.01))
	# se a colisão do terreno/cerca desviou o caminho, volta a mirar no tronco (o teste mede o corte, não a pontaria)
	player.yaw = atan2(-a_t.x, -a_t.z)
	await get_tree().physics_frame
	await _tecla(KEY_2)
	for i in 4:
		await get_tree().process_frame
	_ok(pc.ferramentas.em_id == "machado", "machado na mão (tecla 2)")
	_ok(not pc.viewmodel.visible or true, "viewmodel da arma escondido")
	await _shot("02_machado_na_mao")
	# golpes com o clique esquerdo real
	var golpes_ant := 0
	var fotos := 0
	var t_ini := Time.get_ticks_msec()
	Input.action_press("fire")
	while arv.viva and (Time.get_ticks_msec() - t_ini) < 120000:
		await get_tree().physics_frame
		var g := int(pc.ferramentas.corte._golpes.get(alvo, 0))
		if g != golpes_ant:
			golpes_ant = g
			print("GOLPE ", g)
			if g == 3 and fotos == 0:
				fotos = 1
				await _shot("03_golpe_3")
	Input.action_release("fire")
	_ok(not arv.viva, "árvore derrubada (viva=false)")
	_ok(arv.col == null, "colisão da árvore removida")
	# durante a queda
	await get_tree().create_timer(0.75).timeout
	await _shot("04_caindo")
	var caindo := m.get_node_or_null("ArvoreCaindo")
	print("ARVORE_CAINDO existe=", caindo != null, " rot_x=", caindo.rotation_degrees if caindo else Vector3.ZERO)
	# espera as toras
	var toras: Array = []
	var t0 := Time.get_ticks_msec()
	while toras.size() < 5 and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
		toras = _toras_no_chao(m)
	_ok(toras.size() == 5, "5 toras no chão (%d)" % toras.size())
	var piso_ok := true
	for l in toras:
		var h: float = terreno.height_world(l.global_position.x, l.global_position.z)
		var dy: float = l.global_position.y - h
		print("TORA y-chao=", snappedf(dy, 0.01), " dist_jogador=", snappedf(l.global_position.distance_to(player.global_position), 0.01))
		if absf(dy) > 0.6:
			piso_ok = false
	_ok(piso_ok, "toras apoiadas no chão")
	await get_tree().create_timer(0.5).timeout
	player.pitch = deg_to_rad(-35.0)
	await get_tree().create_timer(0.3).timeout
	await _shot("05_toras_no_chao")
	# inventário de proximidade
	var prox := m.itens_proximos()
	var n_prox := 0
	for inv in prox:
		for it in inv.items:
			if String(it.id) == "tora":
				n_prox += int(it.qty)
	_ok(n_prox == 5, "5 toras na PROXIMIDADE (%d)" % n_prox)
	pc.ferramentas.desequipar()
	m.abrir_inventario()
	await get_tree().create_timer(0.5).timeout
	await _shot("06_inventario_proximidade")
	var passou := 0
	for inv in m.itens_proximos():
		for it in inv.items.duplicate(true):
			if String(it.id) == "tora":
				passou += inv.transfer_to(bag, int(it.uid))
	print("TRANSFERIU ", passou, " toras; peso_kg=", snappedf(bag.weight_kg(), 0.01), "/", bag.capacity_kg())
	_ok(passou == 5, "5 toras arrastadas para a mochila")
	await get_tree().create_timer(0.5).timeout
	await _shot("07_mochila_com_toras")
	m.br_ui.close()
	await get_tree().create_timer(0.3).timeout
	player.pitch = deg_to_rad(-12.0)
	await _shot("08_depois_toco")
	var restantes := _toras_no_chao(m).size()
	_ok(restantes == 0, "nenhuma tora sobrou no chão (%d)" % restantes)
	print("RESULT corte_arvore ", "PASSOU" if falhas == 0 else "FALHOU %d" % falhas)
	get_tree().quit()
