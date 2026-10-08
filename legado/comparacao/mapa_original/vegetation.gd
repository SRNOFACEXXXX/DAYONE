class_name IlhaVegetation
extends Node3D
## Vegetação autoral (docs/design/vegetacao.json -> maps/ilha/vegetacao.json): instâncias em MultiMesh por tipo
## e por bloco de 120 m (mesma grade do terreno), com distância de desenho por tipo. Colisão só nos troncos/pedras.

const BLOCO := 120.0
const BLOCO_TIPO := {"cana": 20.0, "capim_alto": 40.0}
const ALCANCE := {"cana": 48.0, "coqueiro": 480.0, "arvore_mata_a": 520.0, "arvore_mata_b": 560.0, "bananeira": 220.0,
	"arbusto": 160.0, "capim_alto": 80.0, "pedra_pequena": 120.0}
## mata atlântica real: dossel de 20–30 m e copas que se tocam (com 10 m entre troncos a copa precisa ~1,25x)
const ESCALA_TIPO := {"arvore_mata_a": 1.25, "arvore_mata_b": 1.2}
const TRONCO := {"coqueiro": 0.25, "arvore_mata_a": 0.4, "arvore_mata_b": 0.35, "bananeira": 0.18}   # raio do cilindro de colisão

## Variantes de alta qualidade dos pacotes do usuário (assets/models/cenario/natureza, pedras): a posição autoral não muda;
## a instância de índice i usa VARIANTES[tipo][i % n] ("" = modelo original). Escala por variante em VAR_ESCALA.
const VARIANTES := {
	"arvore_mata_a": ["", "cenario/natureza/carvalho", "cenario/natureza/arvore_d"],
	"arvore_mata_b": ["", "cenario/natureza/arvore_b", "cenario/natureza/betula"],
	"arbusto": ["", "cenario/natureza/arbusto_a", "cenario/natureza/arbusto_b", "cenario/natureza/samambaia_a"],
	"pedra_pequena": ["cenario/pedras/pedra_01", "cenario/pedras/pedra_02", "cenario/pedras/pedra_05", "cenario/pedras/pedra_07"],
}
## as árvores do pacote têm 5,5–8,5 m: sobem ao porte do dossel da mata (o tipo original usa ESCALA_TIPO)
const PERTO_VARIANTE := 170.0
const VAR_ESCALA := {"cenario/natureza/carvalho": 2.1, "cenario/natureza/arvore_d": 2.2, "cenario/natureza/arvore_b": 2.5,
	"cenario/natureza/betula": 1.9, "cenario/natureza/arbusto_a": 1.0, "cenario/natureza/arbusto_b": 1.0,
	"cenario/natureza/samambaia_a": 0.8}

var terrain: IlhaTerrain


