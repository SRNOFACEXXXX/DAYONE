extends Node
## QA v2: menu -> criador (>=20 s) -> partida real; 60 s andando/correndo/girando com input; zumbis; magenta.
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/qa_v2/"
var R := {}
var _q: Array[float] = []
var _ult := 0
var _med := false
var _fim := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(280.0, true, false, true).timeout.connect(func() -> void: R["timeout"] = true; _salva(); get_tree().quit(2))
	await get_tree().process_frame
	var menus := []
	# 3 aberturas do menu: mede frames e compara imagem do personagem
	var hashes := []
	for i in 3:
		get_tree().current_scene = null
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		await get_tree().create_timer(2.5).timeout
		_q.clear(); _ult = Time.get_ticks_usec(); _fim = _ult + 6000000; _med = true
		while _med: await get_tree().process_frame
		var st := _stats(_q)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT + "menu_abertura_%d.png" % i)
		var small := img.duplicate() as Image
		small.resize(16, 9)
		hashes.append(small.get_data().hex_encode().md5_text())
		var sc := get_tree().current_scene
		var info := {}
		if sc and sc.get("stage") != null:
			var s = sc.stage
			info["soldier"] = str(s.soldier.name) if s.soldier else "null"
			var n_mesh := 0
			if s.soldier: n_mesh = s.soldier.find_children("*", "MeshInstance3D", true, false).size()
			info["meshes_soldier"] = n_mesh
		menus.append({"stats": st, "info": info})
		if i < 2:
			sc.queue_free(); await get_tree().process_frame
	R["menu"] = {"aberturas": menus, "hashes": hashes, "distintos": hashes.size() - 0 if hashes[0] != hashes[1] or hashes[1] != hashes[2] else 1}
	var menu := get_tree().current_scene
	menu.abrir_criador()
	var cr: Node = menu.criador
	_q.clear(); _ult = Time.get_ticks_usec(); _fim = _ult + 22000000; _med = true
	cr.aleatorio()
	while _med: await get_tree().process_frame
	R["criador_22s"] = _stats(_q)
	var t0 := Time.get_ticks_usec()
	cr.confirmar()
	var lim := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < lim:
		await get_tree().process_frame
		var m := Game.current_match
		if m != null and is_instance_valid(m) and m.get("local_player") != null and not Loading._root.visible:
			break
	R["ms_ate_controle"] = (Time.get_ticks_usec() - t0) / 1000.0
	var m: Node = Game.current_match
	var sol: Soldier = m.local_player
	R["zumbis_ao_nascer"] = _zumbis(sol)
	R["hp_inicio"] = sol.health
	await get_tree().create_timer(1.0).timeout
	_q.clear(); _ult = Time.get_ticks_usec(); _fim = _ult + 60000000; _med = true
	var rosa_total := 0
	var k := 0
	var yaw_v := 0.9
	while _med:
		await get_tree().process_frame
		k += 1
		var seg := int((Time.get_ticks_usec() - (_fim - 60000000)) / 1000000.0)
		var f := (seg % 20)
		Input.action_press("move_forward")
		if f < 10: Input.action_release("sprint")
		else: Input.action_press("sprint")
		if seg % 7 == 6: Input.action_press("move_left") 
		else: Input.action_release("move_left")
		sol.yaw += yaw_v * get_process_delta_time() * (1.0 if (seg / 5) % 2 == 0 else -1.0)
		if k % 600 == 0:
			rosa_total += await _shot("p%d" % k, true)
			_ult = Time.get_ticks_usec()
		if k % 600 == 0:
			R["z_%ds" % seg] = _zumbis(sol)
	for a in ["move_forward", "sprint", "move_left"]: Input.action_release(a)
	var st := _stats(_q)
	R["partida_60s"] = st
	R["rosa_px_total"] = rosa_total
	R["hp_fim"] = sol.health
	R["pos_fim"] = [sol.global_position.x, sol.global_position.z]
	_salva()
	print("QA2_FLUXO_OK ", JSON.stringify(R))
	get_tree().quit(0)
func _zumbis(sol: Soldier) -> Dictionary:
	var ds := []
	var estados := {}
	for z in get_tree().get_nodes_in_group("zombies") if get_tree().has_group("zombies") else []:
		pass
	for z in _all_z(get_tree().root):
		var d: float = (z.global_position - sol.global_position).length()
		ds.append(snappedf(d, 0.1))
		var s := str(z.state)
		estados[s] = estados.get(s, 0) + 1
	ds.sort()
	return {"n": ds.size(), "mais_perto": ds.slice(0, 5), "estados": estados}
func _all_z(n: Node) -> Array:
	var r := []
	if n is ZombieEnemy: r.append(n)
	for c in n.get_children(): r.append_array(_all_z(c))
	return r
func _stats(q: Array[float]) -> Dictionary:
	var a := q.duplicate(); a.sort()
	var soma := 0.0; var l33 := 0; var l50 := 0; var l100 := 0
	for v in q:
		soma += v
		if v > 33.0: l33 += 1
		if v > 50.0: l50 += 1
		if v > 100.0: l100 += 1
	var n := a.size()
	return {"quadros": n, "media_ms": snappedf(soma / maxf(n, 1), 0.01), "p99_ms": snappedf(a[int(n * 0.99)] if n > 0 else 0, 0.01), "max_ms": snappedf(a[n - 1] if n > 0 else 0, 0.1), "q33": l33, "q50": l50, "q100": l100, "fps_medio": snappedf(1000.0 / maxf(soma / maxf(n, 1), 0.01), 0.1)}
func _salva() -> void:
	var f := FileAccess.open(OUT + "fluxo_" + String(Game.test_args.get("tag", "x")) + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " ")); f.close()
func _process(_d: float) -> void:
	if not _med: return
	var a := Time.get_ticks_usec()
	var dq := (a - _ult) / 1000.0
	_q.append(dq); _ult = a
	if dq > 100.0:
		var lst: Array = R.get("picos_100ms", [])
		lst.append([snappedf((a - _fim) / 1e6, 0.1), snappedf(dq, 0.0)])
		R["picos_100ms"] = lst
	if a >= _fim: _med = false
func _shot(nome: String, salvar: bool) -> int:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			if c.r > 0.9 and c.b > 0.9 and c.g < 0.15: n += 1
	n *= 4
	if n > 0: R["rosa_" + nome] = n
	if salvar or n > 0: img.save_png(OUT + "fluxo_%s.png" % nome)
	return n
