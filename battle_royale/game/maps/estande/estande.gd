class_name Estande
extends Node3D
## Estande de tiro + percurso de movimentação (medidas fixas, escritas à mão). Frente do atirador = -Z.
## Linha de tiro em z = 0, x = 0. Alvos a 10/25/50/100 m com o centro na altura do olho em pé.
## Percurso à esquerda (x < -6): porta 1,0 × 2,1 m, mureta 1,0 m, muro 1,5 m, cerca de ripas 1,1 m, caixote 0,8 m,
## escada de degraus 0,18 m e rampa de 25° até plataformas de 1,8 m.

const DISTANCIAS := [10.0, 25.0, 50.0, 100.0]
const ALVO_X := [0.0, 2.5, -2.0, 3.0]

var alvos: Array[Node3D] = []   # centro de cada alvo (Marker)
var _mats := {}


func _ready() -> void:
	_ambiente()
	_chao()
	for i in DISTANCIAS.size():
		_alvo(Vector3(ALVO_X[i], 0.0, -DISTANCIAS[i]))
	_bancada()
	_percurso()


func _mat(cor: Color) -> StandardMaterial3D:
	if not _mats.has(cor):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.9
		_mats[cor] = m
	return _mats[cor]


## Caixa visível com colisão idêntica (sem parede invisível).
func caixa(centro: Vector3, tam: Vector3, cor: Color, rot_y := 0.0, rot_x := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Soldier.LAYER_WORLD
	b.collision_mask = 0
	b.position = centro
	b.rotation = Vector3(rot_x, rot_y, 0.0)
	add_child(b)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(cor)
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = tam
	cs.shape = sh
	b.add_child(cs)
	return b


func _ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4F7DB8")
	sm.sky_horizon_color = Color("C9D6E3")
	sm.ground_horizon_color = Color("C9D6E3")
	sm.ground_bottom_color = Color("6E7B5A")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # mesmo tom quente da ilha (sem azul do céu na arma)
	env.ambient_light_color = Color("A8A195")
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sol.light_energy = 1.05
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 60.0
	add_child(sol)


func _chao() -> void:
	caixa(Vector3(0, -0.25, -50), Vector3(80, 0.5, 140), Color("5E7A3C"))
	caixa(Vector3(0, 0.005, -55), Vector3(10, 0.01, 110), Color("9C7A52"))      # raia de terra
	caixa(Vector3(0, 3.5, -121), Vector3(40, 7, 1), Color("8C7B62"))             # anteparo do fundo
	for d in DISTANCIAS:                                                            # marcas de distância no chão
		caixa(Vector3(-4.2, 0.02, -d), Vector3(1.2, 0.04, 0.12), Color("E8E0C8"))


## Alvo: placa 0,6 × 1,8 m sobre dois pés, anéis e centro vermelho de 8 cm na altura do olho.
func _alvo(base: Vector3) -> void:
	var olho := Soldier.EYE_STAND
	caixa(base + Vector3(0, olho - 0.2, 0), Vector3(0.6, 1.8, 0.04), Color("EDE6D3"))
	caixa(base + Vector3(0, olho, 0.025), Vector3(0.36, 0.36, 0.01), Color("2B2B2B"))
	caixa(base + Vector3(0, olho, 0.031), Vector3(0.22, 0.22, 0.01), Color("EDE6D3"))
	caixa(base + Vector3(0, olho, 0.037), Vector3(0.08, 0.08, 0.01), Color("C8321E"))
	for x in [-0.25, 0.25]:
		caixa(base + Vector3(x, (olho - 1.1) * 0.5, 0.05), Vector3(0.06, olho - 1.1, 0.06), Color("5A4632"))
	var mk := Marker3D.new()
	mk.name = "Alvo%d" % int(-base.z)
	mk.position = base + Vector3(0, olho, 0.04)
	add_child(mk)
	alvos.append(mk)


func _bancada() -> void:
	caixa(Vector3(0, 0.3, -1.6), Vector3(3.0, 0.6, 0.6), Color("7A5A3A"))      # bancada baixa: não tampa a mira
	for x in [-2.6, 2.6]:                                                          # divisórias da baia
		caixa(Vector3(x, 1.1, 0.0), Vector3(0.1, 2.2, 2.4), Color("8C7B62"))


func _percurso() -> void:
	var x0 := -12.0
	var parede := Color("CFC6B4")
	# V1: parede com porta de 1,0 x 2,1 m (vão livre) em z = -6
	caixa(Vector3(x0 - 2.75, 1.4, -6), Vector3(4.5, 2.8, 0.2), parede)
	caixa(Vector3(x0 + 2.75, 1.4, -6), Vector3(4.5, 2.8, 0.2), parede)
	caixa(Vector3(x0, 2.45, -6), Vector3(1.0, 0.7, 0.2), parede)
	# V2: mureta 1,0 m (z = -12) e muro 1,5 m (z = -18)
	caixa(Vector3(x0, 0.5, -12), Vector3(4.0, 1.0, 0.25), parede)
	caixa(Vector3(x0, 0.75, -18), Vector3(4.0, 1.5, 0.3), Color("B9A98C"))
	# cerca de ripas 1,1 m (z = -24): travessas + ripas com vão (colisão igual ao desenho)
	for y in [0.3, 0.9]:
		caixa(Vector3(x0, y, -24), Vector3(4.0, 0.08, 0.05), Color("8B6B4A"))
	for i in 17:
		caixa(Vector3(x0 - 2.0 + 0.25 * i, 0.55, -24.04), Vector3(0.1, 1.1, 0.025), Color("A9865E"))
	# caixote 0,8 m (z = -29)
	caixa(Vector3(x0, 0.4, -29), Vector3(1.0, 0.8, 1.0), Color("6B7042"))
	# V3: escada de 10 degraus de 0,18 m (piso 0,3 m) até plataforma de 1,8 m, à esquerda do percurso
	var ex := x0 - 7.0
	for i in 10:
		var h := 0.18 * (i + 1)
		caixa(Vector3(ex, h * 0.5, -6.0 - 0.3 * i), Vector3(1.4, h, 0.3), Color("9A8E7C"))
	caixa(Vector3(ex, 0.9, -10.5), Vector3(3.0, 1.8, 3.0), Color("8C8272"))
	# rampa de 25° (comprimento na inclinação 1,8/sin25 = 4,26 m) até outra plataforma de 1,8 m
	var comp := 1.8 / sin(deg_to_rad(25.0))
	var horiz := comp * cos(deg_to_rad(25.0))
	caixa(Vector3(ex, 0.9 - 0.1, -14.0 - horiz * 0.5), Vector3(1.6, 0.2, comp), Color("9A8E7C"), 0.0, deg_to_rad(25.0))
	caixa(Vector3(ex, 0.9, -14.0 - horiz - 1.5), Vector3(3.0, 1.8, 3.0), Color("8C8272"))
