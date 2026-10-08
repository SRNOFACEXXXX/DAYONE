class_name YUI
extends RefCounted
## Linguagem visual da concept art (docs/ref/menu_inventario.jpg): painéis cinza-escuro translúcidos com leve blur,
## cabeçalho amarelo vivo com título condensado preto, slots com contador nos cantos e seleção amarelo-escuro.

const YELLOW := Color("F2C200")
const PANEL := Color("2B2B2B")
const TILE := Color(0.0, 0.0, 0.0, 0.22)
const TILE_ITEM := Color(0.32, 0.32, 0.3, 0.86)
const SELECTED := Color("6E5C0E")
const INK := Color("111111")
const TEXT := Color("F1EEE4")
const DIM := Color("A9A69A")

static var _glass: ShaderMaterial


## Vidro escuro: desfoca e escurece o que está atrás do painel (amostra mip do framebuffer).
static func glass() -> ShaderMaterial:
	if _glass == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\n" \
			+ "uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;\n" \
			+ "void fragment() {\n" \
			+ "\tvec3 bg = textureLod(screen_tex, SCREEN_UV, 2.5).rgb * 0.62;\n" \
			+ "\tCOLOR = vec4(mix(bg, COLOR.rgb, 0.86), COLOR.a);\n" \
			+ "}\n"
		_glass = ShaderMaterial.new()
		_glass.shader = sh
	return _glass


static func title_font() -> Font:
	return UIStyle.font(700, "title")


static func label(text: String, size: int, color: Color, bold := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIStyle.font(700, "title") if bold else UIStyle.font(400, "text"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	return l


## Desenha um slot de hotbar: número no canto superior esquerdo, ícone, quantidade no canto inferior direito.
static func draw_slot(ci: CanvasItem, font: Font, rect: Rect2, key: String, icon_id: String, qty: String, active: bool, empty := false) -> void:
	ci.draw_rect(rect, Color(0.11, 0.11, 0.1, 0.78) if not active else Color(SELECTED, 0.95), true)
	ci.draw_rect(rect, Color(0.62, 0.6, 0.52, 0.55) if not active else YELLOW, false, 2.0 if active else 1.0)
	if not empty and icon_id != "":
		ItemIcons.draw(ci, icon_id, rect.grow(-4.0))
	ci.draw_string(font, rect.position + Vector2(4, 12), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(TEXT, 0.92))
	if qty != "":
		ci.draw_string(font, rect.position + Vector2(0, rect.size.y - 4), qty, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4, 12, TEXT)


## Ícones de status (gota/sede/saúde) desenhados em código.
static func draw_status(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"drop":
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.62, s * 0.25), c + Vector2(s * 0.5, s * 0.72), c + Vector2(0, s), c + Vector2(-s * 0.5, s * 0.72), c + Vector2(-s * 0.62, s * 0.25)])
			ci.draw_colored_polygon(pts, col)
		"food":
			ci.draw_rect(Rect2(c.x - s * 0.7, c.y - s * 0.5, s * 1.4, s * 1.1), col, false, 2.0)
			ci.draw_line(c + Vector2(-s * 0.7, -s * 0.1), c + Vector2(s * 0.7, -s * 0.1), col, 2.0)
		"cross":
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.8, s * 0.44, s * 1.6), col)
			ci.draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.22, s * 1.6, s * 0.44), col)
		"run":
			ci.draw_circle(c + Vector2(s * 0.3, -s * 0.7), s * 0.22, col)
			ci.draw_line(c + Vector2(s * 0.2, -s * 0.4), c + Vector2(-s * 0.1, s * 0.15), col, 3.0)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.15), c + Vector2(-s * 0.6, s * 0.7), col, 3.0)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.15), c + Vector2(s * 0.45, s * 0.7), col, 3.0)
			ci.draw_line(c + Vector2(s * 0.15, -s * 0.3), c + Vector2(s * 0.7, -s * 0.05), col, 3.0)
			ci.draw_line(c + Vector2(s * 0.15, -s * 0.3), c + Vector2(-s * 0.5, -s * 0.1), col, 3.0)
