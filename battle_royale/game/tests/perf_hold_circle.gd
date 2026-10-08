extends Node
## Perf: HoldCircle.mostrar() só pede redesenho quando progresso/texto/visibilidade mudam.
## Uso: godot --path battle_royale/game res://tests/perf_hold_circle.tscn


func _ready() -> void:
	var hc := HoldCircle.new()
	add_child(hc)
	await get_tree().process_frame
	hc.mostrar(0.0, "")
	var base := hc.redibujos
	for i in 50:
		hc.mostrar(0.0, "")
	assert(hc.redibujos == base, "oculto e parado: nenhum redesenho")
	hc.mostrar(0.4, "Abrindo")
	assert(hc.redibujos == base + 1 and hc.visible, "mudança de progresso/texto redesenha uma vez")
	hc.mostrar(0.4, "Abrindo")
	assert(hc.redibujos == base + 1, "mesmos valores: sem redesenho")
	hc.mostrar(0.0, "")
	assert(not hc.visible and hc.redibujos == base + 2, "ao ocultar redesenha uma vez")
	print("PERF_HOLD_CIRCLE_OK redibujos=", hc.redibujos)
	get_tree().quit()
