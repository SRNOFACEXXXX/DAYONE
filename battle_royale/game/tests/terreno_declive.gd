extends Node
## Mede o terreno com as plataformas das casas: inclinação sob cada carro (ajuste de plano num disco de 2,6 m) e declive
## máximo do mapa (entre nós vizinhos, só em terra h > 1 m). Uso: -- --antigo (sem plataformas de carro e sem suavizador).

func _ready() -> void:
	var antigo := "--antigo" in OS.get_cmdline_user_args()
	var il: Node3D = load("res://maps/ilha/ilha.gd").new()
	il.layout = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/ilha_layout.json"))
	var t := IlhaTerrain.new()
	t.plataformas = il._plataformas_casas()
	t.plataformas_carros = il._plataformas_carros()
	t.bloqueios = il._bloqueios_terreno()
	if antigo:
		t.aplanar_carros = false
		t.suavizar = false
	add_child(t)
	var ini := Time.get_ticks_msec()
	await t.terrain_ready
	print("TERRENO modo=", "antigo" if antigo else "novo", " build_ms=", Time.get_ticks_msec() - ini, " carros=", t.plataformas_carros.size())
	var soma := 0.0
	var pior := 0.0
	var tilts: Array = []
	for pc in t.plataformas_carros:
		var c: Vector2 = pc[0]
		# plano por mínimos quadrados em h(x,z) = a x + b z + d num disco de 2,6 m
		var sx := 0.0
		var sz := 0.0
		var sxx := 0.0
		var szz := 0.0
		var sxz := 0.0
		var sh := 0.0
		var sxh := 0.0
		var szh := 0.0
		var n := 0.0
		var hmin := INF
		var hmax := -INF
		for i in 25:
			for j in 25:
				var q := Vector2(-2.6 + i * 0.2167, -2.6 + j * 0.2167)
				if q.length() > 2.6:
					continue
				var h := t.height_world(c.x + q.x, c.y + q.y)
				hmin = minf(hmin, h)
				hmax = maxf(hmax, h)
				n += 1.0
				sx += q.x
				sz += q.y
				sxx += q.x * q.x
				szz += q.y * q.y
				sxz += q.x * q.y
				sh += h
				sxh += q.x * h
				szh += q.y * h
		# sistema normal 3x3 (simétrico em disco: sx = sz = sxz ~ 0)
		var a := (sxh - sx * sh / n) / (sxx - sx * sx / n)
		var b := (szh - sz * sh / n) / (szz - sz * sz / n)
		var tilt := rad_to_deg(atan(sqrt(a * a + b * b)))
		tilts.append(tilt)
		soma += tilt
		pior = maxf(pior, tilt)
		print("CARRO (%.1f, %.1f) tilt=%.2f desnivel_disco=%.2f" % [c.x, c.y, tilt, hmax - hmin])
	print("CARROS tilt_medio=%.2f tilt_max=%.2f n>1.5=%d" % [soma / maxf(1.0, tilts.size()), pior, tilts.filter(func(x): return x > 1.5).size()])
	# declive entre nós vizinhos
	var N := IlhaTerrain.N
	var maxg := 0.0
	var n35 := 0
	var n45 := 0
	var onde := []
	var blocos := {}
	var n35_livre := 0
	var max_livre := 0.0
	for r in N - 1:
		for c in N - 1:
			var h := t.h_at(c, r)
			if h < 1.0:
				continue
			var g := maxf(maxf(absf(t.h_at(c + 1, r) - h) / 2.0, absf(t.h_at(c, r + 1) - h) / 2.0), maxf(absf(t.h_at(c + 1, r + 1) - h), absf(t.h_at(c + 1, r) - t.h_at(c, r + 1))) / 2.83)
			var ang := rad_to_deg(atan(g))
			if ang > 35.1:
				n35 += 1
				if t._trava[r * N + c] == 0:
					n35_livre += 1
				var kb := "%d,%d" % [int((IlhaTerrain.ORIGIN + c * 2.0) / 50.0) * 50, int((IlhaTerrain.ORIGIN + r * 2.0) / 50.0) * 50]
				blocos[kb] = int(blocos.get(kb, 0)) + 1
			if ang > 45.0:
				n45 += 1
			if t._trava[r * N + c] == 0:
				max_livre = maxf(max_livre, ang)
			if ang > maxg:
				maxg = ang
				onde = [IlhaTerrain.ORIGIN + c * 2.0, IlhaTerrain.ORIGIN + r * 2.0, h]
	print("MAPA declive_max=%.1f nos>35=%d nos>45=%d em(x=%.0f z=%.0f h=%.1f)" % [maxg, n35, n45, onde[0], onde[1], onde[2]])
	print("MAPA fora_das_zonas_travadas: declive_max=%.1f nos>35=%d" % [max_livre, n35_livre])
	print("MAPA_BLOCOS_>35 (x,z de 50 m: nos) ", blocos)
	get_tree().quit()
