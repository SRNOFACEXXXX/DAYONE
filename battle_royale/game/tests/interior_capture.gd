extends Node
## Capturas dos interiores mobiliados no mapa real (1024x768): 3 casas perto da Vila (sala = sofá, cozinha = fogão,
## quarto = cama) e 1 galpão (da porta para dentro). Uso: --path game res://tests/interior_capture.tscn -- --out=<pasta> [--perf]
## Câmera a 1,6 m, 2,3 m à frente do móvel, olhando para ele (frente do móvel = +Z local no quadro de tools/interior.py).

const CASAS := ["casa_laje", "casa_caicara", "casa_colono", "vila_operaria", "sobrado", "casarao"]
const CENTRO := Vector3(-330, 0, 300)          # Vila (design -330, -300)
const COMODOS := {"sala": ["sofa_"], "cozinha": ["fogao_"], "quarto": ["cama_"]}


func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	await get_tree().process_frame
	var ex: Node3D = scene.get_node("Explorador")
	ex.set_physics_process(false)
	ex.set_process(false)
	var cam: Camera3D = ex.cam
	cam.fov = 75.0
	# prédios com modelo: casas (3 tipos diferentes, mais perto da Vila) e o galpão mais perto
	var casas: Array = []
	var galpao: Node3D = null
	for b in scene.get_node("Blockout").get_children():
		if not b.has_meta("modelo"):
			continue
		var mod := String(b.get_meta("modelo"))
		var tipo := mod.substr(0, mod.length() - 2)
		if tipo in CASAS and b.has_node("Moveis"):
			casas.append([b.global_position.distance_to(CENTRO), tipo, b])
		elif tipo == "galpao" and (galpao == null or b.global_position.distance_to(CENTRO) < galpao.global_position.distance_to(CENTRO)):
			galpao = b
	casas.sort_custom(func(a, b): return a[0] < b[0])
	var usados: Array = []
	var fotos: Array = []           # [nome, posição da câmera, alvo]
	for c in casas:
		if c[1] in usados:
			continue
		usados.append(c[1])
		var corpo: Node3D = c[2]
		var lista: Array = _moveis(String(corpo.get_meta("modelo")))
		for comodo in COMODOS:
			for it in lista:
				if String(it.m).begins_with(COMODOS[comodo][0]):
					var p := Vector3(float(it.pos[0]), float(it.pos[1]), float(it.pos[2]))
					var fr := Basis(Vector3.UP, deg_to_rad(float(it.rot_y))) * Vector3.BACK
					var olho := corpo.global_transform * (p + fr * 2.3 + Vector3.UP * 1.6)
					var alvo := corpo.global_transform * (p + Vector3.UP * 0.45)
					fotos.append(["%s_%s_%s" % [comodo, c[1], corpo.name], olho, alvo])
					break
		if usados.size() >= 3:
			break
	if galpao:
		var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			ProjectSettings.globalize_path("res://").path_join("../tools/_loot/%s.json" % galpao.get_meta("modelo"))))
		if not (dados.entradas as Array).is_empty():
			var e: Dictionary = dados.entradas[0]
			var d := Vector3(float(e.dx), 0, -float(e.dy))
			var p := Vector3(float(e.x), 1.7, -float(e.y)) + d * 3.8
			fotos.append(["galpao_%s" % galpao.name, galpao.global_transform * p, galpao.global_transform * (p + d * 6.0 + Vector3.DOWN * 1.0)])
	var ok := 0
	await get_tree().physics_frame
	var esp := cam.get_world_3d().direct_space_state
	for f in fotos:
		# não atravessar parede: recua a câmera até 0,35 m antes do primeiro obstáculo entre o móvel e o olho
		var a: Vector3 = f[2] + Vector3.UP * 1.0
		var hit := esp.intersect_ray(PhysicsRayQueryParameters3D.create(a, f[1]))
		if hit:
			f[1] = (hit.position as Vector3) - (f[1] - a).normalized() * 0.35
		cam.global_position = f[1]
		cam.look_at(f[2])
		for i in 20:
			await get_tree().process_frame
		var fps_txt := ""
		if Game.test_args.has("perf"):
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			var t0 := Time.get_ticks_usec()
			var n := 0
			while Time.get_ticks_usec() - t0 < 2000000:
				await get_tree().process_frame
				n += 1
			var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
			fps_txt = " %.0f fps draws=%d" % [1000.0 / ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("interior_%s.png" % f[0]))
		print("INTERIOR %s%s" % [f[0], fps_txt])
		ok += 1
	print("INTERIOR_OK fotos=%d" % ok)
	get_tree().quit(0 if ok >= 4 else 1)


func _moveis(modelo: String) -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(Moveis.JSON_PATH))
	return d.get(modelo, []) if d is Dictionary else []
