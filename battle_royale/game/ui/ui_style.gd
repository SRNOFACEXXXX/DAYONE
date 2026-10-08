class_name UIStyle
extends RefCounted
## Tokens visuais do HUD_SPEC (cores, fontes Bahnschrift variáveis, painéis) + ícones vetoriais desenhados em código.

const TEXT := Color("F4EBDD")
const TEXT_DIM := Color("B9AE9C")
const BG := Color(0.063, 0.071, 0.078, 0.6)
const BG_SOLID := Color(0.047, 0.055, 0.063, 0.9)
const PANEL_LINE := Color(0.957, 0.922, 0.867, 0.12)
const T_COLOR := Color("E8A33D")
const T_DARK := Color("8A5A1C")
const CT_COLOR := Color("4DA3E0")
const CT_DARK := Color("1F5A85")
const MONEY := Color("E8D39A")
const GOOD := Color("9BE39B")
const LOSS := Color("FF6A6A")
const DANGER := Color("FF5A4A")
const HURT := Color("FF4D3A")
const BOMB := Color("FF3B2F")
const ACCENT := Color("D9A441")
const ARMOR := Color("9FB0C4")
const OUTLINE := Color(0.043, 0.047, 0.051, 0.7)

static var _fonts: Dictionary = {}


## kind: "num" (SemiBold Condensed), "title" (Bold Condensed), "text" (Regular)
static func font(weight := 400, kind := "") -> Font:
	var key := "%d_%s" % [weight, kind]
	if _fonts.has(key):
		return _fonts[key]
	var base := SystemFont.new()
	base.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	base.hinting = TextServer.HINTING_LIGHT
	base.allow_system_fallback = true
	var sym := SystemFont.new()
	sym.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI Emoji"])
	base.fallbacks = [sym]
	var fv := FontVariation.new()
	fv.base_font = base
	var wdth := 100
	var wght := weight
	match kind:
		"num":
			wght = 600; wdth = 75
		"title":
			wght = 700; wdth = 75
		"text":
			wght = 400; wdth = 100
	fv.variation_opentype = {"wght": wght, "wdth": wdth}
	_fonts[key] = fv
	return fv


static func label(text: String, size := 18, color := TEXT, weight := 400, kind := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


static func panel_style(color := BG, radius := 4, border := 1, border_color := PANEL_LINE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func panel(color := BG, radius := 4) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color, radius))
	return p


static func button(text: String, size := 20, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font(600, "title"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(TEXT_DIM, 0.5))
	var normal := panel_style(Color(1, 1, 1, 0.05) if not primary else Color(ACCENT, 0.92), 3, 1, PANEL_LINE)
	var hover := panel_style(Color(1, 1, 1, 0.12) if not primary else ACCENT.lightened(0.12), 3, 2, ACCENT)
	var pressed := panel_style(Color(0, 0, 0, 0.3), 3, 2, ACCENT)
	var disabled := panel_style(Color(1, 1, 1, 0.02), 3, 1, PANEL_LINE)
	for sb in [normal, hover, pressed, disabled]:
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	if primary:
		b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04))
		b.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.02))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), 3, 2, ACCENT))
	b.mouse_entered.connect(func() -> void: Audio.ui("ui_hover"))
	b.pressed.connect(func() -> void: Audio.ui("ui_click"))
	return b


static func team_color(team: int) -> Color:
	return T_COLOR if team == 0 else CT_COLOR


## "$ 4 750" com espaço fino de milhar
static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return ("-$ " if v < 0 else "$ ") + out


