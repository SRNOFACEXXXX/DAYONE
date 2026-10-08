extends Node
## Contexto do playtester: log, eventos, achados, capturas, tempos de quadro, espião de áudio, medidores e gravação por bus.
## Não altera o jogo: só observa (Audio.espiao) e injeta entrada pelo InputMap/Input.parse_input_event.

const BUSES := ["Master", "SFX", "Music", "Voice", "UI", "Tiros", "TiroMedio", "TiroLonge"]
const REC_BUSES := ["Master", "Music", "SFX"]
const MAX_SHOTS := 220

var out := ""
var semente := 1
var m: BRMatch
var s: Soldier
var pc: PlayerController
var ilha: Node3D
var terr: IlhaTerrain
var etapa := ""
var etapa_ini := 0.0
var t0_us := 0
var deadline_ms := 0
var eventos: Array = []
var achados: Array = []
var metricas := {}
var audio_ev: Array = []
var bus_amostras: Array = []
var quadros := {}          # etapa -> Array de ms
var capturas: Array = []   # {etapa, t, evento, arquivo}
var logs: Array = []
var gravacoes := {}        # tag -> {bus: arquivo}
var externos := {}         # id da instância -> true (players fora do Audio)
var externos_ev: Array = []
var _shot_busy := false
var _ultimo_periodico := -99.0
var _t_bus := 0.0
var _t_ext := 0.0
var _last_us := 0
var _recs := {}
var _n_shots := 0
var _sev_ordem := {"critico": 4, "alto": 3, "medio": 2, "baixo": 1, "info": 0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t0_us = Time.get_ticks_usec()
	_last_us = t0_us
	Audio.espiao = Callable(self, "_espia")


func tempo() -> float:
	return float(Time.get_ticks_usec() - t0_us) / 1e6


func log_(msg: String) -> void:
	var l := "[%7.2f][%s] %s" % [tempo(), etapa, msg]
	print("PT ", l)
	logs.append(l)


func ev(tipo: String, dados: Dictionary = {}) -> void:
	var d := {"t": snappedf(tempo(), 0.001), "etapa": etapa, "tipo": tipo}
	d.merge(dados)
	eventos.append(d)


func achado(id: String, sev: String, titulo: String, evidencia: Dictionary, captura := "", categoria := "") -> void:
	for a in achados:
		if a.id == id and a.etapa == etapa and a.get("titulo", "") == titulo:
			a["ocorrencias"] = int(a.get("ocorrencias", 1)) + 1
			return
	achados.append({"id": id, "severidade": sev, "etapa": etapa, "categoria": categoria, "titulo": titulo,
		"evidencia": evidencia, "captura": captura, "t": snappedf(tempo(), 0.01)})
	log_("ACHADO [%s] %s: %s %s" % [sev, id, titulo, JSON.stringify(evidencia)])


func sev_ordem(sev: String) -> int:
	return int(_sev_ordem.get(sev, 0))


func vivo() -> bool:
	return Time.get_ticks_msec() < deadline_ms


func comeca_etapa(nome: String, timeout_s: float) -> void:
	etapa = nome
	etapa_ini = tempo()
	deadline_ms = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	quadros[nome] = []
	_ultimo_periodico = tempo()
	log_("=== etapa %s (timeout %.0f s) ===" % [nome, timeout_s])


func termina_etapa() -> void:
	log_("=== fim da etapa %s em %.1f s ===" % [etapa, tempo() - etapa_ini])
	metricas.get_or_add(etapa, {})["duracao_s"] = snappedf(tempo() - etapa_ini, 0.1)
	etapa = ""
	deadline_ms = 0


# ---- espera com respeito ao tempo limite da etapa
func fq(n: int) -> void:
	for _i in n:
		if not vivo():
			return
		await get_tree().physics_frame


func seg(x: float) -> void:
	await fq(int(ceil(x * float(Engine.physics_ticks_per_second))))


func pq(n: int) -> void:   # quadros de renderização
	for _i in n:
		if not vivo():
			return
		await get_tree().process_frame


# ---- captura
func shot(evento: String) -> String:
	if _n_shots >= MAX_SHOTS or DisplayServer.get_name() == "headless" or out == "":
		return ""
	while _shot_busy:
		await get_tree().process_frame
	_shot_busy = true
	await RenderingServer.frame_post_draw
	var nome := "%s_t%05.1f_%s.png" % [etapa if etapa != "" else "x", tempo(), evento.validate_filename()]
	var img := get_viewport().get_texture().get_image()
	var ok := false
	if img:
		ok = img.save_png(out.path_join("img").path_join(nome)) == OK
	_shot_busy = false
	if not ok:
		return ""
	_n_shots += 1
	capturas.append({"etapa": etapa, "t": snappedf(tempo(), 0.1), "evento": evento, "arquivo": "img/" + nome})
	return "img/" + nome


# ---- espião de áudio
func _cam_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.INF


func _espia(tipo: String, id: String, p: Node, opts: Dictionary) -> void:
	var d := {"t": snappedf(tempo(), 0.001), "etapa": etapa, "tipo": tipo, "id": id}
	if p != null:
		var st: AudioStream = (p as Object).get("stream")
		d["arquivo"] = st.resource_path.get_file() if st else ""
		d["dur"] = snappedf(st.get_length(), 0.001) if st else 0.0
		d["volume_db"] = snappedf(float((p as Object).get("volume_db")), 0.01)
		d["bus"] = String((p as Object).get("bus"))
		d["pitch"] = snappedf(float((p as Object).get("pitch_scale")), 0.001)
		if p is AudioStreamPlayer3D:
			var pos := (p as AudioStreamPlayer3D).global_position
			d["pos"] = [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), snappedf(pos.z, 0.1)]
			var cp := _cam_pos()
			d["dist"] = snappedf(cp.distance_to(pos), 0.1) if cp != Vector3.INF else -1.0
			d["atenuacao"] = (p as AudioStreamPlayer3D).attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED
			d["max_dist"] = (p as AudioStreamPlayer3D).max_distance
		else:
			d["dist"] = 0.0
		if opts.has("atraso"):
			d["atraso"] = opts.atraso
	audio_ev.append(d)


