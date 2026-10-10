extends Node
## Perf: sombra do sol com 50 m (antes 70 m) e fade de 0,8. Uso: godot --path battle_royale/game res://tests/perf_sombra_sol.tscn


func _ready() -> void:
	Game.test_mode = true
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	var sol: DirectionalLight3D = null
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		sol = n
		break
	assert(sol != null, "sol da ilha existe")
	assert(is_equal_approx(sol.directional_shadow_max_distance, 50.0), "distância da sombra deve ser 50 m")
	assert(is_equal_approx(sol.directional_shadow_fade_start, 0.8), "fade da sombra deve começar em 0,8")
	print("PERF_SOMBRA_SOL_OK dist=", sol.directional_shadow_max_distance)
	get_tree().quit()
