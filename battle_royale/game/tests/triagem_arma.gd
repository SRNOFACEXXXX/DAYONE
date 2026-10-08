extends Node
## Triagem numérica de recarga / coice / quadril.
## Uso: -- --armas=m4,ak47 [--cap=m4:quadril,m4:rec50] [--out=raw/triagem]
## Saída: JSON em OUT/triagem_<armas>.json
var OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/triagem"
var m: BRMatch
var pc: PlayerController
var vm: ViewModel
var sol: Soldier
var cam: Camera3D
var caps: Array = []
var res := {}
var _capturados := {}


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	if Game.test_args.has("out"):
		OUT = "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/" + String(Game.test_args["out"])
	DirAccess.make_dir_recursive_absolute(OUT)
	caps = String(Game.test_args.get("cap", "")).split(",", false)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	sol = m.local_player
	pc = sol.controller as PlayerController
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
	for a in String(Game.test_args.get("armas", "m4")).split(","):
		await _arma(a)
	var f := FileAccess.open(OUT.path_join("triagem_%s.json" % String(Game.test_args.get("armas", "m4")).replace(",", "_")), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	print("TRIAGEM_OK")
	get_tree().quit()


func _arma(id: String) -> void:
	for it in m.br_bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "mosin", "glock", "usp"]:
			m.br_bag.remove_item(int(it.uid))
	m.br_bag.add_item(id, 1, Vector2i(-1, -1), {"mag": 5})
	var uid := -1
	for it in m.br_bag.items:
		if String(it.id) == id:
			uid = int(it.uid)
	m._equip_br_weapon(uid)
	await _frames(80)
	vm = pc.viewmodel
	cam = pc.camera
	var r := {}
	r["quadril"] = await _quadril(id)
	r["recarga"] = await _recarga(id)
	r["coice"] = await _coice(id)
	res[id] = r
	print("RES ", id, " ", JSON.stringify(r))


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _cap(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT.path_join(nome + ".png"))


func _sp(p: Vector3) -> Vector2:
	if cam.is_position_behind(p):
		return Vector2(-9999, -9999)
	return cam.unproject_position(p)


func _bone(bname: String) -> Vector3:
	var sk := vm._rig_skel
	var i := sk.find_bone(bname)
	if i < 0:
		return Vector3.INF
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin


func _bone_local(bname: String) -> Vector3:
	return vm._mira_no.global_transform.affine_inverse() * _bone(bname)


func _dedo() -> Vector3:
	if vm._rig_skel:
		return _bone("LeftHandMiddle2")
	return _mao()


func _mao() -> Vector3:
	if vm._rig_skel:
		return _bone("LeftHand")
	return vm._mao_e.global_position if vm._mao_e else Vector3.INF


func _mag1() -> Vector3:
	if vm._rig_skel:
		return _bone("Mag1_j")
	return vm._carregador.global_position if vm._carregador else Vector3.INF


func _centro() -> Vector3:
	return (vm._mira_no.global_position + vm.muzzle.global_position) * 0.5


func _fora(p: Vector2) -> bool:
	var s := get_viewport().get_visible_rect().size
	return p.x < 0 or p.y < 0 or p.x > s.x or p.y > s.y


