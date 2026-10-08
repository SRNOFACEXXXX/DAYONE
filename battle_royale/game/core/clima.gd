extends Node
## Autoload "Clima": ciclo dia/noite + clima da Ilha do Tauá.
##
## API pública (para bots/IA/testes):
##   Clima.hora (0..24, float)  Clima.dia (1..)  Clima.estado / Clima.estado_alvo (enum Estado)
##   Clima.escala_tempo   multiplicador do relógio (1.0 = 1 dia em 24 min reais; 60 = 1 dia em 24 s)
##   Clima.escala_clima   multiplicador da duração/transição do clima (1.0 = tempo real)
##   Clima.semente        semente do sorteio ponderado (mude antes de ligar/`sortear_proximo`)
##   Clima.set_hora(h)  Clima.avancar(horas)  Clima.forcar_clima(estado, instantaneo=false)
##   Clima.luz_fator (0..1, 0 = escuro total, ~0.1 = noite de lua, 1 = dia claro)
##   Clima.visibilidade_fator (0.3..1.0, 1 = céu limpo, 0.3 = nevoeiro denso)
##   Clima.chuva (0..1)  Clima.vento (0..1)  Clima.e_noite()  Clima.fator_visao_zumbi()
## Sinais: hora_mudou(hora) a cada hora cheia, novo_dia(dia), amanheceu, anoiteceu, clima_mudou(estado).

signal hora_mudou(hora: int)
signal novo_dia(dia: int)
signal amanheceu
signal anoiteceu
signal clima_mudou(estado: int)

enum Estado { LIMPO, NUBLADO, CHUVA, TEMPESTADE, NEVOEIRO }
const NOMES := ["Limpo", "Nublado", "Chuva", "Tempestade", "Nevoeiro"]
const HORA_INICIAL := 10.0
const DIA_REAL_S := 1440.0          # 1 dia = 24 min reais com escala 1
const SOL_MAX_ELEV := 58.0          # graus ao meio-dia
const NASCER := 6.0
const POENTE := 18.0
const CHUVA_PARTICULAS := 220        # antes 380 (~40% menos gotas); o quad ficou mais comprido para manter o risco

var hora := HORA_INICIAL
var dia := 1
var escala_tempo := 1.0
var escala_clima := 1.0
var congelado := false              # relógio parado (testes: --hora=X sem --ciclo)
var clima_automatico := true
var semente := 1337
var estado: int = Estado.LIMPO
var estado_alvo: int = Estado.LIMPO
var luz_fator := 1.0
var visibilidade_fator := 1.0
var chuva := 0.0
var vento := 0.15
var coberto := false                # jogador sob teto (chuva abafada)
var elevacao_sol := 30.0            # graus (negativo = noite)

# parâmetros por clima: luz (sol), fog (mult. densidade), cinza (céu/névoa), chuva, vento, vis, trov (prob. de relâmpago)
const CLIMA := {
	Estado.LIMPO: {"luz": 1.0, "fog": 1.0, "cinza": 0.0, "chuva": 0.0, "vento": 0.15, "vis": 1.0, "trov": 0.0},
	Estado.NUBLADO: {"luz": 0.55, "fog": 1.6, "cinza": 0.6, "chuva": 0.0, "vento": 0.35, "vis": 0.9, "trov": 0.0},
	Estado.CHUVA: {"luz": 0.35, "fog": 2.8, "cinza": 0.8, "chuva": 0.6, "vento": 0.5, "vis": 0.7, "trov": 0.15},
	Estado.TEMPESTADE: {"luz": 0.18, "fog": 4.0, "cinza": 0.92, "chuva": 1.0, "vento": 1.0, "vis": 0.5, "trov": 1.0},
	Estado.NEVOEIRO: {"luz": 0.5, "fog": 12.0, "cinza": 0.5, "chuva": 0.0, "vento": 0.05, "vis": 0.3, "trov": 0.0},
}
const PESOS := {Estado.LIMPO: 35.0, Estado.NUBLADO: 25.0, Estado.CHUVA: 18.0, Estado.TEMPESTADE: 7.0, Estado.NEVOEIRO: 15.0}

