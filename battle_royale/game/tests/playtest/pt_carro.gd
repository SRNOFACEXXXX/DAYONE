extends RefCounted
## Etapa CARRO: acha o carro mais próximo, entra (segurando E), dirige 10 s, mede velocidade/tombo/sons, sai.
const U := preload("res://tests/playtest/pt_util.gd")


static func run(c) -> void:
	c.comeca_etapa("carro", 100.0)
	var s: Soldier = c.s
	var R := {}
	c.metricas["carro"] = R
	c.solta_entradas()
	c.limpa_zumbis()
	var carros = c.get_tree().get_nodes_in_group("drivable_vehicle")
	R["carros_no_mapa"] = carros.size()
	if carros.is_empty():
		c.achado("SEM_CARROS", "alto", "Nenhum DrivableVehicle no mapa", {}, "", "Carros")
		c.termina_etapa()
		return
	var spawn := s.global_position
	var melhor: DrivableVehicle = null
	var md := INF
	for v in carros:
		var d := (v as Node3D).global_position.distance_to(spawn)
		if d < md:
			md = d
			melhor = v
	R["carro"] = {"tipo": melhor.vehicle_kind, "pos": U.v3(melhor.global_position), "dist_do_spawn_m": snappedf(md, 0.1), "nome": String(melhor.name)}
	# põe o jogador ao lado da porta do motorista (lado esquerdo = -X local) olhando para o carro
	var entrou := false
	for off in [Vector3(-2.3, 0, 0), Vector3(2.3, 0, 0), Vector3(0, 0, 3.0), Vector3(0, 0, -3.0)]:
		var pos: Vector3 = melhor.global_transform * off
		pos.y = c.chao_em(pos.x, pos.z, melhor.global_position.y + 6.0) + 0.1
		c.teleporta(pos, U.yaw_de(melhor.global_position - pos))
		await c.fq(25)
		if c.pc._nearest_vehicle() == null:
			continue
		c.shot("carro_perto")
		var i0: int = c.audio_ev.size()
		var t_in: float = c.tempo()
		Input.action_press("use")
		var g := 0
		while c.pc.active_vehicle == null and g < 200 and c.vivo():
			await c.fq(1)
			g += 1
		Input.action_release("use")
		await c.fq(10)
		if c.pc.active_vehicle != null:
			entrou = true
			R["entrada"] = {"tempo_s": snappedf(c.tempo() - t_in, 0.01), "sons_na_entrada": c.audio_ev.slice(i0).map(func(e): return e.id)}
			break
	if not entrou:
		c.achado("CARRO_NAO_ENTRA", "alto", "Não conseguiu entrar no carro segurando E a 2-3 m", R["carro"], "", "Carros")
		R["quadros"] = c.resumo_quadros("carro")
		c.termina_etapa()
		return
	var car: DrivableVehicle = c.pc.active_vehicle
	c.shot("dentro_do_carro")
	var i_dir: int = c.audio_ev.size()
	var ext0: int = c.externos_ev.size()
	var bus0: int = c.bus_amostras.size()
	var t0: float = c.tempo()
	var p_ini := car.global_position
	var vmax := 0.0
	var roll_max := 0.0
	var amostras: Array = []
	var tombou := false
	var seq := [["move_forward", 4.0, ""], ["move_forward", 3.0, "move_right"], ["move_forward", 3.0, "move_left"]]
	for etapa in seq:
		Input.action_press(etapa[0])
		if etapa[2] != "":
			Input.action_press(etapa[2])
		var tt: float = c.tempo()
		while c.vivo() and c.tempo() - tt < float(etapa[1]):
			await c.fq(8)
			var v := car.linear_velocity.length()
			vmax = maxf(vmax, v)
			var roll := rad_to_deg(car.global_basis.y.angle_to(Vector3.UP))
			roll_max = maxf(roll_max, roll)
			if roll > 60.0:
				tombou = true
			amostras.append({"t": snappedf(c.tempo() - t0, 0.1), "kmh": car.speed_kmh(), "roll": snappedf(roll, 0.1)})
		c.shot("dirigindo_" + str(etapa[2] if etapa[2] != "" else "reto"))
		Input.action_release(etapa[0])
		if etapa[2] != "":
			Input.action_release(etapa[2])
	# freia
	Input.action_press("move_back")
	await c.seg(2.0)
	Input.action_release("move_back")
	var tev = c.audio_ev.slice(i_dir)
	var ids := {}
	for e in tev:
		ids[e.id] = int(ids.get(e.id, 0)) + 1
	var ext_novos: Array = c.externos_ev.slice(ext0)
	var dist := Vector2(car.global_position.x - p_ini.x, car.global_position.z - p_ini.z).length()
	# nível do master durante a condução
	var pk: Array = []
	for a in c.bus_amostras.slice(bus0):
		pk.append(float(a.db.get("Master", -80.0)))
	pk.sort()
	R["conducao"] = {"duracao_s": snappedf(c.tempo() - t0, 0.1), "vel_max_kmh": snappedf(vmax * 3.6, 0.1), "distancia_m": snappedf(dist, 0.1),
		"inclinacao_max_graus": snappedf(roll_max, 0.1), "tombou": tombou, "amostras": amostras.slice(0, 60, 3),
		"sons_tocados_via_Audio": ids, "players_externos_novos": ext_novos, "pico_master_mediana_db": snappedf(pk[pk.size() / 2], 0.1) if not pk.is_empty() else null}
	R["tem_arquivo_motor"] = Audio.has_sound("engine") or Audio.has_sound("car_engine") or Audio.has_sound("motor") or Audio.has_sound("engine_loop")
	var motor := false
	for id in ids:
		var sid := String(id)
		if sid.contains("engine") or sid.contains("motor") or sid.contains("car"):
			motor = true
	for e in ext_novos:
		var a := String(e.arquivo).to_lower()
		if a.contains("engine") or a.contains("motor") or a.contains("car"):
			motor = true
	R["som_de_motor_detectado"] = motor
	if vmax * 3.6 > 10.0 and not motor:
		c.achado("CARRO_MUDO", "critico", "Carro dirigido a até %.0f km/h por %.0f s sem nenhum evento/loop de motor (só portas existem em assets/audio/vehicle)" % [vmax * 3.6, c.tempo() - t0],
			{"vel_max_kmh": snappedf(vmax * 3.6, 0.1), "eventos_audio": ids, "players_externos": ext_novos.map(func(e): return e.arquivo), "arquivos_vehicle": ["door_open", "door_close"]},
			"", "Carros")
	if vmax * 3.6 < 15.0:
		c.achado("CARRO_LENTO", "medio", "Velocidade máxima de apenas %.1f km/h em 10 s acelerando" % (vmax * 3.6), R["conducao"], "", "Carros")
	if tombou:
		c.achado("CARRO_TOMBOU", "alto", "Carro tombou (inclinação %.0f graus) em condução simples" % roll_max, R["conducao"], "", "Carros")
	# sai
	var t_s: float = c.tempo()
	Input.action_press("use")
	var g2 := 0
	while c.pc.active_vehicle != null and g2 < 240 and c.vivo():
		await c.fq(1)
		g2 += 1
	Input.action_release("use")
	await c.fq(20)
	R["saida"] = {"saiu": c.pc.active_vehicle == null, "tempo_s": snappedf(c.tempo() - t_s, 0.01), "vel_kmh_ao_sair": car.speed_kmh()}
	c.shot("saiu_do_carro")
	if c.pc.active_vehicle != null:
		c.achado("CARRO_NAO_SAI", "alto", "Não saiu do carro segurando E por 3,7 s", R["saida"], "", "Carros")
	R["quadros"] = c.resumo_quadros("carro")
	c.solta_entradas()
	c.termina_etapa()
