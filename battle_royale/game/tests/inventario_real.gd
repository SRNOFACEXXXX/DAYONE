extends Node
## INVENTÁRIO REAL, com mouse de verdade (eventos na UI): pegar arma da proximidade para a mão, trocar de arma, soltar a arma da mão,
## largar item da mochila no chão, pegar de novo, peso/espaço, mochila, atalhos 1–5.
## Confere SEMPRE o estado de 3 lugares: mochila (BRInventory), Soldier (arma ativa) e o que aparece na mão (viewmodel/corpo).
## Uso: godot --path game res://tests/inventario_real.tscn [-- --out=pasta]  -> INVENTARIO_REAL_OK / FALHOU. Capturas: inv_real_*.png
var out := ""
var m: BRMatch
var ui: BRInventoryUI
var s: Soldier
var pc: PlayerController
var falhas: Array = []


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func() -> void: print("INVENTARIO_REAL_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	out = String(Game.test_args.get("out", ProjectSettings.globalize_path("res://").path_join("../raw/inv_real")))
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	s = m.local_player
	pc = s.controller as PlayerController
	ui = m.br_ui
	s.godmode = true
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	var y: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s.global_position = Vector3(-345.0, y + 0.1, 352.0)
	s.yaw = deg_to_rad(40.0)
	s.reset_physics_interpolation()
	await _f(30)
	_ck("kit inicial não pesa mais que o bolso (peso %.1f/%.1f kg)" % [m.br_bag.weight_kg(), m.br_bag.capacity_kg()], m.br_bag.weight_kg() < m.br_bag.capacity_kg() * 0.4)
	var fwd := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
	var lado := Vector3(fwd.z, 0, -fwd.x)
	for it in [["ak47", 1.8, -0.6], ["m4", 1.8, 0.6], ["backpack_medium", 2.4, 0.0], ["ammo_762", 1.4, 1.0], ["grenade", 1.4, -1.0], ["bandagem", 1.2, 0.0]]:
		var ex := {"mag": 30} if it[0] in ["ak47", "m4"] else {}
		m.criar_drop(String(it[0]), 30 if it[0] == "ammo_762" else 1, s.global_position + fwd * float(it[1]) + lado * float(it[2]), ex)
	await _f(10)
	_tab()
	await _f(10)
	_ck("TAB abre o inventário", ui.visible)
	await _foto("1_aberto")
	# 1) mochila média para o slot
	await _arrasta_prox("backpack_medium", _centro(ui._slot_mochila))
	_ck("mochila equipada pelo slot", m.br_bag.backpack_id == "backpack_medium")
	# 2) AK da proximidade direto para a mão principal
	await _arrasta_prox("ak47", _centro(ui._maos[0]))
	await _f(15)
	_estado("AK na mão principal", &"ak47")
	await _foto("2_ak_na_mao")
	# 3) M4 da proximidade para a mesma mão: troca (a AK volta para a mochila)
	await _arrasta_prox("m4", _centro(ui._maos[0]))
	await _f(15)
	_estado("M4 substitui a AK na mão", &"m4")
	_ck("AK continua na mochila", _na_bag("ak47") == 1)
	# 4) AK da mochila para a mão de novo (troca de volta)
	await _arrasta(_item_na_grade("ak47"), _centro(ui._maos[0]))
	await _f(15)
	_estado("AK de volta na mão (vinda da mochila)", &"ak47")
	# 5) solta a arma da mão no chão: arrasta da mão para a coluna PROXIMIDADE
	await _arrasta(_centro(ui._maos[0]), ui._painel_prox.get_global_rect().get_center())
	await _f(15)
	var tem_pistola := s.inventory.has(WeaponDef.Slot.PISTOL)
	var esperado: StringName = (s.inventory[WeaponDef.Slot.PISTOL] as WeaponState).def.id if tem_pistola else &""
	_estado("soltou a AK da mão", esperado)
	_ck("AK saiu da mochila", _na_bag("ak47") == 0)
	await _foto("3_soltou_ak")
	# 6) pega a AK de volta e a M4 (que está na mochila) -> M4 na mão
	await _arrasta_prox("ak47", _centro(ui._maos[0]))
	await _f(15)
	_estado("AK recolhida do chão para a mão", &"ak47")
	await _arrasta(_item_na_grade("m4"), _centro(ui._maos[0]))
	await _f(15)
	_estado("M4 da mochila para a mão", &"m4")
	# 7) munição para a mochila (empilha)
	await _arrasta_prox("ammo_762", ui._grade_mochila.get_global_rect().position + Vector2(1.5, 1.5) * BRInventoryUI.CELL)
	_ck("munição 7,62 na mochila", m.br_bag.count_ammo("762") >= 30)
	# 8) peso: M107 (12 kg) não pode estourar a capacidade; deve recusar sem quebrar nada
	m.criar_drop("m107", 1, s.global_position + fwd * 1.6, {"mag": 10})
	await _f(5)
	var peso0 := m.br_bag.weight_kg()
	await _arrasta_prox("m107", ui._grade_mochila.get_global_rect().position + Vector2(2.5, 2.5) * BRInventoryUI.CELL)
	print("M107 coube na mochila? ", _na_bag("m107") == 1, " peso ", snappedf(peso0, 0.1), " -> ", snappedf(m.br_bag.weight_kg(), 0.1), " / ", m.br_bag.capacity_kg())
	_ck("peso nunca passa da capacidade", m.br_bag.weight_kg() <= m.br_bag.capacity_kg() + 0.01)
	await _foto("4_peso")
	# 9) fechar, atalhos 1-5 e troca de armas de verdade
	_tab()
	await _f(10)
	_ck("TAB fecha", not ui.visible)
	for ij in m.br_bag.items:
		if String(ij.id) in ["ak47", "m4"]:
			m.br_bag.assign_quick_slot(1 if String(ij.id) == "ak47" else 2, int(ij.uid))
	m.use_quick_slot(1)
	await _f(25)
	_estado("tecla 2 -> AK", &"ak47")
	m.use_quick_slot(2)
	await _f(25)
	_estado("tecla 3 -> M4", &"m4")
	m.use_quick_slot(1)
	await _f(25)
	_estado("tecla 2 de novo -> AK", &"ak47")
	await _foto("5_final")
	print("INVENTARIO_REAL_OK" if falhas.is_empty() else "INVENTARIO_REAL_FALHOU %d %s" % [falhas.size(), str(falhas)])
	get_tree().quit(0 if falhas.is_empty() else 1)


func _ck(nome: String, ok: bool) -> void:
	print("%s %s" % ["ok   " if ok else "FALHA", nome])
	if not ok:
		falhas.append(nome)


## mochila == Soldier == mão (viewmodel e corpo 3ª pessoa): tudo igual ao esperado
func _estado(nome: String, esperado: StringName) -> void:
	var ativo: StringName = s.current_def().id if s.current_def() else &""
	var vm: StringName = pc.viewmodel.current_id
	var corpo: StringName = s.body_model.weapon_id if s.body_model else &""
	var ok := ativo == esperado and vm == esperado and (corpo == esperado or s.body_model == null)
	print("%s %s | soldado=%s viewmodel=%s corpo=%s esperado=%s" % ["ok   " if ok else "FALHA", nome, ativo, vm, corpo, esperado])
	if not ok:
		falhas.append(nome)


func _na_bag(id: String) -> int:
	var n := 0
	for it in m.br_bag.items:
		if String(it.id) == id:
			n += int(it.qty)
	return n


func _item_na_grade(id: String) -> Vector2:
	ui._atualizar()
	for g in [ui._grade_roupa, ui._grade_mochila]:
		var gr = g
		for it in gr.inv.items:
			if String(it.id) == id:
				var sz: Vector2i = BRInventory.definition(id).size
				return gr.get_global_rect().position + (Vector2(int(it.x), int(it.y) - gr.row0) + Vector2(sz) * 0.5) * BRInventoryUI.CELL
	push_error("item não está na mochila/roupa: " + id)
	return Vector2(10, 10)


func _tab() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	m._unhandled_input(ev)


func _centro(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("inv_real_%s.png" % nome))


func _mouse(pos: Vector2, pressed := false, release := false, motion := false) -> void:
	if motion:
		var e := InputEventMouseMotion.new()
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
	else:
		var e2 := InputEventMouseButton.new()
		e2.position = pos
		e2.global_position = pos
		e2.button_index = MOUSE_BUTTON_LEFT
		e2.pressed = pressed
		Input.parse_input_event(e2)


func _arrasta(de: Vector2, para: Vector2) -> void:
	_mouse(de, true)
	await _f(1)
	for k in 6:
		_mouse(de.lerp(para, float(k + 1) / 6.0), false, false, true)
		await _f(1)
	_mouse(para, false, true)
	await _f(3)


func _arrasta_prox(id: String, para: Vector2) -> void:
	ui._atualizar()
	await _f(2)
	var g := ui._grade_prox
	for it in g.inv.items:
		if String(it.id) == id:
			var sz: Vector2i = BRInventory.definition(id).size
			await _arrasta(g.get_global_rect().position + (Vector2(int(it.x), int(it.y)) + Vector2(sz) * 0.5) * BRInventoryUI.CELL, para)
			return
	_ck("item em proximidade: " + id, false)
