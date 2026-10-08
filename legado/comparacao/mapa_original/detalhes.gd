class_name IlhaDetalhes
extends Node3D
## Detalhes de chão dos POIs (docs/design/detalhes.json -> maps/ilha/detalhes.json):
##  props soltos (com colisão convexa), cercas/muros em segmentos de 3 m ao longo das polilinhas,
##  linhas de postes com 3 fios em catenária entre as cruzetas.

const ARVORES_PACOTE := ["carvalho", "arvore_b", "arvore_d", "betula", "betula_jovem", "pinheiro", "pinheiro_medio", "pinheiro_jovem",
	"salgueiro", "arvore_seca", "arvore_seca_p"]
const SEM_COLISAO_PACOTE := ["arbusto_a", "arbusto_b", "samambaia_a", "samambaia_b", "tufo_capim", "tufo_misto", "urtiga", "galho", "pedrisco_a", "pedrisco_b"]
const SEM_COLISAO := ["varal", "placa_rua", "bicicleta", "lixeira", "mochila_tatica"]
const SEGMENTO := 3.0
const ESCALA_TIPO := {"lixeira": 0.65, "barraca_militar": 0.01}
const CRUZETA := {"poste_madeira": [0.7, 7.78], "poste_concreto": [0.8, 8.73]}   # [x do isolador, altura]

var terrain: IlhaTerrain
var _cache := {}
var _shape_cache: Dictionary = {}
var _corpo: StaticBody3D
var _fio_mat: StandardMaterial3D
var _military_canvas: StandardMaterial3D


var _casas: Array = []        # [centro Vector2 (x,z), yaw] das casas do pacote (CasaPacote): props/cercas antigos ali dentro são descartados
var _filtrar := true


func _dentro_casa(xy: Vector2) -> bool:
	var p := Vector2(xy.x, -xy.y)   # design (x leste, y norte) -> mundo (x, z)
	for c in _casas:
		var d: Vector2 = (p - c[0]).rotated(float(c[1]))
		if absf(d.x) < 8.0 and absf(d.y) < 8.2:
			return true
	return false


func build_async(t: IlhaTerrain, path := "res://maps/ilha/detalhes.json") -> int:
	terrain = t
	var blk := get_parent().get_node_or_null("Blockout")
	if blk:
		for b in blk.get_children():
			if b is Node3D and b.has_meta("casa_pacote"):
				_casas.append([Vector2((b as Node3D).position.x, (b as Node3D).position.z), (b as Node3D).rotation.y])
	if not FileAccess.file_exists(path):
		return 0
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_corpo = StaticBody3D.new()
	_corpo.name = "DetalhesColisao"
	add_child(_corpo)
	_fio_mat = StandardMaterial3D.new()
	_fio_mat.albedo_color = Color(0.08, 0.08, 0.08)
	_fio_mat.roughness = 0.6
	_military_canvas = StandardMaterial3D.new()
	_military_canvas.albedo_color = Color("C0B68C")
	_military_canvas.roughness = 1.0
	_military_canvas.emission_enabled = true
	_military_canvas.emission = Color("A79B6D")
	_military_canvas.emission_energy_multiplier = 0.7
	var n := 0
	var completed := 0
	var props: Array = d.get("props", [])
	for p in props:
		_colocar(String(p.tipo), Vector2(float(p.x), float(p.y)), float(p.get("rot_deg", 0.0)))
		n += 1
		completed += 1
		if completed % 28 == 0:
			Loading.set_progress("Montando objetos e saque...", 48.0 + 25.0 * float(completed) / maxf(1.0, float(props.size())))
			await get_tree().process_frame
	if FileAccess.file_exists("res://maps/ilha/detalhes_refino.json"):
		var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/detalhes_refino.json"))
		for p in extra.get("props", []):
			_colocar(String(p.tipo), Vector2(float(p.x), float(p.y)), float(p.get("rot_deg", 0.0)))
			n += 1
			completed += 1
			if completed % 28 == 0:
				await get_tree().process_frame
	# decoração por área com as peças dos pacotes do usuário (docs/design/cenario_areas.json, autoral: tipo = "cenario/<pasta>/<nome>")
	for arq in ["res://maps/ilha/cenario_areas.json", "res://maps/ilha/cenario_areas_02.json", "res://maps/ilha/cenario_areas_03.json"]:
		if not FileAccess.file_exists(arq):
			continue
		var areas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arq))
		for area in areas.get("areas", []):
			for p in area.get("props", []):
				var no := _colocar(String(p.tipo), Vector2(float(p.x), float(p.y)), float(p.get("rot_deg", 0.0)))
				if no and p.has("escala"):
					no.scale *= float(p.escala)
				n += 1
				completed += 1
				if completed % 28 == 0:
					await get_tree().process_frame
	n += await _casas_pacote_async()
	for c in d.get("cercas", []):
		n += await _cerca_async(String(c.tipo), c.pontos)
	for l in d.get("linhas_fiacao", []):
		n += _fiacao(String(l.get("tipo_poste", "poste_madeira")), l.postes)
	return n