# chaves de hora: paleta do céu/ambiente. sol = luz do sol, sc = cor do disco no céu
const CH_HORAS := [0.0, 4.8, 5.6, 6.2, 8.5, 12.0, 15.5, 17.0, 17.9, 18.8, 19.8, 24.0]
var _chaves: Array = []

# ligações com a cena (ilha.gd chama ligar())
var _ilha: Node3D
var _env: Environment
var _sol: DirectionalLight3D
var _ceu: ShaderMaterial
var _sky: Sky
var nuvens_mat: ShaderMaterial
var _hud: Control
var _chuva_fx: CPUParticles3D
var _chuva_mat: StandardMaterial3D
var _raiz_fx: Node3D
var _a_chuva: AudioStreamPlayer
var _a_vento: AudioStreamPlayer
var _a_grilos: AudioStreamPlayer

# estado interno
var _rng := RandomNumberGenerator.new()
var _w := {}              # parâmetros de clima atuais (interpolados)
var _w_de := {}
var _w_para := {}
var _w_t := 1.0
var _w_dur := 45.0
var _resta := 240.0       # s de clima até sortear o próximo
var _hora_int := -1
var _era_dia := true
var _flash := 0.0
var _flash_t := 99.0
var _prox_raio := 8.0
var _acc_ceu := 0.0
var _acc_raio_cobertura := 0.0
var _acc_luz := 0.0                 # luz/névoa/céu aplicados a 10 Hz (a cada quadro só durante relâmpago)
var _acc_hud := 0.0                 # texto e ícone do HUD a 5 Hz
var _pausa_visual := false
var _fog_base := 0.0006
var _parado_teste := false   # --semclima: só aplica a hora inicial (medir custo do sistema)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_chaves()
	_rng.seed = semente
	_w = (CLIMA[Estado.LIMPO] as Dictionary).duplicate()
	_w_de = _w.duplicate()
	_w_para = _w.duplicate()
	_resta = _rng.randf_range(180.0, 600.0)
	if Game.test_args.has("hora"):
		hora = float(Game.test_args["hora"])
		congelado = not Game.test_args.has("ciclo")
	if Game.test_args.has("clima"):
		var i := NOMES.find(String(Game.test_args["clima"]).capitalize())
		if i >= 0:
			forcar_clima(i, true)
			clima_automatico = false
	if Game.test_args.has("escala_tempo"):
		escala_tempo = float(Game.test_args["escala_tempo"])


# ------------------------------------------------------------------ API

func set_hora(h: float) -> void:
	hora = fposmod(h, 24.0)
	_aplicar(true)


func avancar(horas: float) -> void:
	var nova := hora + horas
	while nova >= 24.0:
		nova -= 24.0
		dia += 1
		novo_dia.emit(dia)
	while nova < 0.0:
		nova += 24.0
		dia = maxi(1, dia - 1)
	hora = nova
	_aplicar(true)


func forcar_clima(e: int, instantaneo := false, duracao := 45.0) -> void:
	estado_alvo = e
	_w_de = _w.duplicate()
	_w_para = (CLIMA[e] as Dictionary).duplicate()
	_w_dur = 0.01 if instantaneo else maxf(duracao, 0.1)
	_w_t = 0.0
	_resta = _rng.randf_range(180.0, 600.0)
	if instantaneo:
		_w = _w_para.duplicate()
		_w_t = 1.0
		estado = e
		clima_mudou.emit(e)
		_aplicar(true)


func sortear_proximo() -> int:
	_rng.seed = hash(semente + dia * 7919 + int(hora * 10.0) + estado_alvo)
	var total := 0.0
	var pesos := {}
	for k in PESOS:
		var p: float = PESOS[k]
		if k == estado_alvo:
			p = 0.0
		if k == Estado.TEMPESTADE and estado_alvo not in [Estado.CHUVA, Estado.NUBLADO]:
			p = 0.0   # tempestade só vem depois de nublado/chuva
		pesos[k] = p
		total += p
	var r := _rng.randf() * total
	for k in pesos:
		r -= pesos[k]
		if r <= 0.0:
			return k
	return Estado.NUBLADO


