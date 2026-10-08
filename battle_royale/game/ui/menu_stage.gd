class_name MenuStage
extends SubViewportContainer
## Cena 3D viva do menu (diorama da vila + soldado em idle) ou só o soldado com fundo transparente (inventário).
## Luz simples em tempo real, sem sombras nem bake.

## ÚNICO ponto de configuração do modelo do soldado: troque aqui para outro .glb.
const SOLDIER_PATHS: Array[String] = [
	"res://assets/models/characters/soldado.glb",
	"res://assets/models/characters/counter.glb",
]
const PREDIOS := "res://assets/models/predios/"
const VEG := "res://assets/models/veg/"

var viewport: SubViewport
var camera: Camera3D
var soldier: Node3D
var anim: AnimationPlayer
var world_root: Node3D
var with_world := true


## with_world = true: diorama completo. false: só o soldado com fundo transparente (vira retrato do inventário).
func _init(diorama := true, yaw_deg := -22.0, look_y := 1.15, dist := 4.4, fov := 30.0) -> void:
	with_world = diorama
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = not diorama
	viewport.msaa_3d = Viewport.MSAA_DISABLED if diorama else Viewport.MSAA_2X   # diorama: GT 730 não aguenta MSAA + capim a 60 FPS
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.size = Vector2i(1024, 768)
	add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	_build_light(diorama)
	if diorama:
		_build_diorama()
	_add_soldier(yaw_deg)
	camera = Camera3D.new()
	camera.fov = fov
	camera.near = 0.3
	camera.far = 600.0
	viewport.add_child(camera)
	var cam_y := look_y + 0.32 if diorama else look_y - 0.1   # diorama: um pouco acima, mostra o chão do acampamento
	camera.look_at_from_position(Vector3(0, cam_y, dist), Vector3(0, look_y, 0))
	camera.current = true


func set_soldier_yaw(deg: float) -> void:
	if soldier:
		soldier.rotation_degrees.y = deg


var _boneco: Node3D
var _cam_padrao := Transform3D()


## Criador de personagem: troca o soldado do menu pelo boneco montado (ou volta ao soldado com null).
func mostrar_boneco(n: Node3D) -> void:
	if _boneco and is_instance_valid(_boneco) and _boneco != n:
		_boneco.get_parent().remove_child(_boneco)
	_boneco = n
	if soldier:
		soldier.visible = n == null
	if n and n.get_parent() == null:
		world_root.add_child(n)


## Enquadra a câmera no boneco: alvo em (x, y, 0) a dist metros (x desloca o boneco para um lado da tela).
func enquadrar(x: float, look_y: float, dist: float) -> void:
	if _cam_padrao == Transform3D():
		_cam_padrao = camera.transform
	camera.look_at_from_position(Vector3(x, look_y + 0.05, dist), Vector3(x, look_y, 0))


func enquadrar_padrao() -> void:
	if _cam_padrao != Transform3D():
		camera.transform = _cam_padrao


func _build_light(diorama: bool) -> void:
	var env := Environment.new()
	if diorama:
		# fim de tarde: topo azul saturado (ref menu_low poly) descendo para um horizonte quente
		var sky := Sky.new()
		var psm := ProceduralSkyMaterial.new()
		psm.sky_top_color = Color(0.11, 0.36, 0.84)
		psm.sky_horizon_color = Color(0.74, 0.86, 0.97)
		psm.sky_curve = 0.22
		psm.ground_horizon_color = Color(0.74, 0.86, 0.97)
		psm.ground_bottom_color = Color(0.30, 0.42, 0.22)
		psm.sun_angle_max = 0.0
		sky.sky_material = psm
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.8
		# névoa só de distância: o acampamento fica limpo, morros e serra ganham a bruma quente do horizonte
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(0.72, 0.83, 0.94)
		env.fog_density = 0.75
		env.fog_depth_begin = 28.0
		env.fog_depth_end = 330.0
		env.fog_depth_curve = 1.6
		env.fog_sky_affect = 0.0
	else:
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.78, 0.82, 0.9)
		env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	# sol baixo atrás da câmera, à esquerda: luz dourada de lado no personagem e no acampamento
	sun.rotation_degrees = Vector3(-26, -36, 0) if diorama else Vector3(-38, -32, 0)
	sun.light_color = Color(1.0, 0.84, 0.64) if diorama else Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.35 if diorama else 1.25
	sun.shadow_enabled = false
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 150, 0)
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.light_energy = 0.4 if diorama else 0.35
	viewport.add_child(fill)