## Troca visual por peças dos pacotes do usuário (mesma posição autoral; variante pelo índice da peça).
const TROCA := {"lixeira": ["cenario/rua/rua_trash_bin", "cenario/rua/rua_bin"], "banco_praca": ["cenario/rua/rua_streetbank"]}
var _n_troca := 0


## Casas extras do pacote em terrenos planos (casas_pacote.json): mesma casa dos prédios residenciais do layout.
func _casas_pacote_async() -> int:
	var arq := "res://maps/ilha/casas_pacote.json"
	if not FileAccess.file_exists(arq):
		return 0
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arq))
	var n := 0
	var aj: Dictionary = CasaPacote.ajustes()
	for c in dados.get("casas", []):
		var a: Dictionary = aj.get("extra_%d" % n, {})
		CasaPacote.criar(self, terrain, "CasaPacote_%d" % n, float(c.x) + float(a.get("dx", 0.0)), -float(c.y) - float(a.get("dy", 0.0)),
			deg_to_rad(float(a.yaw_deg)) if a.has("yaw_deg") else deg_to_rad(float(c.get("rot_deg", 0.0))))
		n += 1
		await get_tree().process_frame
	return n


func _cena(tipo: String) -> PackedScene:
	if not _cache.has(tipo):
		var p := ("res://assets/models/%s.glb" % tipo) if "/" in tipo else ("res://assets/models/detalhes/%s.glb" % tipo)
		_cache[tipo] = load(p) if ResourceLoader.exists(p) else null
	return _cache[tipo]


func _chao(xy: Vector2) -> Vector3:
	return Vector3(xy.x, terrain.height_world(xy.x, -xy.y), -xy.y)


func _colocar(tipo: String, xy: Vector2, rot_deg: float, escala_x := 1.0) -> Node3D:
	if TROCA.has(tipo):
		_n_troca += 1
		tipo = String(TROCA[tipo][_n_troca % TROCA[tipo].size()])
	if _filtrar and _dentro_casa(xy):
		return null
	var sc := _cena(tipo)
	if sc == null:
		return null
	var n: Node3D = sc.instantiate()
	add_child(n)
	n.position = _chao(xy)
	n.rotation.y = deg_to_rad(rot_deg)
	var e: float = ESCALA_TIPO.get(tipo, 1.0)
	n.scale = Vector3(escala_x * e, e, e)
	# distância de desenho: objetos pequenos somem cedo; estruturas lineares (cerca, muro, poste) vão mais longe
	var linear := tipo.begins_with("cerca") or tipo.begins_with("cenario/natureza/cerca") or tipo.begins_with("muro") or tipo.begins_with("poste") or tipo.begins_with("portao")
	# pequenos somem a 110 m (GT 730: ~430 draws só de props na Vila); carros e estruturas lineares vão mais longe
	var alcance := 260.0 if linear else (220.0 if tipo.begins_with("cenario/carros") else 110.0)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if tipo == "barraca_militar":
			(g as GeometryInstance3D).material_override = _military_canvas
		(g as GeometryInstance3D).visibility_range_end = alcance
		(g as GeometryInstance3D).visibility_range_end_margin = 15.0
		# só postes projetam sombra: muro/cerca sobre terreno facetado fazia "serrote" com o sol baixo (crítica 03, ajuste 2)
		if alcance < 200.0 or not tipo.begins_with("poste"):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# peças de pacote com malhas UCX já trazem a colisão fiel (StaticBody do importador): não soma casco convexo
	var tem_colisao := not n.find_children("*", "CollisionShape3D", true, false).is_empty()
	var nat := tipo.trim_prefix("cenario/natureza/") if tipo.begins_with("cenario/natureza/") else ""
	if nat != "" and (nat in ARVORES_PACOTE):
		# árvore: só o tronco colide (cilindro na origem = pé do tronco); a copa não vira parede invisível
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.32 * n.scale.x
		cyl.height = 5.0 * n.scale.y
		cs.shape = cyl
		_corpo.add_child(cs)
		cs.global_position = n.global_position + Vector3.UP * cyl.height * 0.5
		return n
	if nat != "" and (nat in SEM_COLISAO_PACOTE):
		return n
	if not tipo in SEM_COLISAO and not tem_colisao:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var cs := CollisionShape3D.new()
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			var mesh_id := mesh.get_instance_id()
			if not _shape_cache.has(mesh_id):
				# peças vazadas/finas (cercas de ripas, muros, portões, ruínas) usam colisão FIEL (trimesh): o casco convexo
				# fechava os vãos e criava a "parede invisível" que impedia pular/passar
				var fiel := tipo == "barraca_militar" or tipo.begins_with("cerca") or tipo.begins_with("muro") or tipo.begins_with("portao") 						or tipo.begins_with("cenario/natureza/cerca") or tipo.begins_with("cenario/natureza/muro") or tipo == "cenario/natureza/entulho"
				_shape_cache[mesh_id] = mesh.create_trimesh_shape() if fiel else mesh.create_convex_shape(true, true)
			cs.shape = _shape_cache[mesh_id]
			_corpo.add_child(cs)
			cs.global_transform = (mi as MeshInstance3D).global_transform
	return n


