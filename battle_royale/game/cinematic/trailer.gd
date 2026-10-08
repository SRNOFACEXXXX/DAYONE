extends Node
## TRAILER DAYONE (2 min): "O PRIMEIRO DIA" — roteiro em docs/trailer/ROTEIRO.md.
## Roda no jogo real (BRMatch: ilha, clima, personagem do criador, zumbis, portas, armas, carro) com câmera de cinema por tomadas.
## O Godot só renderiza imagem limpa (sem faixas/vinheta/grão): o pós-processamento com IA é offline (tools/trailer/pos.py).
##
## Tempo real (ver):          godot --path game res://cinematic/trailer.tscn -- --shot=praia --quadros=0,2,4
## Vídeo (Movie Maker, 30fps): godot --path game res://cinematic/trailer.tscn --write-movie raw/trailer/bruto.avi --fixed-fps 30 --resolution 1280x720
##   (a linha "TRAILER_INICIO frame=N" marca onde começa o filme; o AVI tem também o áudio do jogo)

const T0 := 6.0          # o filme do Godot começa aqui (0–6 s é preto + rádio, feito no pós)
const FIM := 110.0

var t := T0
var m: BRMatch
var s: Soldier
var pc: PlayerController
var bm: BodyModel
var cam: Camera3D
var shots: Array = []
var shot_i := -1
var _iniciado := false
var _extras: Array[Node] = []
var _luzes_fogo: Array = []
var _solo := ""
var _quadros: Array = []
var _qi := 0
var _real := 0.0
var _vig := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.physics_ticks_per_second = 60    # 30 fps do filme = exatamente 2 passos físicos por quadro (64 Hz gerava tremida)
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	if Game.test_args.has("quadros"):
		for q in String(Game.test_args["quadros"]).split(","):
			_quadros.append(float(q))
	_solo = String(Game.test_args.get("shot", ""))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for i in 90:
		await get_tree().process_frame
	_montar_base()
	_definir_shots()
	var inicio := 0
	if _solo != "":
		for k in shots.size():
			if shots[k].id == _solo:
				inicio = k
		t = shots[inicio].t0
	_iniciar_shot(inicio)
	for i in 14:
		(shots[inicio].cam as Callable).call(t - float(shots[inicio].t0))    # câmera já no lugar certo no 1º quadro do filme
		await get_tree().process_frame
	(shots[inicio].cam as Callable).call(t - float(shots[inicio].t0))
	print("TRAILER_INICIO frame=", Engine.get_frames_drawn())
	_iniciado = true


# ======================================================================== base
func _montar_base() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	m.hud.root.visible = false
	for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false     # relógio do Clima, dicas [B]/[TAB], etc.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	s = m.local_player
	pc = s.controller as PlayerController
	bm = s.body_model
	s.godmode = true
	pc.set_process(false)
	pc.set_physics_process(false)
	pc.set_process_input(false)
	pc.set_process_unhandled_input(false)
	pc._set_third_person(true)
	pc.camera.current = false
	if pc.viewmodel:
		pc.viewmodel.visible = false
	for sl in s.inventory.keys():
		s.remove_slot(sl)
	Clima.congelado = true
	cam = Camera3D.new()
	cam.top_level = true
	cam.far = 3000.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()


func _chao(x: float, z: float) -> float:
	return m.ilha.terrain.height_world(x, z)


func P(x: float, z: float, h := 0.0) -> Vector3:
	return Vector3(x, _chao(x, z) + h, z)


func h_pos(p: Vector3, yaw: float) -> void:
	s.global_position = Vector3(p.x, _chao(p.x, p.z) + 0.1, p.z)
	s.velocity = Vector3.ZERO
	s.yaw = yaw
	s.reset_physics_interpolation()


func h_ir(alvo: Vector3, agachado := false, vel := 1.0, andar := false) -> bool:
	var d := alvo - s.global_position
	d.y = 0.0
	s.in_crouch = agachado
	s.in_walk = andar
	if d.length() < 0.25:
		s.in_move = Vector2.ZERO
		return true
	s.yaw = lerp_angle(s.yaw, atan2(-d.x, -d.z), 0.18)
	s.in_move = Vector2(0.0, clampf(d.length() / 0.8, 0.0, 1.0) * vel)
	return false


func h_andar(pontos: Array, tl: float, dur: float, vmax := 6.35, agachado := false) -> bool:
	## herói anda por uma polilinha com perfil de velocidade suave (acelera, cruza, desacelera) e curva naturalmente
	var comp := 0.0
	for i in pontos.size() - 1:
		comp += (pontos[i + 1] - pontos[i]).length()
	var u := clampf(tl / dur, 0.0, 1.0)
	var uu := u * u * (3.0 - 2.0 * u)
	var dist := comp * uu
	var vel := comp * 6.0 * u * (1.0 - u) / dur
	var alvo_d := minf(dist + 1.2, comp)
	var acc := 0.0
	var alvo: Vector3 = pontos[pontos.size() - 1]
	for i in pontos.size() - 1:
		var seg: float = (pontos[i + 1] - pontos[i]).length()
		if acc + seg >= alvo_d:
			alvo = pontos[i].lerp(pontos[i + 1], (alvo_d - acc) / maxf(seg, 0.001))
			break
		acc += seg
	var d: Vector3 = alvo - s.global_position
	d.y = 0.0
	s.in_crouch = agachado
	s.in_walk = false
	if u >= 1.0 and d.length() < 0.35:
		s.in_move = Vector2.ZERO
		return true
	if d.length() > 0.05:
		s.yaw = lerp_angle(s.yaw, atan2(-d.x, -d.z), 0.10)
	s.in_move = Vector2(0.0, clampf(vel / vmax, 0.0, 1.0))
	return u >= 1.0


func h_parado() -> void:
	s.in_move = Vector2.ZERO
	s.in_crouch = false
	s.in_walk = false
	s.in_sprint = false


func h_visivel(v: bool) -> void:
	s.visible = v
	if bm:
		bm.visible = v


func z_novo(p: Vector3, yaw: float, estado := &"idle", variante := -1) -> ZombieEnemy:
	var z: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
	if variante >= 0:
		z._variant_index = variante
	m.ilha.get_node("ZombieDirector").add_child(z)
	z.global_position = Vector3(p.x, _chao(p.x, p.z) + 0.08, p.z)
	z.rotation.y = yaw
	if estado != &"":
		z.set_demo_state(estado)
	_varia(z)
	_extras.append(z)
	return z


func _varia(z: ZombieEnemy) -> void:
	## cada zumbi tem ritmo, fase e passada próprios (antes todos andavam em uníssono, igual)
	var r := RandomNumberGenerator.new()
	r.seed = int(z.get_instance_id())
	z.set_meta("vel", r.randf_range(0.82, 1.22))
	z.run_speed *= r.randf_range(0.8, 1.2)
	z.walk_speed *= r.randf_range(0.75, 1.3)
	z._demo_locomotion_speed *= r.randf_range(0.8, 1.2)
	z.set_meta("fase", r.randf_range(0.0, 1.0))
	z.set_meta("fase_ok", false)
	z.scale = Vector3.ONE * r.randf_range(0.95, 1.07)


func _anima_variacao() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		var zz := z as ZombieEnemy
		if zz == null or not zz.has_meta("vel") or zz.state == ZombieEnemy.State.DEAD:
			continue
		var ap: AnimationPlayer = zz._animation_player
		if ap == null:
			continue
		ap.speed_scale = float(zz.get_meta("vel"))
		if not bool(zz.get_meta("fase_ok")) and ap.current_animation != "" and ap.is_playing():
			ap.seek(float(zz.get_meta("fase")) * ap.current_animation_length, true)
			zz.set_meta("fase_ok", true)


func limpar() -> void:
	Input.action_release("alt_fire")
	for n in _extras:
		if is_instance_valid(n):
			n.queue_free()
	_extras.clear()
	_luzes_fogo.clear()
	if bm:
		MxRetarget.parar(bm)
	h_visivel(true)
	h_parado()


func clima(hora: float, estado: int) -> void:
	Clima.set_hora(hora)
	Clima.forcar_clima(estado, true)


# ======================================================================== efeitos
func _tex_radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 128
	tx.height = 128
	return tx


