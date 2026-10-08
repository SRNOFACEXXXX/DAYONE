extends Node
## Fumaça do modo sobrevivência: caixa abre, colete/placas (B), granada (G) e regeneração lenta. Capturas em --out=<pasta>.

var out := ""


func _ready() -> void:
	Game.test_mode = true
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	await _frames(90)
	assert(m.is_survival(), "modo sobrevivência")
	assert(s.global_position.distance_to(Vector3(BRMatch.SPAWN_JOGADOR.x, 0, -BRMatch.SPAWN_JOGADOR.y)) < 40.0, "nasce perto da cidade")
	print("SV spawn=", s.global_position, " estado=", m.estado.get(s))
	await _foto("spawn")
	# caixa
	var crate: BRCrate = m.br_loot_root.get_child(0)
	s.global_position = crate.global_position + Vector3(0, 0.3, 2.2)
	s.yaw = 0.0
	s.reset_physics_interpolation()
	await _frames(20)
	crate.abrir()
	await _frames(14)
	await _foto("caixa_abrindo")
	await _frames(40)
	print("SV caixa itens=", crate.contents.items.size(), " ", crate.contents.items.map(func(i): return i.id))
	assert(crate.contents.items.size() <= 2, "no máximo 2 itens")
	await _foto("caixa_aberta")
	crate.take_all(m.br_bag)
	# colete/placas desativados (Soldier.PLACAS_ATIVAS = false): reativar este bloco quando voltarem os tiers
	# granada
	var g0: int = m.granadas()   # a caixa sorteada pode ter dado granadas
	# quanto coube de verdade (limite de peso/pilha: a caixa pode já ter dado granadas)
	var cabe: int = m.br_bag.add_item("grenade", 2)
	await _frames(3)
	print("SV granadas antes=", g0, " cabe=", cabe)
	assert(cabe >= 1 and m.granadas() == g0 + cabe, "granadas somadas = quantia que coube")
	var g1: int = m.granadas()
	m._lancar_granada()
	assert(m.granadas() == g1 - 1, "lançar gasta 1 granada")
	await _frames(200)
	await _foto("granada")
	# regeneração: 2 min sem combate
	s.health = 50
	s.combat_t = s.t
	await get_tree().create_timer(3.0).timeout
	assert(s.health == 50, "sem regen antes de 2 min")
	s.combat_t = s.t - 119.5
	await get_tree().create_timer(3.5).timeout
	print("SV health após atraso=", s.health)
	assert(s.health > 50 and s.health < 60, "regen lenta depois de 2 min")
	# morte -> respawn
	s.take_damage(500.0, null, null, "chest", Vector3.DOWN)
	await _frames(10)
	assert(not s.alive)
	await get_tree().create_timer(BRMatch.RESPAWN_S + 1.0).timeout
	assert(s.alive and s.health == 100 and not s.has_vest, "renasce limpo")
	print("SV OK")
	get_tree().quit()


func _tecla(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("sv_%s.png" % nome))
