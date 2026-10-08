class_name BRInventoryUI
extends Control
## Inventário de sobrevivência (TAB). Estilo da concept art (docs/ref/menu_inventario.jpg).
## Colunas: PROXIMIDADE (itens abertos/no chão ao alcance) | soldado 3D + MÃOS | ROUPA (bolsos) e, abaixo, MOCHILA (só quando há
## mochila equipada; sem ela aparece o slot "arraste uma mochila"). Barra de acesso rápido 1–5 na base.
## Arraste: o fantasma tem o tamanho REAL do item (pistola = 2 células) e mostra em verde/vermelho onde encaixa.
## Clique direito / duplo clique: equipar arma, vestir mochila, acoplar ACOG. Soltar em PROXIMIDADE joga o item no chão.

signal closed
signal weapon_equipped(uid: int)
signal attachment_changed
signal drop_requested(uid: int)
signal quick_assigned

const CELL := 42
const MARGIN := 22.0
const COL_W := 290.0

enum Alvo { NADA, GRADE, ATALHO, MAO, MOCHILA_SLOT, PROX }

## Parte de um inventário desenhada como grade (uma por painel).
class Grade extends Control:
	var ui: BRInventoryUI
	var inv: BRInventory
	var row0 := 0
	var rows := 4
	var prox := false
	var map := {}                 # uid da visão de proximidade -> [BRInventory origem, uid origem]

	func _init(u: BRInventoryUI) -> void:
		ui = u
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func ajustar() -> void:
		custom_minimum_size = Vector2(6 * CELL, rows * CELL)
		size = custom_minimum_size

	func _draw() -> void:
		if inv == null:
			return
		for y in rows:
			for x in 6:
				var r := Rect2(Vector2(x, y) * CELL + Vector2.ONE, Vector2.ONE * (CELL - 2))
				draw_rect(r, YUI.TILE, true)
				draw_rect(r, Color(1, 1, 1, 0.07), false, 1.0)
		for it in inv.items:
			var iy := int(it.y) - row0
			if iy < 0 or iy >= rows:
				continue
			ui.desenhar_item(self, it, Vector2(int(it.x), iy) * CELL, prox)


class Atalho extends Control:
	var ui: BRInventoryUI
	var idx := 0
	func _init(u: BRInventoryUI, i: int) -> void:
		ui = u
		idx = i
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var it: Dictionary = ui.item_do_atalho(idx)
		var arrastando := not it.is_empty() and int(it.uid) == ui._drag_uid and ui._drag_origem == "atalho"
		YUI.draw_slot(self, UIStyle.font(600, "num"), Rect2(Vector2.ZERO, size), str(idx + 1), "" if it.is_empty() or arrastando else String(it.id),
				ui.rotulo_qtd(it) if not arrastando else "", ui.equipado(it), it.is_empty())
		if ui._alvo_hover == Alvo.ATALHO and ui._alvo_idx == idx and ui._drag_uid >= 0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(ui._cor_encaixe(), 0.35), true)
			draw_rect(Rect2(Vector2.ZERO, size), ui._cor_encaixe(), false, 2.0)


class Mao extends Control:
	var ui: BRInventoryUI
	var slot := WeaponDef.Slot.PRIMARY
	var titulo := "PRINCIPAL"
	func _init(u: BRInventoryUI, s: int, t: String) -> void:
		ui = u
		slot = s
		titulo = t
		custom_minimum_size = Vector2(150, 78)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ativo := ui.arma_na_mao(slot)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.11, 0.11, 0.1, 0.8), true)
		draw_rect(r, YUI.YELLOW if not ativo.is_empty() else Color(0.62, 0.6, 0.52, 0.5), false, 1.5)
		var f := UIStyle.font(600, "num")
		draw_string(f, Vector2(8, 15), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, YUI.YELLOW)
		if ativo.is_empty():
			draw_string(f, Vector2(0, size.y * 0.58), "vazia", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, YUI.DIM)
		else:
			if not (ui._drag_origem == "mao" and int(ativo.uid) == ui._drag_uid):
				ItemIcons.draw(self, String(ativo.id), Rect2(8, 20, size.x - 16, size.y - 36))
				draw_string(f, Vector2(0, size.y - 6), "%d/%d" % [int(ativo.mag), int(BRInventory.definition(String(ativo.id)).get("mag_size", 0))],
						HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 12, YUI.TEXT)
		if ui._alvo_hover == Alvo.MAO and ui._alvo_idx == slot and ui._drag_uid >= 0:
			draw_rect(r, Color(ui._cor_encaixe(), 0.3), true)
			draw_rect(r, ui._cor_encaixe(), false, 2.0)


