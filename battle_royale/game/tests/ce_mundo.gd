extends Node
## Trilhas C/E no mapa real (terreno + prédios como no jogo).
##   --modo=portas : cada entrada registrada (tools/_loot/*.json) de cada prédio do layout é atravessada por um Soldier real
##   --modo=fotos  : capturas de dentro das construções (lista FOTOS abaixo; --only=a,b --out=pasta)
##   --modo=mantle : um Soldier tenta escalar as cercas/muros colocados no mapa (amostras em detalhes.json)

const FOTOS := [
	# nome, id do prédio, câmera local (x, y, z Godot local), alvo local
	["laje_sala", "morro_cruzeiro_01", Vector3(2.2, 1.6, 3.0), Vector3(-1.0, 0.9, -1.0)],
	["laje_cozinha", "morro_cruzeiro_01", Vector3(0.6, 1.7, 0.9), Vector3(1.8, 0.9, -3.0)],
	["laje_quarto", "morro_cruzeiro_01", Vector3(-1.0, 1.7, -0.3), Vector3(-2.2, 0.8, -2.6)],
]

var scene: Node3D
var falhas := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1024, 768))
	scene = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	await get_tree().process_frame
	var ex: Node3D = scene.get_node("Explorador")
	ex.set_physics_process(false)
	var modo: String = Game.test_args.get("modo", "portas")
	match modo:
		"portas": await _portas()
		"fotos": await _fotos(ex)
		"mantle": await _mantle()
		"escada": await _escada_foto(ex)
	print("RESULTADO modo=%s falhas=%d" % [modo, falhas])
	get_tree().quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _dados(nome: String) -> Dictionary:
	var p := ProjectSettings.globalize_path("res://").path_join("../tools/_loot/%s.json" % nome)
	if not FileAccess.file_exists(p):
		return {"entradas": []}
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _modelo(pr: Dictionary) -> String:
	var tipo := String(pr.tipo)
	var vs: Array[String] = []
	for v in ["a", "b", "c", "d"]:
		if ResourceLoader.exists("res://assets/models/predios/%s_%s.glb" % [tipo, v]):
			vs.append("%s_%s" % [tipo, v])
	if vs.is_empty():
		return ""
	var idx := int(String(pr.id).get_slice("_", String(pr.id).get_slice_count("_") - 1))
	return vs[idx % vs.size()]


func _portas() -> void:
	var only: String = Game.test_args.get("only", "")
	var total := 0
	var layout: Dictionary = scene.layout
	for poi in layout.pois + layout.get("marcos", []):
		for pr in poi.get("predios", []):
			var modelo := _modelo(pr)
			if modelo == "":
				continue
			if only != "" and not String(pr.id) in only.split(","):
				continue
			var d := _dados(modelo)
			var x := float(pr.pos[0])
			var z := -float(pr.pos[1])
			var base := Vector3(x, scene.terrain.height_world(x, z), z)
			var basis := Basis(Vector3.UP, deg_to_rad(float(pr.get("rot_deg", 0))))
			var i := 0
			for e in d.entradas:
				i += 1
				total += 1
				var dir_l := Vector3(float(e.dx), 0, -float(e.dy)).normalized()
				var dir: Vector3 = basis * dir_l
				var ini_l := Vector3(float(e.x), 0.0, -float(e.y))
				var ini: Vector3 = base + basis * ini_l
				ini.y = scene.terrain.height_world(ini.x, ini.z)
				var s := Soldier.new()
				scene.add_child(s)
				s.global_position = ini + Vector3(0, 0.3, 0)
				s.yaw = atan2(-dir.x, -dir.z)
				await _frames(10)
				var p0 := s.global_position
				s.in_move = Vector2(0, 1)
				# em escadarias/rampas o jogador também pula; aqui só andar (o degrau automático deve bastar)
				await _frames(110)
				var viajou := (s.global_position - p0).dot(dir)
				var ok := viajou > 2.4
				if not ok:
					falhas += 1
				print("PORTA_MUNDO %s (%s) #%d %s percorreu=%.2f m  desnivel_porta=%.2f" % [pr.id, modelo, i, "OK" if ok else "FALHA", viajou, ini.y - base.y])
				s.queue_free()
				await get_tree().physics_frame


