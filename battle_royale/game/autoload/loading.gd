extends CanvasLayer
## Sobreposição persistente de carregamento (DAYONE). Permanece visível durante trocas de cena e preparação do mapa.
## Também faz o AQUECIMENTO: enquanto o jogador monta o personagem no menu, carrega em thread os recursos que a
## partida usa (ilha, prédios, móveis, props, armas, shaders) e renderiza 1 cópia de cada material real numa
## SubViewport oculta, para o driver compilar os shaders antes do clique em JOGAR. Os recursos ficam presos em
## _cache: o load() da partida pega a MESMA instância (mesmos materiais = shaders já compilados).

signal aquecimento_feito

const LISTA_AQUECIMENTO := "res://autoload/aquecimento.json"
## Sempre aquecidos, além da lista gravada (tests/menu_fluxo.tscn --gravar=1).
const PASTAS_SEMPRE := ["res://assets/models/weapons/", "res://assets/models/fp/", "res://shaders/"]
const POR_QUADRO := 1            # instâncias postas na frente da câmera por quadro (1: o menu/criador não pode travar)
const QUADROS_POR_LOTE := 2      # quadros renderizados por lote antes de liberar

var _root: Control
var _status: Label
var _bar: ProgressBar
var _percent: Label
var _hide_frames := 0
var etapas: Array = []           # [ms desde o início do carregamento, texto] (medição)
var _t_etapa0 := 0

# ---- aquecimento
var aquecendo := false
var aquecido := false
var aquecimento_ms := -1
var _t_aq0 := 0
var _pendentes: Array[String] = []   # pedidos de thread ainda não concluídos
var _fila_render: Array = []          # recursos prontos esperando render
var _total := 0
var _prontos := 0
var _cache := {}                      # path -> Resource (mantém vivo no cache do ResourceLoader)
var _vp: SubViewport
var _vp_env: Environment
var _vp_raiz: Node3D
var _lote: Array[Node] = []
var _lote_quadros := 0
var _fim_render_quadros := 0


func _ready() -> void:
	layer = 120
	# início do quadro para o orçamento da montagem: este handler é o 1º ligado ao sinal, roda antes das corrotinas
	get_tree().process_frame.connect(func() -> void: _t_ini_quadro = Time.get_ticks_usec())
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "LoadingOverlay"
	_root.visible = false
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("111A20")
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.anchor_left = 0.5
	stack.anchor_top = 0.5
	stack.anchor_right = 0.5
	stack.anchor_bottom = 0.5
	stack.offset_left = -260
	stack.offset_top = -110
	stack.offset_right = 260
	stack.offset_bottom = 110
	stack.add_theme_constant_override("separation", 12)
	_root.add_child(stack)
	var logo := Label.new()
	logo.text = "DAYONE"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_override("font", UIStyle.font(700, "title"))
	logo.add_theme_font_size_override("font_size", 54)
	logo.add_theme_color_override("font_color", Color("F2C230"))
	stack.add_child(logo)
	var title := Label.new()
	title.text = "PREPARANDO A ILHA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("F4EBDD"))
	stack.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color("B8C0BF"))
	stack.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(520, 16)
	_bar.show_percentage = false
	_bar.max_value = 100
	stack.add_child(_bar)
	_percent = Label.new()
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.add_theme_font_size_override("font_size", 13)
	_percent.add_theme_color_override("font_color", Color("D2A66E"))
	stack.add_child(_percent)


func _process(_delta: float) -> void:
	var agora := Time.get_ticks_usec()
	if pre_estado == "montando" or pre_estado == "compilando":
		var dq := (agora - _t_quadro) / 1000.0
		if dq > 100.0 and pre_lentos.size() < 400:
			pre_lentos.append([snappedf(dq, 0.1), pre_estado, snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1), pre_passo, snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1), snappedf(RenderingServer.get_frame_setup_time_cpu(), 0.1), get_tree().get_node_count()])
		var ch := pre_passo.split(" ")[0]
		var e: Array = pre_por_passo.get(ch, [0, 0.0, 0.0, 0, 0])
		e[0] += 1
		e[1] += dq
		e[2] = maxf(e[2], dq)
		e[3] += 1 if dq > 50.0 else 0
		e[4] += 1 if dq > 100.0 else 0
		pre_por_passo[ch] = e
	_dt_ultimo = (agora - _t_quadro) / 1000.0
	_t_quadro = agora
	if _hide_frames > 0:
		_hide_frames -= 1
		if _hide_frames == 0 and is_instance_valid(_root):
			_root.visible = false
			_registrar("[controle]")
	if aquecendo:
		_passo_aquecimento()


