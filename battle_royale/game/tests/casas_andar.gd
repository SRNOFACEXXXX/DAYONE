extends Node
## Casas do pacote (core/casa_pacote.gd): Soldier real e ZombieEnemy andam 3 s de 4 lados (norte/sul/leste/oeste, 9 m) em direção ao centro.
## Paredes devem parar o corpo; só portas/janelas abertas deixam entrar. Mede o quanto cada lado avançou e se algum corpo ficou DENTRO
## da planta (|x|<4,5 e |z|<4,5 do centro) sem passar por abertura: aqui só relatamos a profundidade máxima por lado.
func _ready() -> void:
	Game.test_mode = true
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	for i in 40:
		await get_tree().physics_frame
	var s: Soldier = m.local_player
	s.godmode = true
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	var casas := get_tree().get_nodes_in_group("casa_pacote")
	print("CASAS total=%d" % casas.size())
	var bloq_s := 0
	var bloq_z := 0
	var n := 0
	for k in mini(casas.size(), int(Game.test_args.get("n", 4))):
		var c: Node3D = casas[k * maxi(1, casas.size() / 4)]
		for lado in 4:
			var d := Vector3(1, 0, 0).rotated(Vector3.UP, c.rotation.y + lado * PI * 0.5)
			var ini: Vector3 = c.global_position - d * 9.0
			ini.y = m.ilha.terrain.height_world(ini.x, ini.z) + 0.15
			s.global_position = ini
			s.velocity = Vector3.ZERO
			s.yaw = atan2(-d.x, -d.z)
			s.reset_physics_interpolation()
			await get_tree().create_timer(0.3).timeout
			Input.action_press("move_forward")
			var t0 := Time.get_ticks_msec()
			var dep_s := -99.0
			while Time.get_ticks_msec() - t0 < 3000:
				await get_tree().physics_frame
				dep_s = maxf(dep_s, (s.global_position - c.global_position).dot(d))
			Input.action_release("move_forward")
			var zb: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
			add_child(zb)
			zb.set_physics_process(false)
			zb.global_position = ini
			var dep_z := -99.0
			for i in 192:
				zb.velocity = d * zb.run_speed + Vector3(0, -2.0, 0)
				zb.move_and_slide()
				await get_tree().physics_frame
				dep_z = maxf(dep_z, (zb.global_position - c.global_position).dot(d))
			zb.queue_free()
			# parede externa a ~±6 m do centro: parou antes dela = bloqueado
			n += 1
			if dep_s < -4.5:
				bloq_s += 1
			if dep_z < -4.5:
				bloq_z += 1
			print("CASA %s lado %d: soldado avancou ate %.1f m do centro (profundidade, - = fora), zumbi %.1f m" % [c.name, lado, -dep_s, -dep_z])
	print("CASAS_RESUMO lados=%d parados_na_parede soldado=%d zumbi=%d (os demais entraram por porta/janela aberta ou ficaram a >4,5 m)" % [n, bloq_s, bloq_z])
	get_tree().quit()
