extends Node
## QA v1: capturas + FPS parado + travada ao andar (1ª e 3ª pessoa) em pontos do mapa, br_match, 1024x768 sem vsync.
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/qa_v1"
var m: BRMatch
var pc: PlayerController
var sol: Soldier
var res := {}
func _ready() -> void:
	get_tree().create_timer(195.0).timeout.connect(func() -> void: print("QA_CENA_TIMEOUT ", JSON.stringify(res)); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	sol = m.local_player
	pc = sol.controller as PlayerController
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	m.br_bag.add_item("m4", 1, Vector2i(-1, -1), {"mag": 30})
	await _f(40)
	for it in m.br_bag.items:
		if String(it.id) == "m4": m._equip_br_weapon(int(it.uid))
	var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/ilha_layout.json"))
	var pts := []
	pts.append(["vila_spawn", -345.0, 352.0, 40.0])
	for p in lay.pois:
		res["poi_" + String(p.id)] = p.centro
	var pois: Array = lay.pois
	pts.append(["vila2_" + String(pois[1].id), float(pois[1].centro[0]), -float(pois[1].centro[1]), 120.0])
	pts.append(["quartel", 330.0, -300.0, 200.0])
	# casa mobiliada mais perto da vila
	var melhor: Node3D = null
	for b in m.ilha.get_node("Blockout").get_children():
		if b.has_meta("modelo") and b.has_node("Moveis"):
			if melhor == null or b.global_position.distance_to(Vector3(-330, 0, 300)) < melhor.global_position.distance_to(Vector3(-330, 0, 300)):
				melhor = b
	if melhor: pts.append(["interior_casa", melhor.global_position.x, melhor.global_position.z, 0.0])
	for p in pts:
		await _ponto(p)
	# 3ª pessoa andando no spawn
	await _ponto(["vila_spawn_3p", -345.0, 352.0, 40.0], true)
	var f := FileAccess.open(OUT.path_join("cena.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " ")); f.close()
	print("QA_CENA_OK ", JSON.stringify(res))
	get_tree().quit()
func _f(n: int) -> void:
	for _i in n: await get_tree().process_frame
func _ponto(p: Array, tp := false) -> void:
	var x: float = p[1]; var z: float = p[2]
	var y: float = m.ilha.terrain.height_world(x, z)
	sol.global_position = Vector3(x, y + 0.6, z)
	sol.velocity = Vector3.ZERO
	sol.yaw = deg_to_rad(float(p[3]))
	pc._prefer_third_person = tp
	pc._set_third_person(tp)
	await _f(150)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT.path_join("cena_%s.png" % p[0]))
	# FPS parado 4 s
	var r := {"pos": [snappedf(sol.global_position.x, 0.1), snappedf(sol.global_position.y, 0.1), snappedf(sol.global_position.z, 0.1)]}
	var q := await _medir(4.0)
	r["parado_fps_medio"] = q[0]; r["parado_fps_min"] = q[1]; r["parado_max_ms"] = q[2]
	Input.action_press("move_forward")
	var w := await _medir(8.0)
	Input.action_release("move_forward")
	r["andar_fps_medio"] = w[0]; r["andar_fps_min"] = w[1]; r["andar_max_ms"] = w[2]; r["andar_q50"] = w[3]; r["andar_q100"] = w[4]
	r["andou_m"] = snappedf(Vector2(sol.global_position.x - x, sol.global_position.z - z).length(), 0.1)
	res[p[0]] = r
func _medir(dur: float) -> Array:
	var t0 := Time.get_ticks_usec(); var ult := t0
	var n := 0; var mx := 0.0; var q50 := 0; var q100 := 0
	var tmin := 1e9
	while (Time.get_ticks_usec() - t0) / 1e6 < dur:
		await get_tree().process_frame
		var a := Time.get_ticks_usec()
		var ms := (a - ult) / 1000.0; ult = a
		n += 1; mx = maxf(mx, ms)
		if ms > 50: q50 += 1
		if ms > 100: q100 += 1
	var fps := n / ((ult - t0) / 1e6)
	return [snappedf(fps, 0.1), snappedf(1000.0 / maxf(mx, 0.001), 0.1), snappedf(mx, 0.1), q50, q100]
