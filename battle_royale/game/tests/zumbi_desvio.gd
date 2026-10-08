extends Node3D
## Teste de desvio de obstáculos: zumbi persegue um alvo parado atrás de cada obstáculo (barril, cerca longa, muro em L,
## carro, mureta baixa, porta fechada). Mede tempo, travamentos (tempo encostado sem progresso) e salva PNG de cima.

const ALVO_Z := -16.0
const LIMITE := 45.0
const PX := 14.0
var cenarios: Array = []   # {nome, rects[[cx,cz,w,d,h]], zumbi, alvo, trilha, t, ok, parado}


func _ready() -> void:
	var chao := StaticBody3D.new()
	chao.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1000, 1, 1000)
	cs.shape = bx
	cs.position.y = -0.5
	chao.add_child(cs)
	add_child(chao)
	var defs := [
		["barril", [[0.0, -8.0, 0.9, 0.9, 1.2]]],
		["cerca_longa", [[0.0, -8.0, 24.0, 0.15, 1.8]]],
		["muro_U_concavo", [[0.0, -8.0, 10.0, 0.3, 2.5], [5.0, -5.0, 0.3, 6.0, 2.5], [-5.0, -5.0, 0.3, 6.0, 2.5]]],
		["carro", [[0.0, -8.0, 2.0, 4.5, 1.5]]],
		["mureta_baixa", [[0.0, -8.0, 24.0, 0.4, 0.9]]],
		["porta_fechada", [[-6.5, -8.0, 11.0, 0.3, 2.6], [6.5, -8.0, 11.0, 0.3, 2.6], [-30.0, -8.0, 40.0, 0.3, 2.6], [30.0, -8.0, 40.0, 0.3, 2.6]]],
	]
	var i := 0
	for d in defs:
		var ox := i * 100.0
		var c := {"nome": d[0], "rects": d[1], "ox": ox, "trilha": [], "t": -1.0, "parado": 0.0, "ult": Vector3.ZERO}
		for r in d[1]:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			var s := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(r[2], r[4], r[3])
			s.shape = b
			sb.position = Vector3(ox + r[0], r[4] * 0.5, r[1])
			sb.add_child(s)
			add_child(sb)
		if d[0] == "porta_fechada":
			var porta := PortaCasa.new()
			porta.position = Vector3(ox - 0.5, 0.0, -8.0)
			add_child(porta)
			c["porta"] = porta
		var z := ZombieEnemy.new()
		z._variant_index = 0
		z.position = Vector3(ox, 0.05, 0.0)
		add_child(z)
		var alvo := Node3D.new()
		alvo.add_to_group("zombie_targets")
		alvo.position = Vector3(ox, 0.0, ALVO_Z)
		add_child(alvo)
		c["zumbi"] = z
		c["alvo"] = alvo
		cenarios.append(c)
		i += 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	for c in cenarios:
		var z: ZombieEnemy = c["zumbi"]
		z.set_target(c["alvo"])
		z.rotation.y = 0.0
		z._set_state(ZombieEnemy.State.CHASE)
		c["ult"] = z.global_position
	var t := 0.0
	var feitos := 0
	while t < LIMITE and feitos < cenarios.size():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		for c in cenarios:
			if c["t"] >= 0.0:
				continue
			var z: ZombieEnemy = c["zumbi"]
			z._time_without_sight = 0.0
			if z.state != ZombieEnemy.State.CHASE and z.state != ZombieEnemy.State.ATTACK:
				z._set_state(ZombieEnemy.State.CHASE)
			var p := z.global_position
			if int(t * 20.0) != int((t - 0.0167) * 20.0):
				c["trilha"].append(p)
			# travado = quase sem deslocamento por >1.2 s fora de ataque
			if (p - c["ult"]).length() < 0.004 and z.state == ZombieEnemy.State.CHASE:
				c["parado"] += get_physics_process_delta_time()
			else:
				c["parado"] = 0.0
			c["ult"] = p
			if c["parado"] > 1.2:
				c["travou"] = true
			if z.state == ZombieEnemy.State.ATTACK or Vector2(p.x - c["alvo"].global_position.x, p.z - c["alvo"].global_position.z).length() < 1.9:
				c["t"] = t
				feitos += 1
	var tudo_ok := true
	var out := OS.get_environment("ZUMBI_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://").path_join("../docs/zumbi_desvio")
	DirAccess.make_dir_recursive_absolute(out)
	for c in cenarios:
		var z: ZombieEnemy = c["zumbi"]
		var ok: bool = c["t"] >= 0.0 and not c.get("travou", false)
		if not ok:
			tudo_ok = false
		print("DESVIO %s alcancou=%s tempo=%.1fs travou=%s saltos=%d travamentos_internos=%d" % [c["nome"], str(c["t"] >= 0.0), c["t"], str(c.get("travou", false)), z.contagem_saltos, z.contagem_travamentos])
		_png(c, out)
	print("ZUMBI_DESVIO_", "OK" if tudo_ok else "FALHA")
	get_tree().quit(0 if tudo_ok else 1)


func _png(c: Dictionary, out: String) -> void:
	var W := 40.0
	var Z0 := -20.0
	var Z1 := 4.0
	var img := Image.create_empty(int(W * PX), int((Z1 - Z0) * PX), false, Image.FORMAT_RGB8)
	img.fill(Color(0.18, 0.2, 0.18))
	var ox: float = c["ox"]
	for r in c["rects"]:
		_rect(img, r[0] + W * 0.5, r[1] - Z0, r[2], r[3], Color(0.8, 0.3, 0.3), Z1 - Z0)
	var pa := Vector2(c["alvo"].global_position.x - ox + W * 0.5, c["alvo"].global_position.z - Z0)
	_rect(img, pa.x, pa.y, 0.8, 0.8, Color(0.3, 0.9, 0.3), Z1 - Z0)
	for p in c["trilha"]:
		_rect(img, p.x - ox + W * 0.5, p.z - Z0, 0.18, 0.18, Color(1, 1, 0.2), Z1 - Z0)
	if not c["trilha"].is_empty():
		var p0: Vector3 = c["trilha"][0]
		_rect(img, p0.x - ox + W * 0.5, p0.z - Z0, 0.5, 0.5, Color(0.3, 0.6, 1.0), Z1 - Z0)
	img.save_png(out.path_join("desvio_%s.png" % c["nome"]))


func _rect(img: Image, cx: float, cz: float, w: float, d: float, col: Color, zspan: float) -> void:
	var x0 := int((cx - w * 0.5) * PX)
	var x1 := int((cx + w * 0.5) * PX)
	var y0 := int((cz - d * 0.5) * PX)
	var y1 := int((cz + d * 0.5) * PX)
	for y in range(maxi(y0, 0), mini(y1 + 1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1 + 1, img.get_width())):
			img.set_pixel(x, y, col)
