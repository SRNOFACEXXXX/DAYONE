extends Node
## Sound library + pooled 2D/3D players.
## Files live in res://assets/audio/<category>/<id>[_N].(ogg|wav|mp3); variations share the id.

const ROOT := "res://assets/audio"
const POOL_3D := 64
const POOL_2D := 32

## Barulho global (tiros, explosões...): IA (zumbis/bots) conecta e decide se ouviu — ver docs/ARMAS_FP.md.
## pos = origem; raio = distância máxima em que é ouvido (m); fonte = quem fez (pode ser null).
signal barulho(pos: Vector3, raio: float, fonte: Node)

var _library: Dictionary = {}      # id -> Array[String] (paths)
var _cache: Dictionary = {}        # path -> AudioStream
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _voice: AudioStreamPlayer
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _ambient_id := ""
var _last_played: Dictionary = {}  # id -> last variation index
## Observador opcional (tests/playtest): Callable(tipo, id, player, opts). Só observa; não altera o comportamento.
var espiao := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_scan(ROOT)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_polyphony = 1
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var q := AudioStreamPlayer.new()
		q.bus = "SFX"
		add_child(q)
		_pool2d.append(q)
	_voice = AudioStreamPlayer.new(); _voice.bus = "Voice"; add_child(_voice)
	_music = AudioStreamPlayer.new(); _music.bus = "Music"; add_child(_music)
	_ambient = AudioStreamPlayer.new(); _ambient.bus = "Music"; add_child(_ambient)
	Settings.apply_audio()


func _setup_buses() -> void:
	for bus_name in ["SFX", "Music", "Voice", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# tiros: Tiros (compressor leve = "parede de som" no automático) <- TiroMedio/TiroLonge (passa-baixa pela distância)
	_bus("Tiros", "SFX")
	_bus("TiroMedio", "Tiros")
	_bus("TiroLonge", "Tiros")
	var tiros := AudioServer.get_bus_index("Tiros")
	if AudioServer.get_bus_effect_count(tiros) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -12.0
		comp.ratio = 3.0
		comp.attack_us = 800.0
		comp.release_ms = 120.0
		comp.gain = 2.0
		AudioServer.add_bus_effect(tiros, comp)
	for par in [["TiroMedio", 2800.0], ["TiroLonge", 1000.0]]:
		var bi := AudioServer.get_bus_index(par[0])
		if AudioServer.get_bus_effect_count(bi) == 0:
			var lpf := AudioEffectLowPassFilter.new()
			lpf.cutoff_hz = par[1]
			lpf.resonance = 0.5
			AudioServer.add_bus_effect(bi, lpf)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, lim)


func _bus(nome: String, envia: String) -> void:
	if AudioServer.get_bus_index(nome) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, nome)
		AudioServer.set_bus_send(idx, envia)


## Emite o barulho global (ver signal barulho). Ex.: Audio.barulho.connect(func(pos, raio, fonte): if pos.distance_to(me) <= raio: ...)
func emitir_barulho(pos: Vector3, raio: float, fonte: Node = null) -> void:
	barulho.emit(pos, raio, fonte)


## Ajuda para IA: o ponto `ouvinte` escuta um barulho (pos, raio)? (paredes/terreno não contam)
static func ouve(ouvinte: Vector3, pos: Vector3, raio: float) -> bool:
	return ouvinte.distance_squared_to(pos) <= raio * raio


