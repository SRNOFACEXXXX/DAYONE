class_name PlayerController
extends Node3D
## Local human: mouse/keyboard -> soldier intents, first-person camera, viewmodel, death cam and spectating.

var soldier: Soldier
var match_ref: Match
var camera: Camera3D
var viewmodel: ViewModel
var ui_blocking := false
var spectate_target: Soldier = null
var death_time := -1.0
var killer: Soldier = null
var _shake := 0.0
var _eye := Soldier.EYE_STAND
var _step_smooth := 0.0
var _fov_kick := 0.0
var _sprint_fov := 0.0           # graus somados ao FOV ao correr (suave; zera com Ajustes > Balanço da câmera = 0)
var _ads_amount := 0.0
var _ads_acog := false
var _mira := ""                  # mira instalada na arma da mão: "", "acog" (4x, só luneta) ou "reddot" (holográfica); trocar = retirar a atual no inventário
var _ads_indicator: Control
var _prefer_third_person := false
var _third_person := false
var _air_camera_blend := 0.0
# passada (docs/criteria/MOVIMENTO_REFERENCIA.md): fase do passo, intensidade suavizada e mola de aterrissagem
var gait_phase := 0.0
var gait_amount := 0.0
var _land_off := 0.0
var _land_vel := 0.0
var active_vehicle: DrivableVehicle
var _vehicle_label: Label
var _vehicle_use_block_until := 0
const VEHICLE_HOLD_TIME := 0.72
var _vehicle_hold := 0.0
var _vehicle_hold_triggered := false


func setup(s: Soldier, m: Match) -> void:
	soldier = s
	garantir_sprint()
	match_ref = m
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.top_level = true
	camera.near = 0.05
	camera.far = 600.0
	camera.cull_mask = 0xFFFFF & ~(1 << 11)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = Settings.vertical_fov()
	add_child(camera)
	camera.current = true
	viewmodel = ViewModel.new()
	viewmodel.name = "ViewModel"
	camera.add_child(viewmodel)
	viewmodel.setup(s)
	var aim_layer := CanvasLayer.new()
	aim_layer.name = "MosinAimLayer"
	aim_layer.layer = 2
	add_child(aim_layer)
	_ads_indicator = preload("res://core/ads_indicator.gd").new()
	aim_layer.add_child(_ads_indicator)
	if s.body_model and s.body_model.has_method("set_first_person"):
		s.body_model.set_first_person(true)
	s.landed.connect(func(impact: float) -> void:
		# pulo normal ~2,5 cm; queda grande até 8 cm; volta por mola (~0,22–0,4 s)
		_land_vel -= clampf((impact - 3.0) * 0.13, 0.0, 1.7))
	_build_agua_fx()
	if not Game.test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---- nado: tinta subaquática quando a câmera está abaixo da superfície e barra de fôlego ----
var _agua_tinta: ColorRect
var _folego_box: Control
var _folego_fill: ColorRect
var _folego_lbl: Label


func _build_agua_fx() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AguaFx"
	layer.layer = 3
	add_child(layer)
	_agua_tinta = ColorRect.new()
	_agua_tinta.color = Color(0.05, 0.28, 0.36, 0.42)
	_agua_tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_agua_tinta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_agua_tinta.visible = false
	layer.add_child(_agua_tinta)
	_folego_box = Control.new()
	_folego_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folego_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_folego_box.position = Vector2(-110, -150)
	_folego_box.size = Vector2(220, 26)
	_folego_box.visible = false
	layer.add_child(_folego_box)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.size = Vector2(220, 12)
	fundo.position = Vector2(0, 14)
	_folego_box.add_child(fundo)
	_folego_fill = ColorRect.new()
	_folego_fill.color = Color(0.45, 0.8, 1.0)
	_folego_fill.size = Vector2(216, 8)
	_folego_fill.position = Vector2(2, 16)
	_folego_box.add_child(_folego_fill)
	_folego_lbl = Label.new()
	_folego_lbl.text = "FÔLEGO"
	_folego_lbl.add_theme_font_size_override("font_size", 12)
	_folego_lbl.position = Vector2(0, -2)
	_folego_box.add_child(_folego_lbl)


