extends Node
## Mosin em 1ª pessoa: quadril (boca do cano na tela), ciclo do ferrolho, recarga por clip, ADS e assento da luneta.
## Uso: godot --path game res://tests/sniper_fp.tscn -- [--partes=quadril,ferrolho,recarga,ads,luneta] [--cap=1]
##      [--q=px,py,pz,rx,ry,rz,vx,vy,vz]  (sobrepõe "quadril" de miras.json para ajuste)
## Saída: raw/sniper/sniper_fp.json (+ PNGs em raw/sniper/ com --cap=1)
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/sniper"
var m: BRMatch
var pc: PlayerController
var vm: ViewModel
var sol: Soldier
var cam: Camera3D
var cap := false
## --cobertura=1: mede braço/ferrolho/clip pintando as peças de MAGENTA em quadros parados (a janela pisca em rosa e
## o tempo para por instantes: não rodar enquanto o dono joga)
var medir_cob := false
var res := {}
var capturas: Array = []


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	cap = Game.test_args.get("cap", "0") == "1"
	medir_cob = Game.test_args.get("cobertura", "0") == "1"
	DirAccess.make_dir_recursive_absolute(OUT)
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
	for it in m.br_bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "mosin", "glock", "usp"]:
			m.br_bag.remove_item(int(it.uid))
	m.br_bag.add_item("mosin", 1, Vector2i(-1, -1), {"mag": 5})
	var uid := -1
	for it in m.br_bag.items:
		if String(it.id) == "mosin":
			uid = int(it.uid)
	m._equip_br_weapon(uid)
	await _frames(90)
	vm = pc.viewmodel
	cam = pc.camera
	if Game.test_args.has("q"):
		var q := String(Game.test_args["q"]).split(",")
		vm._miras_rig["quadril"] = {"pos": [float(q[0]), float(q[1]), float(q[2])], "rot": [float(q[3]), float(q[4]), float(q[5])], "pivo": [float(q[6]), float(q[7]), float(q[8])]}
		vm._setup_mira(sol.current().def)
		await _frames(20)
	if Game.test_args.get("sem_maos", "0") == "1":   # depuração: esconde os braços para ver ferrolho/clip
		for mi in vm.scene_root.find_children("Hand_Mesh", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).visible = false
	res["ferrolho_separado"] = vm._ferrolho != null
	res["ik"] = vm._ferrolho_ik != null
	var partes := String(Game.test_args.get("partes", "quadril,ferrolho,recarga,ads,luneta")).split(",")
	if "quadril" in partes:
		res["quadril"] = await _quadril()
	if "luneta" in partes:
		res["luneta_folga_cm"] = _folga_luneta()
	if "ferrolho" in partes:
		res["ferrolho"] = await _ferrolho()
	if "recarga" in partes:
		res["recarga"] = await _recarga()
	if "ads" in partes:
		res["ads"] = await _ads()
	res["capturas"] = capturas
	var f := FileAccess.open(OUT.path_join(String(Game.test_args.get("tag", "")) + "sniper_fp.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	print("SNIPER ", JSON.stringify(res))
	print("SNIPER_OK")
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _cap(nome: String) -> void:
	if not cap:
		return
	await RenderingServer.frame_post_draw
	nome = String(Game.test_args.get("tag", "")) + nome
	get_viewport().get_texture().get_image().save_png(OUT.path_join(nome + ".png"))
	capturas.append("raw/sniper/" + nome + ".png")
	# o quadro seguinte (que carrega o tempo gasto salvando o PNG) passa com dt = 0: a animação não pula fases
	Engine.time_scale = 0.0
	await get_tree().process_frame
	Engine.time_scale = 1.0


func _tela() -> Vector2:
	return get_viewport().get_visible_rect().size


## Projeção com o FOV do viewmodel (o shader da arma usa o próprio FOV, não o da câmera).
func _px(p: Vector3) -> Vector2:
	var c := cam.global_transform.affine_inverse() * p
	if c.z >= -0.001:
		return Vector2(-9999, -9999)
	var f := 1.0 / tan(deg_to_rad(vm._vm_fov()) * 0.5)
	var s := _tela()
	return s * 0.5 + Vector2(c.x / -c.z, -c.y / -c.z) * f * s.y * 0.5


func _fora(p: Vector2) -> bool:
	var s := _tela()
	return p.x < 0 or p.y < 0 or p.x > s.x or p.y > s.y


func _modelo() -> Node3D:
	return vm._mosin_modelo


## Boca do cano pela geometria (vértices da ponta, -Z do glb), em coordenadas globais.
func _boca() -> Vector3:
	var mo := _modelo()
	var mi := mo.find_child("sniper_rifle_001", true, false) as MeshInstance3D
	var xf := ViewModel._rel(mi, mo)
	var zmin := INF
	var pts := []
	for si in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			var w := xf * v
			pts.append(w)
			zmin = minf(zmin, w.z)
	var soma := Vector3.ZERO
	var n := 0
	for w: Vector3 in pts:
		if w.z < zmin + 0.01:
			soma += w
			n += 1
	return mo.global_transform * (soma / maxf(n, 1))


func _casco_luneta() -> PackedVector2Array:
	var mo := _modelo()
	var mi := mo.find_child("sight_001", true, false) as MeshInstance3D
	var pts := PackedVector2Array()
	if mi == null:
		return pts
	for si in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			pts.append(_px(mi.global_transform * v))
	return Geometry2D.convex_hull(pts)


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]


func _bone(n: String) -> Vector3:
	var sk := vm._rig_skel
	var i := sk.find_bone(n)
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin if i >= 0 else Vector3.INF


func _quadril() -> Dictionary:
	await _frames(30)
	await RenderingServer.frame_post_draw
	var a := get_viewport().get_texture().get_image()
	var boca := _boca()
	var bp := _px(boca)
	var casco := _casco_luneta()
	var coberta := casco.size() > 2 and Geometry2D.is_point_in_polygon(bp, casco)
	var mao_e := _px(_bone("LeftHand"))
	var mao_d := _px(_bone("RightHand"))
	# trecho do cano entre a frente da luneta e a boca: % dos pontos fora do contorno da luneta e dentro da tela
	var vis_cano := 0
	var mo := _modelo()
	var boca_l := mo.global_transform.affine_inverse() * boca
	var frente_l := Vector3(boca_l.x, boca_l.y, -0.18)
	for i in 11:
		var q := _px(mo.global_transform * frente_l.lerp(boca_l, i / 10.0))
		if not _fora(q) and not (casco.size() > 2 and Geometry2D.is_point_in_polygon(q, casco)):
			vis_cano += 1
	res["cano_visivel_pct"] = roundi(vis_cano / 11.0 * 100.0)
	vm.set_viewmodel_enabled(false)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var b := get_viewport().get_texture().get_image()
	vm.set_viewmodel_enabled(true)
	await _frames(3)
	var desenhada := false
	if not _fora(bp):
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x := clampi(int(bp.x) + dx, 0, a.get_width() - 1)
				var y := clampi(int(bp.y) + dy, 0, a.get_height() - 1)
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.1:
					desenhada = true
	# área coberta pela arma+braços
	var n := 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.15:
				n += 1
	var cb2 := Rect2()
	if casco.size() > 2:
		cb2 = Rect2(casco[0], Vector2.ZERO)
		for p in casco:
			cb2 = cb2.expand(p)
	await _cap("quadril")
	if medir_cob:
		var cq: Dictionary = await _cobertura([])
		res["quadril_braco_tela_pct"] = snappedf(cq.pct, 0.1)
	var ci := cam.global_transform.affine_inverse()
	var hc := vm.holder.global_transform.affine_inverse()
	res["quadril_dbg"] = {"boca_holder": _v(hc * boca), "receptor_holder": _v(hc * (_modelo().global_transform * Vector3(-0.0175, 0.08, 0.15))),
		"bola_holder": _v(hc * vm._ferrolho_knob.global_position) if vm._ferrolho_knob else [], "boca_cam": _v(ci * boca)}
	return {"boca_px": [roundi(bp.x), roundi(bp.y)], "boca_visivel": (not _fora(bp)) and not coberta and desenhada,
		"boca_dentro_tela": not _fora(bp), "boca_coberta_luneta": coberta, "boca_desenhada": desenhada,
		"luneta_bbox_px": [roundi(cb2.position.x), roundi(cb2.position.y), roundi(cb2.end.x), roundi(cb2.end.y)],
		"mao_apoio_px": [roundi(mao_e.x), roundi(mao_e.y)], "mao_apoio_visivel": not _fora(mao_e),
		"mao_direita_px": [roundi(mao_d.x), roundi(mao_d.y)], "area_arma_pct": snappedf(n * 16.0 / (a.get_width() * a.get_height()) * 100.0, 0.1)}


func _ferrolho() -> Dictionary:
	if vm._ferrolho == null:
		return {"erro": "sem ferrolho"}
	var ws := sol.current()
	ws.mag = 5
	await _frames(100)
	var mo := _modelo()
	var e: Array = vm._ferrolho_cfg.eixo
	var rest_l := Vector3(e[0], e[1], e[2])
	var tl: Array = vm._ferrolho_cfg.tempos
	var t0 := Time.get_ticks_usec()
	var tiros := [0]
	var cb := func(_d: WeaponDef) -> void: tiros[0] += 1
	sol.fired.connect(cb)
	Input.action_press("fire")
	var curso := 0.0
	var dmin := INF
	var dmin_t := 0.0
	var ini := -1.0
	var fim := -1.0
	var capt := {}
	var serie := []
	var fora_mao := 0
	var n := 0
	var prox_cob := 0.0
	var cobs: Array = []
	var cob_serie: Array = []
	var bola_n := 0
	var bola_vis := 0
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_usec() - t0) / 1e6
		if t > 0.08 and Input.is_action_pressed("fire"):
			Input.action_release("fire")
		if (ini >= 0.0 and vm._ferrolho_t < 0.0) or t > 40.0:
			break
		var tf := vm._ferrolho_t
		var peso := vm._ferrolho_peso
		var g_rest := mo.global_transform * rest_l
		var g_now := vm._ferrolho.global_position
		curso = maxf(curso, g_now.distance_to(g_rest) * 100.0)
		var palma := vm.mosin_palma_global()
		var bola := vm._ferrolho_knob.global_position
		var d := palma.distance_to(bola) * 100.0
		if peso > 0.01:
			if ini < 0.0:
				ini = tf
			fim = tf
			n += 1
			if _fora(_px(palma)):
				fora_mao += 1
		if peso > 0.98 and d < dmin:
			dmin = d
			dmin_t = tf
		if peso > 0.98 and not res.has("ik_dbg"):
			var sk := vm._rig_skel
			var ombro := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightArm")).origin
			var cot := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightForeArm")).origin
			var pul := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
			res["ik_dbg"] = {"ombro_alvo_cm": snappedf(ombro.distance_to(vm._ferrolho_alvo.global_position) * 100, 0.1), "braco_cm": snappedf(ombro.distance_to(cot) * 100, 0.1), "antebraco_cm": snappedf(cot.distance_to(pul) * 100, 0.1),
				"pulso_ik_alvo_cm": snappedf((sk.global_transform * vm._ferrolho_pulso_ik).distance_to(vm._ferrolho_alvo.global_position) * 100, 0.1) if vm._ferrolho_pulso_ik != Vector3.INF else -1.0,
				"palma_pulso_cm": snappedf(vm.mosin_palma_global().distance_to(sk.global_transform * vm._ferrolho_pulso_ik) * 100, 0.1) if vm._ferrolho_pulso_ik != Vector3.INF else -1.0}
		if serie.size() < 80:
			serie.append([snappedf(tf, 0.01), snappedf(peso, 0.01), snappedf(vm._ferrolho_giro, 0.01), snappedf(vm._ferrolho_recuo, 0.01), snappedf(d, 0.1)])
		if medir_cob and peso > 0.01 and tf >= prox_cob:
			prox_cob = tf + 0.08
			var cr: Dictionary = await _cobertura([vm._ferrolho])
			cobs.append(cr.pct)
			cob_serie.append([snappedf(tf, 0.01), snappedf(cr.pct, 0.1), cr.motivo])
			if peso > 0.5:
				bola_n += 1
				if cr.vis[0]:
					bola_vis += 1
		for k in [["ferrolho_1_aberto", tl[2]], ["ferrolho_2_recuado", tl[3]], ["ferrolho_3_fechando", (tl[4] + tl[5]) * 0.5]]:
			if tf >= float(k[1]) and not capt.has(k[0]):
				capt[k[0]] = true
				await _cap(k[0])
	sol.fired.disconnect(cb)
	return {"tiros": tiros[0], "dur_s": snappedf(fim - ini, 0.01), "curso_cm": snappedf(curso, 0.1), "mao_ferrolho_min_cm": snappedf(dmin, 0.1),
		"mao_ferrolho_min_t_s": snappedf(dmin_t, 0.01), "mao_fora_tela_pct": snappedf(100.0 * fora_mao / maxf(n, 1), 0.1),
		"braco_tela_pct": _resumo_cob(cobs), "bola_visivel_pct": snappedf(100.0 * bola_vis / maxf(bola_n, 1), 0.1), "cob_serie_t_pct_bola": cob_serie, "serie_t_peso_giro_recuo_dcm": serie}


