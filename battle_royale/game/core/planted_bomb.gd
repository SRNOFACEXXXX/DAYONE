class_name PlantedBomb
extends Node3D

const BOMB_WORLD := preload("res://assets/models/weapons/bomb_world.tscn")
## The planted C4: model, blinking LED, accelerating beeps, explosion hook.

var match_ref: Node
var total := 40.0
var time_left := 40.0
var _beep_acc := 0.0
var _led: OmniLight3D
var _led_mesh: MeshInstance3D
var _led_mat: StandardMaterial3D
var _flash := 0.0
var _done := false


func setup(m: Node, timer: float) -> void:
	match_ref = m
	total = timer
	time_left = timer
	var path := "res://assets/models/weapons/bomb_world.tscn"
	if ResourceLoader.exists(path):
		var model: Node3D = BOMB_WORLD.instantiate()
		add_child(model)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.21, 0.08, 0.15)
		mi.mesh = bm
		mi.position.y = 0.04
		add_child(mi)
	_led_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	_led_mesh.mesh = sm
	_led_mat = StandardMaterial3D.new()
	_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_led_mat.albedo_color = Color(1, 0.15, 0.1)
	_led_mesh.material_override = _led_mat
	_led_mesh.position = Vector3(0.05, 0.1, 0.0)
	add_child(_led_mesh)
	_led = OmniLight3D.new()
	_led.light_color = Color(1, 0.2, 0.1)
	_led.omni_range = 1.6
	_led.light_energy = 0.0
	_led.position = Vector3(0.05, 0.2, 0.0)
	_led.shadow_enabled = false
	add_child(_led)
	Audio.play_at("bomb_planted_beep", global_position, {"volume_db": 0.0, "max_distance": 45.0})


func set_time_left(v: float) -> void:
	time_left = v


func _process(dt: float) -> void:
	if _done:
		return
	_beep_acc += dt
	# intervalo do bip cai de ~1 s para ~0,1 s nos segundos finais
	var frac := clampf(time_left / total, 0.0, 1.0)
	var interval := lerpf(0.12, 1.0, pow(frac, 0.75))
	if time_left < 1.2:
		interval = 0.08
	if _beep_acc >= interval:
		_beep_acc = 0.0
		_flash = 1.0
		Audio.play_at("bomb_beep", global_position + Vector3.UP * 0.1, {"volume_db": 2.0, "unit_size": 5.0, "max_distance": 55.0, "pitch_var": 0.0, "pitch": 1.0 + (1.0 - frac) * 0.25})
	_flash = maxf(_flash - dt * 7.0, 0.0)
	_led.light_energy = _flash * 1.4
	_led_mat.albedo_color = Color(1, 0.15, 0.1).lerp(Color(0.25, 0.02, 0.02), 1.0 - _flash)


func defused() -> void:
	_done = true
	_led.light_energy = 0.0
	_led_mat.albedo_color = Color(0.1, 0.9, 0.2)
	Audio.play_at("bomb_defused_click", global_position, {"volume_db": 0.0, "max_distance": 30.0})


func explode() -> void:
	_done = true
	visible = false