func _update_agua_fx() -> void:
	if _agua_tinta == null:
		return
	var s := soldier
	var sub := s != null and s.alive and s.nadando and camera.global_position.y < s.agua_y - 0.02
	_agua_tinta.visible = sub
	var mostrar := s != null and s.alive and s.nadando and (s.folego < Soldier.FOLEGO_MAX - 0.05 or sub)
	_folego_box.visible = mostrar
	if mostrar:
		var f := clampf(s.folego / Soldier.FOLEGO_MAX, 0.0, 1.0)
		_folego_fill.size.x = 216.0 * f
		_folego_fill.color = Color(0.45, 0.8, 1.0).lerp(Color(1.0, 0.25, 0.2), clampf(1.0 - f * 3.0, 0.0, 1.0))
		_folego_lbl.text = "SEM FÔLEGO!" if s.folego <= 0.0 else "FÔLEGO"


## Sprint no Shift (estilo DayZ). O andar lento ("walk"), que usava o Shift, passa para o Alt.
## Settings.BINDINGS não salva teclas, então o remapeamento é feito aqui, uma vez, em tempo de execução.
static func garantir_sprint() -> void:
	if not InputMap.has_action("sprint"):
		InputMap.add_action("sprint", 0.2)
	if InputMap.action_get_events("sprint").is_empty():
		var k := InputEventKey.new()
		k.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("sprint", k)
	if InputMap.has_action("walk"):
		var tinha_shift := false
		for ev in InputMap.action_get_events("walk"):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_SHIFT:
				InputMap.action_erase_event("walk", ev)
				tinha_shift = true
		if tinha_shift and InputMap.action_get_events("walk").is_empty():
			var a := InputEventKey.new()
			a.physical_keycode = KEY_ALT
			InputMap.action_add_event("walk", a)


func view_target() -> Soldier:
	if soldier.alive:
		return soldier
	return spectate_target if spectate_target and spectate_target.alive else soldier


func muzzle_world_position() -> Vector3:
	return viewmodel.muzzle_world_position()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# ------------------------------------------------------------------ entrada
func _input(event: InputEvent) -> void:
	# Entrada e saída são medidas continuamente em _physics_process para exigir
	# que E permaneça segurado mesmo quando o HUD consome o evento da tecla.
	if event.is_action_released("use"):
		_vehicle_hold = 0.0
		_vehicle_hold_triggered = false