func _recarga() -> Dictionary:
	var ws := sol.current()
	var def := ws.def
	await _frames(60)
	ws.mag = 1
	ws.reserve = 500
	await _frames(5)
	var mo := _modelo()
	var eixo0: Vector3 = (mo.global_basis * Vector3(0, 0, -1)).normalized()
	var eixo0_cam := cam.global_basis.inverse() * eixo0
	var t0 := Time.get_ticks_usec()
	var feito := [false, 0.0]
	var cb := func(_d: WeaponDef) -> void:
		feito[0] = true
		feito[1] = (Time.get_ticks_usec() - t0) / 1e6
	sol.reload_finished.connect(cb)
	sol.start_reload()
	var n := 0
	var fora := 0
	var fora_boca := 0
	var ang_max := 0.0
	var clip_visto := false
	var clip_fora := 0
	var clip_n := 0
	var mao_clip_min := INF
	var fases := {}
	var capt := {}
	var rec_max := 0.0
	var prox_cob := 0.0
	var cobs: Array = []
	var cob_serie: Array = []
	var bola_n := 0
	var bola_vis := 0
	var clip_vn := 0
	var clip_vis := 0
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_usec() - t0) / 1e6
		if t > def.reload_time + 60.0:
			break
		n += 1
		var boca := _boca()
		var centro := (mo.global_position + boca) * 0.5
		var receptor := mo.global_transform * Vector3(-0.0175, 0.08, 0.15)
		if _fora(_px(centro)) or _fora(_px(receptor)):
			fora += 1
		if _fora(_px(boca)):
			fora_boca += 1
		var eixo_cam := cam.global_basis.inverse() * (mo.global_basis * Vector3(0, 0, -1)).normalized()
		ang_max = maxf(ang_max, rad_to_deg(eixo_cam.angle_to(eixo0_cam)))
		if vm._mosin_clip and vm._mosin_clip.visible:
			clip_visto = true
			clip_n += 1
			var cp := vm._mosin_clip.global_position
			if _fora(_px(cp)):
				clip_fora += 1
			mao_clip_min = minf(mao_clip_min, vm.mosin_palma_global().distance_to(cp) * 100.0)
		fases[vm._mosin_fase] = true
		if medir_cob and vm._mosin_rec_t >= 0.0 and vm._mosin_rec_t >= prox_cob:
			prox_cob = vm._mosin_rec_t + 0.15
			var clip_on := vm._mosin_clip != null and vm._mosin_clip.visible
			var pts: Array = [vm._ferrolho]
			if clip_on:
				pts.append(vm._mosin_clip)
			var cr: Dictionary = await _cobertura(pts)
			cobs.append(cr.pct)
			cob_serie.append([snappedf(vm._mosin_rec_t / vm._mosin_rec_len, 0.01), vm._mosin_fase, snappedf(cr.pct, 0.1), cr.motivo])
			if vm._ferrolho_recuo > 0.5 or vm._ferrolho_giro > 0.5:
				bola_n += 1
				if cr.vis[0]:
					bola_vis += 1
			if clip_on:
				clip_vn += 1
				if cr.vis[1]:
					clip_vis += 1
		var p := vm._mosin_rec_t / vm._mosin_rec_len if vm._mosin_rec_t >= 0.0 else (1.0 if feito[0] else 0.0)
		if vm._mosin_rec_t >= 0.0:
			rec_max = vm._mosin_rec_t
		for k in [["recarga_1_abre", 0.22], ["recarga_2_clip", 0.46], ["recarga_3_empurra", 0.62], ["recarga_4_fecha", 0.83]]:
			if p >= float(k[1]) and not capt.has(k[0]):
				capt[k[0]] = true
				await _cap(k[0])
		if feito[0] and vm._mosin_rec_t < 0.0:
			break
	sol.reload_finished.disconnect(cb)
	return {"tipo": "clip" if clip_visto else "carregador", "dur_s": snappedf(rec_max, 0.01), "dur_parede_s": snappedf(feito[1], 0.01), "reload_time_def": def.reload_time,
		"fora_tela_pct": snappedf(100.0 * fora / maxf(n, 1), 0.1), "boca_fora_tela_pct": snappedf(100.0 * fora_boca / maxf(n, 1), 0.1),
		"rifle_giro_max_graus": snappedf(ang_max, 0.1), "clip_fora_tela_pct": snappedf(100.0 * clip_fora / maxf(clip_n, 1), 0.1),
		"mao_clip_min_cm": snappedf(mao_clip_min, 0.1), "fases": fases.keys(), "mag_final": ws.mag,
		"braco_tela_pct": _resumo_cob(cobs), "bola_visivel_pct": snappedf(100.0 * bola_vis / maxf(bola_n, 1), 0.1), "clip_visivel_pct": snappedf(100.0 * clip_vis / maxf(clip_vn, 1), 0.1), "cob_serie_p_fase_pct_vis": cob_serie}


