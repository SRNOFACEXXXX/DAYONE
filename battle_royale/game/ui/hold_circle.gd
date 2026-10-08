class_name HoldCircle
extends Control
## Barra circular de "segurar para abrir" no centro da tela (anel que enche em sentido horário + texto do alvo).

var progresso := 0.0
var texto := ""
var redibujos := 0   # pedidos de redesenho feitos (teste de desempenho)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func mostrar(p: float, t: String) -> void:
	var visivel := p > 0.0
	if p == progresso and t == texto and visivel == visible:
		return   # nada mudou: sem redesenho (antes pedia um a cada quadro, mesmo oculto)
	progresso = p
	texto = t
	visible = visivel
	redibujos += 1
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5 + Vector2(0, 36)
	var r := 26.0
	draw_arc(c, r, 0.0, TAU, 48, Color(0, 0, 0, 0.45), 8.0, true)
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(progresso, 0.0, 1.0), 48, Color("F2C200"), 6.0, true)
	var f := UIStyle.font(700, "title")
	draw_string(f, c + Vector2(-80, r + 26), texto, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(1, 1, 1, 0.95))
