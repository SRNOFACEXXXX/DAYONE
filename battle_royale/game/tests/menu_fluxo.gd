extends Node
## MENU DAYONE / fluxo: menu -> (criador de personagem) -> partida. Mede o tempo do clique em JOGAR (ou CONFIRMAR
## no criador) até o jogador ter controle (tela de carregamento escondida + jogador local vivo) e os quadros > 50 ms
## no 1º minuto com controle.
## Uso: godot --path game res://tests/menu_fluxo.tscn -- --modo=antes|depois [--montar=20] [--tag=x] [--minuto=60]
##   antes : clica JOGAR no menu e entra direto na partida (fluxo antigo, Game.start_match()).
##   depois: clica JOGAR -> tela PERSONAGEM; espera --montar s (jogador montando o boneco, aquecimento roda atrás);
##           clica ALEATÓRIO, depois CONFIRMAR / JOGAR.
## Saída: raw/triagem/menu_fluxo_<tag>.json ; imprime MENU_FLUXO_OK.
var R := {}
var modo := "antes"
var _medindo := false
var _ultimo_us := 0
var _quadros: Array[float] = []
var _fim_us := 0
var _gpu: Array[float] = []
var _cpu_r: Array[float] = []
var _proc: Array[float] = []
var _fis: Array[float] = []
var _inicios_sprint: Array[int] = []
var _q_criador: Array[float] = []
var _medindo_criador := false
var _ult_criador := 0


