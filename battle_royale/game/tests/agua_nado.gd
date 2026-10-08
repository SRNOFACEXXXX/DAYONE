extends Node
## Soldier real entra no mar: nado obrigatório, velocidades, flutuação, sem tiro/recarga, fôlego/dano, saída e volta a andar.
## Uso: --path game res://tests/agua_nado.tscn -- --out=<pasta>   (linhas AGUA_NADO ...; falha = FAIL e exit code 1)
## O nível d'água vem de Soldier.agua_fn: aqui o mar (y = 0) e a represa (mesma regra de ilha.nivel_agua_em).

var terr: IlhaTerrain
var s: Soldier
var pc: PlayerController
var falhas := 0
var out := ""


func _ok(cond: bool, msg: String) -> void:
	print("AGUA_NADO %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _foto(nome: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("agua_%s.png" % nome))


func _achar_praia() -> Array:
	# ponto com chão ~0,5 m e declive suave até < -2,5 m a 60 m numa das 4 direções
	for r in range(40, 560, 6):
		for c in range(40, 560, 6):
			var x := -600.0 + c * 2.0
			var z := -600.0 + r * 2.0
			var h := terr.height_world(x, z)
			if h < 0.4 or h > 0.9:
				continue
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var bom := true
				var anterior := h
				for k in range(1, 31):
					var p := Vector2(x, z) + d * 2.0 * k
					var hh := terr.height_world(p.x, p.y)
					if hh > anterior + 0.05 or absf(hh - anterior) > 0.9:
						bom = false
						break
					anterior = hh
				if bom and anterior < -2.5:
					# 8 m para dentro de terra também precisa ser chão firme
					var tras := Vector2(x, z) - d * 8.0
					if terr.height_world(tras.x, tras.y) > 0.5:
						return [Vector2(x, z), d]
	return []


func _ready() -> void:
	Game.test_mode = true
	out = Game.test_args.get("out", "")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9bb4c8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8d4e0")
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
	terr = IlhaTerrain.new()
	add_child(terr)
	await terr.terrain_ready
	# mar visual simples + regra de nível (mar = 0)
	var mar := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	mar.mesh = pm
	var mm := ShaderMaterial.new()
	mm.shader = load("res://shaders/agua.gdshader")
	mar.material_override = mm
	add_child(mar)
	Soldier.agua_fn = func(_x: float, _z: float) -> float: return 0.0
	var praia := _achar_praia()
	_ok(not praia.is_empty(), "praia encontrada %s" % str(praia))
	if praia.is_empty():
		get_tree().quit(1)
		return
	var p0: Vector2 = praia[0]
	var d: Vector2 = praia[1]
	s = Soldier.new()
	s.is_local = true
	add_child(s)
	s.give_weapon(&"m4", true)
	s.switch_to(WeaponDef.Slot.PRIMARY)
	s.global_position = Vector3(p0.x - d.x * 4.0, terr.height_world(p0.x - d.x * 4.0, p0.y - d.y * 4.0) + 0.1, p0.y - d.y * 4.0)
	s.yaw = atan2(-d.x, -d.y)
	var body := BodyModel.new()
	s.add_child(body)
	s.body_model = body
	body.setup(s)
	pc = PlayerController.new()
	add_child(pc)
	pc.setup(s, null)
	pc.set_physics_process(false)   # entrada manual abaixo (o teclado não é lido)
	await _frames(40)
	_ok(s.is_on_floor() and not s.nadando, "em terra: no chão e sem nadar")
	var ws := s.current()
	var mag0 := ws.mag if ws else -1
	# anda até a água
	s.in_move = Vector2(0, 1)
	var n := 0
	while not s.nadando and n < 900:
		await _frames(1)
		n += 1
	_ok(s.nadando, "entrou na água e passou a NADAR (%d quadros, y_pes=%.2f nivel=%.2f)" % [n, s.global_position.y, s.agua_y])
	await _frames(90)
	var v := s.horizontal_speed()
	_ok(v > 1.3 and v < 1.75, "velocidade de nado %.2f m/s (alvo ~1,6)" % v)
	var eye_acima := s.eye_position().y - s.agua_y
	_ok(eye_acima > 0.15 and eye_acima < 0.55, "flutua meio submerso: olhos %.2f m acima da superfície" % eye_acima)
	_ok(not s.is_on_floor(), "nadando não anda no fundo")
	await _foto("nadando_superficie")
	s.in_sprint = true
	await _frames(90)
	v = s.horizontal_speed()
	_ok(v > 2.3 and v < 2.9, "nado rápido (Shift) %.2f m/s (alvo ~2,6)" % v)
	s.in_sprint = false
	# pular não pula
	var y0 := s.global_position.y
	s.in_jump = true
	var ymax := y0
	for i in 40:
		await _frames(1)
		ymax = maxf(ymax, s.global_position.y)
	s.in_jump = false
	_ok(ymax - y0 < 0.1 and s.eye_position().y - s.agua_y < 0.6, "pulo na água não salta (subida %.2f m)" % (ymax - y0))
	# tiro / recarga / ADS bloqueados
	s.in_fire = true
	await _frames(30)
	s.in_fire = false
	_ok(ws == null or (ws.mag == mag0 and s.shots_fired == 0.0), "sem tiro nadando (carregador %d -> %d)" % [mag0, ws.mag if ws else -1])
	if ws:
		ws.mag = maxi(ws.mag - 5, 0)
	s.in_reload = true
	await _frames(20)
	s.in_reload = false
	_ok(not s.is_reloading(), "sem recarga nadando")
	_ok(s.sprint_bloqueado(), "ADS/arma bloqueados (arma abaixada)")
	# mergulho + fôlego
	s.in_move = Vector2.ZERO
	s.in_crouch = true
	var m := 0
	while not s.submerso and m < 300:
		await _frames(1)
		m += 1
	_ok(s.submerso, "mergulhou: câmera abaixo da superfície (%d quadros)" % m)
	var f0 := s.folego
	await _frames(60)
	_ok(absf((f0 - s.folego) - 1.0) < 0.15, "fôlego cai 1 s/s (%.2f -> %.2f)" % [f0, s.folego])
	await _foto("submerso")
	s.folego = 0.4
	var hp0 := s.health
	await _frames(24)   # 0,4 s para zerar
	await _frames(240)  # 4 s afogando
	var perda := hp0 - s.health
	_ok(perda >= 17 and perda <= 22, "afogando: %d HP em ~4 s (alvo ~5 HP/s)" % perda)
	# sobe e recupera
	s.in_crouch = false
	s.in_jump = true
	var q := 0
	while s.submerso and q < 300:
		await _frames(1)
		q += 1
	s.in_jump = false
	_ok(not s.submerso, "voltou à superfície (%d quadros)" % q)
	await _frames(60)
	_ok(s.folego > 4.0, "fôlego regenera na superfície (%.1f s)" % s.folego)
	var hp1 := s.health
	await _frames(60)
	_ok(s.health == hp1, "sem dano com a cabeça fora d'água")
	# volta para a praia e anda
	s.yaw += PI
	s.in_move = Vector2(0, 1)
	s.in_sprint = true
	var r := 0
	while s.nadando and r < 1500:
		var alvo := Vector2(p0.x - d.x * 4.0, p0.y - d.y * 4.0) - Vector2(s.global_position.x, s.global_position.z)
		s.yaw = atan2(-alvo.x, -alvo.y)
		await _frames(1)
		r += 1
		if r % 300 == 0:
			print("AGUA_NADO volta r=%d pos=%s nad=%s floor=%s" % [r, s.global_position, s.nadando, s.is_on_floor()])
	_ok(not s.nadando, "saiu da água e voltou a andar (%d quadros)" % r)
	await _frames(60)
	_ok(s.is_on_floor(), "de volta ao chão")
	var vw := s.horizontal_speed()
	_ok(vw > 3.0, "velocidade de caminhada restaurada %.2f m/s" % vw)
	s.in_sprint = false
	s.in_jump = true
	await _frames(10)
	_ok(s.velocity.y > 1.0 or not s.is_on_floor(), "pulo normal de novo em terra")
	print("AGUA_NADO %s (%d falhas)" % ["PASSOU" if falhas == 0 else "FALHOU", falhas])
	get_tree().quit(0 if falhas == 0 else 1)
