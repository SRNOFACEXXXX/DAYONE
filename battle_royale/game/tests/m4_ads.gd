extends Node
## Captura da M4 mirando (sem e com ACOG) para conferir que há uma única mira.

const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/ads_review"


func _ready() -> void:
	get_tree().create_timer(40.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	DirAccess.make_dir_recursive_absolute(OUT)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	var arma: String = Game.test_args.get("arma", "m4")
	m.br_bag.add_item("backpack_medium")
	print("ADD ", m.br_bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": 30}))
	m.br_bag.add_item("acog")
	var uid := _uid(m.br_bag, arma)
	m._equip_br_weapon(uid)
	var pc := m.local_player.controller as PlayerController
	# campo aberto (sem o parapeito do spawn de teste na frente da arma)
	var s0 := m.local_player
	var hx: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s0.global_position = Vector3(-345.0, hx + 0.1, 352.0)
	s0.velocity = Vector3.ZERO
	s0.yaw = deg_to_rad(float(Game.test_args.get("yaw", "40")))
	s0.pitch = 0.0
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(40)
	await _cap(arma + "_quadril")
	Input.action_press("alt_fire")
	await _frames(40)
	await _cap(arma + "_iron")
	Input.action_release("alt_fire")
	m.br_bag.attach_acog(_uid(m.br_bag, "acog"), uid)
	await _frames(30)
	Input.action_press("alt_fire")
	await _frames(40)
	await _cap(arma + "_acog")
	Input.action_release("alt_fire")
	print("RETIRAR ", m.br_bag.retirar_mira(uid))
	m.br_bag.add_item("reddot")
	print("ACOPLAR ", m.br_bag.attach_mira(_uid(m.br_bag, "reddot"), uid))
	await _frames(30)
	Input.action_press("alt_fire")
	await _frames(40)
	await _cap(arma + "_holo")
	Input.action_release("alt_fire")
	await _frames(40)
	await _cap(arma + "_holo_quadril")
	# vista lateral ortográfica da arma montada (confere se a mira está sentada no trilho)
	var vm := pc.viewmodel
	var alvo: Node3D = vm.scene_root.find_child("Arma", true, false) as Node3D
	if alvo:
		for mi in alvo.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			var loc: AABB = (alvo.global_transform.affine_inverse() * m3.global_transform) * m3.get_aabb()
			print("NO_ARMA ", m3.name, " ", loc)
		print("ARMA_SCALE ", alvo.global_transform.basis.get_scale())
		var mod := alvo.find_child("Modelo", false, false) as Node3D
		if mod:
			var topo := {}
			var baixo := {}
			for mi in mod.find_children("*", "MeshInstance3D", true, false):
				var m4 := mi as MeshInstance3D
				var xf := alvo.global_transform.affine_inverse() * m4.global_transform
				for si in m4.mesh.get_surface_count():
					for v: Vector3 in m4.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
						var w := xf * v
						var k := int(floor(w.z / 4.0))
						topo[k] = maxf(float(topo.get(k, -1e9)), w.y)
						if absf(w.x - 0.3) < 2.0:
							baixo[k] = minf(float(baixo.get(k, 1e9)), w.y)
			var ks := topo.keys()
			ks.sort()
			var linha := "TOPO (z cm: y max) "
			for k in ks:
				linha += "%d:%.1f " % [k * 4, topo[k]]
			print(linha)
			var l2 := "BAIXO "
			for k in ks:
				l2 += "%d:%.1f " % [k * 4, float(baixo.get(k, 99))]
			print(l2)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 0.3
		cam.near = 0.01
		cam.cull_mask = 0xFFFFF
		add_child(cam)
		var o := alvo.global_transform
		var lado := o.basis.x.normalized()
		cam.global_position = o.origin + o.basis.z.normalized() * 0.15 + lado * 1.0
		cam.look_at(o.origin + o.basis.z.normalized() * 0.15, o.basis.y.normalized())
		cam.current = true
		await _frames(3)
		await _cap(arma + "_lado")
	print("MIRA ", pc._mira, " fov=", pc.camera.fov)
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _cap(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT.path_join(nome + ".png"))


func _uid(bag: BRInventory, id: String) -> int:
	for it in bag.items:
		if String(it.id) == id:
			return int(it.uid)
	return -1
