extends Node
## Capturas em 1ª pessoa (trilha F/G): AK-47 e Mosin de quadril, correndo, mirando (ADS), atirando e recarregando.
## Compara com docs/ref/ak47_fps.jpg e docs/ref/mosin_lowpoly.png. Args: --weapons=ak47,mosin --out=<pasta>

var OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/fp_soldado"

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		push_error("FP_CAPTURE_TIMEOUT")
		get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	OUT = Game.test_args.get("out", OUT)
	DirAccess.make_dir_recursive_absolute(OUT)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null:
		await get_tree().process_frame
	var pc := m.local_player.controller as PlayerController
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var ws: PackedStringArray = String(Game.test_args.get("weapons", "ak47,mosin")).split(",")
	for w in ws:
		m.br_bag.add_item(w, 1, Vector2i(-1, -1), {"mag": 30 if w == "ak47" else 5})
		var uid := -1
		for item in m.br_bag.items:
			if String(item.id) == w:
				uid = int(item.uid)
		m._equip_br_weapon(uid)
		await _frames(45)
		await _cap("%s_01_quadril" % w)
		m.local_player.in_move = Vector2(0, 1)
		await _frames(40)
		await _cap("%s_02_correndo" % w)
		m.local_player.in_move = Vector2.ZERO
		await _frames(25)
		Input.action_press("alt_fire")
		var dl := Time.get_ticks_msec() + 6000
		while pc._ads_amount < 0.95 and Time.get_ticks_msec() < dl:
			await get_tree().process_frame
		await _frames(10)
		var br := pc.viewmodel.scene_root.find_child("BracosSoldado", true, false) as MeshInstance3D
		if br:
			for si in br.mesh.get_surface_count():
				var sm := br.get_surface_override_material(si) as ShaderMaterial
				print("SURF ", si, " tex=", sm.get_shader_parameter("albedo_tex"), " col=", sm.get_shader_parameter("albedo_color"))
				var bm := br.mesh.surface_get_material(si) as BaseMaterial3D
				print("  base ", bm.resource_name, " ", bm.albedo_texture)
		await _cap("%s_03_ads" % w)
		Input.action_press("fire")
		await _frames(3)
		await _cap("%s_04_tiro" % w)
		Input.action_release("fire")
		Input.action_release("alt_fire")
		await _frames(30)
		m.local_player.start_reload()
		await _frames(28)
		await _cap("%s_05_recarga" % w)
		await _frames(150)
	print("FP_CAPTURE_OK")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _cap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT.path_join(name + ".png"))

func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		extra = " vis=%s mats=%s" % [mi.visible, [mi.get_surface_override_material(0), mi.get_surface_override_material(1)]]
		if mi.mesh: extra += " surfs=%d" % mi.mesh.get_surface_count()
	print("  ".repeat(d), n.name, " ", n.get_class(), extra)
	if d < 4:
		for c in n.get_children(): _dump(c, d + 1)
