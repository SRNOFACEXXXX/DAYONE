extends Node3D
## Trilhas C/E (construções e escadas): verificações automáticas em terreno plano, sem a ilha inteira.
##   --modo=portas   : cada prédio com entrada registrada em tools/_loot/<modelo>.json é atravessado por um Soldier real
##   --modo=loot     : pontos de saque internos livres (caixa 0,7x0,5x0,5), com teto acima e alcançáveis a pé desde a porta (BFS de cápsula)
##   --modo=escadas  : escadas de mão (Empties ESCADA_*) sobem e descem pelo Soldier
##   --modo=mantle   : muros, cercas e caixas (modelos reais de detalhes/cobertura) são escalados pelo Soldier
## Filtros: --modelos=a,b (nomes sem .glb)   --out=pasta (capturas com --foto)

const PREDIOS := "res://assets/models/predios/"
var modelos_filtro: PackedStringArray = []
var falhas := 0
var world: Node3D


func _ready() -> void:
	Game.test_mode = true
	var modo: String = Game.test_args.get("modo", "portas")
	if Game.test_args.has("modelos"):
		modelos_filtro = String(Game.test_args.modelos).split(",")
	_mundo()
	await get_tree().physics_frame
	match modo:
		"portas": await _portas()
		"loot": await _loot()
		"escadas": await _escadas()
		"mantle": await _mantle()
		"sonda": await _sonda()
		"lances": await _lances()
		"degrau": await _degrau()
	print("RESULTADO modo=%s falhas=%d" % [modo, falhas])
	get_tree().quit(1 if falhas > 0 else 0)


func _mundo() -> void:
	var piso := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(400, 1, 400)
	cs.shape = bs
	cs.position.y = -0.5
	piso.add_child(cs)
	add_child(piso)
	world = Node3D.new()
	add_child(world)


func _lista() -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(PREDIOS):
		if f.ends_with(".glb"):
			var n := f.get_basename()
			if modelos_filtro.is_empty() or n in modelos_filtro:
				out.append(n)
	out.sort()
	return out


func _dados(nome: String) -> Dictionary:
	var p := ProjectSettings.globalize_path("res://").path_join("../tools/_loot/%s.json" % nome)
	if not FileAccess.file_exists(p):
		return {"loot": [], "entradas": []}
	return JSON.parse_string(FileAccess.get_file_as_string(p))


## Instancia o prédio no mundo de teste com a mesma colisão do jogo (trimesh com backface).
func _predio(nome: String) -> Node3D:
	var corpo := StaticBody3D.new()
	world.add_child(corpo)
	var sc: Node3D = load(PREDIOS + nome + ".glb").instantiate()
	corpo.add_child(sc)
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var cs := CollisionShape3D.new()
		var tm := (mi as MeshInstance3D).mesh.create_trimesh_shape()
		tm.backface_collision = true
		cs.shape = tm
		corpo.add_child(cs)
		cs.global_transform = (mi as MeshInstance3D).global_transform
	EscadaVertical.instalar(corpo, sc)
	Moveis.instalar(corpo, nome)          # mesma mobília (e caixas de colisão) do jogo
	return corpo


func _soldado(pos: Vector3, yaw: float) -> Soldier:
	var s := Soldier.new()
	world.add_child(s)
	s.global_position = pos
	s.yaw = yaw
	return s


