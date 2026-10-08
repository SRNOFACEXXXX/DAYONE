extends Node3D
signal map_ready
## Cena da Ilha do Tauá (fase de construção): ambiente, terreno, água, blockout dos prédios do design
## (caixas com o tamanho real de cada prédio, substituídas pelos modelos definitivos depois) e explorador.

var terrain: IlhaTerrain
var layout: Dictionary
var _collision_cache: Dictionary = {}


func _collision_for(mesh: Mesh, convex: bool) -> Shape3D:
	var key := "%s:%s" % [mesh.get_instance_id(), convex]
	if not _collision_cache.has(key):
		if convex:
			_collision_cache[key] = mesh.create_convex_shape(true, true)
		else:
			# colisão fiel à malha (vãos de porta, cercas, escadas); backface para não vazar por paredes finas
			var tm := mesh.create_trimesh_shape()
			tm.backface_collision = true
			_collision_cache[key] = tm
	return _collision_cache[key]


const FOG_CHAO := 0.0007
var FOG_ATUAL := FOG_CHAO
var _env: Environment


## Névoa cai com a altitude da câmera: no chão segura a profundidade, do alto (avião/aérea) não lava a ilha.
func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if _env and cam:
		_env.fog_density = FOG_ATUAL * clampf(1.0 - (cam.global_position.y - 60.0) / 500.0, 0.3, 1.0)


func _ready() -> void:
	await _build_map_async()


func _build_map_async() -> void:
	Loading.show_progress("Lendo o mapa e as texturas...", 5.0)
	Loading.marcar_passo("layout")
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/ilha_layout.json"))
	if Loading.ceder():
		await get_tree().process_frame
	Loading.marcar_passo("ambiente")
	_environment()
	if Loading.ceder():
		await get_tree().process_frame
	Loading.marcar_passo("terreno")
	terrain = IlhaTerrain.new()
	terrain.name = "Terreno"
	terrain.plataformas = _plataformas_casas()
	terrain.plataformas_carros = _plataformas_carros()
	terrain.bloqueios = _bloqueios_terreno()
	add_child(terrain)
	await terrain.terrain_ready
	Loading.set_progress("Preparando água e terreno...", 23.0)
	Loading.marcar_passo("agua")
	_water()
	if Loading.ceder():
		await get_tree().process_frame
	Loading.marcar_passo("capim")
	var grama := IlhaGrama.new()   # capim alto em volta da câmera (splat G + fora de trilhas/estradas/prédios)
	grama.name = "Capim"
	add_child(grama)
	grama.setup(terrain, layout)
	grama.set_process(false)   # só começa depois de tudo montado (precisa enxergar as casas do pacote)
	if Loading.ceder():
		await get_tree().process_frame
	# preparação única das casas do pacote (~3 s de GDScript) numa thread: o menu/criador continua liso
	Loading.marcar_passo("casa_preparar")
	var tarefa_casa := WorkerThreadPool.add_task(CasaPacote.preparar, false, "casa_pacote")
	while not WorkerThreadPool.is_task_completed(tarefa_casa):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa_casa)
	Loading.marcar_passo("predios")
	await _blockout_async()   # antes da vegetação: ela evita as casas do pacote (grupo "casa_pacote")
	Loading.marcar_passo("vegetacao")
	var veg := IlhaVegetation.new()
	veg.name = "Vegetacao"
	add_child(veg)
	print("VEGETACAO instancias=", await veg.build_async(terrain))
	Loading.marcar_passo("coberturas")
	await _coberturas_async()
	Loading.marcar_passo("nuvens")
	_nuvens()
	Loading.marcar_passo("detalhes")
	var det := IlhaDetalhes.new()
	det.name = "Detalhes"
	add_child(det)
	print("DETALHES itens=", await det.build_async(terrain))
	Loading.marcar_passo("refugios")
	var refugios: Node3D = load("res://maps/ilha/refugios_gpt.gd").new()
	refugios.name = "RefugiosGPT"
	add_child(refugios)
	refugios.build(terrain)
	Loading.marcar_passo("explorador")
	var p: Node3D = null
	if not Loading.silencioso:   # pré-montagem da partida: o explorador (câmera livre do tour) seria descartado pela br_match
		p = load("res://core/explorer.gd").new()
		p.name = "Explorador"
		add_child(p)
		var start: Array = Game.test_args.get("start", "-360,-330").split(",")
		var sx := float(start[0])
		var sy := float(start[1])
		p.global_position = Vector3(sx, terrain.height_world(sx, -sy) + 2.0, -sy)
		p.yaw = deg_to_rad(float(Game.test_args.get("yaw", "0")))
	Loading.set_progress("Compilando shaders de terreno, céu e água...", 94.0)
	# Mantém a tela de carregamento por quadros renderizados: o driver compila os shaders usados
	# pelo cenário antes de devolver o controle ao jogador.
	# Com o aquecimento do menu feito (Loading.aquecido) ou na pré-montagem escondida, os shaders já estão
	# compilados ou serão compilados na SubViewport: 1 quadro basta.
	for _i in (1 if (Loading.aquecido or Loading.silencioso) else 4):
		await RenderingServer.frame_post_draw
	print("ILHA_PREPARADA shaders=terreno,agua,ceu,nuvem")
	if Loading.silencioso:
		_grama_adiada = grama   # capim em volta da câmera começa no CONFIRMAR (ativar_ambiente)
	else:
		grama.set_process(true)
	Loading.marcar_passo("zumbis")
	var zombie_director := ZombieDirector.new()
	zombie_director.name = "ZombieDirector"
	add_child(zombie_director)
	if Loading.silencioso:
		# pré-montagem: zumbis só nascem no CONFIRMAR (ativar_ambiente), em volta do jogador, sob a tela de carregamento
		zombie_director.process_mode = Node.PROCESS_MODE_DISABLED
		_zumbis_adiados = true
	else:
		zombie_director.setup(terrain, p, _zombie_settlement_centers())
	map_ready.emit()
	if Game.current_match == null:
		Loading.hide_after_render()


