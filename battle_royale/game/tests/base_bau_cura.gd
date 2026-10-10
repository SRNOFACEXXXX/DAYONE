extends Node
## Teste de integração: base construída pelo Soldier real (ConstructionSystem), baú de base e itens de cura.
## Rodar (com janela, para as capturas): godot --path game res://tests/base_bau_cura.tscn --quit-after 4000
## Saída: linhas BASE_BAU_CURA_* e PNGs em game/tests/_out/. Código de saída 1 se algo falhar.

class MockMatch extends Node3D:
	var hud: CanvasLayer = CanvasLayer.new()
	var local_player: Soldier = Soldier.new()
	var br_bag: BRInventory = BRInventory.new()
	var br_ui: BRInventoryUI
	var bau_aberto: StorageChest
	var drops: Array = []

	func is_survival() -> bool:
		return true

	func on_damage(_v, _a, _d, _g) -> void:
		pass

	func play_sfx(_id, _pos) -> void:
		pass

	func criar_drop(id: String, qtd: int, pos: Vector3, _extra := {}) -> void:
		drops.append({"id": id, "qty": qtd, "pos": pos})

	## Igual ao BRMatch.abrir_bau: o baú aparece em PROXIMIDADE.
	func abrir_bau(b: StorageChest) -> void:
		bau_aberto = b
		br_ui.fonte_proximos = func() -> Array: return [bau_aberto.contents]
		br_ui.open(br_bag, [])


var _falhas := 0
var _out_dir := ""


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_falhas += 1
		print("  FALHA ", msg)


