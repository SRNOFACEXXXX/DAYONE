extends Node
## Simple terrain slope analysis without loading the full island.

func _ready() -> void:
	var terrain := IlhaTerrain.new()
	terrain.name = "Terreno"
	add_child(terrain)
	await terrain.terrain_ready

	print("\n=== ANALYZING TERRAIN SLOPES ===")

	# Load vehicle positions
	var vehicles = _load_vehicle_positions()
	print("Found %d vehicles" % vehicles.size())

	# Measure slope at each vehicle
	var vehicle_slopes = []
	for v in vehicles:
		var slope = _measure_slope_at(terrain, v.pos.x, v.pos.y)
		vehicle_slopes.append({
			"type": v.type,
			"x": v.pos.x,
			"z": v.pos.y,
			"slope": slope,
			"height": terrain.height_world(v.pos.x, v.pos.y)
		})

	# Find max slope on map
	var max_map_slope = 0.0
	print("\nScanning terrain for max slope...")
	for x in range(-600, 600, 20):
		for z in range(-600, 600, 20):
			var slope = _measure_slope_at(terrain, float(x), float(z))
			max_map_slope = maxf(max_map_slope, slope)

	# Print results
	print("\n" + "=".repeat(80))
	print("VEHICLE SLOPES:")
	print("=".repeat(80))
	vehicle_slopes.sort_custom(func(a, b): return a.slope > b.slope)
	for v in vehicle_slopes:
		var type_name = v.type.trim_prefix("cenario/carros/carro_")
		print("  %-15s @ (%-8.1f, %-8.1f): %5.1f° (h=%.1f m)" % [
			type_name, v.x, v.z, v.slope, v.height
		])

	print("\n" + "=".repeat(80))
	var slopes_only = vehicle_slopes.map(func(v): return v.slope)
	if not slopes_only.is_empty():
		slopes_only.sort()
		print("Min slope: %.1f°" % slopes_only[0])
		print("Max slope: %.1f°" % slopes_only[-1])
		var avg = slopes_only.reduce(func(a, b): return a + b, 0.0) / slopes_only.size()
		print("Avg slope: %.1f°" % avg)

	print("Overall max map slope: %.1f°" % max_map_slope)
	print("Target for playable areas: ~35°")
	print("=".repeat(80) + "\n")

	get_tree().quit(0)

func _load_vehicle_positions() -> Array:
	var vehicles = []
	var files = ["res://maps/ilha/cenario_areas.json", "res://maps/ilha/cenario_areas_02.json"]

	for file_path in files:
		if not FileAccess.file_exists(file_path):
			continue
		var text = FileAccess.get_file_as_string(file_path)
		var data = JSON.parse_string(text)
		if data == null:
			continue

		for area in data.get("areas", []):
			for prop in area.get("props", []):
				var tipo = String(prop.get("tipo", ""))
				if tipo.begins_with("cenario/carros/carro_"):
					vehicles.append({
						"type": tipo,
						"pos": Vector2(float(prop.x), float(prop.y))
					})

	return vehicles

func _measure_slope_at(terrain: IlhaTerrain, x: float, z: float) -> float:
	# Measure height gradients in X and Z directions
	var step = 1.0
	var h_c = terrain.height_world(x, z)
	var h_x_plus = terrain.height_world(x + step, z)
	var h_x_minus = terrain.height_world(x - step, z)
	var h_z_plus = terrain.height_world(x, z + step)
	var h_z_minus = terrain.height_world(x, z - step)

	# Calculate slopes
	var slope_x = abs(h_x_plus - h_x_minus) / (2.0 * step)
	var slope_z = abs(h_z_plus - h_z_minus) / (2.0 * step)

	# Combine slopes (steepest direction)
	var combined_slope = sqrt(slope_x * slope_x + slope_z * slope_z)
	return rad_to_deg(atan(combined_slope))
