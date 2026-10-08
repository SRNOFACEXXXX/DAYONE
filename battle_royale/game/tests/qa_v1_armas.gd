extends Node
## QA v1: armas no jogo real (br_match). Por arma: equipar, rajada, recarga, ADS, sprint, troca. Max quadro por evento + magenta.
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/qa_v1"
var m: BRMatch
var pc: PlayerController
var sol: Soldier
var res := {}
var uid := {}
func _ready() -> void:
	get_tree().create_timer(195.0).timeout.connect(func() -> void: print("QA_ARMAS_TIMEOUT ", JSON.stringify(res)); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	sol = m.local_player
	pc = sol.controller as PlayerController
	var hx: float = m.ilha.terrain.height_world(-345.0, 352.0)
	sol.global_position = Vector3(-345.0, hx + 0.1, 352.0)
	sol.yaw = deg_to_rad(40.0)
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	await _f(60)
	var ids: Array = String(Game.test_args.get("armas", "m4,ak47,m249,m107,uzi,glock")).split(",")
	for id in ids:
		m.br_bag.add_item(id, 1, Vector2i(-1, -1), {"mag": 30})
		var ok := false
		for it in m.br_bag.items:
			if String(it.id) == id:
				uid[id] = int(it.uid); ok = true
		res["_add_" + id] = ok
	await _f(30)
	for id in ids:
		if not uid.has(id): continue
		var r := {}
		r["equipar"] = await _ev(func() -> void: m._equip_br_weapon(uid[id]), 1.5, false)
		r["arma_atual"] = String(sol.current_def().id) if sol.current_def() else "?"
		await _f(30)
		sol.current().mag = 30; sol.current().reserve = 200
		r["rajada"] = await _ev(func() -> void: Input.action_press("fire"), 1.2, true)
		Input.action_release("fire")
		await _f(20)
		var mag0: int = sol.current().mag
		sol.current().mag = 2
		r["recarga"] = await _ev(func() -> void: sol.start_reload(), 4.5, true)
		r["recarga_encheu"] = sol.current().mag > 2
		await _f(20)
		r["ads"] = await _ev(func() -> void: Input.action_press("alt_fire"), 1.0, true, id + "_ads")
		Input.action_release("alt_fire")
		await _f(20)
		var vm = pc.viewmodel
		r["ads_sw_antes"] = vm._sprint_w
		r["sprint"] = await _ev(func() -> void: Input.action_press("move_forward"); Input.action_press("sprint"), 1.2, true, id + "_sprint")
		r["sprint_w_durante"] = vm._sprint_w
		r["is_sprinting"] = sol.is_sprinting
		Input.action_release("sprint"); Input.action_release("move_forward")
		await _f(20)
		r["som_nodes"] = _sons()
		res[id] = r
	# troca ciclica
	var tr := []
	for id in ids:
		if uid.has(id):
			tr.append(await _ev(func() -> void: m._equip_br_weapon(uid[id]), 0.8, true))
	res["_trocas"] = tr
	var f := FileAccess.open(OUT.path_join("armas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " ")); f.close()
	print("QA_ARMAS_OK ", JSON.stringify(res))
	get_tree().quit()
func _sons() -> int:
	var n := 0
	for p in get_tree().root.find_children("*", "AudioStreamPlayer*", true, false):
		n += 1
	return n
func _f(n: int) -> void:
	for _i in n: await get_tree().process_frame
func _ev(acao: Callable, dur: float, rosa: bool, cap := "") -> Dictionary:
	await _f(6)
	var t0 := Time.get_ticks_usec()
	acao.call()
	var mx := 0.0; var soma := 0.0; var n := 0; var nr := 0; var rmax := 0
	var ult := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - t0) / 1e6 < dur:
		await get_tree().process_frame
		var a := Time.get_ticks_usec()
		var ms := (a - ult) / 1000.0
		mx = maxf(mx, ms); soma += ms; n += 1
		if rosa and n % 4 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var c := _rosa(img)
			rmax = maxi(rmax, c)
			if c >= 100: nr += 1
			if cap != "" and n == 24:
				img.save_png(OUT.path_join("arma_%s.png" % cap))
		ult = Time.get_ticks_usec()
	return {"max_ms": snappedf(mx, 0.1), "medio_ms": snappedf(soma / maxf(n, 1), 0.1), "q": n, "rosa_q": nr, "rosa_px_max": rmax}
func _rosa(a: Image) -> int:
	var n := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			var c := a.get_pixel(x, y)
			if c.r > 0.7 and c.b > 0.6 and c.g < 0.5 and c.r - c.g > 0.3: n += 1
	return n
