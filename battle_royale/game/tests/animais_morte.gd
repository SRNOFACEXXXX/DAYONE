extends Node3D
## Sequência de MORTE dos 4 animais em close (câmera a ~3 m): quadros em 0, 0,3, 0,7, 1,2 e 2,5 s depois do último tiro. --out=<pasta>
const ANIMAL := preload("res://core/animal.gd")
var out := ""


func _shot(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))


func _ready() -> void:
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.66, 0.7)
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.4, 0.55, 0.3)
	chao.material_override = cm
	add_child(chao)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for esp in ["cervo", "cachorro", "lobo", "galinha"]:
		var a := ANIMAL.new()
		a.configurar(esp, null)
		add_child(a)
		a.set_physics_process(false)
		a.position = Vector3.ZERO
		a.rotation.y = deg_to_rad(35.0)
		var dist := 4.2 if esp == "cervo" else 2.6
		cam.global_position = Vector3(dist * 0.55, 1.2 if esp == "cervo" else 0.9, dist)
		cam.look_at(Vector3(0, 0.55 if esp == "cervo" else 0.3, 0))
		for i in 6:
			await get_tree().process_frame
		await _shot("%s_0_vivo" % esp)
		a.receber_dano(9999, null)
		var t0 := Time.get_ticks_msec()
		for k in [["1_0s", 0.0], ["2_03s", 0.3], ["3_07s", 0.7], ["4_12s", 1.2], ["5_25s", 2.5]]:
			while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k[1]):
				await get_tree().process_frame
			await _shot("%s_%s" % [esp, k[0]])
		a.queue_free()
		await get_tree().process_frame
	print("MORTE_FIM")
	get_tree().quit()
