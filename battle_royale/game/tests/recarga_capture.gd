extends Node
## Captura quadros da recarga (mão de apoio indo ao carregador): -- --arma=ak47 
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/recarga"


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	DirAccess.make_dir_recursive_absolute(OUT)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	var arma: String = Game.test_args.get("arma", "ak47")
	m.br_bag.add_item("backpack_medium")
	m.br_bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": 10})
	m.br_bag.add_item("ammo_762", 90)
	m.br_bag.add_item("ammo_556", 90)
	m.br_bag.add_item("ammo_9mm", 90)
	m.br_bag.add_item("ammo_127", 30)
	var uid := -1
	for it in m.br_bag.items:
		if String(it.id) == arma:
			uid = int(it.uid)
	m._equip_br_weapon(uid)
	var pc := m.local_player.controller as PlayerController
	var hx: float = m.ilha.terrain.height_world(-345.0, 352.0)
	m.local_player.global_position = Vector3(-345.0, hx + 0.1, 352.0)
	m.local_player.yaw = deg_to_rad(40.0)
	m.local_player.pitch = 0.0
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for _i in 60:
		await get_tree().process_frame
	var def: WeaponDef = m.local_player.current_def()
	print("VM mao_e=", pc.viewmodel._mao_e, " carregador=", pc.viewmodel._carregador, " scene=", pc.viewmodel.scene_root)
	if pc.viewmodel.scene_root:
		pc.viewmodel.scene_root.print_tree_pretty()
	m.local_player.start_reload()
	var t0 := Time.get_ticks_msec() / 1000.0
	var marcas := [0.1, 0.25, 0.4, 0.55, 0.7, 0.85]
	var k := 0
	while k < marcas.size():
		await get_tree().process_frame
		var p := (Time.get_ticks_msec() / 1000.0 - t0) / def.reload_time
		if p >= marcas[k]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUT.path_join("%s_%s_%02d.png" % [arma, String(Game.test_args.get("tag", "x")), int(marcas[k] * 100)]))
			k += 1
	get_tree().quit()