func _yaw_para(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


# ------------------------------------------------------------------ portas
func _portas() -> void:
	for nome in _lista():
		var d := _dados(nome)
		if d.entradas.is_empty():
			continue
		var corpo := _predio(nome)
		await _frames(2)
		var i := 0
		for e in d.entradas:
			i += 1
			var dir := Vector3(float(e.dx), 0, -float(e.dy)).normalized()
			var ini := Vector3(float(e.x), 0.0, -float(e.y))
			var s := _soldado(ini, _yaw_para(dir))
			await _frames(4)
			s.in_move = Vector2(0, 1)
			await _frames(110)
			var viajou := (s.global_position - ini).dot(dir)
			var ok := viajou > 2.4
			if not ok:
				falhas += 1
			print("PORTA %s #%d %s percorreu=%.2f m y=%.2f" % [nome, i, "OK" if ok else "FALHA", viajou, s.global_position.y])
			s.queue_free()
		corpo.queue_free()
		await _frames(1)


# ------------------------------------------------------------------ saque
func _caixa_livre(centro: Vector3, rot_deg: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.72, 0.46, 0.52)
	q.shape = b
	q.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), centro + Vector3(0, 0.27, 0))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _cap_livre(pos: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.34
	c.height = 1.7
	q.shape = c
	q.transform = Transform3D(Basis(), pos + Vector3(0, 0.85 + 0.06, 0))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _chao(x: float, z: float, y_ref: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y_ref + 0.36, z), Vector3(x, y_ref - 0.7, z), 1)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return h.position.y if not h.is_empty() and h.normal.y > 0.7 else NAN


## Apoio sob a cápsula: o ponto mais alto dentre o centro e 4 pontos a 0,3 m (a cápsula "sobe" num degrau como o Soldier faz).
func _chao_cap(x: float, z: float, y_ref: float) -> float:
	var melhor := NAN
	for o in [Vector2(0, 0), Vector2(0.3, 0), Vector2(-0.3, 0), Vector2(0, 0.3), Vector2(0, -0.3)]:
		var y := _chao(x + o.x, z + o.y, y_ref)
		if not is_nan(y) and (is_nan(melhor) or y > melhor):
			melhor = y
	return melhor


func _loot() -> void:
	for nome in _lista():
		var d := _dados(nome)
		if d.loot.is_empty():
			continue
		var corpo := _predio(nome)
		await _frames(2)
		# BFS 2,5D a partir da 1ª entrada, 0,25 m por célula
		var alcan := {}
		var fila: Array = []
		var cel := 0.25
		var e0: Dictionary = d.entradas[0] if not d.entradas.is_empty() else {}
		if not e0.is_empty():
			var dir := Vector3(float(e0.dx), 0, -float(e0.dy)).normalized()
			var p0 := Vector3(float(e0.x), 0, -float(e0.y)) + dir * 2.0
			var y0 := _chao(p0.x, p0.z, 0.12)
			if not is_nan(y0):
				fila.append(Vector3(p0.x, y0, p0.z))
				alcan[_chave(p0.x, p0.z, y0)] = Vector3(p0.x, y0, p0.z)
		var caixa := AABB()
		var primeiro := true
		for mi in corpo.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
			caixa = bb if primeiro else caixa.merge(bb)
			primeiro = false
		caixa = caixa.grow(0.6)
		for l in d.get("lances", []):                      # piso logo depois do último degrau (o lance é validado à parte por simulação)
			var ty := _chao(float(l.tx), -float(l.ty), float(l.z) + 0.3)
			if not is_nan(ty):
				var pv := Vector3(float(l.tx), ty, -float(l.ty))
				fila.append(pv)
				alcan[_chave(pv.x, pv.z, pv.y)] = pv
		var guarda := 0
		while not fila.is_empty() and guarda < 120000:
			guarda += 1
			var c: Vector3 = fila.pop_front()
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx == 0 and dz == 0:
						continue
					var nx: float = c.x + dx * cel
					var nz: float = c.z + dz * cel
					if nx < caixa.position.x or nx > caixa.end.x or nz < caixa.position.z or nz > caixa.end.z:
						continue
					var ny := _chao_cap(nx, nz, c.y)
					if is_nan(ny) or ny - c.y > 0.32:
						continue
					var k := _chave(nx, nz, ny)
					if alcan.has(k):
						continue
					if not _cap_livre(Vector3(nx, ny, nz)):
						continue
					alcan[k] = Vector3(nx, ny, nz)
					fila.append(Vector3(nx, ny, nz))
		var n_ok := 0
		var i := 0
		for l in d.loot:
			i += 1
			var pos := Vector3(float(l.x), float(l.y), float(l.z))
			var livre := _caixa_livre(pos, float(l.rot_deg))
			var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.6, 0), pos + Vector3(0, 16.0, 0), 1)
			var teto := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
			var chao := _chao(pos.x, pos.z, pos.y)
			var no_piso := not is_nan(chao) and absf(chao - pos.y) < 0.06
			var alcancavel := false
			for k in alcan:
				var v: Vector3 = alcan[k]
				if Vector2(v.x - pos.x, v.z - pos.z).length() < 0.75 and absf(v.y - pos.y) < 0.35:
					alcancavel = true
					break
			var ok: bool = livre and teto and no_piso and alcancavel
			if ok:
				n_ok += 1
			else:
				falhas += 1
			print("SAQUE %s #%d %s (%s) livre=%s teto=%s piso=%s alcancavel=%s pos=(%.2f,%.2f,%.2f)" % [nome, i, "OK" if ok else "FALHA", l.sala, livre, teto, no_piso, alcancavel, pos.x, pos.y, pos.z])
		var max_y := 0.0
		for k in alcan:
			max_y = maxf(max_y, (alcan[k] as Vector3).y)
		print("SAQUE_RESUMO %s pontos=%d ok=%d celulas=%d altura_max_alcancada=%.2f" % [nome, d.loot.size(), n_ok, alcan.size(), max_y])
		corpo.queue_free()
		await _frames(1)


