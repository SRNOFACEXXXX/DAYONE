class_name CasaPacote
extends RefCounted
## Casa completa do pacote de interiores (cenario/casas/casa_demo.glb): corpo estático com colisão fiel (trimesh por peça),
## mobília (moveis.json["casa_demo"]), saque nos armários da cozinha e saia de concreto sob o piso. Origem = centro da pegada
## no terreno MAIS ALTO sob ela; frente (porta) = +Z local.

const GLB := "res://assets/models/cenario/casas/casa_demo.glb"
const TIPOS := ["casa_laje", "casa_caicara", "casa_colono", "sobrado", "casa_faroleiro", "casa_piloto", "casa_operador", "vila_operaria", "casarao"]
static var _cena: PackedScene
static var _saia: StandardMaterial3D
static var _malha: ArrayMesh          # todas as peças fundidas por material (≈10 superfícies em vez de 56 draw calls por casa)
static var _variantes: Array[ArrayMesh] = []   # mesma geometria, revestimento externo em outras cores (vila deixa de ser clone)
static var _variantes_longe: Array[ArrayMesh] = []   # desempenho: sem as superfícies internas (parede/piso/teto), além de PERTO_INTERIOR
const PERTO_INTERIOR := 55.0
static var _contador := 0
static var _colisao: ConcavePolygonShape3D   # trimesh único e compartilhado entre as casas
## peças da cozinha do glb trocadas pelos móveis do pack "props interiores" (moveis.json["casa_demo_cozinha"]):
## bancadas/armários (028, 030, 031, 038), mesa+cadeiras+toalha (032–037) e geladeira (041, 042). O fogão (029) fica (o pack não tem).
## papel das superfícies do interior (nome do nó do glb -> papel), recebem materiais próprios por variante
const PAPEIS := {"WallpaperForties": "parede", "_040_Wood_02_": "piso", "_040_Concrete_0": "teto"}
const SHADER_PAREDE := "res://assets/models/atualizacao/interiores/parede_casa.gdshader"
const SHADER_PISO := "res://assets/models/atualizacao/interiores/piso_casa.gdshader"
## paletas internas por casa: [cozinha, sala, quarto NE, quarto SE, banheiro, hall, lambri, madeira escura, madeira clara, ladrilho]
const PALETAS := [
	["c8e3cf", "f0d9a8", "a9c6e6", "f2b8ae", "bfe6ea", "eee2c6", "4f8a7e", "7a4a26", "b07a45", "2f7f7a"],
	["f3e1a0", "bfe0c8", "f0c0cf", "a8d0e0", "c8e8e0", "f2e6cc", "a04f3c", "5e3a22", "94643c", "c0503c"],
	["d7e8b8", "f2c99a", "c5b6e3", "b6dccf", "cfe4f0", "efe3c8", "3f6d8f", "8a5a30", "c48d55", "3a6d9a"],
	["f4cfb0", "c6dbe8", "e8e0a8", "c8e6b8", "d8ecf0", "f0e4cc", "6d8a3a", "6b4024", "a8703f", "6d9a3a"],
	["bfe2e6", "f0d0b0", "d8e6b0", "e6c0d8", "c0e0f0", "f2e8d0", "8a5a8f", "70482a", "b8834e", "8a5a8f"],
	["f0e6b8", "e8b8a8", "b8d8f0", "d0e8c0", "d0f0ec", "efe0c0", "2f6f5f", "5a3820", "9a6a40", "d08a30"],
]
## (sem luzes por cômodo: o mapa já está no limite da GT 730; o "AO" falso vem do shader das paredes e das manchas sob os móveis)
static var _papeis: Dictionary = {}    # índice da superfície de _malha -> papel
const EXCLUIR_COZINHA := ["_028_", "_030_", "_031_", "_032_", "_033_", "_034_", "_035_", "_036_", "_037_", "_038_", "_041_", "_042_", "Demo_Refrigerator"]