func show_progress(status: String, progress: float = 0.0) -> void:
	if silencioso:
		_pre_status(status, progress)
		return
	if not _root.visible:
		etapas.clear()
		_t_etapa0 = Time.get_ticks_msec()
	_root.visible = true
	set_progress(status, progress)


func set_progress(status: String, progress: float) -> void:
	if not is_instance_valid(_root):
		return
	if silencioso:
		_pre_status(status, progress)
		return
	if not _root.visible:
		etapas.clear()
		_t_etapa0 = Time.get_ticks_msec()
	_root.visible = true
	if _status.text != status:
		_registrar(status)
	_status.text = status
	_bar.value = clampf(progress, 0.0, 100.0)
	_percent.text = "%d%%" % int(round(_bar.value))


func hide_after_render() -> void:
	if silencioso or _entrando:
		return
	_hide_frames = 2


func visivel() -> bool:
	return is_instance_valid(_root) and _root.visible


func _registrar(txt: String) -> void:
	etapas.append([Time.get_ticks_msec() - _t_etapa0, txt])


# =========================================================================== aquecimento
## Começa (uma vez por execução) a carregar e renderizar os recursos da partida em segundo plano.
func iniciar_aquecimento() -> void:
	if aquecendo or aquecido:
		return
	aquecendo = true
	_t_aq0 = Time.get_ticks_msec()
	var paths := _lista_recursos()
	_total = paths.size()
	for p in paths:
		if ResourceLoader.has_cached(p):
			_cache[p] = load(p)
			_fila_render.append(p)
			continue
		if ResourceLoader.load_threaded_request(p, "", false) == OK:
			_pendentes.append(p)
		else:
			_total -= 1
	_criar_viewport()
	print("AQUECIMENTO_INICIO recursos=", _total)


## 0..1: fração de recursos carregados E renderizados.
func aquecimento_progresso() -> float:
	if aquecido:
		return 1.0
	if _total <= 0:
		return 0.0
	return clampf(float(_prontos) / float(_total), 0.0, 0.999)


func _lista_recursos() -> Array[String]:
	var out: Array[String] = []
	var vistos := {}
	if FileAccess.file_exists(LISTA_AQUECIMENTO):
		var data = JSON.parse_string(FileAccess.get_file_as_string(LISTA_AQUECIMENTO))
		if data is Dictionary:
			for p in data.get("recursos", []):
				if not String(p).ends_with(".tscn"):   # cenas com script (partida/HUD/ilha) não carregam em thread
					_add(out, vistos, String(p))
	for d in PASTAS_SEMPRE:
		_varrer(d, out, vistos)
	return out


func _add(out: Array[String], vistos: Dictionary, p: String) -> void:
	if vistos.has(p) or not ResourceLoader.exists(p):
		return
	vistos[p] = true
	out.append(p)


func _varrer(dir: String, out: Array[String], vistos: Dictionary) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		var nome := f.trim_suffix(".remap").trim_suffix(".import")
		if nome.get_extension() in ["glb", "gdshader"]:
			_add(out, vistos, dir.path_join(nome))
	for sub in da.get_directories():
		_varrer(dir.path_join(sub), out, vistos)


func _criar_viewport() -> void:
	_vp = SubViewport.new()
	_vp.name = "Aquecimento"
	_vp.size = Vector2i(96, 96)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_2X   # mesmas variações do jogo/menu
	add_child(_vp)
	# luz/ambiente com as mesmas features da ilha: sol com sombra + névoa + céu
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	sky.sky_material = psm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_density = 0.002
	_vp_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var omni := OmniLight3D.new()   # variação com luz pontual (lanternas/clarão)
	omni.position = Vector3(0, 2, 2)
	omni.omni_range = 8.0
	_vp.add_child(omni)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 6)
	cam.far = 200.0
	cam.current = true
	_vp.add_child(cam)
	_vp_raiz = Node3D.new()
	_vp.add_child(_vp_raiz)


