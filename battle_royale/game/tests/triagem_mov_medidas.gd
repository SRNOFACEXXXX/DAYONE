extends Node
## Triagem de movimentação: mede velocidades, aceleração, pulo, agachar, ADS, espalhamento. Saída: raw/triagem/mov_raw_" + String(Game.test_args.get("tag", "a")) + ".json
var OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/triagem"
var R := {}
var m: BRMatch
var pc: PlayerController
var s: Soldier
var dtp := 1.0 / 60.0


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	DirAccess.make_dir_recursive_absolute(OUT)
	dtp = 1.0 / Engine.physics_ticks_per_second
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	pc = m.local_player.controller as PlayerController
	s = m.local_player
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	R["physics_hz"] = Engine.physics_ticks_per_second
	R["const"] = {"GRAVITY": Soldier.GRAVITY, "JUMP_V": Soldier.JUMP_VELOCITY, "ACCEL": Soldier.ACCEL, "FRICTION": Soldier.FRICTION, "STOP_SPEED": Soldier.STOP_SPEED, "DUCK_SPEED": Soldier.DUCK_SPEED}
	R["actions"] = {}
	for a in ["sprint", "walk", "crouch", "jump", "lean_left", "lean_right", "slide", "alt_fire", "fire"]:
		R["actions"][a] = InputMap.has_action(a)
	for arma in String(Game.test_args.get("armas", "ak47,m4,m249,m107")).split(","):
		await _equip(arma)
		await _arma(arma)
	await _equip("ak47")
	await _extras()
	var f := FileAccess.open(OUT.path_join("mov_raw_" + String(Game.test_args.get("tag", "a")) + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	print("TRIAGEM_OK")
	get_tree().quit(0)


func _equip(arma: String) -> void:
	var bag: BRInventory = m.br_bag
	for it in bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "reddot", "acog", "mosin"]:
			bag.remove_item(int(it.uid))
	bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": 30})
	var uid := -1
	for it in bag.items:
		if String(it.id) == arma:
			uid = int(it.uid)
	m._equip_br_weapon(uid)
	await _frames(120)


func _reset() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "walk", "alt_fire", "fire"]:
		Input.action_release(a)
	var y: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s.global_position = Vector3(-345.0, y + 0.1, 352.0)
	s.velocity = Vector3.ZERO
	s.yaw = deg_to_rad(40.0)
	s.pitch = 0.0
	s.shots_fired = 0.0
	s.fire_inacc = 0.0


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _vel(mods: Array) -> Dictionary:
	_reset()
	await _frames(40)
	for a in mods:
		Input.action_press(a)
	await _frames(30)
	Input.action_press("move_forward")
	var vmax := 0.0
	var t90 := -1.0
	var samples := []
	for i in 180:
		await _frames(1)
		var v := s.horizontal_speed()
		vmax = maxf(vmax, v)
		samples.append(v)
	for i in samples.size():
		if t90 < 0.0 and samples[i] >= 0.9 * vmax:
			t90 = (i + 1) * dtp
	var vss: float = samples[samples.size() - 1]
	Input.action_release("move_forward")
	var tp := -1.0
	for i in 240:
		await _frames(1)
		if tp < 0.0 and s.horizontal_speed() < 0.05:
			tp = (i + 1) * dtp
	for a in mods:
		Input.action_release(a)
	return {"v": snappedf(vss, 0.01), "t90_s": snappedf(t90, 0.001), "parar_s": snappedf(tp, 0.001), "v_t05": snappedf(samples[29], 0.01)}


