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
var _env: Environment


## Névoa cai com a altitude da câmera: no chão segura a profundidade, do alto (avião/aérea) não lava a ilha.
func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if _env and cam:
		_env.fog_density = FOG_CHAO * clampf(1.0 - (cam.global_position.y - 60.0) / 500.0, 0.3, 1.0)


func _ready() -> void:
	await _build_map_async()


func _build_map_async() -> void:
	Loading.show_progress("Lendo o mapa e as texturas...", 5.0)
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/ilha_layout.json"))
	_environment()
	terrain = IlhaTerrain.new()
	terrain.name = "Terreno"
	terrain.plataformas = _plataformas_casas()
	add_child(terrain)
	await terrain.terrain_ready
	Loading.set_progress("Preparando água e terreno...", 23.0)
	_water()
	var grama := IlhaGrama.new()   # capim alto em volta da câmera (splat G + fora de trilhas/estradas/prédios)
	grama.name = "Capim"
	add_child(grama)
	grama.setup(terrain, layout)
	grama.set_process(false)   # só começa depois de tudo montado (precisa enxergar as casas do pacote)
	await _blockout_async()   # antes da vegetação: ela evita as casas do pacote (grupo "casa_pacote")
	var veg := IlhaVegetation.new()
	veg.name = "Vegetacao"
	add_child(veg)
	print("VEGETACAO instancias=", await veg.build_async(terrain))
	await _coberturas_async()
	_nuvens()
	var det := IlhaDetalhes.new()
	det.name = "Detalhes"
	add_child(det)
	print("DETALHES itens=", await det.build_async(terrain))
	var p: Node3D = load("res://core/explorer.gd").new()
	p.name = "Explorador"
	add_child(p)
	var start: Array = Game.test_args.get("start", "-360,-330").split(",")
	var sx := float(start[0])
	var sy := float(start[1])
	p.global_position = Vector3(sx, terrain.height_world(sx, -sy) + 2.0, -sy)
	Loading.set_progress("Compilando shaders de terreno, céu e água...", 94.0)
	# Mantém a tela de carregamento por quadros renderizados: o driver compila os shaders usados
	# pelo cenário antes de devolver o controle ao jogador.
	for _i in 4:
		await RenderingServer.frame_post_draw
	print("ILHA_PREPARADA shaders=terreno,agua,ceu,nuvem")
	grama.set_process(true)
	map_ready.emit()
	if Game.current_match == null:
		Loading.hide_after_render()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skm := ShaderMaterial.new()          # céu próprio (tools: shaders/ceu.gdshader); vira skybox 360° da Scenario quando houver
	skm.shader = load("res://shaders/ceu.gdshader")
	sky.sky_material = skm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1   # críticas 02/03: sombras menos pesadas
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
	var rampa := Gradient.new()
	rampa.set_color(0, Color("080C16"))   # (a rampa da crítica, 2B3350->FFE7C2, remapeia canal a canal e lava a imagem)
	rampa.add_point(0.5, Color("817E76"))
	rampa.set_color(rampa.get_point_count() - 1, Color("FFF6E6"))
	var cc := GradientTexture1D.new()
	cc.gradient = rampa
	env.adjustment_color_correction = cc
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, -35, 0)   # fim de tarde baixo: sombras longas, relevo legível
	sun.light_energy = 1.6
	sun.light_color = Color("FFC98F")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.8   # crítica 04: sombra não chapada em preto
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL   # 1 estágio: metade dos passes de sombra (GT 730)
	add_child(sun)


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
	var rep: Dictionary = layout.agua.represa
	var cont: Array = rep.contorno
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in cont:
		mn = mn.min(Vector2(p[0], p[1]))
		mx = mx.max(Vector2(p[0], p[1]))
	var lake := MeshInstance3D.new()
	var lm := PlaneMesh.new()
	lm.size = (mx - mn) + Vector2(20, 20)
	lake.mesh = lm
	lake.material_override = mat_rep
	_rio(mat)
	lake.name = "Represa"
	var c := (mn + mx) * 0.5
	lake.position = Vector3(c.x, float(rep.nivel_agua_m), -c.y)
	add_child(lake)


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
			var sz: Array = pr.tamanho_m
			if _modelo_predio(root, pr, _centro_poi(poi)):
				built += 1
				if built % 8 == 0:
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
			if built % 8 == 0:
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
		if i % 16 == 0:
			Loading.set_progress("Colocando coberturas e pontos de referência...", 62.0 + 14.0 * float(i) / maxf(1.0, float(lista.size())))
			await get_tree().process_frame


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
	# mobília do pacote do usuário (maps/ilha/moveis.json, gerado por tools/interior.py): malha compartilhada + caixa de colisão
	Moveis.instalar(body, arq.get_file().get_basename())
	return true


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
		for i in pts.size():
			var p := Vector3(float(pts[i][0]), float(pts[i][2]) - 0.5, -float(pts[i][1]))
			var a := Vector3(float(pts[maxi(i - 1, 0)][0]), 0, -float(pts[maxi(i - 1, 0)][1]))
			var b := Vector3(float(pts[mini(i + 1, pts.size() - 1)][0]), 0, -float(pts[mini(i + 1, pts.size() - 1)][1]))
			var dir := (b - a).normalized()
			var lado := Vector3(-dir.z, 0, dir.x) * larg * 0.5
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
	mat_nuvem.set_shader_parameter("sol_dir", Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(-35), 0)).z)   # mesmo ângulo do sol
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
