class_name FxManager
extends Node3D
## Pooled combat effects: tracers, 3rd-person muzzle flashes, impact marks, dust, sparks, blood, explosion.

const MAX_MARKS := 160
const TEX := "res://fx/textures/"

var _marks: MultiMeshInstance3D
var _blood_marks: MultiMeshInstance3D
var _mark_i := 0
var _blood_i := 0
var _tracers: Array[MeshInstance3D] = []
var _tracer_life: Array[float] = []
var _tracer_i := 0
var _puffs: Array[CPUParticles3D] = []
var _puff_i := 0
var _sparks: Array[CPUParticles3D] = []
var _spark_i := 0
var _blood: Array[CPUParticles3D] = []
var _blood_i2 := 0
var _flashes: Array[Node3D] = []
var _flash_life: Array[float] = []
var _flash_i := 0
var _shot_count: Dictionary = {}
# sangue: gotas com gravidade, jatos de saída, pedaços (tiro na cabeça), poças de morte
var _drops: Array[CPUParticles3D] = []
var _drop_i := 0
var _chunks: Array[CPUParticles3D] = []
var _chunk_i := 0
var _sprays: Array[MeshInstance3D] = []
var _spray_life: Array[float] = []
var _spray_i := 0
var _pools: Array[MeshInstance3D] = []
var _pool_grow: Array[float] = []
var _pool_i := 0

const SURFACE_DUST := {
	"sand": Color(0.82, 0.68, 0.48, 0.8),
	"stone": Color(0.78, 0.72, 0.62, 0.8),
	"plaster": Color(0.9, 0.84, 0.72, 0.85),
	"wood": Color(0.55, 0.40, 0.26, 0.8),
	"metal": Color(0.5, 0.5, 0.5, 0.5),
	"cloth": Color(0.7, 0.6, 0.5, 0.5),
	"knife": Color(0.8, 0.75, 0.65, 0.6),
}


## Instância ativa (zumbis e granadas acham o FX sem depender de Match).
static var shared: FxManager


func _enter_tree() -> void:
	shared = self


func _exit_tree() -> void:
	if shared == self:
		shared = null


func _ready() -> void:
	_marks = _make_marks(TEX + "bullet_hole.png", 0.075)
	_blood_marks = _make_marks(TEX + "blood_splat.png", 0.55)
	for i in 24:
		var tr := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.018, 1.0)
		tr.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.82, 0.45, 0.9)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		tr.material_override = m
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tr.visible = false
		add_child(tr)
		_tracers.append(tr)
		_tracer_life.append(0.0)
	for i in 10:
		_puffs.append(_make_puff())
	for i in 6:
		_sparks.append(_make_sparks())
	for i in 8:
		_blood.append(_make_blood())
	for i in 8:
		_drops.append(_make_drops())
	for i in 4:
		_chunks.append(_make_chunks())
	for i in 10:
		var sp := MeshInstance3D.new()
		var qm2 := QuadMesh.new()
		qm2.size = Vector2(1.0, 0.5)
		qm2.center_offset = Vector3(0.5, 0, 0)     # nasce no ponto de saída e se estende para +X
		sp.mesh = qm2
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_texture = _tex("blood_spray.png")
		sp.material_override = sm
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.visible = false
		add_child(sp)
		_sprays.append(sp)
		_spray_life.append(0.0)
	for i in 10:
		var pl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.0, 1.0)
		pl.mesh = pm
		var plm := StandardMaterial3D.new()
		plm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plm.albedo_texture = _tex("blood_pool.png")
		plm.roughness = 0.45          # úmido, sem refletir o céu azul (antes ficava arroxeado)
		plm.metallic_specular = 0.3
		plm.albedo_color = Color(0.85, 0.8, 0.8)
		pl.material_override = plm
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pl.visible = false
		add_child(pl)
		_pools.append(pl)
		_pool_grow.append(-1.0)
	for i in 12:
		var f := _make_flash()
		_flashes.append(f)
		_flash_life.append(0.0)


func _tex(name: String) -> Texture2D:
	var p := TEX + name
	return load(p) if ResourceLoader.exists(p) else null


func _make_marks(tex_path: String, size: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	mm.mesh = qm
	mm.instance_count = MAX_MARKS
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load(tex_path) if ResourceLoader.exists(tex_path) else null
	m.albedo_color = Color(1, 1, 1, 1)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 300, 1000))
	add_child(mi)
	return mi


