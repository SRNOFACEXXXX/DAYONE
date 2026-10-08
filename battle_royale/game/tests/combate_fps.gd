extends Node
## COMBATE-NÚCLEO / custo: FPS do estande (1024x768, sem vsync) parado e em fogo contínuo de M4,
## comparando o projétil simulado com o hitscan antigo (muzzle_velocity = 0 cai no trace_bullet).
## Também cronometra _balas_passo com 40 balas em voo. Saída: raw/triagem/combate_fps.json ; COMBATE_FPS_OK.
var m: Node
var s: Soldier
var R := {}


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func() -> void: print("COMBATE_FPS_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1024, 768))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	m = load("res://core/estande_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	s = m.local_player
	var pc := s.controller as PlayerController
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	s.give_weapon(&"m4")
	await _seg(2.0)
	var def := s.current_def()
	var v0 := def.muzzle_velocity
	R["parado_fps"] = await _medir(false)
	def.muzzle_velocity = 0.0
	R["fogo_hitscan_fps"] = await _medir(true)
	def.muzzle_velocity = v0
	R["fogo_projetil_fps"] = await _medir(true)
	R["parado_fps_2"] = await _medir(false)
	# micro: 40 balas em voo (céu/chão), tempo médio de um passo
	for i in 40:
		var b := Basis.from_euler(Vector3(deg_to_rad(randf_range(-10, 25)), deg_to_rad(randf_range(-60, 60)), 0), EULER_ORDER_YXZ)
		s._disparar_projetil(b, Vector2.ZERO, def)
	var tot := 0
	var passos := 0
	for i in 20:
		var t0 := Time.get_ticks_usec()
		s._balas_passo(1.0 / 64.0)
		tot += Time.get_ticks_usec() - t0
		passos += 1
		await get_tree().physics_frame
	R["balas_passo_40_us"] = snappedf(float(tot) / passos, 0.1)
	var queda := 100.0 * (1.0 - float(R["fogo_projetil_fps"]) / maxf(float(R["fogo_hitscan_fps"]), 1.0))
	R["queda_fps_projetil_vs_hitscan_pct"] = snappedf(queda, 0.1)
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	var f := FileAccess.open(out.path_join("combate_fps.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("FPS ", JSON.stringify(R))
	var ok := queda <= 5.0 and float(R["balas_passo_40_us"]) < 1500.0
	print("COMBATE_FPS_OK" if ok else "COMBATE_FPS_FALHOU")
	get_tree().quit(0 if ok else 1)


func _seg(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _medir(fogo: bool) -> float:
	var ws := s.current()
	ws.mag = 30
	ws.reserve = 9999
	if fogo:
		Input.action_press("fire")
	var quadros := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 4000000:
		await get_tree().process_frame
		quadros += 1
		if ws.mag < 3:
			ws.mag = 30   # sem recarga: só tiro
	Input.action_release("fire")
	await _seg(0.5)
	return snappedf(quadros / ((Time.get_ticks_usec() - t0) / 1e6), 0.1)