func fx_fumaca(p: Vector3, escala := 1.0, escuro := 0.12, alt := 1.0) -> Node3D:
	var c := CPUParticles3D.new()
	c.amount = 38
	c.lifetime = 15.0
	c.preprocess = 15.0
	c.local_coords = false
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 1.3 * escala
	c.direction = Vector3.UP
	c.spread = 7.0
	c.initial_velocity_min = 2.2 * alt
	c.initial_velocity_max = 3.4 * alt
	c.gravity = Vector3(0.9, 0.0, 0.2)
	c.damping_min = 0.15
	c.damping_max = 0.3
	c.scale_amount_min = 6.0 * escala
	c.scale_amount_max = 9.5 * escala
	var sc := Curve.new()
	sc.min_value = 0.0
	sc.max_value = 3.0
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 2.3))
	c.scale_amount_curve = sc
	var gr := Gradient.new()
	gr.set_color(0, Color(escuro, escuro, escuro * 1.05, 0.0))
	gr.add_point(0.12, Color(escuro, escuro, escuro * 1.05, 0.7))
	gr.set_color(gr.get_point_count() - 1, Color(escuro + 0.12, escuro + 0.12, escuro + 0.14, 0.0))
	c.color_ramp = gr
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mt.billboard_keep_scale = true
	mt.vertex_color_use_as_albedo = true
	mt.albedo_texture = _tex_radial()
	mt.particles_anim_h_frames = 1
	mt.particles_anim_v_frames = 1
	mt.no_depth_test = false
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mt
	c.mesh = q
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.position = p          # antes de entrar na árvore: o preprocess nasce no lugar certo (partículas em coordenadas do mundo)
	add_child(c)
	_extras.append(c)
	return c


func fx_fogo(p: Vector3, escala := 1.0) -> Node3D:
	var c := CPUParticles3D.new()
	c.amount = 24
	c.lifetime = 0.9
	c.preprocess = 1.0
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.45 * escala
	c.direction = Vector3.UP
	c.spread = 14.0
	c.initial_velocity_min = 1.2
	c.initial_velocity_max = 2.4
	c.gravity = Vector3(0.3, 1.5, 0.0)
	c.scale_amount_min = 1.2 * escala
	c.scale_amount_max = 2.2 * escala
	var sc := Curve.new()
	sc.min_value = 0.0
	sc.max_value = 1.5
	sc.add_point(Vector2(0, 0.7))
	sc.add_point(Vector2(1, 0.1))
	c.scale_amount_curve = sc
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.85, 0.35, 0.95))
	gr.add_point(0.45, Color(1.0, 0.42, 0.1, 0.8))
	gr.set_color(gr.get_point_count() - 1, Color(0.35, 0.05, 0.0, 0.0))
	c.color_ramp = gr
	var q := QuadMesh.new()
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mt.billboard_keep_scale = true
	mt.vertex_color_use_as_albedo = true
	mt.albedo_texture = _tex_radial()
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mt
	c.mesh = q
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.position = p
	add_child(c)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.omni_range = 16.0 * escala
	l.light_energy = 2.2
	l.shadow_enabled = false
	add_child(l)
	l.global_position = p + Vector3(0, 1.0, 0)
	_luzes_fogo.append(l)
	_extras.append(c)
	_extras.append(l)
	return c


func fogueira(p: Vector3, escala := 1.0, fumaca := true) -> void:
	fx_fogo(p, escala)
	if fumaca:
		fx_fumaca(p + Vector3(0, 0.8, 0), escala * 1.2, 0.09, 1.0)


func _tremeluz(tt: float) -> void:
	for i in _luzes_fogo.size():
		var l: OmniLight3D = _luzes_fogo[i]
		if is_instance_valid(l):
			l.light_energy = 2.0 + 0.7 * sin(tt * 17.0 + i * 3.1) + 0.4 * sin(tt * 31.0 + i)


func prop(caminho: String, p: Vector3, yaw_graus := 0.0, escala := 1.0) -> Node3D:
	var r := load(caminho) as PackedScene
	if r == null:
		push_warning("prop não carregou: " + caminho)
		return null
	var n := r.instantiate() as Node3D
	add_child(n)
	n.global_position = Vector3(p.x, _chao(p.x, p.z) + p.y, p.z)
	n.rotation_degrees.y = yaw_graus
	n.scale = Vector3.ONE * escala
	_extras.append(n)
	return n


