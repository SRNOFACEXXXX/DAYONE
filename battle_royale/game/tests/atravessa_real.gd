extends Node
## Colisão no jogo real: o Soldier (input real) anda 3 s contra árvores, cercas, muros, caixotes, tambores etc.
## Para cada alvo: começa a (raio + 1,6 m) do centro, de frente para ele, segura W. Atravessou = terminou além do centro.
## Saída: ATRAVESSA tipo=... ok/ATRAVESSOU e RESUMO. Uso: --por_tipo=3 (instâncias por tipo).
const CHAVES := ["cerca", "muro", "caixa", "caixote", "tambor", "barril", "pilha", "pneu", "sacos", "mureta", "poste", "portao",
		"carvalho", "arvore", "pinheiro", "Pine_", "betula", "salgueiro", "Tree", "palmeira", "Barrier", "Fence", "Concrete", "Crate", "Box"]


func _tipo_ok(t: String) -> bool:
	for c in CHAVES:
		if t.contains(c):
			return true
	return false


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["audit_props"] = true
	Game.test_args["bots"] = "0"
	Game.test_args["sem_stamina"] = "1"
	var por_tipo := int(Game.test_args.get("por_tipo", "2"))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	for i in 10:
		await get_tree().physics_frame
	var p: Soldier = m.local_player
	var terr: IlhaTerrain = m.ilha.terrain
	var alvos: Array = []
	var cont := {}
	var fontes: Array = []
	var det := m.ilha.get_node_or_null("Detalhes")
	if det:
		fontes.append_array(det.auditoria)
	var veg := m.ilha.get_node_or_null("Vegetacao")
	if veg and "auditoria" in veg:
		fontes.append_array(veg.auditoria)
	print("ATRAVESSA fontes=%d" % fontes.size())
	for a in fontes:
		var t := String(a.tipo)
		if not _tipo_ok(t):
			continue
		if int(cont.get(t, 0)) >= por_tipo:
			continue
		cont[t] = int(cont.get(t, 0)) + 1
		alvos.append(a)
	var falhas := 0
	var n := 0
	var ss := m.get_world_3d().direct_space_state
	for a in alvos:
		var solidos := PackedVector3Array()
		for q in (a.pts as PackedVector3Array):
			var h: float = q.y - terr.height_world(q.x, q.z)
			if h > 0.25 and h < 1.7:
				solidos.append(q)
		if solidos.size() < 3:
			continue
		var c := Vector3.ZERO
		for q in solidos:
			c += q
		c /= float(solidos.size())
		var r := 0.3
		for q in solidos:
			r = maxf(r, Vector2(q.x - c.x, q.z - c.z).length())
		r = minf(r, 4.0)
		# escolhe a direção de aproximação com chão plano e espaço livre para a cápsula
		var escolhido := false
		var ini := Vector3.ZERO
		var dir := Vector3.ZERO
		for k in 8:
			var ang := TAU * k / 8.0
			var d := Vector3(sin(ang), 0, cos(ang))
			var s := c - d * (r + 1.6)
			s.y = terr.height_world(s.x, s.z)
			if absf(s.y - terr.height_world(c.x, c.z)) > 0.8 or s.y < 0.3:
				continue
			var cap := CapsuleShape3D.new()
			cap.radius = 0.35
			cap.height = 1.7
			var pq := PhysicsShapeQueryParameters3D.new()
			pq.shape = cap
			pq.transform = Transform3D(Basis(), s + Vector3.UP * 1.0)
			pq.collision_mask = 1
			if not ss.intersect_shape(pq, 1).is_empty():
				continue
			ini = s
			dir = d
			escolhido = true
			break
		if not escolhido:
			continue
		p.global_position = ini + Vector3.UP * 0.1
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.yaw = atan2(-dir.x, -dir.z)
		await get_tree().physics_frame
		Input.action_press("move_forward")
		var dentro := INF   # menor distância horizontal do eixo do corpo a um ponto sólido visível (na faixa de altura do corpo)
		for i in 150:
			p.yaw = atan2(-dir.x, -dir.z)
			await get_tree().physics_frame
			var pp := p.global_position
			for q in solidos:
				if q.y > pp.y + 0.1 and q.y < pp.y + 1.75:
					dentro = minf(dentro, Vector2(q.x - pp.x, q.z - pp.z).length())
		Input.action_release("move_forward")
		var avanco := (p.global_position - ini).dot(dir)
		var passou := dentro < 0.15   # eixo do corpo a menos de 15 cm da superfície visível = entrou no modelo
		var andou := (p.global_position - ini).length()
		n += 1
		if passou:
			falhas += 1
		print("ATRAVESSA tipo=%s pos=(%.0f,%.0f) raio=%.2f avanco=%.2f dentro=%.2f %s" % [a.tipo, c.x, c.z, r, avanco, dentro, "ATRAVESSOU" if passou else ("ok" if andou > 0.3 else "ok(parado?)")])
	print("ATRAVESSA_RESUMO testados=%d atravessaram=%d" % [n, falhas])
	get_tree().quit(0 if falhas == 0 else 1)