class Sobreposicao extends Control:
	var ui: BRInventoryUI
	func _init(u: BRInventoryUI) -> void:
		ui = u
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		ui.desenhar_arrasto(self)


var bag: BRInventory
var proximos: Array = []           # BRInventory de origem (móveis/caixas abertos e itens no chão)
var fonte_proximos := Callable()   # reavalia a proximidade a cada atualização (itens recém-soltos aparecem na hora)
var _view: BRInventory             # proximidade fundida
var _grade_prox: Grade
var _grade_roupa: Grade
var _grade_mochila: Grade
var _painel_prox: YPanel
var _painel_roupa: YPanel
var _painel_mochila: YPanel
var _slot_mochila: Control         # alvo "arraste uma mochila" quando não há mochila
var _scroll_prox: ScrollContainer
var _scroll_mochila: ScrollContainer
var _atalhos: Array[Atalho] = []
var _maos: Array[Mao] = []
var _peso_label: Label
var _peso_fill: ColorRect
var _info: Label
var _retrato: MenuStage
var _sobre: Sobreposicao
var _prev_mouse := Input.MOUSE_MODE_VISIBLE
# arrasto
var _press_pos := Vector2.ZERO
var _press_ok := false
var _press_button := 0
var _arrastando := false
var _drag_uid := -1               # uid na mochila (ou na visão de proximidade quando _drag_origem == "prox")
var _drag_origem := ""            # "roupa" | "mochila" | "prox" | "atalho" | "mao"
var _drag_id := ""
var _drag_size := Vector2i.ONE
var _drag_grab := Vector2.ZERO    # deslocamento do mouse dentro do item (px)
var _alvo_hover := Alvo.NADA
var _alvo_idx := 0
var _alvo_cell := Vector2i.ZERO
var _alvo_grade: Grade
var _alvo_ok := false
var _hover_item := {}
var _ultimo_clique := 0.0
var _ultimo_uid := -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_construir()
	ItemIcons.when_ready(_redesenhar)