func _ready() -> void:
	Game.test_args["construcao_livre"] = "1"   # teste da mecânica de encaixe, não do custo em toras
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_out_dir = ProjectSettings.globalize_path("res://tests/_out")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var m := MockMatch.new()
	add_child(m)
	m.add_child(m.hud)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#91b7cf")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8dfce")
	env.ambient_light_energy = 0.9
	we.environment = env
	m.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.3
	m.add_child(sun)
	m.add_child(_make_ground())
	var sol := m.local_player
	sol.is_local = true
	sol.is_bot = false
	sol.match_ref = m
	sol.position = Vector3(0, 0, 8)
	sol.external_motion = true
	sol.controller = PlayerController.new()
	m.add_child(sol)
	var camera := Camera3D.new()
	m.add_child(camera)
	camera.current = true
	(sol.controller as PlayerController).camera = camera
	m.br_ui = load("res://ui/br_inventory_ui.tscn").instantiate()
	m.hud.add_child(m.br_ui)
	m.br_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.br_ui.visible = false
	var build := ConstructionSystem.new()
	m.add_child(build)
	build.setup(m)
	await get_tree().process_frame

	print("== TAREFA 1: mini-base com baú ==")
	var idx_chest := -1
	for i in build.PIECES.size():
		if String(build.PIECES[i].id) == "chest":
			idx_chest = i
	_check(idx_chest == build.PIECES.size() - 1, "peça 'chest' existe na roda de construção (índice %d de %d)" % [idx_chest, build.PIECES.size()])
	# B abre a roda e a seleção navega até o baú
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_B
	_check(build.handle_input(ev), "B abre a roda")
	build.selected_piece = idx_chest
	await get_tree().process_frame
	build._close_wheel()
	build.wheel_open = false
	_check(await _place(build, camera, 0, Vector3(0, 0, 0), 0, "fundação"), "fundação colocada")
	for d in [[2, Vector3(0, .24, 1.8), 0, "parede fundo"], [2, Vector3(-1.8, .24, 0), 1, "parede esq"], [2, Vector3(1.8, .24, 0), 1, "parede dir"], [4, Vector3(0, .24, -1.8), 0, "porta"]]:
		_check(await _place(build, camera, int(d[0]), d[1], int(d[2]), String(d[3])), "%s colocada" % d[3])
	build.current_piece = idx_chest
	build._build_preview_mesh()
	await _aim(camera, Vector3(1.0, .24, 0.9))
	build._update_candidate()
	_check(build.candidate_valid, "raio da câmera aceita o baú sobre a fundação (%s)" % build.candidate_status)
	_check(build.place_current(), "baú colocado")
	var bau: StorageChest = null
	for n in get_tree().get_nodes_in_group("bau"):
		bau = n as StorageChest
	_check(bau != null and bau.contents != null, "nó StorageChest criado com contents")
	_check(bau.contents.columns * bau.contents.base_rows == 48, "capacidade 6x8 = 48 células")
	# baú sobre baú é recusado
	await _aim(camera, bau.global_position + Vector3(0, .6, 0))
	build.current_piece = idx_chest
	build._update_candidate()
	_check(not build.candidate_valid, "baú não empilha sobre baú")
	# captura 1: base aberta por cima (sem telhado) mostrando o baú
	build._leave_build_mode()
	build.notice_time = 0.0
	build.set_process(false)
	camera.global_position = Vector3(2.6, 9.5, -2.6)
	camera.look_at(Vector3(0.4, 0.0, 0.5), Vector3.UP)
	await _foto("base_bau_1_vista_de_cima_sem_telhado")
	build.set_process(true)

	# telhado e porta
	_check(await _place(build, camera, 5, Vector3(-1.5, 3.24, -2.0), 0, "telhado", Vector3(0, 3.24, 0)), "telhado colocado")
	var porta: ConstructionSystem.ConstructionDoor
	for n in get_tree().get_nodes_in_group("construction_doors"):
		porta = n as ConstructionSystem.ConstructionDoor
	_check(porta != null, "porta operável criada")
	var partes := get_tree().get_nodes_in_group("player_constructed")
	_check(partes.size() == 7, "base com 7 peças: fundação+3 paredes+porta+telhado+baú (%d)" % partes.size())

	# jogador entra: abre a porta, vai até o baú
	sol.global_position = Vector3(0, 0, -1.0)
	_check(_tecla(build, KEY_E), "E abre a porta")
	await get_tree().create_timer(.5).timeout
	_check(porta.opened, "porta aberta")
	sol.global_position = Vector3(0.9, .24, -0.1)
	sol.yaw = PI   # olhando para +Z? (yaw 0 = -Z): o baú está em +Z
	sol.yaw = 0.0
	# interação por raycast: do olho do Soldier até o baú (colisão da peça, camada MUNDO)
	var olho := sol.eye_position()
	var alvo := bau.global_position + Vector3(0, .3, 0)
	var rq := PhysicsRayQueryParameters3D.create(olho, olho + (alvo - olho).normalized() * 2.6, Soldier.LAYER_WORLD, [sol.get_rid()])
	var hit := m.get_world_3d().direct_space_state.intersect_ray(rq)
	_check(not hit.is_empty() and StorageChest.de_no(hit.collider as Node) == bau, "raycast do olho do Soldier acha o baú (colisor %s)" % (hit.collider.name if not hit.is_empty() else "nenhum"))
	# longe demais não abre
	var longe := sol.global_position
	sol.global_position = Vector3(0, 0, 7)
	_check(not bau.abrir_para(sol), "abrir_para falha a >3,2 m")
	sol.global_position = longe

	print("== depósito / retirada ==")
	_check(bau.depositar("ak47", 1, {"mag": 30}) == 1, "deposita AK-47")
	_check(bau.depositar("ammo_762", 45) == 45, "deposita 45 de 7,62")
	_check(bau.depositar("bandagem", 4) == 4, "deposita 4 bandagens")
	_check(bau.depositar("kit_medico", 1) == 1, "deposita kit médico")
	_check(bau.depositar("grenade", 2) == 2, "deposita 2 granadas")
	_check(bau.itens().size() == 5, "5 tipos de item no baú (%d)" % bau.itens().size())
	_tecla_fecha_porta(build, sol)
	await get_tree().create_timer(.5).timeout
	_check(not porta.opened, "porta fechada com o baú guardado")
	_check(bau.retirar("ammo_762", 20) == 20 and bau.retirar("bandagem", 2) == 2, "retira 20 de munição e 2 bandagens")
	_check(bau.contar("ammo_762") == 25 and bau.contar("bandagem") == 2 and bau.contar("ak47") == 1 and bau.contar("kit_medico") == 1 and bau.contar("grenade") == 2, "contagens finais 25/2/1/1/2")
	_check(bau.retirar("ammo_762", 999) == 25 and bau.contar("ammo_762") == 0, "retirar além do estoque devolve só o que existe")
	bau.depositar("ammo_762", 25)
	# inventário pelo jogador: arrastar mochila → baú (mesma operação da UI) e baú → mochila
	m.br_bag.add_item("wood", 30)
	var wood_uid := int(m.br_bag.items[0].uid)
	_check(m.br_bag.transfer_to(bau.contents, wood_uid) == 30 and bau.contar("wood") == 30, "mochila → baú (transfer_to) 30 madeira")
	_check(bau.retirar_para(m.br_bag, "wood", 10) == 10 and bau.contar("wood") == 20 and m.br_bag.count_ammo("762") == 0, "baú → mochila 10 madeira")
	bau.retirar("wood", 20)
	# capacidade: enche a grade (granadas ocupam 1 célula, pilha 3)
	var cheio := bau.depositar("grenade", 200)
	_check(cheio < 200 and cheio > 0, "baú enche (aceitou %d de 200 granadas) sem estourar a grade" % cheio)
	bau.retirar("grenade", 500)
	bau.depositar("grenade", 2)

	print("== persistência ==")
	var salvo := Baus.serializar()
	var texto := JSON.stringify(salvo)
	var lido: Dictionary = JSON.parse_string(texto)
	_check((lido.baus as Array).size() == 1, "serializar() acha 1 baú e vira JSON")
	var copias := Baus.restaurar(lido, build)
	_check(copias.size() == 1, "restaurar() recria o baú")
	var copia: StorageChest = copias[0]
	copia.get_parent().global_position = Vector3(40, 0, 40)
	_check(copia.contar("ak47") == 1 and copia.contar("ammo_762") == 25 and copia.contar("bandagem") == 2 and copia.contar("kit_medico") == 1 and copia.contar("grenade") == 2, "restaurado com os mesmos itens")
	# X no baú cheio: itens caem no chão (não se perde nada) e depois a peça some
	_check(not copia.derrubar_itens(null), "sem partida, o baú cheio não é derrubado")
	build.construction_mode = true
	await _aim_from(camera, Vector3(40, 2.5, 43), Vector3(40, .3, 40))
	_check(_tecla(build, KEY_X), "X no baú cheio")
	await get_tree().process_frame
	var soltos := 0
	for d in m.drops:
		soltos += int(d.qty)
	_check(soltos == 1 + 25 + 2 + 1 + 2 and not is_instance_valid(copia), "itens do baú removido caem no chão (%d unidades) e a peça some" % soltos)
	build._leave_build_mode()
	build.notice_time = 0.0
	build.wheel_ui.visible = false

	print("== painel do baú ==")
	build.wheel_ui.visible = false
	m.br_bag.add_item("glock", 1, Vector2i(-1, -1), {"mag": 12})
	m.br_bag.add_item("ammo_9mm", 40)
	m.br_bag.add_item("bandagem", 2)
	_check(bau.abrir_para(sol), "abrir_para(soldier) abre o inventário")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(m.br_ui.visible and m.br_ui._bau_proximo() == bau.contents, "UI aberta com o baú em PROXIMIDADE")
	_check(m.br_ui._painel_prox.title_label.text.begins_with("BAÚ"), "painel titulado BAÚ")
	camera.global_position = Vector3(5.5, 2.4, -5.5)
	camera.look_at(Vector3(0, 1.0, 0.4), Vector3.UP)
	await _foto("base_bau_2_painel_aberto")
	m.br_ui.close()
	camera.global_position = Vector3(6.5, 4.6, -8.0)
	camera.look_at(Vector3(0, 1.4, 0.2), Vector3.UP)
	await _foto("base_bau_3_exterior_com_telhado")
	camera.global_position = Vector3(-0.9, 1.7, -1.0)
	camera.look_at(Vector3(1.0, 0.35, 1.0), Vector3.UP)
	await _foto("base_bau_4_interior_com_bau")

	await _cura(m, sol)

	print("BASE_BAU_CURA_RESULTADO falhas=%d" % _falhas)
	m.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _falhas > 0 else 0)