func _zombie_settlement_centers() -> Array[Vector3]:
	var centers: Array[Vector3] = []
	for poi in layout.get("pois", []):
		var buildings: Array = poi.get("predios", [])
		if buildings.is_empty():
			continue
		var map_center := Vector2.ZERO
		for building in buildings:
			map_center += Vector2(float(building.pos[0]), float(building.pos[1]))
		map_center /= buildings.size()
		var world_x := map_center.x
		var world_z := -map_center.y
		centers.append(Vector3(world_x, terrain.height_world(world_x, world_z), world_z))
	return centers


var _we_adiado: WorldEnvironment


var _zumbis_adiados := false
var _grama_adiada: Node


func ativar_ambiente(jogador: Node3D = null) -> void:
	if is_instance_valid(_grama_adiada):
		_grama_adiada.set_process(true)
		_grama_adiada = null
	if _we_adiado:
		add_child(_we_adiado)
		_we_adiado = null
	if _zumbis_adiados:
		_zumbis_adiados = false
		var zd := get_node_or_null("ZombieDirector")
		if zd:
			zd.process_mode = Node.PROCESS_MODE_INHERIT
			if jogador:
				zd.setup(terrain, jogador, _zombie_settlement_centers())


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skm := ShaderMaterial.new()          # céu próprio (tools: shaders/ceu.gdshader); vira skybox 360° da Scenario quando houver
	skm.shader = load("res://shaders/ceu.gdshader")
	sky.sky_material = skm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.ambient_light_sky_contribution = 0.3
	env.ambient_light_color = Color("9AB0D0")   # céu azulado nas sombras (crítica 01, item 15)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = not Game.test_args.has("nofog")
	env.fog_light_color = Color("A1B0BD")   # entre o mar e o horizonte pêssego
	env.fog_density = FOG_CHAO
	_env = env
	env.fog_sky_affect = 0.08   # crítica 04: céu menos lavado
	# correção de cor (crítica 01, item 16): sombras frias, altas luzes quentes
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.0
	# passe de paleta (subagente MUNDO, refs Downloads/ref: céu azul saturado, verde vivo, pouca névoa): ver _hora()
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.12
	var rampa := Gradient.new()
	rampa.set_color(0, Color("080C16"))   # (a rampa da crítica, 2B3350->FFE7C2, remapeia canal a canal e lava a imagem)
	rampa.add_point(0.5, Color("817E76"))
	rampa.set_color(rampa.get_point_count() - 1, Color("FFF6E6"))
	var cc := GradientTexture1D.new()
	cc.gradient = rampa
	env.adjustment_color_correction = cc
	var we := WorldEnvironment.new()
	we.environment = env
	# pré-montagem atrás do criador: o céu (radiância do ceu.gdshader) custava ~1,8 s num quadro só do menu;
	# entra no CONFIRMAR, debaixo da tela de carregamento (ativar_ambiente)
	if Loading.silencioso:
		_we_adiado = we
	else:
		add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, -35, 0)   # fim de tarde baixo: sombras longas, relevo legível
	sun.light_energy = 1.35
	sun.light_color = Color("FFDEB3")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.8   # crítica 04: sombra não chapada em preto
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL   # 1 estágio: metade dos passes de sombra (GT 730)
	add_child(sun)
	_sol = sun
	_ceu = skm
	Clima.ligar(self, env, sun, skm)   # ciclo dia/noite + clima (core/clima.gd); --hora=X congela a hora


