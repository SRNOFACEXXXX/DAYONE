extends Node
## Teste de construção (raios reais): fantasma verde/vermelho, inclinação máxima do terreno sob a fundação,
## assentamento na média dos cantos e durabilidade (dano_em_peca -> demolição).

class MockMatch extends Node3D:
	var hud: CanvasLayer = CanvasLayer.new()
	var local_player: Soldier = Soldier.new()
	var br_bag: BRInventory = BRInventory.new()
	var br_ui: Control


func _ready() -> void:
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var m := MockMatch.new()
	add_child(m)
	m.add_child(m.hud)
	# chão plano (topo em y=0) + rampa suave (rise/run 0.2, sobe para +X) + rampa íngreme (0.6, sobe para +X)
	m.add_child(_make_box(Vector3(0, -.1, 0), Vector3(100, .2, 100), 0.0))
	m.add_child(_make_box(Vector3(30, 1.4, 0), Vector3(20, .2, 20), atan(.2)))
	m.add_child(_make_box(Vector3(-30, 2.9, 0), Vector3(20, .2, 20), atan(.6)))
	m.local_player.position = Vector3(0, 0, 8)
	m.local_player.external_motion = true
	m.local_player.controller = PlayerController.new()
	m.add_child(m.local_player)
	var camera := Camera3D.new()
	m.add_child(camera)
	camera.current = true
	(m.local_player.controller as PlayerController).camera = camera
	var build := ConstructionSystem.new()
	m.add_child(build)
	build.setup(m)
	await get_tree().process_frame

	# 1) fantasma: verde quando válido, vermelho quando inválido (também tinge a grade).
	build.current_piece = 0
	build._build_preview_mesh()
	build._set_preview_tint(true)
	var fantasma := _fantasma(build)
	assert(fantasma != null and fantasma.albedo_color.g > .9 and fantasma.albedo_color.r < .5, "fantasma válido deve ser verde")
	build._set_preview_tint(false)
	fantasma = _fantasma(build)
	assert(fantasma != null and fantasma.albedo_color.r > .9 and fantasma.albedo_color.g < .3, "fantasma inválido deve ser vermelho")

	# 2) chão plano: fundação válida, assentada em y=0.
	await _aim(camera, Vector3(0, 0, 0))
	build._update_candidate()
	assert(build.candidate_valid, "fundação no chão plano deve ser válida: %s" % build.candidate_status)
	assert(absf(build.candidate_transform.origin.y) < .02, "fundação plana deve ficar na altura do chão")
	assert(build.place_current(), "fundação plana deve ser colocada")
	var base: Node3D = null
	for node in get_tree().get_nodes_in_group("player_constructed"):
		base = node as Node3D
	assert(base != null, "fundação colocada precisa estar no grupo de construções")

	# 3) durabilidade: 600 pontos; dano parcial só reduz; dano letal demole a peça.
	assert(absf(build.hp_da_peca(base) - 600.0) < .01, "fundação nasce com 600 pontos de durabilidade")
	assert(not build.dano_em_peca(base, 100.0), "dano parcial não destrói")
	assert(absf(build.hp_da_peca(base) - 500.0) < .01, "dano de 100 deve deixar 500")
	assert(build.dano_em_peca(base, 500.0), "dano que zera a durabilidade destrói a peça")
	await get_tree().process_frame
	assert(not is_instance_valid(base), "peça destruída deve sair da cena")

	# 4) rampa suave (0.2 ≈ 11°): aceita; assenta na altura do centro da pegada, não na do ponto mirado.
	build.current_piece = 0
	build._build_preview_mesh()
	await _aim(camera, Vector3(30, 1.4, 0))
	build._update_candidate()
	assert(build.candidate_valid, "rampa suave deve aceitar fundação: %s" % build.candidate_status)
	var x := build.candidate_transform.origin.x
	var y_esperado := 1.5 + (x - 30.0) * .2
	assert(absf(build.candidate_transform.origin.y - y_esperado) < .06, "fundação na rampa deve seguir a superfície: y=%.3f esperado=%.3f" % [build.candidate_transform.origin.y, y_esperado])

	# 5) rampa íngreme (0.6 ≈ 31°): recusada com o motivo de terreno.
	await _aim(camera, Vector3(-30, 2.9, 0))
	build._update_candidate()
	assert(not build.candidate_valid, "rampa de 0.6 não deve aceitar fundação")
	assert(build.candidate_status == "TERRENO MUITO INCLINADO", "motivo deve ser terreno inclinado, veio: %s" % build.candidate_status)
	assert(_fantasma(build).albedo_color.r > .9, "fantasma sobre terreno inclinado deve ser vermelho")

	# 6) modo livre (testes): não há custo nem reembolso, então o inventário continua vazio.
	assert(build._material_count("wood") == 0 and build._material_count("stone") == 0, "modo livre não consome nem devolve material")
	build._reembolsar("foundation")
	assert(build._material_count("wood") == 0, "reembolso não deve creditar no modo livre")

	print("CONSTRUCAO_TERRENO_OK verde_vermelho=ok plano=ok rampa_suave=ok rampa_inclinada=recusada durabilidade=ok")
	m.local_player.controller.free()
	m.local_player.free()
	m.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _fantasma(build: ConstructionSystem) -> StandardMaterial3D:
	for visual in build.preview_root.find_children("*", "MeshInstance3D", true, false):
		if String(visual.name) != "BlueprintGrid":
			return (visual as MeshInstance3D).material_override as StandardMaterial3D
	return null


func _make_box(center: Vector3, size: Vector3, angle_z: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Soldier.LAYER_WORLD
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = center
	body.rotation.z = angle_z
	return body


func _aim(camera: Camera3D, target: Vector3) -> void:
	camera.global_position = target + Vector3(0, 7, 0)
	camera.look_at(target, Vector3.FORWARD)
	await get_tree().physics_frame
	await get_tree().physics_frame