func _chave(x: float, z: float, y: float) -> String:
	return "%d,%d,%d" % [roundi(x * 4.0), roundi(z * 4.0), roundi(y / 0.6)]


# ------------------------------------------------------------------ escadas de mão
func _escadas() -> void:
	for nome in _lista():
		var corpo := _predio(nome)
		await _frames(2)
		var escs := corpo.find_children("Escada*", "Area3D", false, false)
		for e in escs:
			var esc := e as EscadaVertical
			var base := esc.base_world()
			var topo := esc.topo_world()
			var s := _soldado(base + Vector3(0, 0.05, 0), 0.0)
			await _frames(3)
			s.escada_mais_proxima()
			var perto := s.escadas_perto.has(esc)
			s.iniciar_escada(esc)
			s.in_move = Vector2(0, 1)
			var t := 0
			while s.escada != null and t < 64 * 60:
				await get_tree().physics_frame
				t += 1
			var dist_topo := Vector2(s.global_position.x - topo.x, s.global_position.z - topo.z).length()
			var subiu: bool = s.escada == null and absf(s.global_position.y - topo.y) < 0.15 and dist_topo < 0.3
			await _frames(6)
			var em_pe := s.is_on_floor() and absf(s.global_position.y - topo.y) < 0.2
			# desce
			s.iniciar_escada(esc)
			s.in_move = Vector2(0, -1)
			var t2 := 0
			while s.escada != null and t2 < 64 * 60:
				await get_tree().physics_frame
				t2 += 1
			var desceu: bool = s.escada == null and absf(s.global_position.y - base.y) < 0.2
			var ok: bool = perto and subiu and em_pe and desceu
			if not ok:
				falhas += 1
			print("ESCADA %s %s %s area=%s subiu=%s(%.1fs) em_pe=%s desceu=%s altura=%.1f m" % [nome, esc.name, "OK" if ok else "FALHA", perto, subiu, t / 64.0, em_pe, desceu, topo.y - base.y])
			s.queue_free()
		corpo.queue_free()
		await _frames(1)


