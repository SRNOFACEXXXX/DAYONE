class_name IlhaTerrain
extends Node3D
signal terrain_ready
## Terreno da Ilha do Tauá: lê height.bin (601 x 601, passo 2 m, linha 0 = norte) gerado por tools/bake_ilha.py.
## Visual: 10 x 10 pedaços de 120 m, 3 níveis de detalhe (2 m / 4 m / 8 m) por visibility_range.
## Colisão: HeightMapShape3D da grade inteira. Eixos: X = leste, -Z = norte, Y = altura.

const N := 601
const STEP := 2.0
const ORIGIN := -600.0
const CHUNK_CELLS := 60                     # 120 m
const LODS := [[1, 0.0, 140.0], [2, 130.0, 420.0], [4, 400.0, 0.0]]   # [passo em células, início, fim] (0 = sem limite)

var heights := PackedFloat32Array()
var plataformas: Array = []                 # [centro Vector2 (x,z), yaw rad] das casas: o terreno é aplainado sob elas (sem penhasco/aclive na porta)
var material: ShaderMaterial


func _ready() -> void:
	await _build_async()


func _build_async() -> void:
	var f := FileAccess.open("res://maps/ilha/height.bin", FileAccess.READ)
	heights = f.get_buffer(N * N * 4).to_float32_array()
	_aplanar()
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/terreno.gdshader")
	material.set_shader_parameter("splat", load("res://maps/ilha/splat.png"))
	if ResourceLoader.exists("res://maps/ilha/trilhas.png"):
		material.set_shader_parameter("trilhas", load("res://maps/ilha/trilhas.png"))
	if ResourceLoader.exists("res://maps/ilha/mata.png"):
		material.set_shader_parameter("mata", load("res://maps/ilha/mata.png"))
	await _build_visual_async()
	_build_collision()
	terrain_ready.emit()


## Plataforma sob cada casa: núcleo retangular (14 x 16 m, mais a faixa da porta) na altura média do terreno ali e transição
## suave em volta (largura >= 5 m, maior quando o desnível é grande), para não sobrar saia de concreto de 3 m nem degrau na porta.
func _aplanar() -> void:
	# 1) altura-alvo e desnível de cada casa (lidos do relevo original); 2) casas a < 17 m uma da outra dividem a altura média
	var alvos: Array[float] = []
	var aneis: Array[float] = []
	for pl in plataformas:
		var ctr: Vector2 = pl[0]
		var yaw: float = pl[1]
		var soma := 0.0
		var n := 0
		for a in range(-6, 7, 2):
			for b in range(-6, 8, 2):
				var q := Vector2(a, b).rotated(-yaw)
				soma += height_world(ctr.x + q.x, ctr.y + q.y)
				n += 1
		alvos.append(soma / n)
		var hmax := -INF
		var hmin := INF
		for a in [-6.0, 0.0, 6.0]:
			for b in [-6.0, 0.0, 6.0]:
				var q2 := Vector2(a, b).rotated(-yaw)
				var h := height_world(ctr.x + q2.x, ctr.y + q2.y)
				hmax = maxf(hmax, h)
				hmin = minf(hmin, h)
		aneis.append(maxf(6.0, (hmax - hmin) * 3.5))
	var finais: Array[float] = []
	for i in plataformas.size():
		var s2 := 0.0
		var k := 0
		for j in plataformas.size():
			if (plataformas[i][0] as Vector2).distance_to(plataformas[j][0]) < 17.0:
				s2 += alvos[j]
				k += 1
		finais.append(s2 / k)
	for i in plataformas.size():
		var ctr2: Vector2 = plataformas[i][0]
		var yaw2: float = plataformas[i][1]
		var alvo := finais[i]
		var anel := aneis[i]
		var raio := 8.5 + 7.5 + anel
		var c0 := int(floor((ctr2.x - raio - ORIGIN) / STEP))
		var c1 := int(ceil((ctr2.x + raio - ORIGIN) / STEP))
		var r0 := int(floor((ctr2.y - raio - ORIGIN) / STEP))
		var r1 := int(ceil((ctr2.y + raio - ORIGIN) / STEP))
		for r in range(maxi(r0, 0), mini(r1, N - 1) + 1):
			for c in range(maxi(c0, 0), mini(c1, N - 1) + 1):
				var wp := Vector2(ORIGIN + c * STEP, ORIGIN + r * STEP) - ctr2
				var l := wp.rotated(yaw2)          # coordenadas locais da casa (porta = +Z)
				var dx := maxf(absf(l.x) - 7.0, 0.0)
				var dz := maxf(maxf(-7.5 - l.y, l.y - 9.0), 0.0)
				var d := Vector2(dx, dz).length()
				var w := 1.0 - smoothstep(0.0, anel, d)
				if w > 0.0:
					var idx := r * N + c
					heights[idx] = lerpf(heights[idx], alvo, w)