## Paleta por hora do dia (fixa na partida; --hora=15.5 nos testes). Meio do dia: sol alto e branco, céu azul
## saturado até o horizonte claro; fim de tarde (17–18 h): sol baixo e quente, horizonte pêssego. Interpola entre os dois.
const HORA_PADRAO := 15.5
var _sol: DirectionalLight3D
var _ceu: ShaderMaterial


func _hora(h: float) -> void:
	var k := smoothstep(13.0, 18.0, h)            # 0 = meio do dia, 1 = fim de tarde
	_sol.rotation_degrees = Vector3(lerpf(-50.0, -16.0, k), -35.0, 0.0)
	_sol.light_color = Color("FFF7EC").lerp(Color("FFC98F"), k)
	_sol.light_energy = lerpf(1.3, 1.3, k)
	_env.ambient_light_color = Color("A9C4E8").lerp(Color("9AB0D0"), k)
	_env.fog_light_color = Color("B9D3EC").lerp(Color("C9C2B8"), k)
	FOG_ATUAL = lerpf(0.00042, 0.0006, k)
	_env.fog_density = FOG_ATUAL
	_env.fog_sky_affect = 0.03
	_ceu.set_shader_parameter("zenite", Color("1F5FD0").lerp(Color("3A69B0"), k))
	_ceu.set_shader_parameter("meio", Color("4C8FE6").lerp(Color("74A3DA"), k))
	_ceu.set_shader_parameter("horizonte", Color("BFDDF5").lerp(Color("EBCDB0"), k))
	_ceu.set_shader_parameter("mar_longe", Color("A9C8E2").lerp(Color("B4BCC2"), k))
	_ceu.set_shader_parameter("sol_cor", Color("FFF4E0").lerp(Color("FFD49C"), k))


func _water() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/agua.gdshader")
	var prof = load("res://maps/ilha/agua.png") if ResourceLoader.exists("res://maps/ilha/agua.png") else null
	mat.set_shader_parameter("profundidade", prof)
	var mat_rep: ShaderMaterial = mat.duplicate()
	mat_rep.set_shader_parameter("canal", 1)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000, 12000)   # mar até o horizonte (a névoa funde com o céu)
	sea.mesh = pm
	sea.material_override = mat
	sea.name = "Mar"
	add_child(sea)
	# represa: malha recortada no contorno do layout (antes: retângulo do bbox + 20 m, que cobria vales secos)
	var rep: Dictionary = layout.agua.represa
	_lago_nivel = float(rep.nivel_agua_m)
	_lago_poly = PackedVector2Array()
	for p in rep.contorno:
		_lago_poly.append(Vector2(float(p[0]), -float(p[1])))
	var tri := Geometry2D.triangulate_polygon(_lago_poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, tri.size(), 3):
		var v: Array[Vector3] = []
		for k in 3:
			var q := _lago_poly[tri[i + k]]
			v.append(Vector3(q.x, _lago_nivel, q.y))
		if (v[1] - v[0]).cross(v[2] - v[0]).y < 0.0:
			var tmp := v[1]; v[1] = v[2]; v[2] = tmp
		for q in v:
			st.set_normal(Vector3.UP)
			st.add_vertex(q)
	var lake := MeshInstance3D.new()
	lake.mesh = st.commit()
	lake.material_override = mat_rep
	lake.name = "Represa"
	add_child(lake)
	_rio(mat)
	Soldier.agua_fn = Callable(self, "nivel_agua_em")


var _lago_poly := PackedVector2Array()
var _lago_nivel := 15.0