# ======================================================================== câmera
func _suave(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


var _cs_p := Vector3.ZERO
var _cs_v := Vector3.ZERO
var _cs_l := Vector3.ZERO
var _cs_lv := Vector3.ZERO
var _cs_f := 50.0
var _cs_fv := 0.0
var _cs_shot := -99
var _ruido := FastNoiseLite.new()


func _mola(x, v, alvo, omega: float, dt: float) -> Array:
	## mola criticamente amortecida (implícita, estável em qualquer dt)
	var f := 1.0 + 2.0 * dt * omega
	var oo := omega * omega
	var hoo := dt * oo
	var hhoo := dt * hoo
	var det_inv := 1.0 / (f + hhoo)
	var nx = (f * x + dt * v + hhoo * alvo) * det_inv
	var nv = (v + hoo * (alvo - x)) * det_inv
	return [nx, nv]


func cam_a(de: Vector3, para: Vector3, fov: float, tremor := 0.006, roll := 0.0, tt := -1.0) -> void:
	## câmera de cinema: posição, alvo e fov passam por molas (inércia de operador) e recebem ruído Perlin lento de câmera na mão
	var dt := clampf(get_process_delta_time(), 1.0 / 120.0, 0.1)
	if _cs_shot != shot_i:
		_cs_shot = shot_i
		_cs_p = de
		_cs_l = para
		_cs_f = fov
		_cs_v = Vector3.ZERO
		_cs_lv = Vector3.ZERO
		_cs_fv = 0.0
		_ruido.noise_type = FastNoiseLite.TYPE_PERLIN
		_ruido.frequency = 0.9
		_ruido.seed = 11 + shot_i * 7
	var r1 := _mola(_cs_p, _cs_v, de, 9.0, dt)
	_cs_p = r1[0]
	_cs_v = r1[1]
	var r2 := _mola(_cs_l, _cs_lv, para, 6.0, dt)
	_cs_l = r2[0]
	_cs_lv = r2[1]
	var r3 := _mola(_cs_f, _cs_fv, fov, 5.0, dt)
	_cs_f = r3[0]
	_cs_fv = r3[1]
	var k := (t if tt < 0.0 else tt)
	var n := Vector3(_ruido.get_noise_2d(k, 1.0), _ruido.get_noise_2d(k, 7.0), _ruido.get_noise_2d(k, 13.0))
	cam.fov = _cs_f
	cam.global_position = _cs_p + n * tremor
	cam.look_at(_cs_l + n * tremor * 0.7, Vector3.UP)
	cam.rotate_object_local(Vector3.FORWARD, roll + _ruido.get_noise_2d(k, 21.0) * 0.012 * clampf(tremor * 60.0, 0.0, 1.0))


func cabeca() -> Vector3:
	return s.global_position + Vector3(0, 1.62 - 0.55 * s.crouch, 0)


func peito() -> Vector3:
	return s.global_position + Vector3(0, 1.2 - 0.4 * s.crouch, 0)


# ======================================================================== roteiro (tomadas)
func _sh(id: String, t0: float, t1: float, prep: Callable, act: Callable, camf: Callable) -> Dictionary:
	return {"id": id, "t0": t0, "t1": t1, "prep": prep, "act": act, "cam": camf}


func _definir_shots() -> void:
	shots = [
		_sh("praia", 6.0, 14.0, _p_praia, _a_praia, _c_praia),
		_sh("acorda", 14.0, 22.0, _p_acorda, _a_acorda, _c_acorda),
		_sh("duna", 22.0, 30.0, _p_duna, _a_duna, _c_duna),
		_sh("mont1", 30.0, 32.0, _p_mont1, _a_nada, _c_mont1),
		_sh("mont2", 32.0, 34.0, _p_mont2, _a_nada, _c_mont2),
		_sh("mont3", 34.0, 36.0, _p_mont3, _a_nada, _c_mont3),
		_sh("mont4", 36.0, 38.0, _p_mont4, _a_nada, _c_mont4),
		_sh("mont5", 38.0, 40.0, _p_mont5, _a_nada, _c_mont5),
		_sh("rua_anda", 40.0, 46.0, _p_rua, _a_rua_anda, _c_rua_anda),
		_sh("rua_close", 46.0, 48.6, _p_rua2, _a_rua_parado, _c_rua_close),
		_sh("rua_zumbi", 48.6, 51.0, _p_rua2, _a_rua_parado, _c_rua_zumbi),
		_sh("rua_olhos", 51.0, 52.6, _p_rua2, _a_rua_parado, _c_rua_olhos),
		_sh("corre_casa", 52.6, 56.0, _p_rua3, _a_corre_casa, _c_corre_casa),
		_sh("porta", 56.0, 58.2, _p_porta, _a_porta, _c_porta),
		_sh("interior", 58.2, 59.5, _p_interior, _a_interior, _c_interior),
		_sh("janela", 59.5, 60.0, _p_janela, _a_janela, _c_janela),
		_sh("loot1", 60.0, 62.8, _p_loot1, _a_loot1, _c_loot1),
		_sh("loot2", 62.8, 65.4, _p_loot2, _a_loot2, _c_loot2),
		_sh("loot3", 65.4, 68.0, _p_loot3, _a_loot3, _c_loot3),
		_sh("base", 68.0, 78.0, _p_base, _a_base, _c_base),
		_sh("ars_ak", 78.0, 80.6, _p_ars_ak, _a_ars, _c_ars),
		_sh("ars_m4", 80.6, 83.2, _p_ars_m4, _a_ars, _c_ars),
		_sh("ars_snp", 83.2, 86.4, _p_ars_snp, _a_ars_snp, _c_ars),
		_sh("ars_249", 86.4, 89.6, _p_ars_249, _a_ars_249, _c_ars_249),
		_sh("horda", 89.6, 92.0, _p_horda, _a_horda, _c_horda),
		_sh("carro", 92.0, 96.4, _p_carro, _a_carro, _c_carro),
		_sh("tiro3", 96.4, 100.0, _p_tiro1, _a_tiro1, _c_tiro3),
		_sh("cruz", 100.0, 110.0, _p_cruz, _a_cruz, _c_cruz),
		_sh("dbg_fumaca", 200.0, 210.0, _p_dbgf, _a_nada, _c_dbgf),
		_sh("dbg_arco", 220.0, 230.0, _p_caca, _a_caca, _c_dbg_arco),
		_sh("dbg_carro", 240.0, 250.0, _p_dbg_carro, _a_dbg_carro, _c_dbg_carro),
	]
	for k in shots.size():
		shots[k]["ord"] = k


func _iniciar_shot(i: int) -> void:
	shot_i = i
	limpar()
	(shots[i].prep as Callable).call()


# ---------------------------------------------------------------- ATO I
const BARCO := Vector3(-474.0, 0.0, 326.0)
var _zona_praia := Vector3(-466.0, 0.0, 333.0)


func _p_praia() -> void:
	clima(6.0, Clima.Estado.NEVOEIRO)
	h_pos(_zona_praia, 2.6)
	h_visivel(true)
	MxRetarget.tocar(bm, "Prone_Left_Turn", false, 0.0)    # deitado de bruços na areia (congelado no 1º quadro)
	var b := prop("res://assets/models/cobertura/barco_encalhado.glb", Vector3(BARCO.x, 0.0, BARCO.z), 40.0, 1.0)
	fx_fumaca(P(-428, 322), 0.8, 0.2, 0.7)


func _a_praia(tl: float) -> void:
	MxRetarget.seek(bm, 0.02)


func _c_praia(tl: float) -> void:
	var u := _suave(tl / 8.0)
	var de := P(-455.0, 338.5, 0.0).lerp(P(-464.0, 334.7, 0.0), u)
	de.y += lerpf(0.5, 0.75, u)
	cam_a(de, P(-467.0, 332.4, 0.7), lerpf(44.0, 30.0, u), 0.008)


func _p_acorda() -> void:
	clima(6.0, Clima.Estado.NEVOEIRO)
	h_pos(_zona_praia, 2.6)
	h_visivel(false)
	prop("res://assets/models/cobertura/barco_encalhado.glb", Vector3(BARCO.x, 0.0, BARCO.z), 40.0, 1.0)


func _a_acorda(tl: float) -> void:
	pass


func _c_acorda(tl: float) -> void:
	# POV: deitado olhando de lado, depois senta e levanta olhando a duna
	var u := _suave(tl / 7.5)
	var base := _zona_praia
	var y := lerpf(0.28, 1.62, _suave((tl - 3.0) / 3.5))
	var de := Vector3(base.x, _chao(base.x, base.z) + y, base.z)
	var yaw := lerpf(PI * 0.15, -PI * 0.5, _suave((tl - 3.0) / 4.0))
	var pitch := lerpf(0.0, 0.18, _suave((tl - 1.0) / 3.0)) - 0.2 * _suave((tl - 5.0) / 2.5)
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var olhar := de + dir * 6.0 + Vector3(0.0, sin(pitch) * 6.0 + lerpf(-0.2, 0.2, u), 0.0)
	cam_a(de, olhar, lerpf(70.0, 62.0, u), 0.02, lerpf(0.55, 0.0, _suave(tl / 4.5)))


func _p_duna() -> void:
	clima(6.4, Clima.Estado.NUBLADO)
	h_pos(P(-452.0, 338.0), -PI * 0.5)       # olha para leste (-x?) ajustado na ação
	h_visivel(true)
	# colunas de fumaça e fogo na cidade
	for p in [Vector3(-392, 0, 318), Vector3(-368, 0, 365), Vector3(-345, 0, 300), Vector3(-318, 0, 352)]:
		fogueira(P(p.x, p.z, 0.5), 1.4, true)


func _a_duna(tl: float) -> void:
	h_andar([P(-452.0, 338.0), P(-430.0, 337.0), P(-408.0, 336.0)], tl, 7.6, 6.35)


func _c_duna(tl: float) -> void:
	var u := _suave(tl / 8.0)
	var sp := s.global_position
	var de := sp + Vector3(-5.5, 1.3, 0.8)
	de.y = lerpf(_chao(de.x, de.z) + 1.3, _chao(de.x, de.z) + 9.5, u)
	cam_a(de, sp + Vector3(14.0, lerpf(1.2, 5.0, u), 0.0), lerpf(50.0, 62.0, u), 0.006)


func _p_dbgf() -> void:
	clima(10.0, Clima.Estado.LIMPO)
	h_visivel(false)
	fx_fumaca(P(-330.0, 335.0, 0.5), 1.0, 0.1, 1.0)
	fogueira(P(-326.0, 337.0, 0.5), 1.5, false)


func _c_dbgf(_tl: float) -> void:
	cam_a(P(-300.0, 335.0, 3.0), P(-330.0, 335.0, 12.0), 55.0, 0.0)


func _c_dbg_arco(tl: float) -> void:
	var sp := s.global_position
	var f := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
	var lado := Vector3(f.z, 0, -f.x)
	# de frente e um pouco à esquerda do arqueiro, perto, para ver mãos/arco
	cam_a(sp + lado * 3.2 + f * 0.6 + Vector3(0, 1.4, 0), sp + Vector3(0, 1.35, 0), 40.0, 0.0)


func _p_dbg_carro() -> void:
	clima(14.0, Clima.Estado.LIMPO)
	h_visivel(false)
	var melhor: DrivableVehicle = null
	var dmin := 1e9
	for c in get_tree().get_nodes_in_group("drivable_vehicle"):
		var d := (c as Node3D).global_position.distance_to(Vector3(-300, 6, 330))
		if d < dmin:
			dmin = d
			melhor = c
	_carro = melhor
	_carro.global_position = P(-330.0, 331.5, 1.0)
	_carro.global_rotation = Vector3(0, PI * 0.5, 0)
	_carro.freeze = false


func _a_dbg_carro(tl: float) -> void:
	if tl > 1.5:
		var dir := Vector3(1, 0, -0.08).normalized()
		var vel := minf(10.0 + (tl - 1.5) * 3.0, 17.0)
		_carro.linear_velocity = Vector3(dir.x * vel, _carro.linear_velocity.y, dir.z * vel)
		_carro.angular_velocity = Vector3.ZERO
		_carro.global_rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)


func _c_dbg_carro(tl: float) -> void:
	var cp := _carro.global_position
	cam_a(cp + Vector3(-1.5, 0.9, 5.0), cp + Vector3(1.0, 0.55, 0), 40.0, 0.0)


func _a_nada(_tl: float) -> void:
	pass


# ---------------------------------------------------------------- ATO II — montagem
func _p_mont1() -> void:
	clima(17.4, Clima.Estado.NUBLADO)
	h_visivel(false)
	fx_fumaca(P(-352, 352, 0.5), 1.0, 0.1, 1.0)
	fx_fumaca(P(-318, 360, 0.5), 0.9, 0.12, 1.0)
	z_novo(P(-352, 331.5), -PI * 0.5, &"idle")


