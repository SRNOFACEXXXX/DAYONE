extends Node
func _ready() -> void:
	var m: Node = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	for i in 240:
		await get_tree().process_frame
	var p: String = Rastreio.gravar()
	print("RASTREIO_OK ", ProjectSettings.globalize_path(p), " itens=", Rastreio.ultimo.size())
	get_tree().quit()
