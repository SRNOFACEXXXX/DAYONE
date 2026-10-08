extends Node
## Mosin no jogo real (br_match): equipar, 5 tiros, recarga, trocar de arma e voltar.
## Mede o tempo de quadro máximo (ms) em cada evento e procura quadros com rosa (magenta de shader/material inválido).
## Uso: godot --path game res://tests/sniper_jogo.tscn -- [--rosa=1 (lê a imagem de cada 2º quadro)] [--cap=1]
## Saída: raw/sniper/sniper_jogo.json
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/sniper"
var m: BRMatch
var pc: PlayerController
var sol: Soldier
var rosa := false
var res := {}
var _uid := {}


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	rosa = Game.test_args.get("rosa", "0") == "1"
	DirAccess.make_dir_recursive_absolute(OUT)
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	sol = m.local_player
	pc = sol.controller as PlayerController
	var hx: float = m.ilha.terrain.height_world(-345.0, 352.0)
	sol.global_position = Vector3(-345.0, hx + 0.1, 352.0)
	sol.velocity = Vector3.ZERO
	sol.yaw = deg_to_rad(40.0)
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	await _frames(60)
	for id in ["mosin", "glock", "m4"]:
		m.br_bag.add_item(id, 1, Vector2i(-1, -1), {"mag": 5})
		for it in m.br_bag.items:
			if String(it.id) == id:
				_uid[id] = int(it.uid)
	await _frames(30)
	res["controle_m4_equipar"] = await _evento(func() -> void: m._equip_br_weapon(_uid["m4"]), 1.5)
	var tm := []
	for i in 3:
		sol.current().mag = 30
		tm.append(await _evento(_tiro, 1.0))
	res["controle_m4_tiros"] = tm
	res["equipar"] = await _evento(func() -> void: m._equip_br_weapon(_uid["mosin"]), 1.5)
	var vm := pc.viewmodel
	var sem := []
	var total := 0
	for raiz in [vm._ferrolho, vm._mosin_clip, vm._mosin_modelo]:
		if raiz == null:
			continue
		for g in (raiz as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := g as MeshInstance3D
			for si in mi.mesh.get_surface_count():
				total += 1
				var mt := mi.get_active_material(si)
				if not (mt is ShaderMaterial and (mt as ShaderMaterial).shader == ViewModel.VM_SHADER):
					sem.append("%s/%d" % [mi.name, si])
	res["superficies_mosin"] = total
	res["superficies_sem_shader_vm"] = sem
	var tiros := []
	for i in 5:
		sol.current().mag = 5
		tiros.append(await _evento(_tiro, 1.6))
	res["tiros"] = tiros
	sol.current().mag = 1
	sol.current().reserve = 25
	res["recarga"] = await _evento(func() -> void: sol.start_reload(), 4.0)
	res["troca_glock"] = await _evento(func() -> void: m._equip_br_weapon(_uid["glock"]), 1.5)
	res["volta_mosin"] = await _evento(func() -> void: m._equip_br_weapon(_uid["mosin"]), 1.5)
	sol.current().mag = 5
	res["tiro_apos_troca"] = await _evento(_tiro, 1.6)
	var mx := 0.0
	var rosas := 0
	for k in res:
		var l: Array = res[k] if res[k] is Array else [res[k]]
		for e in l:
			if not (e is Dictionary and e.has("quadro_max_ms")):
				continue
			mx = maxf(mx, e.quadro_max_ms)
			rosas += int(e.quadros_rosa)
	res["quadro_max_ms_geral"] = mx
	res["quadros_rosa_total"] = rosas
	var f := FileAccess.open(OUT.path_join(String(Game.test_args.get("tag", "")) + "sniper_jogo.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	print("JOGO ", JSON.stringify(res))
	print("JOGO_OK")
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _tiro() -> void:
	Input.action_press("fire")
	await _frames(4)
	Input.action_release("fire")


## Roda a ação e acompanha `dur` s: tempo de quadro máximo/médio e quadros com rosa (>= 200 px magenta).
func _evento(acao: Callable, dur: float) -> Dictionary:
	await _frames(10)
	var t0 := Time.get_ticks_usec()
	var ult := t0
	acao.call()
	var acao_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var mx := 0.0
	var soma := 0.0
	var n := 0
	var n_rosa := 0
	var rosa_max := 0
	var i := 0
	while (Time.get_ticks_usec() - t0) / 1e6 < dur:
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		var ms := (agora - ult) / 1000.0
		if rosa:
			ms = get_process_delta_time() * 1000.0   # com leitura de imagem o relógio de parede não vale
		mx = maxf(mx, ms)
		soma += ms
		n += 1
		i += 1
		if rosa and i % 2 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var c := _conta_rosa(img)
			rosa_max = maxi(rosa_max, c)
			if c >= 200:
				n_rosa += 1
				if Game.test_args.get("cap", "0") == "1" and n_rosa <= 3:
					img.save_png(OUT.path_join("rosa_%d_%d.png" % [Time.get_ticks_msec(), c]))
		ult = Time.get_ticks_usec()
	return {"acao_ms": snappedf(acao_ms, 0.1), "quadro_max_ms": snappedf(mx, 0.1), "quadro_medio_ms": snappedf(soma / maxf(n, 1), 0.1), "quadros": n, "quadros_rosa": n_rosa, "rosa_px_max": rosa_max}


static func _conta_rosa(a: Image) -> int:
	var n := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			var c := a.get_pixel(x, y)
			if c.r > 0.7 and c.b > 0.6 and c.g < 0.5 and c.r - c.g > 0.3:
				n += 1
	return n * 9