func _ready() -> void:
	modo = String(Game.test_args.get("modo", "antes"))
	var tag := String(Game.test_args.get("tag", modo))
	var minuto := float(Game.test_args.get("minuto", "60"))
	var montar := float(Game.test_args.get("montar", "20"))
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Game.test_args.has("soldado"):
		BodyModel.PERSONAGEM_JOGADOR = false   # config (c): corpo antigo do soldado
	get_tree().create_timer(195.0, true, false, true).timeout.connect(func() -> void: print("MENU_FLUXO_TIMEOUT ", JSON.stringify(R)); get_tree().quit(2))
	await get_tree().process_frame
	# sobrevive às trocas de cena: deixa de ser a cena atual (change_scene não libera este nó)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	await get_tree().create_timer(2.0).timeout
	var menu := get_tree().current_scene
	R["modo"] = modo
	var t_menu_us := Time.get_ticks_usec()
	if modo == "depois":
		if not menu.has_method("abrir_criador"):
			push_error("menu sem abrir_criador")
			get_tree().quit(3)
			return
		menu.abrir_criador()
		var criador: Node = menu.criador
		var t_ini := Time.get_ticks_msec()
		_q_criador.clear()
		_ult_criador = Time.get_ticks_usec()
		_medindo_criador = true
		# o jogador monta o boneco: trocas de peça a cada ~1,5 s
		while Time.get_ticks_msec() - t_ini < montar * 1000.0:
			await get_tree().create_timer(1.5).timeout
			if is_instance_valid(criador):
				criador.aleatorio()
		R["aquecimento_pct_no_confirmar"] = Loading.aquecimento_progresso() if Loading.has_method("aquecimento_progresso") else -1.0
		R["aquecimento_ms"] = Loading.aquecimento_ms if "aquecimento_ms" in Loading else -1
		_medindo_criador = false
		var ec := _estat(_q_criador)
		var q100 := 0
		var q50 := 0
		for q in _q_criador:
			q100 += 1 if q > 100.0 else 0
			q50 += 1 if q > 50.0 else 0
		ec["fps"] = snappedf(1000.0 / maxf(0.001, float(ec.get("media", 1.0))), 0.1)
		ec["q50"] = q50
		ec["q100"] = q100
		R["criador"] = ec
		R["pre_lentos"] = Loading.get("pre_lentos")
		R["pre_por_passo"] = Loading.get("pre_por_passo")
		R["pre_estado_no_confirmar"] = String(Loading.get("pre_estado"))
		R["pre_ms"] = Loading.get("pre_ms")
		var t0 := Time.get_ticks_usec()
		criador.confirmar()
		await _esperar_controle()
		R["ms_ate_controle"] = (Time.get_ticks_usec() - t0) / 1000.0
		R["ms_desde_jogar_no_menu"] = (Time.get_ticks_usec() - t_menu_us) / 1000.0
	else:
		var t0 := Time.get_ticks_usec()
		Game.start_match()
		await _esperar_controle()
		R["ms_ate_controle"] = (Time.get_ticks_usec() - t0) / 1000.0
		R["ms_desde_jogar_no_menu"] = R["ms_ate_controle"]
	print("MENU_FLUXO controle ms=", R["ms_ate_controle"])
	# 1º minuto com controle
	_quadros.clear()
	_ultimo_us = Time.get_ticks_usec()
	_fim_us = _ultimo_us + int(minuto * 1e6)
	_medindo = true
	R["vivos_ao_entrar"] = _vivos()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var andar := Game.test_args.has("andar")
	var t_mov := 0.0
	while _medindo:
		await get_tree().process_frame
		if andar:
			t_mov += get_process_delta_time()
			_mover(t_mov)
	if andar:
		_soltar()
	R["vivos_no_fim"] = _vivos()
	var lentos := 0
	var lentos100 := 0
	var pior := 0.0
	var lista: Array = []
	for i in _quadros.size():
		var q: float = _quadros[i]
		pior = maxf(pior, q)
		if q > 100.0:
			lentos100 += 1
		if q > 50.0:
			lentos += 1
			if lista.size() < 40:
				lista.append([i, snappedf(q, 0.1)])
	R["quadros"] = _quadros.size()
	R["quadros_lentos_50ms"] = lentos
	var ord := _quadros.duplicate()
	ord.sort()
	var soma := 0.0
	var l33 := 0
	for q in ord:
		soma += q
		if q > 33.0:
			l33 += 1
	R["media_ms"] = snappedf(soma / maxf(1.0, ord.size()), 0.01)
	R["p99_ms"] = snappedf(ord[int(ord.size() * 0.99)] if ord.size() > 0 else 0.0, 0.01)
	R["quadros_33ms"] = l33
	R["gpu_ms"] = _estat(_gpu)
	var ini_s := []
	for i in _inicios_sprint:
		var mx := 0.0
		for k in range(i, mini(i + 4, _quadros.size())):
			mx = maxf(mx, _quadros[k])
		ini_s.append(snappedf(mx, 0.1))
	R["inicio_sprint_ms"] = ini_s
	R["render_cpu_ms"] = _estat(_cpu_r)
	R["process_ms"] = _estat(_proc)
	R["fisica_ms"] = _estat(_fis)
	R["quadros_lentos_100ms"] = lentos100
	R["pior_quadro_ms"] = snappedf(pior, 0.1)
	R["lentos_idx_ms"] = lista
	R["renderer"] = RenderingServer.get_video_adapter_name()
	R["etapas_carregamento"] = Loading.etapas.duplicate()
	if Game.test_args.has("gravar"):
		_gravar_lista()
	await _capturas_personagem()
	if Game.test_args.has("terceira"):
		await _fase_3p()
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("menu_fluxo_%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("MENU_FLUXO_OK ", JSON.stringify(R))
	get_tree().quit(0)


## Grava em res://autoload/aquecimento.json todos os recursos que a partida realmente usou (cenas de modelo,
## malhas, materiais, shaders e texturas presentes na árvore depois de 1 min de jogo).
func _gravar_lista() -> void:
	var achados := {}
	for p in ["res://maps/ilha/ilha.tscn", "res://ui/hud.tscn", "res://ui/br_inventory_ui.tscn", "res://core/player_controller.tscn", "res://core/br_match.tscn"]:
		achados[p] = true
	for n in get_tree().root.find_children("*", "", true, false):
		if n.scene_file_path != "":
			_anotar(achados, n.scene_file_path)
		if n is GeometryInstance3D:
			var g := n as GeometryInstance3D
			_anotar_mat(achados, g.material_override)
			_anotar_mat(achados, g.material_overlay)
			var mesh: Mesh = null
			if g is MeshInstance3D:
				mesh = (g as MeshInstance3D).mesh
				for s in (g as MeshInstance3D).get_surface_override_material_count():
					_anotar_mat(achados, (g as MeshInstance3D).get_surface_override_material(s))
			elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
				mesh = (g as MultiMeshInstance3D).multimesh.mesh
			if mesh:
				_anotar(achados, mesh.resource_path)
				for s in mesh.get_surface_count():
					_anotar_mat(achados, mesh.surface_get_material(s))
	var lista: Array = achados.keys()
	lista.sort()
	var f := FileAccess.open("res://autoload/aquecimento.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"gerado_por": "tests/menu_fluxo.tscn --gravar=1", "recursos": lista}, " "))
	f.close()
	R["lista_gravada"] = lista.size()


func _anotar(achados: Dictionary, path: String) -> void:
	if path == "":
		return
	var base := path.split("::")[0]
	if base.begins_with("res://") and not base.begins_with("res://tests/") and ResourceLoader.exists(base):
		achados[base] = true


func _anotar_mat(achados: Dictionary, m: Material) -> void:
	if m == null:
		return
	_anotar(achados, m.resource_path)
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		var sm := m as ShaderMaterial
		_anotar(achados, sm.shader.resource_path)
		for u in sm.shader.get_shader_uniform_list():
			var v = sm.get_shader_parameter(u.name)
			if v is Texture2D:
				_anotar(achados, (v as Texture2D).resource_path)
	elif m is BaseMaterial3D:
		var bm := m as BaseMaterial3D
		for t in [bm.albedo_texture, bm.normal_texture, bm.roughness_texture]:
			if t:
				_anotar(achados, (t as Texture2D).resource_path)
	if m.next_pass:
		_anotar_mat(achados, m.next_pass)


func _esperar_controle() -> void:
	var limite := Time.get_ticks_msec() + 170000
	while Time.get_ticks_msec() < limite:
		await get_tree().process_frame
		var m := Game.current_match
		if m != null and is_instance_valid(m) and m.get("local_player") != null and not Loading._root.visible:
			return
	print("MENU_FLUXO_TIMEOUT_CONTROLE")


func _process(_d: float) -> void:
	if _medindo_criador:
		var ag := Time.get_ticks_usec()
		_q_criador.append((ag - _ult_criador) / 1000.0)
		_ult_criador = ag
	if not _medindo:
		return
	var agora := Time.get_ticks_usec()
	_quadros.append((agora - _ultimo_us) / 1000.0)
	var vr := get_viewport().get_viewport_rid()
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vr))
	_cpu_r.append(RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu())
	_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_fis.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_ultimo_us = agora
	if agora >= _fim_us:
		_medindo = false


