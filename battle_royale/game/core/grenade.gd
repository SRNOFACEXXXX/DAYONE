class_name Grenade
extends RigidBody3D
## Granada de fragmentação (tecla G): pavio de 2,5 s, dano em raio com queda linear; o autor recebe metade do dano.

const PAVIO := 2.5
const RAIO := 7.0
const DANO := 110.0

var autor: Soldier
var _t := 0.0


static func lancar(match_ref: Node, de: Soldier, origem: Vector3, direcao: Vector3) -> void:
	var g := Grenade.new()
	g.autor = de
	match_ref.add_child(g)
	g.global_position = origem
	g.linear_velocity = direcao * 14.0 + Vector3.UP * 2.5
	g.angular_velocity = Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))


func _ready() -> void:
	collision_layer = 0
	collision_mask = Soldier.LAYER_WORLD
	mass = 0.4
	continuous_cd = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.06
	cs.shape = sh
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	physics_material_override = pm
	var vis: Node3D = load("res://assets/models/weapons/wf/rgd5.glb").instantiate()
	vis.position.y = -0.06
	add_child(vis)


func _physics_process(dt: float) -> void:
	_t += dt
	if _t >= PAVIO:
		_explodir()


func _explodir() -> void:
	var m := get_parent()
	var centro := global_position + Vector3.UP * 0.2
	if m and "soldiers" in m:
		for s: Soldier in m.soldiers:
			if not s.alive:
				continue
			var d := s.global_position.distance_to(centro)
			if d > RAIO:
				continue
			var q := PhysicsRayQueryParameters3D.create(centro, s.global_position + Vector3.UP * 1.0, 1)
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				continue   # parede no meio: sem dano
			var f := 1.0 - d / RAIO
			var dano := DANO * f * (0.5 if s == autor else 1.0)
			s.take_damage(dano, autor, null, "chest", (s.global_position - centro).normalized())
	# zumbis: dano linear até RAIO (180 pontos no centro; morrem a ~3 m)
	ZombieEnemy.explosao(self, centro, RAIO, 180, autor)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 60
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.45
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	p.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(1.0, 0.6, 0.15)
	p.material_override = mt
	m.add_child(p)
	p.global_position = centro
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.65, 0.3)
	luz.omni_range = 14.0
	luz.light_energy = 8.0
	m.add_child(luz)
	luz.global_position = centro
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.4)
	tw.tween_callback(luz.queue_free)
	m.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	Audio.play_at("buy", centro, {"volume_db": 4.0, "max_distance": 120.0})
	queue_free()