func _unhandled_input(event: InputEvent) -> void:
	# O radial precisa receber clique/tecla antes do bloqueio geral de UI; com uma
	# prévia ativa, clique esquerdo confirma peça em vez de disparar a arma.
	if match_ref and match_ref.has_method("handle_construction_input") and match_ref.handle_construction_input(event):
		get_viewport().set_input_as_handled()
		return
	if ui_blocking:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		if active_vehicle:
			active_vehicle.add_look(m.relative)
			return
		var deg_per_count := Settings.sensitivity * 0.022
		if soldier.alive:
			soldier.yaw -= deg_to_rad(m.relative.x * deg_per_count)
			var dy := deg_to_rad(m.relative.y * deg_per_count)
			soldier.pitch -= -dy if Settings.invert_y else dy
			soldier.pitch = clampf(soldier.pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
			viewmodel.look_delta(m.relative)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Game.test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if not soldier.alive:
		if event.is_action_pressed("fire"):
			_cycle_spectate(1)
		elif event.is_action_pressed("alt_fire"):
			_cycle_spectate(-1)
		return
	if event is InputEventKey and event.is_action_pressed("camera_toggle") and not event.echo:
		if active_vehicle:
			active_vehicle.toggle_camera()
			get_viewport().set_input_as_handled()
			return
		if not _is_airborne():
			_prefer_third_person = not _prefer_third_person
			_set_third_person(_prefer_third_person)
		get_viewport().set_input_as_handled()
		return
	if active_vehicle and event is InputEventKey and event.pressed and not event.echo:
		if active_vehicle.handle_panel_key(event.physical_keycode):
			get_viewport().set_input_as_handled()
			return
	# Sobrevivência: teclas 1–5 usam o acesso rápido (itens arrastados no inventário); 6 = faca
	if match_ref and match_ref.has_method("use_quick_slot") and event is InputEventKey and event.pressed and not event.echo:
		var kc: int = int(event.physical_keycode)
		if kc >= KEY_1 and kc <= KEY_5:
			match_ref.call("use_quick_slot", kc - int(KEY_1))
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_6:
			soldier.switch_to(WeaponDef.Slot.KNIFE)
			get_viewport().set_input_as_handled()
			return
	if match_ref and match_ref.has_method("use_quick_slot"):
		pass   # o bloco antigo (slots por tipo) fica desligado no modo sobrevivência
	elif event.is_action_pressed("slot_1"):
		soldier.switch_to(WeaponDef.Slot.PRIMARY)
	elif event.is_action_pressed("slot_2"):
		soldier.switch_to(WeaponDef.Slot.PISTOL)
	elif event.is_action_pressed("slot_3"):
		soldier.switch_to(WeaponDef.Slot.KNIFE)
	elif event.is_action_pressed("slot_4") or event.is_action_pressed("slot_5"):
		soldier.switch_to(WeaponDef.Slot.BOMB)
	elif event.is_action_pressed("next_weapon"):
		soldier.cycle_weapon(1)
	elif event.is_action_pressed("prev_weapon"):
		soldier.cycle_weapon(-1)
	elif event.is_action_pressed("last_weapon"):
		soldier.switch_to(soldier.last_slot)
	elif event.is_action_pressed("drop"):
		if soldier.active_slot != WeaponDef.Slot.KNIFE:
			match_ref.drop_item(soldier, soldier.active_slot, true)
	elif event.is_action_pressed("toggle_optic"):
		toggle_optic()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inspect"):
		viewmodel.inspect()
	elif event.is_action_pressed("use"):
		if active_vehicle:
			get_viewport().set_input_as_handled()
		elif _nearest_vehicle() != null:
			get_viewport().set_input_as_handled()
		elif soldier.escada == null and soldier.escada_mais_proxima() != null and not soldier.external_motion:
			soldier.iniciar_escada(soldier.escada_mais_proxima())
		elif soldier.escada == null:
			_try_use_pickup()


## Dica de escada vertical ("E — subir" perto do pé/topo; "W/S mover · Espaço solta" enquanto escala).
var _ladder_label: Label


func _update_ladder_prompt() -> void:
	if _ladder_label == null:
		var layer := CanvasLayer.new()
		layer.name = "EscadaLayer"
		layer.layer = 3
		add_child(layer)
		_ladder_label = Label.new()
		_ladder_label.name = "EscadaDica"
		_ladder_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_ladder_label.offset_top = -190.0
		_ladder_label.offset_bottom = -150.0
		_ladder_label.offset_left = -220.0
		_ladder_label.offset_right = 220.0
		_ladder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ladder_label.add_theme_font_size_override("font_size", 24)
		_ladder_label.add_theme_color_override("font_color", Color("FFE27A"))
		_ladder_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_ladder_label.add_theme_constant_override("outline_size", 6)
		_ladder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_ladder_label)
	var txt := ""
	if soldier.alive and not ui_blocking:
		if soldier.escada != null:
			txt = "W/S mover  ·  Espaço ou E solta"
		else:
			var e := soldier.escada_mais_proxima()
			if e != null and not soldier.external_motion:
				txt = (e as EscadaVertical).rotulo_para(soldier)
	_ladder_label.text = txt
	_ladder_label.visible = txt != ""


func _try_use_pickup() -> void:
	var best: Pickup = null
	var best_d := 2.2
	var eye := soldier.eye_position()
	var fwd := soldier.aim_dir()
	for p in match_ref.pickups_root.get_children():
		if not (p is Pickup):
			continue
		var to: Vector3 = p.global_position - eye
		var d := to.length()
		if d < best_d and to.normalized().dot(fwd) > 0.75 and p.can_take(soldier):
			best = p
			best_d = d
	if best:
		var slot := best.state.def.slot
		if soldier.inventory.has(slot) and slot != WeaponDef.Slot.BOMB:
			match_ref.drop_item(soldier, slot, true)
		best.give_to(soldier)
		soldier.switch_to(slot)


