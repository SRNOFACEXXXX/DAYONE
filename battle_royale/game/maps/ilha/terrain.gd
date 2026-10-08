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
var plataformas_carros: Array = []         # [centro Vector2 (x,z), raio] dos carros: o terreno é aplainado sob eles
var bloqueios: Array = []                   # [a Vector2, b Vector2, raio] (x,z): segmentos (rio, pontes, barragem) onde o suavizador não mexe
var aplanar_carros := true
var suavizar := true
var _trava := PackedByteArray()
var material: ShaderMaterial


func _ready() -> void:
	await _build_async()


func _build_async() -> void:
	var f := FileAccess.open("res://maps/ilha/height.bin", FileAccess.READ)
	heights = f.get_buffer(N * N * 4).to_float32_array()
	if Loading.ceder():
		await get_tree().process_frame
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/terreno.gdshader")
	material.set_shader_parameter("splat", load("res://maps/ilha/splat.png"))
	if ResourceLoader.exists("res://maps/ilha/trilhas.png"):
		material.set_shader_parameter("trilhas", load("res://maps/ilha/trilhas.png"))
	if ResourceLoader.exists("res://maps/ilha/mata.png"):
		material.set_shader_parameter("mata", load("res://maps/ilha/mata.png"))
	# aplainar + vértices dos 300 pedaços numa thread (conta pura, ~2 s de GDScript que travavam o menu/criador);
	# a thread principal só cria as malhas e os nós, com orçamento por quadro. Mesmo resultado.
	var chunks := (N - 1) / CHUNK_CELLS
	for cz in chunks:
		for cx in chunks:
			for lod in LODS:
				_specs.append([cx * CHUNK_CELLS, cz * CHUNK_CELLS, int(lod[0]), lod])
	_arrays.resize(_specs.size())
	var tarefa := WorkerThreadPool.add_task(_tarefa_terreno, false, "terreno_ilha")
	while not WorkerThreadPool.is_task_completed(tarefa):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa)
	await _build_visual_async()
	_build_collision()
	terrain_ready.emit()


## Plataforma sob cada casa: núcleo retangular (14 x 16 m, mais a faixa da porta) na altura média do terreno ali e transição
## suave em volta (largura >= 5 m, maior quando o desnível é grande), para não sobrar saia de concreto de 3 m nem degrau na porta.
func _aplanar() -> void:
	_trava.resize(N * N)
	_trava.fill(0)
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
					if d == 0.0:
						_trava[idx] = 2
	# Plataformas sob carros: planalto circular (todo nó a <= raio está exatamente na altura-alvo, assim os triângulos
	# da colisão sob a carroceria são coplanares) e transição suave em volta. A altura-alvo é a do relevo no centro.
	if aplanar_carros:
		for carro in plataformas_carros:
			var ctr3: Vector2 = carro[0]
			var raio_carro: float = carro[1]
			var anel_carro := raio_carro + 6.0
			var alvo_carro := height_world(ctr3.x, ctr3.y)
			var c0c := int(floor((ctr3.x - anel_carro - ORIGIN) / STEP))
			var c1c := int(ceil((ctr3.x + anel_carro - ORIGIN) / STEP))
			var r0c := int(floor((ctr3.y - anel_carro - ORIGIN) / STEP))
			var r1c := int(ceil((ctr3.y + anel_carro - ORIGIN) / STEP))
			for r in range(maxi(r0c, 0), mini(r1c, N - 1) + 1):
				for c in range(maxi(c0c, 0), mini(c1c, N - 1) + 1):
					var d2 := (Vector2(ORIGIN + c * STEP, ORIGIN + r * STEP) - ctr3).length()
					var w2 := 1.0 - smoothstep(raio_carro, anel_carro, d2)
					if w2 > 0.0:
						var idx := r * N + c
						if _trava[idx] == 2:
							continue   # núcleo de casa: a casa tem prioridade sobre o carro vizinho
						heights[idx] = lerpf(heights[idx], alvo_carro, w2)
						if d2 <= raio_carro:
							_trava[idx] = 1


