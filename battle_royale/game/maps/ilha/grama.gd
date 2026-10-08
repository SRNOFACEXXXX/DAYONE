class_name IlhaGrama
extends Node3D
## Capim alto perto da câmera (docs/ref/ak47_fps.jpg: lâminas low poly até a canela/joelho em todo campo).
## Onde crescer vem dos dados autorais do mapa: canal G (grama) do splat.png, sem trilhas (trilhas.png R), sem estradas
## (terra batida) e fora da planta dos prédios do layout. Blocos de 16 m em volta da câmera (até ALCANCE), cada um um
## MultiMesh montado uma vez e reaproveitado. Posição de cada tufo = célula de 1 m + deslocamento por hash da célula
## (determinístico: o mesmo capim sempre no mesmo lugar).

const BLOCO := 16.0
const PASSO := 0.95
const ALCANCE := 32.0
const GRAMA_MIN := 0.55

var terrain: IlhaTerrain
var _splat: Image
var _trilhas: Image
var _predios: Array = []        # [centro Vector2(x, z), meia-extensão Vector2, rot rad] em coordenadas Godot
var _blocos := {}               # Vector2i -> MultiMeshInstance3D
var _mesh: ArrayMesh
var _mat: ShaderMaterial
var _ultimo := Vector2(1e9, 1e9)
var _casas_novas: Array = []     # [centro Vector2 (x,z), yaw] das casas do pacote (sem capim dentro nem ao redor da porta)
var _casas_lidas := false


func setup(t: IlhaTerrain, layout: Dictionary) -> void:
	terrain = t
	for site in preload("res://maps/ilha/refugios_gpt.gd").SITES:
		_predios.append([Vector2(site.pos.x, -site.pos.y), Vector2(6.0,5.0), 0.0])
	_splat = (load("res://maps/ilha/splat.png") as Texture2D).get_image()
	if _splat.is_compressed():
		_splat.decompress()
	if ResourceLoader.exists("res://maps/ilha/trilhas.png"):
		_trilhas = (load("res://maps/ilha/trilhas.png") as Texture2D).get_image()
		if _trilhas.is_compressed():
			_trilhas.decompress()
	for poi in layout.get("pois", []) + layout.get("marcos", []):
		for pr in poi.get("predios", []):
			var sz: Array = pr.tamanho_m
			_predios.append([Vector2(float(pr.pos[0]), -float(pr.pos[1])), Vector2(float(sz[0]), float(sz[1])) * 0.5 + Vector2(1.0, 1.0),
				deg_to_rad(float(pr.get("rot_deg", 0)))])
	_mesh = _tufo()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/grama.gdshader")
	_mat.set_shader_parameter("alcance", ALCANCE)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or terrain == null:
		return
	var c := Vector2(cam.global_position.x, cam.global_position.z)
	if c.distance_to(_ultimo) < 3.0:
		return
	_ultimo = c
	var r := int(ceil(ALCANCE / BLOCO))
	var cb := Vector2i(int(floor(c.x / BLOCO)), int(floor(c.y / BLOCO)))
	var quer := {}
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var b := cb + Vector2i(dx, dz)
			var centro := (Vector2(b) + Vector2(0.5, 0.5)) * BLOCO
			if centro.distance_to(c) < ALCANCE + BLOCO * 0.72:
				quer[b] = true
	for b in _blocos.keys():
		(_blocos[b] as Node3D).visible = quer.has(b)
		# blocos que ficaram bem para trás são liberados (antes acumulavam a partida inteira)
		if not quer.has(b) and ((Vector2(b) + Vector2(0.5, 0.5)) * BLOCO).distance_to(c) > ALCANCE + BLOCO * 4.0:
			(_blocos[b] as Node).queue_free()
			_blocos.erase(b)
	# orçamento: 1 bloco novo por quadro (antes 3), o mais perto primeiro; montar 3 blocos num quadro dava picos
	var faltam: Array = []
	for b in quer:
		if not _blocos.has(b):
			faltam.append(b)
	if faltam.is_empty():
		return
	faltam.sort_custom(func(a, b2): return ((Vector2(a) + Vector2(0.5, 0.5)) * BLOCO).distance_squared_to(c) < ((Vector2(b2) + Vector2(0.5, 0.5)) * BLOCO).distance_squared_to(c))
	_blocos[faltam[0]] = _montar(faltam[0])
	if faltam.size() > 1:
		_ultimo = Vector2(1e9, 1e9)   # ainda faltam blocos: tenta de novo no próximo quadro