func _passo_aquecimento() -> void:
	# 1) recolhe o que a thread terminou (sem bloquear)
	var i := _pendentes.size() - 1
	while i >= 0:
		var p: String = _pendentes[i]
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_pendentes.remove_at(i)
			_cache[p] = ResourceLoader.load_threaded_get(p)
			_fila_render.append(p)
			if ceder():
				break   # finalizar vários recursos grandes no mesmo quadro passava de 100 ms
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pendentes.remove_at(i)
			_prontos += 1
		i -= 1
	# 2) lote atual na frente da câmera: deixa renderizar QUADROS_POR_LOTE quadros e libera
	if not _lote.is_empty():
		_lote_quadros += 1
		if _lote_quadros < QUADROS_POR_LOTE:
			return
		for n in _lote:
			if is_instance_valid(n):
				n.queue_free()
		_prontos += _lote.size()
		_lote.clear()
	# 3) próximo lote (quadro anterior pesado = compilação de shader ainda rolando: espera um quadro)
	if _dt_ultimo > 30.0 and _pulos_aq < 3:   # no máximo 3 quadros seguidos: máquina lenta não pode parar o aquecimento
		_pulos_aq += 1
		return
	_pulos_aq = 0
	var k := 0
	while k < POR_QUADRO and not _fila_render.is_empty():
		var p: String = _fila_render.pop_front()
		var res: Resource = _cache.get(p)
		if res == null:
			_prontos += 1
			continue
		var n := _instanciar(res, k)
		if n == null:
			_prontos += 1
			continue
		_vp_raiz.add_child(n)
		_lote.append(n)
		k += 1
	_lote_quadros = 0
	if _lote.is_empty() and _pendentes.is_empty() and _fila_render.is_empty():
		_fim_render_quadros += 1
		if _fim_render_quadros >= 2:
			_concluir()


func _instanciar(res: Resource, k: int) -> Node:
	var pos := Vector3(-2.0 + (k % 3) * 2.0, -1.0 + (k / 3) * 2.0, 0.0)
	if res is PackedScene:
		var path := res.resource_path
		# cenas de jogo com script (partida, HUD, controlador) não rodam aqui: só cenas de modelo
		if path.ends_with(".tscn"):
			return null
		var inst := (res as PackedScene).instantiate()
		if inst is Node3D:
			var n3 := inst as Node3D
			n3.position = pos
			_encaixar(n3)
			var ap := n3.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap and ap.get_animation_list().size() > 0:
				ap.play(ap.get_animation_list()[0])   # variação skinned em movimento
		return inst
	if res is Shader:
		var sm := ShaderMaterial.new()
		sm.shader = res
		var sh := res as Shader
		if sh.get_mode() == Shader.MODE_SPATIAL:
			var raiz := Node3D.new()
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.5, 1.5)
			pm.orientation = PlaneMesh.FACE_Z
			mi.mesh = pm
			mi.material_override = sm
			mi.position = pos
			raiz.add_child(mi)
			# mesma shader em MultiMesh (grama/vegetação usam instancing)
			var mmi := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = pm
			mm.instance_count = 2
			mm.set_instance_transform(0, Transform3D(Basis(), pos + Vector3(0.2, 0, 0.1)))
			mm.set_instance_transform(1, Transform3D(Basis(), pos + Vector3(-0.2, 0, 0.1)))
			mmi.multimesh = mm
			mmi.material_override = sm
			raiz.add_child(mmi)
			return raiz
		if sh.get_mode() == Shader.MODE_SKY and _vp_env:
			_vp_env.sky.sky_material = sm   # céu da ilha (ceu.gdshader) compila aqui
			return null
		if sh.get_mode() == Shader.MODE_CANVAS_ITEM:
			var cr := ColorRect.new()
			cr.material = sm
			cr.size = Vector2(32, 32)
			var cl := CanvasLayer.new()
			cl.add_child(cr)
			return cl
		return null
	return null


