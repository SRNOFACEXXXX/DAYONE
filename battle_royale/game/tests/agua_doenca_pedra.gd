extends Node
## Água, doença e mineração no jogo real: (1) perto do lago T hidrata; (2) no mar T desidrata e adoece; (3) carne crua adoece e
## antibiótico cura (fluxo real usar_cura); (4) picareta na mão minera uma pedra (+1 pedra no chão após 3 golpes). --out=<pasta>
var _out := ""


func _shot(nome: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(nome + ".png"))


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["sem_stamina"] = "1"
	_out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null or m.br_bag == null:
		await get_tree().process_frame
	for i in 240:
		await get_tree().physics_frame
	var p: Soldier = m.local_player
	p.godmode = true
	var sv = p.sobrevivencia()
	var t: IlhaTerrain = m.ilha.terrain
	var falhas := 0
	if sv == null:
		print("AGUA sem nó de sobrevivência")
		get_tree().quit(1)
		return
	# --- mar: ponto de praia (terreno um pouco acima de 0) olhando para o mar (terreno descendo)
	var praia := Vector3.ZERO
	var achou := false
	for r in range(200, 560, 8):
		for k in 36:
			var a := TAU * k / 36.0
			var q := Vector3(cos(a) * r, 0, sin(a) * r)
			var h := t.height_world(q.x, q.z)
			var h2 := t.height_world(q.x + cos(a) * 2.5, q.z + sin(a) * 2.5)
			if h > 0.3 and h < 1.2 and h2 < -0.1 and not achou:
				praia = Vector3(q.x, h + 0.1, q.z)
				achou = true
				# olhar para o mar: direção (cos a, sin a) no plano XZ; yaw usa f = (-sin yaw, -cos yaw)
				p.yaw = atan2(-cos(a), -sin(a))
		if achou:
			break
	print("AGUA praia_achada=%s pos=%s" % [achou, praia])
	p.global_position = praia
	p.reset_physics_interpolation()
	for i in 30:
		await get_tree().physics_frame
	sv.hidratacao = 50.0
	sv.doente_s = 0.0
	var tipo: String = sv.agua_ao_alcance()
	Input.action_press("beber")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("beber")
	print("AGUA mar tipo=%s hidratacao=%.1f doente=%.0f" % [tipo, sv.hidratacao, sv.doente_s])
	if tipo != "salgada" or sv.hidratacao >= 50.0 or sv.doente_s <= 0.0:
		falhas += 1
	await _shot("00_mar")
	# --- carne crua adoece, antibiótico cura (fluxo real)
	sv.curar_doenca()
	sv.energia = 30.0
	m.br_bag.add_item("carne_crua", 1)
	m.br_bag.add_item("antibiotico", 1)
	var ok_c: bool = p.usar_cura("carne_crua")
	for i in 60 * 6:
		await get_tree().physics_frame
	print("AGUA carne_crua usou=%s energia=%.1f doente=%.0f" % [ok_c, sv.energia, sv.doente_s])
	if not ok_c or sv.doente_s <= 0.0:
		falhas += 1
	var ok_a: bool = p.usar_cura("antibiotico")
	for i in 60 * 5:
		await get_tree().physics_frame
	print("AGUA antibiotico usou=%s doente=%.0f" % [ok_a, sv.doente_s])
	if not ok_a or sv.doente_s > 0.0:
		falhas += 1
	# --- mineração: pedra mais próxima do jogador
	var veg: IlhaVegetation = m.ilha.get_node("Vegetacao")
	print("AGUA pedras_mineraveis=%d" % veg.pedras.size())
	if veg.pedras.is_empty():
		falhas += 1
	else:
		var alvo: Dictionary = veg.pedras[0]
		var pos: Vector3 = alvo.pos
		p.global_position = pos + Vector3(2.0, 0.6, 0.0)
		p.reset_physics_interpolation()
		p.yaw = atan2(1.0, 0.0)   # olha para -X? ajusta abaixo
		for i in 40:
			await get_tree().physics_frame
		var f := Vector3(pos.x - p.global_position.x, 0, pos.z - p.global_position.z).normalized()
		p.yaw = atan2(-f.x, -f.z)
		m.br_bag.add_item("picareta", 1)
		var uid := -1
		for it in m.br_bag.items:
			if String(it.id) == "picareta":
				uid = int(it.uid)
		var fm = p.controller.get("ferramentas")
		print("AGUA ferramentas=%s uid=%d" % [fm != null, uid])
		var drops_antes := m.br_loot_root.get_child_count()
		if fm != null and uid >= 0 and fm.equipar(uid):
			for g in 3:
				fm._impacto()
				await get_tree().create_timer(0.1).timeout
			for i in 20:
				await get_tree().physics_frame
			var novos := m.br_loot_root.get_child_count() - drops_antes
			print("AGUA mineracao novos_drops=%d restante=%d" % [novos, int(alvo.restante)])
			await _shot("01_pedra")
			if novos < 1 or int(alvo.restante) != 2:
				falhas += 1
		else:
			falhas += 1
	print("AGUA_RESULT falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)
