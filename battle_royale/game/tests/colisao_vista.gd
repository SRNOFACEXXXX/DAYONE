extends Node
## Fotos de objetos com as FORMAS DE COLISÃO desenhadas (rode com --debug-collisions antes do --path ... ou via ver.sh com
## DEBUG_COL=1): mostra se o colisor cobre o modelo. Alvos em design (x, y) = (x, -z). --out=<pasta>
## [nome, x_mundo, z_mundo]
const ALVOS := [
	["carvalho_a", -102.0, -203.0], ["arvore_d_a", -117.0, -194.0], ["arvore_b_a", -119.0, -204.0], ["carvalho_b", -81.0, -194.0],
	["arvore_d_b", -66.0, -192.0], ["pine_01", 100.0, -529.0],
]


func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	await get_tree().process_frame
	var ex: Node3D = scene.get_node("Explorador")
	ex.set_physics_process(false)
	var cam: Camera3D = ex.cam
	var t: IlhaTerrain = scene.terrain
	for a in ALVOS:
		var x: float = a[1]
		var z: float = a[2]
		var h := t.height_world(x, z)
		cam.global_position = Vector3(x - 5.0, h + 1.7, z + 5.0)
		cam.look_at(Vector3(x, h + 1.0, z))
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % a[0]))
		print("VISTA %s" % a[0])
	get_tree().quit()