## Cabe qualquer modelo (casa de 15 m ou bala de 2 cm) no quadro da câmera: o que importa é estar visível.
func _encaixar(n: Node3D) -> void:
	var aabb := AABB()
	var primeiro := true
	for g in n.find_children("*", "VisualInstance3D", true, false):
		var vi := g as VisualInstance3D
		var b := vi.get_aabb()
		if primeiro:
			aabb = b
			primeiro = false
		else:
			aabb = aabb.merge(b)
	var maior := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if maior > 0.001:
		n.scale = Vector3.ONE * (1.6 / maior)


func _concluir() -> void:
	aquecendo = false
	aquecido = true
	aquecimento_ms = Time.get_ticks_msec() - _t_aq0
	if is_instance_valid(_vp):
		_vp.queue_free()
	print("AQUECIMENTO_FEITO recursos=", _cache.size(), " ms=", aquecimento_ms)
	aquecimento_feito.emit()


# =========================================================================== pré-montagem da partida
## Enquanto o jogador está no criador de personagem, a partida (br_match: ilha, prédios, detalhes, saque, jogador)
## é montada numa SubViewport oculta com mundo próprio. Os avisos de progresso ficam silenciosos (vão para o rodapé
## do criador). Pronta, a partida renderiza alguns quadros pequenos da câmera do jogador (compila os shaders com a
## luz/névoa reais) e é congelada (PROCESS_MODE_DISABLED). No CONFIRMAR, entrar_pre_montada() a move para a árvore
## principal com change_scene_to_node: sem montagem, só a troca de mundo (~1 s).
signal pre_pronta

var pre: Node = null
var pre_estado := ""              # "" | "montando" | "compilando" | "pronta"
var silencioso := false
var pre_ms := -1
var pre_texto := ""
var pre_progresso := 0.0          # 0..100
var _pre_vp: SubViewport
var _t_pre0 := 0
var _entrando := false
const PRE_QUADROS_RENDER := 8
const PRE_CENAS := ["res://core/br_match.tscn", "res://maps/ilha/ilha.tscn", "res://ui/hud.tscn", "res://ui/br_inventory_ui.tscn", "res://core/player_controller.tscn", "res://assets/models/atualizacao/player/dayone_base.glb", "res://assets/models/characters/soldado.glb"]


func pre_montar() -> void:
	if _pre_pedido or pre != null or Game.current_match != null or not ResourceLoader.exists("res://core/br_match.tscn"):
		return
	_t_pre0 = Time.get_ticks_msec()
	_pre_vp = SubViewport.new()
	_pre_vp.name = "PreMontagem"
	_pre_vp.own_world_3d = true
	_pre_vp.size = Vector2i(320, 180)
	_pre_vp.msaa_3d = get_tree().root.msaa_3d
	_pre_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_pre_vp.gui_disable_input = true
	_pre_vp.audio_listener_enable_3d = false
	add_child(_pre_vp)
	silencioso = true
	pre_estado = "montando"
	pre_progresso = 0.0
	_pre_pedido = true
	# espera o aquecimento terminar de CARREGAR (threads): sem isso um load() da montagem bloqueava o quadro até a
	# thread do mesmo recurso acabar (casa_caicara: 2,7 s num quadro)
	marcar_passo("espera_cargas")
	while aquecendo and not _pendentes.is_empty():
		await get_tree().process_frame
	# cenas com script da partida também em thread (o load síncrono de br_match/HUD/controle custava 0,5–1,4 s num quadro)
	for cena in PRE_CENAS:
		if ResourceLoader.exists(cena) and not ResourceLoader.has_cached(cena):
			ResourceLoader.load_threaded_request(cena, "", true)
	for cena in PRE_CENAS:
		if not ResourceLoader.exists(cena):
			continue
		if ResourceLoader.load_threaded_get_status(cena) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			if ResourceLoader.has_cached(cena):
				_cache[cena] = load(cena)   # já estava em cache: não bloqueia
			continue
		while ResourceLoader.load_threaded_get_status(cena) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(cena) == ResourceLoader.THREAD_LOAD_LOADED:
			_cache[cena] = ResourceLoader.load_threaded_get(cena)
	if not _pre_pedido or Game.current_match != null:
		return
	marcar_passo("instanciar")
	pre = load("res://core/br_match.tscn").instantiate()
	pre.set_meta("pre_montagem", true)
	if pre.has_signal("partida_montada"):
		pre.connect("partida_montada", _pre_montada, CONNECT_ONE_SHOT)
	_pre_vp.add_child(pre)
	print("PRE_MONTAGEM_INICIO")


