extends Node
## COMBATE-NÚCLEO / movimento: sprint (Shift) 1,25x, bloqueio de tiro/ADS no sprint e por ~0,22 s depois,
## ADS a 55% da velocidade, aceleração/frenagem ~0,25 s, andar lento no Alt.
## Uso: godot --path game res://tests/combate_mov.tscn -- [--armas=ak47,m4] [--tag=depois]
## Saída: raw/triagem/combate_mov_<tag>.json ; imprime COMBATE_MOV_OK / COMBATE_MOV_FALHOU n.
var R := {}
var m: BRMatch
var pc: PlayerController
var s: Soldier
var dtp := 1.0 / 64.0
var falhas: Array = []


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: print("COMBATE_MOV_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	Game.test_args["sem_stamina"] = "1"   # mede velocidade do sprint, não o fôlego (stamina tem teste próprio: movimento_aaa)
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
	var walk_keys := []
	for ev in InputMap.action_get_events("walk"):
		if ev is InputEventKey:
			walk_keys.append(OS.get_keycode_string((ev as InputEventKey).physical_keycode))
	var sprint_keys := []
	for ev in InputMap.action_get_events("sprint"):
		if ev is InputEventKey:
			sprint_keys.append(OS.get_keycode_string((ev as InputEventKey).physical_keycode))
	R["teclas"] = {"sprint": sprint_keys, "walk": walk_keys}
	_check("sprint no Shift", sprint_keys.has("Shift"))
	_check("walk sem Shift", not walk_keys.has("Shift"))
	for arma in String(Game.test_args.get("armas", "ak47,m4")).split(","):
		await _equip(arma)
		R[arma] = await _arma(arma)
		print("MOV ", arma, " ", JSON.stringify(R[arma]))
	R["falhas"] = falhas
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("combate_mov_%s.json" % String(Game.test_args.get("tag", "x"))), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("COMBATE_MOV_OK" if falhas.is_empty() else "COMBATE_MOV_FALHOU %d %s" % [falhas.size(), str(falhas)])
	get_tree().quit(0 if falhas.is_empty() else 1)


func _check(nome: String, ok: bool) -> void:
	if not ok:
		falhas.append(nome)


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
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "walk", "sprint", "alt_fire", "fire"]:
		Input.action_release(a)
	var y: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s.global_position = Vector3(-345.0, y + 0.1, 352.0)
	s.velocity = Vector3.ZERO
	s.yaw = deg_to_rad(40.0)
	s.pitch = 0.0
	s.shots_fired = 0.0
	s.fire_inacc = 0.0
	s.reset_physics_interpolation()


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
	var samples := []
	for i in 160:
		await _frames(1)
		samples.append(s.horizontal_speed())
	var vss: float = samples[samples.size() - 1]
	var t90 := -1.0
	for i in samples.size():
		if samples[i] >= 0.9 * vss:
			t90 = (i + 1) * dtp
			break
	Input.action_release("move_forward")
	var tp := -1.0
	for i in 200:
		await _frames(1)
		if s.horizontal_speed() < 0.05:
			tp = (i + 1) * dtp
			break
	for a in mods:
		Input.action_release(a)
	return {"v": snappedf(vss, 0.01), "t90_s": snappedf(t90, 0.001), "parar_s": snappedf(tp, 0.001)}


func _arma(_arma_id: String) -> Dictionary:
	var r := {}
	r["correr"] = await _vel([])
	r["sprint"] = await _vel(["sprint"])
	r["ads"] = await _vel(["alt_fire"])
	r["andar_lento"] = await _vel(["walk"])
	var base: float = r["correr"]["v"]
	r["razao_sprint"] = snappedf(float(r["sprint"]["v"]) / base, 0.001)
	r["razao_ads"] = snappedf(float(r["ads"]["v"]) / base, 0.001)
	r["razao_andar_lento"] = snappedf(float(r["andar_lento"]["v"]) / base, 0.001)
	# sprint: sem tiro, sem ADS, arma marcada como baixada (is_sprinting)
	_reset()
	await _frames(40)
	var ws := s.current()
	ws.mag = 30
	s.next_attack = 0.0
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(40)
	var sprinting_flag := s.is_sprinting
	var m0: int = ws.mag
	Input.action_press("fire")
	Input.action_press("alt_fire")
	var ads_max := 0.0
	for i in 40:
		await get_tree().process_frame
		ads_max = maxf(ads_max, pc._ads_amount)
	var tiros_no_sprint := m0 - ws.mag
	Input.action_release("alt_fire")
	# solta o sprint segurando o gatilho: mede quanto tempo até o primeiro tiro
	var m1: int = ws.mag
	Input.action_release("sprint")
	var t_rel := s.t
	var t_tiro := -1.0
	for i in 64:
		await _frames(1)
		if ws.mag < m1:
			t_tiro = s.t - t_rel
			break
	Input.action_release("fire")
	Input.action_release("move_forward")
	r["is_sprinting_durante"] = sprinting_flag
	r["tiros_durante_sprint"] = tiros_no_sprint
	r["ads_max_durante_sprint"] = snappedf(ads_max, 0.001)
	r["sprint_para_tiro_s"] = snappedf(t_tiro, 0.001)
	_check("razao_sprint", absf(float(r["razao_sprint"]) - 1.25) <= 0.03)
	_check("razao_ads", absf(float(r["razao_ads"]) - 0.55) <= 0.03)
	_check("t90 correr 0,18-0,32", float(r["correr"]["t90_s"]) >= 0.18 and float(r["correr"]["t90_s"]) <= 0.32)
	_check("parar 0,18-0,32", float(r["correr"]["parar_s"]) >= 0.18 and float(r["correr"]["parar_s"]) <= 0.32)
	_check("is_sprinting", sprinting_flag)
	_check("sem tiro no sprint", tiros_no_sprint == 0)
	_check("sem ADS no sprint", ads_max < 0.05)
	_check("bloqueio pos-sprint 0,18-0,30", t_tiro >= 0.18 and t_tiro <= 0.30)
	_check("andar lento < correr", float(r["razao_andar_lento"]) < 0.6)
	return r
