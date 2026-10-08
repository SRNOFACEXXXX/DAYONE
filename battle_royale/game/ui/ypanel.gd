class_name YPanel
extends PanelContainer
## Painel escuro translúcido com cabeçalho amarelo (estilo da concept art do menu/inventário).

class IconBox extends Control:
	var icon_id := ""
	func _init(id: String) -> void:
		icon_id = id
		custom_minimum_size = Vector2(24, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		ItemIcons.draw(self, icon_id, Rect2(Vector2.ZERO, size))

var body: VBoxContainer
var header: PanelContainer
var title_label: Label
var close_label: Label


## big: título grande centralizado ("PROXIMIDADE"); senão cabeçalho compacto ("COLETE DE CAMPO (18/20)") com ícone opcional.
func _init(text := "", big := true, icon_id := "", closable := false, glass := true) -> void:
	clip_contents = true
	if glass:
		material = YUI.glass()
	var sb := StyleBoxFlat.new()
	sb.bg_color = YUI.PANEL if glass else Color(YUI.PANEL, 0.97)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(0)
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	if text != "":
		header = PanelContainer.new()
		var hs := StyleBoxFlat.new()
		hs.bg_color = YUI.YELLOW
		hs.corner_radius_top_left = 8
		hs.corner_radius_top_right = 8
		hs.content_margin_left = 10
		hs.content_margin_right = 10
		hs.content_margin_top = 1 if big else 2
		hs.content_margin_bottom = 1 if big else 2
		header.add_theme_stylebox_override("panel", hs)
		col.add_child(header)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		header.add_child(row)
		if icon_id != "":
			var ib := IconBox.new(icon_id)
			ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ib)
		title_label = YUI.label(text, 30 if big else 17, YUI.INK)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not big:
			title_label.add_theme_font_override("font", UIStyle.font(600, "num"))
		row.add_child(title_label)
		if closable:
			close_label = YUI.label("✕", 15, YUI.INK)
			row.add_child(close_label)
		elif icon_id != "":
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(24, 0)
			row.add_child(pad)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for e in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + e, 6)
	col.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)


func set_title(text: String) -> void:
	if title_label != null:
		title_label.text = text
