extends Node3D
## DANO EM ZUMBIS: usa Soldier real + armas reais (caminho real do projetil) contra ZombieEnemy.
## Valida: cabeca AK = 2 tiros, corpo AK = 5, sniper cabeca 1 tiro, tabela por arma (WeaponDB.ZUMBI_DANO),
## morte exatamente 1 vez, explosao, FPS durante rajada de 30 tiros em 5 zumbis, max. de emissores de sangue.
## Uso: godot --path game res://tests/zumbi_dano.tscn --resolution 1024x768 -- --tag=x
## Saida: raw/triagem/zumbi_dano_<tag>.json, PNGs raw/triagem/zumbi_dano_*.png ; ZUMBI_DANO_OK / _FALHOU.

const DIST := 25.0

class FakeMatch extends Node:
	var fx: FxManager
	func is_survival() -> bool: return false
	func on_shot(_s, _d, _o, _h) -> void: pass
	func on_impact(_p, _n, _sf, _d) -> void: pass
	func report_noise(_s, _p, _r) -> void: pass
	func on_damage(_v, _a, _amount, _group) -> void: pass
	func friendly_fire() -> bool: return true
	func drop_on_death(_s) -> void: pass
	func site_at(_p) -> String: return ""
	func can_plant() -> bool: return false
	func planted_bomb() -> Node3D: return null

var fm: FakeMatch
var fx: FxManager
var s: Soldier
var cam: Camera3D
var R := {}
var falhas := 0
var mortes: Dictionary = {}     # zombie -> contagem do sinal died
var dts: Array[float] = []
var medindo := false
var emissores_max := 0
var out_dir := ""


func _process(dt: float) -> void:
	if medindo:
		dts.append(dt)
		var n := 0
		for c in fx.get_children():
			if c is CPUParticles3D and c.emitting:
				n += 1
		emissores_max = maxi(emissores_max, n)


func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func() -> void: print("ZUMBI_DANO_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	out_dir = ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_cenario()
	await _frames(20)
	await _testes()
	R["falhas"] = falhas
	var tag := String(Game.test_args.get("tag", "x"))
	var f := FileAccess.open(out_dir.path_join("zumbi_dano_%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("ZUMBI_DANO_OK" if falhas == 0 else "ZUMBI_DANO_FALHOU %d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHA: ", msg)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _box(sz: Vector3, pos: Vector3, surface := "") -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = sz
	cs.shape = bx
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.55, 0.55, 0.52)
	bm.material = mt
	mi.mesh = bm
	b.add_child(mi)
	if surface != "":
		b.set_meta("surface", surface)
	add_child(b)
	b.global_position = pos
	return b


func _cenario() -> void:
	fm = FakeMatch.new()
	add_child(fm)
	fx = FxManager.new()
	add_child(fx)
	fm.fx = fx
	_box(Vector3(200, 1, 200), Vector3(0, -0.5, -60))
	_box(Vector3(30, 8, 0.6), Vector3(0, 4, -27.8), "stone")     # parede para o respingo
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 25, 0)
	add_child(luz)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.65)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	we.environment = env
	add_child(we)
	cam = Camera3D.new()
	add_child(cam)
	s = Soldier.new()
	s.is_bot = true
	s.team = 0
	add_child(s)
	s.match_ref = fm
	s.global_position = Vector3(0, 0.02, 0)


func _novo_zumbi(x := 0.0, z := -DIST, vida := 100) -> ZombieEnemy:
	var zb := ZombieEnemy.new()
	zb.detection_range = 0.0
	zb.hearing_range = 0.0
	zb.walk_speed = 0.0
	zb.run_speed = 0.0
	add_child(zb)
	zb.global_position = Vector3(x, 0.02, z)
	zb.max_health = vida
	zb.health = vida
	mortes[zb] = 0
	zb.died.connect(func(_z, _h, _a) -> void: mortes[zb] = int(mortes[zb]) + 1)
	return zb