## Superfície d'água (m) no ponto do mundo (x, z): represa dentro do contorno, mar (0) fora; usado pelo nado do Soldier.
func nivel_agua_em(x: float, z: float) -> float:
	if _lago_poly.size() > 2 and Geometry2D.is_point_in_polygon(Vector2(x, z), _lago_poly):
		return _lago_nivel
	return 0.0


func _blockout_async() -> void:
	var root := Node3D.new()
	root.name = "Blockout"
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.82, 0.74)
	mat.roughness = 0.9
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.62, 0.3, 0.22)
	var built := 0
	for poi in layout.pois + layout.get("marcos", []):
		for pr in poi.get("predios", []):
			Loading.marcar_passo("predio " + String(pr.get("tipo", pr.get("id", ""))))
			var sz: Array = pr.tamanho_m
			if _modelo_predio(root, pr, _centro_poi(poi)):
				built += 1
				if Loading.ceder():   # orçamento por quadro (pré-montagem: 8 ms; carregamento: 45 ms)
					Loading.set_progress("Construindo prédios e locais de saque...", 48.0 + 12.0 * float(built) / 100.0)
					await get_tree().process_frame
				continue
			var body := StaticBody3D.new()
			body.name = String(pr.id)
			var x := float(pr.pos[0])
			var y := float(pr.pos[1])
			var h := float(sz[2])
			body.position = Vector3(x, terrain.height_world(x, -y), -y)
			body.rotation.y = deg_to_rad(float(pr.get("rot_deg", 0)))
			root.add_child(body)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(float(sz[0]), h, float(sz[1]))
			mi.mesh = bm
			mi.material_override = mat
			mi.position.y = h * 0.5
			body.add_child(mi)
			var cap := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(float(sz[0]) + 0.4, 0.3, float(sz[1]) + 0.4)
			cap.mesh = cm
			cap.material_override = roof
			cap.position.y = h + 0.15
			body.add_child(cap)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			cs.position.y = h * 0.5
			body.add_child(cs)
			built += 1
			if Loading.ceder():   # orçamento por quadro (pré-montagem: 8 ms; carregamento: 45 ms)
				Loading.set_progress("Construindo prédios e locais de saque...", 48.0 + 12.0 * float(built) / 100.0)
				await get_tree().process_frame


## Coberturas de campo aberto do design (assets/models/cobertura/<tipo>.glb); colisão fiel (trimesh) do próprio modelo:
## o casco convexo antigo tampava vãos (trincheira, caminhão, cerca) e criava "parede invisível".
func _coberturas_async() -> void:
	var root := Node3D.new()
	root.name = "Coberturas"
	add_child(root)
	var i := 0
	var lista: Array = layout.cobertura_campo_aberto.duplicate()
	if FileAccess.file_exists("res://maps/ilha/gameplay_01.json"):
		var gp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/gameplay_01.json"))
		lista.append_array(gp.get("coberturas_novas", []))
		_marcos(gp)
	for c in lista:
		i += 1
		var p := "res://assets/models/cobertura/%s.glb" % c.tipo
		if not ResourceLoader.exists(p):
			continue
		var x := float(c.pos[0])
		var z := -float(c.pos[1])
		var body := StaticBody3D.new()
		body.name = "%s_%d" % [c.tipo, i]
		body.position = Vector3(x, terrain.height_world(x, z) - 0.05, z)
		body.rotation.y = deg_to_rad(float(c.get("rot_deg", i * 47 % 360)))
		root.add_child(body)
		var sc: Node3D = load(p).instantiate()
		body.add_child(sc)
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			# 543+ coberturas: sem corte a aérea passava de 2.300 draws; as baixas (< 1,2 m) somem antes e não fazem sombra
			var baixa := float(c.get("altura_m", 2.0)) < 1.2
			(mi as MeshInstance3D).visibility_range_end = 200.0 if baixa else 320.0
			if baixa:
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(mi as MeshInstance3D).visibility_range_end_margin = 20.0
			var cs := CollisionShape3D.new()
			cs.shape = _collision_for((mi as MeshInstance3D).mesh, false)
			body.add_child(cs)
			cs.global_transform = (mi as MeshInstance3D).global_transform
		if Loading.ceder():
			Loading.set_progress("Colocando coberturas e pontos de referência...", 62.0 + 14.0 * float(i) / maxf(1.0, float(lista.size())))
			await get_tree().process_frame