# ------------------------------------------------------------------ escalar
func _mantle() -> void:
	var casos := [
		["muro_baixo", "res://assets/models/detalhes/muro_baixo.glb", 1.28, true],
		["cerca_madeira", "res://assets/models/detalhes/cerca_madeira.glb", 1.3, true],
		["cerca_arame", "res://assets/models/detalhes/cerca_arame.glb", 1.4, true],
		["muro_alto", "res://assets/models/detalhes/muro_alto.glb", 2.3, false],
		["mureta_concreto", "res://assets/models/cobertura/mureta_concreto.glb", 0.0, true],
		["sacos_areia", "res://assets/models/cobertura/sacos_areia.glb", 0.0, true],
		["tambor_x4", "res://assets/models/cobertura/tambor_x4.glb", 0.0, true],
		["caixote", "", 0.9, true],
		["caixote_alto", "", 1.6, true],
	]
	for c in casos:
		var corpo := StaticBody3D.new()
		world.add_child(corpo)
		if String(c[1]) == "":
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.5, float(c[2]), 1.2)
			cs.shape = bs
			cs.position = Vector3(1.5, float(c[2]) * 0.5, 0)
			corpo.add_child(cs)
		else:
			var sc: Node3D = load(String(c[1])).instantiate()
			corpo.add_child(sc)
			sc.rotation.y = PI / 2.0              # comprimento do modelo (+X local) passa a correr ao longo de Z
			sc.position = Vector3(1.5, 0, 1.5)
			for mi in sc.find_children("*", "MeshInstance3D", true, false):
				var cs := CollisionShape3D.new()
				var tm := (mi as MeshInstance3D).mesh.create_trimesh_shape()
				tm.backface_collision = true
				cs.shape = tm
				corpo.add_child(cs)
				cs.global_transform = (mi as MeshInstance3D).global_transform
		await _frames(2)
		# aproxima-se da origem +X por cima, pressiona pular e andar para a frente (yaw que olha para +X)
		var s := _soldado(Vector3(-1.0, 0.0, 0.0), _yaw_para(Vector3.RIGHT))
		await _frames(4)
		s.in_move = Vector2(0, 1)
		var passou := false
		var subiu_em_cima := false
		var max_y := 0.0
		for f in 64 * 5:
			await get_tree().physics_frame
			s.in_jump = f > 20 and f % 64 < 40
			max_y = maxf(max_y, s.global_position.y)
			if s.global_position.x > 2.6 and s.is_on_floor():
				passou = true
				break
			if s.global_position.x > 1.0 and s.global_position.y > 0.4 and s.is_on_floor() and s.velocity.length() < 3.0 and f > 200:
				subiu_em_cima = true
				passou = true
				break
		var esperado: bool = c[3]
		var ok := passou == esperado
		if not ok:
			falhas += 1
		print("MANTLE %s %s passou=%s em_cima=%s altura_max=%.2f x=%.2f (esperado passar=%s)" % [c[0], "OK" if ok else "FALHA", passou, subiu_em_cima, max_y, s.global_position.x, esperado])
		s.queue_free()
		corpo.queue_free()
		await _frames(1)


## Depuração: dispara raios horizontais a partir de cada entrada e diz onde batem (alturas 0,3..2,0 m).
func _sonda() -> void:
	for nome in _lista():
		var d := _dados(nome)
		var corpo := _predio(nome)
		await _frames(2)
		for e in d.entradas:
			var dir := Vector3(float(e.dx), 0, -float(e.dy)).normalized()
			var ini := Vector3(float(e.x), 0.0, -float(e.y))
			for h in [0.2, 0.5, 0.9, 1.3, 1.7, 2.0]:
				var q := PhysicsRayQueryParameters3D.create(ini + Vector3(0, h, 0), ini + Vector3(0, h, 0) + dir * 6.0, 1)
				var hit := get_world_3d().direct_space_state.intersect_ray(q)
				print("SONDA %s h=%.1f -> %s" % [nome, h, ("%.2f m em %s" % [(hit.position - ini).dot(dir), hit.position]) if not hit.is_empty() else "livre"])
		corpo.queue_free()
		await _frames(1)