func _arma(id: StringName) -> WeaponState:
	var ws := s.give_weapon(id, true)
	var d := ws.def
	d.spread_stand = 0.0
	d.spread_crouch = 0.0
	d.spread_move = 0.0
	d.spread_air = 0.0
	d.recoil_random = 0.0
	d.spread_fire = 0.0
	return ws


## Mira (yaw/pitch) num ponto e dispara UM tiro pelo caminho real (_fire_bullet -> projetil simulado).
func _tiro(ws: WeaponState, alvo: Vector3) -> void:
	var o := s.eye_position()
	var d := alvo - o
	s.yaw = atan2(-d.x, -d.z)
	s.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	s.shots_fired = 0.0
	s.fire_inacc = 0.0
	ws.mag = ws.def.mag_size
	s._fire_bullet(ws)
	for _i in 90:
		await get_tree().physics_frame
		if s.balas_em_voo() == 0:
			break
	await get_tree().physics_frame


func _shot_until_dead(ws: WeaponState, zb: ZombieEnemy, y: float, maximo := 12) -> Dictionary:
	var vidas: Array = []
	var zonas: Array = []
	zb.hit_taken.connect(func(z, _a, _at) -> void: zonas.append(String(z)))
	var n := 0
	while zb.state != ZombieEnemy.State.DEAD and n < maximo:
		await _tiro(ws, zb.global_position + Vector3(0, y, 0))
		n += 1
		vidas.append(zb.health)
	return {"tiros": n, "vidas": vidas, "zonas": zonas, "mortes": int(mortes[zb])}


