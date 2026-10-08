extends Node
## Run: godot --headless --path game res://tests/mosin_smoke.tscn


func _ready() -> void:
	call_deferred("_check")


func _check() -> void:
	var definition: Variant = WeaponDB
	var weapon: WeaponDef = definition.get_def(&"mosin")
	assert(weapon != null)
	assert(weapon.mag_size == 5 and weapon.fire_interval > 1.0)
	assert(weapon.ammo_type == &"762x54r")
	var state := WeaponState.new(weapon)
	assert(state.mag == 5 and state.reserve == 25)
	var loot: WeaponState = definition.create_state(&"mosin", 3, 12)
	assert(loot.mag == 3 and loot.reserve == 12)
	assert(definition.add_ammo(loot, &"762x54r", 10) == 10)
	assert(loot.reserve == 22)
	assert(definition.add_ammo(loot, &"wrong", 10) == 0)
	for rifle_id in [&"ak47", &"m4"]:
		var rifle: WeaponDef = definition.get_def(rifle_id)
		assert(rifle.ads_iron_fov > 0.0 and rifle.ads_acog_fov == 0.0, "AK/M4 usam apenas mira aberta")
	assert(weapon.ads_iron_fov > weapon.ads_acog_fov and weapon.ads_acog_fov == 24.0, "ACOG funcional fica na Mosin")
	for path in ["res://assets/models/weapons/mosin.tscn", "res://assets/models/weapons/mosin_fp.tscn"]:
		var packed := load(path) as PackedScene
		assert(packed != null)
		var model := packed.instantiate()
		assert(model.find_child("BoltAssembly", true, false) != null)
		assert(model.find_child("Optic", true, false) != null)
		var front := model.find_child("Front sight post", true, false) as Node3D
		var rear := model.find_child("Rear sight base", true, false) as Node3D
		assert(front != null and rear != null)
		assert(_point(front).z < _point(rear).z)
		assert(_point(front).y > _point(rear).y)
		model.free()
	assert(load("res://core/player_controller.gd") != null)
	assert(load("res://core/viewmodel.gd") != null)
	var controller := PlayerController.new()
	assert(not controller._has_installed_acog())
	controller.free()
	print("MOSIN_SMOKE_OK")
	get_tree().quit()


func _point(node: Node3D) -> Vector3:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current is Node3D:
		transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform.origin
