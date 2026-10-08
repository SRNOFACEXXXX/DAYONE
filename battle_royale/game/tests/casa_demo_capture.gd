extends Node
## Captura a casa completa do pacote (primeira de casas_pacote.json): fora (3 ângulos) e dentro (cozinha, quarto, sala).
## Uso: -- --out=raw/casa_demo [--n=0]
var out := ""
func _ready() -> void:
	Game.test_mode = true
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	var corpo := m.ilha.find_child("CasaPacote_%s" % Game.test_args.get("n", "0"), true, false) as Node3D
	assert(corpo != null, "casa do pacote não encontrada")
	var pc := s.controller as PlayerController
	pc._prefer_third_person = false
	pc._set_third_person(false)
	# [nome, posição local (x,z), yaw local em graus (0 = olhando -Z da casa)]
	var porta := corpo.get_node_or_null("PortaFrente") as PortaCasa
	for v in [["porta_fechada", Vector2(-2.0, 8.2), 0.0], ["porta_aberta", Vector2(-2.0, 8.2), 0.0],
			["corredor", Vector2(-2.0, 4.6), 0.0], ["quarto_ne", Vector2(0.4, -2.6), 0.0], ["sala", Vector2(-0.4, -0.7), -75.0],
			["quarto_se", Vector2(2.2, 0.8), 180.0], ["cozinha", Vector2(-2.0, 0.6), 90.0], ["fora_frente", Vector2(-1.0, 16.0), 0.0],
			["saida_norte", Vector2(-2.4, -1.0), 0.0], ["saida_leste_a", Vector2(3.0, -0.7), -90.0], ["saida_leste_b", Vector2(3.0, -0.7), 90.0]]:
		if v[0] == "saida_norte":
			for nm in ["PortaCozinha", "PortaLeste"]:
				(corpo.get_node(nm) as PortaCasa).alternar()
			await get_tree().create_timer(0.7).timeout
		if v[0] == "porta_aberta" and porta:
			porta.alternar()
			await get_tree().create_timer(0.7).timeout
		var loc: Vector2 = v[1]
		var gp := corpo.to_global(Vector3(loc.x, 0.1, loc.y))
		var h: float = m.ilha.terrain.height_world(gp.x, gp.z)
		s.global_position = Vector3(gp.x, maxf(gp.y, h) + 0.1, gp.z)
		s.velocity = Vector3.ZERO
		s.yaw = corpo.rotation.y + deg_to_rad(float(v[2]))
		s.pitch = deg_to_rad(-4.0)
		s.reset_physics_interpolation()
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
	get_tree().quit()