## Junta as peças do glb numa só malha (uma superfície por material) e num só trimesh de colisão (fiel: portas/janelas abertas).
static func _fundir() -> void:
	var sc: Node3D = _cena.instantiate()
	var por_mat := {}   # Material -> {v, n, uv, i}
	var tris := PackedVector3Array()
	var papel_mat := {}   # Material -> papel (parede/piso/teto)
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var pular := false
		for ex in EXCLUIR_COZINHA:
			if String(m.name).contains(ex):
				pular = true
		if pular:
			continue
		var xf := Transform3D.IDENTITY
		var no: Node = m
		while no != null and no != sc:
			xf = (no as Node3D).transform * xf
			no = no.get_parent()
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var mat: Material = m.mesh.surface_get_material(si)
			for chave in PAPEIS:
				if String(m.name).contains(chave):
					papel_mat[mat] = PAPEIS[chave]
			if not por_mat.has(mat):
				por_mat[mat] = {"v": [], "n": [], "uv": [], "i": []}   # Array (por referência), convertido a Packed no fim
			var d: Dictionary = por_mat[mat]
			var base: int = (d.v as Array).size()
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			for k in vs.size():
				(d.v as Array).append(xf * vs[k])
				(d.n as Array).append((xf.basis * ns[k]).normalized() if ns.size() > k else Vector3.UP)
				(d.uv as Array).append(uvs[k] if uvs.size() > k else Vector2.ZERO)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for k in vs.size():
					idx.append(k)
			for k in idx:
				(d.i as Array).append(base + k)
			for k in idx:
				tris.append(xf * vs[k])
	_malha = ArrayMesh.new()
	for mat in por_mat:
		if papel_mat.has(mat):
			_papeis[_malha.get_surface_count()] = papel_mat[mat]
		var d: Dictionary = por_mat[mat]
		var arrs := []
		arrs.resize(Mesh.ARRAY_MAX)
		arrs[Mesh.ARRAY_VERTEX] = PackedVector3Array(d.v)
		arrs[Mesh.ARRAY_NORMAL] = PackedVector3Array(d.n)
		arrs[Mesh.ARRAY_TEX_UV] = PackedVector2Array(d.uv)
		arrs[Mesh.ARRAY_INDEX] = PackedInt32Array(d.i)
		_malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
		_malha.surface_set_material(_malha.get_surface_count() - 1, mat)
	var tmp := MeshInstance3D.new()
	tmp.mesh = _malha
	Moveis._chapar(tmp, 48, true)    # paredes, piso e papel de parede também achatados (64x64), como o resto do mapa
	# paredes: superfícies verticais grandes viram cor chapada média (papel de parede em ruído borrado era o pior detalhe do interior)
	for i in _malha.get_surface_count():
		var ar := _malha.surface_get_arrays(i)
		var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = ar[Mesh.ARRAY_INDEX]
		var ns2: PackedVector3Array = ar[Mesh.ARRAY_NORMAL]
		var area := 0.0
		var ny2 := 0.0
		for t in range(0, ix.size() - 2, 3):
			area += (vs[ix[t + 1]] - vs[ix[t]]).cross(vs[ix[t + 2]] - vs[ix[t]]).length() * 0.5
		for n in ns2:
			ny2 += absf(n.y)
		var bm := _malha.surface_get_material(i) as BaseMaterial3D
		if bm != null and bm.albedo_texture != null and area > 25.0 and not ns2.is_empty() and ny2 / ns2.size() < 0.3:
			var img2 := bm.albedo_texture.get_image()
			if img2 != null:
				if img2.is_compressed():
					img2.decompress()
				img2.resize(4, 4)
				var cm := Color(0, 0, 0)
				for yy in 4:
					for xx in 4:
						cm += img2.get_pixel(xx, yy) / 16.0
				var mw := bm.duplicate() as BaseMaterial3D
				mw.albedo_texture = null
				mw.albedo_color = Color(cm.r, cm.g, cm.b).lightened(0.06)
				_malha.surface_set_material(i, mw)
	# teto: superfícies viradas para baixo viram cor chapada (a textura de ruído cinza borrava o forro)
	for i in _malha.get_surface_count():
		var ns: PackedVector3Array = _malha.surface_get_arrays(i)[Mesh.ARRAY_NORMAL]
		var ny := 0.0
		for n in ns:
			ny += n.y
		if not ns.is_empty() and ny / ns.size() < -0.6:
			var m2 := (_malha.surface_get_material(i) as BaseMaterial3D).duplicate() as BaseMaterial3D
			m2.albedo_texture = null
			m2.albedo_color = Color(0.98, 0.95, 0.88)
			m2.emission_enabled = true       # o forro não recebe sol: sem isso ficava cinza escuro
			m2.emission = Color(0.78, 0.72, 0.6)
			_malha.surface_set_material(i, m2)
	tmp.free()
	_colisao = ConcavePolygonShape3D.new()
	_colisao.set_faces(tris)
	_colisao.backface_collision = true
	sc.free()


