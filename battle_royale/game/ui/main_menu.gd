extends Control
## Menu principal no estilo da concept art (docs/ref/menu_inventario.jpg): diorama 3D vivo da vila com o soldado ao centro,
## painéis escuros com cabeçalho amarelo à esquerda ("JOGAR") e à direita ("EQUIPAMENTO"), hotbar 1–7 e status na base.

class Hotbar extends Control:
	const SLOTS := [["ak47", "", "80-47"], ["ammo_762", "30", ""], ["plate", "3", ""], ["acog", "", ""], ["", "", ""], ["grenade", "2", ""], ["vest", "", ""]]
	var font: Font = UIStyle.font(600, "num")
	func _init() -> void:
		custom_minimum_size = Vector2(7 * 52 + 6 * 4, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		ItemIcons.when_ready(queue_redraw)
	func _draw() -> void:
		for i in 7:
			var r := Rect2(i * 56, 0, 52, 52)
			var s: Array = SLOTS[i]
			YUI.draw_slot(self, font, r, str(i + 1), String(s[0]), String(s[1]), i == 0, String(s[0]) == "")


class Vitals extends Control:
	var kind := "left"
	func _init(k: String) -> void:
		kind = k
		custom_minimum_size = Vector2(190, 40) if k == "left" else Vector2(200, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if kind == "left":
			YUI.draw_status(self, "run", Vector2(12, 10), 9.0, YUI.TEXT)
			draw_rect(Rect2(28, 8, 130, 4), Color(1, 1, 1, 0.28))
			draw_rect(Rect2(28, 8, 96, 4), Color(1, 1, 1, 0.9))
			YUI.draw_status(self, "food", Vector2(12, 30), 8.0, YUI.TEXT)
			draw_rect(Rect2(28, 28, 130, 4), Color(1, 1, 1, 0.28))
			draw_rect(Rect2(28, 28, 110, 4), Color(1, 1, 1, 0.9))
			var up := PackedVector2Array([Vector2(172, 2), Vector2(180, 14), Vector2(164, 14)])
			draw_colored_polygon(up, YUI.TEXT)
			draw_rect(Rect2(170, 14, 4, 14), YUI.TEXT)
		else:
			YUI.draw_status(self, "drop", Vector2(14, 20), 11.0, Color("d8d8d0"))
			YUI.draw_status(self, "food", Vector2(52, 20), 10.0, Color("d8d8d0"))
			YUI.draw_status(self, "drop", Vector2(92, 20), 11.0, Color("3aa0e0"))
			YUI.draw_status(self, "drop", Vector2(132, 20), 8.0, Color("ffffff"))
			YUI.draw_status(self, "cross", Vector2(172, 20), 10.0, Color("ffffff"))


class Loadout extends Control:
	const ITEMS := [["ammo_762", "30"], ["ammo_556", "24"], ["plate", "3"], ["grenade", "2"], ["acog", ""], ["ammo_9mm", "36"], ["vest", ""], ["backpack_medium", ""]]
	var font: Font = UIStyle.font(600, "num")
	func _init() -> void:
		custom_minimum_size = Vector2(0, 100)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		ItemIcons.when_ready(queue_redraw)
	func _draw() -> void:
		var cols := 4
		var cell := (size.x - 4.0) / cols
		for i in ITEMS.size():
			var r := Rect2((i % cols) * cell + 2, (i / cols) * 48.0 + 2, cell - 4, 44)
			draw_rect(r, YUI.TILE_ITEM if i != 0 else YUI.SELECTED, true)
			ItemIcons.draw(self, String(ITEMS[i][0]), r.grow(-3))
			if String(ITEMS[i][1]) != "":
				draw_string(font, r.position + Vector2(0, r.size.y - 3), String(ITEMS[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 3, 12, YUI.TEXT)


var _settings_overlay: Control
var _weapon_icon: TextureRect
var stage: MenuStage
var criador: CriadorPersonagem
var _colunas: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.ambient("amb_village", -20.0)
	_build_ui()
	ItemIcons.when_ready(_apply_weapon_icon)
	if Game.test_args.has("autostart"):
		call_deferred("_test_autostart")
	elif Game.test_args.get("modo", "") != "antes":
		# aquecimento da partida em segundo plano enquanto o jogador navega / monta o personagem
		get_tree().create_timer(0.6).timeout.connect(Loading.iniciar_aquecimento)


func _test_autostart() -> void:
	Game.start_match()


func _apply_weapon_icon() -> void:
	if _weapon_icon and is_instance_valid(_weapon_icon):
		_weapon_icon.texture = ItemIcons.texture_for("ak47")


func _build_ui() -> void:
	stage = MenuStage.new(true, -22.0)
	stage.name = "DioramaTaua"
	add_child(stage)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.12)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	# ---- coluna esquerda: título + JOGAR + controles
	var left := VBoxContainer.new()
	left.name = "Esquerda"
	left.anchor_left = 0.0
	left.anchor_right = 0.0
	left.offset_left = 44
	left.offset_right = 44 + 318
	left.offset_top = 40
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	var title := YPanel.new("DAYONE", true)
	title.name = "Titulo"
	var tl: Label = title.title_label
	tl.add_theme_font_size_override("font_size", 40)
	var sub := YUI.label("SOBREVIVÊNCIA", 22, YUI.YELLOW)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.body.add_child(sub)
	var sub2 := YUI.label("ILHA DO TAUÁ  ·  PROTÓTIPO JOGÁVEL", 13, YUI.DIM, false)
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.body.add_child(sub2)
	left.add_child(title)

	var play_panel := YPanel.new("JOGAR", true)
	play_panel.name = "Navegacao"
	play_panel.body.add_theme_constant_override("separation", 3)
	var b_play := _menu_button("JOGAR", true)
	b_play.pressed.connect(abrir_criador)
	play_panel.body.add_child(b_play)
	var b_explore := _menu_button("EXPLORAR A ILHA")
	b_explore.pressed.connect(_explore)
	play_panel.body.add_child(b_explore)
	var b_settings := _menu_button("CONFIGURAÇÕES")
	b_settings.pressed.connect(_show_settings)
	play_panel.body.add_child(b_settings)
	var b_quit := _menu_button("SAIR")
	b_quit.pressed.connect(get_tree().quit)
	play_panel.body.add_child(b_quit)
	left.add_child(play_panel)

	var hints := YPanel.new("CONTROLES", false)
	hints.name = "Controles"
	var ht := YUI.label("WASD mover   ·   Mouse olhar   ·   E recolher\nC câmera   ·   I inventário   ·   G granada   ·   B placa", 13, YUI.TEXT, false)
	hints.body.add_child(ht)
	left.add_child(hints)

	# ---- coluna direita: EQUIPAMENTO
	var right := VBoxContainer.new()
	right.name = "Direita"
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -44 - 318
	right.offset_right = -44
	right.offset_top = 40
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	var equip := YPanel.new("EQUIPAMENTO", true)
	equip.name = "Equipamento"
	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(0, 128)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip.body.add_child(_weapon_icon)
	var cap := YUI.label("AK-47  ·  7,62 mm  ·  30/30", 15, YUI.TEXT, false)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip.body.add_child(cap)
	right.add_child(equip)
	var vest := YPanel.new("COLETE DE CAMPO (8/20)", false, "vest", true)
	vest.name = "Colete"
	vest.body.add_child(Loadout.new())
	right.add_child(vest)

	# ---- base: estamina (esq), hotbar (centro) e status (dir)
	var bars := Vitals.new("left")
	bars.anchor_top = 1.0
	bars.anchor_bottom = 1.0
	bars.offset_left = 44
	bars.offset_top = -66
	bars.offset_right = 44 + 190
	bars.offset_bottom = -26
	add_child(bars)
	var hot := Hotbar.new()
	hot.name = "Hotbar"
	hot.anchor_left = 0.5
	hot.anchor_right = 0.5
	hot.anchor_top = 1.0
	hot.anchor_bottom = 1.0
	hot.offset_left = -(7 * 56 - 4) / 2.0
	hot.offset_right = (7 * 56 - 4) / 2.0
	hot.offset_top = -70
	hot.offset_bottom = -18
	add_child(hot)
	var vit := Vitals.new("right")
	vit.anchor_left = 1.0
	vit.anchor_right = 1.0
	vit.anchor_top = 1.0
	vit.anchor_bottom = 1.0
	vit.offset_left = -44 - 200
	vit.offset_right = -44
	vit.offset_top = -66
	vit.offset_bottom = -26
	add_child(vit)

	_colunas = [left, right, bars, hot, vit]
	criador = CriadorPersonagem.new(stage)
	criador.visible = false
	criador.voltar.connect(fechar_criador)
	criador.confirmado.connect(func(_d: Dictionary) -> void: Game.start_match())
	add_child(criador)

	_build_settings_overlay()


func _menu_button(text_value: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text_value
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UIStyle.font(700, "title"))
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_color_override("font_color", YUI.YELLOW if primary else YUI.TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", YUI.YELLOW)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.05 if not primary else 0.09)
	normal.border_width_left = 6 if primary else 0
	normal.border_color = YUI.YELLOW
	normal.content_margin_left = 20
	normal.set_corner_radius_all(2)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.14)
	hover.border_width_left = 8
	hover.content_margin_left = 18
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.mouse_entered.connect(func() -> void: Audio.ui("ui_hover"))
	b.pressed.connect(func() -> void: Audio.ui("ui_click"))
	return b


func _build_settings_overlay() -> void:
	_settings_overlay = Control.new()
	_settings_overlay.name = "Configuracoes"
	_settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	add_child(_settings_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.012, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(dim)
	var panel := YPanel.new("CONFIGURAÇÕES", true, "", false, false)
	panel.anchor_left = 0.16
	panel.anchor_top = 0.03
	panel.anchor_right = 0.84
	panel.anchor_bottom = 0.97
	_settings_overlay.add_child(panel)
	var heading := HBoxContainer.new()
	panel.body.add_child(heading)
	var hint := YUI.label("Ajuste vídeo, áudio e controles", 14, YUI.DIM, false)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(hint)
	var back := _menu_button("VOLTAR  [Esc]", true)
	back.custom_minimum_size = Vector2(190, 38)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_hide_settings)
	heading.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.body.add_child(scroll)
	var settings_panel := SettingsPanel.new()
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_panel)


func _show_settings() -> void:
	_settings_overlay.visible = true


func _hide_settings() -> void:
	_settings_overlay.visible = false


## JOGAR -> tela PERSONAGEM (o aquecimento continua rodando atrás).
func abrir_criador() -> void:
	for c in _colunas:
		c.visible = false
	criador.abrir()


func fechar_criador() -> void:
	criador.fechar()
	for c in _colunas:
		c.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	if criador != null and criador.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		fechar_criador()
		get_viewport().set_input_as_handled()
		return
	if _settings_overlay != null and _settings_overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_hide_settings()
		get_viewport().set_input_as_handled()


func _explore() -> void:
	Game.config["map"] = "ilha"
	Loading.show_progress("Preparando exploração...", 3.0)
	get_tree().change_scene_to_file("res://maps/ilha/ilha.tscn")