## Medição por máscara (quadro parado, mesmo shader/FOV do viewmodel, peças pintadas de magenta puro):
## pct = % da tela coberta pelos braços (Hand_Mesh). Para cada alvo (nó com malhas: ferrolho, clip) conta os pixels dele
## visíveis com os braços e sem os braços: V = visível (>= 25 px e >= 30% do que aparece sem braços), M = coberto pelo braço,
## L = escondido pela própria arma/luneta (< 25 px mesmo sem braços).
var _n_masc := 0


func _pintar(nos: Array, magenta: bool) -> Dictionary:
	var orig := {}
	for raiz in nos:
		var lista: Array = [raiz] if raiz is MeshInstance3D else []
		lista.append_array((raiz as Node).find_children("*", "MeshInstance3D", true, false))
		for g in lista:
			var mi := g as MeshInstance3D
			var l := []
			for si in mi.mesh.get_surface_count():
				var om := mi.get_surface_override_material(si)
				l.append(om)
				if magenta and om is ShaderMaterial:
					var mm := (om as ShaderMaterial).duplicate() as ShaderMaterial
					mm.set_shader_parameter("albedo_color", Color(0, 0, 0))
					mm.set_shader_parameter("emission_color", Color(4, 0, 4))
					mm.set_shader_parameter("rim_strength", 0.0)
					mi.set_surface_override_material(si, mm)
			orig[mi] = l
	return orig


