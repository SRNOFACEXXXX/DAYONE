extends Node3D
## COMBATE-NÚCLEO / balística: dispara (sem dispersão) contra paredes de teste a 50/100/200/400 m e mede
## queda em relação à linha de visada (cm) e tempo de voo; compara com referência RK4 fina (mesmo modelo
## de arrasto a = -k·|v|·v + g) e com o tempo de voo analítico t = (e^{kx}-1)/(k·v0).
## Também confere acerto/dano num soldado-alvo a 100 m (bots/zumbis usam o mesmo caminho de hitbox).
## Uso: godot --path game res://tests/combate_balistica.tscn -- [--armas=ak47,m4,mosin,m107,glock] [--tag=depois]
## Saída: raw/triagem/combate_balistica_<tag>.json ; imprime COMBATE_BALISTICA_OK / _FALHOU.

const DISTS := [50.0, 100.0, 200.0, 400.0]
const G := 9.81

class FakeMatch extends Node:
	var impactos: Array = []
	var tiros := 0
	var danos: Array = []
	func is_survival() -> bool: return false
	func on_shot(_s, _d, _o, _h) -> void: tiros += 1
	func on_impact(pos: Vector3, _n: Vector3, _surf: String, _dir: Vector3) -> void: impactos.append(pos)
	func report_noise(_s, _p, _r) -> void: pass
	func on_damage(_v, _a, amount, group) -> void: danos.append([amount, group])
	func friendly_fire() -> bool: return true
	func drop_on_death(_s) -> void: pass
	func site_at(_p) -> String: return ""
	func can_plant() -> bool: return false
	func planted_bomb() -> Node3D: return null

var fm: FakeMatch
var s: Soldier
var R := {}
var ultimo_impacto := {}


