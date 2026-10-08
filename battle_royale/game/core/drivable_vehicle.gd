class_name DrivableVehicle
extends VehicleBody3D
## Sedã físico com suspensão, peças funcionais e câmeras interna/externa.

const MASS_KG := 1240.0
const MAX_FORWARD_MPS := 27.0
const MAX_REVERSE_MPS := 8.5
const ENGINE_FORCE_N := 6400.0
const REVERSE_FORCE_N := 3900.0
const SERVICE_BRAKE_N := 44.0
const HANDBRAKE_N := 72.0
const AERO_DOWNFORCE_COEFFICIENT := 0.7
const MAX_AERO_DOWNFORCE_N := 650.0
const MAX_STEER := deg_to_rad(25.0)
const WHEEL_RADIUS := 0.35538
const VISUAL_TIRE_CLEARANCE := 0.012
const WHEEL_X := 0.82291
const FRONT_Z := 1.58892
const REAR_Z := -1.35370
const DOOR_ANGLE := deg_to_rad(67.0)
## Módulos puros da dirigibilidade (preload: não dependem do cache global de class_name).
const Transmissao = preload("res://core/veiculo_powertrain.gd")
const Estab = preload("res://core/veiculo_estabilidade.gd")
## Aceleração lateral máxima que o pneu absorve (m/s²); com freio de mão é reduzida pelo fator de drift.
const ACEL_LATERAL_MAX := 9.0
## Hook opcional para chão sem tag (ex.: terreno de areia): Callable(x, z) -> "areia" | "grama" | "terra" ...
static var superficie_chao := Callable()

## Vida do carro (%), aderência lateral (1/s), fator de drift com freio de mão, dano por batida,
## tempo capotado até endireitar sozinho e inclinação visual da carroceria.
@export var vida_max := 100.0
@export var aderencia_lateral := 3.0
@export var aderencia_freio_mao := 0.55
## Batida só conta acima de 9 m/s de variação horizontal (lateral/frontal). Quicadas de terreno são ignoradas.
@export var limiar_impacto_mps := 9.0
@export var dano_por_mps := 2.6
@export var tempo_recuperacao := 2.5
## Rolagem/arfagem visual da carroceria. Padrão 0: as portas são filhas do modelo e o modelo gira com a
## carroceria; sem validar em partida real, deixamos desligado (ajuste > 0 só para teste).
@export var inclinacao_carroceria := 0.0
@export var arfagem_carroceria := 0.0
## Combustível simulado. Padrão desligado (não há posto no jogo): com false nunca consome e nunca corta o motor.
## Liga com --combustivel (Game.test_args) ou ao chamar abastecer().
@export var usar_combustivel := false

var driver: Soldier
var vehicle_kind := "sedan"
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(-9.0)
var first_person_camera := false
var _camera_cut_pending := true
var _wheels: Array[VehicleWheel3D] = []
var _front_wheels: Array[VehicleWheel3D] = []
var _rear_wheels: Array[VehicleWheel3D] = []
var _wheel_visuals: Dictionary = {}
var _panels := {}
var _panel_open := {}
var _panel_angles := {}
var _last_safe_transform := Transform3D.IDENTITY
var _safe_timer := 0.0
var _upright_hold := 0.0
var _entry_candidate: Soldier
var _entry_timer := -1.0
var _exit_timer := -1.0
var _parking := false
var _parking_timer := 0.0
var _door_open_sound: AudioStreamPlayer3D
var _door_close_sound: AudioStreamPlayer3D
## desempenho: estacionado (congelado, sem motorista, portas paradas) não processa nada por quadro
var _paineis_ativos := true
var _rodas_paradas_ok := false
## estado da dirigibilidade
var vida := 100.0
var _trem = Transmissao.new()
var _modelo: Node3D
var _fumaca: CPUParticles3D
var _vel_anterior := Vector3.ZERO
var _acel_suave := Vector3.ZERO
var _impacto_cooldown := 0.0
var _tempo_capotado := 0.0
var _freio_mao := false
var _freio_atual := 0.0


static func create_from_model(model: Node3D, kind: String) -> DrivableVehicle:
	var car := DrivableVehicle.new()
	car.name = "Dirigivel_" + kind.get_file()
	car.vehicle_kind = kind.get_file().trim_prefix("carro_").trim_suffix("_aberto")
	var parent := model.get_parent()
	var world := model.global_transform
	# RigidBody/VehicleWheel must enter the physics server at their final spawn
	# transform. Setting global_transform after add_child leaves the wheel ray
	# anchors at (0,0,0) for the first physics update.
	# The island detail container has a transformed parent; physics bodies under
	# transformed Node3D parents report wheel anchors in parent-local space.
	car.top_level = true
	car.transform = world
	parent.add_child(car)
	model.reparent(car, true)
	model.transform = Transform3D.IDENTITY
	car._build(model)
	return car


