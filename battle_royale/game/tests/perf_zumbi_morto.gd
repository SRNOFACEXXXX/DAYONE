extends Node3D
## Perf: zumbi morto para a física depois do clipe de morte (antes rodava _physics_process todo quadro para sempre).
## Uso: godot --path battle_royale/game res://tests/perf_zumbi_morto.tscn

const LIMITE_FRAMES := 900


func _ready() -> void:
	Game.test_mode = true
	var z := load("res://core/zombie.tscn").instantiate() as ZombieEnemy
	add_child(z)
	await get_tree().process_frame
	assert(z.is_physics_processing(), "zumbi vivo deve processar física")
	z.receive_damage(9999)
	assert(z.state == ZombieEnemy.State.DEAD, "zumbi com vida zero deve morrer")
	var frames := 0
	while z.is_physics_processing() and frames < LIMITE_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert(not z.is_physics_processing(), "corpo deve parar a física depois do clipe de morte")
	assert(z._death_finished, "fim do clipe de morte deve estar marcado")
	print("PERF_ZUMBI_MORTO_OK frames_ate_parar=", frames)
	get_tree().quit()
