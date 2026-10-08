class_name Pickup
extends Node3D
## A dropped weapon/bomb lying on the floor. Simple ballistic fall + auto pickup.

var match_ref: Node
var state: WeaponState
var vel := Vector3.ZERO
var resting := false
var dropper: Soldier = null
var drop_time := 0.0
var _spin := Vector3.ZERO
var _model: Node3D
var _age := 0.0


func setup(m: Node, ws: WeaponState, pos: Vector3, v: Vector3, who: Soldier) -> void:
	match_ref = m
	state = ws
	dropper = who
	global_position = pos
	vel = v
	_spin = Vector3(randf_range(-4, 4), randf_range(-6, 6), randf_range(-4, 4))
	var path := ws.def.model_path.replace(".tscn", "_world.tscn")
	if ResourceLoader.exists(path):
		_model = load(path).instantiate()
	elif ResourceLoader.exists(ws.def.model_path):
		_model = load(ws.def.model_path).instantiate()
	else:
		_model = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.12, 0.7)
		(_model as MeshInstance3D).mesh = bm
	add_child(_model)
	if ws.def.slot == WeaponDef.Slot.BOMB:
		add_to_group("dropped_bomb")


func _physics_process(dt: float) -> void:
	_age += dt
	if not resting:
		vel.y -= 20.0 * dt
		var from := global_position
		var to := from + vel * dt
		var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.05, to, Soldier.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position = to
			rotation += _spin * dt
		else:
			var n: Vector3 = hit.normal
			global_position = hit.position + n * 0.03
			if n.y > 0.6 and vel.length() < 3.0:
				resting = true
				# deita de lado, mantendo a direção horizontal
				rotation = Vector3(0.0, rotation.y, PI * 0.5)
			else:
				vel = vel.bounce(n) * 0.35
				_spin *= 0.5
	_try_auto_pickup()


func _try_auto_pickup() -> void:
	if match_ref == null or _age < 0.6:
		return
	for s: Soldier in match_ref.soldiers:
		if not s.alive:
			continue
		if s == dropper and _age < 1.5:
			continue
		if s.global_position.distance_to(global_position) > 1.1:
			continue
		if can_take(s) and not s.inventory.has(state.def.slot):
			give_to(s)
			return


func can_take(s: Soldier) -> bool:
	if state.def.slot == WeaponDef.Slot.BOMB:
		return s.team == 0
	return true


func give_to(s: Soldier) -> void:
	s.inventory[state.def.slot] = state
	if state.def.slot == WeaponDef.Slot.BOMB:
		s.is_carrying_bomb = true
	s.inventory_changed.emit()
	if s.is_local:
		Audio.ui("pickup")
		if state.def.slot < s.active_slot or s.active_slot == WeaponDef.Slot.KNIFE:
			s.switch_to(state.def.slot)
	else:
		Audio.play_at("pickup", s.global_position, {"volume_db": -8.0, "max_distance": 12.0})
		if state.def.slot != WeaponDef.Slot.BOMB:
			s.switch_to(state.def.slot)
	match_ref.on_pickup(s, self)
	queue_free()
