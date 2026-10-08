class_name PauseMenu
extends Control
## Esc menu: resume, settings, back to title. Pauses the simulation (offline match).

var match_ref: Match
var hud: Node
var main_box: VBoxContainer
var settings_scroll: ScrollContainer


func setup(m: Match, h: Node) -> void:
	match_ref = m
	hud = h
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.02, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := UIStyle.panel(UIStyle.BG_SOLID, 6)
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -330
	p.offset_right = 330
	p.offset_top = -300
	p.offset_bottom = 300
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var title := UIStyle.label("PAUSA", 34, UIStyle.TEXT, 800)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 10)
	v.add_child(main_box)
	var b1 := UIStyle.button("Continuar", 22, true)
	b1.pressed.connect(toggle)
	main_box.add_child(b1)
	var b2 := UIStyle.button("Configurações", 22)
	b2.pressed.connect(func() -> void:
		settings_scroll.visible = not settings_scroll.visible)
	main_box.add_child(b2)
	var b3 := UIStyle.button("Sair para o menu", 22)
	b3.pressed.connect(func() -> void:
		get_tree().paused = false
		Game.back_to_menu())
	main_box.add_child(b3)
	settings_scroll = ScrollContainer.new()
	settings_scroll.custom_minimum_size = Vector2(620, 330)
	settings_scroll.visible = false
	v.add_child(settings_scroll)
	var sp := SettingsPanel.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.add_child(sp)


func toggle() -> void:
	visible = not visible
	settings_scroll.visible = false
	get_tree().paused = visible
	hud.set_ui_blocking(visible)
