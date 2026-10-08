extends Node
## Full copied survival map: grounded refuge collision, walking access and functional loot.
var _failures := 0

func _check(ok: bool, message: String) -> void:
	print("GPT_CHECK ", "PASS " if ok else "FAIL ", message)
	if not ok:
		_failures += 1

func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var match_scene: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(match_scene)
	await match_scene.match_initialized
	var deadline := Time.get_ticks_msec() + 20000
	while match_scene.br_loot_root == null or match_scene.br_loot_root.get_child_count() < 3:
		if Time.get_ticks_msec() > deadline:
			_check(false, "survival setup timed out")
			get_tree().quit(1)
			return
		await get_tree().process_frame
	# Setup yields during existing loot; wait for all three appended refuge crates.
	while get_tree().get_nodes_in_group("gpt_refugio").size() != 3:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var sites := get_tree().get_nodes_in_group("gpt_refugio")
	_check(sites.size() == 3, "three refuges loaded")
	var space := match_scene.get_world_3d().direct_space_state
	for site in sites:
		var origin: Vector3 = site.global_position
		var ray := PhysicsRayQueryParameters3D.create(origin+Vector3(0,2,0),origin-Vector3(0,1,0),1)
		var hit := space.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == site, String(site.name)+" deck supports player")
		var capsule := CapsuleShape3D.new()
		capsule.radius = .35
		capsule.height = 1.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		var clear := true
		for i in range(21):
			var z := 4.1 - float(i)*.2
			var pos: Vector3 = site.to_global(Vector3(-.15,1.1,z))
			query.transform = Transform3D(Basis.IDENTITY,pos)
			if not space.intersect_shape(query,1).is_empty():
				clear = false
		_check(clear, String(site.name)+" 1.8m capsule entrance clear")
		var crate: BRCrate = match_scene.br_loot_root.get_node_or_null(NodePath(String(site.name)+"_suprimentos"))
		_check(crate != null, String(site.name)+" supply crate exists")
		if crate:
			crate.abrir()
			await get_tree().create_timer(1.0).timeout
			_check(crate.contents.items.size() > 0 and crate.contents.items.size() <= 2, String(site.name)+" crate opens with valid supplies")
			var bag := BRInventory.new()
			crate.take_all(bag)
			_check(not bag.items.is_empty(), String(site.name)+" supplies transferable")
	_check(match_scene.is_survival() and match_scene.local_player.alive, "survival mode and living player")
	print("GPT_MAP_RESULT failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
