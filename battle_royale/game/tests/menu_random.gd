extends Node
## Captura o menu inicial 2x para conferir o sobrevivente aleatório do pack novo.
func _ready() -> void:
	for i in 2:
		var mm: Node = load("res://ui/main_menu.tscn").instantiate()
		add_child(mm)
		for _q in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/menu/menu_random_%d.png" % i)
		mm.queue_free()
		await get_tree().process_frame
	get_tree().quit()
