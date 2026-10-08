extends Node3D
## Poses do soldado em 3ª pessoa com AK-47 / Mosin (trilha G): parado, correndo, agachado, mirando, recarregando, atirando.
## Args: --out=<pasta> --weapons=ak47,mosin --views=34,lado --fps=1

var out_dir := ""
var s: Soldier
var body: BodyModel
var cam: Camera3D

func _ready() -> void:
	Game.test_mode = true
	var a := Game.test_args
	out_dir = a.get("out", "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/soldado_poses")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	get_tree().create_timer(150.0).timeout.connect(func() -> void: get_tree().quit(2))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9bb4c8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8b99d")
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new(); world.environment = env; add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0); sun.light_energy = 1.3; sun.shadow_enabled = true; add_child(sun)
	var fl := StaticBody3D.new(); var fs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(60, 1, 60); fs.shape = bx; fs.position.y = -0.5; fl.add_child(fs); add_child(fl)
	var ground := MeshInstance3D.new(); var pl := PlaneMesh.new(); pl.size = Vector2(60, 60); ground.mesh = pl; ground.position.y = -0.02; ground.layers = 2
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("7d8a4e"); ground.material_override = gm; add_child(ground)
	s = Soldier.new(); s.team = 0; add_child(s)
	cam = Camera3D.new(); cam.cull_mask = 2; cam.current = true; cam.fov = 50.0; cam.top_level = true
	s.add_child(cam)
	body = BodyModel.new(); s.add_child(body); s.body_model = body; body.setup(s)
	await _pf(3)
	var weapons: PackedStringArray = String(a.get("weapons", "ak47,mosin")).split(",")
	var views: PackedStringArray = String(a.get("views", "frente,lado")).split(",")
	for w in weapons:
		s.give_weapon(StringName(w), true)
		s._do_switch(WeaponDB.get_def(StringName(w)).slot)
		await _pf(70)
		for st in ["idle", "run", "crouch", "aim", "reload", "fire"]:
			_state(st)
			for i in (30 if st != "run" else 50):
				await get_tree().physics_frame
			for v in views:
				_cam(v)
				if st == "idle" and v == "34": print("POS ", s.global_position, " cam ", cam.global_position, " yaw ", s.yaw)
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s_%s.png" % [w, st, v]))
			s.in_move = Vector2.ZERO
			s.in_crouch = false
			s.in_fire = false
	get_tree().quit()

func _state(st: String) -> void:
	s.in_move = Vector2.ZERO; s.in_crouch = false; s.in_fire = false
	match st:
		"run": s.in_move = Vector2(0, 1)
		"crouch": s.in_crouch = true
		"aim": s.pitch = 0.0
		"reload": s.start_reload() if s.current() and s.current().mag < s.current_def().mag_size or true else null
		"fire": s.in_fire = true

func _cam(v: String) -> void:
	if s.body_model and s.body_model.has_method("set_first_person"):
		s.body_model.set_first_person(false)   # corpo do jogador local é só sombra em 1ª pessoa: sem isto a vista de frente saía vazia
	var p := s.global_position
	var f := Basis(Vector3.UP, s.yaw)
	var off := Vector3(1.9, 1.35, -2.1)
	match v:
		"34": off = Vector3(1.9, 1.35, -2.1)   # frente-direita do soldado (ele olha -Z)
		"lado": off = Vector3(2.9, 1.15, -0.3)
		"tras": off = Vector3(0.6, 1.5, 3.0)
		"frente": off = Vector3(0.4, 1.3, -3.2)
	cam.global_position = p + f * off
	cam.look_at(p + f * Vector3(0, 0.95, -0.1))

func _pf(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
