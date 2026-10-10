extends Node
## Pacote de props no jogo real: cada item novo faz o que a ficha diz. Arremesso de garrafa (barulho), dinamite (mata horda), mina
## (explode por proximidade), frigideira (dano corpo a corpo), cofrinho (moedas), celular (lanterna), cosméticos (efeitos e
## selo), mochila de trilha (capacidade), cozinha mais rápida com panela/frigideira, conserto do carro com chaves/fita.
## Capturas: 1ª pessoa de cada item na mão + 3ª pessoa com todos os cosméticos. --out=<pasta>
var _out := ""
var falhas := 0
var m: BRMatch
var p: Soldier
var pc: PlayerController
var fm


func _ok(c: bool, msg: String) -> void:
	print(("OK    " if c else "FALHA ") + msg)
	if not c:
		falhas += 1


func _shot(nome: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(nome + ".png"))


func _uid(id: String) -> int:
	for it in m.br_bag.items:
		if String(it.id) == id:
			return int(it.uid)
	return -1


func _qtd(id: String) -> int:
	var n := 0
	for it in m.br_bag.items:
		if String(it.id) == id:
			n += int(it.qty)
	return n


func _zumbi_em(pos: Vector3) -> ZombieEnemy:
	var z: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
	m.add_child(z)
	z.global_position = pos
	return z


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["personagem"] = "padrao"   # boneco do criador (o mesmo do jogador), não o soldado de teste
	_out = Game.test_args.get("out", OS.get_user_data_dir())
	DisplayServer.window_set_size(Vector2i(1280, 720))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null or m.br_bag == null:
		await get_tree().process_frame
	while Loading.visivel():
		await get_tree().process_frame
	for i in 120:
		await get_tree().physics_frame
	p = m.local_player
	p.godmode = true
	pc = p.controller as PlayerController
	fm = pc.ferramentas
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	m.br_bag.base_kg = 500.0
	m.br_bag.base_rows = 40
	var fwd := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var chao := p.global_position
	# ---- 0) todos os itens existem e têm modelo
	for id in ["dinamite", "bomba", "mina_naval", "garrafa_vazia", "moeda", "dado", "idolo", "calice", "cofrinho", "frigideira", "ancinho", "celular",
			"panela", "chaves", "fita", "leme", "mochila_trilha", "regador", "chapeu", "fones", "coroa", "mascara_mergulho", "chuteira", "amuleto",
			"escada_telescopica", "regua_torre"]:
		var d := BRInventory.definition(id)
		_ok(not d.is_empty() and ResourceLoader.exists(String(d.get("model_path", ""))), "item %s definido e com modelo" % id)
	# ---- 1) garrafa: barulho no choque
	m.br_bag.add_item("garrafa_vazia", 2)
	_ok(fm.equipar(_uid("garrafa_vazia")), "garrafa na mão")
	await get_tree().physics_frame
	await _shot("mao_garrafa")
	var antes := _qtd("garrafa_vazia")
	fm._arremessar(BRInventory.definition("garrafa_vazia"))
	_ok(_qtd("garrafa_vazia") == antes - 1, "arremesso gastou 1 garrafa")
	var gs := get_tree().get_nodes_in_group("granada_teste")
	var achou_ruido := false
	for n in m.get_children():
		if n is Grenade and (n as Grenade).ruido > 0.0:
			achou_ruido = true
	_ok(achou_ruido, "projétil de barulho no ar (Grenade com ruído)")
	for i in 200:
		await get_tree().physics_frame
	fm.desequipar()
	# ---- 2) dinamite mata horda
	m.br_bag.add_item("dinamite", 1)
	var zs: Array = []
	p.pitch = deg_to_rad(12.0)
	_ok(fm.equipar(_uid("dinamite")), "dinamite na mão")
	await _shot("mao_dinamite")
	fm._arremessar(BRInventory.definition("dinamite"))
	var dina: Grenade = null
	for n in m.get_children():
		if n is Grenade and (n as Grenade).pavio > 3.0 and (n as Grenade).ruido == 0.0 and not (n as Grenade).mina:
			dina = n
	_ok(dina != null, "dinamite no ar com pavio de 3,5 s")
	for i in int(2.9 * 60.0):
		await get_tree().physics_frame
	if dina != null and is_instance_valid(dina):
		for i in 5:   # onde a dinamite parou: cinco zumbis em volta, parados
			var zz := _zumbi_em(dina.global_position + Vector3(randf_range(-1.8, 1.8), 0.3, randf_range(-1.8, 1.8)))
			zz.set_physics_process(false)
			zs.append(zz)
	for i in 120:
		await get_tree().physics_frame
	var mortos := 0
	for z in zs:
		if not is_instance_valid(z) or (z as ZombieEnemy).state == ZombieEnemy.State.DEAD:
			mortos += 1
	print("DINAMITE mortos=%d/5" % mortos)
	_ok(mortos >= 1, "dinamite matou zumbis na área (%d/5)" % mortos)
	fm.desequipar()
	for z in zs:
		if is_instance_valid(z):
			z.queue_free()
	p.pitch = 0.0
	# ---- 3) mina por proximidade
	m.br_bag.add_item("mina_naval", 1)
	_ok(fm.equipar(_uid("mina_naval")), "mina na mão")
	await _shot("mao_mina")
	fm._plantar_mina(BRInventory.definition("mina_naval"))
	var mina: Grenade = null
	for n in m.get_children():
		if n is Grenade and (n as Grenade).mina:
			mina = n
	_ok(mina != null, "mina plantada")
	for i in 150:
		await get_tree().physics_frame
	var zm := _zumbi_em(mina.global_position + Vector3(1.5, 0.2, 0)) if mina != null else null
	if zm != null:
		zm.set_physics_process(false)
		for i in 60:
			await get_tree().physics_frame
		_ok(not is_instance_valid(mina) or mina.is_queued_for_deletion(), "mina explodiu com zumbi perto")
		_ok(not is_instance_valid(zm) or zm.state == ZombieEnemy.State.DEAD, "zumbi morreu na mina")
	fm.desequipar()
	# ---- 4) frigideira: dano corpo a corpo
	m.br_bag.add_item("frigideira", 1)
	_ok(fm.equipar(_uid("frigideira")), "frigideira na mão")
	await _shot("mao_frigideira")
	var zf := _zumbi_em(p.global_position + fwd * 1.3 + Vector3(0, 0.2, 0))
	zf.set_physics_process(false)
	var hp0: int = zf.health
	p.pitch = 0.0
	fm._golpe_melee(BRInventory.definition("frigideira"))
	await get_tree().physics_frame
	_ok(zf.health < hp0, "frigideira feriu o zumbi (%d → %d)" % [hp0, zf.health])
	zf.queue_free()
	_ok(fm._tem_utensilio(), "frigideira conta como utensílio de cozinha")
	fm.desequipar()
	# ---- 5) cofrinho
	m.br_bag.add_item("cofrinho", 1)
	_ok(fm.equipar(_uid("cofrinho")), "cofrinho na mão")
	var moedas0 := _qtd("moeda")
	fm._abrir(BRInventory.definition("cofrinho"))
	_ok(_qtd("moeda") >= moedas0 + 3 and _qtd("cofrinho") == 0, "cofrinho quebrado deu moedas (%d → %d)" % [moedas0, _qtd("moeda")])
	# ---- 6) celular = lanterna
	m.br_bag.add_item("celular", 1)
	_ok(fm.equipar(_uid("celular")), "celular na mão")
	await get_tree().physics_frame
	var luz := false
	for c in pc.camera.get_children():
		if c is SpotLight3D:
			luz = true
	_ok(luz, "lanterna do celular ligada")
	await _shot("mao_celular")
	fm.desequipar()
	luz = false
	await get_tree().process_frame
	for c in pc.camera.get_children():
		if c is SpotLight3D:
			luz = true
	_ok(not luz, "lanterna some ao guardar o celular")
	# ---- 7) props restantes na mão (capturas)
	for id in ["ancinho", "bomba", "idolo", "moeda", "dado", "calice", "regador"]:
		m.br_bag.add_item(id, 1)
		if fm.equipar(_uid(id)):
			await _shot("mao_" + id)
			fm.desequipar()
	# ---- 8) cosméticos: efeitos e selo
	var cos = pc.cosmeticos
	for id in ["chapeu", "fones", "mascara_mergulho", "chuteira", "amuleto", "coroa"]:
		m.br_bag.add_item(id, 1)
		cos.alternar(_uid(id))
	await get_tree().create_timer(1.0).timeout
	var ves: Array = cos.vestidos()
	print("COSM vestidos=", ves)
	_ok(ves.has("mascara_mergulho") and ves.has("chuteira") and ves.has("amuleto") and ves.has("fones"), "cosméticos vestidos (chapéu cede lugar à coroa)")
	_ok(not ves.has("chapeu") and ves.has("coroa"), "coroa tomou o lugar do chapéu (mesmo espaço)")
	_ok(is_equal_approx(p.efeito_cosmetico("queda"), 0.6), "chuteira: dano de queda x0,6")
	_ok(is_equal_approx(p.efeito_cosmetico("folego"), 2.0), "máscara: fôlego x2")
	cos.alternar(_uid("coroa"))
	cos.alternar(_uid("chapeu"))
	_ok(is_equal_approx(p.efeito_cosmetico("chuva"), 0.5), "chapéu: chuva x0,5")
	cos.alternar(_uid("coroa"))
	# terceira pessoa: câmera de teste à frente do rosto e à frente dos pés
	pc._prefer_third_person = true
	pc._set_third_person(true)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var f := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	var cabeca := p.global_position + Vector3(0, 1.55, 0)
	cam.fov = 40.0
	cam.global_position = cabeca + f * 1.1 + Vector3(0.0, 0.1, 0.0)
	cam.look_at(cabeca, Vector3.UP)
	await get_tree().create_timer(1.2).timeout
	await _shot("cosm_rosto")
	cam.global_position = cabeca + f * 1.4 + Vector3(0.9, -0.2, 0.0)
	cam.look_at(cabeca + Vector3(0, -0.35, 0), Vector3.UP)
	await get_tree().process_frame
	await _shot("cosm_lado")
	cam.global_position = p.global_position + f * 1.2 + Vector3(0.0, 0.6, 0.0)
	cam.look_at(p.global_position + Vector3(0, 0.15, 0), Vector3.UP)
	await get_tree().process_frame
	await _shot("cosm_pes")
	cam.global_position = cabeca + f * 1.0 + Vector3(0.0, -0.3, 0.0)
	cam.look_at(cabeca + Vector3(0, -0.55, 0), Vector3.UP)
	await get_tree().process_frame
	await _shot("cosm_peito")
	cam.queue_free()
	pc._prefer_third_person = false
	pc._set_third_person(false)
	# ---- 9) mochila de trilha (a partida já veste a primeira mochila que entra na bolsa)
	m.br_bag.backpack_id = ""
	var cap0 := m.br_bag.capacity_kg()
	var add_n := m.br_bag.add_item("mochila_trilha", 1)
	var uid_m := _uid("mochila_trilha")
	if uid_m >= 0:
		m.br_bag.equip_backpack(uid_m)
	print("MOCHILA add=%d id=%s cap %.1f -> %.1f rows=%d" % [add_n, m.br_bag.backpack_id, cap0, m.br_bag.capacity_kg(), m.br_bag.rows()])
	_ok(m.br_bag.backpack_id == "mochila_trilha" and m.br_bag.capacity_kg() >= cap0 + 19.0, "mochila de trilha vestida e com +20 kg")
	# ---- 10) escada telescópica: parede de 3 m com plataforma; apoia, sobe com E + W
	var bloco := StaticBody3D.new()
	bloco.collision_layer = Soldier.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(5, 3.0, 5)
	cs.shape = bx
	bloco.add_child(cs)
	m.add_child(bloco)
	var plano := Vector3(p.global_position.x, 0, p.global_position.z)
	var f2 := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	# laje plana lá no alto do céu (sem nenhum objeto do mapa por perto)
	var alto := 300.0
	plano = Vector3(plano.x, 0, plano.z)
	var laje := StaticBody3D.new()
	laje.collision_layer = Soldier.LAYER_WORLD
	var cs2 := CollisionShape3D.new()
	var bx2 := BoxShape3D.new()
	bx2.size = Vector3(16, 3.0, 16)
	cs2.shape = bx2
	laje.add_child(cs2)
	m.add_child(laje)
	laje.global_position = Vector3(plano.x, alto - 1.5, plano.z) + f2 * 3.0
	bloco.global_position = Vector3(plano.x, alto + 1.5, plano.z) + f2 * 5.5
	p.global_position = Vector3(plano.x, alto + 0.1, plano.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.pitch = 0.0
	for i in 20:
		await get_tree().physics_frame
	m.hud_message.connect(func(t, _d): print("HUD ", t))
	m.br_bag.add_item("escada_telescopica", 1)
	_ok(fm.equipar(_uid("escada_telescopica")), "escada telescópica na mão")
	fm._apoiar_escada()
	var esc: EscadaVertical = m.get_node_or_null("EscadaTelescopica") as EscadaVertical
	_ok(esc != null and _qtd("escada_telescopica") == 0, "escada apoiada e item gasto")
	if esc != null:
		var base := esc.base_world()
		p.global_position = base + (base - bloco.global_position).normalized() * 0.0 + Vector3(0, 0.05, 0)
		p.reset_physics_interpolation()
		for i in 15:
			await get_tree().physics_frame
		_ok(p.escada_mais_proxima() != null, "jogador no pé da escada")
		await _shot("escada_pe")
		var y_ini := p.global_position.y
		if p.escada_mais_proxima() != null:
			p.iniciar_escada(p.escada_mais_proxima())
			Input.action_press("move_forward")
			var ymax := y_ini
			for i in 240:
				await get_tree().physics_frame
				ymax = maxf(ymax, p.global_position.y)
				if i > 20 and p.escada == null:
					break   # chegou no topo e saiu da escada
			Input.action_release("move_forward")
			await _shot("escada_cima")
			print("ESCADA y %.2f -> máx %.2f (topo %.2f)" % [y_ini, ymax, esc.topo_world().y])
			_ok(ymax > y_ini + 2.5, "subiu a escada (+%.1f m)" % (ymax - y_ini))
	print("PROPS_RESULT falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)
