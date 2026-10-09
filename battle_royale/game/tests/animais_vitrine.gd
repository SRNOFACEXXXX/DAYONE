extends Node3D
## Vitrine dos 4 animais (cervo, cachorro, lobo, galinha) com a paleta real, em cada clipe (parado, andar, correr, comer, morrer),
## sem carregar a partida (rápido). Uma foto por clipe. --out=<pasta>
const ANIMAL := preload("res://core/animal.gd")
const CLIPES := ["parado", "andar", "correr", "comer", "morrer"]


func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.66, 0.7)
	env.environment = e
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.4, 0.55, 0.3)
	chao.material_override = cm
	add_child(chao)
	var bichos := []
	var x := -4.5
	for esp in ["cervo", "cachorro", "lobo", "galinha"]:
		var a := ANIMAL.new()
		a.configurar(esp, null)
		add_child(a)
		a.set_physics_process(false)   # depois do add_child: o _ready religa a física de quem tem _physics_process
		a.position = Vector3(x, 0, 0)
		x += 3.0
		bichos.append(a)
	var ref := MeshInstance3D.new()   # cubo de referência (confere câmera e luz)
	var bx := BoxMesh.new()
	bx.size = Vector3(0.3, 0.3, 0.3)
	ref.mesh = bx
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.9, 0.1, 0.1)
	ref.material_override = rm
	ref.position = Vector3(0, 0.15, 1.5)
	add_child(ref)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 1.8, 7.5)
	cam.look_at(Vector3(0, 0.7, 0))
	for a in bichos:
		var n_mesh := 0
		var caixa := AABB()
		for mi in a.find_children("*", "MeshInstance3D", true, false):
			n_mesh += 1
			caixa = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		print("VIT %s malhas=%d aabb=%s visivel=%s pos=%s" % [a.especie, n_mesh, caixa, a.is_visible_in_tree(), a.global_position])
	for k in 20:
		await get_tree().process_frame
	var cerv = bichos[0]
	var sk := cerv.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		for i in sk.get_bone_count():
			var gp := sk.get_bone_global_pose(i)
			print("OSSO %s origem=%s escala=%s" % [sk.get_bone_name(i), gp.origin.snapped(Vector3.ONE * 0.01), gp.basis.get_scale().snapped(Vector3.ONE * 0.01)])
	var mi0 := cerv.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	print("MALHA skin=%s skeleton_path=%s layers=%d visivel=%s transp=%s" % [mi0.skin != null, mi0.skeleton, mi0.layers, mi0.visible, mi0.transparency])
	print("ANIMPLAYER clip_atual=%s tocando=%s" % [cerv._anim.current_animation if cerv._anim else "nulo", cerv._anim.is_playing() if cerv._anim else false])
	for clip in CLIPES:
		for a in bichos:
			a._clip = ""
			a._tocar(clip)
			if clip == "morrer":
				a.state = ANIMAL.DEAD
		for k in 25:   # ~0,4 s de animação em cada clipe
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("clip_%s.png" % clip))
	# diagnóstico: sem animação, pose de repouso
	for b in bichos:
		if b._anim:
			b._anim.stop()
		var sk2 := b.find_child("Skeleton3D", true, false) as Skeleton3D
		if sk2:
			sk2.reset_bone_poses()
	for k in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("clip_repouso.png"))
	print("ANIMAIS_VITRINE_OK")
	get_tree().quit()
