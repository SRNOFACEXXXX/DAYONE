extends Node3D
## Executar somente quando coordenado: --headless --path game res://tests/br_stability.tscn
## Fixtures reposicionam entre casos; nenhuma correção de posição durante as simulações.
## Não usa br_bots, capturas, renderização, recursos da ilha ou temporizadores de parede.

class TestMatch extends BRMatch:
	func _ready() -> void:
		pass

class TestIsland extends Node3D:
	var terrain: IlhaTerrain
	var layout := {"aviao": {"altitude_m": 300.0}}

var errors := 0
var br: BRMatch
var actor: Soldier

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error("BR_STABILITY: " + message)

func _box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = at
	add_child(body)

func _fixture(at: Vector3) -> void:
	actor.global_position = at
	actor.velocity = Vector3.ZERO
	actor.in_move = Vector2.ZERO
	actor.yaw = 0.0
	actor.alive = true
	actor.external_motion = true
	actor.frozen = true
	br.estado[actor] = "para"

func _descent(label: String, at: Vector3, expected_y: float, dt: float) -> void:
	_fixture(at)
	var landed := false
	for frame in 900:
		var before := actor.global_position
		br._descer(actor, dt)
		_check(actor.global_position.distance_to(before) <= BRMatch.PARA_V * dt + 0.1, label + ": salto de posição")
		_check(actor.global_position.y >= expected_y - 0.05, label + ": atravessou piso")
		if br.estado[actor] == "chao":
			landed = true
			break
	_check(landed, label + ": não pousou")
	_check(absf(actor.position.y - expected_y) < 0.1, label + ": altura incorreta")
	_check(not actor.external_motion and not actor.frozen, label + ": posse de movimento não transferida")
	for frame in 120:
		actor._move(1.0 / 60.0)
	_check(absf(actor.position.y - expected_y) < 0.1, label + ": instável após pouso")

func _run() -> void:
	br = TestMatch.new()
	br.set_process(false)
	br.set_physics_process(false)
	add_child(br)
	var island := TestIsland.new()
	island.terrain = IlhaTerrain.new()
	island.terrain.heights.resize(IlhaTerrain.N * IlhaTerrain.N)
	island.terrain.heights.fill(-12.0)
	br.ilha = island
	br.add_child(island)
	br._criar_limites()
	# Piso seco, telhado fino, fundo submerso e parede vertical.
	_box(Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	_box(Vector3(3, 0.15, 4), Vector3(2, 0.3, 3))
	_box(Vector3(-5, 1.0, 4), Vector3(2, 2, 3))
	_box(Vector3(30, 4.95, 0), Vector3(20, 0.1, 20))
	_box(Vector3(60, -12.5, 0), Vector3(20, 1, 20))
	_box(Vector3(90, 0, 0), Vector3(0.1, 40, 20))
	_box(Vector3(100, -12.5, 0), Vector3(25, 1, 20))
	actor = Soldier.new()
	add_child(actor)
	actor.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_descent("terra", Vector3(0, 8, 0), 0.0, 1.0 / 60.0)
	_descent("telhado fino/dt alto", Vector3(30, 8, 0), 5.0, 0.5)
	_descent("mar sem piso em y=0", Vector3(60, 8, 0), -12.0, 1.0 / 60.0)
	_fixture(Vector3(88, 8, 0))
	actor.in_move = Vector2.RIGHT
	for frame in 120:
		br._descer(actor, 1.0 / 60.0)
	_check(actor.position.x < 89.6, "atravessou parede na descida")
	_check(actor.position.y < 1.0, "parede foi confundida com pouso")
	for side in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		_fixture(side * 595.0 + Vector3.UP * 30.0)
		actor.in_move = Vector2(side.x, -side.z)
		for frame in 60:
			br._descer(actor, 1.0 / 60.0)
		_check(absf(actor.position.x) < 598.0 and absf(actor.position.z) < 598.0, "saiu da cobertura do heightmap")
	# Degrau válido mantém continuidade; obstáculo alto não vira teleporte vertical.
	_fixture(Vector3(0, 0.05, 4))
	actor.external_motion = false
	actor.frozen = false
	for frame in 10:
		actor._move(1.0 / 60.0)
	actor.in_move = Vector2.RIGHT
	var climbed := false
	for frame in 45:
		var before := actor.position
		actor._move(1.0 / 60.0)
		_check(actor.position.y - before.y <= Soldier.STEP_HEIGHT + 0.03, "step excedeu altura máxima")
		_check(Vector2(actor.position.x - before.x, actor.position.z - before.z).length() < 0.15, "step excedeu movimento horizontal")
		climbed = climbed or actor.position.y > 0.25
	_check(climbed and actor.position.x > 2.0, "degrau de 30 cm não foi transposto: pos=%s floor=%s vel=%s" % [actor.position, actor.is_on_floor(), actor.velocity])
	_fixture(Vector3(-2, 0.05, 4))
	actor.external_motion = false
	actor.frozen = false
	actor.in_move = Vector2.LEFT
	for frame in 90:
		actor._move(1.0 / 60.0)
	_check(actor.position.x > -3.7 and actor.position.y < 0.1, "step escalou parede de 2 m")
	# Reset de rodada não herda voo/congelamento/suavização.
	actor.eye_offset_smooth = -0.4
	actor.reset_for_round(false)
	_check(not actor.external_motion and not actor.frozen and actor.eye_offset_smooth == 0.0, "reset herda movimento externo")
	# Cápsula desativada na morte: Soldier não pode continuar aplicando gravidade.
	actor.alive = false
	actor._shape.disabled = true
	var dead_position := actor.position
	for frame in 120:
		actor._physics_process(1.0 / 60.0)
	_check(actor.position == dead_position, "cadáver sem cápsula cai no limbo")
	island.terrain.free()
	print("BR_STABILITY %s errors=%d" % ["PASS" if errors == 0 else "FAIL", errors])
	get_tree().quit(0 if errors == 0 else 1)