func _quadril(id: String) -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	await _frames(20)
	await RenderingServer.frame_post_draw
	var a := get_viewport().get_texture().get_image()
	vm.set_viewmodel_enabled(false)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var b := get_viewport().get_texture().get_image()
	vm.set_viewmodel_enabled(true)
	await _frames(3)
	var x0 := 99999
	var y0 := 99999
	var x1 := -1
	var y1 := -1
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.15:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
				n += 1
	var frente := 1.0 if vm._rig_skel else -1.0
	var no := vm._mira_no
	var eixo: Vector3 = (no.global_basis.z * frente).normalized()
	var fw: Vector3 = -cam.global_basis.z
	var ang := rad_to_deg(eixo.angle_to(fw))
	var alvo := cam.global_position + fw * 25.0
	var ang25 := rad_to_deg(eixo.angle_to((alvo - vm.muzzle.global_position).normalized()))
	var mao := _mao()
	var mp := _sp(mao) if mao != Vector3.INF else Vector2(-9999, -9999)
	var mz := _sp(vm.muzzle.global_position)
	var d := {"bbox_pct": [snappedf(x0 / s.x * 100, 0.1), snappedf(y0 / s.y * 100, 0.1), snappedf((x1 + 1) / s.x * 100, 0.1), snappedf((y1 + 1) / s.y * 100, 0.1)],
		"area_pct": snappedf(n * 4.0 / (s.x * s.y) * 100, 0.1),
		"angulo_cano_mira_graus": snappedf(ang, 0.1), "angulo_cano_ponto25m_graus": snappedf(ang25, 0.1),
		"mao_apoio_px": [snappedf(mp.x, 1), snappedf(mp.y, 1)], "mao_apoio_visivel": (not _fora(mp)) and mao != Vector3.INF,
		"muzzle_px": [snappedf(mz.x, 1), snappedf(mz.y, 1)]}
	if (id + ":quadril") in caps:
		await _cap(id + "_quadril")
	return d


func _recarga(id: String) -> Dictionary:
	var ws := sol.current()
	var def := ws.def
	ws.mag = 1
	ws.reserve = 500
	await _frames(10)
	var rig := vm._rig_skel != null
	var mag1_0 := _mag1()
	var arma0 := vm._mira_no.global_position
	var rig0 := vm._rig_skel != null
	var mg_a := _bone("Mag1_j") if rig0 else Vector3.INF
	var mg_b := _bone("Mag2_j") if rig0 else Vector3.INF
	var dentro := 0
	if rig0 and mg_b.distance_to(arma0) < mg_a.distance_to(arma0):
		dentro = 1
	var mg_ini := mg_b if dentro == 1 else mg_a
	var mg_ini_nome := "Mag2_j" if dentro == 1 else "Mag1_j"
	var mg_ini_l := _bone_local(mg_ini_nome) if rig0 else Vector3.ZERO
	var t0 := Time.get_ticks_usec()
	var feito := [false]
	var t_fim := [0.0]
	var cb := func(_d: WeaponDef) -> void:
		feito[0] = true
		t_fim[0] = (Time.get_ticks_usec() - t0) / 1e6
	sol.reload_finished.connect(cb)
	sol.start_reload()
	var dmin := INF
	var dmin_t := 0.0
	var mag_max := 0.0
	var mag_ret := 0.0
	var fora := 0
	var fora_mao := 0
	var n := 0
	var amax := 0.0
	var dedo_min := INF
	var dedo_na_saida := -1.0
	var dur_guard := def.reload_time + 2.0
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_usec() - t0) / 1e6
		if t > dur_guard:
			break
		n += 1
		var hp := _mao()
		var carregadores: Array[Vector3] = []
		if rig:
			carregadores = [_bone("Mag1_j"), _bone("Mag2_j")]
		elif vm._carregador:
			carregadores = [vm._carregador.global_position]
		for cp in carregadores:
			if cp != Vector3.INF and hp != Vector3.INF:
				var dd := hp.distance_to(cp) * 100.0
				if dd < dmin:
					dmin = dd
					dmin_t = t
		if rig:
			var dp := _dedo()
			for cp2 in carregadores:
				var d2 := dp.distance_to(cp2) * 100.0
				if d2 < dedo_min:
					dedo_min = d2
		var m1 := _bone(mg_ini_nome) if rig else _mag1()
		if mag1_0 != Vector3.INF and m1 != Vector3.INF:
			var dsl := m1.distance_to(mag1_0) * 100.0
			if dsl > mag_max and rig:
				dedo_na_saida = minf(_dedo().distance_to(_bone("Mag1_j")), _dedo().distance_to(_bone("Mag2_j"))) * 100.0
			mag_max = maxf(mag_max, dsl)
			mag_ret = m1.distance_to(mag1_0) * 100.0
		if _fora(_sp(_centro())):
			fora += 1
		if hp != Vector3.INF and _fora(_sp(hp)):
			fora_mao += 1
		amax = maxf(amax, vm._mira_no.global_position.distance_to(arma0) * 100.0)
		for k in ["rec25", "rec50", "rec75"]:
			if (id + ":" + k) in caps:
				var pr := float(k.substr(3)) / 100.0
				if t >= pr * def.reload_time and not _capturados.has(id + k):
					_capturados[id + k] = true
					await _cap(id + "_" + k)
		if feito[0]:
			break
	sol.reload_finished.disconnect(cb)
	await _frames(60)
	var m2_final := -1.0
	if rig:
		var ea := _bone_local("Mag1_j")
		var eb := _bone_local("Mag2_j")
		var e_in := eb if eb.length() < ea.length() else ea
		m2_final = e_in.distance_to(mg_ini_l) * 100.0
	await _frames(5)
	var anim_len := -1.0
	if vm.anim and vm.anim.has_animation("reload"):
		anim_len = vm.anim.get_animation("reload").length
	return {"dur_s": snappedf(t_fim[0], 0.01), "reload_time_def": def.reload_time, "anim_len_s": snappedf(anim_len, 0.01),
		"mao_carregador_min_cm": snappedf(dmin, 0.1), "dedo_carregador_min_cm": (snappedf(dedo_min, 0.1) if dedo_min < 1e6 else -1.0), "dedo_carregador_na_saida_cm": snappedf(dedo_na_saida, 0.1), "mao_carregador_min_t_s": snappedf(dmin_t, 0.01),
		"carregador_sai": mag_max > 6.0, "carregador_desloc_max_cm": snappedf(mag_max, 0.1), "mag_dentro_inicial": mg_ini_nome, "mag_final_vs_inicial_cm": snappedf(m2_final, 0.1),
		"fora_da_tela_pct": snappedf(100.0 * fora / maxf(n, 1), 0.1), "mao_fora_da_tela_pct": snappedf(100.0 * fora_mao / maxf(n, 1), 0.1),
		"arma_desloc_max_cm": snappedf(amax, 0.1), "quadros": n}