## Plataformas circulares sob cada carro: [centro Vector2 (x,z), raio].
func _plataformas_carros() -> Array:
	var out: Array = []
	var files = ["res://maps/ilha/cenario_areas.json", "res://maps/ilha/cenario_areas_02.json", "res://maps/ilha/cenario_areas_03.json",
			"res://maps/ilha/cenario_atualizacao.json"]

	for file_path in files:
		if not FileAccess.file_exists(file_path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		if data == null:
			continue

		for area in data.get("areas", []):
			for prop in area.get("props", []):
				var tipo = String(prop.get("tipo", ""))
				if not tipo.begins_with("cenario/carros/carro_"):
					continue

				var x := float(prop.get("x", 0.0))
				var z := -float(prop.get("y", 0.0))  # -y porque JSON usa y = -z do mundo
				# Planalto de 5 m de raio (carro ~ 2 x 4.5 m + meia célula de 2 m da colisão), transição de 6 m em volta
				out.append([Vector2(x, z), 5.0])

	return out


## Trechos onde o suavizador de declives não mexe: rio (leito escavado), pontes e crista da barragem. [a, b, raio] em (x, z).
func _bloqueios_terreno() -> Array:
	var out: Array = []
	for tr in layout.get("agua", {}).get("rio", {}).get("trechos", []):
		var pts: Array = tr.pontos
		for i in pts.size() - 1:
			out.append([Vector2(float(pts[i][0]), -float(pts[i][1])), Vector2(float(pts[i + 1][0]), -float(pts[i + 1][1])), float(tr.largura_m) * 0.5 + 6.0])
	var lista: Array = []
	if FileAccess.file_exists("res://maps/ilha/cenario_atualizacao.json"):
		var ca: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/cenario_atualizacao.json"))
		lista = ca.get("pontes", []).duplicate()
	lista.append({"centro": [-100.0, -86.0], "direcao_deg": -45.0, "comprimento_m": 40.0, "largura_m": 6.0})   # crista da barragem
	for p in lista:
		var dv := Vector2(cos(deg_to_rad(float(p.direcao_deg))), sin(deg_to_rad(float(p.direcao_deg))))
		var c := Vector2(float(p.centro[0]), float(p.centro[1]))
		var h := float(p.comprimento_m) * 0.5 + 10.0
		out.append([Vector2((c - dv * h).x, -(c - dv * h).y), Vector2((c + dv * h).x, -(c + dv * h).y), float(p.largura_m) * 0.5 + 6.0])
	return out


## Posição e giro de cada casa do pacote (mesma conta de _casa_do_pacote) para aplainar o terreno antes de construí-lo.
func _plataformas_casas() -> Array:
	var out: Array = []
	for poi in layout.get("pois", []) + layout.get("marcos", []):
		var centro := _centro_poi(poi)
		for pr in poi.get("predios", []):
			var tipo := String(pr.tipo)
			if not CasaPacote.e_casa(tipo):
				continue
			var aj: Dictionary = CasaPacote.ajustes().get(String(pr.id), {})
			var x := float(pr.pos[0]) + float(aj.get("dx", 0.0))
			var z := -float(pr.pos[1]) - float(aj.get("dy", 0.0))
			var yaw := deg_to_rad(float(aj.yaw_deg)) if aj.has("yaw_deg") else (atan2(centro.x - x, centro.y - z) if centro != Vector2.ZERO else deg_to_rad(float(pr.get("rot_deg", 0))))
			var rot_l := deg_to_rad(float(pr.get("rot_deg", 0)))
			var deslocs: Array[Vector2] = [Vector2.ZERO]
			if tipo == "vila_operaria":
				deslocs = [Vector2(0, -6.9).rotated(-rot_l), Vector2(0, 6.9).rotated(-rot_l)]
			elif tipo == "casarao":
				deslocs = [Vector2(-7.2, 0).rotated(-rot_l), Vector2(7.2, 0).rotated(-rot_l)]
			for d in deslocs:
				out.append([Vector2(x + d.x, z + d.y), yaw])
	return out


## Toda casa residencial do layout vira a casa completa do pacote (mesma posição; porta para o centro do POI).
## vila_operaria (6x24) = 2 casas lado a lado no eixo longo; casarao (26x18) = 2 casas no eixo x.
func _casa_do_pacote(root: Node3D, pr: Dictionary, centro: Vector2) -> void:
	var tipo := String(pr.tipo)
	var aj: Dictionary = CasaPacote.ajustes().get(String(pr.id), {})   # tools/ajustar_casas.py: sai de estrada/declive/prédios, porta para a rua
	var x := float(pr.pos[0]) + float(aj.get("dx", 0.0))
	var z := -float(pr.pos[1]) - float(aj.get("dy", 0.0))
	var yaw := deg_to_rad(float(aj.yaw_deg)) if aj.has("yaw_deg") else (atan2(centro.x - x, centro.y - z) if centro != Vector2.ZERO else deg_to_rad(float(pr.get("rot_deg", 0))))
	var rot_l := deg_to_rad(float(pr.get("rot_deg", 0)))
	var deslocs: Array[Vector2] = [Vector2.ZERO]
	if tipo == "vila_operaria":
		deslocs = [Vector2(0, -6.9).rotated(-rot_l), Vector2(0, 6.9).rotated(-rot_l)]
	elif tipo == "casarao":
		deslocs = [Vector2(-7.2, 0).rotated(-rot_l), Vector2(7.2, 0).rotated(-rot_l)]
	for i in deslocs.size():
		var nome := String(pr.id) if i == 0 else "%s_b" % String(pr.id)
		CasaPacote.criar(root, terrain, nome, x + deslocs[i].x, z + deslocs[i].y, yaw)


## Prédio modelado (assets/models/predios/<tipo>_<variante>.glb): variante fixa pelo índice do id; colisão da malha.
func _centro_poi(poi: Dictionary) -> Vector2:
	var ps: Array = poi.get("predios", [])
	if ps.is_empty():
		return Vector2.ZERO
	var c := Vector2.ZERO
	for p in ps:
		c += Vector2(float(p.pos[0]), -float(p.pos[1]))
	return c / ps.size()


func _modelo_predio(root: Node3D, pr: Dictionary, centro := Vector2.ZERO) -> bool:
	var tipo := String(pr.tipo)
	if CasaPacote.e_casa(tipo):
		_casa_do_pacote(root, pr, centro)
		return true
	var variantes: Array[String] = []
	for v in ["a", "b", "c", "d"]:
		var p := "res://assets/models/predios/%s_%s.glb" % [tipo, v]
		if ResourceLoader.exists(p):
			variantes.append(p)
	if variantes.is_empty():
		return false
	var idx := int(String(pr.id).get_slice("_", String(pr.id).get_slice_count("_") - 1))
	var x := float(pr.pos[0])
	var z := -float(pr.pos[1])
	var body := StaticBody3D.new()
	body.name = String(pr.id)
	body.position = Vector3(x, terrain.height_world(x, z), z)
	body.rotation.y = deg_to_rad(float(pr.get("rot_deg", 0)))
	root.add_child(body)
	var arq := variantes[idx % variantes.size()]
	var sc: Node3D = load(arq).instantiate()
	body.add_child(sc)
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var cs := CollisionShape3D.new()
		cs.shape = _collision_for((mi as MeshInstance3D).mesh, false)
		body.add_child(cs)
		cs.global_transform = (mi as MeshInstance3D).global_transform
	# desempenho: as peças do prédio viram UMA malha (uma superfície por material), compartilhada por todos os
	# prédios do mesmo .glb; some além de ALCANCE_PREDIO. A colisão acima continua fiel, peça por peça.
	var fundida := _predio_fundido(arq, sc)
	if fundida:
		var vis := MeshInstance3D.new()
		vis.name = "Visual"
		vis.mesh = fundida
		vis.visibility_range_end = ALCANCE_PREDIO
		vis.visibility_range_end_margin = 20.0
		body.add_child(vis)
		sc.free()
	# mobília do pacote do usuário (maps/ilha/moveis.json, gerado por tools/interior.py): malha compartilhada + caixa de colisão
	# fundir = true: as peças do pack viram uma malha por modelo de prédio (mesmo layout em todos)
	Moveis.instalar(body, arq.get_file().get_basename(), true, true)
	return true


const ALCANCE_PREDIO := 450.0
var _predios_fundidos: Dictionary = {}   # arq -> ArrayMesh (null = não dá para fundir)


## Junta as MeshInstance3D da cena do prédio numa ArrayMesh (por material e formato). Só funde cenas simples
## (Node3D + MeshInstance3D sem esqueleto); qualquer outro nó mantém a cena original.
func _predio_fundido(arq: String, sc: Node3D) -> ArrayMesh:
	if _predios_fundidos.has(arq):
		return _predios_fundidos[arq]
	var grupos := {}
	var ok := true
	for n in sc.find_children("*", "", true, false):
		if n is MeshInstance3D:
			if (n as MeshInstance3D).skeleton != NodePath("") and (n as MeshInstance3D).skin != null:
				ok = false
		elif not (n.get_class() == "Node3D"):
			ok = false
	var inv := sc.global_transform.affine_inverse()
	if ok:
		for n in sc.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			var xf := inv * mi.global_transform
			for si in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(si)
				var chave := "%d|%d" % [mat.get_instance_id() if mat else 0, mi.mesh.surface_get_format(si) & Mesh.ARRAY_FORMAT_CUSTOM_BASE - 1]
				if not grupos.has(chave):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					st.set_material(mat)
					grupos[chave] = st
				(grupos[chave] as SurfaceTool).append_from(mi.mesh, si, xf)
	var am: ArrayMesh = null
	if ok and not grupos.is_empty():
		am = ArrayMesh.new()
		for chave in grupos:
			(grupos[chave] as SurfaceTool).commit(am)
	_predios_fundidos[arq] = am
	return am


## Superfície do rio: faixa ao longo dos trechos do design, 0,5 m abaixo do eixo (o leito foi escavado 1,6 m no bake).
## UV.x atravessa (0 margem esquerda .. 1 margem direita), UV.y = distância em metros (correnteza no shader).
func _rio(base: ShaderMaterial) -> void:
	var mat: ShaderMaterial = base.duplicate()
	mat.set_shader_parameter("canal", 2)
	# rio de mata atlântica: verde-oliva escuro (taninos), não turquesa de mar
	mat.set_shader_parameter("cor_rasa", Color("3E6E66"))
	mat.set_shader_parameter("cor_media", Color("2A5A5C"))    # crítica 05: entre rasa e funda
	mat.set_shader_parameter("cor_funda", Color("1C3F4C"))
	mat.set_shader_parameter("cor_espuma", Color("9FA89A"))
	for tr in layout.agua.rio.trechos:
		var pts: Array = tr.pontos
		var larg := float(tr.largura_m) + 1.0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var dist := 0.0
		var prev := Vector3.ZERO
		var linhas := []
		# densifica a cada ~4 m e assenta a fita no terreno (antes pairava até 2,7 m acima do chão nos pontos do layout)
		var dens: Array[Vector3] = []
		for i in pts.size() - 1:
			var pa := Vector3(float(pts[i][0]), 0.0, -float(pts[i][1]))
			var pb := Vector3(float(pts[i + 1][0]), 0.0, -float(pts[i + 1][1]))
			var n := maxi(int(pa.distance_to(pb) / 4.0), 1)
			for k in n:
				dens.append(pa.lerp(pb, float(k) / n))
		dens.append(Vector3(float(pts[pts.size() - 1][0]), 0.0, -float(pts[pts.size() - 1][1])))
		for i in dens.size():
			var a := dens[maxi(i - 1, 0)]
			var b := dens[mini(i + 1, dens.size() - 1)]
			var dir := (b - a).normalized()
			var lado := Vector3(-dir.z, 0, dir.x) * larg * 0.5
			var c := dens[i]
			var y := minf(terrain.height_world(c.x, c.z), minf(terrain.height_world(c.x - lado.x, c.z - lado.z), terrain.height_world(c.x + lado.x, c.z + lado.z))) + 0.12
			var p := Vector3(c.x, y, c.z)
			if i > 0:
				dist += p.distance_to(prev)
			prev = p
			linhas.append([p - lado, p + lado, dist])
		for i in linhas.size() - 1:
			var l0: Array = linhas[i]
			var l1: Array = linhas[i + 1]
			for v in [[l0[0], 0.0, l0[2]], [l1[0], 0.0, l1[2]], [l0[1], 1.0, l0[2]], [l0[1], 1.0, l0[2]], [l1[0], 0.0, l1[2]], [l1[1], 1.0, l1[2]]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v[1], v[2]))
				st.add_vertex(v[0])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.name = "Rio_" + String(tr.trecho)
		add_child(mi)