func _physics_process(_dt: float) -> void:
	# Consulta o estado da ação além de _unhandled_input: inventário/HUD podem consumir
	# o evento E antes do controlador, mas não devem impedir a entrada no carro.
	var near_vehicle := _nearest_vehicle() if active_vehicle == null else null
	var can_hold_vehicle := soldier.alive and not ui_blocking and (active_vehicle != null or near_vehicle != null)
	if can_hold_vehicle and Input.is_action_pressed("use") and not _vehicle_hold_triggered and Time.get_ticks_msec() >= _vehicle_use_block_until:
		_vehicle_hold += _dt
		if _vehicle_hold >= VEHICLE_HOLD_TIME:
			var started := active_vehicle.start_exit() if active_vehicle else near_vehicle.start_entry(soldier)
			if started:
				_vehicle_hold_triggered = true
				_vehicle_use_block_until = Time.get_ticks_msec() + 500
	else:
		if not Input.is_action_pressed("use"):
			_vehicle_hold = 0.0
			_vehicle_hold_triggered = false
	if active_vehicle:
		soldier.in_move = Vector2.ZERO
		soldier.in_jump = false
		soldier.in_crouch = false
		soldier.in_walk = false
		soldier.in_sprint = false
		soldier.in_fire = false
		soldier.in_alt = false
		soldier.in_reload = false
		soldier.in_use = false
		return
	var active := soldier.alive and not ui_blocking
	if active:
		soldier.in_move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		soldier.in_jump = Input.is_action_pressed("jump")
		soldier.in_crouch = Input.is_action_pressed("crouch")
		soldier.in_walk = Input.is_action_pressed("walk")
		soldier.in_sprint = InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
		soldier.in_fire = Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		soldier.in_alt = Input.is_action_pressed("alt_fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		soldier.in_reload = Input.is_action_pressed("reload")
		soldier.in_use = Input.is_action_pressed("use")
	else:
		soldier.in_move = Vector2.ZERO
		soldier.in_jump = false
		soldier.in_fire = false
		soldier.in_alt = false
		soldier.in_reload = false
		soldier.in_use = false
		if not soldier.alive:
			soldier.in_crouch = false
			soldier.in_walk = false
		soldier.in_sprint = false


# ------------------------------------------------------------------ câmera
func _process(dt: float) -> void:
	_update_agua_fx()
	_update_vehicle_prompt()
	if active_vehicle:
		active_vehicle.update_camera(camera, dt)
		return
	var forced_third := _is_airborne()
	_air_camera_blend = move_toward(_air_camera_blend, 1.0 if forced_third else 0.0, dt * 2.5)
	var climbing := soldier.alive and soldier.escada != null
	var wanted_third := _prefer_third_person or forced_third or climbing
	_update_ladder_prompt()
	if wanted_third != _third_person:
		_set_third_person(wanted_third)
	var def := soldier.current_def()
	# ACOG instalada: mira sempre pela óptica (a alça de ferro fica escondida atrás dela)
	_mira = _mira_instalada()
	_ads_acog = _mira == "acog"
	var can_ads := soldier.alive and not ui_blocking and def != null and def.ads_iron_fov > 0.0 and not soldier.is_reloading() and soldier.t >= soldier.ready_at and not (viewmodel and viewmodel.has_method("ferrolho_ocupado") and viewmodel.ferrolho_ocupado()) and not soldier.sprint_bloqueado()
	var target_ads := 1.0 if not _third_person and can_ads and Input.is_action_pressed("alt_fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else 0.0
	var transition := maxf(def.ads_transition, 0.05) if def else 0.16
	_ads_amount = move_toward(_ads_amount, target_ads, dt / transition)
	# correr no chão abre o FOV ~4° (suave); usa o mesmo interruptor do balanço da câmera, então 0 desliga
	var sprint_alvo := 4.0 * Settings.camera_bob if soldier.alive and soldier.is_sprinting and soldier.is_on_floor() else 0.0
	_sprint_fov = lerpf(_sprint_fov, sprint_alvo, 1.0 - exp(-dt * 5.0))
	var base_fov := (minf(Settings.vertical_fov(), 66.0) if _third_person else Settings.vertical_fov()) + _fov_kick + _sprint_fov + soldier.mantle_fx.z
	var aim_fov := base_fov
	if def and def.ads_iron_fov > 0.0:
		aim_fov = def.ads_acog_fov if _ads_acog and def.ads_acog_fov > 0.0 else def.ads_iron_fov
		if viewmodel.luneta:
			aim_fov = def.ads_acog_fov if def.ads_acog_fov > 0.0 else 24.0
	var target_fov := lerpf(base_fov, aim_fov, _ads_amount)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-dt / transition))
	viewmodel.acog_dot = _mira == "reddot"
	viewmodel.set_ads(_ads_amount, _ads_acog)
	soldier.aim_amount = _ads_amount
	Crosshair.ads_amount = _ads_amount if not _third_person else 0.0
	viewmodel.set_mira(_mira)
	_ads_indicator.set_aim(_ads_amount if not _third_person and def and def.ads_iron_fov > 0.0 else 0.0, _ads_acog or viewmodel.luneta or _mira == "reddot", _mira == "reddot")
	if _mira == "reddot" and not _ads_indicator.fonte_reticulo.is_valid():
		_ads_indicator.fonte_reticulo = func() -> Dictionary: return viewmodel.reticulo_holo(camera, get_viewport().get_visible_rect().size)
	_shake = move_toward(_shake, 0.0, dt * 1.8)
	var shake_off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.03
	if soldier.alive:
		var base := soldier.get_global_transform_interpolated().origin
		_eye = lerpf(_eye, soldier.eye_height(), clampf(dt * 18.0, 0.0, 1.0))
		_step_smooth = lerpf(_step_smooth + soldier.eye_offset_smooth, 0.0, clampf(dt * 12.0, 0.0, 1.0))
		soldier.eye_offset_smooth = 0.0
		var bob := _gait(dt)
		viewmodel.gait_phase = gait_phase
		viewmodel.gait_amount = gait_amount
		var yaw_b := Basis(Vector3.UP, soldier.yaw)
		var p := soldier.pitch + deg_to_rad(soldier.aim_punch.y) + soldier.mantle_fx.x
		var y := soldier.yaw - deg_to_rad(soldier.aim_punch.x)
		var aim_basis := Basis.from_euler(Vector3(p, y, randf_range(-1, 1) * _shake * 0.01 + bob.z + soldier.mantle_fx.y), EULER_ORDER_YXZ)
		if _third_person:
			_update_third_person_camera(dt, base, aim_basis, shake_off)
		else:
			camera.global_position = base + Vector3(0, _eye + _step_smooth + _land_off + bob.y, 0) + yaw_b.x * bob.x + aim_basis * shake_off
			camera.global_basis = aim_basis
		return
	# ---- morto: câmera da morte e espectador ----
	var since := match_ref.clock - death_time
	if since < 2.2:
		var corpse := soldier.global_position + Vector3(0, 0.6, 0)
		var look_at_pos := corpse
		if killer and is_instance_valid(killer) and killer.alive:
			look_at_pos = killer.eye_position()
		var back := Vector3(sin(soldier.yaw), 0, cos(soldier.yaw)) * 2.6
		var target_pos := corpse + back + Vector3(0, 1.4, 0)
		camera.global_position = camera.global_position.lerp(target_pos, clampf(dt * 3.0, 0.0, 1.0))
		var dir := (look_at_pos - camera.global_position)
		if dir.length() > 0.1:
			camera.global_basis = camera.global_basis.slerp(Basis.looking_at(dir.normalized(), Vector3.UP), clampf(dt * 4.0, 0.0, 1.0))
		return
	if spectate_target == null or not spectate_target.alive:
		_cycle_spectate(1)
	if spectate_target and spectate_target.alive:
		var s := spectate_target
		var base2 := s.get_global_transform_interpolated().origin
		camera.global_position = base2 + Vector3(0, s.eye_height(), 0)
		var cur := camera.global_basis.get_euler(EULER_ORDER_YXZ)
		var ty := lerp_angle(cur.y, s.yaw - deg_to_rad(s.aim_punch.x), clampf(dt * 16.0, 0.0, 1.0))
		var tp := lerp_angle(cur.x, s.pitch + deg_to_rad(s.aim_punch.y), clampf(dt * 16.0, 0.0, 1.0))
		camera.global_basis = Basis.from_euler(Vector3(tp, ty, 0), EULER_ORDER_YXZ)