## Capturas do personagem na partida (tela de jogo e retrato do inventário) em raw/personagem/.
func _capturas_personagem() -> void:
	var m := Game.current_match
	if m == null or DisplayServer.get_name() == "headless":
		return
	var dir := ProjectSettings.globalize_path("res://").path_join("../raw/personagem")
	DirAccess.make_dir_recursive_absolute(dir)
	var bm = m.local_player.body_model if m.local_player else null
	R["corpo_personagem"] = bool(bm.get("personagem")) if bm else false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("partida_%s.png" % modo))
	if m.has_method("abrir_inventario"):
		m.abrir_inventario()
		for _i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("inventario_retrato_%s.png" % modo))
		m.br_ui.close()

## Simula o jogador: anda, corre, vira de lado e gira a câmera (mouse) o minuto inteiro. Ciclo de 12 s.
const ACOES := ["move_forward", "move_back", "move_left", "move_right", "sprint"]


func _mover(t: float) -> void:
	var ciclo := fmod(t, 12.0)
	var quer := {}
	if ciclo < 3.0:
		quer = {"move_forward": true}
	elif ciclo < 7.0:
		quer = {"move_forward": true, "sprint": true}
	elif ciclo < 9.0:
		quer = {"move_left": true}
	elif ciclo < 11.0:
		quer = {"move_forward": true, "move_right": true}
	for a in ACOES:
		if not InputMap.has_action(a):
			continue
		if quer.has(a) and not Input.is_action_pressed(a):
			if a == "sprint":
				_inicios_sprint.append(_quadros.size())
			Input.action_press(a)
		elif not quer.has(a) and Input.is_action_pressed(a):
			Input.action_release(a)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(sin(t * 0.9) * 6.0, sin(t * 0.37) * 1.5)
	Input.parse_input_event(mm)


