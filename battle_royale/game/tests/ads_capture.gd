extends Node
## Gate de mira: AK com alça aberta; ACOG instalada e funcional apenas na Mosin.

const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/ads_review"


func _ready() -> void:
	# Um assert interrompe a coroutine, mas não encerra o Godot. O watchdog evita
	# deixar janelas gráficas de teste abertas quando uma validação falha.
	get_tree().create_timer(25.0).timeout.connect(func() -> void:
		push_error("ADS_CAPTURE_TIMEOUT")
		get_tree().quit(2)
	)
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	DirAccess.make_dir_recursive_absolute(OUT)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null:
		await get_tree().process_frame
	assert(m.br_bag.add_item("ak47", 1, Vector2i(-1, -1), {"mag": 30}) == 1, "AK precisa entrar no inventário de teste")
	assert(m.br_bag.add_item("acog") == 1, "ACOG precisa entrar no inventário de teste")
	var ak_uid := _uid_for(m.br_bag, "ak47")
	var optic_uid := _uid_for(m.br_bag, "acog")
	assert(not m.br_bag.attach_acog(optic_uid, ak_uid), "AK deve manter a mira aberta e rejeitar ACOG")
	assert(m.br_bag.get_item(optic_uid) != {}, "ACOG incompatível não pode ser consumida")
	m._equip_br_weapon(ak_uid)
	var ak_def: WeaponDef = WeaponDB.get_def(&"ak47")
	assert(ak_def.ads_iron_fov > 0.0 and ak_def.ads_acog_fov == 0.0, "AK deve usar apenas alça e massa de mira")
	var pc := m.local_player.controller as PlayerController
	assert(m.br_bag.assign_quick_slot(0, ak_uid), "AK deve aceitar atribuição F1")
	var quick_key := InputEventKey.new()
	quick_key.pressed = true
	quick_key.keycode = KEY_F1
	pc._unhandled_input(quick_key)
	assert(m.local_player.current_def().id == &"ak47", "F1 deve equipar a arma atribuída")
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(40)
	await _capture("01_hipfire")
	Input.action_press("alt_fire")
	var deadline := Time.get_ticks_msec() + 8000
	while pc._ads_amount < 0.9 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert(pc._ads_amount > 0.8, "mira iron precisa chegar ao estado ADS")
	assert(not pc._ads_acog, "AK nunca pode entrar no modo ACOG")
	await _capture("02_ak_iron")
	Input.action_release("alt_fire")
	await _frames(20)
	assert(m.br_bag.add_item("mosin", 1, Vector2i(-1, -1), {"mag": 5}) == 1, "Mosin precisa entrar no inventário")
	var mosin_uid := _uid_for(m.br_bag, "mosin")
	assert(m.br_bag.attach_acog(optic_uid, mosin_uid), "ACOG deve instalar na Mosin")
	m._equip_br_weapon(mosin_uid)
	await _frames(35)
	Input.action_press("alt_fire")
	deadline = Time.get_ticks_msec() + 8000
	while pc._ads_amount < 0.9 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert(pc._ads_amount > 0.8 and not pc._ads_acog, "Mosin deve mirar com a alça aberta antes de alternar")
	await _capture("03_mosin_iron")
	assert(pc.toggle_optic(), "Mosin equipada deve aceitar alternância para ACOG")
	await _frames(30)
	assert(pc._ads_amount > 0.8 and pc._ads_acog, "V deve alternar para a ACOG instalada na Mosin")
	assert(absf(pc.camera.fov - WeaponDB.get_def(&"mosin").ads_acog_fov) < 0.75, "FOV da ACOG deve ampliar a imagem")
	assert(pc.viewmodel.optic != null and pc.viewmodel.optic.visible, "a óptica visível deve pertencer à Mosin equipada")
	await _capture("04_mosin_acog")
	Input.action_release("alt_fire")
	var loot := BRInventory.make_loot_container()
	loot.add_item("mosin", 1, Vector2i(0, 0), {"mag": 5})
	loot.add_item("ammo_762", 42)
	loot.add_item("backpack_small")
	loot.add_item("ammo_9mm", 30)
	m.br_ui.open(m.br_bag, loot)
	await _frames(4)
	await _capture("05_inventory")
	print("ADS_CAPTURE_OK ak_iron_fov=%.1f mosin_iron_fov=%.1f mosin_acog_fov=%.1f" % [ak_def.ads_iron_fov, WeaponDB.get_def(&"mosin").ads_iron_fov, WeaponDB.get_def(&"mosin").ads_acog_fov])
	get_tree().quit()


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUT.path_join(name + ".png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	assert(err == OK, "falha ao salvar captura " + name)


func _uid_for(bag: BRInventory, id: String) -> int:
	for item in bag.items:
		if String(item.id) == id:
			return int(item.uid)
	return -1
