extends Node
## ANDAR PELO MUNDO REAL: o Soldier real (input de teclado) anda de sprint por todos os POIs da ilha em várias direções.
## A cada quadro de física confere se a cápsula do jogador está DENTRO de geometria sólida (camada 1) = atravessou.
## Mostra os piores infratores (nome do corpo/nó pai) e a posição. Prova de "atravessar props/cercas/muros".
## Uso: godot --path game res://tests/andar_mundo.tscn [-- --seg=5 --dirs=8]   -> ANDAR_MUNDO_OK / FALHOU
var m: BRMatch
var s: Soldier
var cap := CapsuleShape3D.new()
var infracoes: Dictionary = {}     # chave "colisor" -> [quadros, exemplo pos]
var total_quadros := 0
var quadros_dentro := 0
var mantle_quadros := 0


func _ready() -> void:
	get_tree().create_timer(800.0).timeout.connect(func() -> void: print("ANDAR_MUNDO_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	while m.ilha.terrain.get_node_or_null("TerrenoColisao") == null:
		await get_tree().process_frame
	s = m.local_player
	s.godmode = true
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	cap.radius = 0.30
	cap.height = 1.5
	var seg := float(Game.test_args.get("seg", 5.0))
	var ndir := int(Game.test_args.get("dirs", 8))
	var layout: Dictionary = m.ilha.layout
	var pois: Array = layout.pois
	for poi in pois:
		var c: Array = poi.centro
		var raio := float(poi.get("raio_m", 40.0))
		for k in ndir:
			var ang := TAU * float(k) / float(ndir)
			var off := Vector3(cos(ang), 0, sin(ang)) * raio * 0.5
			var x := float(c[0]) + off.x
			var z := -float(c[1]) + off.z
			var y: float = m.ilha.terrain.height_world(x, z)
			if y < 1.0:
				continue
			s.global_position = Vector3(x, y + 0.15, z)
			s.velocity = Vector3.ZERO
			s.yaw = ang + PI * 0.5 + float(k) * 0.7
			s.reset_physics_interpolation()
			await _f(8)
			Input.action_press("move_forward")
			Input.action_press("sprint")
			var t_fim := Time.get_ticks_msec() + int(seg * 1000.0)
			while Time.get_ticks_msec() < t_fim:
				await get_tree().physics_frame
				_conferir(String(poi.id))
			Input.action_release("move_forward")
			Input.action_release("sprint")
		print("POI %-22s ok  dentro=%d/%d" % [poi.id, quadros_dentro, total_quadros])
	var lista := infracoes.keys()
	lista.sort_custom(func(a, b) -> bool: return infracoes[a][0] > infracoes[b][0])
	for k in lista.slice(0, 15):
		print("INFRACAO ", k, " quadros=", infracoes[k][0], " ex=", infracoes[k][1])
	print("QUADROS total=%d dentro=%d (%.3f%%) em_mantle=%d" % [total_quadros, quadros_dentro, 100.0 * quadros_dentro / maxf(1.0, total_quadros), mantle_quadros])
	print("ANDAR_MUNDO_OK" if quadros_dentro == 0 else "ANDAR_MUNDO_FALHOU")
	get_tree().quit(0 if quadros_dentro == 0 else 1)


func _conferir(poi: String) -> void:
	total_quadros += 1
	var ps := PhysicsShapeQueryParameters3D.new()
	ps.shape = cap
	ps.transform = Transform3D(Basis(), s.global_position + Vector3(0, 0.95, 0))
	ps.collision_mask = 1
	ps.exclude = [s.get_rid()]
	var r := s.get_world_3d().direct_space_state.intersect_shape(ps, 6)
	if r.is_empty():
		return
	quadros_dentro += 1
	if s._mantle_on:
		mantle_quadros += 1
	for h in r:
		var col: Object = h.collider
		var nome := "?"
		if col is Node:
			var n: Node = col
			nome = "%s/%s/%s" % [n.get_parent().get_parent().name if n.get_parent() and n.get_parent().get_parent() else "", n.get_parent().name if n.get_parent() else "", n.name]
		var chave := "%s | %s" % [poi, nome]
		if not infracoes.has(chave):
			infracoes[chave] = [0, s.global_position.snapped(Vector3(0.1, 0.1, 0.1))]
		infracoes[chave][0] += 1


func _f(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