func _testes() -> void:
	var T := {}
	# ---- 1) AK: cabeca = 2 tiros, corpo = 5 tiros
	var ak := _arma(&"ak47")
	var z1 := _novo_zumbi()
	await _frames(5)
	T["ak_cabeca"] = await _shot_until_dead(ak, z1, 1.72)
	print("AK cabeca ", JSON.stringify(T["ak_cabeca"]))
	_check(T["ak_cabeca"].tiros == 2 and T["ak_cabeca"].vidas == [50, 0], "AK cabeca deve matar em 2 tiros (50%)")
	_check(T["ak_cabeca"].zonas == ["head", "head"], "zona deve ser head")
	_check(T["ak_cabeca"].mortes == 1, "1 morte (AK cabeca)")
	var z2 := _novo_zumbi()
	await _frames(5)
	T["ak_corpo"] = await _shot_until_dead(ak, z2, 1.0)
	print("AK corpo ", JSON.stringify(T["ak_corpo"]))
	_check(T["ak_corpo"].tiros == 5 and T["ak_corpo"].vidas == [80, 60, 40, 20, 0], "AK corpo: 5 tiros de 20%")
	_check(T["ak_corpo"].zonas.all(func(z): return z == "body"), "zona deve ser body")
	_check(T["ak_corpo"].mortes == 1, "1 morte (AK corpo)")
	# ---- 2) tabela por arma: queda de vida no 1o tiro de cabeca e de corpo
	var tab := {}
	for id in [&"ak47", &"m4", &"m249", &"glock", &"usp", &"uzi", &"mosin", &"m107"]:
		var ws := _arma(id)
		var zc := _novo_zumbi(0.0, -DIST, 100)
		await _frames(3)
		await _tiro(ws, zc.global_position + Vector3(0, 1.72, 0))
		var cab := 100 - zc.health
		var zb := _novo_zumbi(3.0, -DIST, 100)
		await _frames(3)
		await _tiro(ws, zb.global_position + Vector3(0, 1.0, 0))
		var cor := 100 - zb.health
		var tiros_cab := 0
		while zc.state != ZombieEnemy.State.DEAD and tiros_cab < 12:
			await _tiro(ws, zc.global_position + Vector3(0, 1.72, 0))
			tiros_cab += 1
		var tiros_cor := 0
		while zb.state != ZombieEnemy.State.DEAD and tiros_cor < 14:
			await _tiro(ws, zb.global_position + Vector3(0, 1.0, 0))
			tiros_cor += 1
		tab[String(id)] = {"cabeca_pct": cab, "corpo_pct": cor, "tiros_p_matar_cabeca": tiros_cab + 1, "tiros_p_matar_corpo": tiros_cor + 1,
			"mortes": [int(mortes[zc]), int(mortes[zb])]}
		var esp: Array = WeaponDB.ZUMBI_DANO[id]
		_check(cab == roundi(100.0 * esp[0]) and cor == roundi(100.0 * esp[1]), "tabela %s: obtido %d/%d" % [id, cab, cor])
		_check(int(mortes[zc]) == 1 and int(mortes[zb]) == 1, "1 morte por zumbi (%s)" % id)
		print("ARMA ", id, " ", JSON.stringify(tab[String(id)]))
	T["tabela"] = tab
	_check(tab["mosin"].cabeca_pct == 100 and tab["m107"].cabeca_pct == 100, "sniper: cabeca = morte em 1 tiro")
	_check(tab["mosin"].corpo_pct >= 50 and tab["m107"].corpo_pct >= 50, "sniper: corpo >= 50%")
	_check(tab["glock"].cabeca_pct >= 34 and tab["uzi"].cabeca_pct >= 34, "pistola/uzi cabeca >= 34%")
	_check(tab["glock"].corpo_pct >= 12 and tab["glock"].corpo_pct <= 15 and tab["uzi"].corpo_pct >= 12 and tab["uzi"].corpo_pct <= 15, "pistola/uzi corpo 12-15%")
	# ---- 3) mortes: cadaver nao conta de novo, bala atravessa o cadaver
	var z3 := _novo_zumbi()
	await _frames(3)
	await _tiro(ak, z3.global_position + Vector3(0, 1.72, 0))
	await _tiro(ak, z3.global_position + Vector3(0, 1.72, 0))
	for _i in 3:
		await _tiro(ak, z3.global_position + Vector3(0, 1.0, 0))
	T["cadaver_mortes"] = int(mortes[z3])
	_check(int(mortes[z3]) == 1 and z3.mortes_emitidas == 1 and z3.health == 0, "morte exatamente 1 vez mesmo com tiros no cadaver")
	# ---- 4) explosao
	var ze1 := _novo_zumbi(3.0, -10.0)
	var ze2 := _novo_zumbi(-3.0, -15.0)
	var ze3 := _novo_zumbi(0.0, -30.0)
	await _frames(3)
	var n_exp := ZombieEnemy.explosao(self, Vector3(3.0, 1.0, -8.0), 7.0, 180)
	T["explosao"] = {"atingidos": n_exp, "perto_hp": ze1.health, "longe_hp": ze2.health, "fora_hp": ze3.health}
	print("EXPLOSAO ", JSON.stringify(T["explosao"]))
	_check(ze1.health < 100 and ze2.health == 100 and ze3.health == 100, "explosao fere so dentro do raio")
	ZombieEnemy.explosao(self, Vector3(3.0, 1.0, -9.5), 7.0, 180)
	_check(ze1.state == ZombieEnemy.State.DEAD and int(mortes[ze1]) == 1, "explosao mata e emite 1 morte")
	await _frames(2)
	# ---- 5) capturas de sangue: corpo, cabeca (morte), poca/parede
	for old in get_tree().get_nodes_in_group("zombie"):
		old.queue_free()
	fx.clear_round()
	await _frames(3)
	var zc2 := _novo_zumbi(0.0, -DIST)
	await _frames(10)
	cam.global_position = Vector3(3.2, 1.6, -DIST + 4.2)
	cam.look_at(Vector3(0, 1.2, -DIST), Vector3.UP)
	cam.current = true
	await _frames(3)
	await _tiro(ak, zc2.global_position + Vector3(0, 1.1, 0))
	await _captura("corpo_0")
	await _frames(6)
	await _captura("corpo_1")
	var zh := _novo_zumbi(0.0, -DIST)
	zc2.global_position = Vector3(40, 0, -DIST)
	await _frames(10)
	await _tiro(ak, zh.global_position + Vector3(0, 1.72, 0))
	await _tiro(ak, zh.global_position + Vector3(0, 1.72, 0))
	await _captura("cabeca_morte_0")
	await _frames(8)
	await _captura("cabeca_morte_1")
	await _frames(150)
	await _captura("cabeca_morte_final")
	# ---- 6) FPS: rajada de 30 tiros em 5 zumbis (vida alta: ninguem morre e os 5 alvos ficam)
	var zs: Array[ZombieEnemy] = []
	for k in 5:
		zs.append(_novo_zumbi(-4.0 + 2.0 * k, -DIST, 100))
		zs[k].health = 100000   # nao morre: mantem os 5 alvos; dano = pontos tirados
	if Game.test_args.has("semsangue"):
		FxManager.shared = null   # A/B do custo do sangue
	await _frames(30)
	medindo = true
	dts.clear()
	await get_tree().create_timer(1.5).timeout
	T["fps_base"] = _fps_stats()
	medindo = false
	var ak2 := _arma(&"ak47")
	s.switch_to(ak2.def.slot)
	await _frames(int(ak2.def.draw_time * 64.0) + 10)
	ak2.mag = 30
	ak2.reserve = 90
	dts.clear()
	emissores_max = 0
	medindo = true
	var antes := ak2.mag
	var i := 0
	s.in_fire = true
	var t_fim := Time.get_ticks_msec() + 12000
	while antes - ak2.mag < 30 and Time.get_ticks_msec() < t_fim:
		var z := zs[i % 5]
		var d := (z.global_position + Vector3(0, 1.3, 0)) - s.eye_position()
		s.yaw = atan2(-d.x, -d.z)
		s.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		s.shots_fired = 0.0
		s.fire_inacc = 0.0
		i += 1
		await get_tree().physics_frame
	s.in_fire = false
	await get_tree().create_timer(0.8).timeout
	medindo = false
	T["fps_rajada"] = _fps_stats()
	T["fps_rajada"]["tiros"] = antes - ak2.mag
	T["fps_rajada"]["emissores_max"] = emissores_max
	var danos := 0
	var acertos := 0
	for z in zs:
		danos += 100000 - z.health
		acertos += 1 if z.health < 100000 else 0
	T["fps_rajada"]["dano_total_pts"] = danos
	T["fps_rajada"]["zumbis_feridos"] = acertos
	print("FPS base ", JSON.stringify(T["fps_base"]))
	print("FPS rajada ", JSON.stringify(T["fps_rajada"]))
	_check(T["fps_rajada"].tiros == 30, "30 tiros na rajada")
	_check(acertos == 5 and danos >= 30 * 12, "rajada feriu os 5 zumbis (%d pts)" % danos)
	_check(emissores_max <= 30, "<=30 emissores ativos (%d)" % emissores_max)
	_check(T["fps_rajada"].fps_medio >= 45.0, "FPS medio da rajada >= 45")
	R["testes"] = T


func _fps_stats() -> Dictionary:
	var arr := dts.duplicate()
	arr.sort()
	var soma := 0.0
	for v in arr:
		soma += v
	var n := maxi(arr.size(), 1)
	return {"quadros": arr.size(), "fps_medio": snappedf(float(n) / maxf(soma, 0.0001), 0.1),
		"pior_quadro_ms": snappedf(float(arr.back()) * 1000.0 if arr.size() > 0 else 0.0, 0.1),
		"p99_ms": snappedf(float(arr[int(n * 0.99)] if arr.size() > 0 else 0.0) * 1000.0, 0.1)}


func _captura(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("zumbi_dano_%s.png" % nome))