func e_noite() -> bool:
	return elevacao_sol < -2.0


## Multiplicador do alcance de visão dos zumbis (luz e nevoeiro).
func fator_visao_zumbi() -> float:
	return (0.6 + 0.4 * luz_fator) * visibilidade_fator


func nome_estado() -> String:
	return NOMES[estado_alvo]


func hora_texto() -> String:
	var h := int(hora)
	return "%02d:%02d" % [h, int((hora - h) * 60.0)]


# ------------------------------------------------------------------ ligação com a cena

func ligar(ilha: Node3D, env: Environment, sol: DirectionalLight3D, ceu: ShaderMaterial) -> void:
	_ilha = ilha
	_env = env
	_sol = sol
	_ceu = ceu
	_sky = env.sky
	if _sky:
		_sky.radiance_size = Sky.RADIANCE_SIZE_32
	_fog_base = float(ilha.get("FOG_ATUAL"))
	if not Game.test_args.has("hora"):
		hora = HORA_INICIAL
		dia = 1
	_hora_int = int(hora)
	_era_dia = elevacao_para(hora) > 0.0
	_montar_chuva()
	_montar_audio()
	if ilha.get_parent() is BRMatch:
		_montar_hud()
	_aplicar(true)
	_parado_teste = Game.test_args.has("semclima")


func _montar_chuva() -> void:
	if is_instance_valid(_raiz_fx):
		_raiz_fx.queue_free()
	_raiz_fx = Node3D.new()
	_raiz_fx.name = "ClimaFx"
	_raiz_fx.top_level = true
	_ilha.add_child(_raiz_fx)
	var p := CPUParticles3D.new()
	p.amount = CHUVA_PARTICULAS
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9.0, 0.2, 9.0)
	p.direction = Vector3(0, -1, 0)
	p.spread = 2.0
	p.gravity = Vector3(0, -6.0, 0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 24.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-14, -30, -14), Vector3(28, 40, 28))
	var q := QuadMesh.new()
	q.size = Vector2(0.034, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.8, 0.86, 0.97, 0.5)
	m.disable_fog = false
	q.material = m
	p.mesh = q
	p.emitting = false
	_chuva_fx = p
	_chuva_mat = m
	_raiz_fx.add_child(p)


func _montar_audio() -> void:
	if _a_chuva == null:
		_a_chuva = _player("chuva_loop")
		_a_vento = _player("vento_loop")
		_a_grilos = _player("grilos_loop")


func _player(id: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.volume_db = -60.0
	add_child(p)
	var path := "res://assets/audio/clima/%s.wav" % id
	if ResourceLoader.exists(path):
		var s: AudioStreamWAV = load(path)
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
		p.stream = s
	return p


func _montar_hud() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 4
	layer.name = "ClimaHud"
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.32)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -190
	box.offset_right = -14
	box.offset_top = 12
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	box.add_child(h)
	var ic := _IconeCeu.new()
	ic.custom_minimum_size = Vector2(22, 22)
	h.add_child(ic)
	var l := YUI.label("", 14, YUI.TEXT)
	l.name = "txt"
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	h.add_child(l)
	_hud.add_child(box)
	add_child(layer)
	_hud.set_meta("icone", ic)
	_hud.set_meta("txt", l)


class _IconeCeu extends Control:
	var noite := false
	var chuva := 0.0
	var nublado := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var cor_nuv := Color(0.78, 0.8, 0.85, 0.95)
		if noite:
			draw_circle(c, 8.0, Color("DDE6FF"))
			draw_circle(c + Vector2(4, -2), 7.0, Color(0.1, 0.12, 0.2, 1.0))
		else:
			draw_circle(c, 5.5, Color("FFD34A"))
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2.from_angle(a) * 7.5, c + Vector2.from_angle(a) * 10.0, Color("FFD34A"), 1.6)
		if nublado > 0.2:
			draw_circle(c + Vector2(2, 4), 5.0, cor_nuv)
			draw_circle(c + Vector2(-3, 5), 4.0, cor_nuv)
			draw_circle(c + Vector2(7, 5), 3.5, cor_nuv)
		if chuva > 0.2:
			for i in 3:
				draw_line(c + Vector2(-4 + i * 5, 8), c + Vector2(-5 + i * 5, 11), Color("8FC4FF"), 1.4)