func _ready() -> void:
	get_tree().create_timer(180.0).timeout.connect(func() -> void: print("COMBATE_BALISTICA_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	fm = FakeMatch.new()
	add_child(fm)
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new(); bx.size = Vector3(10, 1, 10)   # só sob o atirador: a bala não pode bater no chão antes da parede
	cs.shape = bx
	chao.add_child(cs)
	chao.position = Vector3(0, -0.5, 0)
	add_child(chao)
	s = Soldier.new()
	s.is_bot = true
	s.team = 0
	add_child(s)
	s.match_ref = fm
	s.global_position = Vector3(0, 0.02, 0)
	if s.has_signal("bala_impacto"):
		s.connect("bala_impacto", func(info: Dictionary) -> void: ultimo_impacto = info)
	await _frames(20)
	var armas := String(Game.test_args.get("armas", "ak47,m4,mosin,m107,glock")).split(",")
	var falhas := 0
	for a in armas:
		var r := await _arma(a)
		R[a] = r
		falhas += int(r.get("falhas", 0))
		print("BAL ", a, " ", JSON.stringify(r))
	R["alvo_soldado"] = await _alvo_soldado()
	if not bool(R["alvo_soldado"].get("passou", false)):
		falhas += 1
	R["falhas"] = falhas
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("combate_balistica_%s.json" % String(Game.test_args.get("tag", "x"))), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("COMBATE_BALISTICA_OK" if falhas == 0 else "COMBATE_BALISTICA_FALHOU %d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _parede(d: float) -> StaticBody3D:
	var w := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new(); bx.size = Vector3(40, 40, 0.6)
	cs.shape = bx
	w.add_child(cs)
	w.set_meta("surface", "stone")
	add_child(w)
	w.global_position = Vector3(0, 1.6, -d - 0.3)   # face de entrada exatamente em z = -d
	return w


func _num(def: WeaponDef, campo: String, padrao: float) -> float:
	var v = def.get(campo)
	return float(v) if v != null else padrao


## Referência fina (RK4, dt = 0,05 ms) no plano vertical: retorna [queda_visada_m, t_voo_s, y_bruto_m].
func _ref(v0: float, k: float, h: float, theta: float, x_alvo: float) -> Array:
	var p := Vector2(0.0, -h)
	var v := Vector2(cos(theta), sin(theta)) * v0
	var t := 0.0
	var dt := 0.00005
	var acc := func(vel: Vector2) -> Vector2: return -k * vel.length() * vel + Vector2(0, -G)
	while p.x < x_alvo and t < 6.0:
		var k1v: Vector2 = acc.call(v); var k1p := v
		var k2v: Vector2 = acc.call(v + k1v * dt * 0.5); var k2p := v + k1v * dt * 0.5
		var k3v: Vector2 = acc.call(v + k2v * dt * 0.5); var k3p := v + k2v * dt * 0.5
		var k4v: Vector2 = acc.call(v + k3v * dt); var k4p := v + k3v * dt
		var np := p + (k1p + 2.0 * k2p + 2.0 * k3p + k4p) * dt / 6.0
		var nv := v + (k1v + 2.0 * k2v + 2.0 * k3v + k4v) * dt / 6.0
		if np.x >= x_alvo:
			var f := (x_alvo - p.x) / (np.x - p.x)
			return [-(p.y + (np.y - p.y) * f), t + dt * f, p.y + (np.y - p.y) * f]
		p = np; v = nv; t += dt
	return [INF, INF, INF]


## Ângulo de zeragem pela referência RK4 (bissecção): trajetória cruza a visada em z.
func _theta_ref(v0: float, k: float, h: float, z: float) -> float:
	var lo := -0.01
	var hi := 0.05
	for _i in 40:
		var mid := (lo + hi) * 0.5
		var r := _ref(v0, k, h, mid, z)
		if float(r[0]) > 0.0:   # ainda abaixo da visada -> sobe
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


func _arma(id: String) -> Dictionary:
	var ws := s.give_weapon(StringName(id))
	var def := ws.def
	var backup := [def.spread_stand, def.spread_crouch, def.recoil_random, def.spread_move]
	def.spread_stand = 0.0; def.spread_crouch = 0.0; def.recoil_random = 0.0; def.spread_move = 0.0
	await _frames(int(def.draw_time * 64.0) + 10)
	var v0 := _num(def, "muzzle_velocity", 0.0)
	var k := _num(def, "air_friction", 0.0)
	var h := _num(def, "sight_height", 0.0)
	var z := _num(def, "zero_range", 0.0)
	var r := {"v0_m_s": v0, "k_1_m": k, "altura_mira_m": h, "zero_m": z, "medidas": {}}
	var theta := _theta_ref(v0, k, h, z) if v0 > 0.0 else 0.0
	r["theta_zero_ref_mrad"] = snappedf(theta * 1000.0, 0.001)
	if s.current_def() and s.current_def().has_method("zero_angle"):
		r["theta_zero_jogo_mrad"] = snappedf(float(s.current_def().call("zero_angle")) * 1000.0, 0.001)
	var falhas := 0
	for d: float in DISTS:
		var wall := _parede(d)
		await _frames(3)
		fm.impactos.clear()
		ultimo_impacto = {}
		ws.mag = def.mag_size
		s.yaw = 0.0
		s.pitch = 0.0
		s.shots_fired = 0.0
		s.fire_inacc = 0.0
		s.next_attack = 0.0
		var eye_y := s.eye_position().y
		var t_tiro := s.t
		s.in_fire = true
		await _frames(1)
		s.in_fire = false
		var esperou := 0
		while fm.impactos.is_empty() and esperou < 64 * 3:
			await _frames(1)
			esperou += 1
		var m := {}
		if fm.impactos.is_empty():
			m["acertou"] = false
		else:
			var p: Vector3 = fm.impactos[0]
			m["acertou"] = true
			m["queda_cm"] = snappedf((eye_y - p.y) * 100.0, 0.01)
			m["t_voo_s"] = snappedf(float(ultimo_impacto.get("t_voo", s.t - t_tiro)), 0.0001)
			if ultimo_impacto.has("vel"):
				m["vel_impacto_m_s"] = snappedf(float(ultimo_impacto["vel"]), 0.1)
		if v0 > 0.0:
			var ref := _ref(v0, k, h, theta, d)
			var t_an := (exp(k * d) - 1.0) / (k * v0) if k > 0.0 else d / v0
			m["ref_queda_cm"] = snappedf(float(ref[0]) * 100.0, 0.01)
			m["ref_t_voo_s"] = snappedf(float(ref[1]), 0.0001)
			m["analitico_t_voo_s"] = snappedf(t_an, 0.0001)
			m["ref_queda_bruta_cm"] = snappedf(-(float(ref[2]) + h - d * tan(theta)) * 100.0, 0.01)
			var ok := bool(m["acertou"])
			if ok:
				var eq := absf(float(m["queda_cm"]) - float(m["ref_queda_cm"]))
				m["erro_queda_cm"] = snappedf(eq, 0.01)
				m["erro_queda_pct"] = snappedf(100.0 * eq / maxf(absf(float(m["ref_queda_cm"])), 0.01), 0.1)
				# queda bruta (abaixo da linha do cano) medida = queda da visada + subida do zero - altura da mira
				var bruta := float(m["queda_cm"]) / 100.0 + d * tan(theta) - h
				m["queda_bruta_cm"] = snappedf(bruta * 100.0, 0.01)
				m["erro_queda_bruta_pct"] = snappedf(100.0 * absf(bruta * 100.0 - float(m["ref_queda_bruta_cm"])) / maxf(absf(float(m["ref_queda_bruta_cm"])), 0.01), 0.1)
				m["erro_t_voo_pct"] = snappedf(100.0 * absf(float(m["t_voo_s"]) - t_an) / t_an, 0.1)
				# critério: queda da visada dentro de 10% (ou 2 cm perto do zero), queda bruta e tempo de voo ≤ 10%
				ok = (eq <= maxf(0.10 * absf(float(m["ref_queda_cm"])), 2.0)) and float(m["erro_queda_bruta_pct"]) <= 10.0 and float(m["erro_t_voo_pct"]) <= 10.0
			m["passou"] = ok
			if not ok:
				falhas += 1
		else:
			m["passou"] = false
			falhas += 1
		r["medidas"][str(int(d))] = m
		wall.queue_free()
		await _frames(3)
	def.spread_stand = backup[0]; def.spread_crouch = backup[1]; def.recoil_random = backup[2]; def.spread_move = backup[3]
	r["falhas"] = falhas
	return r


## Soldado-alvo a 100 m: o dano chega depois do tempo de voo e acerta a hitbox do peito.
func _alvo_soldado() -> Dictionary:
	var ws := s.give_weapon(&"m4")
	var def := ws.def
	var bk := [def.spread_stand, def.recoil_random, def.spread_move, def.spread_air]
	def.spread_stand = 0.0; def.recoil_random = 0.0; def.spread_move = 0.0; def.spread_air = 0.0
	await _frames(int(def.draw_time * 64.0) + 10)
	var piso := StaticBody3D.new()
	var pcs := CollisionShape3D.new()
	var pbx := BoxShape3D.new(); pbx.size = Vector3(4, 1, 4)
	pcs.shape = pbx
	piso.add_child(pcs)
	add_child(piso)
	piso.global_position = Vector3(0, -0.5, -100.0)
	var alvo := Soldier.new()
	alvo.team = 1
	add_child(alvo)
	alvo.match_ref = fm
	alvo.global_position = Vector3(0, 0.02, -100.0)
	alvo.yaw = PI
	await _frames(10)
	fm.danos.clear()
	var hp0 := alvo.health
	ws.mag = def.mag_size
	s.yaw = 0.0
	# mira no peito (~1,3 m) de 100 m: olho 1,63 m
	s.pitch = atan2(1.30 - s.eye_height(), 100.0)
	s.shots_fired = 0.0
	s.fire_inacc = 0.0
	s.next_attack = 0.0
	var t0 := s.t
	s.in_fire = true
	await _frames(1)
	s.in_fire = false
	var hp_no_tiro := alvo.health
	var w := 0
	while alvo.health == hp0 and w < 64 * 2:
		await _frames(1)
		w += 1
	var dt := s.t - t0
	var res_extra := {}
	def.spread_stand = bk[0]; def.recoil_random = bk[1]; def.spread_move = bk[2]; def.spread_air = bk[3]
	res_extra["no_chao"] = s.is_on_floor()
	var res := {"hp_antes": hp0, "hp_no_quadro_do_tiro": hp_no_tiro, "hp_depois": alvo.health, "danos": fm.danos.duplicate(), "atraso_s": snappedf(dt, 0.001)}
	res.merge(res_extra)
	res["passou"] = alvo.health < hp0 and hp_no_tiro == hp0 and dt > 0.05
	alvo.queue_free()
	return res
