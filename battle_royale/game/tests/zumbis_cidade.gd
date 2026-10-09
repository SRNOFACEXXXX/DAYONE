extends Node
## População por cidade: leva o jogador a cada cidade e conta zumbis vivos no raio dela após alguns segundos.
## Meta (pedido do dono): >= 20 por cidade ativa. Também confere que cidades longe esvaziam (memória).
func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	var zd: ZombieDirector = m.ilha.get_node("ZombieDirector")
	var p: Soldier = m.local_player
	p.godmode = true   # o teste fica 20 s no meio de 20 zumbis; sem isso o jogador morre
	print("ZCID cidades=%d raios=%s" % [zd.city_locations.size(), str(zd.city_radii)])
	var falhas := 0
	for i in mini(3, zd.city_locations.size()):
		var c: Vector3 = zd.city_locations[i]
		p.global_position = c + Vector3(0, 2, 0)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		for f in 60 * 20:
			await get_tree().physics_frame
			if f % 300 == 0:
				var nn := 0
				for z in zd.get_children():
					var zz := z as ZombieEnemy
					if zz and zz.state != ZombieEnemy.State.DEAD and Vector2(zz.global_position.x - c.x, zz.global_position.z - c.z).length() <= zd.city_radii[i] + 12.0:
						nn += 1
				print("ZCID   t=%ds cidade=%d vivos=%d jogador_vivo=%s alvos=%d pos_jogador=(%.0f,%.0f) vida=%s" % [f / 60, i, nn, p.alive, zd._alvos_cache.size(), p.global_position.x, p.global_position.z, str(p.health) if "health" in p else "?"])
			if p.alive == false:
				p.global_position = c + Vector3(0, 2, 0)
		var n := 0
		for z in zd.get_children():
			var zz := z as ZombieEnemy
			if zz and zz.state != ZombieEnemy.State.DEAD and Vector2(zz.global_position.x - c.x, zz.global_position.z - c.z).length() <= zd.city_radii[i] + 12.0:
				n += 1
		var total := zd.get_child_count()
		print("ZCID cidade=%d centro=(%.0f,%.0f) raio=%.0f vivos_na_cidade=%d filhos_total=%d" % [i, c.x, c.z, zd.city_radii[i], n, total])
		if n < 18:
			falhas += 1
	print("ZCID_RESULT falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)