func _c_mont1(tl: float) -> void:
	var u := _suave(tl / 2.0)
	cam_a(P(-282.0, 329.5, lerpf(1.0, 1.2, u)).lerp(P(-290.0, 330.5, 1.2), u), P(-335.0, 336.0, 1.6), lerpf(40.0, 34.0, u), 0.01)


func _p_mont2() -> void:
	clima(17.8, Clima.Estado.NUBLADO)
	h_visivel(false)
	fogueira(P(322.0, 285.5, 0.3), 1.5, true)
	z_novo(P(311.0, 281.0), PI * 0.5, &"idle", 2)


func _c_mont2(tl: float) -> void:
	var u := _suave(tl / 2.0)
	cam_a(P(300.0, 285.0, lerpf(0.9, 1.5, u)), P(330.0, 285.0, 3.0), lerpf(50.0, 44.0, u), 0.008)


func _p_mont3() -> void:
	clima(17.8, Clima.Estado.NUBLADO)
	h_visivel(false)
	fx_fumaca(P(262.0, 296.0, 0.3), 1.2, 0.1, 1.2)


func _c_mont3(tl: float) -> void:
	var u := _suave(tl / 2.0)
	cam_a(P(235.0, 326.0, 1.4).lerp(P(240.0, 322.0, 1.4), u), P(290.0, 265.0, 3.0), 46.0, 0.01)


func _p_mont4() -> void:
	clima(17.2, Clima.Estado.NEVOEIRO)
	h_visivel(false)
	for i in 5:
		z_novo(P(-338.0 - i * 5.5, 331.0 + sin(float(i) * 2.1) * 2.4), -PI * 0.5 + 0.2 * sin(float(i)), &"idle", i % 4)


func _c_mont4(tl: float) -> void:
	var u := _suave(tl / 2.0)
	cam_a(P(-296.0 + 6.0 * u, 331.2, 1.35), P(-360.0, 331.5, 1.6), lerpf(26.0, 20.0, u), 0.004)


func _p_mont5() -> void:
	clima(17.6, Clima.Estado.NUBLADO)
	h_visivel(false)
	fogueira(P(-338.0, 344.0, 1.4), 2.6, true)
	fogueira(P(-333.0, 342.0, 1.2), 1.8, false)


func _c_mont5(tl: float) -> void:
	var u := _suave(tl / 2.0)
	cam_a(P(-347.0, 328.0, lerpf(0.8, 1.1, u)), P(-336.0, 343.0, 2.0), lerpf(44.0, 38.0, u), 0.01)


# ---------------------------------------------------------------- ATO II — a rua
const P_PARA := Vector3(-326.0, 0.0, 331.9)
const P_PORTA_FORA := Vector3(-334.7, 0.0, 338.2)
const P_DENTRO := Vector3(-334.8, 0.0, 345.2)
const Z_INICIO := Vector3(-350.0, 0.0, 331.2)
var porta: PortaCasa
var _porta_aberta := false
var zumbi: ZombieEnemy


func _achar_porta() -> void:
	var melhor := 1e9
	for pp in get_tree().get_nodes_in_group("porta"):
		var d := (pp as Node3D).global_position.distance_to(Vector3(-334.9, 6.5, 341.0))
		if d < melhor:
			melhor = d
			porta = pp


func _fecha_porta() -> void:
	if porta and porta.aberta:
		porta.alternar()


func _zumbi_x(x: float) -> void:
	zumbi.global_position = Vector3(x, _chao(x, Z_INICIO.z) + 0.08, Z_INICIO.z)
	zumbi.rotation.y = -PI * 0.5
	zumbi.set_demo_state(&"walk")
	zumbi._demo_locomotion_speed = 0.95


func _p_rua() -> void:
	clima(17.45, Clima.Estado.NUBLADO)
	_achar_porta()
	_fecha_porta()
	h_pos(P(-309.0, 330.3), PI * 0.5)
	h_visivel(true)
	zumbi = z_novo(Z_INICIO, -PI * 0.5, &"idle")


func _a_rua_anda(_tl: float) -> void:
	h_ir(P_PARA, false, 0.62, true)


func _c_rua_anda(tl: float) -> void:
	var u := tl / 6.0
	var sp := s.global_position
	var lado := lerpf(2.4, -1.6, _suave(u))
	var de := sp + Vector3(4.2, 0.0, lado)
	de.y = _chao(de.x, de.z) + lerpf(0.75, 1.25, u)
	cam_a(de, sp + Vector3(-1.5, 1.15, 0.0), 46.0, 0.012)


func _p_rua2() -> void:
	clima(17.45, Clima.Estado.NUBLADO)
	_achar_porta()
	_fecha_porta()
	h_pos(P_PARA, PI * 0.5)
	h_visivel(true)
	zumbi = z_novo(Z_INICIO, -PI * 0.5, &"idle")


func _a_rua_parado(_tl: float) -> void:
	h_parado()
	s.yaw = lerp_angle(s.yaw, PI * 0.5, 0.06)


func _c_rua_close(tl: float) -> void:
	var u := _suave(tl / 2.6)
	var h := cabeca()
	cam_a(h + Vector3(-2.7 + 0.5 * u, 0.15, -0.55), h, lerpf(36.0, 30.0, u), 0.008)


func _c_rua_zumbi(tl: float) -> void:
	var u := _suave(tl / 2.4)
	var h := cabeca()
	cam_a(h + Vector3(1.4, -0.18, 0.62), Vector3(Z_INICIO.x, _chao(Z_INICIO.x, Z_INICIO.z) + 1.35, Z_INICIO.z), lerpf(22.0, 14.0, u), 0.003)


func _c_rua_olhos(tl: float) -> void:
	var u := _suave(tl / 1.6)
	var h := cabeca()
	cam_a(h + Vector3(-0.85 + 0.12 * u, 0.04, -0.62), h + Vector3(0, 0.02, 0), lerpf(22.0, 18.0, u), 0.006)


func _p_rua3() -> void:
	clima(17.45, Clima.Estado.NUBLADO)
	_achar_porta()
	_fecha_porta()
	h_pos(P_PARA, PI * 0.5)
	h_visivel(true)
	zumbi = z_novo(Z_INICIO + Vector3(1.5, 0, 0), -PI * 0.5, &"walk")


func _a_corre_casa(tl: float) -> void:
	h_ir(P_PORTA_FORA, true)
	_zumbi_x(Z_INICIO.x + 1.5 + tl * 0.95)


func _c_corre_casa(tl: float) -> void:
	var u := tl / 3.4
	var dir := (P_PORTA_FORA - P_PARA).normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var sp := s.global_position
	var de := sp + perp * 3.3 + dir * lerpf(0.0, 1.5, u)
	de.y = _chao(de.x, de.z) + 0.5
	cam_a(de, sp + Vector3(0.0, 0.85, 0.0) + dir * 0.6, 42.0, 0.01)


func _p_porta() -> void:
	clima(17.45, Clima.Estado.NUBLADO)
	_achar_porta()
	_fecha_porta()
	_porta_aberta = false
	h_pos(P_PORTA_FORA, PI)
	h_visivel(true)
	zumbi = z_novo(Vector3(-346.0, 0.0, 331.2), -PI * 0.5, &"walk")


func _a_porta(tl: float) -> void:
	if tl > 0.2 and not _porta_aberta and porta:
		porta.alternar()
		_porta_aberta = true
	if tl > 0.8:
		h_ir(P_DENTRO, false, 0.55, true)
	_zumbi_x(Z_INICIO.x + 12.0 + tl * 0.95)


func _c_porta(tl: float) -> void:
	var u := _suave(tl / 2.2)
	var de := P(-331.4, 336.6, 1.25)
	cam_a(de, P(-334.8, 341.4, 1.15).lerp(s.global_position + Vector3(0, 1.1, 0), 0.6 * u), 44.0, 0.008)


func _p_interior() -> void:
	clima(17.45, Clima.Estado.NUBLADO)
	_achar_porta()
	if porta and not porta.aberta:
		porta.alternar()
	h_pos(P(-334.8, 343.2), PI)
	h_visivel(true)
	zumbi = z_novo(Vector3(-336.0, 0.0, 331.2), -PI * 0.5, &"walk")


func _a_interior(tl: float) -> void:
	h_parado()
	s.in_crouch = true
	s.yaw = lerp_angle(s.yaw, 0.0, 0.1)
	if tl > 0.5 and porta and porta.aberta:
		porta.alternar()
	_zumbi_x(Z_INICIO.x + 15.0 + tl * 0.95)