## Cerca/muro: segmentos de 3 m (o último é esticado/encolhido para fechar o trecho) ao longo da polilinha.
func _cerca_async(tipo: String, pts: Array) -> int:
	var n := 0
	for i in pts.size() - 1:
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var L := a.distance_to(b)
		var k := maxi(1, int(round(L / SEGMENTO)))
		var passo := L / k
		var ang := rad_to_deg(atan2(b.y - a.y, b.x - a.x))     # +X local do segmento ao longo do trecho
		for j in k:
			_colocar(tipo, a + (b - a).normalized() * passo * j, ang, passo / SEGMENTO)
			n += 1
			if n % 40 == 0:
				await get_tree().process_frame
	return n


## Postes + 3 fios em catenária (flecha de 3% do vão) entre isoladores correspondentes.
func _fiacao(tipo: String, postes: Array) -> int:
	var cru: Array = CRUZETA.get(tipo, [0.7, 7.78])
	var anteriores := []
	var n := 0
	for i in postes.size():
		var xy := Vector2(float(postes[i][0]), float(postes[i][1]))
		# poste virado para o próximo (cruzeta perpendicular à linha)
		var alvo := Vector2(float(postes[mini(i + 1, postes.size() - 1)][0]), float(postes[mini(i + 1, postes.size() - 1)][1]))
		if i == postes.size() - 1:
			alvo = xy + (xy - Vector2(float(postes[i - 1][0]), float(postes[i - 1][1])))
		var dir := (alvo - xy).normalized()
		var rot := rad_to_deg(atan2(dir.y, dir.x)) + 90.0
		var poste := _colocar(tipo, xy, rot)
		n += 1
		if poste == null:
			continue
		var pontas := []
		for dx in [-float(cru[0]), 0.0, float(cru[0])]:
			pontas.append(poste.global_transform * Vector3(dx, float(cru[1]), 0))
		if anteriores.size() == 3:
			for k in 3:
				_fio(anteriores[k], pontas[k])
		anteriores = pontas
	return n


func _fio(a: Vector3, b: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 8
	var flecha := a.distance_to(b) * 0.03
	var lado := (b - a).cross(Vector3.UP).normalized() * 0.012
	var pts := []
	for i in seg + 1:
		var t := float(i) / seg
		pts.append(a.lerp(b, t) + Vector3.DOWN * flecha * 4.0 * t * (1.0 - t))
	for i in seg:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		for v in [p0 - lado, p1 - lado, p0 + lado, p0 + lado, p1 - lado, p1 + lado,
				p0 + Vector3.UP * 0.012, p1 + Vector3.UP * 0.012, p0 - Vector3.UP * 0.012, p0 - Vector3.UP * 0.012, p1 + Vector3.UP * 0.012, p1 - Vector3.UP * 0.012]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _fio_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 220.0
	add_child(mi)
