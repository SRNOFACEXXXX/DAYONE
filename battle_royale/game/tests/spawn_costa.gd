extends Node
## SPAWN do jogador no jogo real: 60 sorteios de praia medidos (altura, inclinação, colisão, zumbis, onde nasce) e 8 renascimentos reais
## do Soldier (m.respawn) com captura em 1ª pessoa. Regras: terreno 0,6–9 m, inclinação < 12°, cápsula livre, nenhum zumbi a < 45 m,
## olhando para o interior, nunca o mesmo ponto duas vezes seguidas.
## Uso: godot --path game res://tests/spawn_costa.tscn -> SPAWN_COSTA_OK / FALHOU ; capturas raw/spawn/spawn_N.png
var m: BRMatch
var falhas: Array = []


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func() -> void: print("SPAWN_COSTA_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["spawn_costa"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	var s: Soldier = m.local_player
	await _f(30)
	var t: IlhaTerrain = m.ilha.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fixos := 0
	var hmin := 99.0
	var hmax := -99.0
	var decl_max := 0.0
	var tent_total := 0
	var pontos: Array = []
	for i in 60:
		var sp: Dictionary = m.escolher_spawn_costa(rng)
		if sp.get("fixo", false):
			fixos += 1
			continue
		var p: Vector3 = sp.pos
		tent_total += int(sp.tentativas)
		hmin = minf(hmin, p.y)
		hmax = maxf(hmax, p.y)
		var d := 0.0
		for off in [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]:
			d = maxf(d, absf(t.height_world(p.x + off.x, p.z + off.z) - p.y) / 3.0)
		decl_max = maxf(decl_max, d)
		pontos.append(Vector2(p.x, p.z).snapped(Vector2(20, 20)))
	var unicos := {}
	for p in pontos:
		unicos[p] = true
	print("SPAWN 60 sorteios: fixos(fallback)=%d válidos=%d  altura %.1f..%.1f m  declive máx %.0f%% (%.1f°)  tentativas média %.1f  regiões distintas(20 m)=%d" % [fixos, pontos.size(), hmin, hmax, decl_max * 100.0, rad_to_deg(atan(decl_max)), float(tent_total) / maxf(1.0, pontos.size()), unicos.size()])
	_ck("nenhum sorteio caiu no ponto fixo de fallback", fixos == 0)
	_ck("altura entre 0,6 e 9 m", hmin >= 0.6 and hmax <= 9.0)
	_ck("declive < 12°", rad_to_deg(atan(decl_max)) < 12.0)
	_ck("pelo menos 25 regiões diferentes", unicos.size() >= 25)
	# renascimentos reais
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/spawn")
	DirAccess.make_dir_recursive_absolute(out)
	var anterior := Vector3.INF
	for i in 8:
		m.respawn(s)
		s.godmode = true
		await _f(120)
		var p := s.global_position
		var na_agua := p.y < 0.3
		var ps := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.5
		ps.shape = cap
		ps.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
		ps.collision_mask = 1
		ps.exclude = [s.get_rid()]
		var dentro: bool = not s.get_world_3d().direct_space_state.intersect_shape(ps, 1).is_empty()
		var zmin := 1e9
		for z in get_tree().get_nodes_in_group("zombie"):
			zmin = minf(zmin, (z as Node3D).global_position.distance_to(p))
		var vm: ViewModel = (s.controller as PlayerController).viewmodel
		print("   mão: arma=%s viewmodel=%s modelo=%s visivel=%s holder_vis=%s draw_t=%.2f pivot_vis=%s root_vis=%s holder_pos=%s cam_rel=%s" % [s.current_def().id if s.current_def() else "-", vm.current_id, vm.scene_root != null, vm.is_visible_in_tree(), vm.holder.visible, vm._draw_t, vm.pivot.visible, vm.scene_root.visible if vm.scene_root else "-", vm.holder.position, (s.controller as PlayerController).camera.to_local(vm.holder.global_position)])
		print("RENASCEU %d pos=(%.0f, %.1f, %.0f) yaw=%.0f° agua=%s dentro_de_geometria=%s zumbi_mais_perto=%.0f m no_chao=%s" % [i, p.x, p.y, p.z, rad_to_deg(s.yaw), na_agua, dentro, zmin, s.is_on_floor()])
		_ck("renascimento %d fora da água" % i, not na_agua)
		_ck("renascimento %d fora de geometria" % i, not dentro)
		_ck("renascimento %d no chão" % i, s.is_on_floor())
		_ck("renascimento %d longe de zumbis (>=40 m)" % i, zmin >= 40.0)
		if anterior != Vector3.INF:
			_ck("renascimento %d em outro ponto" % i, p.distance_to(anterior) > 5.0)
		anterior = p
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("spawn_%d.png" % i))
	print("SPAWN_COSTA_OK" if falhas.is_empty() else "SPAWN_COSTA_FALHOU %d %s" % [falhas.size(), str(falhas)])
	get_tree().quit(0 if falhas.is_empty() else 1)


func _ck(nome: String, ok: bool) -> void:
	if not ok:
		print("FALHA ", nome)
		falhas.append(nome)


func _f(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