func _c_interior(tl: float) -> void:
	var u := _suave(tl / 1.3)
	var de := P(-334.9, 349.4, lerpf(1.35, 1.2, u))
	cam_a(de, P(-334.9, 341.0, 1.3).lerp(s.global_position + Vector3(0, 1.1, 0), 0.5), 52.0, 0.01)


func _p_janela() -> void:
	clima(17.45, Clima.Estado.NEVOEIRO)
	_achar_porta()
	_fecha_porta()
	h_pos(P(-334.8, 346.0), 0.0)
	h_visivel(true)
	zumbi = z_novo(Vector3(-340.0, 0.0, 331.2), -PI * 0.5, &"walk")


func _a_janela(tl: float) -> void:
	h_parado()
	s.in_crouch = true
	_zumbi_x(Z_INICIO.x + 17.0 + tl * 1.2)


func _c_janela(tl: float) -> void:
	var u := _suave(tl / 0.5)
	cam_a(P(-337.9, 342.6, 1.1), P(-338.0, 332.0, 1.3).lerp(zumbi.global_position + Vector3(0, 1.3, 0), 0.5), lerpf(40.0, 34.0, u), 0.004)


func _fps_cam(de: Vector3, olhar: Vector3, fov: float) -> void:
	## câmera do jogador (leva o viewmodel junto): usada nas tomadas em 1ª pessoa
	pc.camera.fov = fov
	pc.camera.global_position = de
	pc.camera.look_at(olhar, Vector3.UP)
	if not pc.camera.current:
		pc.camera.make_current()


func _volta_cam() -> void:
	cam.make_current()
	if pc.viewmodel:
		pc.viewmodel.visible = false
	pc._set_third_person(true)
	pc.camera.current = false
	cam.make_current()


func mira_zumbi(max_dist := 40.0) -> ZombieEnemy:
	var melhor: ZombieEnemy = null
	var dmin := max_dist
	for z in get_tree().get_nodes_in_group("zombie"):
		var zz := z as ZombieEnemy
		if zz == null or zz.state == ZombieEnemy.State.DEAD:
			continue
		var d := zz.global_position.distance_to(s.global_position)
		if d < dmin:
			dmin = d
			melhor = zz
	return melhor


func atira_no_mais_perto(cadencia := true) -> void:
	var z := mira_zumbi()
	if z == null:
		s.in_fire = false
		return
	var alvo := z.global_position + Vector3(0, 1.5, 0) + z.velocity * 0.08   # cabeça, com antecipação do movimento
	var d := alvo - s.eye_position()
	var yaw_a := atan2(-d.x, -d.z)
	var pit_a := asin(clampf(d.y / maxf(d.length(), 0.01), -1.0, 1.0))
	s.yaw = lerp_angle(s.yaw, yaw_a, 0.45)
	s.pitch = lerpf(s.pitch, pit_a, 0.45)
	var err := rad_to_deg(absf(angle_difference(s.yaw, yaw_a))) + rad_to_deg(absf(s.pitch - pit_a))
	var ws := s.current()
	if ws:
		ws.mag = 30
		ws.reserve = 90
	s.in_fire = cadencia and err < (1.6 if not pc._third_person else 6.0) and (pc._third_person or pc._ads_amount > 0.85 or not pc._prefer_third_person and s.aim_amount < 0.1)


func armar(id: StringName) -> void:
	for sl in s.inventory.keys():
		s.remove_slot(sl)
	var ws := s.give_weapon(id)
	if ws:
		ws.mag = ws.def.mag_size
		ws.reserve = 120


func desarmar() -> void:
	s.in_fire = false
	for sl in s.inventory.keys():
		s.remove_slot(sl)


# ---------------------------------------------------------------- ATO III — saque
func _p_loot1() -> void:
	clima(17.9, Clima.Estado.NUBLADO)
	_achar_porta()
	if porta and not porta.aberta:
		porta.alternar()
	h_pos(P(-337.0, 346.6), 2.2)
	h_visivel(true)


func _a_loot1(tl: float) -> void:
	h_parado()
	s.in_crouch = true
	s.yaw = lerp_angle(s.yaw, 2.4 + 0.5 * sin(tl * 1.4), 0.05)


func _c_loot1(tl: float) -> void:
	var u := _suave(tl / 2.8)
	cam_a(P(-334.9, 349.3, lerpf(1.5, 1.2, u)).lerp(P(-333.8, 348.6, 1.2), u), s.global_position + Vector3(0, 0.8, 0), lerpf(58.0, 48.0, u), 0.012)


var _ui_estado := 0


func _p_loot2() -> void:
	clima(17.9, Clima.Estado.NUBLADO)
	h_pos(P(-337.0, 346.6), 2.2)
	h_visivel(true)
	_ui_estado = 0
	var fwd := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
	var lado := Vector3(fwd.z, 0, -fwd.x)
	for it in [["bandagem", 1.0, -0.5], ["ammo_556", 1.0, 0.5], ["backpack_medium", 1.5, 0.0], ["m4", 1.4, 0.9], ["kit_medico", 1.2, -1.0]]:
		var ex := {"mag": 30} if it[0] == "m4" else {}
		m.criar_drop(String(it[0]), 30 if it[0] == "ammo_556" else 1, s.global_position + fwd * float(it[1]) + lado * float(it[2]), ex)
	m.hud.visible = true
	m.hud.root.visible = false
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	m._unhandled_input(ev)


func _mouse(pos: Vector2, pressed := false, motion := false) -> void:
	if motion:
		var e := InputEventMouseMotion.new()
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
	else:
		var e2 := InputEventMouseButton.new()
		e2.position = pos
		e2.global_position = pos
		e2.button_index = MOUSE_BUTTON_LEFT
		e2.pressed = pressed
		Input.parse_input_event(e2)


func _item_prox(id: String) -> Vector2:
	var ui: BRInventoryUI = m.br_ui
	ui._atualizar()
	var g = ui._grade_prox
	for it in g.inv.items:
		if String(it.id) == id:
			var sz: Vector2i = BRInventory.definition(id).size
			return g.get_global_rect().position + (Vector2(int(it.x), int(it.y)) + Vector2(sz) * 0.5) * BRInventoryUI.CELL
	return Vector2(-1, -1)


var _drag := {}


func _a_loot2(tl: float) -> void:
	h_parado()
	s.in_crouch = true
	var ui: BRInventoryUI = m.br_ui
	# arrasta 3 itens para a mochila/roupa em sequência
	var plano := [["backpack_medium", 0.35], ["bandagem", 1.0], ["m4", 1.6]]
	for k in plano.size():
		var id: String = plano[k][0]
		var t0: float = plano[k][1]
		if tl >= t0 and not _drag.has(id):
			var de := _item_prox(id)
			if de.x < 0:
				_drag[id] = true
				continue
			var para: Vector2
			if id == "backpack_medium":
				para = ui._slot_mochila.get_global_rect().get_center()
			elif id == "m4":
				para = ui._maos[0].get_global_rect().get_center()
			else:
				para = ui._grade_roupa.get_global_rect().position + Vector2(2.5, 1.5) * BRInventoryUI.CELL
			_drag[id] = [de, para, tl]
			_mouse(de, true)
	for id in _drag.keys():
		var d = _drag[id]
		if d is Array:
			var u := clampf((tl - float(d[2])) / 0.45, 0.0, 1.0)
			_mouse((d[0] as Vector2).lerp(d[1], _suave(u)), false, true)
			if u >= 1.0:
				_mouse(d[1], false, false)
				_drag[id] = true


func _c_loot2(tl: float) -> void:
	cam_a(s.global_position + Vector3(2.0, 1.3, 1.0), s.global_position + Vector3(0, 1.0, 0), 50.0, 0.004)


func _p_loot3() -> void:
	m.hud.visible = false
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	if m.br_ui and m.br_ui.visible:
		m._unhandled_input(ev)
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	clima(17.9, Clima.Estado.NUBLADO)
	h_pos(P(-336.0, 345.0), 2.8)
	h_visivel(true)


func _a_loot3(tl: float) -> void:
	h_parado()
	s.in_crouch = tl < 1.2


func _c_loot3(tl: float) -> void:
	var u := _suave(tl / 2.6)
	var h := cabeca()
	var f := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	cam_a(h + f * lerpf(2.4, 1.9, u) + Vector3(0.0, 0.05, 0.0), h + Vector3(0, -0.05, 0), lerpf(36.0, 30.0, u), 0.008)


