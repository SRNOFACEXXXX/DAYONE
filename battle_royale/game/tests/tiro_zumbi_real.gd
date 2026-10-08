extends Node
## TIRO REAL em ZUMBI na ilha completa (BRMatch real, ZombieDirector real, AK real, projétil real):
## para cada distância: 10 tiros mirados no peito de um zumbi parado; conta impactos no zumbi e mede a vida.
## Uso: godot --path game res://tests/tiro_zumbi_real.tscn   -> TIRO_ZUMBI_OK / TIRO_ZUMBI_FALHOU
var m: BRMatch
var s: Soldier
var falhas: Array = []
var impactos: Dictionary = {}   # nome do zumbi -> n
var outros: Array = []


func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(func() -> void: print("TIRO_ZUMBI_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	s = m.local_player
	s.godmode = true
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	m.br_bag.add_item("backpack_medium")
	m.br_bag.equip_backpack(int(m.br_bag.items[0].uid))
	m.br_bag.add_item("ak47", 1, Vector2i(-1, -1), {"mag": 30})
	m._equip_br_weapon(int(m.br_bag.items[m.br_bag.items.size() - 1].uid))
	s.bala_impacto.connect(_on_impacto)
	await _f(60)
	var base := Vector3(-345.0, 0.0, 352.0)
	var yaw := deg_to_rad(40.0)
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var dd := m.ilha.get_node("ZombieDirector")
	for dist in [2.0, 4.0, 8.0, 15.0, 30.0, 60.0, 100.0]:
		var p0 := base
		p0.y = m.ilha.terrain.height_world(p0.x, p0.z) + 0.1
		s.global_position = p0
		s.velocity = Vector3.ZERO
		s.yaw = yaw
		s.pitch = 0.0
		s.reset_physics_interpolation()
		var zp: Vector3 = base + dir * dist
		zp.y = m.ilha.terrain.height_world(zp.x, zp.z) + 0.05
		var z: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
		z.name = "Z%d" % int(dist)
		dd.add_child(z)
		z.global_position = zp
		z.set_demo_state(&"idle")
		await _f(40)
		var peito := z.global_position + Vector3.UP * 1.2
		var olho := s.eye_position()
		var d3 := peito - olho
		s.yaw = atan2(-d3.x, -d3.z)
		s.pitch = asin(d3.y / d3.length())
		s.aim_amount = 1.0
		await _f(10)
		var vida0 := z.health
		var disparos := 0
		for i in 10:
			if z.state == ZombieEnemy.State.DEAD:
				break
			var ws := s.current()
			ws.mag = 30
			s.next_attack = 0.0
			s.shots_fired = 0.0
			s.fire_inacc = 0.0
			s._fire_bullet(ws)
			disparos += 1
			await _f(14)
		await _f(30)
		var n: int = int(impactos.get(z.name, 0))
		var gastou: int = vida0 - z.health
		print("DIST %5.0f m | tiros %2d | impactos no zumbi %2d | vida %3d -> %3d | estado=%s lod=%d | visivel=%s" % [dist, disparos, n, vida0, z.health, ZombieEnemy.State.keys()[z.state], z.lod, z._visual_root.visible if z._visual_root else "?"])
		if n == 0 or gastou <= 0:
			falhas.append("dist %d: nenhum dano" % int(dist))
		z.queue_free()
		await _f(5)
	print("OUTROS_IMPACTOS ", outros.slice(0, 12))
	print("TIRO_ZUMBI_OK" if falhas.is_empty() else "TIRO_ZUMBI_FALHOU %s" % str(falhas))
	get_tree().quit(0 if falhas.is_empty() else 1)


func _on_impacto(info: Dictionary) -> void:
	if info.has("zombie") and is_instance_valid(info["zombie"]):
		var n := String(info["zombie"].name)
		impactos[n] = int(impactos.get(n, 0)) + 1
	else:
		outros.append([snappedf(float(info.get("dist", 0.0)), 0.1), str(info.get("surface", "?"))])


func _f(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