func _build(model: Node3D) -> void:
	mass = MASS_KG
	continuous_cd = true
	can_sleep = true
	linear_damp = 0.12
	angular_damp = 0.82
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.36, -0.08)
	collision_layer = Soldier.LAYER_WORLD
	collision_mask = Soldier.LAYER_WORLD | Soldier.LAYER_SOLDIER
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	# Deixa a suspensão resolver o primeiro passo antes de estacionar o corpo.
	# VehicleWheel3D congelado desde a criação pode inicializar seus pontos em 0,0,0.
	freeze = false
	add_to_group("drivable_vehicle")
	# Contatos reportados alimentam o dano por colisão (body_entered).
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	vida = vida_max
	if Game.test_args.has("combustivel"):
		usar_combustivel = true
	_last_safe_transform = global_transform

	var chassis_shape := CollisionShape3D.new()
	chassis_shape.name = "ChassisCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(1.76, 0.66, 4.35)
	chassis_shape.shape = box
	chassis_shape.position = Vector3(0, 0.74, -0.04)
	add_child(chassis_shape)

	var left_source: MeshInstance3D
	var right_source: MeshInstance3D
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := item as MeshInstance3D
		var low := String(mesh_node.name).to_lower()
		_apply_car_materials(mesh_node)
		if "wheelfl" in low:
			left_source = mesh_node
		elif "wheelfr" in low:
			right_source = mesh_node
		if "wheel" in low:
			mesh_node.visible = false
	assert(left_source != null and right_source != null, "car model requires separate front wheel meshes")
	# The wheel origin is the suspension stop; its rest length lowers the hub to
	# the tire's loaded ride height while leaving the chassis above the ground.
	# Âncoras 1,5 cm mais altas mantêm o mesmo curso/rest-length, mas assentam a
	# carroceria mais perto dos pneus como um sedã, sem deixar a mola afundar no fim.
	_make_wheel("FrontLeft", Vector3(WHEEL_X, .51, FRONT_Z), true, true, left_source)
	_make_wheel("FrontRight", Vector3(-WHEEL_X, .51, FRONT_Z), true, true, right_source)
	_make_wheel("RearLeft", Vector3(WHEEL_X, .51, REAR_Z), false, true, left_source)
	_make_wheel("RearRight", Vector3(-WHEEL_X, .51, REAR_Z), false, true, left_source)
	_build_panels(model)
	# A carroceria original estava visualmente alta sobre os pneus. Baixamos a
	# casca 4 cm sem mexer no curso das molas nem nos cubos físicos das rodas.
	model.position.y -= 0.04
	_modelo = model
	_build_audio()
	_build_motor()
	_build_fumaca()
	call_deferred("_finish_spawn")


func _apply_car_materials(part: MeshInstance3D) -> void:
	if part.mesh == null:
		return
	part.mesh = part.mesh.duplicate()
	var tex_root := "res://assets/models/cenario/carros/texturas_abertos/"
	var body_file: String = String({"sedan":"Car_color.png", "policia":"Car_Police.png", "taxi":"Car_Taxi.png"}.get(vehicle_kind, "Car_color.png"))
	for surface in part.mesh.get_surface_count():
		var old := part.mesh.surface_get_material(surface)
		var low := String(old.resource_name if old else part.mesh.surface_get_name(surface)).to_lower()
		var material := StandardMaterial3D.new()
		material.roughness = .78
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if "glass" in low or "vidro" in low:
			material.albedo_texture = load(tex_root + "Glass.png")
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(1, 1, 1, .28)
			material.roughness = .18
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		elif "detail" in low or "wheel" in low or "tire" in low or "radio" in low:
			material.albedo_texture = load(tex_root + "Car_details.png")
		elif "number" in low or "plate" in low:
			material.albedo_texture = load(tex_root + "Car_Number.png")
		else:
			material.albedo_texture = load(tex_root + String(body_file))
		part.mesh.surface_set_material(surface, material)


