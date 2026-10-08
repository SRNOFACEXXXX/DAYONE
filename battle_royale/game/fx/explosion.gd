extends Node3D
## One-shot C4 explosion: fireball, debris, smoke column, light flash. Frees itself.

var _life := 0.0
var _light: OmniLight3D


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 38.0
	_light.light_energy = 14.0
	_light.shadow_enabled = false
	_light.position.y = 2.0
	add_child(_light)
	add_child(_fire())
	add_child(_smoke())
	add_child(_debris())


func _mat(tex: String, add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var p := "res://fx/textures/" + tex
	m.albedo_texture = load(p) if ResourceLoader.exists(p) else null
	return m


func _fire() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 42
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.92
	var qm := QuadMesh.new(); qm.size = Vector2(3.2, 3.2); qm.material = _mat("fireball.png", true)
	p.mesh = qm
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 13.0
	p.damping_min = 6.0
	p.damping_max = 10.0
	p.gravity = Vector3(0, 3.0, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	g.add_point(0.35, Color(1.0, 0.45, 0.12, 0.9))
	g.set_color(g.get_point_count() - 1, Color(0.2, 0.08, 0.03, 0.0))
	p.color_ramp = g
	p.position.y = 0.6
	p.emitting = true
	return p


func _smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 36
	p.lifetime = 5.5
	p.one_shot = true
	p.explosiveness = 0.7
	var qm := QuadMesh.new(); qm.size = Vector2(4.5, 4.5); qm.material = _mat("smoke_puff.png", false)
	p.mesh = qm
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.8
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.gravity = Vector3(0.4, 1.2, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.22, 0.2, 0.0))
	g.add_point(0.1, Color(0.3, 0.27, 0.24, 0.75))
	g.set_color(g.get_point_count() - 1, Color(0.55, 0.5, 0.45, 0.0))
	p.color_ramp = g
	p.position.y = 1.0
	p.emitting = true
	return p


func _debris() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 1.8
	p.one_shot = true
	p.explosiveness = 1.0
	var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.05, 0.1)
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.35, 0.3, 0.25)
	bm.material = m
	p.mesh = bm
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0, -20, 0)
	p.angular_velocity_min = -600.0
	p.angular_velocity_max = 600.0
	p.position.y = 0.3
	p.emitting = true
	return p


func _process(dt: float) -> void:
	_life += dt
	_light.light_energy = maxf(14.0 * (1.0 - _life / 0.9), 0.0)
	if _life > 6.0:
		queue_free()
