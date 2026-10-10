extends Node
## Fôlego de corrida e FOV ao correr: chaves de Settings (stamina_ativa, sprint_fov), interruptor --sem_stamina,
## stamina real do Soldier, barra fina da HUD (FolegoBar) e intervalo mínimo entre pulos de desatolamento dos bots.
## Uso: godot --path game res://tests/folego_config.tscn   (linhas FOLEGO_CONFIG ...; falha = FAIL e exit code 1)

var s: Soldier
var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("FOLEGO_CONFIG %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _caixa(centro: Vector3, tam: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Soldier.LAYER_WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.global_position = centro


## Corre em frente (-Z) por n quadros; devolve se estava correndo no último quadro.
func _correr(n: int) -> bool:
	s.global_position = Vector3(0, 0.1, 0)
	s.velocity = Vector3.ZERO
	s.yaw = 0.0
	s.in_move = Vector2(0, 1)
	s.in_sprint = true
	await _frames(n)
	var correndo := s.is_sprinting
	s.in_move = Vector2.ZERO
	s.in_sprint = false
	return correndo


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void: print("FOLEGO_CONFIG TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	_caixa(Vector3(0, -0.25, 0), Vector3(200, 0.5, 200))

	# 1. chaves e padrões
	_ok(Settings.sprint_fov and Settings.stamina_ativa, "padrões: FOV ao correr e fôlego ligados")
	_ok(Settings._keys().has("sprint_fov") and Settings._keys().has("stamina_ativa"), "as duas chaves são salvas em settings.cfg")
	_ok(Settings.valor_seguro("stamina_ativa", false) == false, "valor_seguro aceita bool")
	_ok(Settings.valor_seguro("sprint_fov", "sim") == null, "valor_seguro recusa texto onde há bool")

	# 2. stamina no Soldier real
	s = Soldier.new()
	s.is_local = true
	add_child(s)
	await _frames(10)
	Settings.stamina_ativa = false
	var c1 := await _correr(120)
	_ok(c1 and s.stamina > 0.999, "fôlego desligado em Ajustes: corre e a stamina fica cheia (%.3f)" % s.stamina)
	Settings.stamina_ativa = true
	Game.test_args["sem_stamina"] = "1"
	var c2 := await _correr(120)
	_ok(c2 and s.stamina > 0.999, "--sem_stamina: corre e a stamina fica cheia (%.3f)" % s.stamina)
	Game.test_args.erase("sem_stamina")
	var c3 := await _correr(120)
	_ok(c3 and s.stamina < 0.9 and s.stamina > 0.6, "com fôlego ligado: 2 s de corrida gastam stamina (%.3f)" % s.stamina)

	# 3. barra da HUD (classe FolegoBar de ui/hud.gd), testada direto sem partida
	var clase = preload("res://ui/hud.gd").FolegoBar
	var barra = clase.new()
	barra.soldier = s
	s.stamina = 0.4
	for _i in 30:
		barra._process(1.0 / 60.0)
	_ok(barra.modulate.a > 0.9, "barra aparece com fôlego baixo (alfa %.2f)" % barra.modulate.a)
	s.stamina = 1.0
	for _i in 90:
		barra._process(1.0 / 60.0)
	_ok(barra.modulate.a < 0.05, "barra some com fôlego cheio (alfa %.2f)" % barra.modulate.a)
	Settings.stamina_ativa = false
	s.stamina = 0.2
	for _i in 60:
		barra._process(1.0 / 60.0)
	_ok(barra.modulate.a < 0.05, "com fôlego desligado a barra não aparece")
	Settings.stamina_ativa = true
	barra.free()

	# 4. bots: pulo de desatolamento é um aperto por vez, com intervalo mínimo
	var bot := BotBrain.new()
	bot._rng.seed = 12345
	var pulos: Array = []
	var t_bot := 0.0
	for _i in 64 * 20:
		t_bot += 1.0 / 64.0
		bot._now = t_bot
		if bot._quer_pulo():
			pulos.append(t_bot)
	var gap_min := 99.0
	for i in range(1, pulos.size()):
		gap_min = minf(gap_min, float(pulos[i]) - float(pulos[i - 1]))
	_ok(pulos.size() >= 5 and gap_min >= BotBrain.PULO_INTERVALO - 0.001,
		"bot: %d apertos em 20 s, intervalo mínimo %.2f s" % [pulos.size(), gap_min])
	bot.free()

	s.queue_free()
	print("FOLEGO_CONFIG %s (%d falhas)" % ["PASSOU" if falhas == 0 else "FALHOU", falhas])
	get_tree().quit(0 if falhas == 0 else 1)