func _particle_mat(tex: String, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex(tex)
	return m


func _make_puff() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.9
	p.explosiveness = 0.95
	var qm := QuadMesh.new()
	qm.size = Vector2(0.22, 0.22)
	qm.material = _particle_mat("smoke_puff.png")
	p.mesh = qm
	p.direction = Vector3(0, 0, 1)
	p.spread = 28.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1.2, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.35
	p.explosiveness = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.03)
	qm.material = _particle_mat("spark.png", true)
	p.mesh = qm
	p.direction = Vector3(0, 0, 1)
	p.spread = 55.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -14, 0)
	p.color = Color(1.0, 0.8, 0.4)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_blood() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.55
	p.explosiveness = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	qm.material = _particle_mat("blood_puff.png")
	p.mesh = qm
	p.direction = Vector3(0, 0, 1)
	p.spread = 30.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.02, 0.02, 0.95))
	g.set_color(1, Color(0.35, 0.0, 0.0, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Gotas: saem na direção do tiro, caem com gravidade.
func _make_drops() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 22
	p.lifetime = 0.9
	p.explosiveness = 0.95
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	qm.material = _particle_mat("blood_drop.png")
	p.mesh = qm
	p.direction = Vector3(0, 0, 1)
	p.spread = 28.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -9.8, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.color = Color(0.62, 0.05, 0.05, 1.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Pedaços (gore) do tiro na cabeça: cubinhos escuros que giram e caem.
func _make_chunks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 1.1
	p.explosiveness = 1.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.02, 0.018)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.03, 0.03)
	m.roughness = 0.4
	bm.material = m
	p.mesh = bm
	p.direction = Vector3(0, 0, 1)
	p.spread = 40.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_flash() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.45, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _tex("muzzle_flash.png")
	m.albedo_color = Color(1.0, 0.85, 0.55)
	qm.material = m
	mi.mesh = qm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.4)
	l.omni_range = 4.0
	l.light_energy = 2.0
	l.shadow_enabled = false
	root.add_child(l)
	root.visible = false
	add_child(root)
	return root


func _process(dt: float) -> void:
	for i in _tracers.size():
		if _tracer_life[i] > 0.0:
			_tracer_life[i] -= dt
			var m: StandardMaterial3D = _tracers[i].material_override
			m.albedo_color.a = clampf(_tracer_life[i] / 0.07, 0.0, 1.0) * 0.9
			if _tracer_life[i] <= 0.0:
				_tracers[i].visible = false
	for i in _sprays.size():
		if _spray_life[i] > 0.0:
			_spray_life[i] -= dt
			var k := 1.0 - _spray_life[i] / 0.22
			var sp := _sprays[i]
			var ln := lerpf(0.15, float(sp.get_meta("len", 0.8)), minf(k * 2.5, 1.0))
			sp.scale = Vector3(ln, ln * 0.55, 1.0)
			(sp.material_override as StandardMaterial3D).albedo_color.a = clampf(_spray_life[i] / 0.12, 0.0, 1.0)
			if _spray_life[i] <= 0.0:
				sp.visible = false
	for i in _pools.size():
		if _pool_grow[i] >= 0.0 and _pool_grow[i] < 1.0:
			_pool_grow[i] = minf(_pool_grow[i] + dt / 5.0, 1.0)
			var e := 1.0 - pow(1.0 - _pool_grow[i], 2.0)
			var r: float = float(_pools[i].get_meta("size", 1.2)) * maxf(e, 0.05)
			_pools[i].scale = Vector3(r, 1.0, r)
	for i in _flashes.size():
		if _flash_life[i] > 0.0:
			_flash_life[i] -= dt
			if _flash_life[i] <= 0.0:
				_flashes[i].visible = false


# ------------------------------------------------------------------ API
func shot(s: Soldier, def: WeaponDef, origin: Vector3, hit: Dictionary) -> void:
	var n: int = _shot_count.get(s, 0) + 1
	_shot_count[s] = n
	var muzzle := origin
	if s.is_local and s.controller and s.controller.has_method("muzzle_world_position"):
		muzzle = s.controller.muzzle_world_position()
	elif s.body_model and s.body_model.has_method("muzzle_position"):
		muzzle = s.body_model.muzzle_position()
	if not s.is_local:
		_flash_at(muzzle, def.muzzle_scale)
	var every := def.tracer_every if s.is_local else maxi(def.tracer_every - 1, 1)
	if n % every == 0:
		tracer(muzzle, hit.get("end", origin + s.aim_dir() * 60.0))
	if hit.has("victim"):
		var dir: Vector3 = (hit.end - origin).normalized()
		var group: String = hit.get("group", "chest")
		blood(hit.end, dir, group == "head", def.damage if def else 30.0)
		var v = hit.victim
		if v is Soldier and v.body_model and v.body_model.has_method("add_wound"):
			v.body_model.add_wound(hit.end, -dir)