func _set_third_person(enabled: bool) -> void:
	_third_person = enabled
	if viewmodel:
		viewmodel.set_viewmodel_enabled(not enabled)
	if soldier and soldier.body_model:
		soldier.body_model.set_first_person(not enabled)
	if enabled:
		camera.fov = Settings.vertical_fov()
		_ads_amount = 0.0
		_ads_acog = false


func attach_vehicle(vehicle: DrivableVehicle) -> void:
	active_vehicle = vehicle
	_vehicle_use_block_until = Time.get_ticks_msec() + 300
	_set_third_person(true)
	viewmodel.set_viewmodel_enabled(false)
	Crosshair.ads_amount = 1.0


func detach_vehicle(vehicle: DrivableVehicle) -> void:
	if active_vehicle != vehicle:
		return
	active_vehicle = null
	_vehicle_use_block_until = Time.get_ticks_msec() + 300
	_set_third_person(_prefer_third_person)
	viewmodel.set_viewmodel_enabled(not _third_person)
	Crosshair.ads_amount = 0.0


func _nearest_vehicle() -> DrivableVehicle:
	var best: DrivableVehicle
	var best_distance := 4.2
	for node in get_tree().get_nodes_in_group("drivable_vehicle"):
		var vehicle := node as DrivableVehicle
		if vehicle == null or not vehicle.can_enter(soldier):
			continue
		var distance := soldier.global_position.distance_to(vehicle.global_position)
		if distance < best_distance:
			best = vehicle
			best_distance = distance
	return best


