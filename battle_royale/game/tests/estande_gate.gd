extends Node
## Gate de mira/tiro no estande (docs/criteria/ESTANDE_CRITERIOS.md). Para cada arma: quadril, ADS, tiro, recarga e corrida
## em capturas; mede M1 (alça/massa no centro, px), M3 (média dos impactos a 25 m, cm), M5 (estabilidade) e Q2 (corpo FP).
## Uso: --path game res://tests/estande_gate.tscn -- --out=raw/estande_01 [--only=ak47,m4]

const W := 1024
const H := 768

var out := ""
var m: EstandeMatch
var pc: PlayerController
var falhas: Array[String] = []


func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		push_error("ESTANDE_TIMEOUT")
		get_tree().quit(2))
	Game.test_mode = true
	out = Game.test_args.get("out", "user://estande")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(W, H))
	m = load("res://core/estande_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	pc = m.local_player.controller as PlayerController
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(30)
	_q2()
	var lista: Array = EstandeMatch.ARMAS
	if Game.test_args.has("only"):
		lista = String(Game.test_args.only).split(",")
	for id in lista:
		await _arma(StringName(id))
	if not Game.test_args.has("only") or "acog" in String(Game.test_args.only):
		m.acog = true
		for a in ([&"ak47", &"m4", &"m107", &"m249"] if (not Game.test_args.has("only") or "todas" in String(Game.test_args.only)) else [&"ak47"]):
			await _arma(a, "acog")
		m.acog = false
	print("ESTANDE_RESULTADO falhas=%d" % falhas.size())
	for f in falhas:
		print("  FALHA ", f)
	get_tree().quit(0 if falhas.is_empty() else 1)


func _q2() -> void:
	var s := m.local_player
	var total := 0
	var ok := 0
	for g in s.body_model.find_children("*", "GeometryInstance3D", true, false):
		total += 1
		if (g as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or not (g as GeometryInstance3D).is_visible_in_tree():
			ok += 1
	print("Q2 corpo_fp_oculto %d/%d" % [ok, total])
	if ok < total:
		falhas.append("Q2 %d malhas do corpo visíveis em 1ª pessoa" % (total - ok))


func _arma(id: StringName, tag := "") -> void:
	var s := m.local_player
	m.equipar(id)
	s.yaw = 0.0
	s.pitch = 0.0
	s.global_position = EstandeMatch.POS
	s.velocity = Vector3.ZERO
	s.reset_physics_interpolation()
	_mirar_alvo(25.0)
	await get_tree().create_timer(WeaponDB.get_def(id).draw_time + 0.4).timeout
	var nome := String(id) + ("_" + tag if tag != "" else "")
	await _foto("%s_1_quadril" % nome)
	# ADS
	Input.action_press("alt_fire")
	var limite := Time.get_ticks_msec() + 3000
	while pc._ads_amount < 0.999 and Time.get_ticks_msec() < limite:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var p1 := _sights_px()
	await _frames(20)
	var p2 := _sights_px()
	await _foto("%s_2_mira" % nome)
	if p1.is_empty():
		falhas.append("M1 %s sem marcas de mira (miras.json)" % id)
	else:
		var c := Vector2(W, H) * 0.5
		var er: Vector2 = p1[0] - c
		var ef: Vector2 = p1[1] - c
		var mov := maxf((p2[0] - p1[0]).length(), (p2[1] - p1[1]).length())
		print("M1 %s alca=(%.1f,%.1f) massa=(%.1f,%.1f) px  M5 mov=%.2f px" % [id, er.x, er.y, ef.x, ef.y, mov])
		if absf(er.x) > 2.0 or absf(ef.x) > 2.0 or absf(er.y) > 3.0 or absf(ef.y) > 3.0:
			falhas.append("M1 %s alça/massa fora do centro" % id)
		if mov > 1.0:
			falhas.append("M5 %s mira se move parada (%.2f px)" % [id, mov])
	# M3: 5 tiros espaçados a 25 m, parado, em ADS
	var visado := _ponto_visado()
	m.impactos.clear()
	var def := WeaponDB.get_def(id)
	for i in 5:
		_mirar_alvo(25.0)
		Input.action_press("fire")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("fire")
		if i == 0:
			# rajada de quadros do coice: nada pode chegar a menos de 5 cm do olho nem sumir/cortar
			var subida := 0.0
			var y0: float = p1[1].y if not p1.is_empty() else 0.0
			for q in 6:
				await _frames(1 if q == 0 else 2)
				var pq := _sights_px()
				if not pq.is_empty():
					subida = maxf(subida, y0 - float(pq[1].y))
				var perto := _mais_perto()
				if perto < 0.05:
					falhas.append("C1 %s quadro %d do tiro: arma a %.3f m do olho" % [id, q, perto])
				await _foto("%s_3_tiro_q%d" % [nome, q])
			print("C1 %s dist_min_olho=%.3f m" % [id, _mais_perto()])
		await get_tree().create_timer(maxf(def.fire_interval, 2.6 if id in [&"mosin", &"m107"] else 0.55) + 0.25).timeout
	var soma := Vector3.ZERO
	var n := 0
	for p in m.impactos:
		if absf(p.z + 25.0) < 0.3 and absf(p.x - visado.x) < 1.0:
			soma += p
			n += 1
	if n == 0:
		falhas.append("M3 %s nenhum impacto no alvo de 25 m" % id)
	else:
		var media := soma / n
		var err := Vector2(media.x - visado.x, media.y - visado.y).length() * 100.0
		print("M3 %s impactos=%d media_desvio=%.1f cm" % [id, n, err])
		if err > (8.0 if def.slot == WeaponDef.Slot.PISTOL else 6.0):   # pistola: espalhamento maior é legítimo
			falhas.append("M3 %s desvio médio %.1f cm" % [id, err])
	# K1: um tiro extra só medindo (sem captura no meio, que trava o quadro); Mosin espera o ferrolho
	await get_tree().create_timer(2.0 if id in [&"mosin", &"m107"] else 0.8).timeout
	var base_k := _sights_px()
	_mirar_alvo(25.0)
	m.local_player.current().mag = def.mag_size
	var mag0: int = m.local_player.current().mag
	Input.action_press("fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("fire")
	var sub := 0.0
	var kmax := 0.0
	var t_k := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_k < 300:
		await get_tree().process_frame
		var pk := _sights_px()
		kmax = maxf(kmax, pc.viewmodel._kick_rot)
		if not pk.is_empty() and not base_k.is_empty():
			sub = maxf(sub, float(base_k[1].y) - float(pk[1].y))
	print("K1 %s subida_massa=%.1f px kick_rot_max=%.2f atirou=%s" % [id, sub, kmax, m.local_player.current().mag < mag0])
	if sub < 12.0:
		falhas.append("K1 %s coice pouco visível (%.1f px)" % [id, sub])
	Input.action_release("alt_fire")
	await _frames(20)
	# recarga (meio da animação) e corrida
	var ws: WeaponState = s.current()
	ws.mag = 0
	Input.action_press("reload")
	await _frames(3)
	Input.action_release("reload")
	await get_tree().create_timer(def.reload_time * 0.45).timeout
	var vmr: ViewModel = pc.viewmodel
	print("RECARGA %s piv=%s rot=%s holder=%s draw=%.2f reload_t=%.2f ads=%.2f" % [nome, vmr.pivot.position, vmr.pivot.rotation, vmr.holder.position, vmr._draw_t, vmr._reload_t, vmr.ads_amount])
	await _foto("%s_4_recarga" % nome)
	await get_tree().create_timer(def.reload_time * 0.7).timeout
	Input.action_press("move_forward")
	await get_tree().create_timer(1.0).timeout
	await _foto("%s_5_andando" % nome)
	Input.action_release("move_forward")
	await _frames(30)


func _mirar_alvo(dist: float) -> void:
	var s := m.local_player
	var alvo: Vector3 = m.estande.alvos[Estande.DISTANCIAS.find(dist)].global_position
	var olho := s.eye_position()
	var d := alvo - olho
	s.yaw = atan2(-d.x, -d.z)
	s.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## Menor distância (à frente) entre o olho e os cantos das malhas visíveis do viewmodel. Usa as transformações locais
## encadeadas até o ViewModel (o global_transform de nós filhos da câmera top_level vinha defasado no mesmo quadro).
func _mais_perto() -> float:
	var vm: ViewModel = pc.viewmodel
	var menor := 99.0
	for g in vm.holder.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.skin != null:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != vm and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var bb := mi.mesh.get_aabb()
		for k in 8:
			var p := t * bb.get_endpoint(k)
			if p.z < 0.0:
				menor = minf(menor, p.length())
	return menor


## Onde o centro da tela encontra o alvo de 25 m.
func _ponto_visado() -> Vector3:
	var cam := pc.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 60.0, 1)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3.ZERO


## Projeta alça e massa com o FOV do viewmodel (mesma conta do shaders/viewmodel.gdshader).
func _sights_px() -> Array:
	var pts: Array = pc.viewmodel.sight_points_camera()
	if pts.is_empty():
		return []
	var f := 1.0 / tan(deg_to_rad(Settings.vertical_fov(Settings.viewmodel_fov)) * 0.5)
	var aspect := float(W) / float(H)
	var res := []
	for p: Vector3 in pts:
		var nx := (f / aspect) * p.x / -p.z
		var ny := f * p.y / -p.z
		res.append(Vector2((nx + 1.0) * 0.5 * W, (1.0 - ny) * 0.5 * H))
	return res


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % nome))
