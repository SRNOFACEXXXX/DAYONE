class_name BuyMenu
extends Control
## Menu de compra (B) conforme HUD_SPEC 4.15: categorias 1–3 à esquerda, grade de cartões 180 × 110
## com a silhueta da arma (renderizada do próprio modelo 3D), nome, preço e tecla de atalho.

const CATS := ["PISTOLAS", "RIFLES", "EQUIPAMENTO"]

var match_ref: Match
var hud: Node
var grid: GridContainer
var money_label: Label
var time_label: Label
var cat_buttons: Array[Button] = []
var cat := 1
var cards: Array = []           # [{panel, item, price_label, badge}]
var _shown_money := -1.0
var _icons: Dictionary = {}     # id -> Texture2D (SubViewport)
var _icon_root: Node


func setup(m: Match, h: Node) -> void:
	match_ref = m
	hud = h
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon_root = Node.new()
	add_child(_icon_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.BG_SOLID, 8, 1))
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -420
	p.offset_right = 420
	p.offset_top = -190
	p.offset_bottom = 150
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	# barra superior: saldo · tempo de compra · fechar
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	v.add_child(head)
	var title := UIStyle.label("COMPRAR", 26, UIStyle.TEXT, 700, "title")
	head.add_child(title)
	money_label = UIStyle.label("", 28, UIStyle.MONEY, 600, "num")
	head.add_child(money_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	time_label = UIStyle.label("", 18, UIStyle.TEXT_DIM, 600, "num")
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(time_label)
	var close_l := UIStyle.label("B / Esc — fechar", 15, UIStyle.TEXT_DIM, 400, "text")
	close_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(close_l)
	var line := ColorRect.new()
	line.color = UIStyle.PANEL_LINE
	line.custom_minimum_size.y = 1
	v.add_child(line)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var catcol := VBoxContainer.new()
	catcol.add_theme_constant_override("separation", 8)
	catcol.custom_minimum_size.x = 190
	body.add_child(catcol)
	for i in CATS.size():
		var b := UIStyle.button("%d   %s" % [i + 1, CATS[i]], 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 46
		var idx := i
		b.pressed.connect(func() -> void: _select_cat(idx))
		catcol.add_child(b)
		cat_buttons.append(b)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)


func _items_for(team: int, c: int) -> Array:
	var items := []
	if c < 2:
		for w in WeaponDB.buyable_for(team):
			if (c == 0 and w.slot == WeaponDef.Slot.PISTOL) or (c == 1 and w.slot == WeaponDef.Slot.PRIMARY):
				items.append({"id": String(w.id), "name": w.display_name, "price": w.price, "model": w.model_path})
	else:
		items.append({"id": "kevlar", "name": "Colete", "price": 650, "icon": "shield"})
		items.append({"id": "helmet", "name": "Colete + capacete", "price": 1000, "icon": "helmet"})
		if team == 1:
			items.append({"id": "defuser", "name": "Kit de desarme", "price": 400, "icon": "kit"})
	return items


func open() -> void:
	visible = true
	hud.set_ui_blocking(true)
	_shown_money = float(match_ref.local_player.money)
	_select_cat(cat)


func close() -> void:
	visible = false
	hud.set_ui_blocking(false)


func _select_cat(c: int) -> void:
	cat = c
	for i in cat_buttons.size():
		var sb := UIStyle.panel_style(Color(UIStyle.ACCENT, 0.18) if i == c else Color(1, 1, 1, 0.05), 3, 2 if i == c else 1,
			UIStyle.ACCENT if i == c else UIStyle.PANEL_LINE)
		sb.content_margin_left = 18
		cat_buttons[i].add_theme_stylebox_override("normal", sb)
	for ch in grid.get_children():
		ch.queue_free()
	cards.clear()
	var lp := match_ref.local_player
	var n := 0
	for it in _items_for(lp.team, c):
		n += 1
		_add_card(it, n)
	_refresh()


func _add_card(it: Dictionary, key: int) -> void:
	var card := Button.new()
	card.custom_minimum_size = Vector2(180, 110)
	card.focus_mode = Control.FOCUS_NONE
	var normal := UIStyle.panel_style(Color(1, 1, 1, 0.045), 4, 1)
	var hover := UIStyle.panel_style(Color(1, 1, 1, 0.09), 4, 2, UIStyle.ACCENT)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", UIStyle.panel_style(Color(UIStyle.ACCENT, 0.25), 4, 2, UIStyle.ACCENT))
	card.add_theme_stylebox_override("disabled", normal)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	grid.add_child(card)
	# silhueta / ícone
	if it.has("model"):
		var tr := TextureRect.new()
		tr.texture = _weapon_icon(it.id, it.model)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(14, 10)
		tr.size = Vector2(152, 58)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tr)
	else:
		var ic := UIStyle.Icon.new(it.icon, UIStyle.TEXT, 44)
		ic.position = Vector2(68, 14)
		ic.size = Vector2(44, 44)
		card.add_child(ic)
	var name_l := UIStyle.label(it.name, 15, UIStyle.TEXT, 600, "title")
	name_l.position = Vector2(10, 72)
	card.add_child(name_l)
	var price := UIStyle.label(UIStyle.money(int(it.price)), 16, UIStyle.MONEY, 600, "num")
	price.position = Vector2(10, 88)
	card.add_child(price)
	var keyl := UIStyle.label(str(key), 14, UIStyle.TEXT_DIM, 600, "num")
	keyl.position = Vector2(160, 6)
	card.add_child(keyl)
	var badge := UIStyle.label("EQUIPADO", 12, UIStyle.GOOD, 700, "title")
	badge.position = Vector2(100, 90)
	badge.visible = false
	card.add_child(badge)
	for ch in card.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.mouse_entered.connect(func() -> void:
		Audio.ui("ui_hover")
		var tw := card.create_tween()
		tw.tween_property(card, "position:y", card.position.y - 2.0, 0.08))
	card.mouse_exited.connect(func() -> void: grid.queue_sort())
	card.pressed.connect(func() -> void: _buy(it, card))
	cards.append({"card": card, "item": it, "price": price, "badge": badge})


