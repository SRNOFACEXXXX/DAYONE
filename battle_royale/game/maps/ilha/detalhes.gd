class_name IlhaDetalhes
extends Node3D
## Detalhes de chão dos POIs (docs/design/detalhes.json -> maps/ilha/detalhes.json):
##  props soltos (com colisão convexa), cercas/muros em segmentos de 3 m ao longo das polilinhas,
##  linhas de postes com 3 fios em catenária entre as cruzetas.

const ARVORES_PACOTE := ["carvalho", "arvore_b", "arvore_d", "betula", "betula_jovem", "pinheiro", "pinheiro_medio", "pinheiro_jovem",
	"salgueiro", "arvore_seca", "arvore_seca_p"]
const SEM_COLISAO_PACOTE := ["arbusto_a", "arbusto_b", "samambaia_a", "samambaia_b", "tufo_capim", "tufo_misto", "urtiga", "galho", "pedrisco_a", "pedrisco_b"]
const COLISAO_CAIXA := ["varal", "cenario/rua/rua_box_03"]   # ignora as formas UCX do glb (cobriam só parte): caixa do AABB da malha
const SEM_COLISAO := ["lixeira", "mochila_tatica"]   # varal/placa_rua/bicicleta agora colidem (auditoria tests/props_colisao.gd)
const SEGMENTO := 3.0
const ESCALA_TIPO := {"lixeira": 0.65, "barraca_militar": 0.01, "detalhes/barraca_militar": 0.01}   # barraca vem em cm (474 m sem escala)
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
	for site in preload("res://maps/ilha/refugios_gpt.gd").SITES:
		if absf(xy.x - site.pos.x) < 8.0 and absf(xy.y - site.pos.y) < 7.0:
			return true
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
	var d: Dictionary = JsonSeguro.dict(path)
	_corpo = StaticBody3D.new()
	_corpo.name = "DetalhesColisao"
	add_child(_corpo)
	# colisão de todos os props num corpo estático do servidor de física (sem 1 nó StaticBody/CollisionShape por peça);
	# os raios resolvem o collider para o nó DetalhesColisao
	_rid = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(_rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(_rid, get_world_3d().space)
	PhysicsServer3D.body_attach_object_instance_id(_rid, _corpo.get_instance_id())
	PhysicsServer3D.body_set_collision_layer(_rid, _corpo.collision_layer)
	PhysicsServer3D.body_set_collision_mask(_rid, _corpo.collision_mask)
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
		if Loading.ceder():
			Loading.set_progress("Montando objetos e saque...", 48.0 + 25.0 * float(completed) / maxf(1.0, float(props.size())))
			await get_tree().process_frame
	if FileAccess.file_exists("res://maps/ilha/detalhes_refino.json"):
		var extra: Dictionary = JsonSeguro.dict("res://maps/ilha/detalhes_refino.json")
		for p in JsonSeguro.lista(extra, "props"):
			if not p is Dictionary:
				continue
			_colocar(String(p.tipo), Vector2(float(p.x), float(p.y)), float(p.get("rot_deg", 0.0)))
			n += 1
			completed += 1
			if Loading.ceder():
				await get_tree().process_frame
	# decoração por área com as peças dos pacotes do usuário (docs/design/cenario_areas.json, autoral: tipo = "cenario/<pasta>/<nome>")
	for arq in ["res://maps/ilha/cenario_areas.json", "res://maps/ilha/cenario_areas_02.json", "res://maps/ilha/cenario_areas_03.json",
			"res://maps/ilha/cenario_atualizacao.json", "res://maps/ilha/cenario_pontos.json"]:
		if not FileAccess.file_exists(arq):
			continue
		var areas: Dictionary = JsonSeguro.dict(arq)
		for area in JsonSeguro.lista(areas, "areas"):
			if not area is Dictionary:
				continue
			if Game.test_args.has("sem_vilas") and String(area.get("nome", "")).begins_with("Vilas"):
				continue   # A/B da rodada das vilas (tests/mundo_fps -- --sem_vilas)
			for p in area.get("props", []):
				var no := _colocar(String(p.tipo), Vector2(float(p.x), float(p.y)), float(p.get("rot_deg", 0.0)), 1.0,
					float(p.get("escala", 1.0)), float(p.get("dy", 0.0)), float(p.get("tomba", 0.0)))
				if no and arq.ends_with("cenario_atualizacao.json"):
					no.set_meta("atualizacao", true)   # tests/mundo_fps.gd mede com/sem estas peças
				if no and p.has("copa"):   # árvore do pacote com copa de outono (escolha autoral por instância)
					_copa_outono(no, String(p.copa))
				if no and (p.has("alcance") or p.get("sombra", false)):   # cenario_atualizacao: veículos/torres vistos de longe
					for g in no.find_children("*", "GeometryInstance3D", true, false):
						(g as GeometryInstance3D).visibility_range_end = float(p.get("alcance", 110.0))
						if p.get("sombra", false):
							(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				n += 1
				completed += 1
				if Loading.ceder():
					await get_tree().process_frame
			for c in area.get("cercas", []):   # cercas autorais do ponto de interesse (mesma montagem das cercas do layout)
				n += await _cerca_async(String(c.tipo), c.pontos)
		# ruído autoral (rodada 3): grupos de 2-4 props soltos ao longo das estradas, vilas e costa; mesmo caminho de _colocar
		for p in (areas.get("ruido", []) if not Game.test_args.has("sem_ruido") else []):   # A/B: --sem_ruido
			_colocar(String(p.tipo), Vector2(float(p.x), float(p.y)), float(p.get("rot_deg", 0.0)), 1.0,
				float(p.get("escala", 1.0)), float(p.get("dy", 0.0)), float(p.get("tomba", 0.0)))
			n += 1
			completed += 1
			if Loading.ceder():
				await get_tree().process_frame
	# pontes sobre o rio (decisões em cenario_atualizacao.json -> "pontes"; montagem em pontes_atualizacao.gd)
	if FileAccess.file_exists("res://maps/ilha/cenario_atualizacao.json"):
		var ca: Dictionary = JsonSeguro.dict("res://maps/ilha/cenario_atualizacao.json")
		if ca.has("pontes"):
			var pa: Node3D = load("res://maps/ilha/pontes_atualizacao.gd").new()
			pa.name = "Pontes"
			add_child(pa)
			n += pa.build(self, ca.pontes)
	n += await _casas_pacote_async()
	for c in d.get("cercas", []):
		n += await _cerca_async(String(c.tipo), c.pontos)
	for l in d.get("linhas_fiacao", []):
		n += _fiacao(String(l.get("tipo_poste", "poste_madeira")), l.postes)
	await _fundir()
	return n


## Troca visual por peças dos pacotes do usuário (mesma posição autoral; variante pelo índice da peça).
const TROCA := {"lixeira": ["cenario/rua/rua_trash_bin", "cenario/rua/rua_bin"], "banco_praca": ["cenario/rua/rua_streetbank"],
	"tambor": ["atualizacao/mundo/Barrel_005"]}   # tambor de 200 L -> tambor do pack (mesma posição; paleta compartilhada)
var _n_troca := 0


## Casas extras do pacote em terrenos planos (casas_pacote.json): mesma casa dos prédios residenciais do layout.
func _casas_pacote_async() -> int:
	var arq := "res://maps/ilha/casas_pacote.json"
	if not FileAccess.file_exists(arq):
		return 0
	var dados: Dictionary = JsonSeguro.dict(arq)
	var n := 0
	var aj: Dictionary = CasaPacote.ajustes()
	for c in JsonSeguro.lista(dados, "casas"):
		if not c is Dictionary:
			continue
		var a: Dictionary = aj.get("extra_%d" % n, {})
		CasaPacote.criar(self, terrain, "CasaPacote_%d" % n, float(c.x) + float(a.get("dx", 0.0)), -float(c.y) - float(a.get("dy", 0.0)),
			deg_to_rad(float(a.yaw_deg)) if a.has("yaw_deg") else deg_to_rad(float(c.get("rot_deg", 0.0))))
		n += 1
		if Loading.ceder():
			await get_tree().process_frame
	return n


func _cena(tipo: String) -> PackedScene:
	if not _cache.has(tipo):
		var recurso := tipo
		var extensao := ".glb"
		# Os três carros completos mantêm interior, vidros transparentes e peças
		# separadas no FBX original; os nomes antigos continuam no layout da ilha.
		if tipo.begins_with("cenario/carros/carro_"):
			recurso += "_aberto"
			extensao = ".fbx"
		var p := ("res://assets/models/%s%s" % [recurso, extensao]) if "/" in recurso else ("res://assets/models/detalhes/%s%s" % [recurso, extensao])
		_cache[tipo] = load(p) if ResourceLoader.exists(p) else null
		if _cache[tipo] and tipo.begins_with("atualizacao/mundo/"):
			_materiais_mundo(_cache[tipo])
	return _cache[tipo]


## Pack 'atualizacao/mundo' (tools/importar_pack_mundo.py): glb sem imagem; cada superfície recebe UM material
## compartilhado pelo nome do slot (paleta com filtro nearest = 1 textura para todas as peças).
const TEX_MUNDO := {"mil_paleta": "mundo/tex/Textures1.png", "mil_camo1": "mundo/tex/Camouflage_1.png",
	"mil_camo2": "mundo/tex/Camouflage_2.png", "apo_paleta": "mundo/tex/Color2.png", "apo_painel": "mundo/tex/Dashboard.png",
	"apo_mapa": "mundo/tex/Map.png", "apo_placas": "mundo/tex/RoadSigns.png", "apo_numeros": "mundo/tex/Car_Numbers.png",
	"int_paleta": "interiores/Textures_4.png", "ani_paleta": "mundo/tex/Animais.png"}
static var _mat_mundo := {}


const COR_COPA := {"laranja": Color("EE8420"), "amarela": Color("F2C230"), "vermelha": Color("C8402A")}
var _mat_copa := {}


func _copa_outono(no: Node3D, cor: String) -> void:
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		var m0 := (mi as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		if m0 == null or m0.albedo_texture == null:
			continue
		var k := "%s|%d" % [cor, m0.albedo_texture.get_instance_id()]
		if not _mat_copa.has(k):
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://shaders/copa_outono.gdshader")
			sm.set_shader_parameter("paleta", m0.albedo_texture)
			sm.set_shader_parameter("outono", COR_COPA.get(cor, COR_COPA.laranja))
			_mat_copa[k] = sm
		(mi as MeshInstance3D).material_override = _mat_copa[k]


func _materiais_mundo(sc: PackedScene) -> void:
	var raiz := sc.instantiate()
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m0 := mesh.surface_get_material(i)
			var nome := m0.resource_name if m0 else "mil_paleta"
			if not TEX_MUNDO.has(nome):
				continue
			if not _mat_mundo.has(nome):
				var m := StandardMaterial3D.new()
				m.albedo_texture = load("res://assets/models/atualizacao/" + String(TEX_MUNDO[nome]))
				var paleta := nome.ends_with("paleta")
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if paleta else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				m.roughness = 0.9
				m.metallic_specular = 0.25
				_mat_mundo[nome] = m
			mesh.surface_set_material(i, _mat_mundo[nome])
	raiz.free()


func _chao(xy: Vector2) -> Vector3:
	return Vector3(xy.x, terrain.height_world(xy.x, -xy.y), -xy.y)


## Auditoria de colisão (tests/props_colisao.gd, só com --audit_props): pontos sólidos (centroides de triângulos) de cada peça colocada.
var auditoria: Array = []


func _colocar(tipo: String, xy: Vector2, rot_deg: float, escala_x := 1.0, escala := 1.0, dy := 0.0, tomba := 0.0) -> Node3D:
	var tipo0 := tipo
	var r := _colocar_i(tipo, xy, rot_deg, escala_x, escala, dy, tomba)
	if r != null and Game.test_args.has("audit_props"):
		var pts := PackedVector3Array()
		for mi in r.find_children("*", "MeshInstance3D", true, false):
			var me: Mesh = (mi as MeshInstance3D).mesh
			if me == null:
				continue
			var f := me.get_faces()
			var xf := (mi as MeshInstance3D).global_transform
			var passo := maxi(3, int(f.size() / 3.0 / (800.0 if Game.test_args.has("denso") else 40.0)) * 3)
			var i := 0
			while i + 2 < f.size():
				pts.append(xf * ((f[i] + f[i + 1] + f[i + 2]) / 3.0))
				if Game.test_args.has("denso"):
					pts.append(xf * f[i])
					pts.append(xf * ((f[i] + f[i + 1]) * 0.5))
				i += passo
		auditoria.append({"tipo": tipo0, "pos": r.global_position, "pts": pts, "basis": r.global_transform.basis})
	return r


func _colocar_i(tipo: String, xy: Vector2, rot_deg: float, escala_x := 1.0, escala := 1.0, dy := 0.0, tomba := 0.0) -> Node3D:
	if TROCA.has(tipo) and not (tipo == "tambor" and Game.test_args.has("sem_vilas")):
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
	n.scale = Vector3(escala_x * e, e, e) * escala
	n.position.y += dy
	# tombado (poste caído): gira em torno do eixo Z local antes de criar a colisão, que é copiada da transformação atual
	if tomba != 0.0:
		n.rotation.z = deg_to_rad(tomba)
	# Os carros do cenário deixam de ser cascos estáticos: a própria carroceria existente
	# vira VehicleBody3D, mantendo posição, rotação, modelo e materiais autorais do mapa.
	if tipo.begins_with("cenario/carros/carro_"):
		var vehicle := DrivableVehicle.create_from_model(n, tipo)
		for g in vehicle.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = 340.0
			(g as GeometryInstance3D).visibility_range_end_margin = 20.0
		return vehicle
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
	var formas_glb := n.find_children("*", "CollisionShape3D", true, false)
	var antiga := Game.test_args.has("colisao_antiga")   # A/B da auditoria: comportamento antes das correções
	var caixa := tipo in COLISAO_CAIXA and not antiga
	var tem_colisao := not formas_glb.is_empty() and not caixa
	n.set_meta("prop", tipo)   # _fundir(): vira MultiMesh por célula
	for cs0 in ([] if caixa else formas_glb):
		_forma_caixa((cs0 as CollisionShape3D).shape, (cs0 as CollisionShape3D).global_transform)
	for sb in n.find_children("*", "CollisionObject3D", true, false):
		sb.get_parent().remove_child(sb)
		sb.free()
	var nat := tipo.trim_prefix("cenario/natureza/") if tipo.begins_with("cenario/natureza/") else ""
	if nat != "" and (nat in ARVORES_PACOTE):
		# árvore: só o tronco colide (cilindro na origem = pé do tronco); a copa não vira parede invisível
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.32 * n.scale.x
		for mi0 in n.find_children("*", "MeshInstance3D", true, false):
			var mesh0: Mesh = (mi0 as MeshInstance3D).mesh
			if mesh0 != null:
				var rm := IlhaVegetation.raio_tronco(mesh0, n.scale.x, n.global_transform.affine_inverse() * (mi0 as MeshInstance3D).global_transform)
				cyl.radius = maxf(cyl.radius, rm)   # tronco medido na malha (antes 0,32 fixo: o jogador entrava no tronco)
				break
		cyl.height = 5.0 * n.scale.y
		_forma(cyl, Transform3D(Basis(), n.global_position + Vector3.UP * cyl.height * 0.5))
		return n
	if nat != "" and (nat in SEM_COLISAO_PACOTE):
		return n
	if not (tipo in SEM_COLISAO or (antiga and tipo in ["varal", "placa_rua", "bicicleta"])) and not tem_colisao:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			var mesh_id := mesh.get_instance_id()
			if not _shape_cache.has(mesh_id):
				# peças vazadas/finas (cercas de ripas, muros, portões, ruínas) usam colisão FIEL (trimesh): o casco convexo
				# fechava os vãos e criava a "parede invisível" que impedia pular/passar
				var fiel := tipo == "barraca_militar" or tipo.begins_with("cerca") or tipo.begins_with("muro") or tipo.begins_with("portao") 						or tipo.begins_with("cenario/natureza/cerca") or tipo.begins_with("cenario/natureza/muro") or tipo == "cenario/natureza/entulho"
				# o resto vira caixa (AABB da malha): convexo por peça custava caro no move_and_slide
				if fiel:
					var tm := mesh.create_trimesh_shape()
					tm.backface_collision = true   # sem isso o corpo atravessa a cerca/muro vindo pelo lado de trás da malha
					_shape_cache[mesh_id] = tm
				else:
					_shape_cache[mesh_id] = _caixa_aabb(mesh.get_aabb())
			var xf := (mi as MeshInstance3D).global_transform
			if _shape_cache[mesh_id] is BoxShape3D:
				xf = xf * Transform3D(Basis(), mesh.get_aabb().get_center())
			_forma(_shape_cache[mesh_id], xf)
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
			if Loading.ceder():
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
	# fios fundidos por célula de 128 m (1 malha por célula em vez de 1 nó por vão)
	var ck := Vector2i(int(floor(a.x / 128.0)), int(floor(a.z / 128.0)))
	if not _fios.has(ck):
		_fios[ck] = PackedVector3Array()
	_fios[ck].append_array(st.commit_to_arrays()[Mesh.ARRAY_VERTEX])

# ---- desempenho (triagem 07/10): colisão sem nós e malhas fundidas por célula -------------------------------------
var _rid := RID()
var _formas: Array[Shape3D] = []     # mantém as formas vivas (o servidor só guarda o RID)
var _caixa_cache := {}
var _fios := {}
const CELULA := 80.0


func _exit_tree() -> void:
	if _rid.is_valid():
		PhysicsServer3D.free_rid(_rid)
		_rid = RID()


func _forma(sh: Shape3D, xf: Transform3D) -> void:
	_formas.append(sh)
	PhysicsServer3D.body_add_shape(_rid, sh.get_rid(), xf)


func _caixa_aabb(ab: AABB) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = ab.size.max(Vector3(0.05, 0.05, 0.05))
	return b


## Forma importada do glb (convexo por parte, -convcolonly): vira caixa do AABB dos pontos (cobertura de sacos/HESCO
## continua fiel por parte); trimesh e primitivas passam como estão.
func _forma_caixa(sh: Shape3D, xf: Transform3D) -> void:
	if sh is ConvexPolygonShape3D:
		var id := sh.get_instance_id()
		if not _caixa_cache.has(id):
			var pts: PackedVector3Array = (sh as ConvexPolygonShape3D).points
			var ab := AABB(pts[0], Vector3.ZERO)
			for q in pts:
				ab = ab.expand(q)
			_caixa_cache[id] = [_caixa_aabb(ab), ab.get_center()]
		_forma(_caixa_cache[id][0], xf * Transform3D(Basis(), _caixa_cache[id][1]))
	else:
		_forma(sh, xf)


## Props decorativos (meta "prop") -> um MultiMeshInstance3D por (malha, material, sombra, alcance, célula de 48 m).
## Mesma posição/escala/giro de cada peça; menos nós e menos draw calls. Peças com script/animação não entram.
func _fundir() -> void:
	if Game.test_args.has("sem_fundir"):
		_fios_soltos()
		return
	var grupos := {}
	var soltar: Array = []
	for no in get_children():
		if not no.has_meta("prop") or no.get_script() != null:
			continue
		if not no.find_children("*", "AnimationPlayer", true, false).is_empty() or not no.find_children("*", "Skeleton3D", true, false).is_empty():
			continue
		var ok := true
		var itens: Array = []
		for g in no.find_children("*", "VisualInstance3D", true, false):
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null and _verts((g as MeshInstance3D).mesh) > 1500:
				ok = false   # malhas pesadas (árvores, carros) mantêm o LOD automático da MeshInstance
				break
			if not (g is MeshInstance3D) or (g as MeshInstance3D).mesh == null or (g as MeshInstance3D).get_surface_override_material_count() > 0 and _tem_override_superficie(g):
				ok = false
				break
			itens.append(g)
		if not ok or itens.is_empty():
			continue
		for g in itens:
			var mi := g as MeshInstance3D
			var p := mi.global_position
			var k := "%d|%d|%d|%d|%d|%d" % [mi.mesh.get_instance_id(), mi.material_override.get_instance_id() if mi.material_override else 0,
				mi.cast_shadow, int(mi.visibility_range_end), int(floor(p.x / CELULA)), int(floor(p.z / CELULA))]
			if not grupos.has(k):
				grupos[k] = [mi.mesh, mi.material_override, mi.cast_shadow, mi.visibility_range_end, []]
			grupos[k][4].append(mi.global_transform)
		soltar.append(no)
		if Loading.ceder():   # orçamento por quadro (pré-montagem atrás do criador)
			await get_tree().process_frame
	for k in grupos:
		var gq: Array = grupos[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = gq[0]
		mm.instance_count = (gq[4] as Array).size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, gq[4][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = gq[1]
		mmi.cast_shadow = gq[2]
		mmi.visibility_range_end = gq[3]
		mmi.visibility_range_end_margin = 15.0
		add_child(mmi)
		if Loading.ceder():
			await get_tree().process_frame
	for no in soltar:
		remove_child(no)
		no.free()
		if Loading.ceder():
			await get_tree().process_frame
	for ck in _fios:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in _fios[ck]:
			st.add_vertex(v)
		st.generate_normals()
		var fm := MeshInstance3D.new()
		fm.mesh = st.commit()
		fm.material_override = _fio_mat
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fm.visibility_range_end = 300.0
		add_child(fm)
	print("DETALHES_FUNDIDOS pecas=%d multimesh=%d formas=%d" % [soltar.size(), grupos.size(), _formas.size()])


func _tem_override_superficie(mi: MeshInstance3D) -> bool:
	for i in mi.get_surface_override_material_count():
		if mi.get_surface_override_material(i) != null:
			return true
	return false


func _fios_soltos() -> void:
	for ck in _fios:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in _fios[ck]:
			st.add_vertex(v)
		st.generate_normals()
		var fm := MeshInstance3D.new()
		fm.mesh = st.commit()
		fm.material_override = _fio_mat
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fm.visibility_range_end = 300.0
		add_child(fm)


func _verts(me: Mesh) -> int:
	var n := 0
	for i in me.get_surface_count():
		n += me.surface_get_array_len(i)
	return n
