extends Node
## Movimento do Soldier real (sem partida): coyote time, buffer do pulo, segurar pulo não repete,
## agachar com teto baixo, stamina de corrida. Chão grande em y=0 e uma plataforma isolada para a beirada.
## Uso: godot --path game res://tests/movimento_aaa.tscn   (linhas MOV_AAA ...; falha = FAIL e exit code 1)

var s: Soldier
var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("MOV_AAA %s %s" % ["ok  " if cond else "FAIL", msg])
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


func _zerar(pos: Vector3) -> void:
	s.global_position = pos
	s.velocity = Vector3.ZERO
	s.yaw = 0.0
	s.pitch = 0.0
	s.in_move = Vector2.ZERO
	s.in_jump = false
	s.in_crouch = false
	s.in_sprint = false
	s.reset_physics_interpolation()


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func() -> void: print("MOV_AAA TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	_caixa(Vector3(0, -0.25, 0), Vector3(200, 0.5, 200))      # chão plano, topo em y = 0
	_caixa(Vector3(150, -0.25, 150), Vector3(4, 0.5, 4))      # plataforma isolada (beirada em z = 152)
	s = Soldier.new()
	s.is_local = true
	add_child(s)
	await _frames(5)
	await _testes()
	print("MOV_AAA %s (%d falhas)" % ["PASSOU" if falhas == 0 else "FALHOU", falhas])
	get_tree().quit(0 if falhas == 0 else 1)


func _testes() -> void:
	# 1. parado no chão
	_zerar(Vector3(0, 0.1, 0))
	await _frames(30)
	_ok(s.is_on_floor(), "parado no chão plano")

	# 2. coyote: anda para fora da beirada e aperta pulo logo depois -> pula
	_zerar(Vector3(150, 0.1, 149.0))
	s.yaw = PI                                   # frente = +Z (para a beirada)
	await _frames(20)
	s.in_move = Vector2(0, 1)
	var n := 0
	while s.is_on_floor() and n < 300:
		await _frames(1)
		n += 1
	s.in_move = Vector2.ZERO
	s.in_jump = true
	await _frames(1)
	s.in_jump = false
	var vy := s.velocity.y
	_ok(vy > 3.0, "coyote: pulo 1 quadro depois de sair da beirada (vy=%.2f)" % vy)

	# 3. sem coyote: ~0,25 s depois de sair da beirada, o pulo não salta
	_zerar(Vector3(150, 0.1, 149.0))
	s.yaw = PI
	await _frames(20)
	s.in_move = Vector2(0, 1)
	n = 0
	while s.is_on_floor() and n < 300:
		await _frames(1)
		n += 1
	s.in_move = Vector2.ZERO
	await _frames(16)
	var no_ar := not s.is_on_floor()
	s.in_jump = true
	await _frames(1)
	s.in_jump = false
	_ok(no_ar and s.velocity.y < 0.0, "sem coyote: pulo após ~0,25 s no ar não salta (no_ar=%s vy=%.2f)" % [str(no_ar), s.velocity.y])

	# 4. buffer: aperto a ~0,05 s do pouso -> pula ao pousar; aperto a ~0,25 s do pouso -> não pula
	var perto: Dictionary = await _salto_no_pouso(0.12)
	_ok(perto.janela <= Soldier.JUMP_BUFFER and perto.vy > 3.0,
		"buffer: aperto %.3f s antes do pouso salta (vy=%.2f)" % [perto.janela, perto.vy])
	var longe: Dictionary = await _salto_no_pouso(0.6)
	_ok(longe.janela > Soldier.JUMP_BUFFER and longe.vy < 1.0,
		"buffer: aperto %.3f s antes do pouso não salta (vy=%.2f)" % [longe.janela, longe.vy])

	# 5. segurar o pulo não repete: uma única saída do chão
	_zerar(Vector3(0, 0.1, 0))
	await _frames(30)
	s.in_jump = true
	var saidas := 0
	var estava := true
	for _i in 120:
		await _frames(1)
		var no_chao := s.is_on_floor()
		if estava and not no_chao:
			saidas += 1
		estava = no_chao
	s.in_jump = false
	_ok(saidas == 1, "segurar pulo não repete ao pousar (saídas do chão = %d)" % saidas)

	# 6. agachar: a cápsula encolhe em transição (não de uma vez)
	_zerar(Vector3(0, 0.1, 0))
	await _frames(30)
	s.in_crouch = true
	await _frames(1)
	var meio := s.crouch
	await _frames(30)
	_ok(meio > 0.0 and meio < 0.9 and s.crouch > 0.99 and absf(s._capsule.height - Soldier.CROUCH_HEIGHT) < 0.01,
		"agachar suave: %.2f no 1º quadro, %.2f depois; altura %.2f m" % [meio, s.crouch, s._capsule.height])

	# 7. teto baixo (face de baixo em y = 1,6 m): não levanta; sem teto, levanta
	var teto_b := StaticBody3D.new()
	teto_b.collision_layer = Soldier.LAYER_WORLD
	teto_b.collision_mask = 0
	var cs_t := CollisionShape3D.new()
	var bs_t := BoxShape3D.new()
	bs_t.size = Vector3(6, 0.2, 6)
	cs_t.shape = bs_t
	teto_b.add_child(cs_t)
	add_child(teto_b)
	teto_b.global_position = Vector3(0, 1.7, 0)
	await _frames(3)
	s.in_crouch = false
	await _frames(40)
	_ok(s.crouch > 0.99 and s._capsule.height < Soldier.STAND_HEIGHT - 0.2,
		"teto baixo: continua agachado (crouch %.2f, altura %.2f m)" % [s.crouch, s._capsule.height])
	teto_b.queue_free()
	await _frames(3)
	await _frames(40)
	_ok(s.crouch < 0.01, "sem teto: levanta de novo (crouch %.2f)" % s.crouch)

	# 8. stamina: corre até zerar, para de correr, recupera parado e volta a correr com 25%
	_zerar(Vector3(0, 0.1, 0))
	s.yaw = PI
	await _frames(20)
	s.in_move = Vector2(0, 1)
	s.in_sprint = true
	await _frames(5)
	_ok(s.is_sprinting, "corre com Shift e fôlego cheio")
	var t0 := s.t
	n = 0
	while s.is_sprinting and n < 1500:
		await _frames(1)
		n += 1
		if s.global_position.z > 60.0:
			s.global_position.z = -60.0
	var gasto := s.t - t0
	_ok(gasto > 7.0 and gasto < 11.0 and s.stamina < 0.01,
		"stamina: correu %.1f s até zerar (stamina %.3f)" % [gasto, s.stamina])
	await _frames(20)
	_ok(not s.is_sprinting, "stamina zerada: não corre mesmo segurando Shift")
	s.in_move = Vector2.ZERO
	s.in_sprint = false
	n = 0
	while s.stamina < 0.25 and n < 1500:
		await _frames(1)
		n += 1
	_ok(s.stamina >= 0.25, "stamina recupera parado (%.2f)" % s.stamina)
	s.in_move = Vector2(0, 1)
	s.in_sprint = true
	await _frames(10)
	_ok(s.is_sprinting, "com 25% de stamina volta a correr")
	s.in_sprint = false
	s.in_move = Vector2.ZERO

	# 9. parede: andar em diagonal contra ela desliza ao longo dela (não gruda nem para)
	_caixa(Vector3(10.5, 1.0, 0), Vector3(1, 2, 200))         # parede em x = 10..11, de z = -100 a 100
	_zerar(Vector3(8.0, 0.1, 0))
	await _frames(20)
	s.in_move = Vector2(0.7071, -0.7071)                     # direita + trás = diagonal (+X, +Z) contra a parede
	await _frames(20)
	var z0 := s.global_position.z
	await _frames(40)
	var dz := s.global_position.z - z0
	var vz := s.velocity.z
	s.in_move = Vector2.ZERO
	_ok(s.global_position.x < 9.7 and dz > 0.8 and s.is_on_floor(),
		"parede diagonal: para em x=%.2f e desliza %.2f m ao longo dela" % [s.global_position.x, dz])
	_ok(vz > 2.0, "parede diagonal: a velocidade ao longo da parede não zera (vz=%.2f)" % vz)


## Anda parado no ar (solta de altura_disparo m do chão) e aperta pulo quando passa por essa altura.
## Devolve o tempo entre o aperto e o pouso (s) e a maior velocidade vertical nos 3 quadros seguintes.
func _salto_no_pouso(altura_disparo: float) -> Dictionary:
	_zerar(Vector3(0, 0.6, 0))
	await _frames(2)
	var n := 0
	while s.global_position.y > altura_disparo and n < 200:
		await _frames(1)
		n += 1
	var t_aperto := s.t
	s.in_jump = true
	await _frames(1)
	s.in_jump = false
	n = 0
	while not s.is_on_floor() and n < 200:
		await _frames(1)
		n += 1
	var t_pouso := s.t
	var vy_max := -99.0
	for _i in 3:
		await _frames(1)
		vy_max = maxf(vy_max, s.velocity.y)
	return {"janela": t_pouso - t_aperto, "vy": vy_max}