## Limita o declive entre nós vizinhos (4 vizinhos + diagonais) a max_declive_graus. Duas varreduras de distância
## (chamfer) em O(N): "teto" (min-plus: corta o topo do penhasco) e "piso" (max-plus: aterra o pé) e a média dos dois,
## que também respeita o limite. Só mexe onde o limite é violado; nós travados (plataformas das casas e dos carros,
## rio, pontes, barragem) mantêm a altura.
func _suavizar_declives(max_declive_graus: float = 35.0) -> void:
	if not suavizar:
		return
	var L := tan(deg_to_rad(max_declive_graus))
	var d1 := L * STEP
	var d2 := L * STEP * 1.41421356
	for bl in bloqueios:
		var pa: Vector2 = bl[0]
		var pb: Vector2 = bl[1]
		var rb: float = bl[2]
		var cb0 := maxi(int(floor((minf(pa.x, pb.x) - rb - ORIGIN) / STEP)), 0)
		var cb1 := mini(int(ceil((maxf(pa.x, pb.x) + rb - ORIGIN) / STEP)), N - 1)
		var rb0 := maxi(int(floor((minf(pa.y, pb.y) - rb - ORIGIN) / STEP)), 0)
		var rb1 := mini(int(ceil((maxf(pa.y, pb.y) + rb - ORIGIN) / STEP)), N - 1)
		for r in range(rb0, rb1 + 1):
			for c in range(cb0, cb1 + 1):
				var q := Vector2(ORIGIN + c * STEP, ORIGIN + r * STEP)
				if Geometry2D.get_closest_point_to_segment(q, pa, pb).distance_to(q) <= rb:
					_trava[r * N + c] = 1
	var h0 := heights.duplicate()
	var teto := heights.duplicate()
	var piso := heights.duplicate()
	# (dc, dr, custo) dos vizinhos já visitados na varredura para frente; a de trás usa o oposto
	var dcs: Array[int] = [-1, -1, 0, 1]
	var drs: Array[int] = [0, -1, -1, -1]
	var custo: Array[float] = [d1, d2, d1, d2]
	for _it in 1:
		for sweep in 2:
			var sg := 1 if sweep == 0 else -1
			var r := 0 if sweep == 0 else N - 1
			while r >= 0 and r < N:
				var c := 0 if sweep == 0 else N - 1
				while c >= 0 and c < N:
					var idx := r * N + c
					var t := teto[idx]
					var p := piso[idx]
					for k in 4:
						var cj := c + dcs[k] * sg
						var rj := r + drs[k] * sg
						if cj < 0 or cj >= N or rj < 0 or rj >= N:
							continue
						var j := rj * N + cj
						t = minf(t, teto[j] + custo[k])
						p = maxf(p, piso[j] - custo[k])
					teto[idx] = t
					piso[idx] = p
					c += sg
				r += sg
	for i in heights.size():
		heights[i] = h0[i] if _trava[i] != 0 else (teto[i] + piso[i]) * 0.5


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
	var h00 := h_at(c, r)
	var h10 := h_at(c + 1, r)
	var h01 := h_at(c, r + 1)
	var h11 := h_at(c + 1, r + 1)
	# Use a mesma anti-diagonal b-c do HeightMapShape3D/Jolt. Bilinear height
	# lookup and adaptive render diagonals put the visible ground at a different
	# height between samples, which makes wheels and props appear buried or float.
	if tx + tz <= 1.0:
		return h00 + tx * (h10 - h00) + tz * (h01 - h00)
	return h11 * (tx + tz - 1.0) + h10 * (1.0 - tz) + h01 * (1.0 - tx)


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


var _specs: Array = []     # [c0, r0, passo, lod] de cada pedaço
var _arrays: Array = []    # arrays de superfície prontos (preenchidos pela thread)


func _tarefa_terreno() -> void:
	_aplanar()
	_suavizar_declives()
	for i in _specs.size():
		_arrays[i] = _chunk_arrays(int(_specs[i][0]), int(_specs[i][1]), int(_specs[i][2]))


func _build_visual_async() -> void:
	for si in _specs.size():
		var lod: Array = _specs[si][3]
		var mi := MeshInstance3D.new()
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays[si])
		mi.mesh = am
		mi.material_override = material
		mi.visibility_range_begin = lod[1]
		mi.visibility_range_end = lod[2]
		mi.visibility_range_begin_margin = 10.0 if lod[1] > 0.0 else 0.0
		mi.visibility_range_end_margin = 10.0 if lod[2] > 0.0 else 0.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # autossombra do terreno: serrilhada e cara na GT 730
		add_child(mi)
		if Loading.ceder():   # orçamento por quadro (pré-montagem atrás do criador)
			await get_tree().process_frame
	_arrays.clear()


func _chunk_mesh(c0: int, r0: int, s: int) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _chunk_arrays(c0, r0, s))
	return m


## Arrays de superfície de um pedaço (conta pura: pode rodar fora da thread principal).
func _chunk_arrays(c0: int, r0: int, s: int) -> Array:
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
			# Diagonal uniforme b-c: combina com a triangulação do HeightMapShape3D
			# no Jolt. Uma diagonal adaptativa divergia da colisão em cada encosta.
			idx.append_array([a, b, cc, cc, b, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


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
