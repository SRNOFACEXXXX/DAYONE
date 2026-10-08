extends Node
## Uma captura por área autoral de maps/ilha/cenario_pontos.json (câmera a ~16 m, olhando o centro). --out=<pasta> --only=id1,id2
## Coordenadas do JSON são de design (z = -y), como em mundo_vistas.gd.


func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/cenario_pontos.json"))
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	await get_tree().process_frame
	var ex: Node3D = scene.get_node("Explorador")
	ex.set_physics_process(false)
	var cam: Camera3D = ex.cam
	var t: IlhaTerrain = scene.terrain
	var so: String = Game.test_args.get("only", "")
	var n := 0
	for area in dados.get("areas", []):
		var id := ("%02d_%s" % [n, String(area.get("nome", "area")).to_lower().replace(" ", "_").replace("/", "_")]).left(40)
		n += 1
		if so != "" and not id in so.split(","):
			continue
		var c := Vector2.ZERO
		var props: Array = area.get("props", [])
		if props.is_empty():
			continue
		for p in props:
			c += Vector2(float(p.x), float(p.y))
		c /= float(props.size())
		var raio := 8.0
		for p in props:
			raio = maxf(raio, c.distance_to(Vector2(float(p.x), float(p.y))))
		var dist := clampf(raio * 1.6 + 6.0, 14.0, 60.0)
		# câmera ao sul-sudoeste do centro (design y menor), olhando para ele
		var cx := c.x - dist * 0.55
		var cz := -(c.y - dist * 0.85)
		var tx := c.x
		var tz := -c.y
		cam.global_position = Vector3(cx, t.height_world(cx, cz) + 4.5, cz)
		cam.look_at(Vector3(tx, t.height_world(tx, tz) + 1.0, tz))
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % id))
		print("VISTA %s centro=(%.0f,%.0f) props=%d" % [id, c.x, c.y, props.size()])
	get_tree().quit()
