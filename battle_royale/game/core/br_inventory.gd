class_name BRInventory
extends RefCounted
## Inventário de partida. Mantenha esta instância no jogador/partida; a UI só a apresenta.
## IDs de calibre são ammo_762, ammo_9mm e ammo_556. Quantidades são cartuchos reais.

signal changed

const COLUMNS := 6
const BASE_ROWS := 4
const BASE_KG := 12.0
const DEFINITIONS := {
	"wood": {"name": "Madeira", "kind": "material", "size": Vector2i(1, 1), "kg": 0.04, "stack": 100},
	"stone": {"name": "Pedra", "kind": "material", "size": Vector2i(1, 1), "kg": 0.08, "stack": 100},
	"ammo_762": {"name": "7,62 mm", "kind": "ammo", "caliber": "762", "size": Vector2i(1, 1), "kg": 0.024, "stack": 60},
	"ammo_9mm": {"name": "9 mm", "kind": "ammo", "caliber": "9mm", "size": Vector2i(1, 1), "kg": 0.012, "stack": 90},
	"ammo_556": {"name": "5,56 mm", "kind": "ammo", "caliber": "556", "size": Vector2i(1, 1), "kg": 0.012, "stack": 60},
	"ammo_127": {"name": "12,7 mm", "kind": "ammo", "caliber": "127", "size": Vector2i(1, 1), "kg": 0.11, "stack": 20},
	"uzi": {"name": "Uzi", "kind": "weapon", "caliber": "9mm", "mag_size": 32, "size": Vector2i(2, 2), "kg": 3.0, "stack": 1},
	"m249": {"name": "M249", "kind": "weapon", "caliber": "556", "mag_size": 100, "size": Vector2i(4, 2), "kg": 7.5, "stack": 1},
	"m107": {"name": "M107", "kind": "weapon", "caliber": "127", "mag_size": 10, "size": Vector2i(5, 2), "kg": 12.0, "stack": 1},
	"ak47": {"name": "AK-47", "kind": "weapon", "caliber": "762", "mag_size": 30, "size": Vector2i(3, 2), "kg": 3.5, "stack": 1},
	"m4": {"name": "M4", "kind": "weapon", "caliber": "556", "mag_size": 30, "size": Vector2i(3, 2), "kg": 3.2, "stack": 1},
	"mosin": {"name": "Mosin-Nagant", "kind": "weapon", "caliber": "762", "mag_size": 5, "size": Vector2i(4, 1), "kg": 4.0, "stack": 1},
	"glock": {"name": "Glock-18", "kind": "weapon", "caliber": "9mm", "mag_size": 20, "size": Vector2i(2, 1), "kg": 0.7, "stack": 1},
	"usp": {"name": "USP", "kind": "weapon", "caliber": "9mm", "mag_size": 12, "size": Vector2i(2, 1), "kg": 0.8, "stack": 1},
	"reddot": {"name": "Mira holográfica", "kind": "attachment", "size": Vector2i(1, 1), "kg": 0.3, "stack": 1},
	"acog": {"name": "Mira ACOG", "kind": "attachment", "size": Vector2i(1, 1), "kg": 0.35, "stack": 1},
	"vest": {"name": "Colete de placas", "kind": "vest", "size": Vector2i(2, 3), "kg": 2.5, "stack": 1},
	"grenade": {"name": "Granada", "kind": "grenade", "size": Vector2i(1, 1), "kg": 0.4, "stack": 3},
	# curas (kind "heal"): usadas pela tecla H / atalho 1–5 / duplo clique → Soldier.usar_cura(id). Bandagem é comum, kit é raro.
	"bandagem": {"name": "Bandagem", "kind": "heal", "size": Vector2i(1, 1), "kg": 0.05, "stack": 5, "heal": 25, "time": 2.5, "rarity": "comum"},
	"kit_medico": {"name": "Kit médico", "kind": "heal", "size": Vector2i(2, 2), "kg": 0.6, "stack": 1, "heal": 60, "time": 5.0, "stop_bleed": true, "rarity": "raro"},
	"backpack_small": {"name": "Mochila pequena", "kind": "backpack", "size": Vector2i(2, 2), "kg": 0.8, "stack": 1, "rows": 2, "capacity_kg": 8.0, "model_path": "res://assets/models/props/tactical_backpack.glb"},
	"backpack_medium": {"name": "Mochila média", "kind": "backpack", "size": Vector2i(2, 2), "kg": 1.2, "stack": 1, "rows": 4, "capacity_kg": 16.0, "model_path": "res://assets/models/props/tactical_backpack.glb"},
	"backpack_large": {"name": "Mochila grande", "kind": "backpack", "size": Vector2i(2, 2), "kg": 1.8, "stack": 1, "rows": 6, "capacity_kg": 24.0, "model_path": "res://assets/models/props/tactical_backpack.glb"},
}

