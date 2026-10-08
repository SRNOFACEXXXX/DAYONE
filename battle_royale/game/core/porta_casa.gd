class_name PortaCasa
extends Node3D
## Porta da casa do pacote: folha própria presa à dobradiça (origem deste nó), colisão de caixa que gira junto.
## E alterna aberta/fechada com animação de 0,45 s (abre para dentro, 100°). Fechada bloqueia; aberta deixa o vão livre.

const GLB := "res://assets/models/cenario/casas/casa_demo_porta.glb"
const LARGURA := 1.007
const ALTURA := 2.246
const ANGULO := 100.0

var aberta := false
var _tw: Tween
var _giro := Node3D.new()


func _ready() -> void:
	add_to_group("porta")
	add_child(_giro)
	var vis: Node3D = (load(GLB) as PackedScene).instantiate()
	_giro.add_child(vis)
	for g in vis.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(g as GeometryInstance3D).visibility_range_end = 120.0
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Soldier.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LARGURA, ALTURA, 0.14)
	cs.shape = bs
	cs.position = Vector3(LARGURA * 0.5, ALTURA * 0.5, 0.0)
	corpo.add_child(cs)
	_giro.add_child(corpo)


## Centro da folha fechada no mundo (alvo da mira / distância).
func centro() -> Vector3:
	return global_transform * Vector3(LARGURA * 0.5, ALTURA * 0.5, 0.0)


func alternar() -> void:
	aberta = not aberta
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_giro, "rotation:y", deg_to_rad(ANGULO) if aberta else 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Audio.play_at("draw_generic", centro(), {"volume_db": -8.0, "max_distance": 14.0, "pitch": 0.7 if aberta else 0.6})
