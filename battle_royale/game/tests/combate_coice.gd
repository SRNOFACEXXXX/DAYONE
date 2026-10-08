extends Node
## COMBATE-NÚCLEO / coice de câmera: tiro isolado (pico em graus e retorno a 10%) e rajada de 10 tiros
## (pico e final da subida da câmera). Mede o ângulo real da Camera3D do jogador (o que a tela mostra).
## Uso: godot --path game res://tests/combate_coice.tscn -- [--armas=m4,ak47,m249,uzi,m107,mosin,glock] [--tag=depois]
## Critérios: automáticas rajada ≤ 1,2°; M4/M249 tiro isolado 0,6–0,8°; M107/Mosin retorno a 10% ≤ 0,8 s.
var R := {}
var m: BRMatch
var pc: PlayerController
var sol: Soldier
var cam: Camera3D
var falhas: Array = []


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: print("COMBATE_COICE_TIMEOUT"); get_tree().quit(2))
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
	cam = pc.camera
	var hx: float = m.ilha.terrain.height_world(-345.0, 352.0)
	sol.global_position = Vector3(-345.0, hx + 0.1, 352.0)
	sol.velocity = Vector3.ZERO
	sol.yaw = deg_to_rad(40.0)
	sol.pitch = 0.0
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	await _frames(30)
	var fps_amostras: Array = []
	for a in String(Game.test_args.get("armas", "m4,ak47,m249,uzi,m107,mosin,glock")).split(","):
		R[a] = await _arma(a)
		fps_amostras.append(Engine.get_frames_per_second())
		print("COICE ", a, " ", JSON.stringify(R[a]))
	R["fps_medio_teste"] = snappedf(fps_amostras.reduce(func(x, y): return x + y, 0.0) / maxf(fps_amostras.size(), 1), 0.1)
	R["falhas"] = falhas
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("combate_coice_%s.json" % String(Game.test_args.get("tag", "x"))), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("COMBATE_COICE_OK" if falhas.is_empty() else "COMBATE_COICE_FALHOU %d %s" % [falhas.size(), str(falhas)])
	get_tree().quit(0 if falhas.is_empty() else 1)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _check(nome: String, ok: bool) -> void:
	if not ok:
		falhas.append(nome)


func _ang(base: Vector3) -> float:
	return rad_to_deg(base.angle_to(-cam.global_basis.z))


func _atirar(max_tiros: int, max_s: float, base: Vector3, amostras: Array) -> int:
	var cont := [0]
	var cb := func(_d: WeaponDef) -> void: cont[0] += 1
	sol.fired.connect(cb)
	var t0 := Time.get_ticks_usec()
	var iv := sol.current().def.fire_interval * 1.1
	var auto: bool = sol.current().def.automatic
	Input.action_press("fire")
	var ult := 0.0
	while cont[0] < max_tiros and (Time.get_ticks_usec() - t0) / 1e6 < max_s:
		await get_tree().process_frame
		var tt := (Time.get_ticks_usec() - t0) / 1e6
		if not auto:
			if Input.is_action_pressed("fire") and tt - ult > 0.05:
				Input.action_release("fire")
			elif not Input.is_action_pressed("fire") and tt - ult >= iv:
				Input.action_press("fire")
				ult = tt
		amostras.append([tt, _ang(base)])
	Input.action_release("fire")
	sol.fired.disconnect(cb)
	return cont[0]


func _arma(id: String) -> Dictionary:
	for it in m.br_bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "mosin", "glock", "usp"]:
			m.br_bag.remove_item(int(it.uid))
	m.br_bag.add_item(id, 1, Vector2i(-1, -1), {"mag": 5})
	var uid := -1
	for it in m.br_bag.items:
		if String(it.id) == id:
			uid = int(it.uid)
	m._equip_br_weapon(uid)
	await _frames(90)
	var ws := sol.current()
	var def := ws.def
	ws.mag = def.mag_size
	ws.reserve = 500
	sol.shots_fired = 0.0
	await _frames(60)
	# tiro isolado
	var base := -cam.global_basis.z
	var am: Array = []
	await _atirar(1, 2.0, base, am)
	var t_ini := Time.get_ticks_usec()
	var off: float = float(am[am.size() - 1][0]) if am.size() > 0 else 0.0
	while (Time.get_ticks_usec() - t_ini) / 1e6 < 1.6:
		await get_tree().process_frame
		am.append([off + (Time.get_ticks_usec() - t_ini) / 1e6, _ang(base)])
	var pk := 0.0
	var ipk := 0
	for i in am.size():
		if float(am[i][1]) > pk:
			pk = float(am[i][1])
			ipk = i
	var ret_pico := -1.0
	var ret_tiro := -1.0
	for i in range(ipk, am.size()):
		if float(am[i][1]) < pk * 0.1:
			ret_pico = float(am[i][0]) - float(am[ipk][0])
			ret_tiro = float(am[i][0])
			break
	# rajada de 10
	ws.mag = def.mag_size
	sol.shots_fired = 0.0
	await _frames(100)
	var base2 := -cam.global_basis.z
	var am10: Array = []
	var n10 := await _atirar(10, 14.0, base2, am10)
	var pico10 := 0.0
	for a in am10:
		pico10 = maxf(pico10, float(a[1]))
	var fim10: float = float(am10[am10.size() - 1][1]) if am10.size() > 0 else 0.0
	await _frames(90)
	var r := {"automatica": def.automatic, "kick_deg": def.kick_deg, "kick_omega": def.kick_omega, "view_kick": def.view_kick,
		"graus_tiro_unico": snappedf(pk, 0.01), "retorno_10pct_do_pico_s": snappedf(ret_pico, 0.001),
		"retorno_10pct_do_tiro_s": snappedf(ret_tiro, 0.001), "tiros_rajada": n10,
		"rajada_pico_graus": snappedf(pico10, 0.01), "rajada_final_graus": snappedf(fim10, 0.01)}
	if def.automatic:
		_check(id + " rajada pico <= 1,25", pico10 <= 1.25)
	if id in ["m4", "m249"]:
		_check(id + " tiro unico 0,6-0,8", pk >= 0.58 and pk <= 0.82)
	if id in ["m107", "mosin"]:
		_check(id + " retorno <= 0,8 s", ret_tiro > 0.0 and ret_tiro <= 0.8)
	_check(id + " retorna", ret_pico > 0.0)
	return r
