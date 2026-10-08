extends Node3D
## PERSONAGEM NO CORPO DE 3ª PESSOA: o jogador local usa o boneco do criador (dayone_base.glb + user://personagem.json).
## Capturas frente / lado / correndo / mirando em raw/personagem/ e medida mão–cabo (RightHandProp x ponto de pega da arma).
## Uso: godot --path game res://tests/personagem_corpo.tscn -- [--personagem=padrao] [--arma=ak47] [--soldado=1]
## Saída: raw/personagem/personagem_corpo.json ; imprime PERSONAGEM_CORPO_OK.

var out := ""
var R := {}
var s: Soldier
var body: BodyModel
var cam: Camera3D


func _ready() -> void:
	Game.test_mode = true
	out = ProjectSettings.globalize_path("res://").path_join("../raw/personagem")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	if Game.test_args.has("soldado"):
		BodyModel.PERSONAGEM_JOGADOR = false
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9bb4c8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8b99d")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	fs.shape = box
	fs.position.y = -0.5
	floor.add_child(fs)
	add_child(floor)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	ground.mesh = plane
	ground.layers = 2
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8b7958")
	ground.material_override = gm
	add_child(ground)
	s = Soldier.new()
	s.team = 0
	s.is_bot = false
	s.is_local = true
	add_child(s)
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 40.0
	cam.cull_mask = 2
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cam)
	cam.current = true
	body = BodyModel.new()
	s.add_child(body)
	s.body_model = body
	body.setup(s)
	var arma := StringName(Game.test_args.get("arma", "ak47"))
	s.give_weapon(arma)
	await _fisica(20)
	R["personagem"] = body.personagem
	R["arma"] = String(arma)
	var nomes := []
	for mi in body.model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			nomes.append(String(mi.name))
	R["pecas_visiveis"] = nomes
	R["clipes"] = {}
	for n in ["idle", "walk_f", "run_f", "sprint_a", "crouch_f", "jump", "death", "hold_rifle"]:
		R["clipes"][n] = body._clip(n)
	var capturas := []
	# frente
	await _pose_parado()
	await _foto("_aquece", Vector3(0.0, 1.3, -3.4))
	capturas.append(await _foto("frente", Vector3(0.0, 1.3, -3.4)))
	R["mao_frente"] = _mao()
	capturas.append(await _foto("lado", Vector3(3.4, 1.3, 0.0)))
	R["mao_lado"] = _mao()
	# correndo (para a frente = -Z)
	s.in_move = Vector2(0.0, 1.0)
	s.in_sprint = true if "in_sprint" in s else false
	# custo do início da corrida: maior quadro (process) nos primeiros 20 quadros
	var t_ult := Time.get_ticks_usec()
	var pior_ini := 0.0
	for _i in 20:
		await get_tree().process_frame
		var ag := Time.get_ticks_usec()
		pior_ini = maxf(pior_ini, (ag - t_ult) / 1000.0)
		t_ult = ag
	R["inicio_sprint_pior_ms"] = snappedf(pior_ini, 0.1)
	await _fisica(25)
	R["vel_correndo"] = snappedf(Vector2(s.velocity.x, s.velocity.z).length(), 0.01)
	capturas.append(await _foto("correndo", Vector3(2.6, 1.3, -1.6), true))
	R["mao_correndo"] = _mao()
	s.in_move = Vector2.ZERO
	if "in_sprint" in s:
		s.in_sprint = false
	await _fisica(60)
	# mirando: parado, cano 10° para cima, câmera sobre o ombro direito
	s.pitch = deg_to_rad(10.0)
	s.last_shot = s.t
	await _fisica(30)
	capturas.append(await _foto("mirando", Vector3(0.7, 1.75, 1.9), true))
	R["mao_mirando"] = _mao()
	# agachado
	s.crouch = 1.0
	s.in_crouch = true if "in_crouch" in s else false
	await _fisica(30)
	capturas.append(await _foto("agachado", Vector3(2.2, 1.0, -2.2), true))
	# caso do QA: pistola inicial -> M4 equipada pelo inventário, correndo, câmera de 3ª pessoa atrás
	s.crouch = 0.0
	s.in_crouch = false
	s.give_weapon(&"glock")
	await _fisica(10)
	var ws := WeaponState.new(WeaponDB.get_def(&"m4"))
	s.inventory[WeaponDef.Slot.PRIMARY] = ws
	s.switch_to(WeaponDef.Slot.PRIMARY)
	s.yaw = 0.0
	s.in_move = Vector2(0.0, 1.0)
	s.in_sprint = true
	await _fisica(60)
	capturas.append(await _foto("costas_correndo_m4", Vector3(0.6, 2.0, 3.0), true))
	var w := body.weapon_node
	R["costas_m4"] = {"weapon_id": String(body.weapon_id), "existe": is_instance_valid(w), "visivel": w.is_visible_in_tree() if is_instance_valid(w) else false,
		"mao": _mao(), "lower": snappedf(body.ik.lower, 0.01) if body.ik else -1.0}
	s.in_move = Vector2.ZERO
	s.in_sprint = false
	# óptica no nó da arma do corpo novo (M4 + holográfica, depois AK + ACOG)
	var opt := {}
	for par in [["m4", "reddot"], [&"ak47", "acog"]]:
		if String(par[0]) != "m4":
			s.give_weapon(StringName(par[0]))
		body.set_mira(String(par[1]))
		await _fisica(25)
		var wn := body.weapon_node
		var o := wn.get_node_or_null(OpticaAssento.NOME) as Node3D if wn else null
		opt[String(par[0])] = {"mira": par[1], "presente": o != null and o.is_inside_tree(), "folga_cm": snappedf(OpticaAssento.folga_cm(wn, o), 0.001) if o else 99.0}
	R["optica"] = opt
	R["capturas"] = capturas
	var pior := 0.0
	for k in ["mao_frente", "mao_lado", "mao_correndo", "mao_mirando"]:
		pior = maxf(pior, float(R[k].get("direita_cm", 99.0)))
	R["mao_cabo_cm_pior"] = snappedf(pior, 0.1)
	R["ok"] = pior <= 3.0 and body.personagem != Game.test_args.has("soldado")
	var f := FileAccess.open(out.path_join("personagem_corpo%s.json" % ("_soldado" if Game.test_args.has("soldado") else "")), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("PERSONAGEM_CORPO_OK ", JSON.stringify(R))
	get_tree().quit(0 if R["ok"] else 1)


func _pose_parado() -> void:
	s.yaw = 0.0
	s.pitch = 0.0
	await _fisica(40)


## Distância (cm) entre o osso de pega (RightHandProp / LeftHandProp) e o ponto de pega da arma (GRIPS r / l).
func _mao() -> Dictionary:
	var sk := body.skeleton
	var g: Dictionary = BodyModel.GRIPS.get(body.weapon_id, {})   # pega real da arma (o IK usa o alvo corrigido)
	if sk == null or body.weapon_node == null or g.is_empty():
		return {"erro": "sem esqueleto/arma/pega"}
	# pose final (depois do IK): lida pelos BoneAttachment3D dos ossos de pega, atualizados após os modificadores
	var wt := body.weapon_node.global_transform
	var ra := sk.get_node("RightHandAttach") as Node3D
	var la := sk.get_node_or_null("LeftHandAttach") as Node3D
	var rd := ra.global_position.distance_to(wt * (g.r as Vector3))
	var d := {"direita_cm": snappedf(rd * 100.0, 0.1)}
	if g.has("l") and la:
		var ld := la.global_position.distance_to(wt * (g.l as Vector3))
		d["esquerda_cm"] = snappedf(ld * 100.0, 0.1)
	return d


func _foto(nome: String, rel: Vector3, seguir := false) -> String:
	var alvo := s.global_position + Vector3(0, 1.0, 0)
	cam.global_position = s.global_position + rel
	cam.look_at(alvo)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var p := out.path_join("corpo_%s%s.png" % [nome, "_soldado" if Game.test_args.has("soldado") else ""])
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png(p)
	return "raw/personagem/" + p.get_file()


func _fisica(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