static var _aj_cache: Dictionary = {}
static var _aj_lido := false


## Posição/giro ajustados por casa (tools/ajustar_casas.py): {"id": {"dx","dy","yaw_deg"}}.
static func ajustes() -> Dictionary:
	if not _aj_lido:
		_aj_lido = true
		var arq := "res://maps/ilha/casas_ajuste.json"
		var d = JsonSeguro.ler(arq, TYPE_DICTIONARY)
		if d != null:
			_aj_cache = d
	return _aj_cache


## Variantes: revestimento externo (tábuas claras) em 5 tintas e interior com paleta própria (paredes por cômodo, lambri,
## madeira do piso, ladrilho da cozinha) — 6 combinações, a vila deixa de ser clone por dentro e por fora.
static func _montar_variantes() -> void:
	var tintas := [Color.WHITE, Color(0.72, 0.84, 1.0), Color(1.0, 0.86, 0.55), Color(0.78, 0.95, 0.78), Color(1.0, 0.72, 0.68), Color(0.8, 0.92, 0.95)]
	var sh_parede: Shader = load(SHADER_PAREDE)
	var sh_piso: Shader = load(SHADER_PISO)
	for vi in PALETAS.size():
		var t: Color = tintas[vi % tintas.size()]
		var pal: Array = PALETAS[vi]
		var m := _malha.duplicate(true) as ArrayMesh
		for i in m.get_surface_count():
			var papel := String(_papeis.get(i, ""))
			if papel == "parede":
				var sm := ShaderMaterial.new()
				sm.shader = sh_parede
				var nomes := ["c_coz", "c_sala", "c_qne", "c_qse", "c_ban", "c_hall", "c_lambri"]
				for k in nomes.size():
					var cc := Color(pal[k])
					if k < 6:     # tons claros "lavam" com o sol/ambiente: mais saturados e um pouco mais escuros
						cc.s = minf(1.0, cc.s * 1.8 + 0.1)
						cc.v *= 0.88
					sm.set_shader_parameter(nomes[k], cc)
				m.surface_set_material(i, sm)
				continue
			if papel == "piso":
				var sp := ShaderMaterial.new()
				sp.shader = sh_piso
				sp.set_shader_parameter("madeira_a", Color(pal[7]))
				sp.set_shader_parameter("madeira_b", Color(pal[8]))
				sp.set_shader_parameter("ladrilho_b", Color(pal[9]))
				m.surface_set_material(i, sp)
				continue
			if papel == "teto":
				continue
			var b := m.surface_get_material(i) as BaseMaterial3D
			if t == Color.WHITE or b == null or b.albedo_texture == null:
				continue
			var img := b.albedo_texture.get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			img.resize(4, 4)
			var c := Color(0, 0, 0)
			for y in 4:
				for x in 4:
					c += img.get_pixel(x, y) / 16.0
			if c.get_luminance() > 0.62 and c.s < 0.18:
				var b2 := b.duplicate() as BaseMaterial3D
				b2.albedo_color = t
				m.surface_set_material(i, b2)
		_variantes.append(m)
		var ml := ArrayMesh.new()
		for i in m.get_surface_count():
			if _papeis.has(i):
				continue
			ml.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(i))
			ml.surface_set_material(ml.get_surface_count() - 1, m.surface_get_material(i))
		_variantes_longe.append(ml)


