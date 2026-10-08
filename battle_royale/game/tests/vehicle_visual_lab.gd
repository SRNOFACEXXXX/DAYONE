extends Node3D

var car: DrivableVehicle
var camera: Camera3D
var out := ""

func _ready() -> void:
	Game.test_mode = true
	out = String(Game.test_args.get("out", OS.get_user_data_dir()))
	DirAccess.make_dir_recursive_absolute(out)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("82b9dc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.25
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, .2, 30)
	collision.shape = shape
	collision.position.y = -.1
	ground.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(30, .2, 30)
	mesh.mesh = box
	mesh.position.y = -.1
	ground.add_child(mesh)
	add_child(ground)
	var model := (load("res://assets/models/cenario/carros/carro_taxi_aberto.fbx") as PackedScene).instantiate()
	add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if "wheel" in String(node.name).to_lower() or "base" in String(node.name).to_lower() or "door" in String(node.name).to_lower():
			print("FBX_NODE ", node.name, " pos=", node.position, " xf=", node.transform, " aabb=", (node as MeshInstance3D).get_aabb())
	car = DrivableVehicle.create_from_model(model, "cenario/carros/carro_taxi")
	for node in car.find_children("*", "MeshInstance3D", true, false):
		if "wheel" in String(node.name).to_lower() or "door" in String(node.name).to_lower():
			print("CAR_NODE ", node.name, " pos=", node.position, " gpos=", node.global_position, " aabb=", (node as MeshInstance3D).get_aabb())
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 58
	add_child(camera)
	for _i in 8:
		await get_tree().physics_frame
	await _capture_external("carro_fechado.png")
	for panel in ["door_fl", "door_fr", "door_bl", "door_br", "hood", "trunk"]:
		car.set_panel_open(panel, true)
	for _i in 40:
		await get_tree().process_frame
	await _capture_external("carro_aberto.png")
	for panel in ["door_fl", "door_fr", "door_bl", "door_br", "hood", "trunk"]:
		car.set_panel_open(panel, false)
	car.first_person_camera = true
	for _i in 12:
		car.update_camera(camera, 1.0 / 60.0)
		await get_tree().process_frame
	await _save("camera_motorista.png")
	print("VEHICLE_VISUAL_LAB ", out)
	get_tree().quit()

func _capture_external(name: String) -> void:
	camera.global_position = car.global_position + Vector3(5.4, 2.6, 6.4)
	camera.look_at(car.global_position + Vector3(0, .8, 0))
	await get_tree().process_frame
	await _save(name)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
