extends Node
## QA v2 no jogo real (br_match): --modo=armas | pontes | zumbis
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/qa_v2/"
var m: BRMatch
var pc: PlayerController
var sol: Soldier
var R := {}
func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(func() -> void: R["timeout"] = true; _fim(); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	sol = m.local_player
	pc = sol.controller as PlayerController
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	_teleporta(-345.0, 352.0, 40.0)
	await _frames(60)
	var modo := String(Game.test_args.get("modo", "armas"))
	if modo == "armas": await _armas()
	elif modo == "pontes": await _pontes()
	elif modo == "cenas": await _cenas()
	else: await _zumbis()
	_fim()
	print("QA2_JOGO_OK ", modo)
	get_tree().quit(0)
func _fim() -> void:
	var f := FileAccess.open(OUT + "jogo_%s.json" % String(Game.test_args.get("modo", "armas")), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " ")); f.close()
func _teleporta(x: float, z: float, yaw_deg: float) -> void:
	for a in ["move_forward", "sprint", "alt_fire", "fire"]: Input.action_release(a)
	var y: float = m.ilha.terrain.height_world(x, z)
	sol.global_position = Vector3(x, y + 0.2, z)
	sol.velocity = Vector3.ZERO
	sol.yaw = deg_to_rad(yaw_deg)
	sol.pitch = 0.0
	sol.reset_physics_interpolation()
func _frames(n: int) -> void:
	for _i in n: await get_tree().process_frame
func _uid(id: String) -> int:
	for it in m.br_bag.items:
		if String(it.id) == id: return int(it.uid)
	return -1
func _janela(dur: float) -> Dictionary:
	var t0 := Time.get_ticks_usec(); var ult := t0; var mx := 0.0; var n := 0; var s := 0.0
	while (Time.get_ticks_usec() - t0) / 1e6 < dur:
		await get_tree().process_frame
		var a := Time.get_ticks_usec(); var ms := (a - ult) / 1000.0; ult = a
		mx = maxf(mx, ms); s += ms; n += 1
	return {"max_ms": snappedf(mx, 0.1), "med_ms": snappedf(s / maxf(n, 1), 0.1), "n": n}
func _rosa(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			if c.r > 0.7 and c.b > 0.6 and c.g < 0.5 and c.r - c.g > 0.3: n += 1
	return n * 9
func _cap(nome: String) -> int:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + nome + ".png")
	return _rosa(img)