func _buy(it: Dictionary, card: Control) -> void:
	if match_ref.try_buy(match_ref.local_player, it.id):
		var fl := ColorRect.new()
		fl.color = Color(UIStyle.ACCENT, 0.45)
		fl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fl)
		var tw := fl.create_tween()
		tw.tween_property(fl, "color:a", 0.0, 0.15)
		tw.tween_callback(fl.queue_free)
		_refresh()
	else:
		Audio.ui("ui_deny")


func _owned(it: Dictionary) -> bool:
	var lp := match_ref.local_player
	match String(it.id):
		"kevlar":
			return lp.armor >= 100
		"helmet":
			return lp.armor >= 100 and lp.has_helmet
		"defuser":
			return lp.has_defuser
	for ws in lp.inventory.values():
		if ws and String(ws.def.id) == String(it.id):
			return true
	return false


func _refresh() -> void:
	var lp := match_ref.local_player
	for c in cards:
		var it: Dictionary = c.item
		var price := int(it.price)
		if it.id == "helmet" and lp.armor >= 100 and not lp.has_helmet:
			price = 350
		c.price.text = UIStyle.money(price)
		var owned := _owned(it)
		var poor := lp.money < price
		c.badge.visible = owned
		c.card.disabled = poor or owned
		c.card.modulate = Color(1, 1, 1, 0.4) if poor and not owned else Color.WHITE
		c.price.add_theme_color_override("font_color", UIStyle.LOSS if poor else UIStyle.MONEY)


func _process(dt: float) -> void:
	if not visible:
		return
	var lp := match_ref.local_player
	# saldo desce contando (0,25 s)
	_shown_money = move_toward(_shown_money, float(lp.money), maxf(absf(_shown_money - lp.money) / 0.25, 400.0) * dt)
	money_label.text = UIStyle.money(int(round(_shown_money)))
	time_label.text = "Compras: " + UIStyle.time_str(match_ref.buy_left)
	_refresh()
	if not match_ref.can_buy(lp):
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			var idx := k - KEY_1
			if idx < cards.size():
				var c: Dictionary = cards[idx]
				if not c.card.disabled:
					_buy(c.item, c.card)
				else:
					Audio.ui("ui_deny")
			get_viewport().set_input_as_handled()
		elif k == KEY_Q or k == KEY_TAB:
			_select_cat((cat + 1) % CATS.size())
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ silhuetas
## Renderiza uma vez o modelo da arma de perfil, em cor lisa, num SubViewport transparente.
func _weapon_icon(id: String, path: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var vp := SubViewport.new()
	vp.size = Vector2i(304, 116)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_icon_root.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	if ResourceLoader.exists(path):
		var inst: Node3D = load(path).instantiate()
		root.add_child(inst)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = UIStyle.TEXT
		var aabb := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
			var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb() if mi.is_inside_tree() else (mi as MeshInstance3D).get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var c := aabb.get_center()
		var aspect := float(vp.size.x) / vp.size.y
		cam.size = maxf(aabb.size.y * 1.15, maxf(aabb.size.z, aabb.size.x) / aspect * 1.1)
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		vp.add_child(cam)
		# perfil: olha do lado +X; o cano (−Z) aponta para a esquerda como nos ícones do CS
		cam.transform = Transform3D(Basis.from_euler(Vector3(0, -PI / 2, 0)), c + Vector3(-5, 0, 0))
		if aabb.size.x > aabb.size.z:
			cam.transform = Transform3D(Basis(), c + Vector3(0, 0, 5))
		cam.current = true
	var tex := vp.get_texture()
	_icons[id] = tex
	return tex
