extends Node
## Perf: o alvo de porta do HUD (BRMatch._porta_alvo_hint, reavaliado a cada 0,1 s) devolve a mesma porta
## que a consulta direta (_porta_alvo). Uso: godot --path battle_royale/game res://tests/perf_hud_cache.tscn


func _ready() -> void:
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	for i in 30:
		await get_tree().process_frame
	var divergencias := 0
	for i in 20:
		m.clock += 0.11   # passa da janela de 0,1 s: cada chamada reavalia
		if m._porta_alvo() != m._porta_alvo_hint():
			divergencias += 1
	assert(divergencias == 0, "o HUD deve mostrar a mesma porta que a consulta direta")
	m.clock += 0.11
	var primeira: PortaCasa = m._porta_alvo_hint()
	var segunda: PortaCasa = m._porta_alvo_hint()
	assert(primeira == segunda, "dentro da janela de 0,1 s o HUD reaproveita a porta guardada")
	print("PERF_HUD_CACHE_OK divergencias=", divergencias)
	get_tree().quit()