# ---------------------------------------------------------------- ATO III — base
var _base_c := Vector3.ZERO
var _base_pecas: Array = []
var _base_idx := 0


func _achar_plano() -> Vector3:
	var melhor := Vector3(-300, 0, 300)
	var vmin := 1e9
	for x in range(-340, -240, 6):
		for z in range(250, 330, 6):
			var h0 := _chao(x, z)
			if h0 < 3.0:
				continue
			var lo := 1e9
			var hi := -1e9
			for dx in [-6, 0, 6, 10]:
				for dz in [-6, 0, 6, 10]:
					var h := _chao(x + dx, z + dz)
					lo = minf(lo, h)
					hi = maxf(hi, h)
			var d := hi - lo + 0.02 * absf(float(x) + 300.0)
			if d < vmin:
				vmin = d
				melhor = Vector3(x, h0, z)
	return melhor


func _construir(idx: int, p: Vector3, yaw_graus: float) -> Node3D:
	var cs: ConstructionSystem = m.construction_system
	cs.current_piece = idx
	cs.candidate_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_graus)), p)
	cs.candidate_valid = true
	var antes := cs.world_root.get_child_count()
	cs.place_current()
	if cs.world_root.get_child_count() > antes:
		var n := cs.world_root.get_child(cs.world_root.get_child_count() - 1) as Node3D
		return n
	return null


func _p_base() -> void:
	clima(9.0, Clima.Estado.LIMPO)
	_base_c = _achar_plano()
	h_pos(Vector3(_base_c.x + 3.5, 0, _base_c.z - 6.5), PI)
	h_visivel(true)
	_base_pecas.clear()
	_base_idx = 0
	var c := _base_c
	var y0 := c.y + 0.02
	var plano := []     # [tempo local, idx peça, x, y, z, yaw]
	var t_ := 0.6
	for f in [Vector2(0, 0), Vector2(4, 0), Vector2(0, 4), Vector2(4, 4)]:
		plano.append([t_, 0, c.x + f.x, y0, c.z + f.y, 0.0]); t_ += 0.28
	var ytop := y0 + 0.24
	t_ = 1.9
	for seg in [[-2, 0, 90.0, 4], [-2, 4, 90.0, 2], [6, 0, 90.0, 2], [6, 4, 90.0, 3]]:
		plano.append([t_, seg[3], c.x + seg[0], ytop, c.z + seg[1], seg[2]]); t_ += 0.3
	for seg in [[0, -2, 0.0, 4], [4, -2, 0.0, 2], [0, 6, 0.0, 3], [4, 6, 0.0, 2]]:
		plano.append([t_, seg[3], c.x + seg[0], ytop, c.z + seg[1], seg[2]]); t_ += 0.3
	t_ = 4.4
	for f in [Vector2(0, 0), Vector2(4, 0), Vector2(0, 4), Vector2(4, 4)]:
		plano.append([t_, 5, c.x + f.x, ytop + 3.0, c.z + f.y, 0.0]); t_ += 0.3
	plano.append([6.0, 8, c.x + 2.0, ytop, c.z + 2.0, 20.0])
	for item in plano:
		_base_pecas.append(item)


func _a_base(tl: float) -> void:
	h_parado()
	while _base_idx < _base_pecas.size() and tl >= float(_base_pecas[_base_idx][0]):
		var it: Array = _base_pecas[_base_idx]
		var n := _construir(int(it[1]), Vector3(it[2], it[3], it[4]), float(it[5]))
		if n:
			var fim := n.scale
			n.scale = Vector3(fim.x, 0.02, fim.z) if int(it[1]) in [2, 3, 4] else fim * 0.05
			var tw := create_tween()
			tw.tween_property(n, "scale", fim, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_extras.append(n)
		_base_idx += 1
	# a hora corre: dia -> noite -> amanhecer (time-lapse)
	var h := 9.0 + tl * 2.9
	Clima.set_hora(fmod(h, 24.0))


func _c_base(tl: float) -> void:
	var u := tl / 9.5
	var c := _base_c + Vector3(2.0, 0.0, 2.0)
	var ang := lerpf(-0.9, 1.2, _suave(u))
	var raio := lerpf(17.0, 11.0, u)
	var de := c + Vector3(sin(ang) * raio, lerpf(5.0, 3.0, u), cos(ang) * raio)
	cam_a(de, c + Vector3(0, 1.8, 0), 52.0, 0.004)


# ---------------------------------------------------------------- ATO III — caça
var _arco: Node3D
var _cervo: Node3D
var _flecha: Node3D
var _caca_solto := false
var _caca_pos := Vector3.ZERO


func _malha_arco() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var lados := 5
	var anel: Array = []
	for i in n + 1:
		var u := float(i) / float(n)
		var y := (u - 0.5) * 1.15
		var z := -0.20 * (1.0 - 4.0 * (u - 0.5) * (u - 0.5))      # barriga do arco
		var r := lerpf(0.026, 0.016, absf(u - 0.5) * 2.0)
		var anel_i := []
		for j in lados:
			var a := TAU * float(j) / float(lados)
			anel_i.append(Vector3(cos(a) * r, y, z + sin(a) * r))
		anel.append(anel_i)
	for i in n:
		for j in lados:
			var j2 := (j + 1) % lados
			var a0: Vector3 = anel[i][j]
			var a1: Vector3 = anel[i][j2]
			var b0: Vector3 = anel[i + 1][j]
			var b1: Vector3 = anel[i + 1][j2]
			for v in [a0, b0, a1, a1, b0, b1]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _faz_arco() -> Node3D:
	var raiz := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _malha_arco()
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.35, 0.2, 0.1)
	mt.roughness = 0.8
	mi.material_override = mt
	raiz.add_child(mi)
	# corda
	var corda := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.004
	cm.bottom_radius = 0.004
	cm.height = 1.15
	corda.mesh = cm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.85, 0.8, 0.7)
	corda.material_override = mc
	raiz.add_child(corda)
	return raiz


func _faz_flecha() -> Node3D:
	var f := Node3D.new()
	var haste := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.85
	haste.mesh = cm
	haste.rotation_degrees.x = 90.0
	var mh := StandardMaterial3D.new()
	mh.albedo_color = Color(0.6, 0.45, 0.25)
	haste.material_override = mh
	f.add_child(haste)
	var ponta := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.0
	pm.bottom_radius = 0.022
	pm.height = 0.09
	ponta.mesh = pm
	ponta.rotation_degrees.x = -90.0
	ponta.position = Vector3(0, 0, -0.45)
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.7, 0.7, 0.72)
	ponta.material_override = mp
	f.add_child(ponta)
	return f


func _p_caca() -> void:
	clima(18.3, Clima.Estado.LIMPO)
	_caca_solto = false
	var base := P(-170.0, 270.0)
	h_pos(base, -PI * 0.5 + 0.3)
	h_visivel(true)
	MxRetarget.tocar(bm, "Shooting_Arrow", false, 1.0)
	var ba := BoneAttachment3D.new()
	ba.bone_name = "LeftHandProp"
	bm.skeleton.add_child(ba)
	_arco = _faz_arco()
	_arco.rotation_degrees = Vector3(0, 90, 0)
	ba.add_child(_arco)
	_extras.append(ba)
	_cervo = prop("res://assets/models/atualizacao/mundo/Deer_001.glb", Vector3(-196.0, 0.0, 279.0), 60.0, 1.0)
	_caca_pos = P(-196.0, 279.0, 1.1)
	_flecha = _faz_flecha()
	_flecha.visible = false
	add_child(_flecha)
	_extras.append(_flecha)


func _a_caca(tl: float) -> void:
	var ap: AnimationPlayer = bm.get_meta(MxRetarget.META)[2]
	if absf(ap.speed_scale - 1.0) > 0.01:
		ap.speed_scale = 1.0
	if tl > 2.8 and not _caca_solto:
		_caca_solto = true
		_flecha.visible = true
		_flecha.global_position = s.global_position + Vector3(0, 1.35, 0)
		_flecha.look_at(_caca_pos, Vector3.UP)
		var tw := create_tween()
		tw.tween_property(_flecha, "global_position", _caca_pos, 0.35)
		tw.tween_callback(func() -> void:
			if _cervo:
				var tw2 := create_tween()
				tw2.tween_property(_cervo, "rotation_degrees:z", 82.0, 0.5).set_trans(Tween.TRANS_QUAD))


