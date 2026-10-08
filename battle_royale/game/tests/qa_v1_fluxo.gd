extends Node
## QA v1: fluxo real menu -> criador -> confirmar -> partida. Mede controle, quadros, magenta.
var R := {}
var _q: Array[float] = []
var _ult := 0
var _med := false
var _fim := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(190.0, true, false, true).timeout.connect(func() -> void: print("QA_TIMEOUT ", JSON.stringify(R)); get_tree().quit(2))
	await get_tree().process_frame
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	await get_tree().create_timer(2.0).timeout
	var menu := get_tree().current_scene
	await _shot("menu", true)
	menu.abrir_criador()
	var cr: Node = menu.criador
	await get_tree().create_timer(3.0).timeout
	await _shot("criador", true)
	cr.aleatorio()
	await get_tree().create_timer(5.0).timeout
	var t0 := Time.get_ticks_usec()
	cr.confirmar()
	var lim := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < lim:
		await get_tree().process_frame
		var m := Game.current_match
		if m != null and is_instance_valid(m) and m.get("local_player") != null and not Loading._root.visible:
			break
	R["ms_ate_controle"] = (Time.get_ticks_usec() - t0) / 1000.0
	_q.clear(); _ult = Time.get_ticks_usec(); _fim = _ult + 60000000; _med = true
	var rosa_total := 0
	var k := 0
	while _med:
		await get_tree().process_frame
		k += 1
		if k % 90 == 0:
			rosa_total += await _shot("partida_%d" % k, false)
	var l50 := 0; var l100 := 0; var pior := 0.0
	for q in _q:
		pior = maxf(pior, q)
		if q > 100.0: l100 += 1
		if q > 50.0: l50 += 1
	R["quadros"] = _q.size(); R["q50"] = l50; R["q100"] = l100; R["pior_ms"] = pior
	R["rosa_px_total"] = rosa_total
	var f := FileAccess.open("C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/qa_v1/fluxo.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " ")); f.close()
	print("QA_FLUXO_OK ", JSON.stringify(R))
	get_tree().quit(0)
func _process(_d: float) -> void:
	if not _med: return
	var a := Time.get_ticks_usec()
	_q.append((a - _ult) / 1000.0); _ult = a
	if a >= _fim: _med = false
func _shot(nome: String, salvar: bool) -> int:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.9 and c.b > 0.9 and c.g < 0.15: n += 1
	R["rosa_" + nome] = n
	if salvar or n > 0:
		img.save_png("C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/qa_v1/fluxo_%s.png" % nome)
	return n