func _make_wheel(label: String, pos: Vector3, steering_wheel: bool, traction: bool, source: MeshInstance3D) -> void:
	var wheel := VehicleWheel3D.new()
	wheel.name = label
	wheel.position = pos
	wheel.wheel_radius = WHEEL_RADIUS
	# Mais comprimento em repouso posiciona o chassi sobre o pneu no ponto de carga;
	# o valor anterior deixava o assoalho do modelo afundar após entrar.
	wheel.wheel_rest_length = 0.24
	wheel.suspension_travel = 0.10
	# Setup de sedã de rua: a faixa 50–100 N/mm e damping 0–1 N·s/mm
	# segue a recomendação do VehicleWheel3D; valores 5.6/6.4 deixavam o curso
	# excessivamente amortecido e o chassi assentava dentro dos para-lamas.
	wheel.suspension_stiffness = 70.0
	wheel.damping_compression = 0.38
	wheel.damping_relaxation = 0.52
	wheel.suspension_max_force = 11000.0
	# A influência padrão deixa muito pouco torque anti-capotamento no chassis.
	# Para sedã de rua, maximizar a transferência de força da suspensão às rodas
	# mantém a carroceria baixa e reduz capotamentos em curvas e terreno irregular.
	wheel.wheel_roll_influence = 1.0
	wheel.wheel_friction_slip = 5.3 if steering_wheel else 5.9
	wheel.use_as_steering = steering_wheel
	wheel.use_as_traction = traction
	add_child(wheel)
	_wheels.append(wheel)
	if steering_wheel:
		_front_wheels.append(wheel)
	else:
		_rear_wheels.append(wheel)
	var visual := MeshInstance3D.new()
	visual.name = "OriginalWheelVisual"
	visual.mesh = source.mesh
	visual.material_override = source.material_override
	# VehicleWheel3D gira em torno da origem da conexão da suspensão, não do cubo.
	# O visual fica top-level para poder colocar o centro no cubo real sem orbitar
	# quando a suspensão comprime. Direção e rotação da roda são aplicadas abaixo.
	visual.top_level = true
	# A pose é atualizada todo frame a partir do transform interpolado do chassi;
	# deixar a interpolação automática ligada neste top-level aplicava um segundo
	# atraso e fazia a malha entrar na carroceria em movimento.
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var visual_basis_in_car := global_basis.inverse() * source.global_basis
	visual.basis = visual_basis_in_car
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	wheel.add_child(visual)
	visual.global_basis = global_basis * visual_basis_in_car
	var spawn_hub := global_transform * (wheel.position + Vector3.DOWN * wheel.wheel_rest_length)
	visual.global_position = spawn_hub - visual.global_basis * source.get_aabb().get_center()
	_wheel_visuals[wheel] = {"node": visual, "basis": visual_basis_in_car, "roll": 0.0}


func _build_panels(model: Node3D) -> void:
	var specs := {
		"door_fl": ["door_fl", Vector3(.912732, .687371, .956567), Vector3(0, -DOOR_ANGLE, 0)],
		"door_fr": ["door_fr", Vector3(-.912732, .687371, .956567), Vector3(0, DOOR_ANGLE, 0)],
		"door_bl": ["door_bl", Vector3(.933020, .870250, -.146058), Vector3(0, -DOOR_ANGLE, 0)],
		"door_br": ["door_br", Vector3(-.933020, .870250, -.146058), Vector3(0, DOOR_ANGLE, 0)],
		"hood": ["hood", Vector3(0, .996423, .954150), Vector3(deg_to_rad(-58), 0, 0)],
		"trunk": ["trunk", Vector3(0, 1.038449, -1.589859), Vector3(deg_to_rad(62), 0, 0)],
	}
	for panel_name in specs:
		var data: Array = specs[panel_name]
		var part: MeshInstance3D
		for item in model.find_children("*", "MeshInstance3D", true, false):
			if String(data[0]) in String(item.name).to_lower():
				part = item as MeshInstance3D
				break
		if part == null:
			continue
		var pivot := Node3D.new()
		pivot.name = "Pivot_" + panel_name
		pivot.position = data[1]
		model.add_child(pivot)
		part.reparent(pivot, true)
		_panels[panel_name] = pivot
		_panel_open[panel_name] = false
		_panel_angles[panel_name] = data[2]


func _build_audio() -> void:
	_door_open_sound = AudioStreamPlayer3D.new()
	_door_open_sound.name = "DoorOpenSound"
	_door_open_sound.stream = load("res://assets/audio/vehicle/door_open.wav")
	_door_open_sound.max_distance = 26.0
	add_child(_door_open_sound)
	_door_close_sound = AudioStreamPlayer3D.new()
	_door_close_sound.name = "DoorCloseSound"
	_door_close_sound.stream = load("res://assets/audio/vehicle/door_close.wav")
	_door_close_sound.max_distance = 26.0
	add_child(_door_close_sound)


## Motor: 3 laços CC0 (marcha lenta / média / alta, OpenGameArt 'racing car engine sound loops') com pitch pela
## rotação simulada (curva de torque + 5 marchas em core/veiculo_powertrain.gd) e crossfade; liga ao entrar, apaga suave ao sair.
var _mot: Array = []
var _mot_vol := 0.0
var _thr := 0.0
var _rpm := 0.0


func _build_motor() -> void:
	for id in ["engine_idle", "engine_mid", "engine_high"]:
		var p := Audio.loop_player_3d(id)
		if p:
			p.volume_db = -80.0
			add_child(p)
			_mot.append(p)