func _add_soldier(yaw_deg: float) -> void:
	# menu inicial: um sobrevivente aleatório do pack novo (dayone_base) a cada abertura
	if with_world and ResourceLoader.exists(CriadorPersonagem.MODELO):
		var d := {}
		for sl in CriadorPersonagem.SLOTS:
			var ops: Array = sl[2]
			d[sl[0]] = String(ops[randi() % ops.size()][0])
		var tons: Array = CriadorPersonagem.TONS
		d["pele_cor"] = (tons[randi() % tons.size()][1] as Color).to_html(false)
		soldier = CriadorPersonagem.boneco_jogo(d, true)
		if soldier:
			soldier.rotation_degrees.y = yaw_deg
			world_root.add_child(soldier)
			anim = _find_anim(soldier)
			return
	var path := ""
	for p in SOLDIER_PATHS:
		if ResourceLoader.exists(p):
			path = p
			break
	if path == "":
		return
	soldier = (load(path) as PackedScene).instantiate()
	soldier.rotation_degrees.y = yaw_deg
	world_root.add_child(soldier)
	anim = _find_anim(soldier)
	if anim:
		var clip := _clip(anim, "idle")
		if clip != "":
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(clip)
	if path.ends_with("counter.glb"):
		_camo_tint(soldier)


## Retoque provisório quando só existe o modelo antigo: tinge as malhas de verde camuflagem.
func _camo_tint(n: Node) -> void:
	if n is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.36, 0.42, 0.26)
		(n as MeshInstance3D).material_overlay = null
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		_camo_tint(c)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _clip(ap: AnimationPlayer, name: String) -> String:
	for lib in ap.get_animation_library_list():
		var full := (String(lib) + "/" + name) if String(lib) != "" else name
		if ap.has_animation(full):
			return full
	return ""


