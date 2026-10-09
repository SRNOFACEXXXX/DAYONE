extends Node
## Animais no jogo real: o diretor faz nascer bichos perto do jogador; um cervo e um lobo de frente para a câmera
## (fotos andando/correndo), tiro no cervo (morre), faca no inventário + E real -> esfola -> itens no chão. --out=<pasta>
const ANIMAL := preload("res://core/animal.gd")
var _out := ""


func _shot(nome: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(nome + ".png"))


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	_out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	var p: Soldier = m.local_player
	var dir_animais: Node3D = m.ilha.get_node_or_null("Animais")
	var falhas := 0
	for i in 60 * 12:
		await get_tree().physics_frame
	var n_vivos := 0
	if dir_animais:
		for a in dir_animais.get_children():
			if a is CharacterBody3D:
				n_vivos += 1
	print("ANIMAIS diretor=%s nasceram=%d" % [dir_animais != null, n_vivos])
	if n_vivos < 1:
		falhas += 1
	# campo aberto e plano perto (o spawn pode ser em cima de muro/laje): 20x20 m com desnível < 0,6 m
	var t: IlhaTerrain = m.ilha.terrain
	var ss := m.get_world_3d().direct_space_state
	var achou := p.global_position
	for r in range(15, 300, 15):
		var ok := false
		for k in 12:
			var c := p.global_position + Vector3(cos(TAU * k / 12.0), 0, sin(TAU * k / 12.0)) * r
			var lo := INF
			var hi := -INF
			for dx in [-10.0, 0.0, 10.0]:
				for dz in [-10.0, 0.0, 10.0]:
					var h := t.height_world(c.x + dx, c.z + dz)
					lo = minf(lo, h)
					hi = maxf(hi, h)
			if lo < 1.5 or hi - lo > 0.6:
				continue
			var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, hi + 6.0, c.z), Vector3(c.x, lo - 1.0, c.z), 1)
			var hit := ss.intersect_ray(q)
			if hit.is_empty() or absf(hit.position.y - t.height_world(c.x, c.z)) > 0.2:
				continue   # tem prédio/objeto em cima
			achou = Vector3(c.x, t.height_world(c.x, c.z) + 0.2, c.z)
			ok = true
			break
		if ok:
			break
	p.global_position = achou
	p.reset_physics_interpolation()
	p.pitch = -0.15
	for i in 30:
		await get_tree().physics_frame
	var frente := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var lado := Vector3(frente.z, 0, -frente.x)
	var bichos := []
	for e in [["cervo", 7.0, -1.8], ["lobo", 6.0, 1.8], ["galinha", 3.5, 0.0]]:
		var a := ANIMAL.new()
		a.configurar(e[0], m.ilha.terrain)
		dir_animais.add_child(a)
		var pos: Vector3 = p.global_position + frente * float(e[1]) + lado * float(e[2])
		pos.y = m.ilha.terrain.height_world(pos.x, pos.z) + 0.3
		a.global_position = pos
		bichos.append(a)
	for i in 50:
		await get_tree().physics_frame
	await _shot("00_animais")
	for i in 40:
		await get_tree().physics_frame
	await _shot("01_movendo")
	var cervo = bichos[0]
	var r: Dictionary = cervo.hit_by_bullet(cervo.global_position + Vector3.UP, frente, WeaponDB.get_def(&"mosin"), 1.0, p)
	r = cervo.hit_by_bullet(cervo.global_position + Vector3.UP, frente, WeaponDB.get_def(&"mosin"), 1.0, p) if not r.killed else r
	for i in 60:
		await get_tree().physics_frame
	await _shot("02_cervo_morto")
	print("ANIMAIS cervo_morto=%s" % [cervo.state == ANIMAL.DEAD])
	if cervo.state != ANIMAL.DEAD:
		falhas += 1
	# faca + E perto da carcaça
	m.br_bag.add_item("faca", 1)
	cervo.set_physics_process(false)
	p.global_position = cervo.global_position - frente * 1.2
	p.reset_physics_interpolation()
	for i in 10:
		await get_tree().physics_frame
	var drops_antes := m.br_loot_root.get_child_count()
	Input.action_press("use")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("use")
	for i in 30:
		await get_tree().physics_frame
	var drops := m.br_loot_root.get_child_count() - drops_antes
	await _shot("03_esfolado")
	print("ANIMAIS esfolar_drops=%d" % drops)
	if drops < 3:
		falhas += 1
	print("ANIMAIS_RESULT falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)
