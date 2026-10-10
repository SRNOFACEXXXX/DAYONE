extends Control
## Folha de ícones de TODOS os itens do jogo (inventário): miniaturas renderizadas dos .glb + ícones de código, na grade como
## no inventário. Lista os que ficaram sem miniatura própria. --out=<pasta>
var _ids: Array = []


func _ready() -> void:
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ids = BRInventory.todos_ids()
	_ids.sort()
	ItemIcons.request()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(1.0).timeout
		var falta := 0
		for id in _ids:
			var p := String(BRInventory.definition(String(id)).get("model_path", ""))
			if p.begins_with(ItemIcons.DIR_MODELOS) and not ItemIcons.textures.has(id):
				falta += 1
		if falta <= 4 and ItemIcons.textures.size() > 12:
			break
	var sem := []
	for id in _ids:
		if not ItemIcons.textures.has(id):
			sem.append(id)
	print("ICONES total=%d miniaturas=%d sem_miniatura=%s" % [_ids.size(), ItemIcons.textures.size(), str(sem)])
	queue_redraw()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	get_viewport().get_texture().get_image().save_png(out.path_join("icones.png"))
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.13))
	var cols := 9
	var w := 138.0
	var h := 96.0
	var f := ThemeDB.fallback_font
	for i in _ids.size():
		var r := Rect2(8 + (i % cols) * w, 8 + (i / cols) * h, w - 6, h - 6)
		draw_rect(r, Color(0.2, 0.2, 0.21))
		ItemIcons.draw(self, String(_ids[i]), Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y - 22)))
		draw_string(f, r.position + Vector2(4, r.size.y - 6), String(_ids[i]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 12, Color.WHITE)
