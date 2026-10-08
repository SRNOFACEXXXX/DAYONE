class_name VitalBar
extends Control
## Barra de saúde do sobrevivente: placa escura com friso amarelo, número grande, 20 segmentos que mudam de verde para âmbar e vermelho,
## rastro vermelho quando toma dano, pulso quando crítico e indicador "REGENERANDO" quando a cura lenta está ativa.

var soldier: Soldier
var _fantasma := 100.0           # rastro do dano (cai devagar até o valor real)
var _pulso := 0.0
var _flash := 0.0                # clarão branco curto ao receber dano
var _vida_antes := 100.0
var _fonte: Font
const SEG := 20


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(330, 62)
	_fonte = UIStyle.font(600, "num")


func vincular(s: Soldier) -> void:
	soldier = s
	_vida_antes = float(s.health)
	_fantasma = _vida_antes


func _process(dt: float) -> void:
	if soldier == null:
		return
	var v := float(soldier.health)
	if v < _vida_antes - 0.5:
		_flash = 1.0
	_vida_antes = v
	_fantasma = move_toward(_fantasma, v, dt * 38.0) if _fantasma > v else v
	_flash = move_toward(_flash, 0.0, dt * 3.5)
	_pulso += dt * (7.0 if v <= 25.0 else 1.5)
	queue_redraw()


func _draw() -> void:
	if soldier == null:
		return
	var v := clampf(float(soldier.health), 0.0, 100.0)
	var r := Rect2(Vector2.ZERO, size)
	# placa
	draw_rect(r, Color(0.07, 0.075, 0.08, 0.82), true)
	draw_rect(Rect2(0, 0, 5, r.size.y), YUI.YELLOW, true)
	draw_rect(r, Color(1, 1, 1, 0.07), false, 1.0)
	# cruz médica
	var cor_v := Color("6fd36b") if v > 60.0 else (Color("f2b01e") if v > 30.0 else Color("e4572e"))
	if v <= 25.0:
		cor_v = cor_v.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_pulso)))
	YUI.draw_status(self, "cross", Vector2(28, r.size.y * 0.5 - 6), 11.0, cor_v)
	# número
	draw_string(_fonte, Vector2(50, 38), str(int(ceil(v))), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, 0.96) if _flash < 0.2 else Color("ffb4a8"))
	draw_string(_fonte, Vector2(50, 53), "SAÚDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, YUI.DIM)
	var regen := soldier.t - soldier.combat_t > Soldier.REGEN_DELAY and v < 100.0
	if soldier.cura_ativa():
		var nome := String(BRInventory.definition(soldier.cura_id).get("name", "cura")).to_upper()
		draw_string(_fonte, Vector2(110, 53), "+ USANDO %s  %d%%" % [nome, int(soldier.cura_progresso() * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8ee6ff"))
	elif soldier.sangrando:
		draw_string(_fonte, Vector2(110, 53), "SANGRANDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e4572e"))
	elif regen:
		draw_string(_fonte, Vector2(110, 53), "+ REGENERANDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("6fd36b"))
	# segmentos
	var x0 := 124.0
	var larg := (r.size.x - x0 - 12.0)
	var gap := 2.0
	var w := (larg - gap * (SEG - 1)) / float(SEG)
	var h := 16.0
	var y := 12.0
	for i in SEG:
		var seg_min := float(i) / SEG * 100.0
		var seg_max := float(i + 1) / SEG * 100.0
		var rc := Rect2(x0 + i * (w + gap), y, w, h)
		draw_rect(rc, Color(1, 1, 1, 0.09), true)
		if _fantasma > seg_min:
			draw_rect(rc, Color("a63a2a", 0.7), true)             # rastro de dano
		if v > seg_min:
			var cheio := clampf((v - seg_min) / (seg_max - seg_min), 0.0, 1.0)
			draw_rect(Rect2(rc.position, Vector2(rc.size.x * cheio, rc.size.y)), cor_v, true)
	# fio inferior de reserva: linha fina com o valor exato
	draw_rect(Rect2(x0, y + h + 6, larg, 2), Color(1, 1, 1, 0.1), true)
	draw_rect(Rect2(x0, y + h + 6, larg * v / 100.0, 2), cor_v, true)
	if soldier.cura_ativa():
		# barra da cura em andamento: sobre os segmentos, azul claro, com a prévia de quanto vai recuperar
		var prog := soldier.cura_progresso()
		var heal := float(BRInventory.definition(soldier.cura_id).get("heal", 0))
		draw_rect(Rect2(x0, y + h + 2, larg * prog, 4), Color("8ee6ff"), true)
		draw_rect(Rect2(x0 + larg * v / 100.0, y - 3, larg * minf(heal, 100.0 - v) / 100.0, 3), Color(0.56, 0.9, 1.0, 0.8), true)
	if _flash > 0.0:
		draw_rect(r, Color(1, 0.3, 0.2, 0.25 * _flash), true)