func _c_caca(tl: float) -> void:
	var sp := s.global_position
	if tl < 3.0:
		var u := _suave(tl / 3.0)
		cam_a(sp + Vector3(-2.8, 1.5, 2.0).rotated(Vector3.UP, s.yaw - 0.3), sp + Vector3(0, 1.4, 0) + Vector3(-1, 0, 0).rotated(Vector3.UP, s.yaw) * 0.5, lerpf(48.0, 38.0, u), 0.006)
	else:
		var u2 := _suave((tl - 3.0) / 3.0)
		cam_a(_caca_pos + Vector3(3.0, 0.4, 2.0), _caca_pos, lerpf(40.0, 30.0, u2), 0.005)


# ---------------------------------------------------------------- ATO III — combate
func _enxame(n: int, dmin: float, dmax: float, dir: Vector3, arco := 1.2) -> void:
	for i in n:
		var a := randf_range(-arco, arco)
		var d := randf_range(dmin, dmax)
		var v := dir.rotated(Vector3.UP, a) * d
		var z := z_novo(s.global_position + v, atan2(-v.x, -v.z) + PI, &"", i % 5)
		z.target = s
		z._set_state(ZombieEnemy.State.CHASE)


func _p_tiro1() -> void:
	clima(21.8, Clima.Estado.NUBLADO)
	h_pos(P(-318.0, 336.5), PI * 0.5)
	h_visivel(true)
	armar(&"m4")
	_enxame(7, 16.0, 30.0, Vector3(-1, 0, 0), 0.5)


var _dbg_k := -1


func _a_tiro1(tl: float) -> void:
	h_parado()
	atira_no_mais_perto()
	if int(tl * 2.0) != _dbg_k:
		_dbg_k = int(tl * 2.0)
		print("TIRO t=%.1f arma=%s node=%s vis=%s mag=%s fire=%s zumbis=%d" % [tl, s.current_def().id if s.current_def() else "-", bm.weapon_node != null, (bm.weapon_node.is_visible_in_tree() if bm.weapon_node else false), s.current().mag if s.current() else -1, s.in_fire, get_tree().get_nodes_in_group("zombie").size()])


func _c_tiro1(tl: float) -> void:
	var u := _suave(tl / 3.0)
	var sp := s.global_position
	cam_a(sp + Vector3(-3.4 + 0.6 * u, 1.5 - 0.25 * u, 3.4 - 0.6 * u), sp + Vector3(-1.2, 1.3, 0.0), 46.0, 0.012)


func _p_tiro2() -> void:
	clima(21.8, Clima.Estado.NUBLADO)
	h_pos(P(-318.0, 336.5), PI * 0.5)
	s.visible = true
	bm.visible = false
	armar(&"m4")
	pc._set_third_person(false)
	pc.camera.make_current()
	if pc.viewmodel:
		pc.viewmodel.visible = true
	_enxame(7, 10.0, 22.0, Vector3(-1, 0, 0), 0.45)


func _a_tiro2(tl: float) -> void:
	h_parado()
	atira_no_mais_perto()


func _c_tiro2(tl: float) -> void:
	_fps_cam(s.eye_position(), s.eye_position() + Vector3(-sin(s.yaw) * cos(s.pitch), sin(s.pitch), -cos(s.yaw) * cos(s.pitch)) * 5.0, 72.0)


func _p_horda() -> void:
	fps_desliga()
	if pc.viewmodel:
		pc.viewmodel.visible = false
	_volta_cam()
	clima(21.6, Clima.Estado.NEVOEIRO)
	desarmar()
	h_pos(P(-318.0, 336.5), PI * 0.5)
	h_visivel(true)
	_prepara_carro()
	for i in 14:
		var v := Vector3(-14.0 - randf_range(0, 30), 0, randf_range(-6, 6))
		var z := z_novo(s.global_position + v, PI * 0.5, &"", i % 5)
		z.target = s
		z._set_state(ZombieEnemy.State.CHASE)


func _a_horda(tl: float) -> void:
	h_parado()


func _c_horda(tl: float) -> void:
	var u := _suave(tl / 2.5)
	var sp := s.global_position
	cam_a(sp + Vector3(lerpf(-5.0, -8.0, u), 0.45, 1.5), sp + Vector3(-20.0, 1.2, 0.0), lerpf(30.0, 38.0, u), 0.01)


var _carro: DrivableVehicle
const ROTA_CARRO := [Vector2(-352.0, 334.0), Vector2(-335.0, 333.4), Vector2(-318.0, 332.6), Vector2(-309.0, 332.0), Vector2(-295.0, 331.2), Vector2(-280.0, 330.2), Vector2(-262.0, 329.0), Vector2(-240.0, 327.5)]


func _prepara_carro() -> void:
	var melhor: DrivableVehicle = null
	var dmin := 1e9
	for c in get_tree().get_nodes_in_group("drivable_vehicle"):
		var d := (c as Node3D).global_position.distance_to(Vector3(-300, 6, 330))
		if d < dmin:
			dmin = d
			melhor = c
	_carro = melhor
	if _carro:
		var a: Vector2 = ROTA_CARRO[0]
		var b: Vector2 = ROTA_CARRO[1]
		var yaw := atan2(b.x - a.x, b.y - a.y)         # a frente do carro é +Z local
		_carro.global_position = P(a.x, a.y, 0.45)
		_carro.global_rotation = Vector3(0, yaw, 0)
		_carro.linear_velocity = Vector3.ZERO
		_carro.angular_velocity = Vector3.ZERO
		_carro.freeze = false


func _p_carro() -> void:
	clima(21.3, Clima.Estado.NUBLADO)
	desarmar()
	h_pos(P(-290.0, 328.0), PI * 0.5)
	if _carro == null:
		_prepara_carro()
	if _carro:
		_carro.enter_vehicle(s)
	for i in 9:
		var z := z_novo(P(-361.0 - randf_range(0, 12), 332.6 + randf_range(-3, 3)), PI * 0.5, &"", i % 5)
		z.target = _carro
		z._set_state(ZombieEnemy.State.CHASE)


func _alvo_rota(cp: Vector3, adiante := 9.0) -> Vector3:
	# ponto da rota a `adiante` metros à frente da posição mais próxima do carro
	var melhor_i := 0
	var dmin := 1e9
	for k in ROTA_CARRO.size():
		var q: Vector2 = ROTA_CARRO[k]
		var d := Vector2(cp.x, cp.z).distance_to(q)
		if d < dmin:
			dmin = d
			melhor_i = k
	var q2: Vector2 = ROTA_CARRO[mini(melhor_i + 1, ROTA_CARRO.size() - 1)]
	var q3: Vector2 = ROTA_CARRO[mini(melhor_i + 2, ROTA_CARRO.size() - 1)]
	var alvo := q2 if Vector2(cp.x, cp.z).distance_to(q2) > adiante else q3
	return Vector3(alvo.x, 0.0, alvo.y)


func _a_carro(tl: float) -> void:
	if _carro == null:
		return
	Input.action_press("move_forward")
	var al := _alvo_rota(_carro.global_position)
	var d := al - _carro.global_position
	d.y = 0.0
	var f := _carro.global_basis.z
	f.y = 0.0
	var ang := f.normalized().signed_angle_to(d.normalized(), Vector3.UP)
	Input.action_release("move_left")
	Input.action_release("move_right")
	if ang > 0.05:
		Input.action_press("move_left")
	elif ang < -0.05:
		Input.action_press("move_right")
	if int(tl * 2.0) != _dbg_k:
		_dbg_k = int(tl * 2.0)
		print("CARRO t=%.1f v=%.1f x=%.1f z=%.1f ang=%.2f" % [tl, _carro.linear_velocity.length(), _carro.global_position.x, _carro.global_position.z, ang])


func _c_carro(tl: float) -> void:
	if _carro == null:
		return
	var cp := _carro.global_position
	var f := _carro.global_basis.z
	var lado := Vector3(f.z, 0.0, -f.x)
	if tl < 2.1:
		# à frente e ao lado do carro, olhando para trás: a horda correndo atrás
		cam_a(cp + f * 6.5 + lado * 3.2 + Vector3(0, 1.2, 0), cp - f * 13.0 + Vector3(0, 1.0, 0), lerpf(52.0, 46.0, tl / 2.1), 0.02)
	else:
		var u := _suave((tl - 2.1) / 2.3)
		cam_a(cp - f * lerpf(6.0, 8.5, u) + lado * lerpf(2.2, -1.2, u) + Vector3(0, lerpf(1.4, 2.4, u), 0), cp + f * 3.0 + Vector3(0, 0.9, 0), 58.0, 0.02)