func _restaurar(orig: Dictionary) -> void:
	for mi in orig:
		for si in orig[mi].size():
			(mi as MeshInstance3D).set_surface_override_material(si, orig[mi][si])


func _quadro() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


static func _conta(a: Image, passo: int) -> int:
	var n := 0
	for y in range(0, a.get_height(), passo):
		for x in range(0, a.get_width(), passo):
			if _dif(a, a, x, y):
				n += 1
	return n


func _cobertura(alvos: Array) -> Dictionary:
	Engine.time_scale = 0.0
	var maos := vm.scene_root.find_children("Hand_Mesh", "MeshInstance3D", true, false)
	var o := _pintar(maos, true)
	var a: Image = await _quadro()
	if Game.test_args.get("mascara", "0") == "1":
		a.save_png(OUT.path_join("mascara_%d.png" % _n_masc))
		_n_masc += 1
	_restaurar(o)
	var tot := (a.get_width() / 4) * (a.get_height() / 4)
	var pct := 100.0 * _conta(a, 4) / maxf(tot, 1)
	var vis: Array = []
	var motivo := PackedStringArray()
	for alvo in alvos:
		var oa := _pintar([alvo], true)
		var com: int = _conta(await _quadro(), 2)
		for mi in maos:
			(mi as MeshInstance3D).visible = false
		var sem: int = _conta(await _quadro(), 2)
		for mi in maos:
			(mi as MeshInstance3D).visible = true
		_restaurar(oa)
		var ok := com >= 25 and float(com) >= 0.3 * float(sem)
		vis.append(ok)
		motivo.append("V" if ok else ("L" if sem < 25 else "M"))
	await get_tree().process_frame
	Engine.time_scale = 1.0
	return {"pct": pct, "vis": vis, "motivo": "".join(motivo)}

