class_name AdminPanel
extends Control
## Painel de administrador do servidor (F10): godmode, voar e "Spawnar itens" (lista rolável com todos os itens do jogo por nome).
## O item aparece no chão a 10 passos (7,5 m) à frente do jogador, sobre o piso real (terreno ou laje), sem atravessar o mapa.

const PASSOS_M := 7.5

var _m: BRMatch
var _lista_aberta := false
var _lista: PanelContainer
var _filtro: LineEdit
var _caixa: VBoxContainer
var _botoes: Array[Button] = []
var _msg: Label
var _prev_mouse := Input.MOUSE_MODE_VISIBLE
var _chk_god: CheckButton
var _chk_voo: CheckButton


func setup(m: BRMatch) -> void:
	_m = m
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.5)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	var painel := YPanel.new("ADMINISTRADOR  ·  F10", true)
	painel.anchor_left = 0.5
	painel.anchor_right = 0.5
	painel.anchor_top = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -190
	painel.offset_right = 190
	painel.offset_top = -270
	painel.offset_bottom = 270
	add_child(painel)
	var col := painel.body
	col.add_theme_constant_override("separation", 10)
	var mg := MarginContainer.new()
	for l in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + l, 14)
	col.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	mg.add_child(v)
	_chk_god = _chk("Godmode (invulnerável)")
	_chk_god.toggled.connect(func(on: bool) -> void: _m.local_player.godmode = on)
	v.add_child(_chk_god)
	_chk_voo = _chk("Voar  (WASD · Espaço sobe · Ctrl desce · Shift acelera)")
	_chk_voo.toggled.connect(func(on: bool) -> void:
		_m.local_player.fly_admin = on
		if not on:
			_m.local_player.velocity = Vector3.ZERO)
	v.add_child(_chk_voo)
	var curar := _botao("Curar totalmente")
	curar.pressed.connect(func() -> void:
		_m.local_player.health = 100
		_msg.text = "Vida restaurada.")
	v.add_child(curar)
	v.add_child(YUI.label("HORA E CLIMA", 13, YUI.YELLOW))
	v.add_child(_fileira([["+1h", func() -> void: Clima.avancar(1.0)], ["Manhã", func() -> void: Clima.set_hora(8.0)],
		["Meio-dia", func() -> void: Clima.set_hora(12.0)], ["Noite", func() -> void: Clima.set_hora(23.0)]]))
	v.add_child(_fileira([["Limpo", func() -> void: Clima.forcar_clima(Clima.Estado.LIMPO)], ["Nublado", func() -> void: Clima.forcar_clima(Clima.Estado.NUBLADO)],
		["Chuva", func() -> void: Clima.forcar_clima(Clima.Estado.CHUVA)], ["Tempest.", func() -> void: Clima.forcar_clima(Clima.Estado.TEMPESTADE)],
		["Névoa", func() -> void: Clima.forcar_clima(Clima.Estado.NEVOEIRO)]]))
	v.add_child(_fileira([["Tempo x1", func() -> void: Clima.escala_tempo = 1.0], ["x10", func() -> void: Clima.escala_tempo = 10.0],
		["x60", func() -> void: Clima.escala_tempo = 60.0], ["Parar/Seguir", func() -> void: Clima.congelado = not Clima.congelado]]))
	v.add_child(YUI.label("SPAWNAR ITENS", 13, YUI.YELLOW))
	var sel := _botao("Selecione um item  ▾")
	sel.pressed.connect(_alternar_lista)
	v.add_child(sel)
	_msg = YUI.label("O item aparece 10 passos à frente, no chão.", 12, YUI.DIM, false)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_msg)
	var fechar := _botao("FECHAR  [F10 / Esc]")
	fechar.pressed.connect(close)
	v.add_child(fechar)
	# lista de seleção (abre abaixo do painel, com barra lateral)
	_lista = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d1d1d")
	sb.border_color = YUI.YELLOW
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	_lista.add_theme_stylebox_override("panel", sb)
	_lista.anchor_left = 0.5
	_lista.anchor_right = 0.5
	_lista.anchor_top = 0.5
	_lista.anchor_bottom = 0.5
	_lista.offset_left = -190
	_lista.offset_right = 190
	_lista.offset_top = 278
	_lista.offset_bottom = 278 + 250
	_lista.visible = false
	add_child(_lista)
	var lv := VBoxContainer.new()
	_lista.add_child(lv)
	_filtro = LineEdit.new()
	_filtro.placeholder_text = "filtrar por nome (ak, pistola, revolver…)"
	_filtro.text_changed.connect(func(_t: String) -> void: _filtrar())
	lv.add_child(_filtro)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_caixa = VBoxContainer.new()
	_caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_caixa)
	var nomes := []
	for id in BRInventory.DEFINITIONS:
		nomes.append([String(BRInventory.DEFINITIONS[id].name), String(id)])
	nomes.sort_custom(func(a, b) -> bool: return String(a[0]).naturalnocasecmp_to(String(b[0])) < 0)
	for par in nomes:
		var b := _botao(String(par[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("id", String(par[1]))
		b.pressed.connect(_spawnar.bind(String(par[1])))
		_caixa.add_child(b)
		_botoes.append(b)


func _fileira(itens: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for it in itens:
		var b := _botao(String(it[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(it[1])
		h.add_child(b)
	return h


func _chk(t: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = t
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_override("font", UIStyle.font(600, "text"))
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", YUI.TEXT)
	return c


func _botao(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	b.add_theme_font_override("font", UIStyle.font(600, "text"))
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", YUI.TEXT)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.2, 0.2, 0.19, 0.9)
	n.set_corner_radius_all(4)
	n.content_margin_left = 10
	b.add_theme_stylebox_override("normal", n)
	var h: StyleBoxFlat = n.duplicate()
	h.bg_color = Color(YUI.YELLOW, 0.85)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_hover_color", YUI.INK)
	return b


func _alternar_lista() -> void:
	_lista_aberta = not _lista_aberta
	_lista.visible = _lista_aberta
	if _lista_aberta:
		_filtro.text = ""
		_filtrar()
		_filtro.grab_focus()


func _filtrar() -> void:
	var q := _filtro.text.strip_edges().to_lower()
	for b in _botoes:
		b.visible = q == "" or b.text.to_lower().contains(q) or String(b.get_meta("id")).contains(q)


## Spawna o item a 10 passos à frente, no piso: raio de cima para baixo (terreno, lajes, assoalhos), sem passar por baixo do mapa.
func _spawnar(id: String) -> void:
	var p := _m.local_player
	var fwd := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	var alvo := p.global_position + fwd * PASSOS_M
	var def := BRInventory.definition(id)
	var qtd := 1
	var extra := {}
	match String(def.get("kind", "")):
		"ammo":
			qtd = mini(int(def.stack), 60)
		"weapon":
			extra = {"mag": int(def.mag_size)}
		"grenade":
			qtd = 2
	_m.criar_drop(id, qtd, alvo, extra)
	_msg.text = "%s spawnado 10 passos à frente." % String(def.name)
	_lista_aberta = false
	_lista.visible = false


func open() -> void:
	_chk_god.set_pressed_no_signal(_m.local_player.godmode)
	_chk_voo.set_pressed_no_signal(_m.local_player.fly_admin)
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_m.local_player.controller as PlayerController).ui_blocking = true
	_m.hud.root.visible = false
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_lista.visible = false
	_lista_aberta = false
	Input.mouse_mode = _prev_mouse
	(_m.local_player.controller as PlayerController).ui_blocking = false
	_m.hud.root.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
