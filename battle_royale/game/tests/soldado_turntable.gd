extends Node3D
## Turntable do soldado (trilha F): frontal / lateral / traseira em pose de descanso (A-pose) para comparar com docs/ref/personagem.jpg,
## mais uma prancha com poses animadas (idle/corrida/agachado + AK e Mosin em 3ª pessoa).
## Args: --model=res://assets/models/characters/soldado.glb --out=<pasta> --poses=1

var out := ""

func _ready() -> void:
	Game.test_mode = true
	var a := Game.test_args
	out = a.get("out", "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/soldado")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.37, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38, -25, 0); sun.light_energy = 1.1
	sun.shadow_enabled = false; add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 150, 0); fill.light_energy = 0.5; add_child(fill)
	var path: String = a.get("model", "res://assets/models/characters/soldado.glb")
	var m: Node3D = load(path).instantiate()
	var holder := Node3D.new(); add_child(holder); holder.add_child(m)

	var tris := 0
	for n in _meshes(m):
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			tris += int(arr[Mesh.ARRAY_INDEX].size() / 3)
	print("SOLDADO_TRIS ", tris)
	var ap := _find_ap(m)
	if ap:
		var lines := []
		for lib in ap.get_animation_library_list():
			for an in ap.get_animation_list():
				lines.append("%s=%.2f" % [an, ap.get_animation(an).length])
			break
		print("CLIPES ", ", ".join(lines))
	var sk := _find_sk(m)
	if sk:
		sk.reset_bone_poses()
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	cam.fov = 18.0
	cam.near = 1.0; cam.far = 100.0
	for v in [["frontal", 0.0], ["lateral", -90.0], ["traseira", 180.0]]:
		holder.rotation_degrees.y = v[1]
		cam.position = Vector3(0, 0.98, 7.5)
		cam.look_at(Vector3(0, 0.93, 0))
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("turn_%s.png" % v[0]))
	# close-up da cabeça/tronco
	holder.rotation_degrees.y = 0
	cam.fov = 12.0
	cam.position = Vector3(0, 1.45, 7.5)
	cam.look_at(Vector3(0, 1.4, 0))
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("turn_busto.png"))
	holder.rotation_degrees.y = -40
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("turn_busto34.png"))
	get_tree().quit()


func _meshes(n: Node, o: Array = []) -> Array:
	if n is MeshInstance3D:
		o.append(n)
	for c in n.get_children():
		_meshes(c, o)
	return o

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null

func _find_sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_sk(c)
		if r:
			return r
	return null
