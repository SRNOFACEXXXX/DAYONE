extends Node
## Fogueira no jogo real: kit na mão (tecla 2) + clique monta; sem fósforos fica apagada; segurar E com fósforos acende;
## segurar E com carne crua cozinha (barra); V põe lenha; a lenha acaba e o fogo apaga (grupo fogueira_acesa). --out=<pasta>

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
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = kc as Key
		e.keycode = kc as Key
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().physics_frame
		await get_tree().physics_frame


func _contar(bag: BRInventory, id: String) -> int:
	var n := 0
	for it in bag.items:
		if String(it.id) == id:
			n += int(it.qty)
	return n


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
	var bag := m.br_bag
	bag.add_item("kit_fogueira", 1)
	bag.add_item("carne_crua", 2)
	bag.add_item("graveto", 4)
	for it in bag.items:
		if String(it.id) == "kit_fogueira":
			bag.assign_quick_slot(1, int(it.uid))
	var terreno = m.ilha.get("terrain")
	# um trecho de terra firme perto: mantém a posição inicial (costa) se estiver em terra, senão sobe
	var p := player.global_position
	player.pitch = deg_to_rad(-25.0)
	for i in 10:
		await get_tree().physics_frame
	await _shot("01_antes")
	await _tecla(KEY_2)
	for i in 4:
		await get_tree().process_frame
	_ok(pc.ferramentas.em_id == "kit_fogueira", "kit de fogueira na mão")
	await _shot("02_kit_na_mao")
	Input.action_press("fire")
	for i in 5:
		await get_tree().physics_frame
	Input.action_release("fire")
	for i in 5:
		await get_tree().physics_frame
	var fogs := get_tree().get_nodes_in_group("fogueira")
	_ok(fogs.size() == 1, "fogueira montada (%d)" % fogs.size())
	if fogs.is_empty():
		get_tree().quit()
		return
	var f: Node3D = fogs[0]
	var h: float = terreno.height_world(f.global_position.x, f.global_position.z)
	print("FOGUEIRA y-chao=", snappedf(f.global_position.y - h, 0.01), " lenha_min=", snappedf(f.minutos(), 0.1), " dist=", snappedf(f.global_position.distance_to(player.global_position), 0.01))
	_ok(_contar(bag, "kit_fogueira") == 0, "kit consumido")
	_ok(not f.acesa and get_tree().get_nodes_in_group("fogueira_acesa").is_empty(), "sem fósforos fica apagada")
	await _shot("03_fogueira_apagada")
	# acende segurando E com fósforos
	bag.add_item("fosforos", 3)
	Input.action_press("use")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("use")
	_ok(f.acesa and get_tree().get_nodes_in_group("fogueira_acesa").size() == 1, "acendeu com E + fósforos (grupo fogueira_acesa)")
	_ok(_contar(bag, "fosforos") == 2, "gastou 1 fósforo (%d)" % _contar(bag, "fosforos"))
	Clima.congelado = true
	Clima.hora = 21.8
	await get_tree().create_timer(1.5).timeout
	await _shot("04_acesa_noite")
	player.pitch = deg_to_rad(-10.0)
	await get_tree().create_timer(0.5).timeout
	await _shot("05_acesa_noite_perto")
	# cozinha
	var t_ini := Time.get_ticks_msec()
	Input.action_press("use")
	var meio := false
	for i in 330:
		await get_tree().physics_frame
		if i == 120 and not meio:
			meio = true
			await _shot("06_cozinhando_barra")
	Input.action_release("use")
	print("COZIDA=", _contar(bag, "carne_cozida"), " CRUA=", _contar(bag, "carne_crua"))
	_ok(_contar(bag, "carne_cozida") >= 1 and _contar(bag, "carne_crua") <= 1, "carne crua virou carne cozida")
	# lenha
	var antes := f.minutos()
	await _tecla(KEY_V)
	_ok(f.minutos() > antes and _contar(bag, "graveto") == 3, "V pôs graveto (+%.1f min)" % (f.minutos() - antes))
	# apaga quando acaba
	f.combustivel_s = 2.0
	await get_tree().create_timer(3.0).timeout
	_ok(not f.acesa and get_tree().get_nodes_in_group("fogueira_acesa").is_empty(), "apagou ao acabar a lenha")
	await _shot("07_apagada_fim")
	print("RESULT fogueira_real ", "PASSOU" if falhas == 0 else "FALHOU %d" % falhas)
	get_tree().quit()