var items: Array[Dictionary] = [] # {uid,id,qty,x,y,mag,acog}; uid é único nesta partida.
var backpack_id := ""
var columns := COLUMNS
var base_rows := BASE_ROWS
var base_kg := BASE_KG
var _next_uid := 1
const QUICK_N := 5
var quick_slots: Array[int] = [-1, -1, -1, -1, -1]   # atalhos 1–5 (uid de qualquer item, exceto mochila)


static func definition(id: String) -> Dictionary:
	if DEFINITIONS.has(id):
		return DEFINITIONS[id]
	_carregar_extras()
	return _extras.get(id, {})


## Itens de sobrevivência e outros vêm de dados: res://data/itens/*.json, cada arquivo {"<id>": {name, kind, size: [w, h], kg,
## stack, ...}}. Um arquivo por área (comida, ferramentas, materiais...) para não haver conflito entre quem edita.
## O que está em DEFINITIONS (armas, munição, mochilas) tem prioridade.
const DIR_ITENS := "res://data/itens/"
static var _extras := {}
static var _extras_ok := false


static func _carregar_extras() -> void:
	if _extras_ok:
		return
	_extras_ok = true
	var d := DirAccess.open(DIR_ITENS)
	if d == null:
		return
	for arq in d.get_files():
		var nome := arq.trim_suffix(".remap")
		if not nome.ends_with(".json"):
			continue
		var dados = JSON.parse_string(FileAccess.get_file_as_string(DIR_ITENS + nome))
		if not dados is Dictionary:
			push_warning("Itens: %s não é um objeto JSON" % nome)
			continue
		for id in dados:
			var def = dados[id]
			if not def is Dictionary or DEFINITIONS.has(id):
				continue
			var tam = def.get("size", [1, 1])
			def["size"] = Vector2i(int(tam[0]), int(tam[1])) if tam is Array and tam.size() >= 2 else Vector2i.ONE
			def["kg"] = float(def.get("kg", 0.1))
			def["stack"] = int(def.get("stack", 1))
			def["name"] = String(def.get("name", id))
			def["kind"] = String(def.get("kind", "material"))
			_extras[String(id)] = def


## Todos os ids conhecidos (DEFINITIONS + dados), para painel de admin e tabelas de saque.
static func todos_ids() -> Array:
	_carregar_extras()
	var ids: Array = DEFINITIONS.keys()
	for k in _extras:
		ids.append(k)
	return ids


static func ammo_id_for_caliber(caliber: String) -> String:
	match caliber:
		"762": return "ammo_762"
		"9mm": return "ammo_9mm"
		"556": return "ammo_556"
		"127": return "ammo_127"
	return ""


static func make_loot_container(rows := 8) -> BRInventory:
	var loot := BRInventory.new()
	loot.base_rows = rows
	loot.base_kg = 1000000.0
	return loot


func rows() -> int:
	return base_rows + int(definition(backpack_id).get("rows", 0))


func capacity_kg() -> float:
	return base_kg + float(definition(backpack_id).get("capacity_kg", 0.0))


