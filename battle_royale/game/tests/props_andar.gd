extends Node
## Teste DINÂMICO: Soldier real (input move_forward [+sprint]) e ZombieEnemy real (move_and_slide a run_speed) andam por 3 s contra
## peças reais da ilha (centro da peça, perpendicular ao comprimento). "Atravessou" = passou do centro da peça.
## Uso: res://tests/props_andar.tscn -- [tipos=a,b] [por_tipo=2] [colisao_antiga=1]
const TIPOS := ["barril", "tambor", "cenario/natureza/cerca_madeira", "cerca_madeira", "cerca_arame", "muro_alto", "muro_baixo", "portao_ferro",
	"atualizacao/mundo/Barrel_005", "atualizacao/mundo/Apocalypse_Car", "atualizacao/mundo/Barrier_004", "atualizacao/mundo/Concrete_Fence",
	"atualizacao/mundo/Tent_002", "atualizacao/mundo/Tower_003", "atualizacao/mundo/Generator_004", "atualizacao/mundo/Road_Barrier_01",
	"cenario/carros/carro_sedan", "cenario/natureza/carvalho", "cenario/natureza/pinheiro_medio", "cenario/natureza/rocha_grande",
	"bicicleta", "varal", "placa_rua", "cenario/rua/rua_box_03", "poste_madeira", "caixote_peixe", "carrinho_mao", "pilha_tijolo"]
const MOLES := ["cenario/natureza/arbusto_a", "cenario/natureza/arbusto_b", "cenario/natureza/samambaia_a", "cenario/natureza/samambaia_b", "cenario/natureza/tufo_capim",
		"cenario/natureza/tufo_misto", "cenario/natureza/urtiga", "cenario/natureza/galho", "cenario/natureza/pedrisco_a", "cenario/natureza/pedrisco_b"]   # sem colisão por design
const PEN_MIN := 0.2   # eixo da cápsula a <0,2 m de um vértice da malha = invadiu a peça (raio da cápsula 0,36)
var m: BRMatch
var det: IlhaDetalhes


func _fontes() -> Array:
	var veg := m.ilha.get_node_or_null("Vegetacao")
	if veg == null:
		veg = m.ilha.find_child("Vegeta*", true, false)
	return det.auditoria + (veg.auditoria if veg and "auditoria" in veg else [])


func _escolher(tipo: String, n: int) -> Array:
	var out := []
	var ss := det.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	for a in _fontes():
		if a.tipo != tipo or out.size() >= n:
			continue
		var c := Vector3.ZERO
		for q in (a.pts as PackedVector3Array):
			c += q
		if (a.pts as PackedVector3Array).is_empty():
			continue
		c /= (a.pts as PackedVector3Array).size()
		var h0: float = m.ilha.terrain.height_world(c.x, c.z)
		var d := Vector3.ZERO
		var ini := Vector3.ZERO
		for cand in [(a.basis as Basis).z, -(a.basis as Basis).z, (a.basis as Basis).x, -(a.basis as Basis).x]:
			var dc: Vector3 = cand
			dc.y = 0.0
			dc = dc.normalized()
			var ic: Vector3 = c - dc * 2.5
			ic.y = m.ilha.terrain.height_world(ic.x, ic.z) + 0.15
			# começo livre (nada na cápsula) e solo plano o bastante
			var ps := PhysicsShapeQueryParameters3D.new()
			ps.shape = cap
			ps.transform = Transform3D(Basis(), ic + Vector3(0, 0.95, 0))
			ps.collision_mask = 1
			if ss.intersect_shape(ps, 1).is_empty() and absf(ic.y - h0) <= 1.2 and h0 >= 0.5:
				d = dc
				ini = ic
				break
		if d == Vector3.ZERO:
			continue
		var pp := Vector3(d.z, 0.0, -d.x)
		var lmin := 0.0
		var lmax := 0.0
		var dmax := 0.0
		for q in (a.pts as PackedVector3Array):
			var r: Vector3 = q - c
			lmin = minf(lmin, r.dot(pp))
			lmax = maxf(lmax, r.dot(pp))
			dmax = maxf(dmax, r.dot(d))
		out.append({"c": c, "d": d, "ini": ini, "pp": pp, "lmin": lmin - 0.1, "lmax": lmax + 0.1, "dmax": dmax + 0.3, "pts": a.pts})
	return out


## menor distância horizontal do eixo do corpo aos pontos sólidos da peça (faixa 0,3..1,5 m acima do chão de partida); 99 se fora do chão
func _pen(p: Vector3, al: Dictionary) -> float:
	if absf(p.y - al.ini.y) > 0.3:
		return 99.0
	var mind := 99.0
	for q in al.pts:
		var h: float = q.y - al.ini.y
		if h > 0.3 and h < 1.5:
			mind = minf(mind, Vector2(q.x - p.x, q.z - p.z).length())
	return mind


