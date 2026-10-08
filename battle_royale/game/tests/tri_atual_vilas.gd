extends Node
## Triagem atualização: 1 vista semi-aérea por POI de ilha_layout.json. --out=<pasta>
## Câmera copiada de ilha_tour.gd (Explorador.cam, 30 quadros de espera).

func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/ilha_layout.json"))
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	await get_tree().process_frame
	var ex: Node3D = scene.get_node("Explorador")
	ex.set_physics_process(false)
	var cam: Camera3D = ex.cam
	var t: IlhaTerrain = scene.terrain
	for p in lay.pois:
		var cx: float = p.centro[0]
		var cz: float = -float(p.centro[1])
		var r: float = clampf(float(p.raio_m) * 0.75, 45.0, 90.0)
		var tgt := Vector3(cx, t.height_world(cx, cz) + 2.0, cz)
		var pos := tgt + Vector3(r * 0.7, 0, r * 0.7)
		pos.y = maxf(t.height_world(pos.x, pos.z), tgt.y) + r * 0.45
		cam.global_position = pos
		cam.look_at(tgt)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("vila_%s.png" % p.id))
		print("VIEW %s fps=%d" % [p.id, Engine.get_frames_per_second()])
	get_tree().quit()
