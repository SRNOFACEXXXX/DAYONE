extends Node
## CINEMÁTICA DE 30 s: o sobrevivente chega à Vila ao entardecer, vê um zumbi no meio da rua e se esconde numa casa.
## Roda no jogo real (BRMatch: ilha, clima, personagem do criador, zumbi, portas animadas). Câmera de cinema com cortes,
## faixas 2,39:1, vinheta, grão de filme, fade. O áudio do jogo (passos, porta, zumbi, vento) sai gravado junto no vídeo.
##
## Tempo real (ver na janela):  godot --path game res://cinematic/cinematica.tscn
## Quadros soltos p/ conferir:  ... -- --quadros=2,8,12,16     (salva raw/cine/q_<t>.png e sai)
## Vídeo (Movie Maker):         godot --path game res://cinematic/cinematica.tscn --write-movie raw/cine/cine.avi --fixed-fps 30 --resolution 1280x720
##                              (os quadros do carregamento ficam no início do AVI; tools/cine_render.py corta no CINE_INICIO e junta a música)
## Linha do tempo (s): 0–5 aérea · 5–10 segue o personagem · 10–13 close · 13–16 revela o zumbi · 16–18 olhos ·
##                     18–23 agacha até a casa · 23–26 abre a porta e entra · 26–28 interior · 28–30 janela + título.

const DURACAO := 30.0
const FPS := 30.0

# ---- lugares (mundo; x leste, z sul) ----
const P_INICIO := Vector3(-309.0, 0.0, 330.3)       # estrada de terra a leste da ponte
const P_PARA := Vector3(-326.0, 0.0, 331.9)         # onde ele para e vê o zumbi
const P_PORTA_FORA := Vector3(-334.7, 0.0, 338.2)   # diante da porta norte da casa
const P_DENTRO := Vector3(-334.8, 0.0, 345.2)       # 4 m dentro da casa
const Z_INICIO := Vector3(-350.0, 0.0, 331.2)       # zumbi parado no meio da rua
const T_ANDA0 := 4.6
const T_PARA := 10.4
const T_ZUMBI_ANDA := 16.6
const T_AGACHA := 18.0
const T_PORTA := 23.0
const T_FECHA := 26.1

var t := 0.0
var m: BRMatch
var s: Soldier
var pc: PlayerController
var zumbi: ZombieEnemy
var porta: PortaCasa
var cam: Camera3D
var fade: ColorRect
var titulo: Label
var barras: Array[ColorRect] = []
var quadros_pedidos: Array = []
var _iniciado := false
var _fase_porta := 0
var _fase_fecha := 0
var _alvo_atual := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	if Game.test_args.has("quadros"):
		for q in String(Game.test_args["quadros"]).split(","):
			quadros_pedidos.append(float(q))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for i in 90:
		await get_tree().process_frame
	_montar()
	for i in 20:
		await get_tree().process_frame
	print("CINE_INICIO frame=", Engine.get_frames_drawn())
	_iniciado = true


func _montar() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	m.hud.root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	s = m.local_player
	pc = s.controller as PlayerController
	s.godmode = true
	# o controlador do jogador não escreve mais nas intenções do Soldier: a cinemática dirige
	pc.set_process(false)
	pc.set_physics_process(false)
	pc.set_process_input(false)
	pc.set_process_unhandled_input(false)
	pc._set_third_person(true)
	pc.camera.current = false
	if pc.viewmodel:
		pc.viewmodel.visible = false
	# mãos vazias: sobrevivente sem arma
	for sl in s.inventory.keys():
		s.remove_slot(sl)
	s.reset_physics_interpolation()
	_por(s, P_INICIO)
	s.yaw = PI * 0.5
	# clima/hora: fim de tarde, céu dramático e um pouco de névoa
	Clima.congelado = true
	Clima.set_hora(17.45)
	Clima.forcar_clima(Clima.Estado.NUBLADO, true)
	# porta norte da casa (a que dá para a estrada)
	var melhor := 1e9
	for p in get_tree().get_nodes_in_group("porta"):
		var d := (p as Node3D).global_position.distance_to(Vector3(-334.9, 6.5, 341.0))
		if d < melhor:
			melhor = d
			porta = p
	# zumbi parado no meio da rua
	zumbi = load("res://core/zombie.tscn").instantiate()
	m.ilha.get_node("ZombieDirector").add_child(zumbi)
	zumbi.set_physics_process(true)
	_por(zumbi, Z_INICIO)
	zumbi.rotation.y = -PI * 0.5
	zumbi.set_demo_state(&"idle")
	# câmera + pós-processamento
	cam = Camera3D.new()
	cam.top_level = true
	cam.far = 3000.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	_pos_processamento()
	m.add_to_group("cine_ativa")