func _arma(arma: String) -> void:
	var r := {}
	r["correr"] = await _vel([])
	r["walk"] = await _vel(["walk"])
	r["agachado"] = await _vel(["crouch"])
	r["ads"] = await _vel(["alt_fire"])
	r["move_speed_def"] = s.current_def().move_speed
	_reset()
	await _frames(40)
	Input.action_press("alt_fire")
	var t := 0.0
	var tads := -1.0
	for i in 90:
		await _frames(1)
		t += dtp
		if tads < 0.0 and pc._ads_amount >= 0.95:
			tads = t
	r["ads_parado_s"] = snappedf(tads, 0.001)
	Input.action_release("alt_fire")
	await _frames(60)
	_reset()
	await _frames(40)
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_press("alt_fire")
	t = 0.0
	tads = -1.0
	for i in 90:
		await _frames(1)
		t += dtp
		if tads < 0.0 and pc._ads_amount >= 0.95:
			tads = t
	r["correr_ads_s"] = snappedf(tads, 0.001)
	r["v_durante_ads"] = snappedf(s.horizontal_speed(), 0.01)
	Input.action_release("alt_fire")
	await _frames(40)
	var ws := s.current()
	ws.mag = 30
	s.next_attack = 0.0
	Input.action_press("fire")
	t = 0.0
	var ttiro := -1.0
	var m0: int = ws.mag
	for i in 60:
		await _frames(1)
		t += dtp
		if ttiro < 0.0 and ws.mag < m0:
			ttiro = t
	r["correr_tiro_s"] = snappedf(ttiro, 0.001)
	Input.action_release("fire")
	Input.action_release("move_forward")
	_reset()
	await _frames(60)
	var sp := {}
	sp["parado"] = s.current_spread()
	Input.action_press("crouch")
	await _frames(40)
	sp["agachado"] = s.current_spread()
	Input.action_release("crouch")
	await _frames(40)
	Input.action_press("alt_fire")
	await _frames(40)
	sp["ads_parado"] = s.current_spread()
	Input.action_release("alt_fire")
	await _frames(30)
	Input.action_press("move_forward")
	await _frames(90)
	sp["andando_correndo"] = s.current_spread()
	Input.action_press("alt_fire")
	await _frames(40)
	sp["ads_correndo"] = s.current_spread()
	Input.action_release("alt_fire")
	Input.action_press("jump")
	await _frames(12)
	sp["pulando"] = s.current_spread()
	Input.action_release("jump")
	Input.action_release("move_forward")
	r["spread"] = sp
	R[arma] = r
	print("ARMA ", arma, " ", JSON.stringify(r))


func _extras() -> void:
	var r := {}
	_reset()
	await _frames(60)
	var y0 := s.global_position.y
	var ymax := y0
	var tar := 0.0
	var landmin := 0.0
	var camy0: float = pc.camera.global_position.y
	var camy_min := camy0
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	for i in 120:
		await _frames(1)
		ymax = maxf(ymax, s.global_position.y)
		if not s.is_on_floor():
			tar += dtp
		camy_min = minf(camy_min, pc.camera.global_position.y)
		landmin = minf(landmin, pc._land_off)
	r["pulo_altura_m"] = snappedf(ymax - y0, 0.001)
	r["pulo_tempo_ar_s"] = snappedf(tar, 0.001)
	r["land_off_min_m"] = snappedf(landmin, 0.0001)
	r["cam_queda_m"] = snappedf(camy0 - camy_min, 0.0001)
	_reset()
	s.global_position.y += 3.0
	var lm := 0.0
	for i in 150:
		await _frames(1)
		lm = minf(lm, pc._land_off)
	r["land_off_queda3m_m"] = snappedf(lm, 0.0001)
	_reset()
	await _frames(40)
	var e0 := s.eye_height()
	Input.action_press("crouch")
	var t := 0.0
	var tc := -1.0
	for i in 60:
		await _frames(1)
		t += dtp
		if tc < 0.0 and s.crouch >= 0.95:
			tc = t
	r["agachar_s"] = snappedf(tc, 0.001)
	r["olho_em_pe_m"] = e0
	r["olho_agachado_m"] = s.eye_height()
	Input.action_release("crouch")
	_reset()
	await _frames(40)
	Input.action_press("move_forward")
	await _frames(60)
	var cy_min := 9.0
	var cy_max := -9.0
	var roll_max := 0.0
	var px_min := Vector3(9, 9, 9)
	var px_max := Vector3(-9, -9, -9)
	var rt_min := Vector3(9, 9, 9)
	var rt_max := Vector3(-9, -9, -9)
	for i in 90:
		await get_tree().process_frame
		var cy: float = pc.camera.global_position.y - s.global_position.y
		cy_min = minf(cy_min, cy)
		cy_max = maxf(cy_max, cy)
		var rr := absf(rad_to_deg(pc.camera.global_basis.get_euler(EULER_ORDER_YXZ).z))
		roll_max = maxf(roll_max, rr)
		var p := pc.viewmodel.pivot
		px_min = px_min.min(p.position)
		px_max = px_max.max(p.position)
		rt_min = rt_min.min(p.rotation)
		rt_max = rt_max.max(p.rotation)
	r["bob_cam_vertical_pp_cm"] = snappedf((cy_max - cy_min) * 100.0, 0.01)
	r["bob_cam_roll_max_graus"] = snappedf(roll_max, 0.01)
	r["bob_vm_pos_pp_cm"] = [snappedf((px_max.x - px_min.x) * 100.0, 0.01), snappedf((px_max.y - px_min.y) * 100.0, 0.01), snappedf((px_max.z - px_min.z) * 100.0, 0.01)]
	r["bob_vm_rot_pp_graus"] = [snappedf(rad_to_deg(rt_max.x - rt_min.x), 0.01), snappedf(rad_to_deg(rt_max.y - rt_min.y), 0.01), snappedf(rad_to_deg(rt_max.z - rt_min.z), 0.01)]
	Input.action_release("move_forward")
	R["extras"] = r
	print("EXTRAS ", JSON.stringify(r))