func _try_enter_vehicle() -> bool:
	var vehicle := _nearest_vehicle()
	return vehicle != null and vehicle.enter_vehicle(soldier)


func _update_vehicle_prompt() -> void:
	if _vehicle_label == null:
		var layer := CanvasLayer.new()
		layer.name = "VehicleLayer"
		layer.layer = 4
		add_child(layer)
		_vehicle_label = Label.new()
		_vehicle_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_vehicle_label.offset_left = -290.0
		_vehicle_label.offset_right = 290.0
		_vehicle_label.offset_top = -118.0
		_vehicle_label.offset_bottom = -70.0
		_vehicle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vehicle_label.add_theme_font_size_override("font_size", 21)
		_vehicle_label.add_theme_color_override("font_color", Color("F3E4B5"))
		_vehicle_label.add_theme_color_override("font_outline_color", Color(0,0,0,.92))
		_vehicle_label.add_theme_constant_override("outline_size", 6)
		layer.add_child(_vehicle_label)
	var text := ""
	if active_vehicle:
		var hold_exit := "  ·  Segure E %.0f%%" % [clampf(_vehicle_hold / VEHICLE_HOLD_TIME, 0.0, 1.0) * 100.0] if _vehicle_hold > 0.0 else ""
		text = "%s  ·  %d km/h%s\nW/S acelerar/frear · A/D virar · C câmera · 1–4 portas · H capô · T porta-malas · Segure E sair" % [active_vehicle.display_name(), active_vehicle.speed_kmh(), hold_exit]
	elif soldier.alive and not ui_blocking:
		var near := _nearest_vehicle()
		if near:
			var progress := clampf(_vehicle_hold / VEHICLE_HOLD_TIME, 0.0, 1.0) * 100.0
			text = "Segure E — abrir a porta e entrar no %s  %.0f%%" % [near.display_name(), progress]
	_vehicle_label.text = text
	_vehicle_label.visible = text != ""


func _is_airborne() -> bool:
	return match_ref != null and match_ref.has_method("is_player_airborne") and bool(match_ref.call("is_player_airborne", soldier))


