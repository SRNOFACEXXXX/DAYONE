## (sem class_name: carregado por preload, não depende do cache de classes do editor)
## Pedaços low poly que voam quando um zumbi perde a cabeça ou um membro (morte por tiro forte/explosão). RigidBody3D
## baratos: caixas/prismas chapados (pele, carne, osso), colidem só com o mundo (camada 1, o jogador não tropeça neles),
## dormem cedo e somem em ~10 s. No máximo MAX_VIVOS ao mesmo tempo (os mais antigos saem primeiro) — GT 730.

const MAX_VIVOS := 36
const VIDA_S := 10.0
const CAMADA := 1 << 5
static var _vivos: Array = []
static var _mats := {}


static func _mat(cor: Color) -> StandardMaterial3D:
	var k := cor.to_html(false)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.9
		_mats[k] = m
	return _mats[k]


## tipo: &"cabeca", &"braco", &"perna" ou &"corpo". pele: cor da pele do zumbi (variação).
static func soltar(pai: Node, pos: Vector3, dir: Vector3, tipo: StringName, pele := Color(0.55, 0.6, 0.48)) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var receita: Array = []   # [tamanho, cor, quantos]
	var carne := Color(0.45, 0.06, 0.05)
	var osso := Color(0.86, 0.82, 0.72)
	match tipo:
		&"cabeca":
			receita = [[Vector3(0.09, 0.07, 0.08), pele, 3], [Vector3(0.06, 0.05, 0.05), carne, 4], [Vector3(0.04, 0.03, 0.03), osso, 2]]
		&"braco":
			receita = [[Vector3(0.09, 0.32, 0.09), pele, 1], [Vector3(0.06, 0.05, 0.05), carne, 3]]
		&"perna":
			receita = [[Vector3(0.12, 0.4, 0.12), pele, 1], [Vector3(0.07, 0.05, 0.06), carne, 3]]
		_:
			receita = [[Vector3(0.14, 0.1, 0.12), pele, 3], [Vector3(0.08, 0.06, 0.07), carne, 6], [Vector3(0.05, 0.12, 0.04), osso, 2]]
	var base := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	for r in receita:
		for i in int(r[2]):
			var corpo := RigidBody3D.new()
			corpo.collision_layer = CAMADA
			corpo.collision_mask = 1
			corpo.mass = 0.4
			corpo.can_sleep = true
			corpo.linear_damp = 0.3
			corpo.angular_damp = 0.6
			var tam: Vector3 = r[0] * randf_range(0.75, 1.25)
			var mi := MeshInstance3D.new()
			var bm: PrimitiveMesh = BoxMesh.new() if randf() < 0.6 else PrismMesh.new()
			bm.set("size", tam)   # BoxMesh e PrismMesh têm size
			mi.mesh = bm
			mi.material_override = _mat(r[1])
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			corpo.add_child(mi)
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = tam
			cs.shape = bx
			corpo.add_child(cs)
			pai.add_child(corpo)
			corpo.global_position = pos + Vector3(randf_range(-0.08, 0.08), randf_range(0.0, 0.12), randf_range(-0.08, 0.08))
			corpo.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
			corpo.linear_velocity = base * randf_range(1.5, 4.0) + Vector3.UP * randf_range(1.5, 3.5) \
				+ Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
			corpo.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
			_vivos.append(corpo)
			var t := corpo.get_tree().create_timer(VIDA_S + randf() * 2.0)
			t.timeout.connect(func():
				if is_instance_valid(corpo):
					_vivos.erase(corpo)
					corpo.queue_free())
	while _vivos.size() > MAX_VIVOS:
		var velho = _vivos.pop_front()
		if is_instance_valid(velho):
			velho.queue_free()