## Nuvens low poly modeladas à mão (assets/models/ceu/nuvem_*.glb) em posições autorais, longe da ilha (não entram na névoa).
const NUVENS := [   # 24 nuvens autorais: anel largo em volta da ilha, alturas 220–340 m, escalas 2.0–3.4 (crítica 01, item 19)
	[-760, 540, 240, 2.6, 20], [-420, 860, 280, 3.2, 75], [120, 900, 260, 2.4, 140], [560, 760, 300, 3.0, 10],
	[900, 420, 250, 2.8, 95], [1000, 20, 320, 3.4, 50], [880, -380, 270, 2.6, 160], [560, -780, 290, 3.1, 40],
	[80, -960, 310, 2.9, 120], [-420, -860, 250, 2.5, 70], [-820, -520, 280, 3.3, 150], [-1000, -80, 300, 2.7, 30],
	[-960, 300, 330, 2.2, 110], [-1300, 900, 340, 3.4, 60], [-200, 1300, 320, 3.0, 170], [700, 1250, 300, 2.8, 25],
	[1350, 700, 330, 3.2, 85], [1400, -500, 310, 2.6, 135], [900, -1250, 340, 3.3, 5], [-150, -1400, 300, 3.0, 100],
	[-1200, -1000, 320, 2.9, 145], [-1500, 200, 290, 3.1, 65], [300, 1600, 340, 2.4, 15], [1650, 150, 300, 2.8, 125]]