func _por(n: Node3D, p: Vector3) -> void:
	var h: float = m.ilha.terrain.height_world(p.x, p.z)
	n.global_position = Vector3(p.x, h + 0.08, p.z)
	if n is CharacterBody3D:
		(n as CharacterBody3D).velocity = Vector3.ZERO
	if n is Soldier:
		(n as Soldier).reset_physics_interpolation()


func _chao(p: Vector3) -> float:
	return m.ilha.terrain.height_world(p.x, p.z)


# ============================================================== pós-processamento
func _pos_processamento() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 uv=UV-0.5; float d=length(uv*vec2(1.15,0.95)); COLOR=vec4(0.0,0.0,0.0,smoothstep(0.38,0.95,d)*0.62); }"
	var mv := ShaderMaterial.new()
	mv.shader = sh
	vig.material = mv
	cl.add_child(vig)
	var gr := ColorRect.new()
	gr.set_anchors_preset(Control.PRESET_FULL_RECT)
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sg := Shader.new()
	sg.code = "shader_type canvas_item;\nfloat h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233)))*43758.5453); }\nvoid fragment(){ float n=h(floor(FRAGCOORD.xy/1.5)+floor(TIME*24.0)*7.1); COLOR=vec4(vec3(n),0.055); }"
	var mg := ShaderMaterial.new()
	mg.shader = sg
	gr.material = mg
	cl.add_child(gr)
	# faixas de cinema 2,39:1
	var vp := get_viewport().get_visible_rect().size
	var alt := maxf(0.0, (vp.y - vp.x / 2.39) * 0.5)
	for k in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_anchors_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
		b.offset_bottom = alt if k == 0 else 0.0
		b.offset_top = 0.0 if k == 0 else -alt
		cl.add_child(b)
		barras.append(b)
	titulo = Label.new()
	titulo.text = "DAYONE"
	titulo.add_theme_font_size_override("font_size", int(vp.y * 0.12))
	titulo.add_theme_color_override("font_color", Color("f2c200"))
	titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.modulate.a = 0.0
	cl.add_child(titulo)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)


# ============================================================== atores
func _ir(alvo: Vector3, agachado := false, vel := 1.0, andar := false) -> bool:
	## move o Soldier em direção a `alvo` (plano); true ao chegar
	var d := alvo - s.global_position
	d.y = 0.0
	var dist := d.length()
	s.in_crouch = agachado
	s.in_walk = andar
	if dist < 0.25:
		s.in_move = Vector2.ZERO
		return true
	s.yaw = lerp_angle(s.yaw, atan2(-d.x, -d.z), 0.18)
	s.in_move = Vector2(0.0, clampf(dist / 0.8, 0.0, 1.0) * vel)
	return false