func weight_kg() -> float:
	var total := float(definition(backpack_id).get("kg", 0.0))
	for item in items:
		var def := definition(String(item.id))
		total += float(def.get("kg", 0.0)) * int(item.qty)
		if String(def.get("kind", "")) == "weapon":
			total += float(definition(ammo_id_for_caliber(String(def.caliber))).get("kg", 0.0)) * int(item.mag)
		if bool(item.get("acog", false)):
			total += float(definition("acog").kg)
		if bool(item.get("reddot", false)):
			total += float(definition("reddot").kg)
	return total


func get_item(uid: int) -> Dictionary:
	for item in items:
		if int(item.uid) == uid:
			return item.duplicate(true)
	return {}


## Atalho 1–5 por UID: aceita qualquer item que não seja mochila; o mesmo item não fica em dois atalhos.
func assign_quick_slot(slot: int, uid: int) -> bool:
	if slot < 0 or slot >= quick_slots.size():
		return false
	var item := get_item(uid)
	if item.is_empty() or String(definition(String(item.id)).get("kind", "")) == "backpack":
		return false
	for i in quick_slots.size():
		if quick_slots[i] == uid:
			quick_slots[i] = -1
	quick_slots[slot] = uid
	changed.emit()
	return true


func clear_quick_slot(slot: int) -> void:
	if slot >= 0 and slot < quick_slots.size() and quick_slots[slot] != -1:
		quick_slots[slot] = -1
		changed.emit()


func quick_item(slot: int) -> Dictionary:
	if slot < 0 or slot >= quick_slots.size() or quick_slots[slot] < 0:
		return {}
	return get_item(quick_slots[slot])


func set_weapon_mag(uid: int, amount: int) -> void:
	for item in items:
		if int(item.uid) == uid and String(definition(String(item.id)).get("kind", "")) == "weapon":
			item.mag = clampi(amount, 0, int(definition(String(item.id)).mag_size))
			changed.emit()
			return


func item_at(cell: Vector2i) -> Dictionary:
	for item in items:
		var size: Vector2i = definition(String(item.id)).size
		if cell.x >= int(item.x) and cell.x < int(item.x) + size.x and cell.y >= int(item.y) and cell.y < int(item.y) + size.y:
			return item.duplicate(true)
	return {}


func can_place(id: String, cell: Vector2i, ignore_uid := -1) -> bool:
	var def := definition(id)
	if def.is_empty():
		return false
	var size: Vector2i = def.size
	if cell.x < 0 or cell.y < 0 or cell.x + size.x > columns or cell.y + size.y > rows():
		return false
	if rows() > base_rows and cell.y < base_rows and cell.y + size.y > base_rows:
		return false   # item não pode ficar metade na roupa e metade na mochila
	var rect := Rect2i(cell, size)
	for other in items:
		if int(other.uid) == ignore_uid:
			continue
		var other_rect := Rect2i(Vector2i(int(other.x), int(other.y)), definition(String(other.id)).size)
		if rect.intersects(other_rect):
			return false
	return true


func first_space(id: String) -> Vector2i:
	for y in rows():
		for x in columns:
			var cell := Vector2i(x, y)
			if can_place(id, cell):
				return cell
	return Vector2i(-1, -1)


