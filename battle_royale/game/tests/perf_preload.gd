extends Node
## Perf: recursos preloadados (rig e variantes de zumbi, explosão). Uso: godot --path battle_royale/game res://tests/perf_preload.tscn


func _ready() -> void:
	assert(ZombieEnemy.ANIMATION_SCENE_RES is PackedScene, "rig de animação preloadado")
	assert(ZombieEnemy.POLYART_SCENES.size() == ZombieEnemy.POLYART_VARIANTS.size(), "todas as variantes preloadadas")
	assert(ZombieEnemy.POLYART_SCENES[3] is PackedScene, "variante preloadada é cena")
	var ex = load("res://fx/explosion.gd").new()
	add_child(ex)
	await get_tree().process_frame
	assert(ex._light != null, "explosão cria a luz")
	ex.queue_free()
	print("PERF_PRELOAD_OK variantes=", ZombieEnemy.POLYART_SCENES.size())
	get_tree().quit()
