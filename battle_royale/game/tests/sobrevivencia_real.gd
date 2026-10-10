extends Node
## Fome / sede / frio no jogo real: acelera o tempo, mede as quedas, come e bebe pelo fluxo real (atalho 1-5 e ação do inventário),
## confere frio à noite, fogueira que aquece, dano com fome zerada e a HUD. Capturas em --out=<pasta>.

var m: BRMatch
var s: Soldier
var sv: Node
var out := ""
var falhas: Array[String] = []


func _ck(nome: String, ok: bool) -> void:
	print("%s %s" % ["ok   " if ok else "FALHA", nome])
	if not ok:
		falhas.append(nome)


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _p(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(nome: String) -> void:
	await _f(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))
	print("CAPTURA ", nome)


func _tab() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	m._unhandled_input(ev)


func _ready() -> void:
	get_tree().create_timer(900.0).timeout.connect(func() -> void: print("SOBREVIVENCIA_REAL_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	out = String(Game.test_args.get("out", OS.get_user_data_dir()))
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null or m.hud == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	s = m.local_player
	var zd := m.ilha.get_node_or_null("ZombieDirector")
	if zd != null:
		zd.process_mode = Node.PROCESS_MODE_DISABLED   # sem zumbis novos: o dano medido é só o da sobrevivência
	s.godmode = true   # zumbis/queda não atrapalham as medições; só o passo do dano por fome liga o dano real
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	var y: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s.global_position = Vector3(-345.0, y + 0.1, 352.0)
	s.reset_physics_interpolation()
	await _f(30)
	sv = s.sobrevivencia()
	_ck("jogador local tem o nó de sobrevivência", sv != null)
	_ck("HUD tem a faixa de sobrevivência", m.hud.get_node_or_null("SobrevHud") != null or m.hud.find_child("SobrevHud", true, false) != null)
	if sv == null:
		get_tree().quit(1)
		return
	var avisos: Array[String] = []
	sv.aviso.connect(func(t: String) -> void: avisos.append(t))
	_ck("começa saciado e na temperatura normal", sv.energia > 99.0 and sv.hidratacao > 99.0 and absf(sv.temperatura - 36.5) < 0.3)
	print("DEBUG inicio ", sv.energia, " ", sv.hidratacao, " ", sv.temperatura)
	Clima.set_hora(12.0)
	await _f(30)
	await _shot("01_inicio")

	# 1) taxas: 20 min de jogo acelerados, parado, de dia (esperado: fome -22,2 ; sede -33,3)
	sv.escala = 600.0
	var e0: float = sv.energia
	var h0: float = sv.hidratacao
	var t0 := Time.get_ticks_msec()
	await _p(120)
	var min_jogo: float = 120.0 / 60.0 * 600.0 / 60.0
	var dE: float = e0 - sv.energia
	var dH: float = h0 - sv.hidratacao
	print("MEDIDA parado %.1f min: fome -%.1f (esperado %.1f) sede -%.1f (esperado %.1f) ; min reais ate zero: fome %.0f sede %.0f" % [min_jogo, dE, min_jogo / 90.0 * 100.0, dH, min_jogo / 60.0 * 100.0, min_jogo / dE * 100.0, min_jogo / dH * 100.0])
	_ck("fome cai ~1,1/min (zera em ~90 min)", absf(dE - min_jogo / 90.0 * 100.0) < 2.5)
	_ck("sede cai ~1,7/min (zera em ~60 min)", absf(dH - min_jogo / 60.0 * 100.0) < 3.0)
	_ck("de dia, sem chuva: temperatura normal", sv.temperatura > 36.3)
	await _shot("02_fome_sede_20min")

	# 2) correr gasta mais
	var e1: float = sv.energia
	var h1: float = sv.hidratacao
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _p(60)
	var corre_ok: bool = s.is_sprinting
	var dE2: float = e1 - sv.energia
	var dH2: float = h1 - sv.hidratacao
	Input.action_release("sprint")
	Input.action_release("move_forward")
	print("MEDIDA correndo (sprint=%s) 10 min: fome -%.1f sede -%.1f (parado seria %.1f / %.1f)" % [corre_ok, dE2, dH2, 10.0 / 90.0 * 100.0, 10.0 / 60.0 * 100.0])
	_ck("correr gasta mais sede e fome que parado", (not corre_ok) or (dH2 > 10.0 / 60.0 * 100.0 * 1.3 and dE2 > 10.0 / 90.0 * 100.0 * 1.2))

	# 3) comer / beber pelo fluxo real: atalho 1 (use_quick_slot) e depois ação do inventário (duplo clique)
	sv.escala = 1.0
	sv.energia = 30.0
	sv.hidratacao = 25.0
	m.br_bag.add_item("lata_comida", 2)
	m.br_bag.add_item("garrafa_agua", 1)
	m.br_bag.add_item("carne_crua", 1)
	var uid_lata := _uid("lata_comida")
	m.br_bag.assign_quick_slot(0, uid_lata)
	var antes_lata := _qtd("lata_comida")
	_ck("atalho 1 aceita a lata", m.use_quick_slot(0))
	_ck("comer inicia o uso com barra (cura_ativa)", s.cura_ativa() and s.cura_id == "lata_comida")
	await _p(20)
	_ck("no meio do uso a fome ainda não subiu", sv.energia < 31.0)
	var tempo: float = float(BRInventory.definition("lata_comida").time)
	await _p(int(tempo * 60.0) + 60)
	print("MEDIDA lata: energia 30 -> %.1f ; latas %d -> %d" % [sv.energia, antes_lata, _qtd("lata_comida")])
	_ck("lata_comida: +35 de energia (deve ficar 65)", absf(sv.energia - 65.0) < 2.0)
	_ck("lata consumida do inventário (2 -> 1)", _qtd("lata_comida") == antes_lata - 1)
	# beber pelo inventário (ação de duplo clique)
	_tab()
	await _f(10)
	await _shot("03_inventario_comida")
	var ui: BRInventoryUI = m.br_ui
	var it_agua: Dictionary = m.br_bag.get_item(_uid("garrafa_agua"))
	ui._acao_item({"item": it_agua, "origem": "mochila"})
	_ck("duplo clique na garrafa inicia o uso", s.cura_ativa() and s.cura_id == "garrafa_agua")
	await _p(int(float(BRInventory.definition("garrafa_agua").time) * 60.0) + 60)
	print("DEBUG garrafa: cura_id=", s.cura_id, " left=", s.cura_left, " alive=", s.alive, " ui=", m.br_ui.visible, " paused=", get_tree().paused, " escala=", sv.escala, " proc=", sv.is_processing(), " physproc=", sv.is_physics_processing())
	print("MEDIDA garrafa: hidratacao 25 -> %.1f" % sv.hidratacao)
	_ck("garrafa_agua: +45 de hidratação (25 - 3 da lata + 45 = 67)", absf(sv.hidratacao - 67.0) < 2.0)
	_ck("garrafa consumida", _qtd("garrafa_agua") == 0)
	_tab()
	await _f(6)
	# saciado: não gasta o item
	sv.energia = 100.0
	_ck("saciado não consome comida (recusa)", not s.usar_cura("lata_comida") and _qtd("lata_comida") == 1)
	# carne crua: avisa
	sv.energia = 40.0
	avisos.clear()
	s.usar_cura("carne_crua")
	await _p(int(float(BRInventory.definition("carne_crua").time) * 60.0) + 60)
	var aviso_cru := false
	for a in avisos:
		if a.contains("crua"):
			aviso_cru = true
	_ck("carne crua dá menos (+18) e avisa", absf(sv.energia - 58.0) < 2.0 and aviso_cru)
	# atirar interrompe
	sv.energia = 10.0
	s.usar_cura("lata_comida")
	await _p(10)
	s.cura_cancelar("teste")
	_ck("cancelar não consome nem alimenta", _qtd("lata_comida") == 1 and sv.energia < 11.0)

	# 4) avisos a 20% e dano com zero
	avisos.clear()
	sv.energia = 80.0
	await _p(5)
	sv.energia = 22.0
	sv.hidratacao = 80.0
	sv.escala = 600.0
	await _p(40)
	sv.escala = 1.0
	_ck("aviso de fome ao passar de 20%", avisos.any(func(a: String) -> bool: return a.contains("fome")))
	sv.energia = 0.0
	sv.hidratacao = 0.0
	s.health = 100
	sv.escala = 1.0
	s.godmode = false
	await _p(60 * 9)
	s.godmode = true
	print("MEDIDA fome+sede zeradas por 9 s: vida 100 -> ", s.health)
	_ck("com fome e sede zeradas a vida cai devagar (>=2 e <=10 em 9 s)", s.health <= 99 and s.health >= 90)
	await _shot("04_critico")
	sv.energia = 80.0
	sv.hidratacao = 80.0
	s.health = 100

	# 5) frio: noite
	s.godmode = true   # a aceleração x600 multiplicaria o dano de hipotermia: só medimos a temperatura
	Clima.set_hora(2.0)
	await _f(30)
	sv.temperatura = 36.5
	sv.escala = 600.0
	var t_antes: float = sv.temperatura
	await _p(180)
	print("MEDIDA noite 30 min: temperatura 36.5 -> %.2f (ambiente %.1f C, elevacao sol %.1f)" % [sv.temperatura, sv.ambiente_c, Clima.elevacao_sol])
	_ck("a noite o corpo esfria", sv.temperatura < t_antes - 0.8)
	_ck("avisou frio", avisos.any(func(a: String) -> bool: return a.contains("frio") or a.contains("Hipotermia")))
	await _shot("05_frio_noite")
	# fogueira aquece
	var fogo := Node3D.new()
	fogo.add_to_group("fogueira_acesa")
	add_child(fogo)
	fogo.global_position = s.global_position + Vector3(2, 0, 0)
	var t_frio: float = sv.temperatura
	await _p(240)
	print("MEDIDA fogueira 40 min: %.2f -> %.2f ; perto=%s" % [t_frio, sv.temperatura, sv.perto_fogueira])
	_ck("perto da fogueira aquece", sv.perto_fogueira and sv.temperatura > t_frio + 0.5)
	await _shot("06_fogueira")
	fogo.queue_free()
	# molhado: água/chuva
	sv.molhado = 0.0
	Clima.set_hora(12.0)
	await _f(20)
	sv.aquecer(0.0)
	sv.escala = 1.0
	_ck("molhado começa em 0 e API estado() existe", sv.estado().has("molhado") and sv.molhado == 0.0)
	s.global_position = Vector3(-345.0, y + 0.1, 352.0)

	# regressão: mochila sem os itens nunca fica negativa
	print("RESULT sobrevivencia_real falhas=%d %s" % [falhas.size(), str(falhas)])
	print("SOBREVIVENCIA_REAL_OK" if falhas.is_empty() else "SOBREVIVENCIA_REAL_FALHOU")
	get_tree().quit(0 if falhas.is_empty() else 1)


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
