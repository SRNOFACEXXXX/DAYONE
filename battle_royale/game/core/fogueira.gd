extends Node3D
## Fogueira de jogo: combustível (minutos), luz barata sem sombra, chama/fumaça leves, calor e cozinhar.
## Sem class_name (use preload). Acesa = grupo "fogueira_acesa" (outro sistema usa para aquecer o jogador).
## Sempre no grupo "fogueira". `raio_calor` = alcance do calor em metros (quem aquece lê esta propriedade).

const MODELO := "res://assets/models/itens/fogueira.glb"
const MAX_MIN := 30.0
const COZINHA_S := 4.0
const ACENDE_S := 0.8

var combustivel_s := 0.0
var acesa := false
var raio_calor := 5.0
var _luz: OmniLight3D
var _fogo: CPUParticles3D
var _fumaca: CPUParticles3D
var _brasa: MeshInstance3D
var _t := 0.0


## Cria a fogueira apagada em `pos` (mundo) com `minutos` de lenha.
static func criar(pai: Node, pos: Vector3, minutos: float) -> Node3D:
	var f: Node3D = load("res://core/fogueira.gd").new()
	pai.add_child(f)
	f.global_position = pos
	f.combustivel_s = minf(minutos, MAX_MIN) * 60.0
	return f


## As mais próximas acesas (≤ r m) de `p`, ou null.
static func acesa_perto(arvore: SceneTree, p: Vector3, r: float) -> Node3D:
	var melhor: Node3D = null
	var dm := r * r
	for n in arvore.get_nodes_in_group("fogueira_acesa"):
		var d := (n as Node3D).global_position.distance_squared_to(p)
		if d <= dm:
			dm = d
			melhor = n
	return melhor


## Qualquer fogueira (acesa ou não) perto de `p`.
static func qualquer_perto(arvore: SceneTree, p: Vector3, r: float) -> Node3D:
	var melhor: Node3D = null
	var dm := r * r
	for n in arvore.get_nodes_in_group("fogueira"):
		var d := (n as Node3D).global_position.distance_squared_to(p)
		if d <= dm:
			dm = d
			melhor = n
	return melhor


func minutos() -> float:
	return combustivel_s / 60.0


func _ready() -> void:
	name = "Fogueira"
	add_to_group("fogueira")
	if ResourceLoader.exists(MODELO):
		var m: Node3D = (load(MODELO) as PackedScene).instantiate()
		add_child(m)
		for g in m.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(g as GeometryInstance3D).visibility_range_end = 120.0
	_luz = OmniLight3D.new()
	_luz.light_color = Color("ff9a3c")
	_luz.light_energy = 0.0
	_luz.omni_range = 8.0
	_luz.shadow_enabled = false
	_luz.distance_fade_enabled = true
	_luz.distance_fade_begin = 45.0
	_luz.distance_fade_length = 15.0
	_luz.position = Vector3(0, 0.8, 0)
	add_child(_luz)
	var gt := GradientTexture2D.new()   # bolinha macia (sem isso as partículas viram retângulos)
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gg
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = gt
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1, 1, 1, 1)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	_fogo = CPUParticles3D.new()
	_fogo.amount = 12
	_fogo.lifetime = 0.7
	_fogo.direction = Vector3.UP
	_fogo.spread = 12.0
	_fogo.gravity = Vector3(0, 1.4, 0)
	_fogo.initial_velocity_min = 0.3
	_fogo.initial_velocity_max = 0.8
	_fogo.scale_amount_min = 0.5
	_fogo.scale_amount_max = 1.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1.0, 0.85, 0.3, 0.9))
	rampa.set_color(1, Color(0.9, 0.15, 0.0, 0.0))
	_fogo.color_ramp = rampa
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1.0))
	curva.add_point(Vector2(1, 0.15))
	_fogo.scale_amount_curve = curva
	_fogo.mesh = quad
	_fogo.material_override = mat
	_fogo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fogo.visibility_range_end = 70.0
	_fogo.position = Vector3(0, 0.25, 0)
	_fogo.emitting = false
	add_child(_fogo)
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_texture = gt
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat2.vertex_color_use_as_albedo = true
	mat2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad2 := QuadMesh.new()
	quad2.size = Vector2(0.5, 0.5)
	_fumaca = CPUParticles3D.new()
	_fumaca.amount = 6
	_fumaca.lifetime = 2.6
	_fumaca.direction = Vector3.UP
	_fumaca.spread = 10.0
	_fumaca.gravity = Vector3(0.1, 0.9, 0)
	_fumaca.initial_velocity_min = 0.2
	_fumaca.initial_velocity_max = 0.5
	var rampa2 := Gradient.new()
	rampa2.set_color(0, Color(0.35, 0.35, 0.35, 0.28))
	rampa2.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	_fumaca.color_ramp = rampa2
	var curva2 := Curve.new()
	curva2.add_point(Vector2(0, 0.5))
	curva2.add_point(Vector2(1, 2.2))
	_fumaca.scale_amount_curve = curva2
	_fumaca.mesh = quad2
	_fumaca.material_override = mat2
	_fumaca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fumaca.visibility_range_end = 60.0
	_fumaca.position = Vector3(0, 0.8, 0)
	_fumaca.emitting = false
	add_child(_fumaca)
	set_process(false)


func acender() -> bool:
	if acesa or combustivel_s <= 0.0:
		return false
	acesa = true
	add_to_group("fogueira_acesa")
	_fogo.emitting = true
	_fumaca.emitting = true
	_luz.light_energy = 1.2
	set_process(true)
	return true


func apagar() -> void:
	if not acesa:
		return
	acesa = false
	remove_from_group("fogueira_acesa")
	_fogo.emitting = false
	_fumaca.emitting = false
	_luz.light_energy = 0.0
	set_process(false)


## Mais lenha (minutos). Em chamas ou apagada. Devolve os minutos realmente adicionados (teto de MAX_MIN).
func adicionar(min_add: float) -> float:
	var antes := combustivel_s
	combustivel_s = minf(combustivel_s + min_add * 60.0, MAX_MIN * 60.0)
	return (combustivel_s - antes) / 60.0


func _process(dt: float) -> void:
	_t += dt
	combustivel_s -= dt
	if combustivel_s <= 0.0:
		combustivel_s = 0.0
		apagar()
		return
	# luz bruxuleante e fraca no fim da lenha
	var fim := clampf(combustivel_s / 20.0, 0.25, 1.0)
	_luz.light_energy = (1.1 + 0.2 * sin(_t * 11.0) + 0.1 * sin(_t * 23.0 + 1.3)) * fim
