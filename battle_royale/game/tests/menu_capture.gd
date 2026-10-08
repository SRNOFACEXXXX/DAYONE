extends Node
## Gate visual do menu e do painel de configurações em Compatibility.
## Args: --out=pasta  --w=1024 --h=768  --inv=1 (captura também o inventário em jogo sobre o diorama)

var out := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/menu_review"

func _ready() -> void:
	Game.test_mode = true
	var a := Game.test_args
	out = String(a.get("out", out))
	DirAccess.make_dir_recursive_absolute(out)
	var w := int(a.get("w", 1024))
	var h := int(a.get("h", 768))
	DisplayServer.window_set_size(Vector2i(w, h))
	get_window().size = Vector2i(w, h)
	get_tree().create_timer(120.0).timeout.connect(func() -> void: get_tree().quit(2))
	await _frames(3)
	if a.has("icons"):
		ItemIcons.request()
		await _frames(60)
		for id: String in ItemIcons.textures:
			var img: Image = ItemIcons.textures[id].get_image()
			img.save_png(out.path_join("icon_%s.png" % id))
		get_tree().quit()
		return
	if a.has("qb"):
		var back2 := MenuStage.new(true, 0.0)
		add_child(back2)
		var hud_script: GDScript = load("res://ui/hud.gd")
		var qb: Control = hud_script.Quickbar.new()
		qb.soldier = Soldier.new()
		qb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		qb.offset_left = -220
		qb.offset_right = 220
		qb.offset_top = -84
		qb.offset_bottom = -16
		add_child(qb)
		await _frames(50)
		await _capture("04_quickbar_%dx%d" % [w, h])
		get_tree().quit()
		return
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)
	await _frames(40)
	await _capture("01_menu_%dx%d" % [w, h])
	# FPS do menu (3 s)
	var t0 := Time.get_ticks_msec()
	var n := 0
	while Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
		n += 1
	print("MENU_FPS %.1f (%dx%d)" % [n / 3.0, w, h])
	menu._show_settings()
	await _frames(3)
	assert(menu.get_node("Configuracoes").visible, "configurações devem abrir sobre o menu")
	await _capture("02_configuracoes_%dx%d" % [w, h])
	menu._hide_settings()
	assert(not menu.get_node("Configuracoes").visible, "voltar deve fechar as configurações")
	print("MENU_CAPTURE_OK settings_open_close=true")
	if a.has("inv"):
		menu.queue_free()
		await _frames(2)
		var back := MenuStage.new(true, 0.0)
		add_child(back)
		back.soldier.visible = false
		var player := BRInventory.new()
		player.add_item("backpack_medium")
		player.equip_backpack(player.items[0].uid)
		player.add_item("ak47", 1, Vector2i(-1, -1), {"mag": 30, "acog": false})
		player.add_item("mosin", 1, Vector2i(-1, -1), {"mag": 5})
		player.add_item("ammo_762", 75)
		player.add_item("ammo_9mm", 30)
		player.add_item("acog")
		player.add_item("vest")
		player.add_item("grenade", 2)
		var loot := BRInventory.make_loot_container(4)
		loot.add_item("m4", 1, Vector2i(-1, -1), {"mag": 12})
		loot.add_item("ammo_556", 40)
		loot.add_item("grenade", 1)
		loot.add_item("glock", 1, Vector2i(-1, -1), {"mag": 8})
		loot.add_item("backpack_small")
		var ui := (load("res://ui/br_inventory_ui.tscn") as PackedScene).instantiate() as BRInventoryUI
		add_child(ui)
		ui.open(player, loot)
		await _frames(50)
		await _capture("03_inventario_%dx%d" % [w, h])
		t0 = Time.get_ticks_msec()
		n = 0
		while Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
			n += 1
		print("INV_FPS %.1f (%dx%d)" % [n / 3.0, w, h])
	get_tree().quit()

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	assert(err == OK, "falha ao salvar captura " + name)