func _scan(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_scan(dir_path + "/" + f)
		else:
			var file := f.trim_suffix(".import").trim_suffix(".remap")
			var ext := file.get_extension().to_lower()
			if ext in ["ogg", "wav", "mp3"]:
				var base := file.get_basename()
				var id := base
				var parts := base.rsplit("_", true, 1)
				if parts.size() == 2 and parts[1].is_valid_int():
					id = parts[0]
				var full := dir_path + "/" + file
				if not _library.has(id):
					_library[id] = []
				if not (full in _library[id]):
					_library[id].append(full)
		f = d.get_next()


func has_sound(id: String) -> bool:
	return _library.has(id)


func _stream(id: String) -> AudioStream:
	var list: Array = _library.get(id, [])
	if list.is_empty():
		if espiao.is_valid():
			espiao.call("faltando", id, null, {})
		return null
	var idx := randi() % list.size()
	if list.size() > 1 and _last_played.get(id, -1) == idx:
		idx = (idx + 1) % list.size()
	_last_played[id] = idx
	var path: String = list[idx]
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Positional sound. opts: volume_db, pitch, pitch_var, max_distance, unit_size, bus,
## atenuacao (false = sem atenuação do Godot: o volume já vem calculado, ex. TiroSom), atraso (s, ex. distância/343)
func play_at(id: String, pos: Vector3, opts: Dictionary = {}) -> AudioStreamPlayer3D:
	var atraso: float = opts.get("atraso", 0.0)
	if atraso > 0.02 and is_inside_tree():
		var o2 := opts.duplicate()
		o2.erase("atraso")
		get_tree().create_timer(atraso, false).timeout.connect(play_at.bind(id, pos, o2))
		return null
	var s := _stream(id)
	if s == null:
		return null
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stop()
	p.stream = s
	p.global_position = pos
	p.volume_db = opts.get("volume_db", 0.0)
	p.unit_size = opts.get("unit_size", 6.0)
	p.max_distance = opts.get("max_distance", 80.0)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE if opts.get("atenuacao", true) else AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.bus = opts.get("bus", "SFX")
	p.pitch_scale = opts.get("pitch", 1.0) * (1.0 + randf_range(-1.0, 1.0) * opts.get("pitch_var", 0.04))
	p.play()
	if espiao.is_valid():
		espiao.call("play_at", id, p, opts)
	return p


## Non-positional sound (own weapon, UI).
func play(id: String, opts: Dictionary = {}) -> AudioStreamPlayer:
	var s := _stream(id)
	if s == null:
		return null
	var p := _pool2d[_next2d]
	_next2d = (_next2d + 1) % _pool2d.size()
	p.stop()
	p.stream = s
	p.volume_db = opts.get("volume_db", 0.0)
	p.bus = opts.get("bus", "SFX")
	p.pitch_scale = opts.get("pitch", 1.0) * (1.0 + randf_range(-1.0, 1.0) * opts.get("pitch_var", 0.03))
	p.play()
	if espiao.is_valid():
		espiao.call("play", id, p, opts)
	return p


func ui(id: String) -> void:
	play(id, {"bus": "UI", "pitch_var": 0.0})


func voice(id: String) -> void:
	var s := _stream(id)
	if s == null:
		return
	_voice.stream = s
	_voice.play()
	if espiao.is_valid():
		espiao.call("voice", id, _voice, {})


func music(id: String, volume_db: float = 0.0) -> void:
	var s := _stream(id)
	if s == null:
		_music.stop()
		return
	if _music.stream == s and _music.playing:
		return
	_music.stream = _looped(s)
	_music.volume_db = volume_db
	_music.play()
	if espiao.is_valid():
		espiao.call("music", id, _music, {})


func stop_music() -> void:
	_music.stop()


func ambient(id: String, volume_db: float = -8.0) -> void:
	if id == _ambient_id and _ambient.playing:
		_ambient.volume_db = volume_db
		return
	var s := _stream(id)
	if s == null:
		_ambient.stop()
		_ambient_id = ""
		return
	_ambient.stream = _looped(s)
	_ambient.volume_db = volume_db
	_ambient.play()
	_ambient_id = id
	if espiao.is_valid():
		espiao.call("ambient", id, _ambient, {})


func set_ambient_volume(volume_db: float) -> void:
	if _ambient.playing:
		_ambient.volume_db = volume_db


func stop_ambient() -> void:
	_ambient.stop()
	_ambient_id = ""


## Player 3D em laço (motor de veículo etc.): o chamador põe na árvore, ajusta pitch_scale/volume_db e dá play().
func loop_player_3d(id: String, bus := "SFX") -> AudioStreamPlayer3D:
	var s := _stream(id)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = _looped(s.duplicate())
	p.bus = bus
	p.unit_size = 8.0
	p.max_distance = 90.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	return p


## Ambiente e música tocam em laço (ogg/wav importados sem loop por padrão).
func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif s is AudioStreamMP3:
		s.loop = true
	return s