static func e_casa(tipo: String) -> bool:
	return tipo in TIPOS


## Cria uma casa em (x, z) mundo, yaw em rad. Devolve o StaticBody3D (já filho de `pai`).
## Preparação única (fundir a casa + variantes, ~3 s de GDScript). Pode rodar numa thread antes da 1ª casa
## (ilha.gd faz isso na pré-montagem atrás do criador, para não travar o menu).
static func preparar() -> void:
	if _malha != null:
		return
	var cena: PackedScene = load(GLB)
	_cena = cena
	_fundir()
	_saia = StandardMaterial3D.new()
	_saia.albedo_color = Color("9C968A")
	_saia.roughness = 1.0
	_montar_variantes()


static func criar(pai: Node3D, terrain: IlhaTerrain, nome: String, x: float, z: float, yaw: float) -> StaticBody3D:
	if _malha == null:
		preparar()
	var hmax := -INF
	var hmin := INF
	for a in [-6.0, 0.0, 6.0]:
		for b in [-6.0, 0.0, 6.0]:
			var p := Vector2(a, b).rotated(-yaw)
			var h := terrain.height_world(x + p.x, z + p.y)
			hmax = maxf(hmax, h)
			hmin = minf(hmin, h)
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.position = Vector3(x, hmax, z)
	corpo.rotation.y = yaw
	corpo.set_meta("casa_pacote", true)
	corpo.add_to_group("casa_pacote")
	pai.add_child(corpo)
	var visual := MeshInstance3D.new()
	visual.mesh = _variantes[_contador % _variantes.size()]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_end = PERTO_INTERIOR
	visual.visibility_range_end_margin = 5.0
	corpo.add_child(visual)
	# longe: a mesma casa sem as superfícies internas (menos draws por casa vista de fora)
	var visual_longe := MeshInstance3D.new()
	visual_longe.name = "VisualLonge"
	visual_longe.mesh = _variantes_longe[_contador % _variantes_longe.size()]
	visual_longe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_longe.visibility_range_begin = PERTO_INTERIOR
	visual_longe.visibility_range_begin_margin = 5.0
	visual_longe.visibility_range_end = 300.0
	corpo.add_child(visual_longe)
	_contador += 1
	var cs := CollisionShape3D.new()
	cs.shape = _colisao
	corpo.add_child(cs)
	var prof := hmax - hmin + 0.7
	var sa := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(11.9, prof, 12.5)
	sa.mesh = bm
	sa.material_override = _saia
	sa.position = Vector3(0, 0.05 - prof * 0.5, 0)
	sa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sa.visibility_range_end = 200.0
	corpo.add_child(sa)
	var porta := PortaCasa.new()
	porta.name = "PortaFrente"
	porta.position = Vector3(-2.5579, 0.0749, 5.7761)   # dobradiça (tools/importar_casa_demo.py)
	corpo.add_child(porta)
	# demais saídas: cozinha-norte (aberta para dentro, dobradiça no lado leste) e leste (dobradiça no lado norte)
	for d in [["PortaCozinha", Vector3(-1.96, 0.07, -3.52), PI], ["PortaLeste", Vector3(5.505, 0.07, -0.18), PI * 0.5]]:
		var pc := PortaCasa.new()
		pc.name = d[0]
		pc.position = d[1]
		pc.rotation.y = d[2]
		corpo.add_child(pc)
	Moveis.instalar(corpo, "casa_demo", false, true)
	Moveis.instalar(corpo, "casa_demo_cozinha", false, true)   # cozinha do pack (saque nos armários/geladeira marcados "loot")
	Moveis.instalar(corpo, "casa_demo_banheiro", false, true)  # banheiro (azulejado, antes vazio): banheira, vaso, pia com armarinho (saque)
	Moveis.instalar(corpo, "casa_demo_adereços", false, true)  # adereços do pack por cômodo (sem colisão)
	Moveis.sombras(corpo)                         # manchas escuras sob os móveis (uma malha por casa)
	return corpo