## Pixel da máscara magenta (braço). b é ignorado (assinatura antiga).
static func _dif(a: Image, _b: Image, x: int, y: int) -> bool:
	var c := a.get_pixel(x, y)
	return c.r > 0.7 and c.b > 0.6 and c.g < 0.55 and c.r - c.g > 0.3


static func _resumo_cob(l: Array) -> Dictionary:
	var mx := 0.0
	var s := 0.0
	for v in l:
		mx = maxf(mx, v)
		s += v
	return {"max": snappedf(mx, 0.1), "media": snappedf(s / maxf(l.size(), 1), 0.1), "amostras": l.size()}


func _ads() -> Dictionary:
	await _frames(30)
	Input.action_press("alt_fire")
	await _frames(70)
	var r := {"ads_amount": snappedf(vm.ads_amount, 0.01), "luneta": vm.luneta, "viewmodel_oculto": not vm.visible, "fov_cam": snappedf(cam.fov, 0.1)}
	await _cap("ads")
	Input.action_release("alt_fire")
	await _frames(30)
	return r


## Folga entre a base da luneta (sight_001) e a superfície da arma logo abaixo dela (cm no jogo; <= 0 = apoiada).
func _folga_luneta() -> float:
	var mo := _modelo()
	var lu := mo.find_child("sight_001", true, false) as MeshInstance3D
	var ri := mo.find_child("sniper_rifle_001", true, false) as MeshInstance3D
	if lu == null or ri == null:
		return -99.0
	var xl := ViewModel._rel(lu, mo)
	var lv := []
	var ymin := INF
	for si in lu.mesh.get_surface_count():
		for v: Vector3 in lu.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			var w := xl * v
			lv.append(w)
			ymin = minf(ymin, w.y)
	var x0 := INF; var x1 := -INF; var z0 := INF; var z1 := -INF
	for w: Vector3 in lv:
		if w.y < ymin + 0.004:
			x0 = minf(x0, w.x); x1 = maxf(x1, w.x); z0 = minf(z0, w.z); z1 = maxf(z1, w.z)
	var xr := ViewModel._rel(ri, mo)
	var tris := []
	for si in ri.mesh.get_surface_count():
		var arr := ri.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, ix.size() - 2, 3):
			tris.append([xr * vs[ix[t]], xr * vs[ix[t + 1]], xr * vs[ix[t + 2]]])
	var topo := -INF
	for ia in 5:
		for ib in 9:
			var px := lerpf(x0, x1, ia / 4.0)
			var pz := lerpf(z0, z1, ib / 8.0)
			topo = maxf(topo, ViewModel._altura_sob(tris, px, pz, ymin + 0.01))
	if topo == -INF:
		return -98.0
	var esc := mo.global_basis.get_scale().x
	return snappedf((ymin - topo) * esc * 100.0, 0.01)
