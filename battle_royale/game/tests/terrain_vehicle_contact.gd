extends Node
## Checks that Jolt's heightfield and the rendered terrain agree between grid vertices.

var failures := 0

func _ready() -> void:
	var terrain := IlhaTerrain.new()
	terrain.name = "TerrainUnderTest"
	add_child(terrain)
	await terrain.terrain_ready
	var body := terrain.get_node("TerrenoColisao") as StaticBody3D
	const TEST_LAYER := 1 << 19
	body.collision_layer = TEST_LAYER
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = terrain.get_world_3d().direct_space_state
	var max_error := 0.0
	var hits := 0
	for row in range(7):
		for col in range(7):
			var c := 17 + col * 83
			var r := 23 + row * 79
			var tx := .73 if (row + col) % 2 == 0 else .31
			var tz := .24 if (row + col) % 2 == 0 else .22
			var x := IlhaTerrain.ORIGIN + (float(c) + tx) * IlhaTerrain.STEP
			var z := IlhaTerrain.ORIGIN + (float(r) + tz) * IlhaTerrain.STEP
			var surface_y := terrain.height_world(x, z)
			var query := PhysicsRayQueryParameters3D.create(
				Vector3(x, surface_y + 200.0, z), Vector3(x, surface_y - 200.0, z), TEST_LAYER)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				hits += 1
				max_error = maxf(max_error, absf(float(hit.position.y) - surface_y))
	var passed := hits == 49 and max_error < .02
	print("TERRAIN_CONTACT_CHECK ", "PASS" if passed else "FAIL",
		" rays=", hits, " max_error_m=", snappedf(max_error, .001))
	get_tree().quit(0 if passed else 1)