## peça baixa (topo <= 0,5 m acima do chão) = degrau automático do Soldier (STEP_HEIGHT 0,46); senão passou por vão/contornou
func _rot_pass(al: Dictionary) -> String:
	var top := -99.0
	for q in al.pts:
		top = maxf(top, q.y - al.ini.y)
	return "degrau(topo %.2f m)" % top if top <= 0.5 else "vao/contorno(topo %.2f m)" % top


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["audit_props"] = true
	Game.test_args["denso"] = true
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	print("ANDAR terreno_colisao_pronta_ao_iniciar=%s spawn_y=%.2f" % [m.ilha.terrain.get_node_or_null("TerrenoColisao") != null, m.local_player.global_position.y])
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for i in 30:
		await get_tree().physics_frame
	det = m.ilha.get_node("Detalhes")
	var s: Soldier = m.local_player
	var tipos: Array = String(Game.test_args["tipos"]).split(",") if Game.test_args.has("tipos") else TIPOS
	if Game.test_args.has("todos"):
		var u := {}
		for a in _fontes():
			u[a.tipo] = true
		tipos = u.keys()
		tipos.sort()
		tipos = tipos.slice(int(Game.test_args.get("ini", 0)), int(Game.test_args.get("fim", 9999)))
	var seg := float(Game.test_args.get("seg", 3.0))
	var por := int(Game.test_args.get("por_tipo", 2))
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	s.godmode = true
	var res := {}
	var tot_s := 0
	var tot_z := 0
	var n_s := 0
	var n_z := 0
	for t in tipos:
		var alvos := _escolher(t, por)
		if alvos.is_empty():
			print("ANDAR %s sem alvo livre" % t)
			continue
		for al in alvos:
			# Soldier
			var d: Vector3 = al.d
			s.global_position = al.ini
			s.velocity = Vector3.ZERO
			s.yaw = atan2(-d.x, -d.z)
			s.pitch = 0.0
			s.reset_physics_interpolation()
			await get_tree().create_timer(0.3).timeout
			if absf(s.global_position.y - al.ini.y) > 0.6:
				print("ANDAR %s INVALIDO soldado fora do chao y=%.2f esperado %.2f" % [t, s.global_position.y, al.ini.y])
				continue
			Input.action_press("move_forward")
			Input.action_press("sprint")
			var t0 := Time.get_ticks_msec()
			var cruz_s := false
			var pen_s := 99.0
			while Time.get_ticks_msec() - t0 < seg * 1000.0:
				await get_tree().physics_frame
				pen_s = minf(pen_s, _pen(s.global_position, al))
				if Game.test_args.has("traco") and Engine.get_physics_frames() % 4 == 0 and t0 > 0:
					print("  traco t=%d dep=%.2f lat=%.2f (piece lat %.2f..%.2f dep<=%.2f) y=%.2f vel=%s nslide=%d" % [Time.get_ticks_msec() - t0, (s.global_position - al.c).dot(d), (s.global_position - al.c).dot(al.pp), al.lmin, al.lmax, al.dmax, s.global_position.y - al.ini.y, s.velocity, s.get_slide_collision_count()])
				if not cruz_s and (s.global_position - al.c).dot(d) > al.dmax:
					var lat: float = (s.global_position - al.c).dot(al.pp)
					cruz_s = lat >= al.lmin and lat <= al.lmax
					if false:
						var perto := 0
						var mind := 99.0
						for q in al.pts:
							if q.y - s.global_position.y > 0.2 and q.y - s.global_position.y < 1.5:
								var dh := Vector2(q.x - s.global_position.x, q.z - s.global_position.z).length()
								mind = minf(mind, dh)
								if dh < 0.3:
									perto += 1
						print("  NA PASSAGEM: pts solidos da malha a <0.3 m do eixo da capsula: %d (min %.2f m)" % [perto, mind])
					if not cruz_s:
						break   # contornou pela ponta, não atravessou
			Input.action_release("move_forward")
			Input.action_release("sprint")
			var prog_s: float = (s.global_position - al.ini).dot(d)
			# Zumbi
			var zb: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
			add_child(zb)
			zb.set_physics_process(false)
			zb.global_position = al.ini
			var cruz_z := false
			var pen_z := 99.0
			var vz: float = zb.run_speed
			for i in int(seg * 64.0):
				zb.velocity = d * vz + Vector3(0, -2.0, 0)
				zb.move_and_slide()
				await get_tree().physics_frame
				pen_z = minf(pen_z, _pen(zb.global_position, al))
				if not cruz_z and (zb.global_position - al.c).dot(d) > al.dmax:
					var latz: float = (zb.global_position - al.c).dot(al.pp)
					cruz_z = latz >= al.lmin and latz <= al.lmax
					if not cruz_z:
						break
			var prog_z: float = (zb.global_position - al.ini).dot(d)
			zb.queue_free()
			n_s += 1
			n_z += 1
			var dg_s := cruz_s and pen_s >= PEN_MIN
			var dg_z := cruz_z and pen_z >= PEN_MIN
			cruz_s = cruz_s and pen_s < PEN_MIN
			cruz_z = cruz_z and pen_z < PEN_MIN
			if cruz_s and not t in MOLES:
				tot_s += 1
			if cruz_z and not t in MOLES:
				tot_z += 1
			print("ANDAR %-45s soldado:%s (%.1f m de 2.5) zumbi:%s (%.1f m)" % [t, ("ATRAVESSOU(mole)" if t in MOLES else "ATRAVESSOU") if cruz_s else (_rot_pass(al) if dg_s else "bloqueado"), prog_s, ("ATRAVESSOU(mole)" if t in MOLES else "ATRAVESSOU") if cruz_z else (_rot_pass(al) if dg_z else "bloqueado"), prog_z])
	print("ANDAR_RESUMO soldado %d/%d atravessaram, zumbi %d/%d atravessaram" % [tot_s, n_s, tot_z, n_z])
	get_tree().quit(0 if tot_s + tot_z == 0 else 1)
