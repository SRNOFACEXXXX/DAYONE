extends Node
## Measures terrain slope under each vehicle spawn point and analyzes the map's overall slope.

class VehicleInfo:
	var tipo: String
	var pos: Vector2
	var rot_deg: float
	var pos_world: Vector3
	var slope_at_vehicle: float
	var height: float

var terrain: IlhaTerrain
var vehicles_data: Array[VehicleInfo] = []
var max_slope_overall: float = 0.0

func _ready() -> void:
	Game.test_mode = true
	var island: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(island)
	await island.map_ready
	terrain = island.get("terrain") as IlhaTerrain

	_load_vehicles()
	_measure_vehicle_slopes()
	_find_max_slope()
	_print_results()

	get_tree().quit(0)

func _load_vehicles() -> void:
	var files = ["res://maps/ilha/cenario_areas.json", "res://maps/ilha/cenario_areas_02.json"]

	for file_path in files:
		if not FileAccess.file_exists(file_path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		if data == null:
			continue

		var areas = data.get("areas", [])
		for area in areas:
			var props = area.get("props", [])
			for prop in props:
				var tipo = String(prop.get("tipo", ""))
				if not tipo.begins_with("cenario/carros/carro_"):
					continue

				var info = VehicleInfo.new()
				info.tipo = tipo
				info.pos = Vector2(float(prop.get("x", 0.0)), float(prop.get("y", 0.0)))
				info.rot_deg = float(prop.get("rot_deg", 0.0))
				info.pos_world = Vector3(info.pos.x, 0.0, -info.pos.y)
				info.height = terrain.height_world(info.pos_world.x, info.pos_world.z)
				info.pos_world.y = info.height
				vehicles_data.append(info)

func _measure_vehicle_slopes() -> void:
	for info in vehicles_data:
		var slope = _calculate_local_slope(info.pos_world.x, info.pos_world.z)
		info.slope_at_vehicle = slope

func _calculate_local_slope(x: float, z: float) -> float:
	var step = 2.0
	var samples = []

	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var sample_x = x + dx * step
			var sample_z = z + dz * step
			var h = terrain.height_world(sample_x, sample_z)
			samples.append(h)

	if samples.is_empty():
		return 0.0

	var max_slope = 0.0
	var center_h = samples[12]

	for i in range(samples.size()):
		if i == 12:
			continue
		var height_diff = abs(samples[i] - center_h)
		var is_diagonal = (i % 4 != 2 and i % 4 != 0) or (i < 4 or i > 20)
		var distance = 2.0 if not is_diagonal else 2.0 * sqrt(2.0)
		var slope_deg = rad_to_deg(atan(height_diff / distance))
		max_slope = maxf(max_slope, slope_deg)

	return max_slope

func _find_max_slope() -> void:
	var step = 10.0
	var fc0 = (IlhaTerrain.ORIGIN - IlhaTerrain.ORIGIN) / IlhaTerrain.STEP
	var fc1 = ((IlhaTerrain.ORIGIN + IlhaTerrain.N * IlhaTerrain.STEP) - IlhaTerrain.ORIGIN) / IlhaTerrain.STEP
	var num_samples = int((fc1 - fc0) / (step / IlhaTerrain.STEP))

	for i in range(0, num_samples, 1):
		for j in range(0, num_samples, 1):
			var x = IlhaTerrain.ORIGIN + i * step
			var z = IlhaTerrain.ORIGIN + j * step
			var slope = _calculate_local_slope(x, z)
			max_slope_overall = maxf(max_slope_overall, slope)

func _print_results() -> void:
	print("\n=== VEHICLE TERRAIN SLOPE ANALYSIS ===\n")
	print("Vehicles found: ", vehicles_data.size())
	print("\nVehicle slopes (degrees):")
	var line = ""
	for i in range(80):
		line += "-"
	print(line)

	var slopes_at_vehicles = []
	for info in vehicles_data:
		var car_name = info.tipo.trim_prefix("cenario/carros/carro_")
		print("  %s at (%.1f, %.1f): %.1f°, height=%.1f m" % [
			car_name, info.pos_world.x, info.pos_world.z,
			info.slope_at_vehicle, info.height
		])
		slopes_at_vehicles.append(info.slope_at_vehicle)

	if not slopes_at_vehicles.is_empty():
		slopes_at_vehicles.sort()
		print("\nSlope statistics:")
		print("  Min: %.1f°" % slopes_at_vehicles[0])
		print("  Max: %.1f°" % slopes_at_vehicles[-1])
		var sum = 0.0
		for s in slopes_at_vehicles:
			sum += s
		print("  Avg: %.1f°" % (sum / float(slopes_at_vehicles.size())))

	print("\nOverall map max slope: %.1f°" % max_slope_overall)
	print("\nTarget slope limit (playable areas): ~35°")
	var line2 = ""
	for i in range(80):
		line2 += "="
	print(line2)
