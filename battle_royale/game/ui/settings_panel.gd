class_name SettingsPanel
extends VBoxContainer
## Settings controls shared by the main menu and the pause menu.


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_title("Controles")
	_slider("Sensibilidade do mouse", 0.2, 8.0, 0.05, Settings.sensitivity, func(v): Settings.sensitivity = v)
	_toggle("Inverter eixo Y", Settings.invert_y, func(v): Settings.invert_y = v)
	_slider("Campo de visão (4:3)", 75.0, 110.0, 1.0, Settings.fov, func(v): Settings.fov = v)
	_slider("FOV da arma", 50.0, 75.0, 1.0, Settings.viewmodel_fov, func(v): Settings.viewmodel_fov = v)
	_slider("Balanço da câmera", 0.0, 1.0, 0.05, Settings.camera_bob, func(v): Settings.camera_bob = v)
	_slider("Balanço da arma", 0.0, 1.0, 0.05, Settings.viewmodel_bob, func(v): Settings.viewmodel_bob = v)
	_toggle("FOV ao correr", Settings.sprint_fov, func(v): Settings.sprint_fov = v)
	_toggle("Fôlego de corrida (stamina)", Settings.stamina_ativa, func(v): Settings.stamina_ativa = v)
	_title("Áudio")
	_slider("Volume geral", 0.0, 1.0, 0.01, Settings.master_volume, func(v): Settings.master_volume = v; Settings.apply_audio())
	_slider("Efeitos", 0.0, 1.0, 0.01, Settings.sfx_volume, func(v): Settings.sfx_volume = v; Settings.apply_audio())
	_slider("Música", 0.0, 1.0, 0.01, Settings.music_volume, func(v): Settings.music_volume = v; Settings.apply_audio())
	_slider("Rádio (vozes)", 0.0, 1.0, 0.01, Settings.voice_volume, func(v): Settings.voice_volume = v; Settings.apply_audio())
	_title("Vídeo")
	_option("Qualidade", ["Baixa", "Média", "Alta"], Settings.quality, func(i): Settings.quality = i; Settings.apply_display())
	_slider("Escala de resolução 3D", 0.5, 1.0, 0.05, Settings.render_scale, func(v): Settings.render_scale = v; Settings.apply_display())
	_toggle("Tela cheia", Settings.fullscreen, func(v): Settings.fullscreen = v; Settings.apply_display())
	_toggle("V-Sync", Settings.vsync, func(v): Settings.vsync = v; Settings.apply_display())
	_toggle("Mostrar FPS (F9)", Settings.show_fps, func(v): Settings.show_fps = v)
	_title("Mira")
	_slider("Tamanho", 2.0, 12.0, 0.5, Settings.crosshair_size, func(v): Settings.crosshair_size = v)
	_slider("Espaço central", 0.0, 10.0, 0.5, Settings.crosshair_gap, func(v): Settings.crosshair_gap = v)
	_toggle("Ponto central", Settings.crosshair_dot, func(v): Settings.crosshair_dot = v)
	_toggle("Mira dinâmica", Settings.crosshair_dynamic, func(v): Settings.crosshair_dynamic = v)


func _title(t: String) -> void:
	var l := UIStyle.label(t.to_upper(), 15, UIStyle.ACCENT, 800)
	add_child(l)


func _row(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := UIStyle.label(text, 17, UIStyle.TEXT, 500)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	add_child(h)
	return h


func _slider(text: String, mn: float, mx: float, step: float, value: float, cb: Callable) -> void:
	var h := _row(text)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v := UIStyle.label(_fmt(value, step), 16, UIStyle.TEXT_DIM, 500)
	v.custom_minimum_size.x = 60
	h.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		cb.call(x)
		v.text = _fmt(x, step)
		Settings.save_settings())


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(v))
	if step >= 0.05 and v <= 1.0:
		return "%d%%" % int(round(v * 100.0))
	return "%.2f" % v


func _toggle(text: String, value: bool, cb: Callable) -> void:
	var h := _row(text)
	var c := CheckButton.new()
	c.button_pressed = value
	h.add_child(c)
	c.toggled.connect(func(on: bool) -> void:
		cb.call(on)
		Settings.save_settings())


func _option(text: String, items: Array, idx: int, cb: Callable) -> void:
	var h := _row(text)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = idx
	o.add_theme_font_override("font", UIStyle.font(500))
	h.add_child(o)
	o.item_selected.connect(func(i: int) -> void:
		cb.call(i)
		Settings.save_settings())