func _cura(m: MockMatch, sol: Soldier) -> void:
	print("== TAREFA 2: curas ==")
	var bag := m.br_bag
	bag.items.clear()
	_check(BRInventory.definition("bandagem").get("heal") == 25 and is_equal_approx(float(BRInventory.definition("bandagem").time), 2.5), "definição bandagem +25 em 2,5 s")
	_check(BRInventory.definition("kit_medico").get("heal") == 60 and is_equal_approx(float(BRInventory.definition("kit_medico").time), 5.0) and bool(BRInventory.definition("kit_medico").stop_bleed), "definição kit +60 em 5 s, estanca sangramento")
	_check(Settings.BINDINGS.has("heal") and Settings.BINDINGS["heal"] == [KEY_H], "BINDINGS heal = H")
	_check(not sol.usar_cura("bandagem"), "sem o item na mochila: false")
	bag.add_item("bandagem", 3)
	bag.add_item("kit_medico", 1)
	sol.health = 100
	_check(not sol.usar_cura("bandagem"), "vida cheia: false (não gasta)")
	_check(not sol.usar_cura("ak47"), "item que não é cura: false")
	# 1) bandagem
	sol.health = 40
	_check(sol.usar_cura("bandagem") and sol.cura_ativa(), "usar_cura('bandagem') começa")
	_check(not sol.usar_cura("kit_medico"), "não empilha duas curas ao mesmo tempo")
	await get_tree().create_timer(1.3).timeout
	var prog := sol.cura_progresso()
	_check(sol.health == 40 and prog > 0.35 and prog < 0.75, "no meio da cura a vida ainda é 40 (progresso %.2f)" % prog)
	# andar e levar dano NÃO interrompe
	sol.in_move = Vector2(0, 1)
	sol.take_damage(5, null, null, "body", Vector3.ZERO)
	_check(sol.health == 35 and sol.cura_ativa(), "levar dano e se mover não interrompem")
	await get_tree().create_timer(1.5).timeout
	sol.in_move = Vector2.ZERO
	_check(not sol.cura_ativa() and sol.health == 60, "bandagem aplicada: 35 + 25 = 60 (HP %d)" % sol.health)
	_check(_contar(bag, "bandagem") == 2, "consumiu 1 bandagem (restam %d)" % _contar(bag, "bandagem"))
	# 2) respeita o máximo
	sol.health = 90
	sol.usar_cura("bandagem")
	await get_tree().create_timer(2.7).timeout
	_check(sol.health == 100 and _contar(bag, "bandagem") == 1, "cura respeita o máximo: 90 + 25 -> 100 (HP %d)" % sol.health)
	# 3) interrompe ao atirar (in_fire) — item e vida intactos
	sol.health = 50
	_check(sol.usar_cura("bandagem"), "inicia outra bandagem")
	await get_tree().create_timer(1.0).timeout
	var cancelou := []
	sol.cura_cancelled.connect(func(id: String, motivo: String) -> void: cancelou.append(motivo))
	sol.in_fire = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	sol.in_fire = false
	_check(not sol.cura_ativa() and sol.health == 50 and _contar(bag, "bandagem") == 1 and cancelou == ["atirou"], "atirar interrompe sem curar nem gastar (%s)" % [cancelou])
	# também pelo sinal fired e por trocar de arma
	sol.give_weapon(&"glock", true)
	sol.give_weapon(&"knife", true)
	sol.switch_to(WeaponDef.Slot.PISTOL)
	await get_tree().create_timer(0.6).timeout
	_check(sol.usar_cura("bandagem"), "inicia cura de novo")
	sol.switch_to(WeaponDef.Slot.KNIFE)
	await get_tree().physics_frame
	_check(not sol.cura_ativa() and cancelou.back() == "trocou de arma", "trocar de arma interrompe")
	sol.switch_to(WeaponDef.Slot.PISTOL)
	await get_tree().create_timer(0.6).timeout
	_check(sol.usar_cura("bandagem"), "inicia cura para testar o sinal fired")
	sol.fired.emit(sol.current_def())
	_check(not sol.cura_ativa() and cancelou.back() == "atirou", "sinal fired interrompe")
	# 4) kit médico: +60, remove sangramento
	sol.health = 20
	sol.iniciar_sangramento()
	_check(sol.sangrando, "sangrando")
	_check(sol.usar_cura("kit_medico"), "usar_cura('kit_medico') começa")
	await get_tree().create_timer(2.6).timeout
	_check(sol.health == 20 and sol.cura_ativa() and sol.cura_progresso() > 0.4, "kit ainda em andamento aos 2,6 s (progresso %.2f)" % sol.cura_progresso())
	await get_tree().create_timer(2.7).timeout
	_check(not sol.cura_ativa() and sol.health == 80 and not sol.sangrando and _contar(bag, "kit_medico") == 0, "kit aplicado: 20 + 60 = 80, sangramento removido, kit consumido (HP %d)" % sol.health)
	# 5) sangramento sem cura tira vida devagar e nunca mata
	sol.health = 3
	sol.iniciar_sangramento()
	await get_tree().create_timer(5.0).timeout
	_check(sol.health >= 1 and sol.health < 3, "sangramento sem cura: HP cai devagar e para em >= 1 (HP %d)" % sol.health)
	sol.sangrando = false
	# 6) H (usar_cura_auto) e bots sem inventário
	sol.health = 70
	bag.add_item("bandagem", 1)
	_check(sol.usar_cura_auto(), "usar_cura_auto() usa a bandagem")
	await get_tree().create_timer(2.7).timeout
	_check(sol.health == 95, "auto: 70 + 25 = 95 (HP %d)" % sol.health)
	var bot_bag := BRInventory.new()
	bot_bag.add_item("kit_medico", 1)
	sol.cura_bag = bot_bag
	sol.health = 30
	_check(sol.usar_cura("kit_medico"), "bot: cura_bag próprio")
	await get_tree().create_timer(5.2).timeout
	_check(sol.health == 90 and _contar(bot_bag, "kit_medico") == 0, "bot: kit sai do cura_bag (HP %d)" % sol.health)
	sol.cura_bag = null
	# 7) ícones e sorteio
	var br_ok := true
	for id in ["bandagem", "kit_medico"]:
		br_ok = br_ok and not BRInventory.definition(id).is_empty()
	_check(br_ok, "itens registrados no inventário")
	var cont := {"bandagem": 0, "kit_medico": 0}
	seed(11)
	for i in 3000:
		var mv := BRMovel.new()
		mv.setup_movel("Nightstand")
		mv.sortear()
		for it in mv.contents.items:
			if cont.has(String(it.id)):
				cont[String(it.id)] += int(it.qty)
		mv.free()
	_check(cont.bandagem > 0 and cont.kit_medico > 0 and cont.bandagem > cont.kit_medico * 3, "móveis (3000 sorteios): bandagem %d  kit %d (kit é raro)" % [cont.bandagem, cont.kit_medico])
	var cc := {"bandagem": 0, "kit_medico": 0}
	for tier in ["baixo", "medio", "alto"]:
		for i in 600:
			var cr := BRCrate.new()
			cr.tier = tier
			cr.contents = BRInventory.make_loot_container(4)
			cr._sortear()
			for it in cr.contents.items:
				if cc.has(String(it.id)):
					cc[String(it.id)] += int(it.qty)
			cr.free()
	_check(cc.bandagem > 0 and cc.kit_medico > 0 and cc.bandagem > cc.kit_medico, "caixas (1800 sorteios): bandagem %d  kit %d" % [cc.bandagem, cc.kit_medico])
	# 8) HUD: VitalBar desenha a cura em andamento (captura)
	var barra := VitalBar.new()
	barra.vincular(sol)
	barra.position = Vector2(30, 600)
	barra.size = Vector2(330, 62)
	m.hud.add_child(barra)
	sol.health = 45
	sol.iniciar_sangramento()
	bag.add_item("bandagem", 1)
	sol.usar_cura("bandagem")
	await get_tree().create_timer(1.3).timeout
	await _foto("cura_hud_barra")
	_check(sol.cura_ativa(), "HUD capturado com a cura em andamento")
	sol.cura_cancelar("fim do teste")
	barra.queue_free()


