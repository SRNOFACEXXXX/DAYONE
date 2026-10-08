extends Node
## O ponto da holográfica tem de acompanhar a arma (colimador): em ADS parado fica no centro; durante a rajada se move
## junto com o eixo óptico da mira. Mede, quadro a quadro, o ponto desenhado (ads_indicator) contra a projeção
## independente do eixo do CANO (boca -> trás, malha) e o deslocamento máximo do ponto.
## Falha se: parado > 1,5 px do centro; erro ponto x eixo do cano > 2 px em algum quadro; ou o ponto não se mover
## (< 3 px) enquanto a arma gira > 0,3°. Uso: -- --armas=m4,m249,m107,ak47,uzi

var OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/holo_reticulo"
var _falhas := 0
var _rel := []


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	DirAccess.make_dir_recursive_absolute(OUT)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	var pc := m.local_player.controller as PlayerController
	var s0 := m.local_player
	var hx: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s0.global_position = Vector3(-345.0, hx + 0.1, 352.0)
	s0.yaw = deg_to_rad(40.0)
	s0.pitch = 0.0
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	for arma in String(Game.test_args.get("armas", "m4,ak47")).split(","):
		await _medir(m, pc, arma)
	var f := FileAccess.open(OUT.path_join("holo_reticulo.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"falhas": _falhas, "armas": _rel}, " "))
	print("RETICULO_RESULT falhas=", _falhas)
	get_tree().quit(1 if _falhas > 0 else 0)


func _medir(m: BRMatch, pc: PlayerController, arma: String) -> void:
	var bag: BRInventory = m.br_bag
	for it in bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "reddot", "acog"]:
			bag.remove_item(int(it.uid))
	bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": 30})
	var uid := _uid(bag, arma)
	m._equip_br_weapon(uid)
	await _frames(90)
	bag.add_item("reddot")
	bag.attach_mira(_uid(bag, "reddot"), uid)
	await _frames(30)
	var vm: ViewModel = pc.viewmodel
	var ind: Control = pc._ads_indicator
	var ret = ind.get("_reticle")
	Input.action_press("alt_fire")
	await _frames(60)
	var tela := get_viewport().get_visible_rect().size
	var r := {"arma": arma}
	var parado := 0.0
	for _q in 30:
		await get_tree().process_frame
		var p: Vector2 = ret.pos
		parado = maxf(parado, (p - tela * 0.5).length() if p.x >= 0 else 999.0)
	r["parado_px"] = snappedf(parado, 0.01)
	# rajada: segura o gatilho ~1 s
	var erro := 0.0
	var desloc := 0.0
	var giro := 0.0
	var b0 := _eixo_cano_cam(vm, pc.camera)
	var melhor_q := -1
	Input.action_press("fire")
	for q in 70:
		await get_tree().process_frame
		var p: Vector2 = ret.pos
		var ec := _eixo_cano_cam(vm, pc.camera)
		var pe := _proj(vm, ec, tela)
		if p.x >= 0:
			erro = maxf(erro, (p - pe).length())
			if (p - tela * 0.5).length() > desloc:
				desloc = (p - tela * 0.5).length()
				melhor_q = q
		giro = maxf(giro, rad_to_deg(ec.angle_to(b0)))
		if q == 6 or q == 20:
			await _cap("%s_rajada_q%02d" % [arma, q])
	Input.action_release("fire")
	Input.action_release("alt_fire")
	r["erro_ponto_vs_cano_px"] = snappedf(erro, 0.01)
	r["desloc_max_px"] = snappedf(desloc, 0.01)
	r["giro_arma_graus"] = snappedf(giro, 0.01)
	var falha := []
	if parado > 1.5:
		falha.append("parado fora do centro %.2f px" % parado)
	if erro > 2.0:
		falha.append("ponto não segue o eixo do cano: erro %.2f px" % erro)
	if giro > 0.3 and desloc < 3.0:
		falha.append("arma girou %.2f° e o ponto ficou parado" % giro)
	r["falhas"] = falha
	_falhas += falha.size()
	_rel.append(r)
	print("RETICULO ", JSON.stringify(r))
	bag.retirar_mira(uid)
	await _frames(20)


## Direção do eixo do cano no espaço da câmera, medida independente da mira: frente da arma = direção
## alça->massa NÃO é usada; usa o eixo Z do nó da arma (rig: +Z boca; wf: -Z boca).
func _eixo_cano_cam(vm: ViewModel, cam: Camera3D) -> Vector3:
	var no: Node3D = vm._mira_no
	var fr := Vector3(0, 0, 1) if vm._rig_skel != null else Vector3(0, 0, -1)
	return (cam.global_transform.affine_inverse().basis * (no.global_transform.basis * fr)).normalized()


func _proj(vm: ViewModel, d: Vector3, tela: Vector2) -> Vector2:
	var f := 1.0 / tan(deg_to_rad(vm._vm_fov()) * 0.5)
	return tela * 0.5 + Vector2(d.x / -d.z, -d.y / -d.z) * f * tela.y * 0.5


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