func _fotos(ex: Node3D) -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	var cam: Camera3D = ex.cam
	var only: String = Game.test_args.get("only", "")
	var layout: Dictionary = scene.layout
	var por_id := {}
	for poi in layout.pois + layout.get("marcos", []):
		for pr in poi.get("predios", []):
			por_id[String(pr.id)] = pr
	var lista: Array = FOTOS.duplicate()
	if Game.test_args.has("cam"):       # --cam=nome:id:cx,cy,cz:ax,ay,az
		var p := String(Game.test_args.cam).split(":")
		var c := p[2].split(",")
		var a := p[3].split(",")
		lista = [[p[0], p[1], Vector3(float(c[0]), float(c[1]), float(c[2])), Vector3(float(a[0]), float(a[1]), float(a[2]))]]
	for f in lista:
		if only != "" and not String(f[0]) in only.split(","):
			continue
		var pr: Dictionary = por_id[String(f[1])]
		var x := float(pr.pos[0])
		var z := -float(pr.pos[1])
		var base := Vector3(x, scene.terrain.height_world(x, z), z)
		var basis := Basis(Vector3.UP, deg_to_rad(float(pr.get("rot_deg", 0))))
		cam.global_position = base + basis * (f[2] as Vector3)
		cam.look_at(base + basis * (f[3] as Vector3))
		cam.fov = 75.0
		for _i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("ce_%s.png" % f[0]))
		print("FOTO %s" % f[0])


func _mantle() -> void:
	# amostras: primeiras cercas/muros do detalhes.json; o Soldier parte a 1,2 m de um lado e empurra para o outro
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/detalhes.json"))
	var n := 0
	for c in d.get("cercas", []):
		if String(c.tipo) == "muro_alto":
			continue
		var pts: Array = c.pontos
		for i in mini(pts.size() - 1, 2):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var meio := (a + b) * 0.5
			var t := (b - a).normalized()
			var nrm := Vector2(-t.y, t.x)
			var p0 := meio - nrm * 1.3
			var p1 := meio + nrm * 1.3
			var w0 := Vector3(p0.x, scene.terrain.height_world(p0.x, -p0.y) + 0.1, -p0.y)
			var dir := Vector3(nrm.x, 0, -nrm.y)
			var s := Soldier.new()
			scene.add_child(s)
			s.global_position = w0
			s.yaw = atan2(-dir.x, -dir.z)
			await _frames(10)
			s.in_move = Vector2(0, 1)
			var passou := false
			var alvo := Vector3(p1.x, 0, -p1.y)
			for f in 64 * 4:
				await get_tree().physics_frame
				s.in_jump = f > 20 and f % 64 < 40
				var depois := (s.global_position - Vector3(meio.x, 0, -meio.y)).dot(dir)
				if depois > 0.9 and s.is_on_floor():
					passou = true
					break
			n += 1
			if not passou:
				falhas += 1
			print("MANTLE_MUNDO %s #%d trecho %d %s em (%.0f,%.0f)" % [c.tipo, n, i, "OK" if passou else "FALHA", meio.x, meio.y])
			s.queue_free()
			await get_tree().physics_frame
		if n >= 14:
			break


## Captura de um Soldier com corpo 3D subindo uma escada de mão (câmera atrás dele): --alvo=<nó em Marcos/Blockout> (padrão marco_torre_vigia_madeira_a)
func _escada_foto(ex: Node3D) -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	var alvo: String = Game.test_args.get("alvo", "marco_torre_vigia_madeira_a")
	var corpo: Node = scene.find_child(alvo, true, false)
	if corpo == null:
		print("FALHA: sem nó ", alvo)
		falhas += 1
		return
	var esc: EscadaVertical = corpo.find_children("Escada*", "Area3D", false, false)[0]
	var s := Soldier.new()
	scene.add_child(s)
	s.global_position = esc.base_world() + Vector3(0, 0.3, 0)
	var corpo_3d := BodyModel.new()
	s.add_child(corpo_3d)
	s.body_model = corpo_3d
	corpo_3d.setup(s)
	var cam: Camera3D = ex.cam
	await _frames(10)
	s.iniciar_escada(esc)
	s.in_move = Vector2(0, 1)
	var frames_subida := int(float(Game.test_args.get("seg", "2.5")) * 64.0)
	for i in frames_subida:
		await get_tree().physics_frame
	var f := esc.frente()
	cam.fov = 70.0
	cam.global_position = s.global_position + (-f * 3.2) + Vector3(0, 1.6, 0) + Vector3.UP.cross(f) * 0.6
	cam.look_at(s.global_position + Vector3(0, 1.0, 0))
	for _i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ce_escada_%s.png" % alvo))
	print("FOTO escada y=%.2f" % s.global_position.y)
	s.in_move = Vector2(0, 1)
	for i in 64 * 20:                       # sobe até o fim
		await get_tree().physics_frame
		if s.escada == null:
			break
	print("ESCADA_MUNDO fim y=%.2f topo=%.2f" % [s.global_position.y, esc.topo_world().y])
