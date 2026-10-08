extends Node
## Morte com pedaços: tiro de M107 na cabeça (cabeça estoura) e explosão (membros arrancados). Confere ossos ocultos e
## pedaços no mundo; fotos antes/depois. --out=<pasta>
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
	var zd: Node = m.ilha.get_node("ZombieDirector")
	var zs: Array = []
	for z in zd.get_children():
		if z is ZombieEnemy and (z as ZombieEnemy).state != ZombieEnemy.State.DEAD:
			zs.append(z)
		if zs.size() >= 2:
			break
	for i in 240:   # a tela de carregamento some depois do match_initialized
		await get_tree().process_frame
	# chão plano à frente: vira o jogador para um lado livre e olha um pouco para baixo
	p.pitch = -0.12
	var frente := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var falhas := 0
	for k in 2:
		var z := zs[k] as ZombieEnemy
		var lado := Vector3(-frente.z, 0, frente.x)
		var alvo := p.global_position + frente * (4.0 + k * 1.5) + lado * (k * 1.6 - 0.8)
		alvo.y = m.ilha.terrain.height_world(alvo.x, alvo.z)
		z.global_position = alvo
		z.set_lod(0)
		z.set_physics_process(false)
		z.rotation.y = p.yaw + PI
	for i in 30:
		await get_tree().physics_frame
	await _shot("00_antes")
	var z0 := zs[0] as ZombieEnemy
	var head := z0.global_position + Vector3.UP * 1.65
	var r := z0.hit_by_bullet(head, frente, WeaponDB.get_def(&"m107"), 1.0, p)
	var z1 := zs[1] as ZombieEnemy
	z1.hit_by_explosion(z1.max_health, z1.global_position - frente * 1.5, p)
	for i in 20:
		await get_tree().physics_frame
	await _shot("01_impacto")
	for i in 70:
		await get_tree().physics_frame
	await _shot("02_depois")
	var ocultos0: int = (z0._desmembrar.ocultos as PackedInt32Array).size() if z0._desmembrar else -1
	var ocultos1: int = (z1._desmembrar.ocultos as PackedInt32Array).size() if z1._desmembrar else -1
	var pedacos := 0
	for n in zd.get_children():
		if n is RigidBody3D:
			pedacos += 1
	print("PEDACOS tiro=%s cabeca_oculta=%d explosao_membros=%d pedacos_no_mundo=%d" % [str(r), ocultos0, ocultos1, pedacos])
	if ocultos0 < 1 or ocultos1 < 1 or pedacos < 5:
		falhas += 1
	print("PEDACOS_RESULT falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)