func _atirar(max_tiros: int, max_s: float, amostras: Array) -> int:
	var cont := [0]
	var cb := func(_d: WeaponDef) -> void: cont[0] += 1
	sol.fired.connect(cb)
	var t0 := Time.get_ticks_usec()
	var iv := sol.current().def.fire_interval * 1.1
	var auto: bool = sol.current().def.automatic
	Input.action_press("fire")
	var ult_press := 0.0
	while cont[0] < max_tiros and (Time.get_ticks_usec() - t0) / 1e6 < max_s:
		await get_tree().process_frame
		var tt := (Time.get_ticks_usec() - t0) / 1e6
		if not auto:
			if Input.is_action_pressed("fire") and tt - ult_press > 0.05:
				Input.action_release("fire")
			elif not Input.is_action_pressed("fire") and tt - ult_press >= iv:
				Input.action_press("fire")
				ult_press = tt
		amostras.append(_amostra(t0))
	Input.action_release("fire")
	sol.fired.disconnect(cb)
	return cont[0]


func _amostra(t0: int) -> Array:
	var fw: Vector3 = -cam.global_basis.z
	return [(Time.get_ticks_usec() - t0) / 1e6, _sp(vm.muzzle.global_position), _sp(_centro()), fw]


func _coice(id: String) -> Dictionary:
	var ws := sol.current()
	var def := ws.def
	ws.mag = def.mag_size
	ws.reserve = 500
	sol.shots_fired = 0.0
	await _frames(90)
	var base_fw: Vector3 = -cam.global_basis.z
	var base_mz := _sp(vm.muzzle.global_position)
	var base_c := _sp(_centro())
	var am1: Array = []
	var n1 := await _atirar(1, 2.0, am1)
	var off_t := float(am1[am1.size() - 1][0]) if am1.size() > 0 else 0.0
	var t_ini := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - t_ini) / 1e6 < 1.6:
		await get_tree().process_frame
		var a := _amostra(t_ini)
		a[0] = float(a[0]) + off_t
		am1.append(a)
	var s1 := _analisa(am1, base_mz, base_c, base_fw)
	var serie := []
	for i in mini(am1.size(), 60):
		serie.append([int(float(am1[i][0]) * 1000.0), snappedf((am1[i][1] as Vector2).distance_to(base_mz), 0.1), snappedf(rad_to_deg(base_fw.angle_to(am1[i][3])), 0.02)])
	ws.mag = def.mag_size
	sol.shots_fired = 0.0
	await _frames(120)
	var base_fw2: Vector3 = -cam.global_basis.z
	var am10: Array = []
	var n10 := await _atirar(10, 8.0, am10)
	var ult: Array = am10[am10.size() - 1] if am10.size() > 0 else []
	var pico_cam := 0.0
	var pico_px := 0.0
	for a in am10:
		pico_cam = maxf(pico_cam, rad_to_deg(base_fw2.angle_to(a[3])))
		pico_px = maxf(pico_px, (a[1] as Vector2).distance_to(base_mz))
	var cam_final := rad_to_deg(base_fw2.angle_to(ult[3])) if ult.size() > 0 else 0.0
	var y_off := 0.0
	if ult.size() > 0:
		var d: Vector3 = ult[3]
		y_off = rad_to_deg(asin(clampf(d.y, -1, 1)) - asin(clampf(base_fw2.y, -1, 1)))
	return {"tiros_unico": n1, "tiros_rajada": n10,
		"px_por_tiro": snappedf(s1.px, 0.1), "px_centro_arma_por_tiro": snappedf(s1.pxc, 0.1), "graus_por_tiro": snappedf(s1.graus, 0.01),
		"retorno_ms": s1.retorno_ms, "retorno_cam_ms": s1.retorno_cam_ms,
		"rajada_pico_cam_graus": snappedf(pico_cam, 0.1), "rajada_final_cam_graus": snappedf(cam_final, 0.1), "rajada_subida_pitch_graus": snappedf(y_off, 0.1),
		"rajada_impacto_a_25m_cm": snappedf(tan(deg_to_rad(cam_final)) * 2500.0, 1.0), "rajada_pico_arma_px": snappedf(pico_px, 1.0),
		"acumula_rajada": pico_cam > 1.6 * maxf(s1.graus, 0.01) and n10 > 2, "serie_t_px_graus": serie}