# --------------------------------------------------------------------------- diorama
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _box(pos: Vector3, size: Vector3, c: Color, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees.y = yaw
	world_root.add_child(mi)
	return mi


func _place(dir: String, file: String, pos: Vector3, yaw := 0.0, scale := 1.0, copa := "") -> Node3D:
	var path := dir + file + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * scale
	if dir == MUNDO:
		_materiais_mundo(n)
	if copa != "":
		_copa_outono(n, copa)
	world_root.add_child(n)
	return n


# --------------------------------------------------------------------------- acampamento do sobrevivente
## Cena composta à mão (nada aleatório). O personagem fica na origem olhando para a câmera (+Z); o painel do menu cobre
## o terço esquerdo da tela e o de equipamento o terço direito, então cada plano tem algo legível nas duas frestas
## ao lado do personagem e na faixa de baixo:
##   1º plano (z 3 .. -3): capim denso e alto nos cantos, galão e pedras;
##   2º plano (z -3 .. -16): fogueira com tronco de assento, barraca e caixas à esquerda; caminhonete apocalíptica,
##       barris, pneus, galões, gerador e placa à direita; cerca de tábuas fechando o acampamento;
##   3º plano (z -18 .. -230): árvores com copas de outono, lago, morros com mata e serra azulada na bruma.
const MUNDO := "res://assets/models/atualizacao/mundo/"
const NAT := "res://assets/models/cenario/natureza/"
const CARRO := Vector2(2.5, -11.6)
const CARRO_YAW := -30.0
const LAGO := Vector2(3.0, -27.5)
const LAGO_R := Vector2(16.0, 6.0)
const COR_COPA := {"laranja": Color("EE8420"), "amarela": Color("F2C230"), "vermelha": Color("C8402A")}

## [pasta, arquivo, x, z, yaw, escala, copa]
const CENA := [
	# 2º plano esquerdo: fogueira e acampamento
	["N", "fogueira", -2.3, -4.6, 0.0, 1.0, ""],
	["N", "lenha", -3.15, -4.0, 40.0, 1.0, ""],
	["N", "tronco_caido", -3.9, -5.6, 62.0, 0.55, ""],
	["M", "Gas_Burner", -1.55, -3.9, 10.0, 1.0, ""],
	["M", "Tent_002", -8.6, -13.0, 28.0, 0.75, ""],
	["M", "Box_022", -4.9, -9.2, 18.0, 0.8, ""],
	["M", "Box_003", -4.2, -8.0, -12.0, 0.8, ""],
	["M", "Box_005", -4.75, -9.15, 30.0, 0.7, ""],
	["M", "Table_002", -6.4, -7.4, 75.0, 0.85, ""],
	["M", "Barbecue_Grill", -1.2, -6.6, 0.0, 1.0, ""],
	["N", "pilha_troncos", -9.0, -8.0, 80.0, 0.6, ""],
	# 2º plano direito: caminhonete e sucata
	["M", "Apocalypse_Car", CARRO.x, CARRO.y, CARRO_YAW, 1.0, ""],
	["M", "Barrel_005", 5.9, -7.0, 0.0, 1.0, ""],
	["M", "Barrel_005", 6.6, -7.45, 40.0, 1.0, ""],
	["M", "Barrel_005", 6.2, -8.1, 75.0, 1.0, ""],
	["M", "Fuel_Canister", 5.2, -6.5, 25.0, 1.0, ""],
	["M", "Fuel_Canister", 4.9, -6.9, -40.0, 1.0, ""],
	["M", "Tires_001", 7.6, -9.4, 0.0, 1.0, ""],
	["M", "Tire_001", 5.6, -6.6, 20.0, 1.0, ""],
	["M", "Generator_004", 7.6, -12.8, -70.0, 0.75, ""],
	["M", "Signs_Shield", 9.3, -9.8, -20.0, 1.0, ""],
	["M", "Road_Barrier_01", 6.2, -15.0, -8.0, 1.0, ""],
	["M", "Protection_001", -0.6, -15.0, 0.0, 1.0, ""],
	["M", "Protection_001", 0.45, -15.05, 0.0, 1.0, ""],
	# atmosfera de apocalipse: carro abandonado na beira do lago, barricada, ouriços, entulho e muro em ruína
	["M", "Apocalypse_Car", -9.5, -21.5, 112.0, 1.0, ""],
	["M", "Hedgehog_001", 12.0, -12.5, 20.0, 0.8, ""],
	["M", "Hedgehog_001", 13.6, -14.4, 60.0, 0.8, ""],
	["M", "Barrier_007", -12.5, -11.0, 70.0, 0.8, ""],
	["M", "Concrete_Fence", 18.0, -17.0, -8.0, 1.0, ""],
	["N", "entulho", 9.6, -15.0, 20.0, 0.9, ""],
	["N", "muro_ruina", -19.0, -15.5, 8.0, 0.9, ""],
	["M", "Katana", -3.35, -3.15, 15.0, 1.0, ""],
	["M", "First_Aid", 1.3, -6.2, 30.0, 1.0, ""],
	["M", "Pistol1_Base", -6.35, -7.25, 75.0, 1.0, ""],
	["M", "Map", -6.5, -7.6, 75.0, 0.8, ""],
	["M", "Walkie_talkie", -6.2, -7.05, 30.0, 1.0, ""],
	["M", "Barrier_009", 0.9, -9.3, 15.0, 1.0, ""],
	# 1º plano
	["M", "Fuel_Canister", 1.75, 0.9, -30.0, 1.0, ""],
	["N", "rocha_media", -2.1, 0.4, 30.0, 0.8, ""],
	["N", "pedrisco_a", 1.4, 1.9, 0.0, 1.0, ""],
	["N", "pedrisco_b", -1.2, 1.6, 60.0, 1.0, ""],
	["N", "samambaia_b", -3.2, -1.4, 0.0, 1.0, ""],
	["N", "arbusto_b", 3.6, -2.6, 30.0, 0.9, ""],
	# cerca e borda do acampamento
	["N", "cerca_madeira", -11.0, -16.4, 4.0, 1.0, ""],
	["N", "cerca_madeira", -6.5, -16.6, -2.0, 1.0, ""],
	["N", "cerca_madeira", -2.0, -16.5, 3.0, 1.0, ""],
	["N", "cerca_madeira", 9.5, -16.8, -4.0, 1.0, ""],
	["N", "cerca_madeira", 14.0, -16.4, 6.0, 1.0, ""],
	["N", "cerca_madeira_curta", 4.6, -16.6, 10.0, 1.0, ""],
	["N", "arbusto_a", -13.5, -15.0, 0.0, 1.2, ""],
	["N", "arbusto_a", 11.8, -14.6, 40.0, 1.1, ""],
	["N", "arbusto_b", 2.6, -16.0, 0.0, 1.2, ""],
	["N", "toco", -5.8, -3.2, 0.0, 0.7, ""],
	# 3º plano: árvores emoldurando as laterais (copas de outono misturadas às verdes); o centro fica aberto para a vista
	["N", "carvalho", -12.5, -21.0, 20.0, 1.0, "laranja"],
	["N", "pinheiro_medio", -16.5, -24.0, 0.0, 1.15, ""],
	["N", "pinheiro", -21.0, -27.0, 0.0, 1.0, ""],
	["N", "arvore_d", -26.0, -20.0, 0.0, 1.1, "amarela"],
	["N", "carvalho", -33.0, -27.0, 0.0, 1.2, "vermelha"],
	["N", "betula", -14.5, -27.0, 0.0, 0.9, ""],
	["N", "arvore_d", 12.5, -22.0, 60.0, 1.0, "amarela"],
	["N", "pinheiro_medio", 16.5, -19.5, 0.0, 1.1, ""],
	["N", "carvalho", 22.0, -27.0, 200.0, 1.1, ""],
	["N", "pinheiro_medio", 27.0, -18.0, 30.0, 1.2, ""],
	["N", "arvore_b", 18.0, -31.0, 140.0, 1.2, "vermelha"],
	["N", "betula_jovem", 9.0, -18.5, 0.0, 1.1, ""],
	["N", "rocha_grande", 13.5, -17.6, 30.0, 0.9, ""],
	["N", "tronco_caido", -16.0, -18.0, 20.0, 0.8, ""],
	["N", "rocha_media", 6.5, -29.0, 0.0, 1.2, ""],
	["N", "arbusto_a", -4.0, -35.5, 0.0, 1.4, ""],
	["N", "arbusto_b", 10.5, -35.2, 0.0, 1.6, ""],
	["N", "tufo_capim", -11.0, -23.0, 0.0, 1.4, ""],
	["N", "tufo_capim", 15.0, -25.0, 0.0, 1.4, ""],
]

## Árvores dos morros (MultiMesh por malha): [arquivo, x, z, escala, copa]
const MORRO := [
	["pinheiro_medio", -40.0, -58.0, 1.6, ""], ["pinheiro_medio", -33.0, -62.0, 1.8, ""], ["carvalho", -24.0, -56.0, 1.3, "laranja"],
	["pinheiro_medio", -14.0, -64.0, 1.7, ""], ["arvore_d", -6.0, -59.0, 1.5, "amarela"], ["pinheiro_medio", 3.0, -66.0, 1.9, ""],
	["carvalho", 12.0, -60.0, 1.4, ""], ["pinheiro_medio", 21.0, -63.0, 1.7, ""], ["arvore_d", 30.0, -57.0, 1.5, "laranja"],
	["pinheiro_medio", 40.0, -61.0, 1.8, ""], ["pinheiro_medio", 50.0, -54.0, 1.6, ""], ["carvalho", -52.0, -52.0, 1.4, "vermelha"],
	["pinheiro_medio", -60.0, -70.0, 2.0, ""], ["pinheiro_medio", 62.0, -72.0, 2.0, ""], ["pinheiro_medio", -20.0, -76.0, 2.1, ""],
	["pinheiro_medio", 17.0, -78.0, 2.1, ""], ["carvalho", 0.0, -74.0, 1.6, "amarela"], ["pinheiro_medio", 35.0, -80.0, 2.0, ""],
	["pinheiro_medio", -45.0, -82.0, 2.2, ""], ["arvore_d", 46.0, -68.0, 1.6, ""], ["pinheiro_medio", -8.0, -84.0, 2.2, ""],
	["carvalho", 25.0, -70.0, 1.5, ""], ["arvore_d", -30.0, -70.0, 1.6, "laranja"], ["pinheiro_medio", 8.0, -56.0, 1.5, ""],
]

## Serra ao fundo: [x, z, altura, raio]
const SERRA := [
	[-230.0, -235.0, 70.0, 75.0], [-150.0, -250.0, 92.0, 85.0], [-80.0, -228.0, 60.0, 60.0], [-20.0, -260.0, 105.0, 95.0],
	[45.0, -232.0, 66.0, 62.0], [110.0, -255.0, 96.0, 88.0], [185.0, -238.0, 74.0, 72.0], [260.0, -250.0, 88.0, 80.0],
	[-115.0, -205.0, 38.0, 45.0], [80.0, -205.0, 42.0, 48.0], [5.0, -210.0, 34.0, 44.0],
]

var _fogo: Array[Node3D] = []
var _luz_fogo: OmniLight3D
var _t := 0.0
var _carro: Node3D
var _fumaca: Array[MeshInstance3D] = []
var _base_fogo := Vector3.ZERO


func _build_diorama() -> void:
	var sem := OS.get_environment("MENU_SEM").split(",")   # diagnóstico de custo (tests/menu_fundo.gd)
	if "chao" not in sem:
		_chao()
	if "serra" not in sem:
		_serra()
	_agua()
	_terra_batida()
	if "msaa" in sem:
		viewport.msaa_3d = Viewport.MSAA_DISABLED
	if "tudo" in sem:
		return
	for p in (CENA if "cena" not in sem else []):
		var n := _place(MUNDO if p[0] == "M" else NAT, p[1], Vector3(p[2], 0.0, p[3]), p[4], p[5], p[6])
		if n and String(p[1]) in ["Pistol1_Base", "Map", "Walkie_talkie"]:
			n.position.y = 0.79   # em cima da mesa
		if n and p[1] == "Apocalypse_Car" and _carro == null:
			_carro = n
		if n and p[1] == "Katana":
			n.rotation_degrees.x = 168.0   # espetada no chão ao lado da fogueira
			n.position.y = 0.86
	_sangue()
	_cachorro(Vector3(-1.1, 0.0, -1.2), 25.0)
	if "morro" not in sem:
		_arvores_morro()
	if "capim" not in sem:
		_capim()
	_fogueira_viva(Vector3(-2.3, 0.0, -4.6))
	_nuvens()


func _process(dt: float) -> void:
	var esc := clampf(get_global_transform_with_canvas().get_scale().y, 0.5, 1.0)
	if not is_equal_approx(viewport.scaling_3d_scale, esc):
		viewport.scaling_3d_scale = esc
	if _fogo.is_empty():
		return
	_t += dt
	for i in _fogo.size():
		var f := _fogo[i]
		var k := 1.0 + 0.16 * sin(_t * (9.0 + i * 3.1)) + 0.09 * sin(_t * (23.0 + i * 5.7))
		f.scale = Vector3(1.0 + 0.06 * sin(_t * 13.0 + i), k, 1.0 + 0.06 * cos(_t * 11.0 + i))
	for k in _fumaca.size():
		var ph := fmod(_t * 0.28 + k / float(_fumaca.size()), 1.0)
		_fumaca[k].position = _base_fogo + Vector3(sin(ph * 5.0 + k) * 0.15 + ph * 0.5, 0.6 + ph * 3.2, -ph * 0.3)
		_fumaca[k].scale = Vector3.ONE * (0.5 + ph * 2.2) * (1.0 - ph * ph)
	if _luz_fogo:
		_luz_fogo.light_energy = 1.6 + 0.35 * sin(_t * 17.0) + 0.2 * sin(_t * 29.0)


# ---- terreno: chão plano no acampamento, lago atrás da cerca, morros e laterais subindo (low poly facetado)
static func _altura(x: float, z: float) -> float:
	var h := 0.0
	var dl := Vector2((x - LAGO.x) / LAGO_R.x, (z - LAGO.y) / LAGO_R.y).length()
	if dl < 1.0:
		h = -1.3 * (1.0 - dl * dl)
	var t := clampf((-z - 44.0) / 40.0, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	h += t * (4.5 + 3.0 * sin(x * 0.045 + 1.0) + 2.0 * sin(x * 0.11 + z * 0.05) + 1.5 * sin(z * 0.09))
	var s := clampf((absf(x) - 34.0) / 44.0, 0.0, 1.0)
	h += s * s * 12.0 * (0.7 + 0.3 * sin(z * 0.07 + x * 0.02))
	return h


static func _h(a: int, b: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7FFFFFFF


static func _r(a: int, b: int, k := 0) -> float:
	return float((_h(a * 7 + k * 101, b * 13 - k * 57) >> 5) & 1023) / 1023.0


func _mat_vc() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _chao() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: Array[float] = []
	var zs: Array[float] = []
	var x := -180.0
	while x < 180.0:
		xs.append(x)
		x += 2.0 if absf(x) < 40.0 else 7.0
	xs.append(180.0)
	var z := -130.0
	while z < 14.0:
		zs.append(z)
		z += 2.0 if z > -50.0 else 6.0
	zs.append(14.0)
	for iz in zs.size() - 1:
		for ix in xs.size() - 1:
			var xa := xs[ix]
			var za := zs[iz]
			var xb := xs[ix + 1]
			var zb := zs[iz + 1]
			var v := [Vector3(xa, 0, za), Vector3(xb, 0, za), Vector3(xa, 0, zb), Vector3(xb, 0, zb)]
			for q in 4:
				v[q].y = _altura(v[q].x, v[q].z)
			for tri in [[0, 1, 2], [1, 3, 2]]:
				var a: Vector3 = v[tri[0]]
				var b: Vector3 = v[tri[1]]
				var c: Vector3 = v[tri[2]]
				var hm := (a.y + b.y + c.y) / 3.0
				var rr := _r(ix, iz, tri[0])
				var cor := Color(0.40, 0.60, 0.20).lerp(Color(0.47, 0.66, 0.22), rr)
				if hm < -0.25:
					cor = Color(0.55, 0.50, 0.34)
				elif hm > 1.5:
					cor = Color(0.36, 0.55, 0.19).lerp(Color(0.52, 0.60, 0.24), rr * rr * rr)
				st.set_color(cor)
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat_vc()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mi)


func _serra() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lados := 7
	for i in SERRA.size():
		var p: Array = SERRA[i]
		var topo := Vector3(p[0], p[2], p[1])
		var base: Array[Vector3] = []
		for k in lados:
			var a := TAU * k / lados + i * 0.7
			var r: float = p[3] * (0.8 + 0.4 * _r(i, k, 3))
			base.append(Vector3(p[0] + cos(a) * r, -2.0, p[1] + sin(a) * r * 0.6))
		# ombro intermediário: quebra o cone em facetas de serra low poly
		var meio: Array[Vector3] = []
		for k in lados:
			var m := topo.lerp(base[k], 0.45 + 0.15 * _r(i, k, 5))
			m.y += p[2] * 0.06 * (_r(i, k, 7) - 0.3)
			meio.append(m)
		for k in lados:
			var k2 := (k + 1) % lados
			var c1 := Color(0.40, 0.50, 0.66).lerp(Color(0.48, 0.56, 0.70), _r(i, k, 9))
			var c2 := Color(0.32, 0.46, 0.50).lerp(Color(0.38, 0.52, 0.52), _r(i, k, 11))
			st.set_color(c1)
			st.add_vertex(topo)
			st.add_vertex(meio[k2])
			st.add_vertex(meio[k])
			st.set_color(c2)
			st.add_vertex(meio[k])
			st.add_vertex(meio[k2])
			st.add_vertex(base[k])
			st.add_vertex(meio[k2])
			st.add_vertex(base[k2])
			st.add_vertex(base[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat_vc()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mi)


func _agua() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(LAGO_R.x * 2.2, LAGO_R.y * 2.4)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.52, 0.72)
	m.roughness = 0.08
	m.metallic = 0.35
	m.metallic_specular = 0.8
	mi.material_override = m
	mi.position = Vector3(LAGO.x, -0.3, LAGO.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mi)


## Terra batida: roda da fogueira e trilha de pneu até a caminhonete (polígonos planos rente ao chão).
func _terra_batida() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_disco(st, Vector2(-2.3, -4.6), 1.9, 1.5, 11, Color(0.52, 0.40, 0.25))
	_disco(st, Vector2(-5.2, -8.6), 1.6, 1.2, 9, Color(0.50, 0.40, 0.27))
	for i in 9:
		var t := float(i) / 8.0
		var c := Vector2(2.6, -6.0).lerp(Vector2(9.0, -24.0), t) + Vector2(sin(t * 5.0) * 0.8, 0)
		_disco(st, c, 1.5, 1.0, 8, Color(0.53, 0.42, 0.27).lerp(Color(0.48, 0.40, 0.26), t))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _mat_vc()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mi)


func _disco(st: SurfaceTool, c: Vector2, rx: float, rz: float, n: int, cor: Color) -> void:
	var y := 0.012 + c.length() * 0.0002
	for k in n:
		var a1 := TAU * k / n
		var a2 := TAU * (k + 1) / n
		var f1 := 0.82 + 0.3 * _r(int(c.x * 10), k, 1)
		var f2 := 0.82 + 0.3 * _r(int(c.x * 10), (k + 1) % n, 1)
		st.set_color(cor)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(c.x, y, c.y))
		st.add_vertex(Vector3(c.x + cos(a2) * rx * f2, y, c.y + sin(a2) * rz * f2))
		st.add_vertex(Vector3(c.x + cos(a1) * rx * f1, y, c.y + sin(a1) * rz * f1))