func _sondar_externos() -> void:
	var raiz := get_tree().root
	for n in raiz.find_children("*", "AudioStreamPlayer3D", true, false):
		_ext(n)
	for n in raiz.find_children("*", "AudioStreamPlayer", true, false):
		_ext(n)


func _ext(n: Node) -> void:
	if n.get_parent() == Audio or not (n as Object).get("playing"):
		return
	var iid := n.get_instance_id()
	if externos.has(iid):
		return
	externos[iid] = true
	var st: AudioStream = (n as Object).get("stream")
	var d := {"t": snappedf(tempo(), 0.001), "etapa": etapa, "no": str(n.get_path()), "arquivo": st.resource_path.get_file() if st else "",
		"bus": String((n as Object).get("bus")), "volume_db": snappedf(float((n as Object).get("volume_db")), 0.01), "dur": snappedf(st.get_length(), 0.001) if st else 0.0}
	if n is AudioStreamPlayer3D:
		var cp := _cam_pos()
		d["dist"] = snappedf(cp.distance_to((n as AudioStreamPlayer3D).global_position), 0.1) if cp != Vector3.INF else -1.0
	externos_ev.append(d)


func _process(_dt: float) -> void:
	var us := Time.get_ticks_usec()
	var ms := float(us - _last_us) / 1000.0
	_last_us = us
	if etapa != "" and quadros.has(etapa):
		quadros[etapa].append(ms)
	var t := tempo()
	if t - _t_bus >= 0.1:
		_t_bus = t
		var a := {}
		for b in BUSES:
			var i := AudioServer.get_bus_index(b)
			if i >= 0:
				a[b] = snappedf(maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0)), 0.1)
		bus_amostras.append({"t": snappedf(t, 0.01), "etapa": etapa, "db": a})
	if t - _t_ext >= 1.0:
		_t_ext = t
		_sondar_externos()
	if etapa != "" and t - _ultimo_periodico >= 5.0:
		_ultimo_periodico = t
		shot("periodico")