# ------------------------------------------------------------------ ciclo

func _process(dt: float) -> void:
	if not is_instance_valid(_env) or _parado_teste:
		return
	# relógio
	if not congelado and not get_tree().paused:
		var antes := hora
		hora += dt * escala_tempo * 24.0 / DIA_REAL_S
		if hora >= 24.0:
			hora -= 24.0
			dia += 1
			novo_dia.emit(dia)
		if int(hora) != int(antes) or (antes > hora):
			pass
	# clima
	if _w_t < 1.0:
		_w_t = minf(1.0, _w_t + dt * maxf(escala_clima, 0.0001) / _w_dur)
		var k := smoothstep(0.0, 1.0, _w_t)
		for key in _w_para:
			_w[key] = lerpf(_w_de[key], _w_para[key], k)
		if _w_t >= 1.0:
			estado = estado_alvo
			clima_mudou.emit(estado)
	elif clima_automatico and not congelado:
		_resta -= dt * escala_clima
		if _resta <= 0.0:
			forcar_clima(sortear_proximo(), false, _rng.randf_range(30.0, 60.0))
	_atualizar_raio(dt)
	_acc_ceu += dt
	_acc_luz += dt
	if _flash > 0.0 or _acc_luz >= 0.1:
		_acc_luz = 0.0
		_aplicar(false)
	_atualizar_fx(dt)


func elevacao_para(h: float) -> float:
	return sin((h - NASCER) / 12.0 * PI) * SOL_MAX_ELEV


func _montar_chaves() -> void:
	var N := {"sol": Color("FFF7EC"), "se": 1.3, "amb": Color("A9C4E8"), "ae": 1.0, "fog": Color("B9D3EC"), "fd": 0.00042,
		"zen": Color("1F5FD0"), "meio": Color("4C8FE6"), "hor": Color("BFDDF5"), "mar": Color("A9C8E2"), "sc": Color("FFF4E0"), "est": 0.0}
	var E := {"sol": Color("FFC98F"), "se": 1.3, "amb": Color("9AB0D0"), "ae": 1.0, "fog": Color("C9C2B8"), "fd": 0.0006,
		"zen": Color("3A69B0"), "meio": Color("74A3DA"), "hor": Color("EBCDB0"), "mar": Color("B4BCC2"), "sc": Color("FFD49C"), "est": 0.0}
	var NOITE := {"sol": Color("7E96D8"), "se": 0.0, "amb": Color("3A5496"), "ae": 1.45, "fog": Color("1C2748"), "fd": 0.0006,
		"zen": Color("07112E"), "meio": Color("0F1E48"), "hor": Color("1E2F5C"), "mar": Color("16224A"), "sc": Color("A8B8E8"), "est": 1.0}
	var PRE := {"sol": Color("8090C8"), "se": 0.0, "amb": Color("5A6AA0"), "ae": 1.4, "fog": Color("4A5578"), "fd": 0.0006,
		"zen": Color("1A2860"), "meio": Color("3B4A85"), "hor": Color("8A6A8A"), "mar": Color("4A5578"), "sc": Color("FFB080"), "est": 0.4}
	var ALVO := {"sol": Color("FFB070"), "se": 0.9, "amb": Color("B09AA8"), "ae": 1.0, "fog": Color("E8B898"), "fd": 0.0007,
		"zen": Color("3A5FA8"), "meio": Color("8AA0C8"), "hor": Color("FFB080"), "mar": Color("C8A090"), "sc": Color("FFA050"), "est": 0.0}
	var MANHA := {"sol": Color("FFEBD0"), "se": 1.2, "amb": Color("A9C4E8"), "ae": 1.0, "fog": Color("C5D6E8"), "fd": 0.0005,
		"zen": Color("2560D0"), "meio": Color("5090E6"), "hor": Color("CFE3F5"), "mar": Color("B0CBE2"), "sc": Color("FFEAC8"), "est": 0.0}
	var POR := {"sol": Color("FF8A4A"), "se": 0.8, "amb": Color("8A7AA0"), "ae": 0.9, "fog": Color("D49A80"), "fd": 0.0007,
		"zen": Color("3A4890"), "meio": Color("8A6A98"), "hor": Color("FF8A55"), "mar": Color("A07888"), "sc": Color("FF7A3A"), "est": 0.1}
	var CREP := {"sol": Color("6A70B8"), "se": 0.2, "amb": Color("4A5C98"), "ae": 1.5, "fog": Color("3A4466"), "fd": 0.0006,
		"zen": Color("141E50"), "meio": Color("2E3A70"), "hor": Color("7A5A7A"), "mar": Color("3A4466"), "sc": Color("FF7A3A"), "est": 0.6}
	var MID := {}
	for k in N:
		MID[k] = _mix(N[k], E[k], 0.5)
	_chaves = [NOITE, NOITE, PRE, ALVO, MANHA, N, MID, E, POR, CREP, NOITE, NOITE]


