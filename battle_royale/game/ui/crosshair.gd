class_name Crosshair
extends Control
## CS-style crosshair: four lines + optional dot, gap grows with inaccuracy.

## 0..1, definido pelo PlayerController: ao mirar (ADS) a cruz do HUD some; a mira é a da arma/luneta (uma só).
static var ads_amount := 0.0
var spread_deg := 0.0
var visible_for := true
var fov_v := 73.7
var dot_only := false   # AWP/faca/bomba: só o ponto central


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not visible_for or ads_amount > 0.25:
		return
	var c := size * 0.5
	var col := Settings.crosshair_color
	var th := Settings.crosshair_thickness
	var ln := Settings.crosshair_size
	var gap := Settings.crosshair_gap
	if Settings.crosshair_dynamic:
		# converte o spread (graus) para pixels na tela
		var px_per_deg := size.y / fov_v
		gap += minf(spread_deg * px_per_deg * 0.9, 60.0)
	var outline := Color(0, 0, 0, 0.75)
	if dot_only:
		var d0 := Rect2(c - Vector2(3, 3), Vector2(6, 6))
		draw_rect(d0.grow(1.0), outline)
		draw_rect(d0, col)
		return
	var rects := [
		Rect2(c.x - th * 0.5, c.y - gap - ln, th, ln),
		Rect2(c.x - th * 0.5, c.y + gap, th, ln),
		Rect2(c.x - gap - ln, c.y - th * 0.5, ln, th),
		Rect2(c.x + gap, c.y - th * 0.5, ln, th),
	]
	for r: Rect2 in rects:
		draw_rect(r.grow(1.0), outline)
	for r: Rect2 in rects:
		draw_rect(r, col)
	if Settings.crosshair_dot:
		var d := Rect2(c - Vector2(th, th) * 0.5, Vector2(th, th))
		draw_rect(d.grow(1.0), outline)
		draw_rect(d, col)
