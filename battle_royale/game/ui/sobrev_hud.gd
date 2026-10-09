extends Control
## Status de sobrevivência (fome, sede, temperatura): faixa fina logo acima da barra de saúde.
## Discreto: ícone + fio de barra, apagado quando está tudo bem; abaixo de 20% fica colorido e pulsa.
## Sem class_name (carregado por preload em hud.gd). Lê o nó core/sobrevivencia.gd do jogador local.

var sv: Node
var _fonte: Font
var _pulso := 0.0
var _vis := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = UIStyle.font(600, "num")


func vincular(s: Node) -> void:
	sv = s


func _process(dt: float) -> void:
	_pulso += dt * 6.0
	queue_redraw()


func _draw() -> void:
	if sv == null or not is_instance_valid(sv):
		return
	var est: Dictionary = sv.estado()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.075, 0.08, 0.5), true)
	var itens := [
		["food", float(est.energia) / 100.0, Color("d9a441"), float(est.energia) < 20.0],
		["drop", float(est.hidratacao) / 100.0, Color("4da3e0"), float(est.hidratacao) < 20.0],
		["temp", sv.frac_temp(), Color("e8734a") if float(est.temperatura) >= 36.0 else Color("8ec9ff"), bool(est.com_frio)],
	]
	var w := (size.x - 8.0) / 3.0
	for i in itens.size():
		var it: Array = itens[i]
		var x0 := 6.0 + i * w
		var v := clampf(it[1], 0.0, 1.0)
		var baixo: bool = it[3]
		var cor: Color = it[2]
		var a := 1.0 if baixo else 0.62
		if baixo:
			cor = Color("ff5a4a") if v < 0.1 or not (it[0] == "temp") else cor
			a = 0.65 + 0.35 * absf(sin(_pulso))
		cor.a = a
		_icone(it[0], Vector2(x0 + 7, size.y * 0.5), 6.0, cor)
		var bx := x0 + 20.0
		var bw := w - 30.0
		draw_rect(Rect2(bx, size.y * 0.5 - 2, bw, 4), Color(1, 1, 1, 0.12), true)
		draw_rect(Rect2(bx, size.y * 0.5 - 2, bw * v, 4), cor, true)
		draw_rect(Rect2(bx + bw * 0.2, size.y * 0.5 - 3, 1, 6), Color(1, 1, 1, 0.25), true)   # marca dos 20%
	# etiquetas de contexto (pequenas, à direita do bloco)
	var tag := ""
	if bool(est.perto_fogueira):
		tag = "FOGUEIRA"
	elif float(est.molhado) > 0.3:
		tag = "MOLHADO"
	if tag != "":
		draw_string(_fonte, Vector2(size.x + 8, size.y * 0.5 + 4), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8ee6ff") if tag == "MOLHADO" else Color("ffb45a"))


func _icone(kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"drop":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, s * 0.25), c + Vector2(s * 0.5, s * 0.8), c + Vector2(-s * 0.5, s * 0.8), c + Vector2(-s * 0.7, s * 0.25)]), col)
		"food":   # coxa de frango: bolota + osso
			draw_circle(c + Vector2(-s * 0.2, -s * 0.2), s * 0.62, col)
			draw_line(c + Vector2(s * 0.1, s * 0.1), c + Vector2(s * 0.75, s * 0.75), col, 2.0)
			draw_circle(c + Vector2(s * 0.8, s * 0.55), s * 0.2, col)
			draw_circle(c + Vector2(s * 0.55, s * 0.85), s * 0.2, col)
		"temp":   # termômetro
			draw_rect(Rect2(c.x - s * 0.22, c.y - s, s * 0.44, s * 1.35), col, true)
			draw_circle(c + Vector2(0, s * 0.55), s * 0.45, col)