## Capim denso do jogo (IlhaGrama._tufo + shaders/grama.gdshader) num único MultiMesh: mais fechado e alto perto da
## câmera, ralo ao longe; fora da terra batida, das caixas/barraca/caminhonete; baixo nos pés do personagem.
func _capim() -> void:
	var xfs: Array[Transform3D] = []
	var z := 3.6
	var iz := 0
	while z > -17.0:
		var passo := 0.23 if z > -3.0 else (0.32 if z > -10.0 else 0.46)
		var meia := (4.8 - z) * 0.56 + 1.0
		var x := -meia
		var ix := 0
		while x < meia:
			var hx := _r(ix, iz, 1)
			var hz := _r(ix, iz, 2)
			var px := x + (hx - 0.5) * passo * 1.6
			var pz := z + (hz - 0.5) * passo * 1.6
			x += passo
			ix += 1
			var esc := _escala_capim(px, pz, _r(ix, iz, 3))
			if esc <= 0.0:
				continue
			var rot := _r(ix, iz, 4) * TAU
			var alt := 0.8 + 0.45 * _r(ix, iz, 5)
			xfs.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(esc, esc * alt, esc)), Vector3(px, -0.02, pz)))
		z -= passo
		iz += 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tufo()
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grama.gdshader")
	mat.set_shader_parameter("alcance", 90.0)
	mat.set_shader_parameter("cor_base", Color(0.19, 0.34, 0.10))
	mat.set_shader_parameter("cor_ponta", Color(0.62, 0.80, 0.28))
	mat.set_shader_parameter("vento", 0.09)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mmi)
	n_capim = xfs.size()