func _update_third_person_camera(dt: float, base: Vector3, aim_basis: Basis, shake_off: Vector3) -> void:
	var focus := base + Vector3(0, _eye * 0.88, 0)
	var yaw_basis := Basis(Vector3.UP, soldier.yaw)
	var follow_basis := aim_basis
	var behind := aim_basis * Vector3(0.5, 0.2, 3.6)
	if _air_camera_blend > 0.0:
		# No salto, a câmera acompanha a direção horizontal do corpo e limita o mergulho
		# vertical para manter o personagem e o horizonte legíveis no enquadramento.
		var air_pitch := clampf(soldier.pitch, deg_to_rad(-28.0), deg_to_rad(18.0))
		follow_basis = Basis.from_euler(Vector3(air_pitch, soldier.yaw, 0.0), EULER_ORDER_YXZ)
		behind = yaw_basis * Vector3(0.0, 0.9, 3.25)
	var desired := focus + behind
	var query := PhysicsRayQueryParameters3D.create(focus, desired, Soldier.LAYER_WORLD, [soldier.get_rid()])
	query.collide_with_areas = false
	var hit := soldier.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + (focus - desired).normalized() * 0.22
	var blend := clampf(dt * (10.0 if _air_camera_blend > 0.0 else 8.0), 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(desired + shake_off, blend)
	var look_dir := (focus + follow_basis * Vector3(0, 0, -24.0) - camera.global_position).normalized()
	if look_dir.length_squared() > 0.5:
		var wanted_basis := Basis.looking_at(look_dir, Vector3.UP)
		camera.global_basis = camera.global_basis.slerp(wanted_basis, blend)


## BRMatch may provide this method once inventory attachments are integrated.
## A missing provider means no optic is installed; iron ADS still works.
func _mira_instalada() -> String:
	if match_ref == null:
		return ""
	if match_ref.has_method("mira_para"):
		return String(match_ref.call("mira_para", soldier))
	return "acog" if _has_installed_acog() else ""


func _has_installed_acog() -> bool:
	return match_ref != null and match_ref.has_method("has_acog_for") and bool(match_ref.call("has_acog_for", soldier))


func toggle_optic() -> bool:
	var def := soldier.current_def()
	if def and def.ads_acog_fov > 0.0 and _has_installed_acog():
		_ads_acog = not _ads_acog
		return true
	if match_ref and match_ref.has_signal("hud_message"):
		match_ref.hud_message.emit("Esta arma usa mira aberta ou não tem ACOG instalada", 1.8)
	return false


## Balanço da cabeça: frequência de passo 1,6 + 0,28·v Hz (1,8–3,4); vertical no passo, lateral e rolagem na passada.
## Correndo: ±0,6 cm vertical, ±0,4 cm lateral, ±0,15° de rolagem; andando (Shift) metade; agachado um quarto.
## Retorna (lateral, vertical, rolagem em rad).
func _gait(dt: float) -> Vector3:
	var v := soldier.horizontal_speed()
	var grounded := soldier.is_on_floor()
	var target := clampf(v / 5.5, 0.0, 1.0) if grounded and v > 0.3 else 0.0
	if soldier.in_walk:
		target *= 0.5
	if soldier.crouch > 0.5:
		target *= 0.25
	# sobe em ~0,15 s, some em ~0,3 s
	var rate := 7.0 if target > gait_amount else 10.0
	gait_amount = lerpf(gait_amount, target, 1.0 - exp(-dt * rate))
	var hz := clampf(1.6 + 0.28 * v, 1.8, 3.4)
	gait_phase = fmod(gait_phase + dt * hz * PI, TAU * 4.0)   # uma passada (2 passos) = 2π
	# mola da aterrissagem
	# subpassos fixos: um quadro lento não pode fazer a mola divergir (câmera voando)
	var resto := minf(dt, 0.1)
	while resto > 0.0:
		var h := minf(resto, 1.0 / 240.0)
		resto -= h
		_land_vel += (-_land_off * 130.0 - _land_vel * 19.0) * h
		_land_off += _land_vel * h
	_land_off = clampf(_land_off, -0.2, 0.2)
	var k := gait_amount * Settings.camera_bob
	var vert := (absf(sin(gait_phase)) - 0.637) * 0.012 * k
	var lat := sin(gait_phase) * 0.004 * k
	var roll := sin(gait_phase) * deg_to_rad(0.15) * k
	return Vector3(lat, vert, roll)


func _cycle_spectate(dir: int) -> void:
	var mates := match_ref.team_members(soldier.team, true)
	if mates.is_empty():
		mates = match_ref.team_members(1 - soldier.team, true)
	if mates.is_empty():
		spectate_target = null
		return
	var idx := mates.find(spectate_target)
	idx = wrapi(idx + dir, 0, mates.size())
	if spectate_target != mates[idx]:
		if spectate_target and spectate_target.body_model:
			spectate_target.body_model.set_first_person(false)
		spectate_target = mates[idx]
		spectate_target.body_model.set_first_person(true)


# ------------------------------------------------------------------ eventos da partida
func on_round_start() -> void:
	if spectate_target and spectate_target.body_model:
		spectate_target.body_model.set_first_person(false)
	spectate_target = null
	killer = null
	death_time = -1.0
	if soldier.body_model:
		soldier.body_model.set_first_person(not _third_person)
	viewmodel.set_viewmodel_enabled(not _third_person)


func on_round_end(_winner: int) -> void:
	pass


func on_soldier_died(victim: Soldier, k: Soldier) -> void:
	if victim == soldier:
		death_time = match_ref.clock
		killer = k
		camera.global_position = soldier.eye_position()
		if soldier.body_model:
			soldier.body_model.set_first_person(false)
	elif victim == spectate_target:
		spectate_target.body_model.set_first_person(false)


func on_damaged(_attacker: Soldier, amount: int) -> void:
	shake(clampf(amount / 60.0, 0.1, 0.6))


func on_noise(_source: Soldier, _pos: Vector3) -> void:
	pass
