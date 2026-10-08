extends RefCounted
## Etapa SOM: estado do ambiente, gravação silenciosa (ambiente puro), gravação de tiros (cauda/mixagem) e cobertura de sons por ação.
const U := preload("res://tests/playtest/pt_util.gd")


static func _estado_audio() -> Dictionary:
	var amb: AudioStreamPlayer = Audio._ambient
	var mus: AudioStreamPlayer = Audio._music
	var r := {"driver": AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?", "mix_rate": AudioServer.get_mix_rate(),
		"dispositivo": AudioServer.output_device, "latencia_ms": snappedf(AudioServer.get_output_latency() * 1000.0, 0.1),
		"ambiente": {"tocando": amb.playing, "id": Audio._ambient_id, "volume_db": amb.volume_db, "bus": String(amb.bus),
			"arquivo": amb.stream.resource_path.get_file() if amb.stream else "", "duracao_s": snappedf(amb.stream.get_length(), 0.1) if amb.stream else 0.0,
			"pos_s": snappedf(amb.get_playback_position(), 0.1)},
		"musica": {"tocando": mus.playing, "arquivo": mus.stream.resource_path.get_file() if mus.stream else ""},
		"volumes_settings": {"master": Settings.master_volume, "sfx": Settings.sfx_volume, "music": Settings.music_volume, "voice": Settings.voice_volume},
		"buses": {}}
	for i in AudioServer.bus_count:
		r["buses"][AudioServer.get_bus_name(i)] = {"volume_db": snappedf(AudioServer.get_bus_volume_db(i), 0.1), "mudo": AudioServer.is_bus_mute(i),
			"envia_para": String(AudioServer.get_bus_send(i)), "efeitos": AudioServer.get_bus_effect_count(i)}
	return r


static func _acao(c, nome: String, f: Callable) -> Dictionary:
	var i0: int = c.audio_ev.size()
	var ext0: int = c.externos_ev.size()
	await f.call(c)
	var ids := {}
	var faltou: Array = []
	var ok := false
	for e in c.audio_ev.slice(i0):
		if e.tipo == "faltando":
			faltou.append(e.id)
		else:
			ids[e.id] = int(ids.get(e.id, 0)) + 1
			ok = true
	var ext: Array = c.externos_ev.slice(ext0).map(func(e): return e.arquivo)
	if not ext.is_empty():
		ok = true
	return {"acao": nome, "ids": ids, "externos": ext, "tocou_algo": ok, "pediu_e_nao_existe": faltou}


static func a_dano(c) -> void:
	c.s.take_damage(10.0, null, null, "chest", Vector3.BACK)
	await c.seg(0.8)
	c.s.health = 100


static func a_queda(c) -> void:
	c.teleporta(c.s.global_position + Vector3.UP * 7.0, c.s.yaw)
	await c.seg(2.0)


static func a_fogo_seco(c) -> void:
	var ws = c.s.current()
	if ws:
		ws.mag = 0
		ws.reserve = 0
	await c.seg(0.2)
	Input.action_press("fire")
	await c.fq(3)
	Input.action_release("fire")
	await c.seg(0.6)


static func a_faca(c) -> void:
	c.s.switch_to(WeaponDef.Slot.KNIFE)
	await c.seg(1.2)


static func a_golpe(c) -> void:
	Input.action_press("fire")
	await c.fq(3)
	Input.action_release("fire")
	await c.seg(1.0)


static func a_pular(c) -> void:
	Input.action_press("jump")
	await c.fq(3)
	Input.action_release("jump")
	await c.seg(1.2)


static func a_andar(c) -> void:
	Input.action_press("move_forward")
	await c.seg(4.0)
	Input.action_release("move_forward")