# ---------------------------------------------------------------- ATO IV — amanhecer
func _p_cruz() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	if _carro:
		_carro.exit_vehicle()
	clima(6.3, Clima.Estado.NUBLADO)
	desarmar()
	h_pos(P(-456.0, 338.0), -PI * 0.5)
	h_visivel(true)


func _a_cruz(tl: float) -> void:
	## o herói sobe a colina devagar, em direção ao sol que nasce
	Clima.set_hora(6.0 + tl * 0.045)
	var pts := [P(-456.0, 338.0), P(-444.0, 337.5), P(-432.0, 337.0), P(-420.0, 336.5)]
	h_andar(pts, tl, 10.0, 6.35)
	s.in_walk = true


func _c_cruz(tl: float) -> void:
	var u := _suave(tl / 10.0)
	var sp := s.global_position
	var f := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	var lado := Vector3(f.z, 0.0, -f.x)
	var de := sp - f * lerpf(5.2, 7.5, u) - lado * lerpf(2.6, 1.6, u) + Vector3(0, lerpf(0.5, 1.2, u), 0)
	cam_a(de, sp + f * 2.0 + Vector3(0, lerpf(1.7, 2.3, u), 0), lerpf(40.0, 34.0, u), 0.004)


func _c_tiro3(tl: float) -> void:
	var u := _suave(tl / 3.0)
	var sp := s.global_position
	cam_a(sp + Vector3(-5.5 + 2.0 * u, 0.4, -1.4), sp + Vector3(0, 1.5, 0), 40.0, 0.012)


# ---------------------------------------------------------------- ATO III — ARSENAL (várias armas atirando em zumbis)
func armar_br(id: String, extra := {}) -> void:
	## equipa a arma pelo inventário BR (mantém a mira holográfica/ACOG do item, igual ao jogo)
	var bag: BRInventory = m.br_bag
	for it in bag.items.duplicate():
		if String(BRInventory.definition(String(it.id)).get("kind", "")) == "weapon":
			bag.remove_item(int(it.uid))
	if bag.backpack_id.is_empty():
		bag.add_item("backpack_large")
		for it in bag.items:
			if String(it.id) == "backpack_large":
				bag.equip_backpack(int(it.uid))
	var ex := {"mag": 30}
	ex.merge(extra, true)
	bag.add_item(id, 1, Vector2i(-1, -1), ex)
	for it in bag.items:
		if String(it.id) == id:
			m._equip_br_weapon(int(it.uid))
			break
	var ws := s.current()
	if ws:
		ws.mag = ws.def.mag_size
		ws.reserve = 200


func fps_liga(ads := true) -> void:
	pc.set_process(true)
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	s.visible = true
	bm.visible = false
	if pc.viewmodel:
		pc.viewmodel.visible = true
		pc.viewmodel.set_viewmodel_enabled(true)
	pc.camera.make_current()
	for nome in ["MosinAimLayer", "AimLayer"]:
		var al := pc.get_node_or_null(nome)
		if al is CanvasLayer:
			(al as CanvasLayer).visible = true          # mira holográfica/ACOG/luneta desenhadas pelo jogo
	if ads:
		Input.action_press("alt_fire")
		s.ready_at = 0.0             # sem o atraso de sacar a arma: o ADS real (viewmodel + retículo alinhados) sobe em ~0,2 s


func fps_desliga() -> void:
	Input.action_release("alt_fire")
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	for nome in ["MosinAimLayer", "AimLayer"]:
		var al2 := pc.get_node_or_null(nome)
		if al2 is CanvasLayer:
			(al2 as CanvasLayer).visible = false
	pc.set_process(false)
	if pc.viewmodel:
		pc.viewmodel.visible = false
	pc._set_third_person(true)
	pc._prefer_third_person = true
	pc.camera.current = false
	cam.make_current()
	bm.visible = true


func _enxame_fps(n: int, dmin: float, dmax: float, arco: float) -> void:
	var dir := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	for i in n:
		var a := randf_range(-arco, arco)
		var d := randf_range(dmin, dmax)
		var v := dir.rotated(Vector3.UP, a) * d
		var z := z_novo(s.global_position + v, atan2(-v.x, -v.z) + PI, &"", i % 5)
		z.target = s
		z._set_state(ZombieEnemy.State.CHASE)


func _p_ars_ak() -> void:
	clima(20.4, Clima.Estado.NUBLADO)
	h_pos(P(-318.0, 336.5), PI * 0.5)
	desarmar()
	armar_br("ak47", {"reddot": true})
	fps_liga(true)
	_enxame_fps(6, 14.0, 24.0, 0.35)


func _a_ars(tl: float) -> void:
	h_parado()
	atira_no_mais_perto()


func _c_ars(_tl: float) -> void:
	pass          # a câmera é a do jogador (pc.camera), com coice, mira e viewmodel reais


func _p_ars_m4() -> void:
	fps_desliga()
	clima(20.4, Clima.Estado.NUBLADO)
	h_pos(P(-318.0, 336.5), PI * 0.5)
	desarmar()
	armar_br("m4", {"acog": true})
	fps_liga(true)
	_enxame_fps(6, 22.0, 40.0, 0.3)


func _p_ars_snp() -> void:
	fps_desliga()
	clima(19.2, Clima.Estado.NUBLADO)
	h_pos(P(-318.0, 336.5), PI * 0.5)
	desarmar()
	armar_br("mosin", {"mag": 5})
	fps_liga(true)
	if pc.viewmodel:
		pc.viewmodel.visible = false
	for i in 3:
		var v := Vector3(-48.0 - i * 9.0, 0, randf_range(-3, 3))
		var z := z_novo(s.global_position + v, PI * 0.5, &"patrol", i % 5)
		_extras.append(z)


func _a_ars_snp(tl: float) -> void:
	h_parado()
	if pc.viewmodel:
		pc.viewmodel.visible = false
	# um tiro por vez no alvo mais perto (ferrolho entre os tiros)
	var z := mira_zumbi(90.0)
	if z == null:
		s.in_fire = false
		return
	var alvo := z.global_position + Vector3(0, 1.62, 0)
	var d := alvo - s.eye_position()
	s.yaw = lerp_angle(s.yaw, atan2(-d.x, -d.z), 0.2)
	s.pitch = lerpf(s.pitch, asin(clampf(d.y / maxf(d.length(), 0.01), -1.0, 1.0)), 0.2)
	var ws := s.current()
	if ws:
		ws.mag = 5
		ws.reserve = 40
	s.in_fire = int(tl * 100.0) % 130 < 4 and tl > 0.9


func _p_ars_249() -> void:
	fps_desliga()
	clima(20.4, Clima.Estado.NUBLADO)
	h_pos(P(-318.0, 336.5), PI * 0.5)
	desarmar()
	armar_br("m249", {"mag": 100})
	fps_liga(false)
	_enxame_fps(9, 12.0, 26.0, 0.5)


func _a_ars_249(tl: float) -> void:
	h_parado()
	atira_no_mais_perto()


func _c_ars_249(_tl: float) -> void:
	pass


# ======================================================================== laço principal
func _physics_process(_dt: float) -> void:
	if not _iniciado:
		return
	var sh: Dictionary = shots[shot_i]
	(sh.act as Callable).call(t - float(sh.t0))
	_tremeluz(t)


func _process(dt: float) -> void:
	if not _iniciado:
		return
	if _quadros.size() > 0:
		_real += dt
		t = (shots[shot_i].t0 if _solo != "" else T0) + _real
		if _qi < _quadros.size() and _real >= float(_quadros[_qi]):
			_avanca_para_quadro()
	else:
		t += dt
	var sh: Dictionary = shots[shot_i]
	if t >= float(sh.t1) and shot_i + 1 < shots.size() and _solo == "":
		_iniciar_shot(shot_i + 1)
		sh = shots[shot_i]
	_anima_variacao()
	(sh.cam as Callable).call(t - float(sh.t0))
	if t >= FIM and _quadros.size() == 0:
		print("TRAILER_FIM frame=", Engine.get_frames_drawn())
		get_tree().quit()


func _avanca_para_quadro() -> void:
	var nome := "q_%s_%05.1f.png" % [_solo if _solo != "" else "tudo", float(_quadros[_qi])]
	_qi += 1
	await RenderingServer.frame_post_draw
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/trailer/prev")
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out.path_join(nome))
	if _qi >= _quadros.size():
		get_tree().quit()