## Fumaça do capô: liga com a vida abaixo de 30% (ver veiculo_estabilidade.gd).
func _build_fumaca() -> void:
	_fumaca = CPUParticles3D.new()
	_fumaca.name = "FumacaMotor"
	_fumaca.position = Vector3(0, 1.0, 1.4)
	_fumaca.amount = 24
	_fumaca.lifetime = 1.6
	_fumaca.direction = Vector3.UP
	_fumaca.spread = 18.0
	_fumaca.initial_velocity_min = 0.6
	_fumaca.initial_velocity_max = 1.2
	_fumaca.gravity = Vector3(0, 0.4, 0)
	_fumaca.scale_amount_min = 0.4
	_fumaca.scale_amount_max = 0.9
	var malha := QuadMesh.new()
	malha.size = Vector2(0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.12, 0.12, 0.12, 0.6)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	malha.material = mat
	_fumaca.mesh = malha
	_fumaca.emitting = false
	add_child(_fumaca)


func _atualizar_motor(dt: float) -> void:
	var ligado := driver != null and vida > 0.0 and _tem_combustivel()
	var v_frente := absf((global_basis.inverse() * linear_velocity).z)
	_trem.atualizar(dt, v_frente, absf(_thr) if ligado else 0.0, ligado)
	if ligado and usar_combustivel:
		_trem.consumir(dt, absf(_thr))
	_atualizar_fumaca()
	if _mot.size() < 3:
		return
	if not ligado and _mot_vol <= 0.0:
		return
	_mot_vol = move_toward(_mot_vol, 1.0 if ligado else 0.0, dt * (2.5 if ligado else 1.4))
	if _mot_vol <= 0.0:
		for p in _mot:
			(p as AudioStreamPlayer3D).stop()
		return
	_rpm = _trem.rpm_norm()
	var w_idle := clampf(1.0 - _rpm * 2.4, 0.0, 1.0)
	var w_high := clampf((_rpm - 0.4) * 2.4, 0.0, 1.0)
	var w_mid := clampf(1.0 - w_idle - w_high + 0.15, 0.0, 1.0)
	var pitches := [lerpf(0.85, 1.5, _rpm), lerpf(0.8, 1.25, _rpm), lerpf(0.78, 1.15, _rpm)]
	var pesos := [w_idle, w_mid, w_high]
	var base_db := -7.0 + 5.0 * absf(_thr) + 4.0 * _rpm
	for i in 3:
		var p: AudioStreamPlayer3D = _mot[i]
		p.pitch_scale = pitches[i]
		p.volume_db = base_db + linear_to_db(maxf(pesos[i], 0.0001)) + linear_to_db(maxf(_mot_vol, 0.0001))
		if not p.playing:
			p.play(randf() * 0.3)


func _atualizar_fumaca() -> void:
	if _fumaca == null:
		return
	var ligada := Estab.fumaca_ligada(vida_frac())
	if _fumaca.emitting != ligada:
		_fumaca.emitting = ligada


func _finish_spawn() -> void:
	# A roda precisa carregar o peso e o chassi precisa assentar antes de o carro
	# ser congelado como veículo estacionado. Congelar após apenas dois passos
	# guardava a pose inicial sem carga; ao entrar, a carroceria caía ~20 cm dentro
	# dos para-lamas/terreno enquanto as molas encontravam o equilíbrio.
	for _i in 30:
		await get_tree().physics_frame
	# As coordenadas da ilha já vêm do heightmap. Não reposicionar pelo raycast:
	# no mapa extenso, a origem física do terreno pode divergir da visual.
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true
	_last_safe_transform = global_transform
	_sync_wheel_visuals()


func _physics_process(dt: float) -> void:
	# Aceleração do quadro anterior (rolagem visual) e velocidade antes do passo de física (impacto).
	var acel_mundo := (linear_velocity - _vel_anterior) / maxf(dt, 0.0001)
	_vel_anterior = linear_velocity
	_impacto_cooldown = maxf(_impacto_cooldown - dt, 0.0)
	_atualizar_motor(dt)
	if freeze and driver == null and _entry_timer < 0.0 and _exit_timer < 0.0 and not _parking and not _paineis_ativos:
		return
	_animate_panels(dt)
	_update_entry_exit(dt)
	if driver != null and (not is_instance_valid(driver) or not driver.alive):
		_finish_exit()
	if driver != null:
		_drive(dt)
	else:
		engine_force = 0.0
		brake = 8.0 if not freeze else 0.0
		_freio_mao = false
	if not freeze:
		_atualizar_estabilidade(dt, acel_mundo)
	if _parking:
		_parking_timer += dt
		brake = HANDBRAKE_N
		if linear_velocity.length() < .28 or _parking_timer > 2.2:
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			freeze = true
			_parking = false
	_safe_timer += dt
	if _safe_timer > .8:
		_safe_timer = 0.0
		if global_basis.y.dot(Vector3.UP) > .62 and linear_velocity.length() < 13.0:
			_last_safe_transform = global_transform
	if global_position.y < -8.0:
		_reset_to_safe()
	if driver:
		driver.global_position = global_transform * Vector3(.42, 1.0, .25)