func _montar(b: Vector2i) -> MultiMeshInstance3D:
	if not _casas_lidas:
		_casas_lidas = true
		for c in get_tree().get_nodes_in_group("casa_pacote"):
			_casas_novas.append([Vector2((c as Node3D).global_position.x, (c as Node3D).global_position.z), (c as Node3D).rotation.y])
	# só as casas/prédios que encostam neste bloco (antes cada tufo testava TODAS as casas e prédios do mapa)
	var r0 := Rect2(Vector2(b) * BLOCO, Vector2(BLOCO, BLOCO)).grow(2.0)
	var casas_aqui: Array = []
	for cc in _casas_novas:
		if r0.grow(13.0).has_point(cc[0]):
			casas_aqui.append(cc)
	var predios_aqui: Array = []
	for pr in _predios:
		var raio: float = (pr[1] as Vector2).length()
		if r0.grow(raio).has_point(pr[0]):
			predios_aqui.append(pr)
	var salvo_c := _casas_novas
	var salvo_p := _predios
	_casas_novas = casas_aqui
	_predios = predios_aqui
	var xfs: Array[Transform3D] = []
	var n := int(BLOCO / PASSO)
	for iz in n:
		for ix in n:
			var cx := b.x * BLOCO + ix * PASSO
			var cz := b.y * BLOCO + iz * PASSO
			var h := _hash(int(round(cx / PASSO)), int(round(cz / PASSO)))
			var x := cx + (h & 255) / 255.0 * PASSO
			var z := cz + ((h >> 8) & 255) / 255.0 * PASSO
			if not _cresce(x, z):
				continue
			var s := 0.85 + ((h >> 16) & 255) / 255.0 * 0.5
			var rot := ((h >> 24) & 255) / 255.0 * TAU
			var y := terrain.height_world(x, z)
			xfs.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(s, s * (0.85 + ((h >> 4) & 15) / 30.0), s)), Vector3(x, y - 0.03, z)))
	_casas_novas = salvo_c
	_predios = salvo_p
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = ALCANCE + 6.0
	add_child(mmi)
	return mmi


func _cresce(x: float, z: float) -> bool:
	var u := (x + 600.0) / 1200.0
	var v := (z + 600.0) / 1200.0
	if u <= 0.0 or u >= 1.0 or v <= 0.0 or v >= 1.0:
		return false
	var sp := _splat.get_pixel(int(u * (_splat.get_width() - 1)), int(v * (_splat.get_height() - 1)))
	if sp.g < GRAMA_MIN:
		return false
	if _trilhas:
		var tr := _trilhas.get_pixel(int(u * (_trilhas.get_width() - 1)), int(v * (_trilhas.get_height() - 1)))
		if tr.r > 0.35 or tr.g > 0.35:
			return false
	var p := Vector2(x, z)
	for c in _casas_novas:
		var dc: Vector2 = (p - c[0]).rotated(float(c[1]))
		if absf(dc.x) < 7.6 and dc.y > -7.8 and dc.y < 9.0:    # casa 12,9 x 13,3 + faixa da porta (+Z)
			return false
	for pr in _predios:
		var d: Vector2 = (p - pr[0]).rotated(-float(pr[2]))
		if absf(d.x) < pr[1].x and absf(d.y) < pr[1].y:
			return false
	return true


static func _hash(a: int, b: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7FFFFFFF


## Tufo low poly: 5 lâminas triangulares de 0,35–0,7 m inclinadas para fora (cor do vértice: base escura -> ponta clara).
static func _tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var laminas := [[0.0, 0.62, 0.10], [1.3, 0.48, 0.16], [2.5, 0.70, 0.08], [3.7, 0.42, 0.18], [5.0, 0.55, 0.13]]
	for l in laminas:
		var a: float = l[0]
		var alt: float = l[1]
		var incl: float = l[2]
		var dir := Vector3(cos(a), 0, sin(a))
		var lado := Vector3(-dir.z, 0, dir.x) * 0.035
		var base := dir * 0.04
		var ponta := dir * (0.04 + incl * alt * 2.0) + Vector3.UP * alt
		st.set_color(Color(0.0, 0.0, 0.0))
		st.set_uv(Vector2(0, 0))
		st.add_vertex(base - lado)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(base + lado)
		st.set_color(Color(1.0, 1.0, 1.0))
		st.set_uv(Vector2(0, 1))
		st.add_vertex(ponta)
	st.generate_normals()
	return st.commit()