static func time_str(sec: float) -> String:
	var s := int(ceil(maxf(sec, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


# ------------------------------------------------------------------ ícones vetoriais
## Desenha um ícone no CanvasItem ci, centrado em c, com tamanho s (px).
static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	var o := Color(0, 0, 0, col.a * 0.6)
	match kind:
		"cross":
			var t := s * 0.32
			for rr in [[Rect2(c.x - t / 2 - 1, c.y - s / 2 - 1, t + 2, s + 2), o], [Rect2(c.x - s / 2 - 1, c.y - t / 2 - 1, s + 2, t + 2), o],
					[Rect2(c.x - t / 2, c.y - s / 2, t, s), col], [Rect2(c.x - s / 2, c.y - t / 2, s, t), col]]:
				ci.draw_rect(rr[0], rr[1])
		"shield", "helmet":
			var pts := PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.45), c + Vector2(s * 0.42, -s * 0.45), c + Vector2(s * 0.42, 0.0),
				c + Vector2(0, s * 0.5), c + Vector2(-s * 0.42, 0.0)])
			ci.draw_colored_polygon(pts, o)
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * 0.82)
			ci.draw_colored_polygon(inner, col)
			if kind == "helmet":
				ci.draw_rect(Rect2(c.x - s * 0.42, c.y - s * 0.62, s * 0.84, s * 0.14), col)
		"c4":
			ci.draw_rect(Rect2(c.x - s * 0.5, c.y - s * 0.3, s, s * 0.6), o)
			ci.draw_rect(Rect2(c.x - s * 0.45, c.y - s * 0.26, s * 0.9, s * 0.52), col)
			ci.draw_rect(Rect2(c.x - s * 0.15, c.y - s * 0.18, s * 0.42, s * 0.2), Color(0.05, 0.05, 0.05, col.a))
			ci.draw_line(c + Vector2(-s * 0.45, -s * 0.1), c + Vector2(-s * 0.62, -s * 0.4), col, 2.0)
		"kit":
			ci.draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.25, s * 0.8, s * 0.5), col)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.25), c + Vector2(-s * 0.1, -s * 0.5), col, 2.0)
			ci.draw_line(c + Vector2(s * 0.2, -s * 0.25), c + Vector2(s * 0.1, -s * 0.5), col, 2.0)
		"skull":
			ci.draw_circle(c + Vector2(0, -s * 0.08), s * 0.36, col)
			ci.draw_rect(Rect2(c.x - s * 0.2, c.y + s * 0.1, s * 0.4, s * 0.25), col)
			ci.draw_circle(c + Vector2(-s * 0.13, -s * 0.08), s * 0.09, Color(0, 0, 0, col.a))
			ci.draw_circle(c + Vector2(s * 0.13, -s * 0.08), s * 0.09, Color(0, 0, 0, col.a))
		"headshot":
			ci.draw_arc(c, s * 0.42, 0, TAU, 20, col, 2.0)
			ci.draw_circle(c, s * 0.12, col)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(c + d * s * 0.3, c + d * s * 0.55, col, 2.0)
		"wallbang":
			ci.draw_rect(Rect2(c.x - s * 0.08, c.y - s * 0.5, s * 0.16, s), col)
			ci.draw_line(c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.5, 0), col, 2.0)
		"cart":
			ci.draw_line(c + Vector2(-s * 0.5, -s * 0.35), c + Vector2(-s * 0.3, -s * 0.35), col, 2.0)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.35), c + Vector2(-s * 0.15, s * 0.15), col, 2.0)
			ci.draw_line(c + Vector2(-s * 0.15, s * 0.15), c + Vector2(s * 0.4, s * 0.15), col, 2.0)
			ci.draw_line(c + Vector2(s * 0.4, s * 0.15), c + Vector2(s * 0.5, -s * 0.2), col, 2.0)
			ci.draw_line(c + Vector2(s * 0.5, -s * 0.2), c + Vector2(-s * 0.25, -s * 0.2), col, 2.0)
			ci.draw_circle(c + Vector2(-s * 0.08, s * 0.33), s * 0.08, col)
			ci.draw_circle(c + Vector2(s * 0.35, s * 0.33), s * 0.08, col)
		"star":
			var p := PackedVector2Array()
			for i in 10:
				var r := s * (0.5 if i % 2 == 0 else 0.22)
				var a := -PI / 2 + i * PI / 5
				p.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(p, col)
		"bullet":
			ci.draw_rect(Rect2(c.x - s * 0.12, c.y - s * 0.2, s * 0.24, s * 0.6), col)
			ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.12, col)


## Controle simples que desenha um ícone.
class Icon extends Control:
	var kind := "cross"
	var color := Color.WHITE
	func _init(k := "cross", col := Color.WHITE, sz := 22.0) -> void:
		kind = k
		color = col
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		UIStyle.draw_icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.9, color)
