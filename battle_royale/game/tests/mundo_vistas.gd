extends Node
## Vistas fixas das peças do pack 'atualizacao/mundo' no Quartel e na Pista. --out=<pasta>
## [nome, cam_x, cam_y (design), altura sobre o chão, alvo_x, alvo_y]
const VISTAS := [
	["q_heli", 370.0, 318.0, 7.0, 389.5, 335.0],
	["q_tanque", 352.0, 284.0, 4.0, 374.0, 266.0],
	["q_portao_w", 246.0, 322.0, 3.5, 226.0, 316.0],
	["q_estande", 292.0, 345.0, 2.5, 291.0, 370.0],
	["q_radio", 316.0, 364.0, 4.0, 334.0, 354.0],
	["q_aereo", 360.0, 236.0, 45.0, 315.0, 312.0],
	["p_heli", 318.0, -264.0, 5.0, 336.0, -282.0],
	["p_camp", 247.0, -326.0, 5.0, 220.0, -305.0],
	["p_aereo", 372.0, -332.0, 40.0, 285.0, -280.0],
	["t_represa", -85.0, -15.0, 6.0, -110.0, -42.0],
	["t_caicara", -352.0, -345.0, 3.0, -335.0, -318.0],
	["v_fazenda", -68.0, -322.0, 1.6, -76.0, -331.0],
	["v_caicara_carro", -376.0, -289.0, 2.5, -385.0, -298.0],
	["v_usina", -244.0, 280.0, 3.0, -256.0, 289.0],
	["v_praia", 160.0, -490.0, 2.0, 152.5, -497.0],
]


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
	var cam: Camera3D = ex.cam
	var t: IlhaTerrain = scene.terrain
	# colisão de cobertura: raio horizontal a 0,6 m (sacos/HESCO) ou 1,5 m (veículos) atravessando a peça
	await get_tree().physics_frame
	var esp := scene.get_world_3d().direct_space_state
	for r in [["Barrier_007 sul", 299.0, 233.0, 0.6], ["Barrier_006 oeste", 231.0, 332.0, 0.5], ["HESCO 309.7", 227.0, 309.7, 0.6],
			["vao portao oeste (deve passar)", 224.0, 317.0, 0.6], ["Tank", 372.0, 268.0, 1.5], ["Hummer", 245.0, 312.0, 1.2],
			["Helicopter corpo", 389.5, 335.0, 1.6], ["Barrier_007 pista", 215.7, -315.0, 0.6], ["Tent_010 pista", 215.0, -305.0, 1.0]]:
		var x: float = r[1]
		var z: float = -float(r[2])
		var y := t.height_world(x, z) + float(r[3])
		var q := PhysicsRayQueryParameters3D.create(Vector3(x - 0.3, y, z - 4.0), Vector3(x + 0.3, y, z + 4.0))
		var hit := esp.intersect_ray(q)
		print("COLISAO %s -> %s" % [r[0], (hit.collider as Node).name if hit else "LIVRE"])
	var so: String = Game.test_args.get("only", "")
	for v in VISTAS:
		if so != "" and not String(v[0]) in so.split(","):
			continue
		var cx: float = v[1]
		var cz: float = -float(v[2])
		var tx: float = v[4]
		var tz: float = -float(v[5])
		cam.global_position = Vector3(cx, t.height_world(cx, cz) + float(v[3]), cz)
		cam.look_at(Vector3(tx, t.height_world(tx, tz) + 1.0, tz))
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
		print("VISTA %s" % v[0])
	get_tree().quit()
