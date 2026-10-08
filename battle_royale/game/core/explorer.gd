extends CharacterBody3D
## Explorador da fase de construção: andar (WASD, Shift correr, Espaço pular), F alterna voo livre, Esc solta o mouse.

const WALK := 4.5
const RUN := 7.5
const FLY := 40.0
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var flying := false
var health := 100
var _hud_label: Label
var _ui_layer: CanvasLayer


func _ready() -> void:
	add_to_group("zombie_targets")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.65
	cam.far = 6000.0
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	_ui_layer = CanvasLayer.new()
	_ui_layer.visible = not Game.test_args.has("out")
	var label := Label.new()
	label.text = "DAYONE · EXPLORAR A ILHA\nWASD: mover  |  Mouse: olhar  |  Shift: correr\nF: voo livre  |  1 / 2 / 3: visitar abrigos  |  Esc: cursor"
	label.position = Vector2(20,20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	_ui_layer.add_child(label)
	add_child(_ui_layer)
	_hud_label = label


func receive_damage(amount: int, _attacker: Node3D = null) -> void:
	health = maxi(health - maxi(amount, 0), 0)
	if _hud_label:
		_hud_label.text = "DAYONE · SAÚDE %d / 100\nWASD: mover  |  Shift: correr  |  Espaço: pular\nF: voo livre  |  1 / 2 / 3: visitar abrigos  |  Esc: cursor" % health


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0022
		pitch = clampf(pitch - e.relative.y * 0.0022, -1.5, 1.5)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1, KEY_2, KEY_3:
				var site: Dictionary = preload("res://maps/ilha/refugios_gpt.gd").SITES[int(e.keycode - KEY_1)]
				var p: Vector2 = site.pos
				yaw = deg_to_rad(float(site.yaw))
				pitch = 0.0
				var offset := Basis(Vector3.UP,yaw) * Vector3(0,0,10)
				global_position = Vector3(p.x,0,-p.y)+offset
				global_position.y = get_parent().terrain.height_world(global_position.x,global_position.z)+.3
				flying = false
				velocity = Vector3.ZERO
				reset_physics_interpolation()
			KEY_F:
				flying = not flying
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(dt: float) -> void:
	rotation.y = yaw
	cam.rotation.x = pitch
	var inp := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if flying:
		var dir := (cam.global_basis * Vector3(inp.x, 0, inp.y)).normalized()
		var up := float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_CTRL))
		velocity = dir * FLY * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0) + Vector3.UP * up * FLY
		global_position += velocity * dt
		return
	var wish := (global_basis * Vector3(inp.x, 0, inp.y)).normalized() * (RUN if Input.is_key_pressed(KEY_SHIFT) else WALK)
	velocity.x = move_toward(velocity.x, wish.x, 40.0 * dt)
	velocity.z = move_toward(velocity.z, wish.z, 40.0 * dt)
	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = 6.5
	else:
		velocity.y -= 20.0 * dt
	move_and_slide()
