extends Node
## Inventário real (TAB): spawna itens ao redor, abre o inventário e arrasta com eventos de mouse: proximidade -> atalho, roupa,
## slot de mochila e mão; confere tamanho do fantasma, colocação, mochila e o painel F10 (spawn a 10 passos no piso).
var out := ""
var m: BRMatch
var ui: BRInventoryUI

func _ready() -> void:
	Game.test_mode = true
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	ui = m.br_ui
	await _f(20)
	var fwd := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
	for it in [["ak47", 1.8, -0.5], ["usp", 1.8, 0.4], ["backpack_medium", 2.4, 0.0], ["ammo_762", 1.4, 0.8], ["grenade", 1.4, -0.8]]:
		var p: Vector3 = s.global_position + fwd * float(it[1]) + Vector3(fwd.z, 0, -fwd.x) * float(it[2])
		var ex := {"mag": 30} if it[0] in ["ak47", "usp"] else {}
		m.criar_drop(String(it[0]), 30 if it[0] == "ammo_762" else 1, p, ex)
	await _f(5)
	var prox := m.itens_proximos()
	print("PROX fontes=", prox.size())
	assert(prox.size() >= 5, "itens soltos devem aparecer em proximidade")
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_TAB; ev.pressed = true
	m._unhandled_input(ev)
	await _f(8)
	assert(ui.visible and not m.hud.root.visible, "inventário abre e esconde o HUD")
	await _foto("1_aberto")
	# 1) AK da proximidade -> atalho 2
	var uid_ak := await _arrasta_prox("ak47", _centro(ui._atalhos[1]))
	print("AK atalho2=", m.br_bag.quick_slots[1], " item=", m.br_bag.get_item(m.br_bag.quick_slots[1]))
	assert(m.br_bag.quick_slots[1] >= 0 and String(m.br_bag.get_item(m.br_bag.quick_slots[1]).id) == "ak47", "AK deve ir ao atalho 2")
	# 2) USP: arrasta para a roupa, célula (3,2) com fantasma de 2 células
	var g := ui._grade_roupa
	var alvo := g.get_global_rect().position + Vector2(3.5, 2.5) * BRInventoryUI.CELL
	await _arrasta_prox("usp", alvo, true)
	var usp := m.br_bag.items.filter(func(i): return i.id == "usp")
	print("USP em ", usp[0].x, ",", usp[0].y, " tamanho=", BRInventory.definition("usp").size)
	# 3) mochila -> slot
	await _arrasta_prox("backpack_medium", _centro(ui._slot_mochila))
	print("mochila=", m.br_bag.backpack_id)
	assert(m.br_bag.backpack_id == "backpack_medium", "mochila equipada pelo slot")
	await _f(4)
	await _foto("2_mochila")
	# 4) AK para a mão principal (arrasta do atalho 2)
	await _arrasta(_centro(ui._atalhos[1]), _centro(ui._maos[0]))
	print("mao principal=", s.inventory.get(WeaponDef.Slot.PRIMARY))
	assert(s.inventory.get(WeaponDef.Slot.PRIMARY) != null, "AK deve ir para a mão")
	# 5) arrasta granada da proximidade para a mochila (grade mochila)
	await _arrasta_prox("grenade", ui._grade_mochila.get_global_rect().position + Vector2(1.5, 1.5) * BRInventoryUI.CELL)
	await _f(4)
	await _foto("3_final")
	m._unhandled_input(ev)
	await _f(4)
	assert(not ui.visible and m.hud.root.visible)
	# 6) F10: spawn a 10 passos
	var f10 := InputEventKey.new(); f10.physical_keycode = KEY_F10; f10.pressed = true
	m._unhandled_input(f10)
	await _f(6)
	assert(m.admin and m.admin.visible and not m.hud.root.visible)
	m.admin._alternar_lista()
	await _f(4)
	await _foto("4_admin")
	var n0 := get_tree().get_nodes_in_group("loot").size()
	m.admin._spawnar("m107")
	await _f(4)
	var novo: BRDrop
	for n in get_tree().get_nodes_in_group("loot"):
		if n is BRDrop and (n as BRDrop).nome == "M107":
			novo = n
	assert(novo != null, "item deve existir")
	var d := Vector2(novo.global_position.x - s.global_position.x, novo.global_position.z - s.global_position.z).length()
	var h: float = m.ilha.terrain.height_world(novo.global_position.x, novo.global_position.z)
	print("SPAWN dist=%.2f y=%.2f chao=%.2f" % [d, novo.global_position.y, h])
	assert(absf(d - 7.5) < 0.6 and novo.global_position.y > h - 0.1 and novo.global_position.y < h + 3.0)
	m.admin.close()
	print("INVUI OK")
	get_tree().quit()

func _centro(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("inv_%s.png" % nome))

func _mouse(pos: Vector2, pressed := false, release := false, motion := false) -> void:
	if motion:
		var e := InputEventMouseMotion.new(); e.position = pos; e.global_position = pos
		Input.parse_input_event(e)
	else:
		var e2 := InputEventMouseButton.new(); e2.position = pos; e2.global_position = pos
		e2.button_index = MOUSE_BUTTON_LEFT; e2.pressed = pressed
		Input.parse_input_event(e2)

func _arrasta(de: Vector2, para: Vector2, pausa_foto := false) -> void:
	_mouse(de, true)
	await _f(1)
	for k in 6:
		_mouse(de.lerp(para, float(k + 1) / 6.0), false, false, true)
		await _f(1)
	if pausa_foto:
		await _foto("arrasto_%d" % Time.get_ticks_msec())
	_mouse(para, false, true)
	await _f(3)

## Encontra o item (por id) na grade de proximidade (a visão é refeita a cada atualização) e arrasta.
func _arrasta_prox(id: String, para: Vector2, foto := false) -> int:
	ui._atualizar()
	await _f(2)
	var g := ui._grade_prox
	for it in g.inv.items:
		if String(it.id) == id:
			var sz: Vector2i = BRInventory.definition(id).size
			var de := g.get_global_rect().position + (Vector2(int(it.x), int(it.y)) + Vector2(sz) * 0.5) * BRInventoryUI.CELL
			await _arrasta(de, para, foto)
			return int(it.uid)
	push_error("item não está em proximidade: " + id)
	return -1
