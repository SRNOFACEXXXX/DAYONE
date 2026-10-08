extends Node
## Pontes do Rio Tauá (cenario_atualizacao.json -> "pontes") + crista da barragem (E10), no JOGO REAL (BRMatch):
##  1) perfil: raios para baixo a cada 0,2 m no eixo e nas faixas laterais -> maior degrau e menor altura sobre a água;
##  2) o Soldier do jogador anda com Input real (move_forward) de 6 m antes de uma cabeceira até 6 m depois da outra,
##     nos dois sentidos, limite 20 s; se ficar parado 3 s registra o obstáculo e captura;
##  3) captura lateral e captura do jogador em cima de cada ponte. --out=<pasta>. Linha final: PONTES OK n/8 | PONTES FALHA.
## Coordenadas: design (x leste, y norte) -> mundo (x, -y).

const DEGRAU_MAX := 0.3

var m: BRMatch
var sol: Soldier
var falhas := 0
var travessias_ok := 0
var R := []


func _ready() -> void:
	get_tree().create_timer(400.0).timeout.connect(func() -> void: print("PONTES TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	sol = m.local_player
	var pc := sol.controller as PlayerController
	if pc.has_method("_set_third_person"):
		pc._set_third_person(false)
	var t: IlhaTerrain = m.ilha.terrain
	var ca: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/cenario_atualizacao.json"))
	var lista: Array = ca.get("pontes", []).duplicate()
	lista.append({"nome": "Crista da Barragem (E10, terreno)", "centro": [-100.0, -86.0], "direcao_deg": -45.0,
		"comprimento_m": 40.0, "largura_m": 6.0, "agua_m": 14.5})
	for i in 60:
		await get_tree().process_frame
	var esp := sol.get_world_3d().direct_space_state
	for p in lista:
		var nome := String(p.nome)
		var arq := nome.get_slice(" (", 0).to_lower().replace(" ", "_")
		var dirv := Vector2(cos(deg_to_rad(float(p.direcao_deg))), sin(deg_to_rad(float(p.direcao_deg))))
		var c := Vector2(float(p.centro[0]), float(p.centro[1]))
		var meio := float(p.comprimento_m) * 0.5 + 6.0
		var agua := float(p.agua_m)
		# 1) perfil (ignora o próprio jogador)
		var lado := Vector2(-dirv.y, dirv.x)
		var pior := 0.0
		var onde := ""
		var min_sobre := 1e9
		for off in [0.0, float(p.largura_m) * 0.5 - 0.9, -float(p.largura_m) * 0.5 + 0.9]:
			var ant := NAN
			var s := 0.0
			while s <= meio * 2.0:
				var q2: Vector2 = c - dirv * meio + dirv * s + lado * float(off)
				var w := Vector3(q2.x, 60.0, -q2.y)
				var rq := PhysicsRayQueryParameters3D.create(w, w + Vector3.DOWN * 100.0)
				rq.exclude = [sol.get_rid()]
				var hit := esp.intersect_ray(rq)
				var y: float = hit.position.y if hit else -99.0
				if not is_nan(ant) and absf(y - ant) > pior:
					pior = absf(y - ant)
					onde = "(%.1f,%.1f) %.2f->%.2f %s" % [q2.x, q2.y, ant, y, (hit.collider as Node).name if hit else "-"]
				ant = y
				if absf(s - meio) < float(p.comprimento_m) * 0.5 - 2.0:
					min_sobre = minf(min_sobre, y - agua)
				s += 0.2
		var r := {"nome": nome, "degrau_max_m": snappedf(pior, 0.01), "pior_degrau_em": onde, "tabuleiro_sobre_agua_min_m": snappedf(min_sobre, 0.01)}
		var ok := pior <= DEGRAU_MAX and min_sobre > 0.3
		# 2) Soldier com Input real, nos dois sentidos
		for sentido in [1.0, -1.0]:
			var a: Vector2 = c - dirv * meio * sentido
			var b: Vector2 = c + dirv * meio * sentido
			var ta := await _travessia(t, esp, a, b, agua, out, "%s_%s" % [arq, "ida" if sentido > 0 else "volta"])
			r["ida" if sentido > 0 else "volta"] = ta
			if ta.chegou:
				travessias_ok += 1
			else:
				ok = false
		r["ok"] = ok
		if not ok:
			falhas += 1
		R.append(r)
		print("PONTE ", JSON.stringify(r))
		# 3) captura lateral
		var cam := get_viewport().get_camera_3d()
		var lc := c + lado * 20.0 + dirv * 6.0
		var cam2 := Camera3D.new()
		add_child(cam2)
		cam2.global_position = Vector3(lc.x, t.height_world(lc.x, -lc.y) + 6.0, -lc.y)
		cam2.look_at(Vector3(c.x, agua + 2.0, -c.y))
		cam2.current = true
		sol.global_position = Vector3(c.x, agua + 3.5, -c.y)   # jogador em cima do tabuleiro na foto
		sol.velocity = Vector3.ZERO
		sol.reset_physics_interpolation()
		for i in 25:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("ponte_%s.png" % arq))
		cam2.queue_free()
		if cam:
			cam.current = true
	var linha := ("PONTES OK %d/%d" % [travessias_ok, lista.size() * 2]) if falhas == 0 else ("PONTES FALHA %d/%d" % [travessias_ok, lista.size() * 2])
	var f := FileAccess.open(out.path_join("pontes_check.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"resultado": linha, "pontes": R}, " "))
	f.close()
	print(linha)
	get_tree().quit()


func _travessia(t: IlhaTerrain, esp: PhysicsDirectSpaceState3D, a: Vector2, b: Vector2, agua: float, out: String, tag: String) -> Dictionary:
	Input.action_release("move_forward")
	var wa := Vector3(a.x, 0, -a.y)
	var wb := Vector3(b.x, 0, -b.y)
	var rq := PhysicsRayQueryParameters3D.create(wa + Vector3.UP * 60.0, wa + Vector3.DOWN * 40.0)
	rq.exclude = [sol.get_rid()]
	var h0 := esp.intersect_ray(rq)
	sol.global_position = (h0.position if h0 else Vector3(a.x, t.height_world(a.x, -a.y), -a.y)) + Vector3.UP * 0.2
	sol.velocity = Vector3.ZERO
	var d := wb - wa
	sol.yaw = atan2(-d.x, -d.z)
	sol.pitch = 0.0
	sol.reset_physics_interpolation()
	for i in 40:
		await get_tree().process_frame
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_msec()
	var chegou := false
	var ult := 0
	var pos_s := sol.global_position
	var min_y := 1e9
	var res := {}
	var total := d.length()
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		sol.yaw = atan2(-d.x, -d.z)     # mantém o rumo (sem mouse)
		var pos := sol.global_position
		min_y = minf(min_y, pos.y)
		if (Vector3(pos.x, 0, pos.z) - wa).dot(d.normalized()) >= total - 1.0:
			chegou = true
			break
		if Time.get_ticks_msec() - t0 - ult >= 3000:
			ult = Time.get_ticks_msec() - t0
			if (pos - pos_s).length() < 1.0 and not res.has("preso_em"):
				var fw := -sol.global_transform.basis.z
				var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.9, 0), pos + Vector3(0, 0.9, 0) + fw * 3.0)
				q.exclude = [sol.get_rid()]
				var hh := esp.intersect_ray(q)
				var q2 := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.25, 0), pos + Vector3(0, 0.25, 0) + fw * 3.0)
				q2.exclude = [sol.get_rid()]
				var hb := esp.intersect_ray(q2)
				res["preso_em_design"] = [snappedf(pos.x, 0.1), snappedf(-pos.z, 0.1), snappedf(pos.y, 0.01)]
				res["preso_em"] = true
				res["obstaculo_0_9m"] = str((hh.collider as Node).get_path()) if hh and hh.collider else "nada"
				res["obstaculo_0_25m"] = str((hb.collider as Node).get_path()) if hb and hb.collider else "nada"
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join("ponte_preso_%s.png" % tag))
			pos_s = pos
	Input.action_release("move_forward")
	res["chegou"] = chegou and min_y > agua + 0.3
	res["tempo_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
	res["min_y_sobre_agua"] = snappedf(min_y - agua, 0.01)
	return res
