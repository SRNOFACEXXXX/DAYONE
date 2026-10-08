extends Node3D
## Renderiza um modelo de 4 lados (+X, -Z, +Z, +Y) com grade de 1 unidade: -- --m=res://... --tag=x
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/fp_packs"
func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(800, 800))
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.7, 0.75, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sol)
	var m: Node3D = load(String(Game.test_args.get("m", ""))).instantiate()
	add_child(m)
	var aabb := AABB()
	var first := true
	for g in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (g as MeshInstance3D).global_transform * (g as MeshInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	print("AABB_TOTAL ", aabb)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = aabb.size[aabb.size.max_axis_index()] * 1.3
	cam.near = 0.001
	cam.far = 10000
	add_child(cam)
	var c := aabb.get_center()
	var r := aabb.size.length() * 2.0
	for v in [["frente_mZ", Vector3(0, 0, -1)], ["tras_pZ", Vector3(0, 0, 1)], ["lado_pX", Vector3(1, 0, 0)], ["topo", Vector3(0, 1, 0.001)]]:
		cam.global_position = c + (v[1] as Vector3) * r
		cam.look_at(c, Vector3.UP if absf((v[1] as Vector3).y) < 0.9 else Vector3.FORWARD)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT.path_join("%s_%s.png" % [Game.test_args.get("tag", "m"), v[0]]))
	get_tree().quit()
