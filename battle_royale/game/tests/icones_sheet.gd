extends Node
## Renderiza os ícones de todos os itens do inventário, salva PNGs e uma folha; escreve JSON de triagem.
func _ready() -> void:
	Game.test_mode = true
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	ItemIcons.request()
	var done := [false]
	ItemIcons.when_ready(func(): done[0] = true)
	var t := 0
	while not done[0] and t < 600:
		await get_tree().process_frame
		t += 1
	var ids: Array = BRInventory.DEFINITIONS.keys()
	var tri := []
	var sheet := Image.create(ItemIcons.ICON_SIZE.x * 4, ItemIcons.ICON_SIZE.y * ceili(ids.size() / 4.0), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.13, 0.12))
	var i := 0
	for id: String in ids:
		var tex := ItemIcons.texture_for(id)
		tri.append({"item": id, "tem_png": tex != null})
		if tex != null:
			var img := tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png(out.path_join("icone_%s.png" % id))
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 4) * ItemIcons.ICON_SIZE.x, (i / 4) * ItemIcons.ICON_SIZE.y))
		i += 1
	sheet.save_png(out.path_join("folha_icones.png"))
	var f := FileAccess.open(out.path_join("tri.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(tri, "  "))
	f.close()
	print("ICONES ok ", tri.size())
	get_tree().quit()