func build_async(t: IlhaTerrain, path := "res://maps/ilha/vegetacao.json") -> int:
	terrain = t
	if not FileAccess.file_exists(path):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var lista: Array = data if data is Array else data.get("instancias", [])
	var meshes := {}
	var grupos := {}          # "tipo|bx|bz" -> Array[Transform3D]
	var corpo := StaticBody3D.new()
	corpo.name = "VegetacaoColisao"
	add_child(corpo)
	var casas: Array = []
	for c in get_tree().get_nodes_in_group("casa_pacote"):
		casas.append([Vector2((c as Node3D).global_position.x, (c as Node3D).global_position.z), (c as Node3D).rotation.y])
	# casas extras (casas_pacote.json) só nascem depois, no Detalhes: usa a mesma pose já ajustada (casas_ajuste.json)
	if FileAccess.file_exists("res://maps/ilha/casas_pacote.json"):
		var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/casas_pacote.json"))
		var aj: Dictionary = CasaPacote.ajustes()
		var k := 0
		for c in ex.get("casas", []):
			var a: Dictionary = aj.get("extra_%d" % k, {})
			var yw := deg_to_rad(float(a.yaw_deg)) if a.has("yaw_deg") else deg_to_rad(float(c.get("rot_deg", 0.0)))
			casas.append([Vector2(float(c.x) + float(a.get("dx", 0.0)), -float(c.y) - float(a.get("dy", 0.0))), yw])
			k += 1
	for index in lista.size():
		var it: Dictionary = lista[index]
		var dentro := false
		var xi := float(it.x)
		var zi := -float(it.y)
		for c in casas:
			var dd: Vector2 = Vector2(xi, zi) - (c[0] as Vector2)
			var yw: float = c[1]
			# espaço local da casa (+Z = frente): inverso da rotação Y do corpo
			var lx := dd.x * cos(yw) - dd.y * sin(yw)
			var lz := dd.x * sin(yw) + dd.y * cos(yw)
			if absf(lx) < 8.0 and lz > -8.4 and lz < 9.4:
				dentro = true
				break
		if dentro:
			continue
		var tipo_base: String = it.tipo
		var tipo := tipo_base
		var vs: Array = VARIANTES.get(tipo_base, [])
		if not vs.is_empty() and String(vs[index % vs.size()]) != "":
			tipo = String(vs[index % vs.size()])
		if not meshes.has(tipo):
			meshes[tipo] = _mesh_of(tipo)
		if meshes[tipo] == null:
			tipo = tipo_base
			if not meshes.has(tipo):
				meshes[tipo] = _mesh_of(tipo)
			if meshes[tipo] == null:
				continue
		var x := float(it.x)
		var z := -float(it.y)
		var y := terrain.height_world(x, z)
		var s := float(it.get("escala", 1.0)) * (float(VAR_ESCALA.get(tipo, 1.0)) if tipo != tipo_base else float(ESCALA_TIPO.get(tipo, 1.0)))
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(it.get("rot_deg", 0.0)))).scaled(Vector3(s, s, s)), Vector3(x, y - 0.05, z))
		var bl: float = BLOCO_TIPO.get(tipo_base, BLOCO)   # capim/cana: blocos menores para o corte por distância ser justo
		var key := "%s|%d|%d|%s" % [tipo, int(floor(x / bl)), int(floor(z / bl)), tipo_base]
		if not grupos.has(key):
			grupos[key] = []
		grupos[key].append(xf)
		if tipo != tipo_base and not tipo_base == "pedra_pequena":
			# LOD: a variante do pacote (500–900 faces) só até PERTO_VARIANTE; além disso, o modelo original leve no mesmo lugar
			var sb := float(it.get("escala", 1.0)) * float(ESCALA_TIPO.get(tipo_base, 1.0))
			var xb := Transform3D(Basis(Vector3.UP, deg_to_rad(float(it.get("rot_deg", 0.0)))).scaled(Vector3(sb, sb, sb)), Vector3(x, y - 0.05, z))
			var kl := "%s|%d|%d|%s|longe" % [tipo_base, int(floor(x / bl)), int(floor(z / bl)), tipo_base]
			if not grupos.has(kl):
				grupos[kl] = []
			grupos[kl].append(xb)
			if not meshes.has(tipo_base):
				meshes[tipo_base] = _mesh_of(tipo_base)
		if TRONCO.has(tipo_base):
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = TRONCO[tipo_base] * (s if tipo == tipo_base else s * 0.55)
			cyl.height = 6.0 * s
			cs.shape = cyl
			cs.position = Vector3(x, y + 3.0 * s, z)
			corpo.add_child(cs)
		if index > 0 and index % 600 == 0:
			Loading.set_progress("Distribuindo vegetação e colisões...", 25.0 + 20.0 * float(index) / maxf(1.0, float(lista.size())))
			await get_tree().process_frame
	for key in grupos:
		var tipo: String = key.split("|")[0]
		var base: String = key.split("|")[3]
		var partes: PackedStringArray = String(key).split("|")
		var longe: bool = partes.size() > 4
		var variante := tipo != base
		var xfs: Array = grupos[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[tipo]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		if base.begins_with("arvore") and not variante and not longe:
			_copas_longe(xfs, base)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = PERTO_VARIANTE if variante else ALCANCE.get(base, 300.0)
		mmi.visibility_range_end_margin = 20.0
		if longe:
			mmi.visibility_range_begin = PERTO_VARIANTE
			mmi.visibility_range_begin_margin = 20.0
			_copas_longe(xfs, base)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if base.begins_with("arvore") or base == "coqueiro" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		if get_child_count() % 30 == 0:
			await get_tree().process_frame
	return lista.size()


## Junta as superfícies do modelo glb num único ArrayMesh (materiais preservados).
func _mesh_of(tipo: String) -> Mesh:
	var p := ("res://assets/models/%s.glb" % tipo) if "/" in tipo else ("res://assets/models/veg/%s.glb" % tipo)
	if not ResourceLoader.exists(p):
		return null
	var sc: Node = load(p).instantiate()
	var mi := sc.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (mi[0] as MeshInstance3D).mesh if mi.size() > 0 else null
	sc.free()
	return m


## Impostor de copa (crítica 01, item 14): icosaedro achatado verde-escuro, 20 triângulos, de ~500 m a 1.600 m.
## Sem isso a ilha fica "careca" vista do avião (as árvores reais somem entre 520 e 560 m).
static var _copa_mesh: Mesh
static var _copa_mat: StandardMaterial3D


func _copas_longe(xfs: Array, tipo: String) -> void:
	if _copa_mesh == null:
		var sm := SphereMesh.new()
		sm.radial_segments = 6
		sm.rings = 3
		sm.radius = 1.0
		sm.height = 2.0
		_copa_mesh = sm
		_copa_mat = StandardMaterial3D.new()
		_copa_mat.albedo_color = Color("3F5E2C")
		_copa_mat.roughness = 1.0
	var alto := 15.0 if tipo == "arvore_mata_b" else 12.5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _copa_mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		var t: Transform3D = xfs[i]
		var s := t.basis.get_scale().x
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(4.6, 2.6, 4.6) * s), t.origin + Vector3.UP * alto * s))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _copa_mat
	mmi.visibility_range_begin = float(ALCANCE.get(tipo, 500.0)) - 20.0
	mmi.visibility_range_end = 1600.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
