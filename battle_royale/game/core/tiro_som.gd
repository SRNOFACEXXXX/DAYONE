class_name TiroSom
extends RefCounted
## Som de tiro "de simulador" para todas as armas de fogo (sons gerados por tools/audio_peso.py em assets/audio/weapons/t2).
## Camadas: <arma>_t2_perto (estampido + reforço grave + thump), _fatia (rajada, 2,4 períodos com fade cruzado),
## _mec (ferrolho), _cauda (eco de campo aberto 1,3–2,6 s), _longe / _longe_fatia (perspectiva distante filtrada).
## Propagação (tiro alheio): atraso d/343 s, ganho por distância (curva suave, audível até ALCANCE_M), passa-baixa por
## barramento (Tiros < 150 m, TiroMedio < 450 m, TiroLonge além) e troca perto -> longe entre 40 e 250 m.
## Cada tiro emite Audio.barulho(pos, raio, fonte) (zumbis/bots ouvem) e, no tiro local, um tremor curto de câmera.

const ALCANCE_M := 1000.0
const VEL_SOM := 343.0
const PITCH_VAR := 0.03
const CAUDA_MIN_S := 0.18   # na rajada a cauda é re-disparada no máximo a cada 0,18 s (a soma vira a "parede de som")
## T = período da rajada (s); raio = alcance do barulho para IA (m); tremor = PlayerController.shake() do tiro local.
const PERFIS := {
	&"ak47": {"T": 0.0916, "auto": true, "raio": 900.0, "tremor": 0.32},
	&"m4": {"T": 0.0843, "auto": true, "raio": 850.0, "tremor": 0.26},
	&"m249": {"T": 0.0783, "auto": true, "raio": 950.0, "tremor": 0.34},
	&"uzi": {"T": 0.062, "auto": true, "raio": 450.0, "tremor": 0.16},
	&"glock": {"T": 0.15, "auto": false, "raio": 400.0, "tremor": 0.14},
	&"usp": {"T": 0.17, "auto": false, "raio": 450.0, "tremor": 0.18},
	&"mosin": {"T": 1.45, "auto": false, "raio": 1000.0, "tremor": 0.55},
	&"m107": {"T": 1.1, "auto": false, "raio": 1200.0, "tremor": 0.9},
}
static var _estado := {}   # id do atirador -> {"t": ms do último tiro, "rajada": bool, "cauda": ms da última cauda}


static func tem(def: WeaponDef) -> bool:
	return PERFIS.has(def.id)


## Ganho (dB) do som direto pela distância: -0,6 x 20·log10(d/8) (mais suave que o físico: tiro se ouve longe).
## 100 m ≈ -13,2 dB; 500 m ≈ -21,5; 1000 m ≈ -25,2.
static func ganho_distancia_db(d: float) -> float:
	return -12.0 * log(maxf(d, 8.0) / 8.0) / log(10.0)


static func barramento(d: float) -> String:
	if d < 150.0:
		return "Tiros"
	if d < 450.0:
		return "TiroMedio"
	return "TiroLonge"


static func _db(w: float) -> float:
	return 20.0 * log(maxf(w, 0.0001)) / log(10.0)


## Plano de camadas de um tiro — usado no jogo e pelo teste offline (tests/audio_armas.gd).
## Retorna [{id, atraso, volume_db, bus}]. fim_rajada = só a cauda cheia ao soltar o gatilho.
static func plano(arma: String, d: float, local: bool, rajada: bool, com_cauda: bool, fim_rajada := false) -> Array:
	var c: Array = []
	var base := arma + "_t2_"
	if local:
		if not fim_rajada:
			c.append({"id": base + ("fatia" if rajada else "perto"), "atraso": 0.0, "volume_db": 0.0, "bus": "Tiros"})
			c.append({"id": base + "mec", "atraso": 0.0, "volume_db": -3.0, "bus": "Tiros"})
		if com_cauda:
			c.append({"id": base + "cauda", "atraso": 0.0, "volume_db": 0.0 if fim_rajada else -1.0, "bus": "Tiros"})
		return c
	if d > ALCANCE_M:
		return c
	var g := ganho_distancia_db(d)
	var atraso := d / VEL_SOM
	var bus := barramento(d)
	if not fim_rajada:
		var w_perto := clampf(1.0 - (d - 50.0) / 200.0, 0.0, 1.0)
		var w_longe := clampf((d - 40.0) / 110.0, 0.0, 1.0)
		if w_perto > 0.01:
			c.append({"id": base + ("fatia" if rajada else "perto"), "atraso": atraso, "volume_db": g + _db(w_perto), "bus": bus})
		if w_longe > 0.01:
			var lid := base + ("longe_fatia" if rajada else "longe")
			c.append({"id": lid, "atraso": atraso, "volume_db": g + 6.0 + _db(w_longe), "bus": bus})
	if com_cauda:
		# a reverberação do campo decai mais devagar que o som direto: é o que se ouve "sempre", de longe
		c.append({"id": base + "cauda", "atraso": atraso + 0.02, "volume_db": g * 0.55 + (0.0 if fim_rajada else -2.0), "bus": bus})
	return c


## Toca o tiro. `s` = atirador; local = própria arma (2D, sem posição); pos = de onde vem o som (tiro alheio).
static func tocar(no: Node, s: Soldier, def: WeaponDef, local: bool, pos: Vector3) -> void:
	var p: Dictionary = PERFIS[def.id]
	var arma := String(def.id)
	var agora := Time.get_ticks_msec()
	var chave := s.get_instance_id()
	var est: Dictionary = _estado.get(chave, {"t": -99999, "rajada": false, "cauda": -99999})
	var folga := (agora - int(est.t)) * 0.001
	var rajada: bool = bool(p.auto) and folga < float(p.T) * 2.2
	var com_cauda := (agora - int(est.cauda)) * 0.001 >= CAUDA_MIN_S
	if com_cauda:
		est.cauda = agora
	est.rajada = rajada
	est.t = agora
	_estado[chave] = est
	var d := 0.0
	if not local:
		var ouvinte := _ouvinte(no)
		d = ouvinte.distance_to(pos) if ouvinte != Vector3.INF else 30.0
	for camada in plano(arma, d, local, rajada, com_cauda):
		_toca(camada, local, pos)
	var origem := s.global_position if local and s.is_inside_tree() else pos
	Audio.emitir_barulho(origem, float(p.raio), s)
	if local and s.controller != null and s.controller.has_method("shake"):
		s.controller.shake(float(p.tremor))   # tremor curto (decai em ~0,2 s) = peso do disparo
	if rajada and no.is_inside_tree():
		var marca := agora
		no.get_tree().create_timer(float(p.T) * 2.4).timeout.connect(func() -> void:
			var e2: Dictionary = _estado.get(chave, {})
			if int(e2.get("t", 0)) == marca and bool(e2.get("rajada", false)):
				e2.rajada = false
				for camada in plano(arma, d, local, false, true, true):
					_toca(camada, local, pos))


static func _toca(c: Dictionary, local: bool, pos: Vector3) -> void:
	if local:
		Audio.play(String(c.id), {"volume_db": float(c.volume_db), "pitch_var": PITCH_VAR, "bus": String(c.bus)})
		return
	Audio.play_at(String(c.id), pos, {"volume_db": float(c.volume_db), "bus": String(c.bus), "atenuacao": false,
		"max_distance": ALCANCE_M + 50.0, "atraso": float(c.atraso), "pitch_var": PITCH_VAR})


static func _ouvinte(no: Node) -> Vector3:
	if no == null or not no.is_inside_tree():
		return Vector3.INF
	var cam := no.get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.INF