static func _mix(a, b, t: float):
	if a is Color:
		return (a as Color).lerp(b, t)
	return lerpf(a, b, t)


func _paleta(h: float) -> Dictionary:
	var i := 0
	while i < CH_HORAS.size() - 2 and h >= CH_HORAS[i + 1]:
		i += 1
	var t := inverse_lerp(CH_HORAS[i], CH_HORAS[i + 1], h)
	t = smoothstep(0.0, 1.0, t)
	var out := {}
	for k in _chaves[i]:
		out[k] = _mix(_chaves[i][k], _chaves[i + 1][k], t)
	return out


func _aplicar(forcar: bool) -> void:
	if not is_instance_valid(_env) or not is_instance_valid(_sol):
		return
	var h := hora
	var e := elevacao_para(h)
	elevacao_sol = e
	var p := _paleta(h)
	var cw := _w
	var luz_w: float = cw.luz
	var cinza: float = cw.cinza
	# luz direcional: sol de dia, lua à noite (uma só luz: custo de sombra inalterado)
	var yaw := -35.0 + (15.5 - h) * 15.0
	var sol_f := smoothstep(-1.5, 4.0, e)
	var lua_f := smoothstep(-1.5, 6.0, -e)
	var dir_sol := _dir_para(yaw, e)
	var dir_lua := _dir_para(yaw + 180.0, -e)
	var luz_lua := 0.34
	if sol_f >= lua_f:
		_sol.rotation_degrees = Vector3(-maxf(e, 1.0), yaw, 0.0)
		_sol.light_color = (p.sol as Color).lerp(Color(0.8, 0.85, 0.95), cinza * 0.7)
		_sol.light_energy = p.se * sol_f * lerpf(1.0, luz_w, 1.0)
	else:
		_sol.rotation_degrees = Vector3(-maxf(-e, 1.0), yaw + 180.0, 0.0)
		_sol.light_color = Color("8FA8E8")
		_sol.light_energy = luz_lua * lua_f * lerpf(1.0, 0.5, cinza)
	_sol.shadow_enabled = true
	var lampada := _flash
	if lampada > 0.0:
		_sol.light_energy += 1.6 * lampada
		_sol.light_color = _sol.light_color.lerp(Color(0.85, 0.9, 1.0), lampada)
	# ambiente
	var amb: Color = p.amb
	var lum := amb.get_luminance()
	amb = amb.lerp(Color(lum, lum, lum * 1.05), cinza * 0.5)
	_env.ambient_light_color = amb
	_env.ambient_light_energy = p.ae * lerpf(1.0, 0.85, cinza) + 2.2 * lampada
	var dia_f := smoothstep(-4.0, 12.0, e)
	_env.ambient_light_sky_contribution = 0.3 * dia_f
	# névoa
	var fog: Color = p.fog
	var fl := fog.get_luminance()
	_env.fog_light_color = fog.lerp(Color(fl, fl, fl * 1.04), cinza * 0.7)
	var fd: float = p.fd * cw.fog
	if _ilha:
		_ilha.set("FOG_ATUAL", fd)
	_env.fog_density = fd
	_env.fog_sky_affect = lerpf(0.03, 0.55, clampf((cw.fog - 1.0) / 11.0, 0.0, 1.0))
	_env.adjustment_saturation = 1.12 * (1.0 - 0.28 * cinza)
	_env.adjustment_brightness = 1.0 - 0.05 * chuva
	# fatores para a IA
	var daylight := smoothstep(-6.0, 25.0, e)
	luz_fator = clampf(maxf(daylight, 0.1) * (0.4 + 0.6 * luz_w), 0.0, 1.0)
	visibilidade_fator = clampf(cw.vis, 0.3, 1.0)
	chuva = cw.chuva
	vento = cw.vento
	# céu (parâmetros caros: radiância; limita a ~4 Hz fora de saltos)
	if forcar or _acc_ceu >= 0.25 or _flash > 0.0:
		_acc_ceu = 0.0
		var cg := func(c: Color, esc: float) -> Color:
			var l := c.get_luminance()
			return c.lerp(Color(l, l, l * 1.05), cinza) * esc
		var esc := lerpf(1.0, 0.55 + 0.45 * clampf(daylight + 0.3, 0.0, 1.0), cinza)
		_ceu.set_shader_parameter("zenite", cg.call(p.zen, esc))
		_ceu.set_shader_parameter("meio", cg.call(p.meio, esc))
		_ceu.set_shader_parameter("horizonte", cg.call(p.hor, esc))
		_ceu.set_shader_parameter("mar_longe", (p.fog as Color).lerp(p.mar, 1.0 - clampf(cw.fog / 12.0, 0.0, 1.0)))
		_ceu.set_shader_parameter("sol_cor", p.sc)
		_ceu.set_shader_parameter("sol_dir", dir_sol)
		_ceu.set_shader_parameter("lua_dir", dir_lua)
		_ceu.set_shader_parameter("sol_vis", sol_f * pow(clampf(luz_w, 0.0, 1.0), 2.0))
		_ceu.set_shader_parameter("lua_vis", lua_f * (1.0 - cinza))
		_ceu.set_shader_parameter("estrelas", p.est * (1.0 - cinza))
		_ceu.set_shader_parameter("raio", _flash)
		if nuvens_mat:
			var k := clampf(0.35 + 0.65 * smoothstep(-8.0, 14.0, e), 0.0, 1.0) * lerpf(1.0, 0.75, cinza)
			nuvens_mat.set_shader_parameter("base", Color(0.655, 0.702, 0.788) * k)
			nuvens_mat.set_shader_parameter("topo", Color(1.0, 0.953, 0.878) * k)
			nuvens_mat.set_shader_parameter("borda_sol", Color(1.0, 0.86, 0.70) * k)
			nuvens_mat.set_shader_parameter("sol_dir", dir_sol)
	# sinais por hora cheia / amanhecer / anoitecer
	var hi := int(h)
	if hi != _hora_int:
		_hora_int = hi
		hora_mudou.emit(hi)
	var dia_agora := e > 0.0
	if dia_agora != _era_dia:
		_era_dia = dia_agora
		if dia_agora:
			amanheceu.emit()
		else:
			anoiteceu.emit()