func _analisa(am: Array, base_mz: Vector2, base_c: Vector2, base_fw: Vector3) -> Dictionary:
	var pk := 0.0
	var pkc := 0.0
	var pg := 0.0
	var i_pk := 0
	var i_pg := 0
	for i in am.size():
		var a: Array = am[i]
		var d: float = (a[1] as Vector2).distance_to(base_mz)
		if d > pk:
			pk = d
			i_pk = i
		pkc = maxf(pkc, (a[2] as Vector2).distance_to(base_c))
		var g := rad_to_deg(base_fw.angle_to(a[3]))
		if g > pg:
			pg = g
			i_pg = i
	var ret_ms := -1
	for i in range(i_pk, am.size()):
		if (am[i][1] as Vector2).distance_to(base_mz) < pk * 0.1:
			ret_ms = int(round((float(am[i][0]) - float(am[i_pk][0])) * 1000.0))
			break
	var ret_c := -1
	for i in range(i_pg, am.size()):
		if rad_to_deg(base_fw.angle_to(am[i][3])) < pg * 0.1:
			ret_c = int(round((float(am[i][0]) - float(am[i_pg][0])) * 1000.0))
			break
	return {"px": pk, "pxc": pkc, "graus": pg, "retorno_ms": ret_ms, "retorno_cam_ms": ret_c}