func _process(dt: float) -> void:
	if freeze and driver == null:
		if _rodas_paradas_ok:
			return
		_rodas_paradas_ok = true
	else:
		_rodas_paradas_ok = false
	_sync_wheel_visuals(dt)


func _sync_wheel_visuals(dt: float = 0.0) -> void:
	var physics_xf := global_transform
	var render_xf := get_global_transform_interpolated()
	for wheel in _wheels:
		if not _wheel_visuals.has(wheel):
			continue
		var state: Dictionary = _wheel_visuals[wheel]
		var visual := state["node"] as MeshInstance3D
		if visual == null or visual.mesh == null:
			continue
		var roll := float(state["roll"]) + wheel.get_rpm() * TAU / 60.0 * dt
		state["roll"] = roll
		_wheel_visuals[wheel] = state
		var steer := wheel.steering if wheel.use_as_steering else 0.0
		var steer_basis := Basis(Vector3.UP, steer)
		var roll_basis := Basis(Vector3.RIGHT, roll)
		var visual_basis: Basis = render_xf.basis.orthonormalized() * steer_basis * roll_basis * state["basis"]
		visual.global_basis = visual_basis
		var hub_local := wheel.position + Vector3.DOWN * wheel.wheel_rest_length
		if wheel.is_in_contact():
			var normal := wheel.get_contact_normal().normalized()
			if normal.length_squared() > .5:
				# O corpo principal é renderizado interpolado entre passos de física.
				# Como esta roda é uma malha top-level, convertemos o cubo medido no
				# passo físico para o espaço local do chassi e o reaplicamos à mesma
				# transformação interpolada. Sem isso a carroceria passava pela roda.
				var hub_physics := wheel.get_contact_point() + normal * (wheel.wheel_radius + VISUAL_TIRE_CLEARANCE)
				hub_local = physics_xf.affine_inverse() * hub_physics
		var hub_world := render_xf * hub_local
		visual.global_position = hub_world - visual_basis * visual.get_aabb().get_center()


func _drive(dt: float) -> void:
	var blocked := driver.controller != null and bool(driver.controller.ui_blocking)
	var throttle := 0.0 if blocked else Input.get_axis("move_back", "move_forward")
	_thr = throttle
	var turn := 0.0 if blocked else Input.get_axis("move_left", "move_right")
	var local_velocity := global_basis.inverse() * linear_velocity
	var forward_speed := local_velocity.z
	var speed := linear_velocity.length()
	var kmh := speed * 3.6
	# Esterço: menos ângulo conforme a velocidade sobe; o volante volta ao centro sem snap.
	steering = move_toward(steering, -turn * MAX_STEER * Estab.fator_direcao(kmh), dt * Estab.taxa_direcao(turn, kmh))
	var freio := 0.0
	var motor := 0.0
	if throttle > .05:
		if forward_speed < -1.0:
			freio = SERVICE_BRAKE_N * throttle
		elif forward_speed < MAX_FORWARD_MPS:
			motor = ENGINE_FORCE_N * throttle * _fator_motor() * (1.0 - .42 * clampf(forward_speed / MAX_FORWARD_MPS, 0.0, 1.0))
	elif throttle < -.05:
		if forward_speed > 1.0:
			freio = SERVICE_BRAKE_N * -throttle
		elif forward_speed > -MAX_REVERSE_MPS:
			# Ré: força cai conforme ganha velocidade para trás (sem disparo de marcha ré).
			motor = REVERSE_FORCE_N * throttle * _fator_motor() * (1.0 - .5 * clampf(-forward_speed / MAX_REVERSE_MPS, 0.0, 1.0))
	else:
		freio = 2.5
	_freio_mao = not blocked and Input.is_action_pressed("jump")
	if _freio_mao:
		freio = HANDBRAKE_N
		motor = 0.0
	# Freio com rampa: o pedal não vai de 0 a 44 de um quadro para o outro.
	_freio_atual = move_toward(_freio_atual, freio, dt * (600.0 if freio > _freio_atual else 900.0))
	brake = _freio_atual
	engine_force = motor
	# Tração por superfície: a roda traseira perde tração em areia/água; freio de mão solta a traseira.
	for rear in _rear_wheels:
		var f_r: Vector2 = _fator_roda(rear)
		rear.wheel_friction_slip = (2.1 if _freio_mao else 5.9) * f_r.y
	for front in _front_wheels:
		var f_f: Vector2 = _fator_roda(front)
		front.wheel_friction_slip = 5.3 * f_f.x
	# Carga aerodinâmica leve: a força antiga (até 5200 N) somava 42% do peso
	# do carro e comprimia demais a suspensão justamente em velocidade alta.
	apply_central_force(Vector3.DOWN * minf(speed * speed * AERO_DOWNFORCE_COEFFICIENT, MAX_AERO_DOWNFORCE_N))
	if not blocked and Input.is_action_pressed("reload") and speed < 1.2:
		_upright_hold += dt
		if _upright_hold >= 1.0:
			_reset_to_safe()
			_upright_hold = 0.0
	else:
		_upright_hold = 0.0