static func _dir_para(yaw_deg: float, elev_deg: float) -> Vector3:
	# luz com rotation (-elev, yaw): dir da luz = -Z; direção PARA o corpo = +Z da basis
	return Basis.from_euler(Vector3(deg_to_rad(-elev_deg), deg_to_rad(yaw_deg), 0.0)).z


func _atualizar_raio(dt: float) -> void:
	if _flash_t < 2.0:
		_flash_t += dt
		var t := _flash_t
		_flash = maxf(exp(-t / 0.07), 0.65 * exp(-maxf(t - 0.16, 0.0) / 0.09) * (1.0 if t > 0.16 else 0.0))
		if t > 1.0:
			_flash = 0.0
	else:
		_flash = 0.0
	var trov: float = _w.trov
	if trov > 0.05 and not congelado:
		_prox_raio -= dt * escala_clima
		if _prox_raio <= 0.0:
			raio_agora()
			_prox_raio = _rng.randf_range(6.0, 22.0) / maxf(trov, 0.2)


## Dispara um relâmpago (flash agora, trovão atrasado pela distância/343).
func raio_agora(distancia_m := -1.0) -> void:
	_flash_t = 0.0
	var d := distancia_m if distancia_m > 0.0 else _rng.randf_range(250.0, 2400.0)
	var atraso := d / 343.0
	var vol := lerpf(-1.0, -17.0, clampf(d / 2600.0, 0.0, 1.0)) - (7.0 if coberto else 0.0)
	if Audio.has_sound("trovao"):
		get_tree().create_timer(atraso, true, false, true).timeout.connect(func() -> void:
			Audio.play("trovao", {"volume_db": vol, "pitch_var": 0.05}))