func _physics_process(_dt: float) -> void:
	if not _iniciado:
		return
	s.in_move = Vector2.ZERO
	s.in_sprint = false
	s.in_fire = false
	s.in_jump = false
	if t >= T_ANDA0 and t < T_PARA:
		var al := P_PARA
		_ir(al, false, 0.62, true)
	elif t >= T_PARA and t < T_AGACHA:
		s.in_crouch = false
		s.in_walk = false
		s.yaw = lerp_angle(s.yaw, PI * 0.5, 0.06)         # parado, olhando para o oeste (a rua)
	elif t >= T_AGACHA and t < T_PORTA:
		_ir(P_PORTA_FORA, true)
	elif t >= T_PORTA and t < T_FECHA:
		if _fase_porta == 0 and porta:
			porta.alternar()
			_fase_porta = 1
		if t > T_PORTA + 0.55:
			_ir(P_DENTRO, false, 0.55, true)
	elif t >= T_FECHA:
		if _fase_fecha == 0 and porta:
			_fase_fecha = 1
		s.in_crouch = true
		s.yaw = lerp_angle(s.yaw, 0.0, 0.1)                # vira para a porta
		if _fase_fecha == 1 and t > T_FECHA + 0.5 and porta and porta.aberta:
			porta.alternar()
			_fase_fecha = 2
	# zumbi: parado, depois arrasta-se para leste pela rua
	if t >= T_ZUMBI_ANDA:
		var d := minf((t - T_ZUMBI_ANDA) * 0.95, 60.0)
		var p := Z_INICIO + Vector3(d, 0.0, 0.0)
		_por(zumbi, p)
		zumbi.rotation.y = -PI * 0.5
		zumbi.set_demo_state(&"walk")
		zumbi._demo_locomotion_speed = 0.95
	if t >= 16.4 and t < 16.5 and not zumbi.has_meta("urrou"):
		zumbi.set_meta("urrou", true)
		zumbi._voz(&"zombie_alert", -2.0, 80.0)


# ============================================================== câmera
func _process(dt: float) -> void:
	if not _iniciado:
		return
	t += dt if Game.test_args.has("quadros") == false else 0.0
	if Game.test_args.has("quadros"):
		_modo_quadros(dt)
	_camera(t)
	var fo := 1.0
	fo = clampf(1.0 - t / 1.4, 0.0, 1.0)
	if t > DURACAO - 1.0:
		fo = clampf((t - (DURACAO - 1.0)) / 1.0, 0.0, 1.0)
	fade.color.a = fo
	titulo.modulate.a = clampf((t - 27.9) / 0.9, 0.0, 1.0)
	if t >= DURACAO and not Game.test_args.has("quadros"):
		print("CINE_FIM frame=", Engine.get_frames_drawn())
		get_tree().quit()


var _qi := 0
var _real := 0.0


func _modo_quadros(dt: float) -> void:
	# avança o relógio em tempo real até cada instante pedido, captura e segue
	_real += dt
	t = _real
	if _qi < quadros_pedidos.size() and t >= float(quadros_pedidos[_qi]):
		var nome := "q_%05.1f.png" % float(quadros_pedidos[_qi])
		await RenderingServer.frame_post_draw
		var out := ProjectSettings.globalize_path("res://").path_join("../raw/cine")
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out.path_join(nome))
		_qi += 1
		if _qi >= quadros_pedidos.size():
			get_tree().quit()


