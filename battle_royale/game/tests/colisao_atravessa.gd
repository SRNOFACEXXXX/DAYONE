extends Node
## ATRAVESSA OU NÃO: para cada ASSET sólido do mundo (agrupado pela fonte, os props se repetem) escolhe instâncias reais, põe o
## Soldier real a ~2 m, de frente para o centro do objeto, e faz ele correr (sprint por input) contra ele.
## "Atravessou" = a posição do jogador passou do centro do objeto sem ter subido nele (mantle) — ou seja, nada o segurou.
## Mede também quanto tempo ficou com o centro da cápsula DENTRO do volume visual (paridade de raios na malha real).
## Saída: raw/colisao/atravessa.json + resumo. Uso: godot --path game res://tests/colisao_atravessa.tscn [-- --inst=2 --max=999 --filtro=texto]
const Comum := preload("res://tests/colisao_comum.gd")
## macios por design (atravessáveis): vegetação rasteira, arbustos, samambaias, tufos, pedriscos, galhos
const MACIOS := ["veg:capim_alto", "veg:cana", "veg:arbusto", "arbusto", "samambaia", "tufo", "pedrisco", "galho", "Decal", "Fern", "Grass", "Bush", "animais/"]   # animais: corpos móveis com cápsula própria (o teste mira a posição antiga)
var m: BRMatch
var s: Soldier
var resultados: Array = []


func _macio(k: String) -> bool:
	for t in MACIOS:
		if k.contains(t):
			return true
	return false