## Fator de torque do motor (curva e marcha, troca, vida e combustível). 0 = motor parado.
func _fator_motor() -> float:
	if vida <= 0.0 or not _tem_combustivel():
		return 0.0
	# Carro muito batido perde potência: 100% acima de 60% de vida, 50% com a vida zerada.
	var saude := clampf(vida / maxf(vida_max, 1.0) / 0.6, 0.0, 1.0)
	return _trem.fator_torque() * lerpf(0.5, 1.0, saude)


## Aderência (x) e tração (y) da roda pela superfície do ponto de contato. Fora do chão = 1.
func _fator_roda(wheel: VehicleWheel3D) -> Vector2:
	if not wheel.is_in_contact():
		return Vector2.ONE
	return Estab.perfil_superficie(_nome_superficie(wheel))


func _nome_superficie(wheel: VehicleWheel3D) -> String:
	var ponto := wheel.get_contact_point()
	if Soldier.agua_fn.is_valid():
		# Represa: abaixo da superfície. Mar (nível 0 fora da represa): só se a roda estiver submersa.
		var nivel := float(Soldier.agua_fn.call(ponto.x, ponto.z))
		var limite := nivel + 0.05 if nivel > 0.0 else -0.15
		if ponto.y < limite:
			return "agua"
	var corpo := wheel.get_contact_body()
	if corpo != null and corpo.has_meta("surface"):
		return str(corpo.get_meta("surface"))
	if superficie_chao.is_valid():
		return str(superficie_chao.call(ponto.x, ponto.z))
	return "asfalto"


## Dinâmica por quadro com o carro livre: aderência lateral (drift com freio de mão), trava de
## rolagem/arfagem no chão, inclinação visual da carroceria e endireitar após capotar.
func _atualizar_estabilidade(dt: float, acel_mundo: Vector3) -> void:
	var inv := global_basis.inverse()
	_acel_suave = _acel_suave.lerp(inv * acel_mundo, 1.0 - exp(-dt * 8.0))
	if _modelo:
		_modelo.rotation = Vector3(-_acel_suave.z * arfagem_carroceria, 0.0, _acel_suave.x * inclinacao_carroceria)
	if Estab.esta_capotado(global_basis.y.dot(Vector3.UP)):
		_tempo_capotado += dt
		if _tempo_capotado >= tempo_recuperacao and linear_velocity.length() < 5.0:
			_endireitar()
	else:
		_tempo_capotado = 0.0
	var soma := 0.0
	var contatos := 0
	for w in _wheels:
		if w.is_in_contact():
			contatos += 1
			soma += _fator_roda(w).x
	if contatos == 0:
		return
	var aderencia := soma / float(contatos)
	# Pneu absorve a velocidade lateral por quadro, com limite de aceleração. Com freio de mão
	# a absorção cai e o limite também, então o carro derrapa de forma controlada.
	var v_lat := (inv * linear_velocity).x
	var fator_mao := aderencia_freio_mao if _freio_mao else 1.0
	var taxa := aderencia_lateral * aderencia * fator_mao
	var limite := ACEL_LATERAL_MAX * fator_mao * dt
	var dv := clampf(v_lat * clampf(taxa * dt, 0.0, 0.9), -limite, limite)
	if absf(dv) > 0.0:
		apply_central_impulse(-global_basis.x * dv * mass)
	# Trava de rolagem/arfagem enquanto há contato com o chão (2+ rodas): reduz o balanço sem travar a guinada.
	if contatos >= 2:
		var ang := inv * angular_velocity
		var amortece := exp(-dt * 3.0)
		ang.x *= amortece
		ang.z *= amortece
		angular_velocity = global_basis * ang


## Endireita o carro capotado mantendo a direção horizontal, um pouco acima do ponto atual.
func _endireitar() -> void:
	var frente := global_basis.z
	var plano := Vector3(frente.x, 0.0, frente.z)
	if plano.length_squared() < 0.01:
		plano = Vector3(global_basis.x.x, 0.0, global_basis.x.z)
	if plano.length_squared() < 0.0001:
		plano = Vector3(0, 0, 1)
	plano = plano.normalized()
	# A frente da carroceria é +Z; Basis.looking_at aponta -Z para o alvo, então usamos -plano.
	global_transform = Transform3D(Basis.looking_at(-plano, Vector3.UP), global_position + Vector3.UP * 1.1)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_tempo_capotado = 0.0


