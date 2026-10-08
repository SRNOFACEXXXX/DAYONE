extends Node
## 1) Confere que toda camada de tiro (TiroSom.plano) existe na biblioteca para todas as armas.
## 2) Mixagem offline dos planos de TiroSom (mesmos volumes/atrasos/barramentos do jogo) -> raw/audio_preview/*.wav:
##    perto (tiro próprio), 100 m e 500 m (tiro alheio), rajada de 1 s (AK, M4). Passa-baixa dos barramentos e limitador
##    do master (teto 0,95) simulados. Mede pico, loudness de ataque (RMS 50 ms após o início) e duração da cauda
##    (até o envelope de 50 ms cair 40 dB abaixo do ataque). Imprime AUDIO_JSON {...} e grava raw/audio_preview/medidas.json.
const SR := 48000
const DIR := "res://assets/audio/weapons/t2/"
const LPF := {"TiroMedio": 2800.0, "TiroLonge": 1000.0}
var _cache := {}
var _pre := 0.0   # pico antes do limitador do master (último render)


func _ready() -> void:
	var falhas := 0
	for id in WeaponDB.weapons:
		var d: WeaponDef = WeaponDB.get_def(id)
		if not d.is_gun():
			continue
		if not TiroSom.tem(d):
			falhas += 1
			print("FALTA perfil TiroSom ", id)
			continue
		var p: Dictionary = TiroSom.PERFIS[d.id]
		var ids := {}
		for dist in [0.0, 30.0, 100.0, 200.0, 500.0]:
			for raj in ([false, true] if bool(p.auto) else [false]):
				for c in TiroSom.plano(String(id), dist, dist == 0.0, raj, true):
					ids[c.id] = true
		for sid in ids:
			if not Audio.has_sound(sid):
				falhas += 1
				print("FALTA ", sid)
		if absf(d.fire_interval - float(p.T)) > 0.02:
			print("AVISO cadência ", id, " ", d.fire_interval, " vs perfil ", p.T)
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/audio_preview")
	DirAccess.make_dir_recursive_absolute(out)
	var res := {}
	for arma in ["ak47", "m4", "m249", "m107", "mosin", "glock", "usp", "uzi"]:
		var r := {}
		for caso in [["perto", 0.0], ["100m", 100.0], ["500m", 500.0]]:
			var buf := _render(_tiro_unico(arma, caso[1]), 4.5)
			r[caso[0]] = _medir(buf)
			_salvar(out.path_join("%s_%s.wav" % [arma, caso[0]]), buf)
		if arma in ["ak47", "m4"]:
			var b2 := _render(_rajada(arma, 0.0, 1.0), 4.0)
			r["rajada_1s"] = _medir(b2)
			_salvar(out.path_join("%s_rajada_1s.wav" % arma), b2)
			var b3 := _render(_rajada(arma, 100.0, 1.0), 4.0)
			r["rajada_1s_100m"] = _medir(b3)
			_salvar(out.path_join("%s_rajada_1s_100m.wav" % arma), b3)
		res[arma] = r
		if float(r.perto.pico) > 0.951:
			falhas += 1
	var js := JSON.stringify({"falhas": falhas, "armas": res})
	var f := FileAccess.open(out.path_join("medidas.json"), FileAccess.WRITE)
	f.store_string(js)
	f.close()
	print("AUDIO_JSON ", js)
	print("AUDIO_RESULTADO falhas=", falhas)
	get_tree().quit()


func _tiro_unico(arma: String, d: float) -> Array:
	return _em(TiroSom.plano(arma, d, d == 0.0, false, true), 0.0)


func _rajada(arma: String, d: float, dur: float) -> Array:
	var T: float = TiroSom.PERFIS[StringName(arma)].T
	var ev := []
	var t := 0.0
	var ult_cauda := -9.0
	var n := 0
	while t < dur - 0.0001:
		var cc := t - ult_cauda >= TiroSom.CAUDA_MIN_S
		if cc:
			ult_cauda = t
		ev += _em(TiroSom.plano(arma, d, d == 0.0, n > 0, cc), t)
		n += 1
		t += T
	ev += _em(TiroSom.plano(arma, d, d == 0.0, false, true, true), t - T + T * 2.4)
	return ev