## Retorna o número de unidades aceitas. at define a célula inicial; sem at, empilha e procura espaços.
## extra permite restaurar mag/acog de armas; armas novas começam com carregador vazio.
func add_item(id: String, quantity := 1, at := Vector2i(-1, -1), extra := {}) -> int:
	var def := definition(id)
	if def.is_empty() or quantity <= 0:
		return 0
	var per_item := float(def.kg)
	if String(def.kind) == "weapon":
		per_item += float(definition(ammo_id_for_caliber(String(def.caliber))).get("kg", 0.0)) * clampi(int(extra.get("mag", 0)), 0, int(def.mag_size))
	var budget := int(floor((capacity_kg() - weight_kg() + 0.0001) / per_item)) if per_item > 0.0 else quantity
	if (bool(extra.get("acog", false)) or bool(extra.get("reddot", false))) and String(def.kind) == "weapon":
		budget = int(floor((capacity_kg() - weight_kg() - 0.35 + 0.0001) / per_item))
	var remaining := mini(quantity, maxi(0, budget))
	var added := 0
	var stack_max := int(def.stack)
	if stack_max > 1:
		for item in items:
			if String(item.id) != id or (at.x >= 0 and Vector2i(int(item.x), int(item.y)) != at):
				continue
			var take := mini(remaining, stack_max - int(item.qty))
			if take > 0:
				item.qty = int(item.qty) + take
				remaining -= take
				added += take
			if remaining == 0:
				break
	while remaining > 0:
		var cell := at if at.x >= 0 else first_space(id)
		if not can_place(id, cell):
			break
		var count := mini(remaining, stack_max)
		items.append({"uid": _next_uid, "id": id, "qty": count, "x": cell.x, "y": cell.y,
			"mag": clampi(int(extra.get("mag", 0)), 0, int(def.get("mag_size", 0))), "acog": bool(extra.get("acog", false)), "reddot": bool(extra.get("reddot", false))})
		_next_uid += 1
		remaining -= count
		added += count
		if at.x >= 0:
			break
	if added > 0:
		changed.emit()
	return added


func remove_item(uid: int, quantity := -1) -> int:
	for i in items.size():
		if int(items[i].uid) != uid:
			continue
		var count := int(items[i].qty) if quantity < 0 else mini(quantity, int(items[i].qty))
		if count <= 0:
			return 0
		items[i].qty = int(items[i].qty) - count
		if int(items[i].qty) == 0:
			items.remove_at(i)
		changed.emit()
		return count
	return 0


func move_item(uid: int, cell: Vector2i) -> bool:
	for item in items:
		if int(item.uid) == uid and can_place(String(item.id), cell, uid):
			item.x = cell.x
			item.y = cell.y
			changed.emit()
			return true
	return false


## Transferência atômica por unidade: o destino aceita, então a origem perde exatamente o aceito.
func transfer_to(target: BRInventory, uid: int, quantity := -1, at := Vector2i(-1, -1)) -> int:
	if target == null or target == self:
		return 0
	var item := get_item(uid)
	if item.is_empty():
		return 0
	var count := int(item.qty) if quantity < 0 else mini(quantity, int(item.qty))
	var accepted := target.add_item(String(item.id), count, at, {"mag": item.mag, "acog": item.acog, "reddot": item.get("reddot", false)})
	if accepted > 0:
		remove_item(uid, accepted)
	return accepted


## Mochila equipada ocupa o slot de equipamento e amplia grade e limite de peso.
func equip_backpack(uid: int) -> bool:
	var item := get_item(uid)
	if not backpack_id.is_empty() or String(definition(String(item.get("id", ""))).get("kind", "")) != "backpack":
		return false
	backpack_id = String(item.id)
	remove_item(uid)
	changed.emit()
	return true


## Armas que aceitam cada mira (trilho medido em ViewModel.ACOG_TRILHO). Só uma mira por arma: para trocar, retire a atual.
const ARMAS_ACOG := [&"ak47", &"m4", &"m107"]
const ARMAS_REDDOT := [&"ak47", &"m4", &"m107", &"m249", &"uzi"]


func attach_acog(scope_uid: int, weapon_uid: int) -> bool:
	return attach_mira(scope_uid, weapon_uid)


## Acopla a mira (ACOG ou holográfica) arrastada à arma; falha se a arma já tem mira ou não tem trilho para ela.
func attach_mira(scope_uid: int, weapon_uid: int) -> bool:
	var scope := get_item(scope_uid)
	var gun := get_item(weapon_uid)
	if scope.is_empty() or gun.is_empty():
		return false
	var wid := StringName(String(gun.get("id", "")))
	var tipo := String(scope.get("id", ""))
	if bool(gun.get("acog", false)) or bool(gun.get("reddot", false)):
		return false
	if (tipo == "acog" and not wid in ARMAS_ACOG) or (tipo == "reddot" and not wid in ARMAS_REDDOT) or not tipo in ["acog", "reddot"]:
		return false
	for item in items:
		if int(item.uid) == weapon_uid:
			item[tipo] = true
			break
	remove_item(scope_uid)
	changed.emit()
	return true