func _construir() -> void:
	_retrato = MenuStage.new(false, -14.0, 1.05, 4.2, 30.0)
	_retrato.name = "SoldadoRetrato"
	add_child(_retrato)
	var sombra := ColorRect.new()
	sombra.color = Color(0.02, 0.025, 0.03, 0.45)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)
	move_child(sombra, 0)

	# ---- esquerda: PROXIMIDADE
	_painel_prox = YPanel.new("PROXIMIDADE", true)
	_painel_prox.name = "Proximidade"
	_painel_prox.offset_left = MARGIN
	_painel_prox.offset_right = MARGIN + COL_W
	_painel_prox.offset_top = MARGIN
	add_child(_painel_prox)
	_scroll_prox = ScrollContainer.new()
	_scroll_prox.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_painel_prox.body.add_child(_scroll_prox)
	var caixa_prox := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		caixa_prox.add_theme_constant_override("margin_" + lado, 8)
	_scroll_prox.add_child(caixa_prox)
	_grade_prox = Grade.new(self)
	_grade_prox.prox = true
	caixa_prox.add_child(_grade_prox)

	# ---- direita: ROUPA e MOCHILA
	var direita := VBoxContainer.new()
	direita.name = "Direita"
	direita.anchor_left = 1.0
	direita.anchor_right = 1.0
	direita.offset_left = -MARGIN - COL_W
	direita.offset_right = -MARGIN
	direita.offset_top = MARGIN
	direita.add_theme_constant_override("separation", 10)
	add_child(direita)
	_painel_roupa = YPanel.new("ROUPA", false, "vest")
	direita.add_child(_painel_roupa)
	var m1 := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		m1.add_theme_constant_override("margin_" + lado, 8)
	_painel_roupa.body.add_child(m1)
	_grade_roupa = Grade.new(self)
	m1.add_child(_grade_roupa)
	_painel_mochila = YPanel.new("MOCHILA", false, "backpack_small")
	direita.add_child(_painel_mochila)
	_scroll_mochila = ScrollContainer.new()
	_scroll_mochila.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_painel_mochila.body.add_child(_scroll_mochila)
	var m2 := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		m2.add_theme_constant_override("margin_" + lado, 8)
	_scroll_mochila.add_child(m2)
	_grade_mochila = Grade.new(self)
	m2.add_child(_grade_mochila)
	_slot_mochila = Control.new()
	_slot_mochila.custom_minimum_size = Vector2(0, 58)
	_slot_mochila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_mochila.draw.connect(_desenhar_slot_mochila)
	_painel_mochila.body.add_child(_slot_mochila)
	var peso_caixa := VBoxContainer.new()
	direita.add_child(peso_caixa)
	var linha := HBoxContainer.new()
	peso_caixa.add_child(linha)
	linha.add_child(YUI.label("PESO", 12, YUI.DIM))
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(esp)
	_peso_label = YUI.label("", 13, YUI.TEXT, true)
	linha.add_child(_peso_label)
	var barra := ColorRect.new()
	barra.color = Color(1, 1, 1, 0.14)
	barra.custom_minimum_size = Vector2(0, 5)
	peso_caixa.add_child(barra)
	_peso_fill = ColorRect.new()
	_peso_fill.color = YUI.YELLOW
	_peso_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_peso_fill.anchor_right = 0.0
	barra.add_child(_peso_fill)

	# ---- centro: mãos
	var maos := HBoxContainer.new()
	maos.name = "Maos"
	maos.anchor_left = 0.5
	maos.anchor_right = 0.5
	maos.anchor_top = 1.0
	maos.anchor_bottom = 1.0
	maos.offset_left = -158
	maos.offset_right = 158
	maos.offset_top = -190
	maos.offset_bottom = -112
	maos.add_theme_constant_override("separation", 12)
	add_child(maos)
	for d in [[WeaponDef.Slot.PRIMARY, "MÃO · PRINCIPAL"], [WeaponDef.Slot.PISTOL, "MÃO · PISTOLA"]]:
		var m := Mao.new(self, int(d[0]), String(d[1]))
		_maos.append(m)
		maos.add_child(m)

	# ---- base: acesso rápido 1–5
	var rapido := HBoxContainer.new()
	rapido.name = "AcessoRapido"
	rapido.anchor_left = 0.5
	rapido.anchor_right = 0.5
	rapido.anchor_top = 1.0
	rapido.anchor_bottom = 1.0
	rapido.offset_left = -170
	rapido.offset_right = 170
	rapido.offset_top = -92
	rapido.offset_bottom = -22
	rapido.add_theme_constant_override("separation", 6)
	add_child(rapido)
	for i in BRInventory.QUICK_N:
		var a := Atalho.new(self, i)
		a.custom_minimum_size = Vector2(62, 62)
		_atalhos.append(a)
		rapido.add_child(a)

	# ---- topo: informação do item sob o mouse
	var topo := PanelContainer.new()
	topo.anchor_left = 0.5
	topo.anchor_right = 0.5
	topo.offset_left = -190
	topo.offset_right = 190
	topo.offset_top = MARGIN
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.78)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(7)
	topo.add_theme_stylebox_override("panel", sb)
	add_child(topo)
	_info = YUI.label("", 13, YUI.TEXT, false)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	topo.add_child(_info)

	_sobre = Sobreposicao.new(self)
	add_child(_sobre)


func _redesenhar() -> void:
	for c in [_grade_prox, _grade_roupa, _grade_mochila, _sobre]:
		if c:
			c.queue_redraw()
	for c in _atalhos + _maos:
		c.queue_redraw()


# ------------------------------------------------------------------ dados
func open(player: BRInventory, nearby = null) -> void:
	bag = player
	proximos = nearby if nearby is Array else ([nearby] if nearby is BRInventory else [])
	if bag.changed.is_connected(_atualizar):
		bag.changed.disconnect(_atualizar)
	bag.changed.connect(_atualizar)
	if not visible:
		_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_cancelar_arrasto()
	_atualizar()


func close() -> void:
	if not visible:
		return
	_cancelar_arrasto()
	visible = false
	Input.mouse_mode = _prev_mouse
	closed.emit()


## Compatibilidade com o BRMatch antigo.
func set_equipped(_uid: int) -> void:
	_redesenhar()


func _partida() -> BRMatch:
	return Game.current_match as BRMatch


func arma_na_mao(slot: int) -> Dictionary:
	var m := _partida()
	if m == null or m.local_player == null or bag == null:
		return {}
	var ws: WeaponState = m.local_player.inventory.get(slot)
	if ws == null or ws.br_uid < 0:
		return {}
	return bag.get_item(ws.br_uid)


func item_do_atalho(i: int) -> Dictionary:
	return bag.quick_item(i) if bag else {}