func _nuvens() -> void:
	var mat_nuvem := ShaderMaterial.new()
	mat_nuvem.shader = load("res://shaders/nuvem.gdshader")
	mat_nuvem.set_shader_parameter("sol_dir", Basis.from_euler(_sol.rotation).z)   # mesmo ângulo do sol
	Clima.nuvens_mat = mat_nuvem
	var raiz := Node3D.new()
	raiz.name = "Nuvens"
	add_child(raiz)
	var i := 0
	for n in NUVENS:
		var p := "res://assets/models/ceu/nuvem_%s.glb" % ["a", "b", "c"][i % 3]
		i += 1
		if not ResourceLoader.exists(p):
			continue
		var nv: Node3D = load(p).instantiate()
		raiz.add_child(nv)
		# crítica 02: anel >= 1.200 m do centro (não pairam sobre a ilha) e alturas 380–520 m
		var xy := Vector2(float(n[0]), float(n[1]))
		xy = xy.normalized() * maxf(xy.length(), 1200.0 + (xy.length() - 760.0) * 0.5)
		var alt := remap(float(n[2]), 220.0, 340.0, 380.0, 520.0)
		nv.position = Vector3(xy.x, alt, -xy.y)
		nv.scale = Vector3(float(n[3]), float(n[3]) * 0.7, float(n[3]))   # achatada
		nv.rotation.y = deg_to_rad(float(n[4]))
		for g in nv.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(g as GeometryInstance3D).material_override = mat_nuvem