## Dano por colisão: a variação de velocidade da batida (m/s) acima do limiar vira % de vida.
func _on_body_entered(body: Node) -> void:
	if freeze or body == driver or _impacto_cooldown > 0.0 or vida <= 0.0:
		return
	# Terreno (chassi batendo no relevo) não é batida: ver Estab.e_terreno e dano_colisao.
	if Estab.e_terreno(String(body.name)):
		return
	var dano := Estab.dano_colisao(_vel_anterior - linear_velocity, limiar_impacto_mps, dano_por_mps)
	if dano <= 0.0:
		return
	_impacto_cooldown = 0.25
	vida = maxf(vida - dano, 0.0)


func start_entry(s: Soldier) -> bool:
	if not can_enter(s) or _entry_timer >= 0.0:
		return false
	_entry_candidate = s
	_entry_timer = 0.0
	set_panel_open("door_fl", true)
	return true


func start_exit() -> bool:
	if driver == null or _exit_timer >= 0.0 or linear_velocity.length() > 1.4:
		return false
	_exit_timer = 0.0
	set_panel_open("door_fl", true)
	return true


func exit_vehicle() -> void:
	# Mantém compatibilidade com testes/sistemas antigos; durante o jogo a saída
	# normal usa start_exit para tocar e mostrar a porta antes de soltar o jogador.
	_finish_exit()


func _update_entry_exit(dt: float) -> void:
	if _entry_timer >= 0.0:
		_entry_timer += dt
		if _entry_timer >= .46:
			var candidate := _entry_candidate
			_entry_timer = -1.0
			_entry_candidate = null
			if candidate and is_instance_valid(candidate) and candidate.global_position.distance_to(global_position) < 5.2:
				enter_vehicle(candidate)
			set_panel_open("door_fl", false)
	if _exit_timer >= 0.0:
		_exit_timer += dt
		if _exit_timer >= .42:
			_exit_timer = -1.0
			_finish_exit()
			set_panel_open("door_fl", false)


func enter_vehicle(s: Soldier) -> bool:
	if not can_enter(s):
		return false
	freeze = false
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	driver = s
	s.external_motion = true
	s.frozen = true
	s.velocity = Vector3.ZERO
	s.collision_layer = 0
	s.collision_mask = 0
	s.set_hitboxes_enabled(false)
	if s.body_model:
		s.body_model.visible = false
	if s.controller and s.controller.has_method("attach_vehicle"):
		s.controller.attach_vehicle(self)
	return true


func can_enter(s: Soldier) -> bool:
	return driver == null and _entry_timer < 0.0 and s != null and s.alive and (freeze or linear_velocity.length() < 1.5)