# ---- gravação do Master (e Music/SFX) em WAV
func inicia_gravacao(tag: String, buses: Array = ["Master"]) -> void:
	_recs[tag] = {}
	for b in buses:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var e := AudioEffectRecord.new()
		AudioServer.add_bus_effect(i, e)
		e.set_recording_active(true)
		_recs[tag][b] = e


func para_gravacao(tag: String) -> void:
	if not _recs.has(tag):
		return
	gravacoes[tag] = {}
	for b in _recs[tag]:
		var e: AudioEffectRecord = _recs[tag][b]
		e.set_recording_active(false)
		var w := e.get_recording()
		var i := AudioServer.get_bus_index(b)
		for k in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
			if AudioServer.get_bus_effect(i, k) == e:
				AudioServer.remove_bus_effect(i, k)
		if w != null:
			var arq := "audio_%s_%s.wav" % [tag, b.to_lower()]
			if w.save_to_wav(out.path_join(arq)) == OK:
				gravacoes[tag][b] = arq
	_recs.erase(tag)


# ---- utilidades de mundo
func chao_em(x: float, z: float, de_y := 60.0) -> float:
	var space := ilha.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, de_y, z), Vector3(x, -20.0, z), 1)
	var h := space.intersect_ray(q)
	return float(h.position.y) if not h.is_empty() else terr.height_world(x, z)


func chao_sob(p: Vector3, excluir: Array = []) -> float:
	var space := ilha.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 30.0, 1, excluir)
	var h := space.intersect_ray(q)
	return float(h.position.y) if not h.is_empty() else terr.height_world(p.x, p.z)


func teleporta(p: Vector3, yaw: float) -> void:
	s.global_position = p
	s.velocity = Vector3.ZERO
	s.yaw = yaw
	s.pitch = 0.0
	s.reset_physics_interpolation()


func solta_entradas() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "walk", "sprint", "alt_fire", "fire", "reload", "use"]:
		Input.action_release(a)


func olha(ponto: Vector3) -> void:
	var d := ponto - s.eye_position()
	var h := Vector2(d.x, d.z).length()
	s.yaw = atan2(-d.x, -d.z)
	s.pitch = clampf(atan2(d.y, h), deg_to_rad(-89.0), deg_to_rad(89.0))


func zumbis() -> Array:
	var r: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z) and not z.is_queued_for_deletion():
			r.append(z)
	return r


func limpa_zumbis() -> int:
	var n := 0
	for z in zumbis():
		z.queue_free()
		n += 1
	return n


func cria_zumbi(pos: Vector3, yaw := 0.0) -> ZombieEnemy:
	var zd := ilha.get_node_or_null("ZombieDirector")
	var z := (load("res://core/zombie.tscn") as PackedScene).instantiate() as ZombieEnemy
	(zd if zd else m).add_child(z)
	z.global_position = Vector3(pos.x, chao_em(pos.x, pos.z, pos.y + 20.0) + 0.05, pos.z)
	z.rotation.y = yaw
	return z


func resumo_quadros(nome: String) -> Dictionary:
	var a: Array = quadros.get(nome, [])
	if a.size() < 5:
		return {"n": a.size()}
	var v := PackedFloat32Array(a)
	var o := v.duplicate()
	o.sort()
	var soma := 0.0
	var l33 := 0
	var l100 := 0
	for x in v:
		soma += x
		if x > 33.4:
			l33 += 1
		if x > 100.0:
			l100 += 1
	return {"n": a.size(), "media_ms": snappedf(soma / a.size(), 0.01), "fps_medio": snappedf(1000.0 / (soma / a.size()), 0.1),
		"p95_ms": snappedf(o[int(o.size() * 0.95)], 0.01), "p99_ms": snappedf(o[mini(int(o.size() * 0.99), o.size() - 1)], 0.01),
		"max_ms": snappedf(o[o.size() - 1], 0.1), "acima_33ms": l33, "acima_100ms": l100}