var n_capim := 0


func _escala_capim(x: float, z: float, r: float) -> float:
	var p := Vector2(x, z)
	# terra batida da fogueira e área das caixas
	if p.distance_to(Vector2(-2.3, -4.6)) < 1.7 or Vector2((x + 5.2) / 1.5, (z + 8.6) / 1.1).length() < 1.0:
		return 0.0
	# trilha da caminhonete
	for i in 9:
		var t := float(i) / 8.0
		var c := Vector2(2.6, -6.0).lerp(Vector2(9.0, -24.0), t) + Vector2(sin(t * 5.0) * 0.8, 0)
		if Vector2((x - c.x) / 1.3, (z - c.y) / 0.9).length() < 1.0:
			return 0.0 if r < 0.85 else 0.45
	# pegada da caminhonete, barraca, mesa e gerador
	var dc := (p - CARRO).rotated(deg_to_rad(CARRO_YAW))
	if absf(dc.x) < 1.4 and absf(dc.y) < 3.0:
		return 0.0
	var dt := (p - Vector2(-8.6, -13.0)).rotated(deg_to_rad(28.0))
	if absf(dt.x) < 2.6 and absf(dt.y) < 3.5:
		return 0.0
	if _altura(x, z) < -0.05:
		return 0.0
	for b in SANGUE:
		if p.distance_to(Vector2(b[0], b[1])) < float(b[2]) * 0.42:
			return 0.0
	var base := 0.5 + 0.28 * r
	if p.distance_to(Vector2(-1.05, -1.35)) < 0.75:   # cachorro deitado
		return base * 0.35
	# pés do personagem: capim baixo para não esconder o calçado
	if p.length() < 0.75:
		return base * 0.6
	# 1º plano: cantos altos e fechados (moldura de capim como na referência), centro baixo para não tapar o personagem
	if z > 0.3:
		var borda := clampf((absf(x) - 1.1) / 1.2, 0.0, 1.0)
		return base * (0.7 + 0.7 * borda * borda) * (0.75 if z > 2.0 else 1.0)
	return base