## Marcos verticais propostos (gameplay_01.json) e mirante do Pico: modelos do lote 4 / caixa d'água.
const MODELO_MARCO := {"caixa_dagua": "caixa_dagua_a", "antena_celular": "antena_celular_a", "torre_vigia_madeira": "torre_vigia_madeira_a",
	"cata_vento": "cata_vento_a", "torre_igreja": "torre_igreja_a"}


func _marcos(gp: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Marcos"
	add_child(root)
	var itens := []
	for poi in gp.get("marcos_verticais", {}).values():
		for m in poi.get("propostos", []):
			itens.append([String(m.tipo), m.pos, float(m.get("rot_deg", 0))])
	var mir: Dictionary = gp.get("mirante_pico", {})
	if not mir.is_empty():
		itens.append(["mirante", mir.pos, float(mir.get("rot_deg", 0))])
	for it in itens:
		var nome: String = MODELO_MARCO.get(it[0], it[0] + "_a")
		var p := "res://assets/models/predios/%s.glb" % nome
		if not ResourceLoader.exists(p):
			continue
		var x := float(it[1][0])
		var z := -float(it[1][1])
		var body := StaticBody3D.new()
		body.name = "marco_" + nome
		body.position = Vector3(x, terrain.height_world(x, z), z)
		body.rotation.y = deg_to_rad(it[2])
		root.add_child(body)
		var sc: Node3D = load(p).instantiate()
		body.add_child(sc)
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			var cs := CollisionShape3D.new()
			cs.shape = _collision_for((mi as MeshInstance3D).mesh, false)
			body.add_child(cs)
			cs.global_transform = (mi as MeshInstance3D).global_transform
		EscadaVertical.instalar(body, sc)