func _suave(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _mira(c: Camera3D, de: Vector3, para: Vector3, roll := 0.0) -> void:
	c.global_position = de
	c.look_at(para, Vector3.UP)
	c.rotate_object_local(Vector3.FORWARD, roll)


func _cabeca() -> Vector3:
	return s.global_position + Vector3(0, 1.62 - 0.55 * s.crouch, 0)


func _camera(tt: float) -> void:
	var u: float
	var de: Vector3
	var para: Vector3
	var fov := 50.0
	var roll := 0.0
	var sp := s.global_position
	var zp := zumbi.global_position
	var treme := 0.0
	if tt < 5.0:   # 1) aérea lenta sobre a estrada, rumo à vila
		u = _suave(tt / 5.0)
		de = Vector3(-262.0, 30.0, 300.0).lerp(Vector3(-296.0, 11.0, 322.5), u)
		para = Vector3(-338.0, 7.0, 336.0)
		fov = lerpf(58.0, 46.0, u)
		treme = 0.004
	elif tt < 10.4:   # 2) acompanha por trás e ao lado, baixo
		u = (tt - 5.0) / 5.4
		var lado := lerpf(2.4, -1.6, _suave(u))
		de = sp + Vector3(4.2, 0.0, lado)
		de.y = _chao(de) + lerpf(0.75, 1.25, u)
		para = sp + Vector3(-1.5, 1.15, 0.0)
		fov = 46.0
		treme = 0.012
	elif tt < 13.2:   # 3) close de frente, empurra devagar
		u = _suave((tt - 10.4) / 2.8)
		de = _cabeca() + Vector3(-2.7 + 0.5 * u, 0.15, -0.55)
		para = _cabeca() + Vector3(0.0, -0.02, 0.0)
		fov = lerpf(36.0, 30.0, u)
		treme = 0.008
	elif tt < 16.4:   # 4) sobre o ombro, lente longa: o zumbi no fim da rua
		u = _suave((tt - 13.2) / 3.2)
		de = _cabeca() + Vector3(0.9, -0.12, 0.42)
		para = Z_INICIO + Vector3(0.0, 1.35, 0.0)
		fov = lerpf(24.0, 15.0, u)
		treme = 0.003
	elif tt < 18.0:   # 5) olhos, bem perto
		u = _suave((tt - 16.4) / 1.6)
		de = _cabeca() + Vector3(-0.85 + 0.12 * u, 0.04, -0.62)
		para = _cabeca() + Vector3(0.0, 0.02, 0.0)
		fov = lerpf(22.0, 18.0, u)
		treme = 0.006
	elif tt < 21.6:   # 6) lateral rasteira: ele se agacha e corre para a casa
		u = (tt - 18.0) / 3.6
		var dir := (P_PORTA_FORA - P_PARA).normalized()
		var perp := Vector3(-dir.z, 0.0, dir.x)
		de = sp + perp * 3.3 + dir * lerpf(0.0, 1.5, u)
		de.y = _chao(de) + 0.5
		para = sp + Vector3(0.0, 0.85, 0.0) + dir * 0.6
		fov = 42.0
		treme = 0.01
	elif tt < 23.4:   # 7) plano geral estático, a casa e o zumbi pequeno ao fundo
		u = _suave((tt - 21.6) / 1.8)
		de = Vector3(-343.0, 0.0, 325.5)
		de.y = _chao(de) + 1.5
		para = Vector3(-334.0, _chao(Vector3(-334.0, 0, 340.0)) + 1.5, 339.5)
		fov = lerpf(46.0, 40.0, u)
		treme = 0.005
	elif tt < 26.1:   # 8) junto à porta: abre e entra
		u = _suave((tt - 23.4) / 2.7)
		de = Vector3(-331.4, 0.0, 336.6)
		de.y = _chao(de) + 1.25
		para = Vector3(-334.8, _chao(Vector3(-334.8, 0, 341.0)) + 1.15, 341.4).lerp(sp + Vector3(0, 1.1, 0), 0.6 * u)
		fov = 44.0
		treme = 0.008
	elif tt < 28.2:   # 9) interior: vem em direção à câmera e fecha a porta atrás de si
		u = _suave((tt - 26.1) / 2.1)
		de = Vector3(-334.9, 0.0, 349.4)
		de.y = _chao(de) + lerpf(1.35, 1.2, u)
		para = Vector3(-334.9, _chao(Vector3(-334.9, 0, 341.0)) + 1.3, 341.0).lerp(sp + Vector3(0, 1.1, 0), 0.5)
		fov = 52.0
		treme = 0.01
	else:   # 10) janela: o zumbi passa na rua
		u = _suave((tt - 28.2) / 1.8)
		de = Vector3(-337.9, 0.0, 342.6)
		de.y = _chao(de) + 1.1
		para = Vector3(-338.0, _chao(Vector3(-338.0, 0, 332.0)) + 1.3, 330.0).lerp(zp + Vector3(0, 1.3, 0), 0.5)
		fov = lerpf(40.0, 34.0, u)
		treme = 0.004
	# mão levemente trêmula (suspense): ruído suave determinístico
	var k := tt * 1.7
	var sac := Vector3(sin(k * 2.3) + 0.5 * sin(k * 5.1), sin(k * 1.9 + 1.0) + 0.5 * sin(k * 4.3), sin(k * 2.9 + 2.0)) * treme
	roll = sin(k * 1.3) * 0.004 * (treme * 80.0)
	cam.fov = fov
	_mira(cam, de + sac, para + sac * 0.6, roll)
