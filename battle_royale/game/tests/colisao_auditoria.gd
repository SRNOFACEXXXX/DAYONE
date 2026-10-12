extends Node
## AUDITORIA DE COLISÃO PELA FORMA REAL: para cada malha visível do mundo (agrupada por ASSET FONTE, já que os props se repetem)
## amostra pontos da SUPERFÍCIE (triângulos entre 0,12 m e 2,2 m acima do chão = o que um jogador toca) e dispara um raio
## de fora para dentro ao longo da normal contra o mundo físico (camada 1). Sem colisor perto da superfície = o jogador atravessa.
## Saída: raw/colisao/auditoria.json (por asset: amostras, cobertura, instâncias, exemplo de posição) + resumo no console.
## Uso: godot --path game res://tests/colisao_auditoria.tscn [-- --amostras=48 --inst=8]
var m: BRMatch
var space: PhysicsDirectSpaceState3D
const Comum := preload("res://tests/colisao_comum.gd")
var relatorio: Dictionary = {}     # chave asset -> {amostras, cobertos, inst, exemplo, falhas, colisores}


func _ready() -> void:
	get_tree().create_timer(900.0).timeout.connect(func() -> void: print("COLISAO_AUDITORIA_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for i in 60:
		await get_tree().process_frame
	space = m.get_world_3d().direct_space_state
	var por_chave: Dictionary = {}       # chave -> Array de [Mesh, Transform3D]
	Comum.coletar(m, m, por_chave)
	print("COLISAO_AUDITORIA assets=", por_chave.size())
	var n_am := int(Game.test_args.get("amostras", 48))
	var n_inst := int(Game.test_args.get("inst", 8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var feitos := 0
	for k in por_chave.keys():
		var inst: Array = por_chave[k]
		var e := {"amostras": 0, "cobertos": 0, "inst": inst.size(), "exemplo": "", "falhas": [], "colisores": {}}
		var escolhidos: Array = []
		if inst.size() <= n_inst:
			escolhidos = inst
		else:
			for j in n_inst:
				escolhidos.append(inst[rng.randi() % inst.size()])
		var por_inst := maxi(4, n_am / maxi(1, escolhidos.size()))
		for it in escolhidos:
			_amostrar(it[0], it[1], por_inst, rng, e)
		relatorio[k] = e
		feitos += 1
		if feitos % 100 == 0:
			await get_tree().process_frame
	_resumo()
	get_tree().quit()


func _amostrar(mesh: Mesh, xf: Transform3D, quant: int, rng: RandomNumberGenerator, e: Dictionary) -> void:
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		if arr.size() <= Mesh.ARRAY_VERTEX or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var ntri := (idx.size() if idx.size() > 0 else v.size()) / 3
		if ntri == 0:
			continue
		var cand: Array = []
		var area_tot := 0.0
		for t in ntri:
			var a: Vector3 = v[idx[t * 3]] if idx.size() > 0 else v[t * 3]
			var b: Vector3 = v[idx[t * 3 + 1]] if idx.size() > 0 else v[t * 3 + 1]
			var c: Vector3 = v[idx[t * 3 + 2]] if idx.size() > 0 else v[t * 3 + 2]
			var wa := xf * a
			var wb := xf * b
			var wc := xf * c
			var area := (wb - wa).cross(wc - wa).length() * 0.5
			if area < 0.01:
				continue
			var ctr := (wa + wb + wc) / 3.0
			var h: float = ctr.y - float(m.ilha.terrain.height_world(ctr.x, ctr.z))
			if h < 0.12 or h > 2.2:
				continue
			area_tot += area
			cand.append([area_tot, wa, wb, wc])
		if cand.is_empty():
			continue
		var por_sup := maxi(1, quant / mesh.get_surface_count())
		for q in por_sup:
			var r := rng.randf() * area_tot
			var tri: Array = cand[cand.size() - 1]
			for cd in cand:
				if cd[0] >= r:
					tri = cd
					break
			var u := rng.randf()
			var w := rng.randf()
			if u + w > 1.0:
				u = 1.0 - u
				w = 1.0 - w
			var p: Vector3 = tri[1] + (tri[2] - tri[1]) * u + (tri[3] - tri[1]) * w
			var nrm: Vector3 = ((tri[2] - tri[1]) as Vector3).cross(tri[3] - tri[1]).normalized()
			e.amostras += 1
			var hit := _raio(p, nrm)
			if hit.is_empty():
				hit = _raio(p, -nrm)
			if hit.is_empty():
				if e.falhas.size() < 3:
					e.falhas.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)])
				if e.exemplo == "":
					e.exemplo = "%.1f,%.1f,%.1f" % [p.x, p.y, p.z]
			else:
				e.cobertos += 1
				var col := hit.get("collider") as Node
				var cn := String(col.name) if col else "?"
				e.colisores[cn] = int(e.colisores.get(cn, 0)) + 1


func _raio(p: Vector3, n: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + n * 0.5, p - n * 0.08, Soldier.LAYER_WORLD)
	q.collide_with_areas = false
	q.hit_from_inside = true
	var h := space.intersect_ray(q)
	if h.is_empty():
		return {}
	var col := h.get("collider") as Node
	if col and (String(col.name).begins_with("TerrenoColisao") or col is IlhaTerrain):
		return {}
	return h


func _resumo() -> void:
	var lista: Array = []
	var am_tot := 0
	var ok_tot := 0
	var am_pond := 0.0
	var ok_pond := 0.0
	for k in relatorio.keys():
		var e: Dictionary = relatorio[k]
		if e.amostras == 0:
			continue
		var cob := float(e.cobertos) / float(e.amostras)
		am_tot += e.amostras
		ok_tot += e.cobertos
		am_pond += e.inst
		ok_pond += e.inst * cob
		lista.append({"asset": k, "amostras": e.amostras, "cobertura": snappedf(cob, 0.001), "inst": e.inst, "peso": snappedf((1.0 - cob) * e.inst, 0.01), "exemplo": e.exemplo, "falhas": e.falhas, "colisores": e.colisores.keys().slice(0, 3)})
	lista.sort_custom(func(a, b): return float(a.peso) > float(b.peso))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../raw/colisao/auditoria.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"assets": lista.size(), "cobertura_amostras": float(ok_tot) / maxf(1.0, am_tot), "cobertura_por_instancia": ok_pond / maxf(1.0, am_pond), "lista": lista}, " "))
	f.close()
	print("COLISAO_AUDITORIA_OK assets=%d cobertura_amostras=%.1f%% cobertura_por_instancia=%.1f%%" % [lista.size(), 100.0 * ok_tot / maxf(1.0, am_tot), 100.0 * ok_pond / maxf(1.0, am_pond)])
	for i in mini(40, lista.size()):
		var it: Dictionary = lista[i]
		if float(it.cobertura) >= 0.99:
			break
		print("  %5.1f%% inst=%-4d %s  ex=%s" % [100.0 * float(it.cobertura), it.inst, it.asset, it.exemplo])