func tracer(from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 1.5:
		return
	var tr := _tracers[_tracer_i]
	_tracer_life[_tracer_i] = 0.07
	_tracer_i = (_tracer_i + 1) % _tracers.size()
	var start := from.lerp(to, 0.08)
	var mid := (start + to) * 0.5
	var dir := (to - start).normalized()
	var cam := get_viewport().get_camera_3d()
	var side := Vector3.UP
	if cam:
		side = dir.cross(cam.global_position - mid).normalized()
	if side.length() < 0.1:
		side = Vector3.UP
	var up := dir
	var normal := side.cross(up).normalized()
	tr.global_transform = Transform3D(Basis(side * 1.0, up * start.distance_to(to), normal), mid)
	tr.visible = true


func _flash_at(pos: Vector3, scale: float) -> void:
	var f := _flashes[_flash_i]
	_flash_life[_flash_i] = 0.045
	_flash_i = (_flash_i + 1) % _flashes.size()
	f.global_position = pos
	f.scale = Vector3.ONE * scale * randf_range(0.8, 1.2)
	f.rotation = Vector3(0, 0, randf() * TAU)
	f.visible = true


func impact(pos: Vector3, normal: Vector3, surface: String, dir: Vector3) -> void:
	if surface != "cloth" and surface != "knife":
		_add_mark(_marks, pos, normal, true)
	var p := _puffs[_puff_i]
	_puff_i = (_puff_i + 1) % _puffs.size()
	p.global_position = pos + normal * 0.02
	p.global_transform.basis = _basis_from_normal(normal.lerp(-dir, 0.25).normalized())
	p.color = SURFACE_DUST.get(surface, SURFACE_DUST["stone"])
	p.restart()
	if surface == "metal" or surface == "stone":
		var sp := _sparks[_spark_i]
		_spark_i = (_spark_i + 1) % _sparks.size()
		sp.global_position = pos + normal * 0.02
		sp.global_transform.basis = _basis_from_normal(normal)
		sp.amount = 12 if surface == "metal" else 5
		sp.restart()
	var snd := "impact_" + surface
	if not Audio.has_sound(snd):
		snd = "impact_stone"
	Audio.play_at(snd, pos, {"volume_db": -6.0, "unit_size": 3.0, "max_distance": 30.0, "pitch_var": 0.12})


func blood(pos: Vector3, dir: Vector3, headshot := false, damage := 30.0) -> void:
	# névoa de entrada
	var p := _blood[_blood_i2]
	_blood_i2 = (_blood_i2 + 1) % _blood.size()
	p.global_position = pos
	p.global_transform.basis = _basis_from_normal(-dir)
	p.amount = 22 if headshot else 14
	p.restart()
	# gotas de saída (atravessam na direção do tiro)
	var dr := _drops[_drop_i]
	_drop_i = (_drop_i + 1) % _drops.size()
	dr.global_position = pos + dir * 0.12
	dr.global_transform.basis = _basis_from_normal((dir + Vector3.UP * 0.25).normalized())
	dr.amount = 34 if headshot else 16 + int(damage * 0.15)
	dr.restart()
	# jato de saída (sprite alongado que abre e some em 0,22 s), virado para a câmera
	var sp := _sprays[_spray_i]
	_spray_life[_spray_i] = 0.22
	_spray_i = (_spray_i + 1) % _sprays.size()
	var cam := get_viewport().get_camera_3d()
	var x := dir.normalized()
	var to_cam := (cam.global_position - pos).normalized() if cam else Vector3.UP
	var z := to_cam - x * to_cam.dot(x)
	z = z.normalized() if z.length() > 0.05 else Vector3.UP
	sp.global_transform = Transform3D(Basis(x, z.cross(x).normalized(), z), pos + dir * 0.08)
	sp.set_meta("len", 1.1 if headshot else 0.7)
	sp.visible = true
	if headshot:
		var ch := _chunks[_chunk_i]
		_chunk_i = (_chunk_i + 1) % _chunks.size()
		ch.global_position = pos + dir * 0.1
		ch.global_transform.basis = _basis_from_normal((dir + Vector3.UP * 0.4).normalized())
		ch.restart()
	# respingo na parede atrás da vítima
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos, pos + dir * (3.0 if headshot else 2.2), Soldier.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_add_mark(_blood_marks, hit.position, hit.normal, true)
	# manchas no chão onde as gotas caem
	for k in (2 if headshot else 1):
		var from := pos + dir * (0.5 + 0.6 * k) + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
		var qf := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, Soldier.LAYER_WORLD)
		var hf := space.intersect_ray(qf)
		if not hf.is_empty():
			_add_mark(_blood_marks, hf.position, hf.normal, true)
	Audio.play_at("impact_flesh", pos, {"volume_db": -1.0 if headshot else -3.0, "max_distance": 30.0, "pitch_var": 0.1})
	if headshot and Audio.has_sound("hit_head"):
		Audio.play_at("hit_head", pos, {"volume_db": 0.0, "max_distance": 40.0, "pitch_var": 0.06})


