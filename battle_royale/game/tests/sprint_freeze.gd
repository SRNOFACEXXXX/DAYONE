extends Node
## Mede o tempo de cada quadro (process_frame) em volta do início/fim do sprint (Shift) por arma.
## Uso: godot --path game res://tests/sprint_freeze.tscn -- --tag=antes [--armas=ak47,m4,...]
var m: BRMatch
var pc: PlayerController
var s: Soldier
var R := {}


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func() -> void: print("SPRINT_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
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
	for _i in 60:
		await get_tree().process_frame
	for arma in String(Game.test_args.get("armas", "ak47,m4,glock,mosin,m107,m249,uzi,nenhuma")).split(","):
		await _equip(arma)
		R[arma] = await _sprint(arma)
		print("SPR ", arma, " ", JSON.stringify(R[arma]))
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("sprint_freeze_%s.json" % String(Game.test_args.get("tag", "x"))), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	var pior := 0.0
	for k in R:
		pior = maxf(pior, maxf(R[k]["max_inicio_ms"], R[k]["max_fim_ms"]))
	print("SPRINT_PIOR_MS ", pior, " ", "SPRINT_OK" if pior <= 33.0 else "SPRINT_FALHOU")
	get_tree().quit(0)


func _equip(arma: String) -> void:
	var bag: BRInventory = m.br_bag
	for it in bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "reddot", "acog", "mosin", "glock"]:
			bag.remove_item(int(it.uid))
	if arma == "nenhuma":
		for sl in s.inventory.keys():
			s.remove_slot(sl)
		for _i in 30:
			await get_tree().process_frame
		return
	bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": 30})
	var uid := -1
	for it in bag.items:
		if String(it.id) == arma:
			uid = int(it.uid)
	m._equip_br_weapon(uid)
	# sem espera longa: alguns quadros só (o 1o sprint pode ser logo após equipar)
	for _i in 40:
		await get_tree().process_frame


func _reset() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "walk", "sprint", "alt_fire", "fire"]:
		Input.action_release(a)
	var y: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s.global_position = Vector3(-345.0, y + 0.1, 352.0)
	s.velocity = Vector3.ZERO
	s.yaw = deg_to_rad(40.0)
	s.pitch = 0.0
	s.reset_physics_interpolation()


func _medir(n: int, out: Array) -> void:
	var last := Time.get_ticks_usec()
	for _i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		out.append((now - last) / 1000.0)
		last = now


func _sprint(arma: String) -> Dictionary:
	_reset()
	await _medir(30, [])
	Input.action_press("move_forward")
	await _medir(60, [])
	var a := []
	await _medir(5, a)
	Input.action_press("sprint")
	await _medir(55, a)
	var b := []
	await _medir(60, b)  # em sprint, estável
	var c := []
	Input.action_release("sprint")
	await _medir(60, c)
	Input.action_release("move_forward")
	# repete (2o sprint) para separar custo da 1a vez
	await _medir(30, [])
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var d := []
	await _medir(60, d)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	return {
		"max_inicio_ms": snappedf(a.max(), 0.1),
		"max_fim_ms": snappedf(c.max(), 0.1),
		"max_estavel_ms": snappedf(b.max(), 0.1),
		"max_2o_sprint_ms": snappedf(d.max(), 0.1),
		"quadro_pior_inicio": a.find(a.max()),
		"top3_inicio": _top(a),
		"top3_fim": _top(c),
		"is_sprinting_viu": s.is_sprinting,
	}


func _top(arr: Array) -> Array:
	var c := arr.duplicate()
	c.sort()
	c.reverse()
	return [snappedf(c[0], 0.1), snappedf(c[1], 0.1), snappedf(c[2], 0.1)]
