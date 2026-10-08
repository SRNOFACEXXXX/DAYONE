extends Node
## Cercas/muros/portões reais da ilha: o Soldier real anda contra a peça vindo pela FRENTE e pelas COSTAS (3 s de input para frente).
## Mede quantas vezes atravessa em cada lado. Com `-- --antigo=1` desliga backface_collision dos trimesh (comportamento antigo) para comparar.
## Uso: godot --path game res://tests/cerca_dois_lados.tscn [-- --antigo=1]  -> CERCA_DOIS_LADOS_OK / FALHOU
var m: BRMatch
var det: IlhaDetalhes
var s: Soldier
var falhas := 0
var testes := 0


func _ready() -> void:
	get_tree().create_timer(280.0).timeout.connect(func() -> void: print("CERCA_DOIS_LADOS_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["audit_props"] = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for i in 40:
		await get_tree().physics_frame
	if Game.test_args.has("antigo"):
		for n in m.find_children("*", "CollisionShape3D", true, false):
			if (n as CollisionShape3D).shape is ConcavePolygonShape3D:
				((n as CollisionShape3D).shape as ConcavePolygonShape3D).backface_collision = false
	det = m.ilha.get_node("Detalhes")
	s = m.local_player
	s.godmode = true
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	var por_tipo := {}
	var cruz := {"frente": 0, "costas": 0}
	var tot := {"frente": 0, "costas": 0}
	for a in det.auditoria:
		var tipo := String(a.tipo)
		if not (tipo.begins_with("cerca") or tipo.begins_with("muro") or tipo.begins_with("cenario/natureza/cerca") or tipo.begins_with("cenario/natureza/muro")):
			continue
		if Game.test_args.has("foco"):
			var fz: PackedStringArray = String(Game.test_args["foco"]).split(",")
			var cc := Vector3.ZERO
			for q0 in (a.pts as PackedVector3Array):
				cc += q0
			cc /= maxf(1.0, float((a.pts as PackedVector3Array).size()))
			if Vector2(cc.x - float(fz[0]), cc.z - float(fz[1])).length() > 3.0:
				continue
		elif int(por_tipo.get(tipo, 0)) >= 3:
			continue
		var pts: PackedVector3Array = a.pts
		if pts.is_empty():
			continue
		var c := Vector3.ZERO
		var mn := Vector3(INF, INF, INF)
		var mx := Vector3(-INF, -INF, -INF)
		for q in pts:
			c += q
			mn = mn.min(q)
			mx = mx.max(q)
		c /= pts.size()
		var ext := mx - mn
		# eixo fino na orientação REAL da peça (base do nó): o menor alcance dos vértices projetados
		var bx: Vector3 = (a.basis as Basis).x
		bx.y = 0.0
		bx = bx.normalized()
		var bz: Vector3 = (a.basis as Basis).z
		bz.y = 0.0
		bz = bz.normalized()
		var e_x := 0.0
		var e_z := 0.0
		for q in pts:
			e_x = maxf(e_x, absf((q - c).dot(bx)))
			e_z = maxf(e_z, absf((q - c).dot(bz)))
		var d := bx if e_x < e_z else bz
		ext = Vector3(e_x * 2.0, ext.y, e_z * 2.0)
		for lado in [["frente", 1.0], ["costas", -1.0]]:
			var sg: float = lado[1]
			var ini: Vector3 = c - d * sg * 2.5
			ini.y = m.ilha.terrain.height_world(ini.x, ini.z) + 0.15
			if m.ilha.terrain.height_world(c.x, c.z) < 0.5:
				continue
			s.global_position = ini
			s.velocity = Vector3.ZERO
			var f: Vector3 = d * sg
			s.yaw = atan2(-f.x, -f.z)
			s.pitch = 0.0
			s.reset_physics_interpolation()
			await get_tree().create_timer(0.35).timeout
			var ps := PhysicsShapeQueryParameters3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.3
			cap.height = 1.5
			ps.shape = cap
			ps.transform = Transform3D(Basis(), s.global_position + Vector3(0, 0.95, 0))
			ps.collision_mask = 1
			ps.exclude = [s.get_rid()]
			if not s.get_world_3d().direct_space_state.intersect_shape(ps, 1).is_empty():
				continue   # começou dentro de algo: inválido
			Input.action_press("move_forward")
			if Game.test_args.has("foco"):
				for k in 12:
					await get_tree().create_timer(0.25).timeout
					print("   t=%.2f pos=(%.2f, %.2f, %.2f) vel=%.1f mantle=%s chao=%s" % [(k + 1) * 0.25, s.global_position.x, s.global_position.y, s.global_position.z, s.velocity.length(), s._mantle_on, s.is_on_floor()])
			else:
				await get_tree().create_timer(3.0).timeout
			Input.action_release("move_forward")
			var avanco := (s.global_position - c).dot(f)
			tot[lado[0]] += 1
			if avanco > 0.4:
				cruz[lado[0]] += 1
				var hs := []
				for hh in [0.4, 0.9, 1.4]:
					var rq := PhysicsRayQueryParameters3D.create(Vector3(ini.x, ini.y + hh, ini.z), Vector3(c.x, ini.y + hh, c.z) + f * 3.0, 1)
					var rh := s.get_world_3d().direct_space_state.intersect_ray(rq)
					hs.append(("%.1f" % Vector3(ini.x, 0, ini.z).distance_to(Vector3(rh.position.x, 0, rh.position.z))) if not rh.is_empty() else "-")
				print("ATRAVESSOU %s lado=%s avanço=%.2f m em (%.0f, %.0f) ext=%s raio(0.4/0.9/1.4 m)=%s" % [tipo, lado[0], avanco, c.x, c.z, (mx - mn).snapped(Vector3(0.1, 0.1, 0.1)), str(hs)])
		por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
	print("RESULTADO frente: %d/%d atravessaram | costas: %d/%d atravessaram (antigo=%s)" % [cruz.frente, tot.frente, cruz.costas, tot.costas, Game.test_args.has("antigo")])
	# peças em aglomerados (3 muros a <3 m) podem ter vão entre elas; tolera até 5% e exige 0 pelas costas (backface_collision)
	var ok: bool = float(cruz.frente) <= 0.05 * float(tot.frente) + 0.99 and cruz.costas == 0 and tot.frente > 5
	print("CERCA_DOIS_LADOS_OK" if ok else "CERCA_DOIS_LADOS_FALHOU")
	get_tree().quit(0 if ok else 1)