func _contar(inv: BRInventory, id: String) -> int:
	var n := 0
	for it in inv.items:
		if String(it.id) == id:
			n += int(it.qty)
	return n


func _foto(nome: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		return
	var caminho := _out_dir.path_join(nome + ".png")
	get_viewport().get_texture().get_image().save_png(caminho)
	print("BASE_BAU_CURA_PNG=", caminho)


func _place(build: ConstructionSystem, camera: Camera3D, piece_id: int, target: Vector3, rot: int, label: String, expected: Variant = null) -> bool:
	build.current_piece = piece_id
	build.yaw_step = rot
	build._build_preview_mesh()
	await _aim(camera, target)
	build._update_candidate()
	if not build.candidate_valid:
		print("  (%s recusada em %s: %s)" % [label, target, build.candidate_status])
		return false
	if expected is Vector3 and build.candidate_transform.origin.distance_to(expected) > .06:
		print("  (%s ancorou em %s, esperado %s)" % [label, build.candidate_transform.origin, expected])
		return false
	return build.place_current()


func _aim(camera: Camera3D, target: Vector3) -> void:
	camera.global_position = target + Vector3(0, 7, 0)
	camera.look_at(target, Vector3.FORWARD)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _aim_from(camera: Camera3D, origem: Vector3, alvo: Vector3) -> void:
	camera.global_position = origem
	camera.look_at(alvo, Vector3.UP if absf((alvo - origem).normalized().y) < .98 else Vector3.FORWARD)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _tecla(build: ConstructionSystem, key: Key) -> bool:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = key
	return build.handle_input(e)


func _tecla_fecha_porta(build: ConstructionSystem, sol: Soldier) -> void:
	sol.global_position = Vector3(0, 0, -1.0)
	_check(_tecla(build, KEY_E), "E fecha a porta")


func _make_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	ground.name = "SandboxGround"
	ground.collision_layer = Soldier.LAYER_WORLD
	ground.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, .2, 200)
	cs.shape = shape
	ground.add_child(cs)
	ground.position.y = -.1
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#608b38")
	mesh.material_override = material
	ground.add_child(mesh)
	return ground