func _soltar() -> void:
	for a in ACOES:
		if InputMap.has_action(a):
			Input.action_release(a)


func _vivos() -> Dictionary:
	var vps := get_tree().root.find_children("*", "SubViewport", true, false)
	var nomes := []
	for v in vps:
		nomes.append(String(v.get_path()))
	var m := Game.current_match
	var bm = m.local_player.body_model if m and m.get("local_player") else null
	var malhas := 0
	if bm and bm.model:
		malhas = bm.model.find_children("*", "MeshInstance3D", true, false).size()
	return {"subviewports": nomes, "nos": get_tree().get_node_count(), "malhas_corpo": malhas, "pre_montagem": Loading.get("pre") != null,
		"pos": str(m.local_player.global_position) if m and m.get("local_player") else ""}

func _estat(a: Array) -> Dictionary:
	if a.is_empty():
		return {}
	var o := a.duplicate()
	o.sort()
	var s := 0.0
	for v in o:
		s += v
	return {"media": snappedf(s / o.size(), 0.01), "p99": snappedf(o[int(o.size() * 0.99)], 0.01), "max": snappedf(o[-1], 0.01)}

## 3ª pessoa: custo parado (1ª x 3ª pessoa), arma na mão correndo, captura.
func _fase_3p() -> void:
	var m := Game.current_match
	var s: Soldier = m.local_player
	var pc := s.controller as PlayerController
	var bm := s.body_model as BodyModel
	var dir := ProjectSettings.globalize_path("res://").path_join("../raw/personagem")
	var r := {}
	r["parado_1p_ms"] = await _media_parado(5.0)
	pc._set_third_person(true)
	await get_tree().create_timer(1.0).timeout
	r["parado_3p_ms"] = await _media_parado(5.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("partida_3p_correndo_%s.png" % String(Game.test_args.get("tag", modo))))
	var w := bm.weapon_node
	var ra := bm.skeleton.get_node_or_null("RightHandAttach") as Node3D if bm.skeleton else null
	r["arma"] = {"id": String(bm.weapon_id), "def": String(s.current_def().id) if s.current_def() else "", "existe": is_instance_valid(w),
		"visivel": w.is_visible_in_tree() if is_instance_valid(w) else false, "na_arvore": w.is_inside_tree() if is_instance_valid(w) else false,
		"mao_cm": snappedf(ra.global_position.distance_to(w.global_transform * (BodyModel.GRIPS[bm.weapon_id].r as Vector3)) * 100.0, 0.1) if is_instance_valid(w) and ra and BodyModel.GRIPS.has(bm.weapon_id) else -1.0,
		"sombra": int((w.find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D).cast_shadow) if is_instance_valid(w) and w.find_children("*", "GeometryInstance3D", true, false).size() > 0 else -1}
	r["correndo_3p_ms"] = await _media_parado(3.0)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	pc._set_third_person(false)
	R["fase_3p"] = r
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/triagem")
	var f := FileAccess.open(out.path_join("menu_fluxo_%s.json" % String(Game.test_args.get("tag", modo))), FileAccess.WRITE)
	f.store_string(JSON.stringify(R, " "))
	f.close()
	print("FASE_3P ", JSON.stringify(r))


func _media_parado(seg: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var ult := t0
	var q: Array[float] = []
	while Time.get_ticks_usec() - t0 < int(seg * 1e6):
		await get_tree().process_frame
		var ag := Time.get_ticks_usec()
		q.append((ag - ult) / 1000.0)
		ult = ag
	var e := _estat(q)
	e["fps"] = snappedf(1000.0 / maxf(0.001, float(e.get("media", 1.0))), 0.1)
	var vr := get_viewport().get_viewport_rid()
	e["gpu_ms"] = snappedf(RenderingServer.viewport_get_measured_render_time_gpu(vr), 0.01)
	return e