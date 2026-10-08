extends Node
## Mede onde a superficie da agua (mar y=0, represa y=nivel, rio) fica ACIMA do terreno em area que deveria ser seca.
## Uso: --path game res://tests/agua_medida.tscn      (linhas AGUA_MEDIDA ...)

func _dentro(p: Vector2, poly: Array) -> bool:
	var ins := false
	var j := poly.size() - 1
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			ins = not ins
		j = i
	return ins


func _ready() -> void:
	Game.test_mode = true
	var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/ilha_layout.json"))
	var t := IlhaTerrain.new()
	add_child(t)
	await t.terrain_ready
	var N := IlhaTerrain.N
	# --- mar: celulas abaixo de 0 nao conectadas ao oceano da borda
	var low := PackedByteArray(); low.resize(N * N)
	for i in N * N:
		low[i] = 1 if t.heights[i] < 0.0 else 0
	var conn := PackedByteArray(); conn.resize(N * N)
	var fila: Array[int] = []
	for i in N:
		for idx in [i, (N - 1) * N + i, i * N, i * N + N - 1]:
			if low[idx] == 1 and conn[idx] == 0:
				conn[idx] = 1; fila.append(idx)
	var qi := 0
	while qi < fila.size():
		var idx: int = fila[qi]; qi += 1
		var c := idx % N; var r := idx / N
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var cc: int = c + d[0]; var rr: int = r + d[1]
			if cc >= 0 and cc < N and rr >= 0 and rr < N:
				var k := rr * N + cc
				if low[k] == 1 and conn[k] == 0:
					conn[k] = 1; fila.append(k)
	var interior := 0
	var ex_int := []
	for i in N * N:
		if low[i] == 1 and conn[i] == 0:
			interior += 1
			if ex_int.size() < 5: ex_int.append([-600 + (i % N) * 2, -600 + (i / N) * 2, snappedf(t.heights[i], 0.1)])
	print("AGUA_MEDIDA mar_celulas_oceano=%d mar_interior_seco_abaixo_de_0=%d ex=%s" % [fila.size(), interior, str(ex_int)])
	# --- mar vs casas / pontos de loot / spawn: chao < 0.15 m sob predios
	var casas_molhadas := []
	for poi in lay.get("pois", []) + lay.get("marcos", []):
		for pr in poi.get("predios", []):
			var px := float(pr.pos[0]); var pz := -float(pr.pos[1])
			var h := t.height_world(px, pz)
			if h < 0.3:
				casas_molhadas.append([String(pr.id), snappedf(px, 0.1), snappedf(pz, 0.1), snappedf(h, 0.01)])
	print("AGUA_MEDIDA casas_com_chao_abaixo_de_0.3m=%d %s" % [casas_molhadas.size(), str(casas_molhadas)])
	# --- represa: plano e retangulo bbox+20; area onde h<nivel fora do poligono
	var rep: Dictionary = lay.agua.represa
	var poly: Array = []
	for p in rep.contorno:
		poly.append(Vector2(float(p[0]), -float(p[1])))
	var nivel := float(rep.nivel_agua_m)
	var mn := Vector2(1e9, 1e9); var mx := Vector2(-1e9, -1e9)
	for p in poly:
		mn = mn.min(p); mx = mx.max(p)
	mn -= Vector2(10, 10); mx += Vector2(10, 10)
	var fora := 0; var dentro_seco := 0; var dentro := 0; var maxp := 0.0
	var ex_f := []
	var x := mn.x
	while x <= mx.x:
		var z := mn.y
		while z <= mx.y:
			var h := t.height_world(x, z)
			var ins := _dentro(Vector2(x, z), poly)
			if h < nivel and not ins:
				fora += 1; maxp = maxf(maxp, nivel - h)
				if ex_f.size() < 5: ex_f.append([x, z, snappedf(h, 0.1)])
			elif ins:
				dentro += 1
				if h >= nivel: dentro_seco += 1
			z += 2.0
		x += 2.0
	print("AGUA_MEDIDA represa nivel=%.1f celulas_agua_fora_do_contorno=%d (%.0f m2, prof_max %.1f m) dentro=%d dentro_com_terreno_acima=%d ex=%s" % [nivel, fora, fora * 4.0, maxp, dentro, dentro_seco, str(ex_f)])
	# --- rio: fita em y-0.5 sobre terreno mais baixo (flutuando) ou muito acima (enterrada)
	for tr in lay.agua.rio.trechos:
		var flut := 0; var tot := 0; var pior := 0.0
		var pts: Array = tr.pontos
		for i in pts.size() - 1:
			var a := Vector3(float(pts[i][0]), float(pts[i][2]) - 0.5, -float(pts[i][1]))
			var b := Vector3(float(pts[i + 1][0]), float(pts[i + 1][2]) - 0.5, -float(pts[i + 1][1]))
			var n := int(a.distance_to(b) / 2.0) + 1
			for k in n + 1:
				var q := a.lerp(b, float(k) / n)
				var h := t.height_world(q.x, q.z)
				tot += 1
				if h < q.y - 0.3:
					flut += 1; pior = maxf(pior, q.y - h)
		print("AGUA_MEDIDA rio %s amostras=%d flutuando_acima_do_chao_>0.3m=%d pior=%.1f m" % [tr.trecho, tot, flut, pior])
	get_tree().quit()
