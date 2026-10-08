extends Node
## Rodar: godot --headless --path game res://tests/br_inventory_check.tscn

var _failed := false

func _ready() -> void:
	var player := BRInventory.new()
	var loot := BRInventory.make_loot_container()
	_assert(loot.add_item("backpack_medium") == 1, "loot da mochila")
	_assert(loot.add_item("ak47", 1, Vector2i(-1, -1), {"mag": 5}) == 1, "loot da arma")
	_assert(loot.add_item("ammo_762", 75) == 75, "pilhas de 7,62")
	_assert(loot.items.filter(func(item: Dictionary) -> bool: return String(item.id) == "ammo_762").size() == 2, "limite da pilha")
	_assert(loot.add_item("ammo_9mm", 20) == 20, "munição 9 mm")
	_assert(loot.add_item("ammo_556", 20) == 20, "munição 5,56")
	_assert(loot.add_item("acog") == 1, "loot ACOG")
	var bag_uid := _uid_for(loot, "backpack_medium")
	_assert(loot.transfer_to(player, bag_uid) == 1, "transferência mochila")
	_assert(player.equip_backpack(_uid_for(player, "backpack_medium")), "equipar mochila")
	_assert(player.rows() == 8 and player.capacity_kg() == 28.0, "capacidade mochila")
	_assert(loot.transfer_to(player, _uid_for(loot, "ak47")) == 1, "transferência arma")
	_assert(loot.transfer_to(player, _uid_for(loot, "ammo_762"), 25) == 25, "transferência parcial de pilha")
	_assert(player.count_ammo("762") == 25, "cartuchos reais")
	var gun_uid := _uid_for(player, "ak47")
	var weight_before := player.weight_kg()
	_assert(player.reload_weapon(gun_uid) == 25, "recarregar conforme estoque")
	_assert(int(player.get_item(gun_uid).mag) == 30 and player.count_ammo("762") == 0, "carregador e estoque")
	_assert(is_equal_approx(player.weight_kg(), weight_before), "peso da munição dentro do carregador")
	_assert(player.fire_round(gun_uid), "consumir disparo")
	_assert(loot.transfer_to(player, _uid_for(loot, "acog")) == 1, "transferência ACOG")
	var optic_uid := _uid_for(player, "acog")
	_assert(not player.attach_acog(optic_uid, gun_uid), "AK deve rejeitar ACOG e manter mira aberta")
	var mosin_added := player.add_item("mosin", 1, Vector2i(-1, -1), {"mag": 5})
	var mosin_uid := _uid_for(player, "mosin")
	_assert(mosin_added == 1, "adicionar Mosin compatível com ACOG")
	_assert(player.attach_acog(optic_uid, mosin_uid), "acoplar ACOG à Mosin")
	_assert(bool(player.get_item(mosin_uid).acog), "estado da ACOG na Mosin")
	_assert(player.assign_quick_slot(0, gun_uid), "atribuir arma ao atalho F1")
	_assert(ResourceLoader.exists(String(BRInventory.definition("backpack_medium").model_path)), "modelo 3D da mochila")
	var saved := player.snapshot()
	var restored := BRInventory.new()
	restored.restore(saved)
	_assert(restored.snapshot() == saved, "persistência da partida")
	var scene := load("res://ui/br_inventory_ui.tscn") as PackedScene
	_assert(scene != null, "parse da cena")
	if scene == null:
		get_tree().quit(1)
		return
	var ui := scene.instantiate() as BRInventoryUI
	_assert(ui != null, "parse da UI")
	if ui == null:
		get_tree().quit(1)
		return
	add_child(ui)
	_check_ui(ui, player, loot)


func _check_ui(ui: BRInventoryUI, player: BRInventory, loot: BRInventory) -> void:
	ui.open(player, loot)
	_assert(ui.visible and ui.player_grid != null, "abertura da UI")
	var mosin_uid := player.add_item("mosin", 1, Vector2i(-1, -1), {"mag": 3})
	var selected_uid := _uid_for(player, "mosin")
	ui._on_player_selected(selected_uid)
	var bind_key := InputEventKey.new()
	bind_key.pressed = true
	bind_key.keycode = KEY_F2
	ui._unhandled_key_input(bind_key)
	_assert(player.quick_slots[1] == selected_uid, "atribuir arma selecionada ao atalho F2")
	_assert(mosin_uid == 1, "adicionar Mosin de teste")
	ui.close()
	_assert(not ui.visible, "fechamento da UI")
	if not _failed:
		print("BRInventory: parse, cena e operações OK")
	get_tree().quit(1 if _failed else 0)


func _uid_for(inventory: BRInventory, id: String) -> int:
	for item in inventory.items:
		if String(item.id) == id:
			return int(item.uid)
	return -1


func _assert(ok: bool, label: String) -> void:
	if not ok:
		_failed = true
		push_error("Falhou: " + label)
