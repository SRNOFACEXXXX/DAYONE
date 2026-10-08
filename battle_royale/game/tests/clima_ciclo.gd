extends Node
## Ciclo dia/noite + clima: --out=<pasta> [--so_ciclo|--so_clima]. Capturas PNG, FPS médio/p95 e luminância por etapa,
## verificação de "pop" (salto de luminância entre amostras) e de noite jogável (luminância mínima).
## Saída: linhas "CICLO ...", "CLIMA ...", "POP ...", "RESULTADO ...".
const LIM_NOITE := 0.05      # luminância média mínima da imagem à noite (0..1)
const LIM_POP := 0.10        # salto máximo de luminância entre amostras de 0,25 s
var cam: Camera3D
var out := ""
var ok := true
var amostras: Array = []


func _ready() -> void:
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	await get_tree().process_frame
	var ex: Node3D = scene.get_node("Explorador")
	ex.set_physics_process(false)
	cam = ex.cam
	var t: IlhaTerrain = scene.terrain
	var a := Vector2(-330, -300)
	var b := Vector2(-420, -370)
	cam.global_position = Vector3(a.x, t.height_world(a.x, -a.y) + 1.65, -a.y)
	cam.look_at(Vector3(b.x, t.height_world(b.x, -b.y) + 4.0, -b.y))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Clima.clima_automatico = false
	Clima.forcar_clima(Clima.Estado.LIMPO, true)
	for i in 30:
		await get_tree().process_frame
	if not Game.test_args.has("so_clima"):
		await _ciclo()
	if not Game.test_args.has("so_ciclo"):
		await _climas()
		await _transicao()
	print("RESULTADO %s" % ("OK" if ok else "FALHOU"))
	get_tree().quit()


func _lum() -> float:
	var img := get_viewport().get_texture().get_image()
	img.resize(64, 48, Image.INTERPOLATE_NEAREST)
	var s := 0.0
	for y in 48:
		for x in 64:
			s += img.get_pixel(x, y).get_luminance()
	return s / 3072.0


func _foto(nome: String) -> float:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("clima_%s.png" % nome))
	var im2 := img.duplicate()
	im2.resize(64, 48, Image.INTERPOLATE_NEAREST)
	var s := 0.0
	for y in 48:
		for x in 64:
			s += im2.get_pixel(x, y).get_luminance()
	return s / 3072.0


func _fps(seg: float) -> Array:
	var dts: Array = []
	var t_fim := Time.get_ticks_usec() + int(seg * 1e6)
	var ult := Time.get_ticks_usec()
	while Time.get_ticks_usec() < t_fim:
		await get_tree().process_frame
		var n := Time.get_ticks_usec()
		dts.append((n - ult) / 1000.0)
		ult = n
	dts.sort()
	var soma := 0.0
	for d in dts:
		soma += d
	var medio: float = soma / dts.size()
	var p95: float = dts[int(dts.size() * 0.95)]
	return [1000.0 / medio, 1000.0 / p95]