## Morte por tiro: jato extra (gotas reaproveitadas do pool, sem alocar) + poça no chão; cabeça = jato maior.
func blood_kill(pe: Vector3, pos: Vector3, dir: Vector3, headshot: bool) -> void:
	var dr := _drops[_drop_i]
	_drop_i = (_drop_i + 1) % _drops.size()
	dr.global_position = pos
	dr.global_transform.basis = _basis_from_normal((Vector3.UP * (1.0 if headshot else 0.5) - dir * 0.3).normalized())
	dr.amount = 60 if headshot else 30
	dr.restart()
	blood_pool(pe, 1.7 if headshot else 1.3)


## Poça que se espalha sob o corpo (5 s), no chão abaixo de pos.
func blood_pool(pos: Vector3, size := 1.3) -> void:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 2.0, Soldier.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var pl := _pools[_pool_i]
	_pool_grow[_pool_i] = 0.0
	_pool_i = (_pool_i + 1) % _pools.size()
	var n: Vector3 = hit.normal
	var b := Basis(Vector3.UP, randf() * TAU)
	if n.dot(Vector3.UP) < 0.999:
		b = Basis(Quaternion(Vector3.UP, n)) * b
	pl.global_transform = Transform3D(b, hit.position + n * 0.008)
	pl.set_meta("size", size)
	pl.scale = Vector3(0.05, 1, 0.05)
	pl.visible = true


func _add_mark(mmi: MultiMeshInstance3D, pos: Vector3, normal: Vector3, random_roll: bool) -> void:
	var mm := mmi.multimesh
	var idx := _mark_i if mmi == _marks else _blood_i
	var b := _basis_from_normal(normal)
	if random_roll:
		b = b.rotated(normal, randf() * TAU)
	var s := randf_range(0.85, 1.2)
	mm.set_instance_transform(idx, Transform3D(b.scaled(Vector3(s, s, s)), pos + normal * 0.006))
	mm.visible_instance_count = maxi(mm.visible_instance_count, idx + 1)
	if mmi == _marks:
		_mark_i = (_mark_i + 1) % MAX_MARKS
	else:
		_blood_i = (_blood_i + 1) % MAX_MARKS


## Basis whose +Z points along n (QuadMesh faces +Z).
func _basis_from_normal(n: Vector3) -> Basis:
	var z := n.normalized()
	var ref := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


func explosion(pos: Vector3) -> void:
	var boom: Node3D = load("res://fx/explosion.gd").new()
	add_child(boom)
	boom.global_position = pos
	Audio.play_at("bomb_explode", pos, {"volume_db": 8.0, "unit_size": 40.0, "max_distance": 400.0, "pitch_var": 0.0})
	var lp: Soldier = get_parent().get_parent().local_player if get_parent() and get_parent().get_parent() else null
	if lp and lp.controller and lp.controller.has_method("shake"):
		var d := lp.global_position.distance_to(pos)
		lp.controller.shake(clampf(1.6 - d / 40.0, 0.2, 1.6))


func clear_round() -> void:
	for i in _pools.size():
		_pools[i].visible = false
		_pool_grow[i] = -1.0
	_marks.multimesh.visible_instance_count = 0
	_blood_marks.multimesh.visible_instance_count = 0
	_mark_i = 0
	_blood_i = 0
	_shot_count.clear()