static func run(c) -> void:
	c.comeca_etapa("som", 120.0)
	var s: Soldier = c.s
	var R := {}
	c.metricas["som"] = R
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	c.solta_entradas()
	c.limpa_zumbis()
	R["estado_audio"] = _estado_audio()
	# 1) ambiente puro: 8 s parado, sem zumbis
	c.inicia_gravacao("som_quieto", ["Master", "Music", "SFX"])
	var t_q0: float = c.tempo()
	await c.seg(8.0)
	c.para_gravacao("som_quieto")
	R["quieto"] = {"t0": snappedf(t_q0, 0.1), "t1": snappedf(c.tempo(), 0.1)}
	var ambiente_tocando: bool = Audio._ambient.playing
	var bus_music := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	R["bus_music_db_nas_configuracoes_do_usuario"] = snappedf(bus_music, 0.1)
	if ambiente_tocando and bus_music < -40.0:
		c.achado("AMBIENTE_MUDO_BUS_MUSIC", "critico", "O ambiente toca no bus 'Music' e a configuração do usuário (music_volume=%.2f -> %.0f dB) o silencia: sem música não há som ambiente" % [Settings.music_volume, bus_music],
			{"music_volume": Settings.music_volume, "bus_music_db": snappedf(bus_music, 0.1), "ambiente": R["estado_audio"].ambiente, "causa": "Audio.ambient() usa o AudioStreamPlayer _ambient com bus Music; Settings.music_volume=0 mata o ambiente"}, "", "Áudio ambiente")
		# subteste: mesmo ambiente com o volume padrão (0.55) só para avaliar o som em si
		var mv := Settings.music_volume
		Settings.music_volume = 0.55
		Settings.apply_audio()
		await c.seg(0.5)
		c.inicia_gravacao("som_quieto_padrao", ["Master", "Music"])
		var t_p0: float = c.tempo()
		await c.seg(8.0)
		c.para_gravacao("som_quieto_padrao")
		R["quieto_padrao"] = {"t0": snappedf(t_p0, 0.1), "t1": snappedf(c.tempo(), 0.1), "music_volume_usado": 0.55}
		Settings.music_volume = mv
		Settings.apply_audio()
	if not ambiente_tocando:
		c.achado("AMBIENTE_AUSENTE", "critico", "Nenhum som ambiente tocando durante a partida (Audio._ambient parado)", R["estado_audio"].ambiente, "", "Áudio ambiente")
	# 2) tiros: AK, rajada + tiros soltos (gravação com cauda), depois Glock
	U.equipa(c, "ak47")
	await c.seg(1.6)
	c.inicia_gravacao("som_tiros", ["Master", "Music", "SFX"])
	var t_t0: float = c.tempo()
	var i_t: int = c.audio_ev.size()
	s.pitch = 0.0
	for k in 3:
		Input.action_press("fire")
		await c.seg(0.5)
		Input.action_release("fire")
		await c.seg(1.2)
	await c.seg(3.5)   # cauda
	U.equipa(c, "glock")
	await c.seg(1.6)
	for k in 4:
		Input.action_press("fire")
		await c.fq(2)
		Input.action_release("fire")
		await c.seg(0.9)
	await c.seg(3.0)
	c.para_gravacao("som_tiros")
	R["tiros"] = {"t0": snappedf(t_t0, 0.1), "t1": snappedf(c.tempo(), 0.1), "eventos": c.audio_ev.slice(i_t).size()}
	c.shot("tiros")
	# 3) cobertura por ação
	var cob: Array = []
	cob.append(await _acao(c, "levar_dano", a_dano))
	cob.append(await _acao(c, "queda_alta", a_queda))
	cob.append(await _acao(c, "fogo_seco", a_fogo_seco))
	cob.append(await _acao(c, "trocar_arma_faca", a_faca))
	cob.append(await _acao(c, "golpe_de_faca", a_golpe))
	cob.append(await _acao(c, "pular", a_pular))
	cob.append(await _acao(c, "andar_4s", a_andar))
	R["cobertura_acoes"] = cob
	for a in cob:
		if not a.tocou_algo:
			var sev := "alto" if a.acao in ["levar_dano", "andar_4s", "golpe_de_faca"] else "medio"
			c.achado("ACAO_SEM_SOM_" + String(a.acao).to_upper(), sev, "Ação '%s' não produziu nenhum som (pedidos inexistentes: %s)" % [a.acao, ",".join(a.pediu_e_nao_existe)], a, "", "Áudio ambiente" if a.acao == "levar_dano" else "Passos" if a.acao == "andar_4s" else "Áudio armas")
	c.solta_entradas()
	R["quadros"] = c.resumo_quadros("som")
	c.termina_etapa()