## Depuração: testa cápsula e apoio em pontos dados (--pontos=x,y,z;x,y,z em coordenadas locais Godot).
func _degrau() -> void:
	var corpo := _predio(_lista()[0])
	await _frames(2)
	for ptxt in String(Game.test_args.get("pontos", "")).split(";"):
		var v := ptxt.split(",")
		var x := float(v[0])
		var z := float(v[2])
		var y := float(v[1])
		print("DEGRAU (%.2f, %.2f, %.2f) chao=%.2f chao_cap=%.2f cap_livre=%s" % [x, y, z, _chao(x, z, y), _chao_cap(x, z, y), _cap_livre(Vector3(x, y, z))])
	corpo.queue_free()


## Lances de escada (degraus) percorridos por um Soldier real: parte do pé, anda para a frente e deve chegar ao topo.
func _lances() -> void:
	for nome in _lista():
		var d := _dados(nome)
		if d.get("lances", []).is_empty():
			continue
		var corpo := _predio(nome)
		await _frames(2)
		var i := 0
		for l in d.lances:
			i += 1
			var dir := Vector3(float(l.dx), 0, -float(l.dy)).normalized()
			var ini := Vector3(float(l.x), 0.0, -float(l.y))
			var gy := _chao(ini.x, ini.z, 1.0)
			var s := _soldado(Vector3(ini.x, 0.0 if is_nan(gy) else gy, ini.z), _yaw_para(dir))
			await _frames(6)
			s.in_move = Vector2(0, 1)
			var max_y := 0.0
			for f in 64 * 8:
				await get_tree().physics_frame
				max_y = maxf(max_y, s.global_position.y)
				if Game.test_args.has("trace") and f % 16 == 0:
					print("  trace f=%d pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) piso=%s" % [f, s.global_position.x, s.global_position.y, s.global_position.z, s.velocity.x, s.velocity.y, s.velocity.z, s.is_on_floor()])
				if s.global_position.y >= float(l.z) - 0.1 and s.is_on_floor():
					break
			if Game.test_args.has("trace"):
				var col := KinematicCollision3D.new()
				var t0 := s.global_transform
				print("  frente livre? ", not s.test_move(t0, dir * 0.2, col), " normal=", col.get_normal() if col.get_collision_count() > 0 else "-", " pos=", col.get_position() if col.get_collision_count() > 0 else "-")
				print("  subir 0.46 livre? ", not s.test_move(t0, Vector3(0, 0.46, 0)))
				var cu := KinematicCollision3D.new()
				s.test_move(t0, Vector3(0, 0.46, 0), cu)
				print("  teto: normal=", cu.get_normal() if cu.get_collision_count() > 0 else "-", " pos=", cu.get_position() if cu.get_collision_count() > 0 else "-", " travel=", cu.get_travel())
				for ys in [0.3, 1.0, 1.6, 2.2, 2.8, 3.4, 4.5]:
					var q := PhysicsRayQueryParameters3D.create(Vector3(s.global_position.x, ys + 2.0, s.global_position.z), Vector3(s.global_position.x, ys - 0.4, s.global_position.z), 1)
					var hh := s.get_world_3d().direct_space_state.intersect_ray(q)
					print("   raio de y=%.1f -> %s" % [ys + 2.0, ("%.2f n=%s" % [hh.position.y, hh.normal]) if not hh.is_empty() else "nada"])
				var t1 := t0.translated(Vector3(0, 0.46, 0))
				print("  frente a 0.46 livre? ", not s.test_move(t1, dir * 0.2, col), " normal=", col.get_normal() if col.get_collision_count() > 0 else "-", " pos=", col.get_position() if col.get_collision_count() > 0 else "-")
			var ok: bool = s.global_position.y >= float(l.z) - 0.12
			if not ok:
				falhas += 1
			print("LANCE %s #%d %s chegou a y=%.2f (alvo %.2f, máx %.2f) em %.1f s" % [nome, i, "OK" if ok else "FALHA", s.global_position.y, float(l.z), max_y, s.t])
			s.queue_free()
		corpo.queue_free()
		await _frames(1)