func _em(pl: Array, t: float) -> Array:
	var r := []
	for c in pl:
		var c2: Dictionary = c.duplicate()
		c2.t = t + float(c.atraso)
		r.append(c2)
	return r


func _wav(id: String, k: int) -> PackedFloat32Array:
	var path := DIR + "%s_%d.wav" % [id, k]
	if not FileAccess.file_exists(path):
		path = DIR + "%s_1.wav" % id
	if _cache.has(path):
		return _cache[path]
	var b := FileAccess.get_file_as_bytes(path)
	var o := PackedFloat32Array()
	var i := 12
	while i + 8 <= b.size():
		var tag := b.slice(i, i + 4).get_string_from_ascii()
		var sz := b.decode_u32(i + 4)
		if tag == "data":
			o.resize(sz / 2)
			for j in sz / 2:
				o[j] = b.decode_s16(i + 8 + j * 2) / 32768.0
			break
		i += 8 + sz + (sz & 1)
	_cache[path] = o
	return o


func _render(ev: Array, dur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * SR))
	var var_k := 0
	for e in ev:
		var_k += 1
		var s := _wav(String(e.id), 1 + var_k % 3)
		var g := db_to_linear(float(e.volume_db))
		var i0 := int(float(e.t) * SR)
		var a := 1.0
		if LPF.has(e.bus):   # passa-baixa de 2ª ordem aproximado (duas seções de 1 polo)
			a = 1.0 - exp(-TAU * float(LPF[e.bus]) / SR)
		var y1 := 0.0
		var y2 := 0.0
		for j in s.size():
			var k := i0 + j
			if k >= buf.size():
				break
			var x := s[j] * g
			if a < 1.0:
				y1 += a * (x - y1)
				y2 += a * (y1 - y2)
				x = y2
			buf[k] += x
	# limitador do master (ataque instantâneo, liberação 60 ms, teto 0,95)
	_pre = 0.0
	for v in buf:
		_pre = maxf(_pre, absf(v))
	var gl := 1.0
	var rel := exp(-1.0 / (0.06 * SR))
	for k in buf.size():
		var v := absf(buf[k])
		var alvo := minf(1.0, 0.95 / maxf(v, 1e-9))
		gl = alvo if alvo < gl else alvo + (gl - alvo) * rel
		buf[k] = clampf(buf[k] * gl, -0.95, 0.95)
	return buf


func _medir(b: PackedFloat32Array) -> Dictionary:
	var pk := 0.0
	for v in b:
		pk = maxf(pk, absf(v))
	var ini := 0
	while ini < b.size() and absf(b[ini]) < pk * 0.1:
		ini += 1
	var n := int(0.05 * SR)
	var ataque := _rms_db(b, ini, n)
	var fim := ini
	var k := ini
	while k + n < b.size():
		if _rms_db(b, k, n) > ataque - 40.0:
			fim = k + n
		k += n / 2
	return {"pico": snappedf(pk, 0.001), "pico_pre_limitador": snappedf(_pre, 0.001), "loudness_ataque_db": snappedf(ataque, 0.1),
		"inicio_s": snappedf(float(ini) / SR, 0.001), "cauda_s": snappedf(maxf(0.0, float(fim - ini) / SR - 0.12), 0.01)}


func _rms_db(b: PackedFloat32Array, i: int, n: int) -> float:
	var s := 0.0
	for j in range(i, mini(i + n, b.size())):
		s += b[j] * b[j]
	return linear_to_db(sqrt(s / maxf(1.0, float(n))) + 1e-9)


func _salvar(path: String, b: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)       # RIFF
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)       # WAVE
	h.encode_u32(12, 0x20746d66)      # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)
	h.encode_u16(22, 1)
	h.encode_u32(24, SR)
	h.encode_u32(28, SR * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)      # data
	h.encode_u32(40, data.size())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(h + data)
	f.close()