func _ready() -> void:
	get_tree().create_timer(float(Game.test_args.get("limite", 2400.0))).timeout.connect(func() -> void: print("COLISAO_ATRAVESSA_TIMEOUT parcial"); _resumo(); get_tree().quit(2))
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
	s = m.local_player
	s.godmode = true
	if Game.test_args.has("cam"):
		(s.controller as PlayerController)._prefer_third_person = true
		(s.controller as PlayerController)._set_third_person(true)
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	var por_chave: Dictionary = {}
	Comum.coletar(m, m, por_chave)
	var n_inst := int(Game.test_args.get("inst", 2))
	var maximo := int(Game.test_args.get("max", 9999))
	var filtro := String(Game.test_args.get("filtro", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	Engine.time_scale = float(Game.test_args.get("vel", 2.0))
	print("COLISAO_ATRAVESSA assets_sólidos=", por_chave.size())
	var feitos := 0
	var chaves: Array = por_chave.keys()
	chaves.sort()
	var pular := int(Game.test_args.get("pular", 0))
	var idx_k := -1
	for k in chaves:
		idx_k += 1
		if idx_k < pular or String(k) < String(Game.test_args.get("desde", "")):
			continue
		if _macio(String(k)) or (filtro != "" and not String(k).contains(filtro)):
			continue
		if feitos >= maximo:
			break
		var inst: Array = por_chave[k]
		var tentativas := 0
		var ok := 0
		while ok < n_inst and tentativas < n_inst * 6:
			tentativas += 1
			var it: Array = inst[rng.randi() % inst.size()]
			var r := await _correr_contra(String(k), it[0], it[1], rng)
			if not r.is_empty():
				resultados.append(r)
				if r.passou:
					print("FALHA passou cruzes=%d dentro=%d cam=%d  %s  @%s" % [r.cruzes, r.dentro_quadros, r.cam_cruzes, r.asset, r.pos])
				ok += 1
		feitos += 1
	Engine.time_scale = 1.0
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_resumo()
	get_tree().quit()


func _aabb_mundo(mesh: Mesh, xf: Transform3D) -> AABB:
	var ab := mesh.get_aabb()
	var r := AABB(xf * ab.position, Vector3.ZERO)
	for i in 8:
		r = r.expand(xf * ab.get_endpoint(i))
	return r


func _livre(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.5
	q.shape = cap
	q.transform = Transform3D(Basis(), p + Vector3.UP * 0.8)
	q.collision_mask = Soldier.LAYER_WORLD
	return m.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## dentro do volume da malha? (paridade de cruzamentos de um raio +Y contra o triângulo-mesh em espaço local)
func _dentro(tm: TriangleMesh, xf_inv: Transform3D, p: Vector3) -> bool:
	var o := xf_inv * p
	var cnt := 0
	for i in 12:
		var h := tm.intersect_ray(o, Vector3.UP)
		if h.is_empty():
			break
		cnt += 1
		o = h.position + Vector3.UP * 0.001
	return cnt % 2 == 1


func _correr_contra(chave: String, mesh: Mesh, xf: Transform3D, rng: RandomNumberGenerator) -> Dictionary:
	var ab := _aabb_mundo(mesh, xf)
	var alt_chao := float(m.ilha.terrain.height_world(ab.get_center().x, ab.get_center().z))
	if ab.size.y < 0.3 or ab.end.y < alt_chao + 0.3 or ab.size.x > 40.0 or ab.size.z > 40.0:
		return {}
	var C := Vector3(ab.get_center().x, 0, ab.get_center().z)
	var raio := maxf(ab.size.x, ab.size.z) * 0.5
	var start := Vector3.ZERO
	var dir := Vector3.ZERO
	var achou := false
	for t in 8:
		var ang := rng.randf() * TAU
		dir = Vector3(-cos(ang), 0, -sin(ang))      # direção de movimento (rumo ao centro)
		start = C - dir * (raio + 2.0)
		start.y = float(m.ilha.terrain.height_world(start.x, start.z))
		if _livre(start + Vector3.UP * 0.1):
			achou = true
			break
	if not achou:
		return {}
	var tm: TriangleMesh = mesh.generate_triangle_mesh() if mesh.get_surface_count() > 0 else null
	var xf_inv := xf.affine_inverse()
	s.global_position = start + Vector3.UP * 0.12
	s.velocity = Vector3.ZERO
	s.yaw = atan2(-dir.x, -dir.z)
	s.pitch = 0.0
	s.reset_physics_interpolation()
	for i in 4:
		await get_tree().physics_frame
	var y0 := s.global_position.y
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var max_p := -999.0
	var subiu := 0.0
	var quadros_dentro := 0
	var quadros := 0
	var cruzes := 0
	var cam_cruzes := 0
	var pcc: PlayerController = s.controller as PlayerController
	var pp := s.global_position
	var limite := int((raio + 2.0) / 5.0 * 64.0) + 110
	for i in limite:
		await get_tree().physics_frame
		quadros += 1
		var pos := s.global_position
		max_p = maxf(max_p, (pos - C).dot(dir))
		subiu = maxf(subiu, pos.y - float(m.ilha.terrain.height_world(pos.x, pos.z)))
		if tm != null:
			var cruzou := false
			var dentro := false
			for hh in [0.35, 0.9, 1.35]:
				var up: Vector3 = Vector3.UP * float(hh)
				if not tm.intersect_segment(xf_inv * (pp + up), xf_inv * (pos + up)).is_empty():
					cruzou = true      # o eixo da cápsula atravessou uma face da malha real = entrou no objeto
				if _dentro(tm, xf_inv, pos + up):
					dentro = true
			if cruzou:
				cruzes += 1
			if dentro:
				quadros_dentro += 1
		if Game.test_args.has("cam") and tm != null and pcc != null:
			var cab := pos + Vector3.UP * 1.45
			if not tm.intersect_segment(xf_inv * cab, xf_inv * pcc.camera.global_position).is_empty():
				cam_cruzes += 1       # objeto entre a cabeça e a câmera = câmera atravessou a geometria
		pp = pos
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var passou := cruzes >= 1 or cam_cruzes > 2     # 'dentro' (paridade) é só informativo: malhas abertas/suspensas dão falso positivo
	return {"asset": chave, "passou": passou, "progresso": snappedf(max_p, 0.01), "raio": snappedf(raio, 0.1), "altura": snappedf(ab.size.y, 0.1),
		"subiu": snappedf(subiu, 0.01), "dentro_quadros": quadros_dentro, "cruzes": cruzes, "cam_cruzes": cam_cruzes, "quadros": quadros, "pos": "%.1f,%.1f,%.1f" % [C.x, alt_chao, C.z]}


func _resumo() -> void:
	var por_asset: Dictionary = {}
	for r in resultados:
		var e: Dictionary = por_asset.get(r.asset, {"n": 0, "passou": 0, "dentro": 0, "subiu": 0, "pos": r.pos, "prog": 0.0})
		e.n += 1
		if r.passou:
			e.passou += 1
			e.pos = r.pos
			e.prog = maxf(e.prog, r.progresso)
		if int(r.dentro_quadros) > 6:
			e.dentro += 1
		if float(r.subiu) >= 0.45:
			e.subiu += 1
		por_asset[r.asset] = e
	var lista: Array = []
	var testes := 0
	var falhas := 0
	for k in por_asset.keys():
		var e: Dictionary = por_asset[k]
		testes += e.n
		falhas += e.passou
		lista.append({"asset": k, "testes": e.n, "passou": e.passou, "dentro": e.dentro, "subiu": e.subiu, "prog": snappedf(e.prog, 0.01), "pos": e.pos})
	lista.sort_custom(func(a, b): return (int(a.passou) * 100 + int(a.dentro)) > (int(b.passou) * 100 + int(b.dentro)))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../raw/colisao/atravessa.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"testes": testes, "passou": falhas, "assets": lista.size(), "lista": lista, "bruto": resultados}, " "))
	f.close()
	print("COLISAO_ATRAVESSA_OK assets=%d testes=%d atravessou=%d (%.1f%%)" % [lista.size(), testes, falhas, 100.0 * falhas / maxf(1.0, testes)])
	for it in lista:
		if int(it.passou) == 0 and int(it.dentro) == 0:
			continue
		print("  passou=%d/%d dentro=%d subiu=%d prog=%.2f  %s  @%s" % [it.passou, it.testes, it.dentro, it.subiu, it.prog, it.asset, it.pos])