## Árvores dos morros em MultiMesh (uma por malha de cada modelo), presas na altura do terreno.
func _arvores_morro() -> void:
	var grupos := {}
	for a in MORRO:
		var k: String = a[0] + "|" + a[4]
		if not grupos.has(k):
			grupos[k] = []
		var x: float = a[1]
		var z: float = a[2]
		grupos[k].append(Transform3D(Basis(Vector3.UP, _r(int(x), int(z)) * TAU).scaled(Vector3.ONE * float(a[3]) * 0.75),
			Vector3(x, _altura(x, z) - 0.3, z)))  # escala x0,75 abaixo
	for k in grupos:
		var partes := String(k).split("|")
		var path := NAT + partes[0] + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var raiz := (load(path) as PackedScene).instantiate() as Node3D
		if partes[1] != "":
			_copa_outono(raiz, partes[1])
		for mi in raiz.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			var local := _rel(raiz, m3)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m3.mesh
			var lista: Array = grupos[k]
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, (lista[i] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = m3.material_override
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world_root.add_child(mmi)
		raiz.free()


func _rel(raiz: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D()
	var c: Node = n
	while c and c != raiz:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## Fogueira acesa: duas chamas low poly (cones sem luz) que tremulam + luz laranja curta.
func _fogueira_viva(p: Vector3) -> void:
	var cores := [Color(1.0, 0.45, 0.08), Color(1.0, 0.78, 0.2), Color(1.0, 0.55, 0.1)]
	var forma := [[0.0, 0.0, 0.13, 0.46], [0.07, 0.04, 0.08, 0.32], [-0.08, -0.05, 0.07, 0.28]]
	for i in 3:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = forma[i][2]
		cm.height = forma[i][3]
		cm.radial_segments = 5
		cm.rings = 1
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = cores[i]
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var piv := Node3D.new()
		piv.position = p + Vector3(forma[i][0], 0.18, forma[i][1])
		mi.position = Vector3(0, forma[i][3] * 0.5, 0)
		piv.add_child(mi)
		world_root.add_child(piv)
		_fogo.append(piv)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.6, 0.58)
	fm.roughness = 1.0
	var esf := SphereMesh.new()
	esf.radial_segments = 6
	esf.rings = 3
	esf.radius = 0.16
	esf.height = 0.3
	for k in 0:   # fumaça desligada (bolas cinza destoavam na captura v3)
		var fu := MeshInstance3D.new()
		fu.mesh = esf
		fu.material_override = fm
		fu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(fu)
		_fumaca.append(fu)
	_base_fogo = p
	_luz_fogo = OmniLight3D.new()
	_luz_fogo.light_color = Color(1.0, 0.55, 0.2)
	_luz_fogo.omni_range = 4.5
	_luz_fogo.light_energy = 1.6
	_luz_fogo.shadow_enabled = false
	_luz_fogo.position = p + Vector3(0, 0.7, 0)
	world_root.add_child(_luz_fogo)


## Nuvens low poly (esferas achatadas de poucas faces, sem névoa) espalhadas acima da serra.
func _nuvens() -> void:
	var sm := SphereMesh.new()
	sm.radial_segments = 7
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.96, 0.9)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.5, 0.45)
	m.roughness = 1.0
	m.disable_fog = true
	sm.material = m
	var grupos := [[-150.0, 70.0, -320.0], [-40.0, 95.0, -360.0], [70.0, 78.0, -330.0], [170.0, 100.0, -380.0], [-230.0, 110.0, -400.0]]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = grupos.size() * 4
	var i := 0
	for g in grupos:
		for k in 4:
			var r := 9.0 + 7.0 * _r(int(g[0]), k, 2)
			var off := Vector3((k - 1.5) * 13.0, (_r(int(g[0]), k, 4) - 0.3) * 6.0, _r(int(g[0]), k, 6) * 8.0)
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r * 1.7, r * 0.75, r)), Vector3(g[0], g[1], g[2]) + off))
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mmi)