func _atualizar_fx(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	# cobertura: raio para cima a 4 Hz
	_acc_raio_cobertura += dt
	if cam and _acc_raio_cobertura > 0.25 and chuva > 0.05 and is_instance_valid(_ilha) and _ilha.is_inside_tree():
		_acc_raio_cobertura = 0.0
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + Vector3.UP * 25.0, 1)
		coberto = not _ilha.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	var alvo_chuva := chuva * (0.0 if coberto else 1.0)
	if _chuva_fx:
		_chuva_fx.emitting = alvo_chuva > 0.04 and cam != null
		if cam:
			_raiz_fx.global_position = cam.global_position + Vector3(0, 9.0, 0)
		if "amount_ratio" in _chuva_fx:
			_chuva_fx.set("amount_ratio", clampf(0.35 + 0.65 * alvo_chuva, 0.1, 1.0))
		_chuva_mat.albedo_color.a = lerpf(0.3, 0.6, alvo_chuva)
		_chuva_fx.gravity = Vector3(-4.0 * vento, -6.0, -2.0 * vento)
	# áudio em camadas
	var dia_f := smoothstep(-4.0, 12.0, elevacao_sol)
	_camada(_a_chuva, chuva * (0.35 if coberto else 1.0), -7.0, dt)
	_camada(_a_vento, clampf(vento * 0.8 + 0.1, 0.0, 1.0) * (0.5 if coberto else 1.0), -14.0, dt)
	_camada(_a_grilos, (1.0 - dia_f) * (1.0 - chuva), -38.0, dt)   # grilos bem baixos (-22 dB incomodavam)
	# HUD (5 Hz: o texto e o ícone mudam devagar; redesenhar a cada quadro custava à toa)
	_acc_hud += dt
	if is_instance_valid(_hud) and _acc_hud >= 0.2:
		_acc_hud = 0.0
		var ic: _IconeCeu = _hud.get_meta("icone")
		ic.noite = e_noite()
		ic.chuva = chuva
		ic.nublado = 1.0 - _w.luz
		ic.queue_redraw()
		var t: Label = _hud.get_meta("txt")
		t.text = "%s   Dia %d   %s" % [hora_texto(), dia, NOMES[estado_alvo if _w_t < 1.0 or estado != estado_alvo else estado]]
		_hud.visible = true


func _camada(p: AudioStreamPlayer, nivel: float, db_max: float, dt: float) -> void:
	if p == null or p.stream == null:
		return
	var alvo := -60.0 if nivel < 0.02 else lerpf(-38.0, db_max, clampf(nivel, 0.0, 1.0))
	p.volume_db = move_toward(p.volume_db, alvo, 40.0 * dt)
	if p.volume_db > -55.0 and not p.playing:
		p.play()
	elif p.volume_db <= -55.0 and p.playing:
		p.stop()