func h_at(c: int, r: int) -> float:
	return heights[clampi(r, 0, N - 1) * N + clampi(c, 0, N - 1)]


## Altura em coordenadas do mundo (bilinear).
func height_world(x: float, z: float) -> float:
	var fc := (x - ORIGIN) / STEP
	var fr := (z - ORIGIN) / STEP
	var c := int(floor(fc))
	var r := int(floor(fr))
	var tx := fc - c
	var tz := fr - r
	var a := lerpf(h_at(c, r), h_at(c + 1, r), tx)
	var b := lerpf(h_at(c, r + 1), h_at(c + 1, r + 1), tx)
	return lerpf(a, b, tz)


func _build_visual() -> void:
	var chunks := (N - 1) / CHUNK_CELLS
	for cz in chunks:
		for cx in chunks:
			for lod in LODS:
				var mi := MeshInstance3D.new()
				mi.mesh = _chunk_mesh(cx * CHUNK_CELLS, cz * CHUNK_CELLS, int(lod[0]))
				mi.material_override = material
				mi.visibility_range_begin = lod[1]
				mi.visibility_range_end = lod[2]
				mi.visibility_range_begin_margin = 10.0 if lod[1] > 0.0 else 0.0
				mi.visibility_range_end_margin = 10.0 if lod[2] > 0.0 else 0.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # autossombra do terreno: serrilhada e cara na GT 730
				add_child(mi)


func _build_visual_async() -> void:
	var chunks := (N - 1) / CHUNK_CELLS
	for cz in chunks:
		for cx in chunks:
			for lod in LODS:
				var mi := MeshInstance3D.new()
				mi.mesh = _chunk_mesh(cx * CHUNK_CELLS, cz * CHUNK_CELLS, int(lod[0]))
				mi.material_override = material
				mi.visibility_range_begin = lod[1]
				mi.visibility_range_end = lod[2]
				mi.visibility_range_begin_margin = 10.0 if lod[1] > 0.0 else 0.0
				mi.visibility_range_end_margin = 10.0 if lod[2] > 0.0 else 0.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)
		await get_tree().process_frame


func _chunk_mesh(c0: int, r0: int, s: int) -> ArrayMesh:
	var n := CHUNK_CELLS / s + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var c := c0 + i * s
			var r := r0 + j * s
			var k := j * n + i
			verts[k] = Vector3(ORIGIN + c * STEP, h_at(c, r), ORIGIN + r * STEP)
			var dx := h_at(c + 1, r) - h_at(c - 1, r)
			var dz := h_at(c, r + 1) - h_at(c, r - 1)
			norms[k] = Vector3(-dx, 2.0 * STEP, -dz).normalized()
			uvs[k] = Vector2(float(c) / (N - 1), float(r) / (N - 1))
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var cc := a + n
			var d := cc + 1
			# diagonal adaptativa: corta o quadrado pela diagonal de menor diferença de altura
			# (segue o relevo; sem isso taludes diagonais à grade viram "serrote")
			if absf(verts[a].y - verts[d].y) <= absf(verts[b].y - verts[cc].y):
				idx.append_array([a, b, d, a, d, cc])
			else:
				idx.append_array([a, b, cc, b, d, cc])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrenoColisao"
	add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(cs)