## Tira a mira instalada e devolve o item à mochila (falha, mantendo a mira, se não houver espaço).
func retirar_mira(weapon_uid: int) -> String:
	var gun := get_item(weapon_uid)
	if gun.is_empty():
		return ""
	var tipo := "acog" if bool(gun.get("acog", false)) else ("reddot" if bool(gun.get("reddot", false)) else "")
	if tipo == "" or add_item(tipo) < 1:
		return ""
	for item in items:
		if int(item.uid) == weapon_uid:
			item[tipo] = false
			break
	changed.emit()
	return tipo


func count_ammo(caliber: String) -> int:
	var id := ammo_id_for_caliber(caliber)
	var total := 0
	for item in items:
		if String(item.id) == id:
			total += int(item.qty)
	return total


func take_ammo(caliber: String, count: int) -> int:
	var id := ammo_id_for_caliber(caliber)
	var taken := 0
	for item in items.duplicate():
		if String(item.id) == id and taken < count:
			taken += remove_item(int(item.uid), count - taken)
	return taken


func reload_weapon(uid: int) -> int:
	for item in items:
		if int(item.uid) != uid:
			continue
		var def := definition(String(item.id))
		if String(def.get("kind", "")) != "weapon":
			return 0
		var need := int(def.mag_size) - int(item.mag)
		var loaded := take_ammo(String(def.caliber), need)
		item.mag = int(item.mag) + loaded
		if loaded > 0:
			changed.emit()
		return loaded
	return 0


func fire_round(uid: int) -> bool:
	for item in items:
		if int(item.uid) == uid and String(definition(String(item.id)).get("kind", "")) == "weapon" and int(item.mag) > 0:
			item.mag = int(item.mag) - 1
			changed.emit()
			return true
	return false


## Snapshot para respawn/serialização; instância viva já persiste ao fechar a UI.
func snapshot() -> Dictionary:
	return {"items": items.duplicate(true), "backpack_id": backpack_id, "next_uid": _next_uid,
		"columns": columns, "base_rows": base_rows, "base_kg": base_kg, "quick_slots": quick_slots.duplicate()}


func restore(data: Dictionary) -> void:
	items.clear()
	columns = maxi(1, int(data.get("columns", COLUMNS)))
	base_rows = maxi(1, int(data.get("base_rows", BASE_ROWS)))
	base_kg = maxf(0.0, float(data.get("base_kg", BASE_KG)))
	backpack_id = String(data.get("backpack_id", ""))
	if String(definition(backpack_id).get("kind", "")) != "backpack":
		backpack_id = ""
	_next_uid = 1
	for raw in data.get("items", []):
		if not raw is Dictionary:
			continue
		var id := String(raw.get("id", ""))
		var cell := Vector2i(int(raw.get("x", -1)), int(raw.get("y", -1)))
		var qty := int(raw.get("qty", 0))
		var def := definition(id)
		if def.is_empty() or qty < 1 or qty > int(def.stack) or not can_place(id, cell):
			continue
		var uid := maxi(_next_uid, int(raw.get("uid", _next_uid)))
		items.append({"uid": uid, "id": id, "qty": qty, "x": cell.x, "y": cell.y,
			"mag": clampi(int(raw.get("mag", 0)), 0, int(def.get("mag_size", 0))), "acog": bool(raw.get("acog", false)) and String(def.kind) == "weapon", "reddot": bool(raw.get("reddot", false)) and String(def.kind) == "weapon"})
		_next_uid = uid + 1
	quick_slots = [-1, -1, -1, -1, -1]
	var restored_quick: Array = data.get("quick_slots", [])
	for slot in mini(quick_slots.size(), restored_quick.size()):
		var quick_uid := int(restored_quick[slot])
		if not get_item(quick_uid).is_empty():
			quick_slots[slot] = quick_uid
	_next_uid = maxi(_next_uid, int(data.get("next_uid", _next_uid)))
	changed.emit()