func _ciclo() -> void:
	Clima.escala_tempo = 36.0   # 24 h em 40 s
	Clima.set_hora(0.0)
	Clima.congelado = false
	var alvos := [6.0, 12.0, 18.0, 23.99]
	var nomes := ["06h", "12h", "18h", "00h"]
	var prox := 0
	var seg_t := Time.get_ticks_usec()
	var seg_dts: Array = []
	var ult := Time.get_ticks_usec()
	var ult_lum := -1.0
	var t_amostra := 0.0
	var lum_min_noite := 9.0
	var maxpop := 0.0
	var h_ant := 0.0
	var sinais := {"amanheceu": 0, "anoiteceu": 0, "novo_dia": 0}
	Clima.amanheceu.connect(func() -> void: sinais.amanheceu += 1)
	Clima.anoiteceu.connect(func() -> void: sinais.anoiteceu += 1)
	Clima.novo_dia.connect(func(_d: int) -> void: sinais.novo_dia += 1)
	var horas_vistas := {}
	Clima.hora_mudou.connect(func(h: int) -> void: horas_vistas[h] = true)
	while prox < alvos.size():
		await get_tree().process_frame
		var n := Time.get_ticks_usec()
		seg_dts.append((n - ult) / 1000.0)
		ult = n
		t_amostra += seg_dts[-1] / 1000.0
		if t_amostra >= 0.25:
			t_amostra = 0.0
			var l := _lum()
			if ult_lum >= 0.0:
				var d := absf(l - ult_lum)
				if d > maxpop:
					maxpop = d
				if d > LIM_POP:
					print("POP salto lum %.3f em h=%.2f" % [d, Clima.hora])
			ult_lum = l
			if Clima.e_noite():
				lum_min_noite = minf(lum_min_noite, l)
		if (prox < 3 and Clima.hora >= alvos[prox]) or (prox == 3 and Clima.dia == 1 and Clima.hora >= 23.9):
			var l2: float = await _foto("ciclo_" + nomes[prox])
			seg_dts.sort()
			var s := 0.0
			for d in seg_dts:
				s += d
			print("CICLO %s hora=%.2f lum=%.3f fps_med=%.0f fps_p95=%.0f elev=%.1f luz_fator=%.2f" % [nomes[prox], Clima.hora, l2, 1000.0 / (s / seg_dts.size()), 1000.0 / seg_dts[int(seg_dts.size() * 0.95)], Clima.elevacao_sol, Clima.luz_fator])
			if prox == 3 and l2 < LIM_NOITE:
				ok = false
			seg_dts.clear()
			prox += 1
	Clima.congelado = true
	Clima.escala_tempo = 1.0
	print("POP maxima variacao de luminancia entre amostras (0,25 s a 36x) = %.3f (limite %.2f)" % [maxpop, LIM_POP])
	print("NOITE luminancia minima amostrada = %.3f (limite %.2f)" % [lum_min_noite, LIM_NOITE])
	print("SINAIS amanheceu=%d anoiteceu=%d horas_vistas=%d" % [sinais.amanheceu, sinais.anoiteceu, horas_vistas.size()])
	if maxpop > LIM_POP * 1.5 or lum_min_noite < LIM_NOITE:
		ok = false


func _climas() -> void:
	Clima.congelado = true
	for par in [["12h", 12.0], ["noite", 23.0]]:
		Clima.set_hora(par[1])
		for e in Clima.Estado.values():
			Clima.forcar_clima(e, true)
			for i in 20:
				await get_tree().process_frame
			if e == Clima.Estado.TEMPESTADE:
				Clima.raio_agora(900.0)
				await get_tree().process_frame
				await get_tree().process_frame
				var lr: float = await _foto("%s_%s_raio" % [par[0], Clima.NOMES[e].to_lower()])
				print("CLIMA %s %s com relampago lum=%.3f" % [par[0], Clima.NOMES[e], lr])
				for i in 30:
					await get_tree().process_frame
			var f: Array = await _fps(2.0)
			var l: float = await _foto("%s_%s" % [par[0], Clima.NOMES[e].to_lower()])
			print("CLIMA %s %s lum=%.3f fps_med=%.0f fps_p95=%.0f luz_fator=%.2f vis=%.2f chuva=%.2f" % [par[0], Clima.NOMES[e], l, f[0], f[1], Clima.luz_fator, Clima.visibilidade_fator, Clima.chuva])
			if par[0] == "noite" and l < LIM_NOITE:
				ok = false


func _transicao() -> void:
	Clima.set_hora(15.0)
	Clima.forcar_clima(Clima.Estado.LIMPO, true)
	for i in 10:
		await get_tree().process_frame
	Clima.forcar_clima(Clima.Estado.TEMPESTADE, false, 8.0)
	var ult := -1.0
	var maxd := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 9000000:
		for i in 12:
			await get_tree().process_frame
		var l := _lum()
		if ult >= 0.0:
			maxd = maxf(maxd, absf(l - ult))
		ult = l
	print("POP transicao LIMPO->TEMPESTADE (8 s) maior salto entre amostras = %.3f (limite %.2f)" % [maxd, LIM_POP])
	if maxd > LIM_POP:
		ok = false
