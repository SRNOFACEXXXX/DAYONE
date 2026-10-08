extends Node
## Auditoria: para cada tipo de prop de Detalhes (props, cenário por área, cercas), amostra pontos sólidos da malha entre 0,25 e 1,7 m
## do chão e testa se uma esfera de 0,2 m ali colide com a camada 1 (o que o Soldier/zumbi enfrentam). Uso: --audit_props
const MOLES := ["cenario/natureza/arbusto_a", "cenario/natureza/arbusto_b", "cenario/natureza/samambaia_a", "cenario/natureza/samambaia_b", "cenario/natureza/tufo_capim",
		"cenario/natureza/tufo_misto", "cenario/natureza/urtiga", "cenario/natureza/galho", "cenario/natureza/pedrisco_a", "cenario/natureza/pedrisco_b"]


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["audit_props"] = true
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	for i in 10:
		await get_tree().physics_frame
	var det: IlhaDetalhes = m.ilha.get_node("Detalhes")
	var ss := det.get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	var tipos := {}   # tipo -> [instancias, falham, semamostra]
	var falhas := {}
	for a in det.auditoria:
		var base: float = a.pos.y
		var tot := 0
		var hit := 0
		var t0: String = a.tipo
		if t0 in MOLES:
			continue   # vegetação rasteira: atravessável por design
		var pts: PackedVector3Array = a.pts
		if t0.contains("arvore") or t0.contains("carvalho") or t0.contains("betula") or t0.contains("salgueiro") or t0.contains("pinheiro") or t0.contains("Pine_") or t0.begins_with("poste"):
			pts = PackedVector3Array([a.pos + Vector3(0, 0.9, 0), a.pos + Vector3(0, 1.2, 0), a.pos + Vector3(0, 1.5, 0)])   # só o tronco/poste
		for q in pts:
			var h: float = q.y - m.ilha.terrain.height_world(q.x, q.z)
			if h < 0.25 or h > 1.7:
				continue
			tot += 1
			var ps := PhysicsShapeQueryParameters3D.new()
			ps.shape = sph
			ps.transform = Transform3D(Basis(), q)
			ps.collision_mask = 1
			if not ss.intersect_shape(ps, 1).is_empty():
				hit += 1
		var t: String = a.tipo
		if tot > 0 and float(hit) / tot < 0.5:
			var mx := 0.0
			for q in (a.pts as PackedVector3Array):
				mx = maxf(mx, Vector2(q.x - a.pos.x, q.z - a.pos.z).length())
			print("DET %s pos=%s tot=%d hit=%d raio_max=%.2f" % [t, a.pos, tot, hit, mx])
		if not tipos.has(t):
			tipos[t] = [0, 0, 0]
		if tot < (1 if pts.size() == 3 else 3):
			tipos[t][2] += 1
			continue
		tipos[t][0] += 1
		if float(hit) / tot < 0.5:
			tipos[t][1] += 1
	var ks := tipos.keys()
	ks.sort()
	var ti := 0
	var fi := 0
	var ni := 0
	var nf := 0
	for k in ks:
		var v: Array = tipos[k]
		ti += v[0]
		fi += v[1]
		ni += 1
		if v[1] > 0:
			nf += 1
		print("TIPO %-55s inst=%d atravessa=%d semamostra=%d" % [k, v[0], v[1], v[2]])
	print("RESUMO tipos=%d tipos_falhos=%d instancias=%d atravessam=%d" % [ni, nf, ti, fi])
	get_tree().quit(0 if fi == 0 else 1)