func _pre_status(status: String, progress: float) -> void:
	pre_texto = status
	pre_progresso = maxf(pre_progresso, progress)


func _pre_montada() -> void:
	if pre == null:
		return
	pre_estado = "compilando"
	marcar_passo("compilar_subviewport")
	pre_progresso = 99.0
	# sem render na SubViewport (compilar ali travava o criador): os quadros de compilação vão para depois do
	# CONFIRMAR, debaixo da tela de carregamento, já com o céu/névoa reais (entrar_pre_montada)
	if is_instance_valid(pre):
		pre.process_mode = Node.PROCESS_MODE_DISABLED
	silencioso = false
	pre_estado = "pronta"
	pre_progresso = 100.0
	pre_ms = Time.get_ticks_msec() - _t_pre0
	print("PRE_MONTAGEM_PRONTA ms=", pre_ms)
	pre_pronta.emit()


var _pre_pedido := false


func tem_pre_montagem() -> bool:
	return _pre_pedido


## 0..1 para o rodapé do criador: aquecimento de shaders + montagem da partida.
func preparo_progresso() -> float:
	var a := aquecimento_progresso()
	if not tem_pre_montagem():
		return a
	return clampf(a * 0.25 + pre_progresso / 100.0 * 0.75, 0.0, 1.0 if pre_estado == "pronta" and aquecido else 0.999)


func preparo_pronto() -> bool:
	return aquecido and (pre_estado == "pronta" or not tem_pre_montagem())


## CONFIRMAR no criador: entra na partida pré-montada (espera terminar, mostrando o progresso, se ainda estiver montando).
func entrar_pre_montada() -> void:
	if not tem_pre_montagem():
		Game.start_match()
		return
	get_tree().paused = false
	silencioso = false
	_entrando = true
	show_progress(pre_texto if pre_estado == "montando" and pre_texto != "" else "Entrando na ilha...", maxf(pre_progresso, 2.0))
	_registrar("[pre] estado=" + pre_estado)
	while pre_estado != "pronta":
		if pre_estado == "montando":
			silencioso = false   # a partir daqui o progresso real aparece na tela de carregamento
		await get_tree().process_frame
		if not tem_pre_montagem():
			_entrando = false
			Game.start_match()
			return
	set_progress("Entrando na ilha...", 99.0)
	var m := pre
	pre = null
	pre_estado = ""
	_pre_pedido = false
	_pre_vp.remove_child(m)
	m.remove_meta("pre_montagem")
	m.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().change_scene_to_node(m)
	while not m.is_inside_tree():
		await get_tree().process_frame
	if m.has_method("ativar_pre_montada"):
		m.ativar_pre_montada()
	_registrar("[pre] na arvore")
	if is_instance_valid(_pre_vp):
		_pre_vp.queue_free()
	# compila o que faltar com o céu/névoa reais, ainda debaixo da tela de carregamento
	for _i in PRE_QUADROS_RENDER:
		await RenderingServer.frame_post_draw
	_entrando = false
	hide_after_render()


# ---- orçamento por quadro da montagem em segundo plano
var _t_quadro := 0
var _dt_ultimo := 0.0
var _t_ini_quadro := 0
var _pulos_aq := 0
var pre_lentos: Array = []        # [ms, estado, texto, passo] dos quadros > 33 ms durante a pré-montagem (medição)
var pre_por_passo := {}          # passo -> [quadros, soma ms, max ms, >50, >100]
var pre_passo := ""               # rótulo fino do passo atual (marcado pelos montadores)
const ORCAMENTO_PRE_MS := 8.0     # trabalho de montagem por quadro com o criador aberto
const ORCAMENTO_CARGA_MS := 45.0  # com a tela de carregamento (ninguém vê o quadro): mais trabalho por quadro


## true quando o trabalho deste quadro já passou do orçamento: o montador deve dar `await get_tree().process_frame`.
func ceder() -> bool:
	var orc := ORCAMENTO_PRE_MS if silencioso else ORCAMENTO_CARGA_MS
	return (Time.get_ticks_usec() - _t_ini_quadro) / 1000.0 >= orc


func marcar_passo(nome: String) -> void:
	pre_passo = nome