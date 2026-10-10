extends Node
## Horda no jogo real: 14 zumbis nascem EXATAMENTE no mesmo ponto e perseguem o jogador; depois de 6 s a distância mínima entre
## pares tem de passar de 0,45 m (antes viravam um bolo na mesma posição). --out=<pasta>
var out := ""


func _shot(nome: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))


func _menor_par(zs: Array) -> float:
	var mn := 99.0
	for i in zs.size():
		for j in range(i + 1, zs.size()):
			var a: Vector3 = (zs[i] as Node3D).global_position
			var b: Vector3 = (zs[j] as Node3D).global_position
			mn = minf(mn, Vector2(a.x - b.x, a.z - b.z).length())
	return mn


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	while Loading.visivel():
		await get_tree().process_frame
	var p := m.local_player
	p.godmode = true
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	await get_tree().physics_frame
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	var ponto := p.global_position + fwd.normalized() * 14.0
	var zs: Array = []
	for i in 14:
		var z: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
		m.add_child(z)
		z.global_position = ponto
		zs.append(z)
	for i in 6 * 60:
		await get_tree().physics_frame
	var vivos := zs.filter(func(z): return is_instance_valid(z))
	var mn := _menor_par(vivos)
	print("HORDA vivos=%d menor_distancia_entre_pares=%.2f m" % [vivos.size(), mn])
	await _shot("horda")
	var ok := vivos.size() >= 10 and mn > 0.45
	print("HORDA_RESULT ", "PASSOU" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)
