extends Node
## Alcançabilidade dentro da casa do pacote: abre a porta, enche a pegada de uma grade de 0,25 m e testa, com a cápsula do jogador
## (r 0,3 / h 1,7) no espaço de física real, quais células cabem e quais são alcançadas a pé desde fora da porta (BFS 8 vizinhos).
## Imprime o mapa ASCII (# bloqueado, . alcançável, o livre mas inalcançável, S saída) e FALHA se houver cômodo inteiro inalcançável.
## Uso: -- [--n=0]
const PASSO := 0.25
func _ready() -> void:
	Game.test_mode = true
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var corpo := m.ilha.find_child("CasaPacote_%s" % Game.test_args.get("n", "0"), true, false) as Node3D
	assert(corpo != null)
	if Game.test_args.has("sem_moveis"):
		for c in corpo.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
				c.queue_free()
	var porta := corpo.get_node("PortaFrente") as PortaCasa
	porta.alternar()
	await get_tree().create_timer(0.8).timeout
	var espaco := corpo.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Soldier.LAYER_WORLD
	var x0 := -7.0
	var z0 := -7.4
	var nx := int(14.0 / PASSO)
	var nz := int(14.8 / PASSO)
	var livre := []
	for iz in nz:
		var linha := []
		for ix in nx:
			var lp := Vector3(x0 + ix * PASSO, 0.08 + 0.95 + 0.05, z0 + iz * PASSO)
			q.transform = Transform3D(Basis(), corpo.to_global(lp))
			linha.append(espaco.intersect_shape(q, 1).is_empty())
		livre.append(linha)
	var ini := Vector2i(int((-2.05 - x0) / PASSO), int((6.9 - z0) / PASSO))   # fora, diante da porta
	var vis := {}
	var fila: Array[Vector2i] = [ini]
	vis[ini] = true
	while not fila.is_empty():
		var c: Vector2i = fila.pop_front()
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n := Vector2i(c.x + dx, c.y + dz)
				if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz or vis.has(n) or not livre[n.y][n.x]:
					continue
				vis[n] = true
				fila.append(n)
	var texto := ""
	var inalc := 0
	for iz in nz:
		var linha := ""
		for ix in nx:
			var c := Vector2i(ix, iz)
			if c == ini:
				linha += "S"
			elif not livre[iz][ix]:
				linha += "#"
			elif vis.has(c):
				linha += "."
			else:
				linha += "o"
				if ix > 0 and ix < nx - 1:
					inalc += 1
		texto += linha + "\n"
	print("ALCANCE_MAPA (x -7..7 colunas; z -7.4..7.4 linhas, norte=cima=-z)")
	print(texto)
	var f := FileAccess.open(ProjectSettings.globalize_path("res://raw/casa_grade%s.txt" % ("_livre" if Game.test_args.has("sem_moveis") else "")), FileAccess.WRITE)
	f.store_string("%d %d %f %f %f
%s" % [nx, nz, x0, z0, PASSO, texto])
	f.close()
	print("ALCANCE inalcancaveis_dentro=%d células (%.1f m2)" % [inalc, inalc * PASSO * PASSO])
	# PASS/FAIL: não piorar a referência (95 células = frestas atrás de móveis, nenhum cômodo isolado) e as 3 saídas alcançáveis
	var limite := int(Game.test_args.get("max_inalc", "95"))
	var saidas := {"frente": Vector2(-2.05, 5.8), "cozinha": Vector2(-2.5, -3.5), "leste": Vector2(5.5, -0.7)}
	var falhas: Array = []
	for nome in saidas:
		var sp: Vector2 = saidas[nome]
		var ok_s := false
		var cx := int((sp.x - x0) / PASSO)
		var cz := int((sp.y - z0) / PASSO)
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				if vis.has(Vector2i(cx + dx, cz + dz)):
					ok_s = true
		if not ok_s:
			falhas.append("saida_" + nome)
	if Game.test_args.has("sem_moveis") == false and inalc > limite:
		falhas.append("inalcancaveis %d > %d" % [inalc, limite])
	print("ALCANCE_RESULTADO %s %s" % ["PASS" if falhas.is_empty() else "FAIL", JSON.stringify(falhas)])
	get_tree().quit(0 if falhas.is_empty() else 1)