func _armas() -> void:
	for id in String(Game.test_args.get("armas", "m107,m4,m249,glock")).split(","):
		var r := {}
		for it in m.br_bag.items.duplicate():
			if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "mosin", "glock", "usp", "reddot", "acog"]:
				m.br_bag.remove_item(int(it.uid))
		for it in m.br_bag.items.duplicate():
			if String(it.id).begins_with("ammo_") and String(it.id) != "ammo_9mm":
				m.br_bag.remove_item(int(it.uid))
		var am := {"m107": "ammo_127", "m4": "ammo_556", "m249": "ammo_556", "ak47": "ammo_762"}
		if am.has(id): m.br_bag.add_item(am[id], 20 if id == "m107" else 60)
		r["bag_kg_antes"] = m.br_bag.weight_kg()
		var okadd = m.br_bag.add_item(id, 1, Vector2i(-1, -1), {"mag": 30})
		r["add_item"] = okadd
		var u := _uid(id)
		r["uid"] = u
		if u < 0:
			r["bag_itens"] = m.br_bag.items.map(func(i): return String(i.id))
			R[id] = r
			continue
		m._equip_br_weapon(u)
		await _frames(90)
		var w = sol.current()
		w.mag = 30
		_teleporta(-345.0, 352.0, 40.0)
		await _frames(30)
		r["parado_rosa"] = await _cap("arma_%s_parado" % id)
		Input.action_press("fire")
		r["rajada"] = await _janela(1.2)
		r["rosa_rajada"] = await _cap("arma_%s_rajada" % id)
		Input.action_release("fire")
		r["mag_apos"] = w.mag
		await _frames(40)
		w.mag = 3
		sol.start_reload()
		var t0 := Time.get_ticks_msec()
		var rj = await _janela(1.0)
		r["recarga_rosa"] = await _cap("arma_%s_recarga" % id)
		var lim := Time.get_ticks_msec() + 9000
		r["reserva_antes"] = w.reserve
		while w.mag < 8 and Time.get_ticks_msec() < lim:
			await _frames(5)
		r["recarga_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
		r["mag_pos_recarga"] = w.mag
		r["recarga_pico"] = rj
		await _frames(30)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		var p0 := sol.global_position
		await _frames(25)
		r["sprint"] = await _janela(1.5)
		r["sprint_desloc_m"] = snappedf((sol.global_position - p0).length(), 0.1)
		r["sprint_rosa"] = await _cap("arma_%s_sprint" % id)
		Input.action_release("move_forward")
		Input.action_release("sprint")
		_teleporta(-345.0, 352.0, 40.0)
		await _frames(30)
		Input.action_press("alt_fire")
		await _frames(40)
		r["ads"] = await _janela(0.8)
		r["ads_rosa"] = await _cap("arma_%s_ads" % id)
		Input.action_release("alt_fire")
		await _frames(30)
		R[id] = r
		print("ARMA ", id, " ", JSON.stringify(r))
func _pontes() -> void:
	var ca: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/cenario_atualizacao.json"))
	var lista: Array = ca.get("pontes", []).duplicate()
	lista.append({"nome": "Crista da Barragem", "centro": [-100.0, -86.0], "direcao_deg": -45.0, "comprimento_m": 40.0, "largura_m": 6.0, "agua_m": 14.5})
	R["pontes"] = []
	for p in lista:
		var dirv := Vector2(cos(deg_to_rad(float(p.direcao_deg))), sin(deg_to_rad(float(p.direcao_deg))))
		var c := Vector2(float(p.centro[0]), float(p.centro[1]))
		var meio := float(p.comprimento_m) * 0.5 + 6.0
		for sentido in [1.0, -1.0]:
			var a: Vector2 = c - dirv * meio * sentido
			var b: Vector2 = c + dirv * meio * sentido
			var yaw := atan2(-(b - a).x, -(b - a).y)
			_teleporta(a.x, a.y, rad_to_deg(yaw))
			await _frames(40)
			var r := {"nome": String(p.nome), "sentido": sentido, "inicio": [a.x, a.y]}
			var ymin := 1e9
			var ymax := -1e9
			var dist_total := (b - a).length()
			Input.action_press("move_forward")
			var t0 := Time.get_ticks_msec()
			var chegou := false
			var ult_s := 0
			var pos_s := sol.global_position
			var preso := false
			while Time.get_ticks_msec() - t0 < 20000:
				await get_tree().process_frame
				var pos := sol.global_position
				if Time.get_ticks_msec() - t0 - ult_s >= 3000:
					ult_s = Time.get_ticks_msec() - t0
					if (pos - pos_s).length() < 1.0 and not preso:
						preso = true
						var fw := -sol.global_transform.basis.z
						var esp := sol.get_world_3d().direct_space_state
						var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.9, 0), pos + Vector3(0, 0.9, 0) + fw * 3.0)
						var h := esp.intersect_ray(q)
						r["preso_em"] = [pos.x, pos.y, pos.z]
						r["obstaculo"] = str(h.collider.get_path()) if h and h.has("collider") else "nada_no_raio_frontal"
						r["obstaculo_dist"] = snappedf((h.position - pos).length(), 0.1) if h and h.has("position") else -1
						var q2 := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos + Vector3(0, 0.3, 0) + fw * 3.0)
						var h2 := esp.intersect_ray(q2)
						r["obstaculo_baixo"] = str(h2.collider.get_path()) if h2 and h2.has("collider") else "nada"
						await _cap("ponte_preso_%s_%d" % [str(p.nome).replace(" ", "_"), int(sentido)])
					pos_s = pos
				ymin = minf(ymin, pos.y)
				ymax = maxf(ymax, pos.y)
				var prog := (Vector2(pos.x, pos.z) - a).dot((b - a).normalized())
				if prog >= dist_total - 1.0:
					chegou = true
					break
			Input.action_release("move_forward")
			r["chegou"] = chegou
			r["preso"] = preso
			r["tempo_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
			r["y_min"] = snappedf(ymin, 0.01)
			r["y_max"] = snappedf(ymax, 0.01)
			r["fim"] = [sol.global_position.x, sol.global_position.z]
			R["pontes"].append(r)
			print("PONTE ", JSON.stringify(r))
func _zumbis() -> void:
	var Z: PackedScene = load("res://core/zombie.tscn")
	var dir_node: Node = m.ilha.get_node_or_null("ZombieDirector")
	R["director"] = dir_node != null
	var res := []
	for cenario in [["perto4", 4.0, false], ["perto8", 8.0, false], ["tiro20", 20.0, true]]:
		sol.health = 100
		_teleporta(-345.0, 352.0, 40.0)
		await _frames(30)
		var zs := []
		for i in 2:
			var z := Z.instantiate() as ZombieEnemy
			dir_node.add_child(z)
			var ang := deg_to_rad(40.0 + 180.0 + (i - 0.5) * 50.0)
			var d: float = cenario[1] + i * 5.0
			var px: float = sol.global_position.x + cos(ang) * d
			var pz: float = sol.global_position.z + sin(ang) * d
			z.global_position = Vector3(px, m.ilha.terrain.height_world(px, pz) + 0.3, pz)
			z.set_target(sol)
			zs.append(z)
		var t0 := Time.get_ticks_msec()
		var primeiro := -1
		var hp_min := 100
		var dmin := 1e9
		if cenario[2]:
			Input.action_press("fire")
		if cenario[0] == "fugir_sprint":
			Input.action_press("move_forward")
			Input.action_press("sprint")
		while Time.get_ticks_msec() - t0 < 25000:
			await get_tree().process_frame
			if sol.health < hp_min:
				hp_min = sol.health
				if primeiro < 0: primeiro = Time.get_ticks_msec() - t0
			for z in zs:
				if is_instance_valid(z): dmin = minf(dmin, (z.global_position - sol.global_position).length())
			if sol.health <= 0: break
		Input.action_release("fire")
		Input.action_release("move_forward")
		Input.action_release("sprint")
		var est := []
		for z in zs:
			if is_instance_valid(z): est.append([str(z.state), snappedf((z.global_position - sol.global_position).length(), 0.1)])
		res.append({"cenario": cenario[0], "dist_inicial": cenario[1], "ms_primeiro_dano": primeiro, "hp_min": hp_min, "dist_min": snappedf(dmin, 0.1), "estado_final": est, "morreu": sol.health <= 0})
		for z in zs:
			if is_instance_valid(z): z.queue_free()
		await _frames(20)
	R["cenarios"] = res

func _cenas() -> void:
	for c in [["quartel_a", 330.0, -300.0, 0.0], ["quartel_b", 330.0, -300.0, 120.0], ["morro", -320.0, -45.0, 60.0]]:
		_teleporta(c[1], c[2], c[3])
		await _frames(90)
		R[c[0]] = await _janela(2.0)
		await _cap("cena_" + c[0])