## Pack 'atualizacao/mundo': glb sem imagem; cada superfície recebe o material do slot (mesma tabela do mapa).
## mesma tabela de maps/ilha/detalhes.gd (cópia local: o menu não depende do script do mapa)
const TEX_MUNDO := {"mil_paleta": "mundo/tex/Textures1.png", "mil_camo1": "mundo/tex/Camouflage_1.png",
	"mil_camo2": "mundo/tex/Camouflage_2.png", "apo_paleta": "mundo/tex/Color2.png", "apo_painel": "mundo/tex/Dashboard.png",
	"apo_mapa": "mundo/tex/Map.png", "apo_placas": "mundo/tex/RoadSigns.png", "apo_numeros": "mundo/tex/Car_Numbers.png",
	"int_paleta": "interiores/Textures_4.png"}
static var _mat_mundo := {}


func _materiais_mundo(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var m0 := m3.mesh.surface_get_material(i)
			var nome := m0.resource_name if m0 else "mil_paleta"
			if not TEX_MUNDO.has(nome):
				continue
			if not _mat_mundo.has(nome):
				var m := StandardMaterial3D.new()
				m.albedo_texture = load("res://assets/models/atualizacao/" + String(TEX_MUNDO[nome]))
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if nome.ends_with("paleta") else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				m.roughness = 0.9
				m.metallic_specular = 0.25
				_mat_mundo[nome] = m
			m3.set_surface_override_material(i, _mat_mundo[nome])


static var _mat_copa := {}


func _copa_outono(no: Node, cor: String) -> void:
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


## Sangue: manchas planas recortadas da máscara do pack (blood_mask.png, alpha scissor = passe opaco, barato no GT 730).
## [x, z, tamanho, yaw, região uv (x, y, w, h)]
const SANGUE := [
	[0.9, -5.6, 1.2, 20.0, [0.15, 0.13, 0.17, 0.18]],
	[-1.4, -6.0, 1.0, 70.0, [0.22, 0.62, 0.13, 0.11]],
	[-1.5, -4.0, 0.8, 10.0, [0.41, 0.46, 0.1, 0.09]],
	[3.6, -7.6, 1.4, 40.0, [0.15, 0.13, 0.17, 0.18]],
	[-8.6, -19.6, 1.8, 120.0, [0.22, 0.62, 0.13, 0.11]],
	[1.6, -8.6, 1.1, 10.0, [0.2, 0.29, 0.12, 0.1]],
]


func _sangue() -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
uniform sampler2D mascara : filter_linear_mipmap, hint_default_black;
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	float m = texture(mascara, regiao.xy + UV * regiao.zw).r;
	ALBEDO = vec3(0.55, 0.04, 0.04);
	EMISSION = vec3(0.12, 0.0, 0.0);
	ROUGHNESS = 1.0;
	ALPHA = m;
	ALPHA_SCISSOR_THRESHOLD = 0.3;
}
"""
	var tex: Texture2D = load("res://assets/models/atualizacao/menu/blood_mask.png")
	for i in SANGUE.size():
		var b: Array = SANGUE[i]
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("mascara", tex)
		var rg: Array = b[4]
		sm.set_shader_parameter("regiao", Vector4(rg[0], rg[1], rg[2], rg[3]))
		var pm := PlaneMesh.new()
		pm.size = Vector2(b[2], b[2])
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(b[0], 0.03 + i * 0.002, b[1])
		mi.rotation_degrees.y = b[3]
		world_root.add_child(mi)
	# mancha no capô da caminhonete: topo da malha na faixa do capô (frente = +Z local do glb)
	if _carro:
		var topo := -1.0
		for m3 in _carro.find_children("*", "MeshInstance3D", true, false):
			var xf := _rel(_carro, m3 as Node3D)
			for si in (m3 as MeshInstance3D).mesh.get_surface_count():
				for v in ((m3 as MeshInstance3D).mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					var w := xf * v
					if w.z > 1.5 and w.z < 2.3 and absf(w.x) < 0.5:
						topo = maxf(topo, w.y)
		if topo > 0.3:
			var sm := ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("mascara", tex)
			sm.set_shader_parameter("regiao", Vector4(0.15, 0.13, 0.17, 0.18))
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.1, 1.0)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0.0, topo + 0.02, 1.9)
			_carro.add_child(mi)
			# respingo na grade/para-choque (de frente para a câmera)
			var mf := mi.duplicate() as MeshInstance3D
			var sm2 := sm.duplicate() as ShaderMaterial
			sm2.set_shader_parameter("regiao", Vector4(0.2, 0.29, 0.12, 0.1))
			mf.material_override = sm2
			mf.mesh = pm.duplicate()
			(mf.mesh as PlaneMesh).size = Vector2(0.9, 0.6)
			mf.rotation_degrees.x = 90.0
			mf.position = Vector3(0.35, 0.8, 2.97)
			_carro.add_child(mf)


## Doberman do pack apocalipse (Doberman.fbx, rigado): deitado ao lado do personagem, com respiração em loop.
func _cachorro(pos: Vector3, yaw: float) -> void:
	var path := "res://assets/models/atualizacao/menu/Doberman.fbx"
	if not ResourceLoader.exists(path):
		return
	var d := (load(path) as PackedScene).instantiate() as Node3D
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/models/atualizacao/mundo/tex/Color2.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.9
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			(mi as MeshInstance3D).set_surface_override_material(i, m)
	d.position = pos
	d.rotation_degrees.y = yaw
	world_root.add_child(d)
	var ap := _find_anim(d)
	if ap:
		for nome in ["Doberman_Idle", "Doberman_Lie"]:
			if ap.has_animation(nome):
				ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
				ap.play(nome)
				break


## Cópia de IlhaGrama._tufo (maps/ilha/grama.gd): o menu não depende do script do mapa.
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