func _finish_exit() -> void:
	if driver == null:
		return
	var s := driver
	driver = null
	# A saída só é aceita quase parado. Estaciona no mesmo frame antes de devolver
	# a colisão ao personagem, eliminando a janela em que ele conseguia empurrar.
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	var side := global_basis.x.normalized()
	var chosen := global_position + side * 2.05 + Vector3.UP * .4
	var space := get_world_3d().direct_space_state
	for sign in [1.0, -1.0]:
		var candidate: Vector3 = global_position + side * 2.05 * sign + Vector3.UP * 1.4
		var query := PhysicsRayQueryParameters3D.create(candidate, candidate + Vector3.DOWN * 4.0, Soldier.LAYER_WORLD, [get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			chosen = hit.position + Vector3.UP * .08
			break
	s.global_position = chosen
	s.velocity = Vector3.ZERO
	s.external_motion = false
	s.frozen = false
	s.collision_layer = Soldier.LAYER_SOLDIER
	s.collision_mask = Soldier.LAYER_WORLD | Soldier.LAYER_SOLDIER
	s.set_hitboxes_enabled(true)
	if s.body_model:
		s.body_model.visible = true
	if s.controller and s.controller.has_method("detach_vehicle"):
		s.controller.detach_vehicle(self)
	_parking = false
	_parking_timer = 0.0
	_freio_mao = false


func set_panel_open(panel: String, opened: bool) -> void:
	if not _panels.has(panel) or bool(_panel_open.get(panel, false)) == opened:
		return
	_panel_open[panel] = opened
	_paineis_ativos = true
	var sound := _door_open_sound if opened else _door_close_sound
	if sound and sound.stream:
		sound.pitch_scale = randf_range(.96, 1.04)
		sound.play()


func toggle_panel(panel: String) -> void:
	if linear_velocity.length() < .7:
		set_panel_open(panel, not bool(_panel_open.get(panel, false)))


func _animate_panels(dt: float) -> void:
	var mexeu := false
	for panel_name in _panels:
		var pivot := _panels[panel_name] as Node3D
		var target: Vector3 = _panel_angles[panel_name] if bool(_panel_open[panel_name]) else Vector3.ZERO
		pivot.rotation.x = move_toward(pivot.rotation.x, target.x, dt * 2.9)
		pivot.rotation.y = move_toward(pivot.rotation.y, target.y, dt * 3.8)
		pivot.rotation.z = move_toward(pivot.rotation.z, target.z, dt * 3.8)
		if not pivot.rotation.is_equal_approx(target):
			mexeu = true
	_paineis_ativos = mexeu


func handle_panel_key(keycode: Key) -> bool:
	var mapping := {KEY_1:"door_fl", KEY_2:"door_fr", KEY_3:"door_bl", KEY_4:"door_br", KEY_H:"hood", KEY_T:"trunk"}
	if not mapping.has(keycode):
		return false
	toggle_panel(mapping[keycode])
	return true


func toggle_camera() -> void:
	first_person_camera = not first_person_camera
	camera_yaw = 0.0
	camera_pitch = 0.0 if first_person_camera else deg_to_rad(-9.0)
	_camera_cut_pending = true


func add_look(delta: Vector2) -> void:
	camera_yaw -= delta.x * Settings.sensitivity * 0.00038
	camera_pitch = clampf(camera_pitch - delta.y * Settings.sensitivity * 0.00032,
		deg_to_rad(-25 if first_person_camera else -32), deg_to_rad(18))
	if first_person_camera:
		camera_yaw = clampf(camera_yaw, deg_to_rad(-85), deg_to_rad(85))


func update_camera(camera: Camera3D, dt: float) -> void:
	var car_xf := get_global_transform_interpolated()
	if first_person_camera:
		# A carroceria tem a frente em +Z, enquanto Camera3D olha por -Z. O giro de
		# 180° alinha os olhos com o para-brisa em vez de mirar os bancos traseiros.
		# Mantenha a câmera presa ao referencial visual do carro. Interpolar a
		# posição em coordenadas globais fazia ela ficar para trás em acelerações
		# fortes, atravessando o encosto do banco. O ponto também fica acima e à
		# frente do encosto para não deixar o banco ocupar a visão do motorista.
		var seat := car_xf * Vector3(.42, 1.12, -.28)
		var local_look := Basis.from_euler(Vector3(camera_pitch, PI + camera_yaw, 0), EULER_ORDER_YXZ)
		var wanted_basis := car_xf.basis * local_look
		if _camera_cut_pending:
			camera.global_position = seat
			camera.global_basis = wanted_basis
			_camera_cut_pending = false
		else:
			camera.global_position = seat
			camera.global_basis = camera.global_basis.slerp(wanted_basis, 1.0 - exp(-dt * 21.0))
		camera.fov = lerpf(camera.fov, 69.0, 1.0 - exp(-dt * 8.0))
		return
	var focus := car_xf * Vector3(0, 1.05, .15)
	var orbit := Basis.from_euler(Vector3(-camera_pitch, camera_yaw, 0.0), EULER_ORDER_YXZ)
	var desired := focus + car_xf.basis * (orbit * Vector3(0, .75, -6.2))
	var query := PhysicsRayQueryParameters3D.create(focus, desired, Soldier.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + (focus - desired).normalized() * .28
	if _camera_cut_pending:
		camera.global_position = desired
		_camera_cut_pending = false
	else:
		camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-dt * 8.0))
	var velocity_look := linear_velocity * .32
	camera.global_basis = camera.global_basis.slerp(Basis.looking_at((focus + velocity_look - camera.global_position).normalized(), Vector3.UP), 1.0 - exp(-dt * 10.0))
	camera.fov = lerpf(camera.fov, 72.0 + minf(linear_velocity.length() * .32, 8.0), 1.0 - exp(-dt * 4.0))


func speed_kmh() -> int:
	return roundi(linear_velocity.length() * 3.6)


## Rotação do motor (RPM) para HUD. Parado/desligado = 0.
func rpm_hud() -> int:
	return roundi(_trem.rpm)


## Marcha atual para HUD (1..5).
func marcha_atual() -> int:
	return _trem.marcha_humana()


## Fração do tanque (0..1).
func combustivel_frac() -> float:
	return _trem.fracao_combustivel()


## Abastecer liga o consumo de combustível (usar_combustivel) e enche o tanque em `litros`.
func abastecer(litros: float) -> void:
	usar_combustivel = true
	_trem.abastecer(litros)


## Rotação do motor como fração do limite (0..1) para barra de RPM.
func rpm_frac() -> float:
	return _trem.rpm_norm()


func _tem_combustivel() -> bool:
	return not usar_combustivel or _trem.tem_combustivel()


## Fração da vida do carro (0..1). Fumaça abaixo de 30%; vida zero desliga o motor.
func vida_frac() -> float:
	return clampf(vida / maxf(vida_max, 1.0), 0.0, 1.0)


func reparar(pontos: float) -> void:
	vida = minf(vida + maxf(pontos, 0.0), vida_max)


func display_name() -> String:
	return {"sedan":"Sedã", "taxi":"Táxi", "policia":"Viatura"}.get(vehicle_kind, "Carro")


func reset_if_stuck() -> void:
	if driver and linear_velocity.length() < 2.0:
		_reset_to_safe()


func _reset_to_safe() -> void:
	freeze = false
	global_transform = _last_safe_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steering = 0.0