func equipado(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	for s in [WeaponDef.Slot.PRIMARY, WeaponDef.Slot.PISTOL]:
		var a := arma_na_mao(s)
		if not a.is_empty() and int(a.uid) == int(it.uid):
			return true
	return false


func rotulo_qtd(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var def := BRInventory.definition(String(it.id))
	if String(def.get("kind", "")) == "weapon":
		return "%d" % int(it.mag)
	return str(int(it.qty)) if int(it.qty) > 1 else ""


func _atualizar() -> void:
	if bag == null or not is_node_ready():
		return
	if fonte_proximos.is_valid():
		proximos = fonte_proximos.call()
	# proximidade fundida (cada item guarda a origem)
	_view = BRInventory.make_loot_container(40)
	_grade_prox.map.clear()
	var proximo_uid := 1
	var usadas := 0
	for src in proximos:
		if not (src is BRInventory) or not is_instance_valid(src as Object):
			continue
		for it in (src as BRInventory).items:
			var id := String(it.id)
			var cell := _view.first_space(id)
			if cell.x < 0:
				continue
			var v := {"uid": proximo_uid, "id": id, "qty": int(it.qty), "x": cell.x, "y": cell.y, "mag": int(it.mag), "acog": bool(it.acog), "reddot": bool(it.get("reddot", false))}
			_view.items.append(v)
			_grade_prox.map[proximo_uid] = [src, int(it.uid)]
			var sz: Vector2i = BRInventory.definition(id).size
			usadas = maxi(usadas, cell.y + sz.y)
			proximo_uid += 1
	var bau := _bau_proximo()
	if bau != null:
		var ocupadas := 0
		for it in bau.items:
			var sz2: Vector2i = BRInventory.definition(String(it.id)).size
			ocupadas += sz2.x * sz2.y
		_painel_prox.set_title("BAÚ · %d/%d" % [ocupadas, bau.columns * bau.base_rows])
	else:
		_painel_prox.set_title("PROXIMIDADE")
	_grade_prox.inv = _view
	_grade_prox.rows = maxi(5, usadas + 1)
	_grade_prox.ajustar()
	var tem_mochila := not bag.backpack_id.is_empty()
	_grade_roupa.inv = bag
	_grade_roupa.row0 = 0
	_grade_roupa.rows = bag.base_rows
	_grade_roupa.ajustar()
	_grade_mochila.inv = bag
	_grade_mochila.row0 = bag.base_rows
	_grade_mochila.rows = maxi(0, bag.rows() - bag.base_rows)
	_grade_mochila.visible = tem_mochila
	_scroll_mochila.visible = tem_mochila
	_grade_mochila.ajustar()
	_slot_mochila.visible = not tem_mochila
	_painel_mochila.set_title("MOCHILA · %s" % String(BRInventory.definition(bag.backpack_id).get("name", "")).to_upper() if tem_mochila else "MOCHILA")
	var usado := 0
	for it in bag.items:
		var s: Vector2i = BRInventory.definition(String(it.id)).size
		usado += s.x * s.y
	_painel_roupa.set_title("ROUPA (%d/%d)" % [mini(usado, bag.base_rows * 6), bag.base_rows * 6])
	var alt_livre := maxf(160.0, size.y - 22.0 - 2.0 * MARGIN - 190.0)
	_scroll_prox.custom_minimum_size.y = minf(_grade_prox.custom_minimum_size.y + 16.0, size.y - 2.0 * MARGIN - 70.0)
	_scroll_mochila.custom_minimum_size.y = minf(_grade_mochila.custom_minimum_size.y + 16.0, maxf(120.0, alt_livre - 200.0))
	var cap := maxf(0.01, bag.capacity_kg())
	_peso_label.text = "%.1f / %.1f kg" % [bag.weight_kg(), cap]
	_peso_fill.anchor_right = clampf(bag.weight_kg() / cap, 0.0, 1.0)
	_peso_fill.color = YUI.YELLOW if bag.weight_kg() / cap < 0.9 else Color("e4572e")
	_redesenhar()


# ------------------------------------------------------------------ desenho
func _cor_encaixe() -> Color:
	return Color("5bd16a") if _alvo_ok else Color("e4572e")


func desenhar_item(ci: Control, it: Dictionary, origem: Vector2, prox: bool) -> void:
	var def := BRInventory.definition(String(it.id))
	var sz: Vector2i = def.size
	var rect := Rect2(origem + Vector2.ONE * 2.0, Vector2(sz) * CELL - Vector2.ONE * 4.0)
	var uid := int(it.uid)
	var no_arrasto := _drag_uid == uid and ((prox and _drag_origem == "prox") or (not prox and _drag_origem in ["roupa", "mochila"]))
	var hover := not _hover_item.is_empty() and int(_hover_item.uid) == uid and bool(_hover_item.get("prox", false)) == prox
	var fill := Color(0.32, 0.32, 0.3, 0.3) if no_arrasto else (Color(0.4, 0.38, 0.3, 0.92) if hover else YUI.TILE_ITEM)
	ci.draw_rect(rect, fill, true)
	if not no_arrasto:
		ItemIcons.draw(ci, String(it.id), rect.grow(-3.0))
		var f := UIStyle.font(600, "num")
		var kind := String(def.get("kind", ""))
		var canto := rotulo_qtd(it)
		if kind == "backpack":
			canto = "+%d" % (int(def.rows) * 6)
		if canto != "":
			ci.draw_string(f, rect.position + Vector2(0, rect.size.y - 3), canto, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4, 12, YUI.TEXT)
		if kind == "weapon" and (bool(it.get("acog", false)) or bool(it.get("reddot", false))):
			ci.draw_string(f, rect.position + Vector2(4, 12), "ACOG" if bool(it.get("acog", false)) else "HOLO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, YUI.YELLOW)
		if not prox and equipado(it):
			ci.draw_rect(rect, YUI.YELLOW, false, 2.0)
			ci.draw_string(f, rect.position + Vector2(4, 13), "NA MÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, YUI.YELLOW)


func _desenhar_slot_mochila() -> void:
	var r := Rect2(Vector2(8, 4), _slot_mochila.size - Vector2(16, 8))
	_slot_mochila.draw_rect(r, YUI.TILE, true)
	var c := YUI.YELLOW if (_alvo_hover == Alvo.MOCHILA_SLOT and _drag_uid >= 0) else Color(1, 1, 1, 0.22)
	if _alvo_hover == Alvo.MOCHILA_SLOT and _drag_uid >= 0:
		c = _cor_encaixe()
	var seg := 8.0
	var x := r.position.x
	while x < r.end.x:   # borda tracejada
		_slot_mochila.draw_line(Vector2(x, r.position.y), Vector2(minf(x + seg, r.end.x), r.position.y), c, 1.5)
		_slot_mochila.draw_line(Vector2(x, r.end.y), Vector2(minf(x + seg, r.end.x), r.end.y), c, 1.5)
		x += seg * 2.0
	_slot_mochila.draw_string(UIStyle.font(600, "num"), Vector2(0, r.position.y + r.size.y * 0.62), "sem mochila — arraste uma para cá", HORIZONTAL_ALIGNMENT_CENTER, _slot_mochila.size.x, 13, YUI.DIM)


func desenhar_arrasto(ci: Control) -> void:
	if not _arrastando or _drag_id == "":
		return
	var mouse := get_local_mouse_position()
	var tam := Vector2(_drag_size) * CELL
	var origem := mouse - _drag_grab
	# destaque do encaixe na grade sob o mouse
	if _alvo_hover == Alvo.GRADE and _alvo_grade != null:
		var go := _alvo_grade.get_global_rect().position - get_global_rect().position
		var r := Rect2(go + Vector2(_alvo_cell) * CELL, tam)
		ci.draw_rect(r, Color(_cor_encaixe(), 0.32), true)
		ci.draw_rect(r, _cor_encaixe(), false, 2.0)
	var fant := Rect2(origem, tam)
	ci.draw_rect(fant, Color(YUI.SELECTED, 0.9), true)
	ci.draw_rect(fant, YUI.YELLOW, false, 2.0)
	ItemIcons.draw(ci, _drag_id, fant.grow(-4.0))


# ------------------------------------------------------------------ entrada
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
		close()
		get_viewport().set_input_as_handled()
		return
	# 1–5 sobre um item da mochila: atribui o atalho
	if event.keycode >= KEY_1 and event.keycode <= KEY_5 and not _hover_item.is_empty() and not bool(_hover_item.get("prox", false)):
		if bag.assign_quick_slot(int(event.keycode) - int(KEY_1), int(_hover_item.uid)):
			quick_assigned.emit()
			_info.text = "Atalho %d: %s" % [int(event.keycode) - int(KEY_1) + 1, BRInventory.definition(String(_hover_item.id)).name]
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_ao_mover(event.position)
	elif event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		if event.pressed:
			_ao_apertar(event.position, event.button_index)
		else:
			_ao_soltar(event.position, event.button_index)
		get_viewport().set_input_as_handled()


func _sob_mouse(pos: Vector2) -> Dictionary:
	## Quem está sob o mouse (coordenadas globais da viewport): {tipo, grade, cell, idx, item, origem}
	for g in [_grade_roupa, _grade_mochila, _grade_prox]:
		var gr: Grade = g
		if not gr.is_visible_in_tree() or gr.inv == null:
			continue
		var r := gr.get_global_rect()
		if r.has_point(pos):
			var cell := Vector2i(int((pos.x - r.position.x) / CELL), int((pos.y - r.position.y) / CELL))
			var it := gr.inv.item_at(Vector2i(cell.x, cell.y + gr.row0))
			return {"tipo": Alvo.PROX if gr.prox else Alvo.GRADE, "grade": gr, "cell": cell, "item": it,
				"origem": "prox" if gr.prox else ("roupa" if gr.row0 == 0 else "mochila")}
	for a in _atalhos:
		if a.get_global_rect().has_point(pos):
			return {"tipo": Alvo.ATALHO, "idx": a.idx, "item": item_do_atalho(a.idx), "origem": "atalho"}
	for m in _maos:
		if m.get_global_rect().has_point(pos):
			return {"tipo": Alvo.MAO, "idx": m.slot, "item": arma_na_mao(m.slot), "origem": "mao"}
	if _slot_mochila.is_visible_in_tree() and _slot_mochila.get_global_rect().has_point(pos):
		return {"tipo": Alvo.MOCHILA_SLOT, "item": {}, "origem": ""}
	if _painel_prox.get_global_rect().has_point(pos):
		return {"tipo": Alvo.PROX, "grade": null, "item": {}, "origem": "prox"}
	return {"tipo": Alvo.NADA, "item": {}, "origem": ""}


func _ao_apertar(pos: Vector2, botao: int) -> void:
	var s := _sob_mouse(pos)
	_press_pos = pos
	_press_button = botao
	_press_ok = false
	if botao == MOUSE_BUTTON_LEFT and not (s.item as Dictionary).is_empty():
		_press_ok = true
		var it: Dictionary = s.item
		_drag_uid = int(it.uid)
		_drag_origem = String(s.origem)
		_drag_id = String(it.id)
		_drag_size = BRInventory.definition(_drag_id).size
		if s.has("grade") and s.grade is Grade:
			var gr: Grade = s.grade
			var top_left := Vector2(int(it.x), int(it.y) - gr.row0) * CELL
			_drag_grab = (pos - gr.get_global_rect().position) - top_left
		else:
			_drag_grab = Vector2(_drag_size) * CELL * 0.5
	elif botao == MOUSE_BUTTON_RIGHT and not (s.item as Dictionary).is_empty():
		_acao_item(s)


func _ao_mover(pos: Vector2) -> void:
	var s := _sob_mouse(pos)
	var it: Dictionary = s.item
	_hover_item = it.duplicate() if not it.is_empty() else {}
	if not _hover_item.is_empty():
		_hover_item["prox"] = s.origem == "prox"
		var d := BRInventory.definition(String(it.id))
		var extra := ""
		if String(d.get("kind", "")) == "weapon":
			extra = "  ·  carregador %d/%d%s" % [int(it.mag), int(d.mag_size), ("  ·  ACOG" if bool(it.get("acog", false)) else ("  ·  HOLOGRÁFICA  (Shift+botão direito retira a mira)" if bool(it.get("reddot", false)) else ""))]
		_info.text = "%s  ·  %.1f kg%s" % [String(d.name), float(d.kg) * int(it.qty), extra]
	elif not _arrastando:
		_info.text = "Arraste os itens · clique direito equipa · 1–5 define atalho"
	if _press_ok and not _arrastando and _press_pos.distance_to(pos) > 5.0:
		_arrastando = true
	if _arrastando:
		_alvo_hover = s.tipo
		_alvo_grade = s.get("grade") as Grade
		_alvo_idx = int(s.get("idx", 0))
		_alvo_ok = false
		if s.tipo == Alvo.GRADE and _alvo_grade != null:
			_alvo_cell = _celula_do_fantasma(pos, _alvo_grade)
			_alvo_ok = _pode_encaixar(_alvo_grade, _alvo_cell)
		else:
			_alvo_ok = _alvo_valido(s)
	_redesenhar()


func _celula_do_fantasma(pos: Vector2, g: Grade) -> Vector2i:
	var origem := pos - _drag_grab - g.get_global_rect().position
	return Vector2i(int(round(origem.x / CELL)), int(round(origem.y / CELL)))


func _item_arrasto() -> Dictionary:
	if _drag_origem == "prox":
		return _view.get_item(_drag_uid) if _view else {}
	return bag.get_item(_drag_uid)


func _pode_encaixar(g: Grade, cell: Vector2i) -> bool:
	if g.prox:
		return _drag_origem != "prox"
	var abs_cell := Vector2i(cell.x, cell.y + g.row0)
	if cell.y < 0 or cell.y + _drag_size.y > g.rows:
		return false
	var ignora := _drag_uid if _drag_origem in ["roupa", "mochila"] else -1
	if g.inv.can_place(_drag_id, abs_cell, ignora):
		return true
	var ocupante := g.inv.item_at(abs_cell)   # empilhar ou acoplar ACOG
	if ocupante.is_empty() or int(ocupante.uid) == _drag_uid:
		return false
	var def := BRInventory.definition(_drag_id)
	if String(ocupante.id) == _drag_id and int(def.stack) > 1 and int(ocupante.qty) < int(def.stack):
		return true
	return _drag_id in ["acog", "reddot"] and String(BRInventory.definition(String(ocupante.id)).get("kind", "")) == "weapon" and not bool(ocupante.get("acog", false)) and not bool(ocupante.get("reddot", false))


func _alvo_valido(s: Dictionary) -> bool:
	var def := BRInventory.definition(_drag_id)
	var kind := String(def.get("kind", ""))
	match int(s.tipo):
		Alvo.ATALHO:
			return kind != "backpack" and (_drag_origem != "prox" or true)
		Alvo.MAO:
			if kind != "weapon":
				return false
			var wd := WeaponDB.get_def(StringName(_drag_id))
			return wd != null and wd.slot == int(s.idx)
		Alvo.MOCHILA_SLOT:
			return kind == "backpack" and bag.backpack_id.is_empty()
		Alvo.PROX:
			return _drag_origem != "prox"
	return false


func _ao_soltar(pos: Vector2, botao: int) -> void:
	if botao != _press_button:
		return
	var s := _sob_mouse(pos)
	if _arrastando and _drag_uid >= 0:
		_largar(s, pos)
	elif _press_ok:
		_clicar(s)
	_cancelar_arrasto()
	_atualizar()


func _cancelar_arrasto() -> void:
	_arrastando = false
	_press_ok = false
	_drag_uid = -1
	_drag_origem = ""
	_drag_id = ""
	_alvo_hover = Alvo.NADA
	_alvo_grade = null
	_redesenhar()


## Garante que o item arrastado esteja na mochila (se veio da proximidade, transfere) e devolve o uid dele na mochila.
func _para_mochila(cell := Vector2i(-1, -1)) -> int:
	if _drag_origem != "prox":
		return _drag_uid
	var origem: Array = _grade_prox.map.get(_drag_uid, [])
	if origem.is_empty():
		return -1
	var antes := {}
	for it in bag.items:
		antes[int(it.uid)] = true
	var n := (origem[0] as BRInventory).transfer_to(bag, int(origem[1]), -1, cell)
	if n <= 0:
		_info.text = "Sem espaço ou peso disponível."
		return -1
	for it in bag.items:
		if not antes.has(int(it.uid)):
			return int(it.uid)
	# empilhou em outro: devolve o primeiro do mesmo id
	for it in bag.items:
		if String(it.id) == _drag_id:
			return int(it.uid)
	return -1


func _largar(s: Dictionary, pos: Vector2) -> void:
	if not _alvo_ok and int(s.tipo) != Alvo.NADA:
		_info.text = "Não encaixa aí."
		return
	match int(s.tipo):
		Alvo.GRADE:
			var g: Grade = s.grade
			var cell := _celula_do_fantasma(pos, g)
			var abs_cell := Vector2i(cell.x, cell.y + g.row0)
			var ocupante := bag.item_at(abs_cell)
			if _drag_id in ["acog", "reddot"] and not ocupante.is_empty() and String(BRInventory.definition(String(ocupante.id)).get("kind", "")) == "weapon" \
					and not bag.can_place(_drag_id, abs_cell, _drag_uid if _drag_origem in ["roupa", "mochila"] else -1):
				var uid := _para_mochila()
				if uid >= 0 and bag.attach_mira(uid, int(ocupante.uid)):
					attachment_changed.emit()
					_info.text = "Mira acoplada."
				else:
					_info.text = "Essa arma já tem mira ou não aceita esta. Shift+botão direito na arma retira a mira."
				return
			if _drag_origem in ["roupa", "mochila"]:
				if bag.can_place(_drag_id, abs_cell, _drag_uid):
					bag.move_item(_drag_uid, abs_cell)
				elif not ocupante.is_empty() and String(ocupante.id) == _drag_id:   # empilha
					var q := int(bag.get_item(_drag_uid).qty)
					var antes := int(ocupante.qty)
					bag.remove_item(_drag_uid)
					var aceito := bag.add_item(_drag_id, q, Vector2i(int(ocupante.x), int(ocupante.y)))
					if aceito < q:
						bag.add_item(_drag_id, q - aceito)
			elif _drag_origem == "prox":
				_para_mochila(abs_cell if bag.can_place(_drag_id, abs_cell) else Vector2i(-1, -1))
			elif _drag_origem in ["atalho", "mao"]:
				if _drag_origem == "mao":
					_desequipar(_drag_uid)
				if bag.can_place(_drag_id, abs_cell, _drag_uid):
					bag.move_item(_drag_uid, abs_cell)
		Alvo.ATALHO:
			var uid2 := _para_mochila()
			if uid2 >= 0 and bag.assign_quick_slot(int(s.idx), uid2):
				quick_assigned.emit()
		Alvo.MAO:
			var uid3 := _para_mochila()
			if uid3 >= 0:
				weapon_equipped.emit(uid3)
		Alvo.MOCHILA_SLOT:
			var uid4 := _para_mochila()
			if uid4 >= 0 and bag.equip_backpack(uid4):
				_info.text = "Mochila equipada."
		Alvo.PROX:
			if _drag_origem in ["roupa", "mochila"]:
				var bau := _bau_proximo()
				if bau != null:   # baú de base aberto: soltar na coluna guarda lá dentro em vez de jogar no chão
					var n := bag.transfer_to(bau, _drag_uid)
					_info.text = "Guardado no baú." if n > 0 else "Baú cheio."
				else:
					drop_requested.emit(_drag_uid)
			elif _drag_origem == "mao":
				drop_requested.emit(_drag_uid)
		Alvo.NADA:
			if _drag_origem == "atalho":
				bag.clear_quick_slot(_slot_do_uid(_drag_uid))


## Contêiner de baú de base entre os de proximidade (marcado com meta "bau" por StorageChest), ou null.
func _bau_proximo() -> BRInventory:
	for src in proximos:
		if src is BRInventory and is_instance_valid(src as Object) and (src as BRInventory).has_meta("bau"):
			return src as BRInventory
	return null


func _slot_do_uid(uid: int) -> int:
	for i in bag.quick_slots.size():
		if bag.quick_slots[i] == uid:
			return i
	return -1


func _desequipar(uid: int) -> void:
	var m := _partida()
	if m == null:
		return
	for sl in m.local_player.inventory.keys():
		var ws: WeaponState = m.local_player.inventory[sl]
		if ws.br_uid == uid:
			bag.set_weapon_mag(uid, ws.mag)
			m.local_player.remove_slot(sl)
			m.local_player.switch_to(WeaponDef.Slot.KNIFE)
			return


func _clicar(s: Dictionary) -> void:
	var it: Dictionary = s.item
	if it.is_empty():
		return
	var agora := Time.get_ticks_msec() / 1000.0
	var duplo := int(it.uid) == _ultimo_uid and agora - _ultimo_clique < 0.35
	_ultimo_uid = int(it.uid)
	_ultimo_clique = agora
	if s.origem == "prox":
		# clique simples recolhe para a mochila
		_drag_uid = int(it.uid)
		_drag_origem = "prox"
		_drag_id = String(it.id)
		_para_mochila()
	elif duplo:
		_acao_item(s)


## Clique direito / duplo clique: equipa a arma, veste a mochila, acopla a ACOG.
func _acao_item(s: Dictionary) -> void:
	var it: Dictionary = s.item
	var uid := int(it.uid)
	if s.origem == "prox":
		return
	var def := BRInventory.definition(String(it.id))
	match String(def.get("kind", "")):
		"weapon":
			if Input.is_key_pressed(KEY_SHIFT) and (bool(it.get("acog", false)) or bool(it.get("reddot", false))):
				var tipo := bag.retirar_mira(uid)
				_info.text = ("Mira retirada: %s (volta à mochila)." % String(BRInventory.definition(tipo).name)) if tipo != "" else "Sem espaço na mochila para a mira."
				attachment_changed.emit()
				_atualizar()
				return
			weapon_equipped.emit(uid)
			_info.text = "%s equipada." % String(def.name)
		"backpack":
			_info.text = "Mochila equipada." if bag.equip_backpack(uid) else "Já há uma mochila equipada."
		"attachment":
			for gun in bag.items:
				if String(BRInventory.definition(String(gun.id)).get("kind", "")) == "weapon" and bag.attach_mira(uid, int(gun.uid)):
					attachment_changed.emit()
					_info.text = "Mira acoplada."
					return
			_info.text = "Nenhuma arma compatível."
		"grenade":
			_info.text = "Arraste para um atalho (1–5) e use a tecla, ou G."
		"heal":
			var pm := _partida()
			if pm != null and pm.local_player.usar_cura(String(it.id)):
				_info.text = "Usando %s... (H usa a melhor cura; atirar ou trocar de arma interrompe)" % String(def.name)
			else:
				_info.text = "Nada a curar ou já curando."
		_:
			_info.text = "Arraste para mover."
	_atualizar()
