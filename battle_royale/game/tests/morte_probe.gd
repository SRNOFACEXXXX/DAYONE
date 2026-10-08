extends Node3D
## Mede o corpo do zumbi depois da animação DEAD: direção da queda e altura (flutuação) por variante de modelo.
func _ready() -> void:
	Game.test_mode = true
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(50, 1, 50)
	cs.shape = bx
	fl.add_child(cs)
	var mi0 := MeshInstance3D.new()
	var bm0 := BoxMesh.new()
	bm0.size = Vector3(50, 1, 50)
	var m0 := StandardMaterial3D.new()
	m0.albedo_color = Color(0.2, 0.55, 0.2)
	bm0.material = m0
	mi0.mesh = bm0
	fl.add_child(mi0)
	fl.position.y = -0.5
	add_child(fl)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(3.2, 0.35, 0.0)
	cam.look_at(Vector3(0, 0.25, 0))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 25, 0)
	add_child(luz)
	var casos := [["frente", Vector3(0, 0, 1), &"body"], ["costas", Vector3(0, 0, -1), &"body"], ["lado", Vector3(1, 0, 0), &"body"], ["cabeca_frente", Vector3(0, 0, 1), &"head"]]
	for k in casos.size():
		var z: ZombieEnemy = load("res://core/zombie.tscn").instantiate()
		z._variant_index = k
		add_child(z)
		z.global_position = Vector3.ZERO
		await get_tree().create_timer(0.6).timeout
		z._golpe_dir = casos[k][1]
		z.receive_damage(100, null, casos[k][2])
		await get_tree().create_timer(2.2).timeout
		var si := z._source_skeleton.find_bone("Hips")
		print("MORTE %s yaw_visual=%.0f deg offset_y=%.2f speed=%.2f estado=%s" % [casos[k][0], rad_to_deg(z._visual_root.rotation.y), z._visual_root.position.y, z._morte_velocidade, ZombieEnemy.State.keys()[z.state]])
		cam.position = Vector3(3.2, 0.35, 0.0)
		cam.look_at(Vector3(0, 0.25, 0))
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../raw/triagem/morte_%s_lado.png" % casos[k][0]))
		cam.position = Vector3(0.0, 3.4, 1.8)
		cam.look_at(Vector3(0, 0.0, -0.4))
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../raw/triagem/morte_%s_cima.png" % casos[k][0]))
		z.queue_free()
	get_tree().quit()
