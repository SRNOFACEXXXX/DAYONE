class_name ZombieDirector
extends Node3D
## Seeds the island's settlements and keeps a small nearby threat so the AI is testable immediately.

const ZOMBIE_SCENE := preload("res://core/zombie.tscn")

@export_range(1, 32, 1) var opening_count := 20
@export_range(0, 8, 1) var nearby_count := 2
@export var inner_radius := 7.0
@export var outer_radius := 9.0
@export var city_inner_radius := 12.0
@export var city_outer_radius := 30.0

var terrain: Node
var player: Node3D
var city_locations: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()

## LOD dos zumbis (desempenho, GT 730): a cada LOD_INTERVALO quadros de física o diretor reclassifica no máximo
## LOD_ORCAMENTO zumbis (orçamento por quadro) pela distância ao alvo/câmera mais próximo e se estão na vista.
const LOD_INTERVALO := 3
const LOD_ORCAMENTO := 8
const PERTO := 38.0          # até aqui: IA completa todo quadro
const MEDIO := 85.0          # até aqui (ou na vista até LONGE): tick a cada 4 quadros, sem animação contínua
const LONGE := 130.0         # além disso, ou > MEDIO fora da vista: dormindo (sem física/IA/animação, invisível)
const ALCANCE_ATIVO := 250.0
var _lod_cursor := 0
var _lod_quadro := 0
var _alvos_t := 0.0


func setup(terrain_node: Node, player_node: Node3D, settlement_centers: Array[Vector3] = []) -> void:
	terrain = terrain_node
	player = player_node
	city_locations = settlement_centers.duplicate()
	_rng.randomize()
	_spawn_opening_group()


func _spawn_opening_group() -> void:
	if not is_instance_valid(terrain) or not is_instance_valid(player):
		return
	var start_angle := _rng.randf_range(-PI, PI)
	var local_count := mini(nearby_count, opening_count)
	var nearest_city := _nearest_city_index()
	var remote_cities: Array[int] = []
	for city_index in city_locations.size():
		if city_index != nearest_city:
			remote_cities.append(city_index)
	for index in opening_count:
		var near_player := index < local_count or remote_cities.is_empty()
		var center := player.global_position
		var min_radius := inner_radius
		var max_radius := outer_radius
		if not near_player:
			var city_index := remote_cities[(index - local_count) % remote_cities.size()]
			center = city_locations[city_index]
			min_radius = city_inner_radius
			max_radius = city_outer_radius
		var angle := start_angle + TAU * float(index) / float(opening_count) + _rng.randf_range(-0.38, 0.38)
		var distance := _rng.randf_range(min_radius, max_radius)
		var require_sight := near_player and index == 0
		var max_height_delta := 1.1 if near_player else INF
		var point := _find_grounded_point(center, angle, distance, min_radius, max_radius, require_sight, max_height_delta)
		var zombie := ZOMBIE_SCENE.instantiate() as ZombieEnemy
		zombie.name = "Zombie_%02d" % index
		add_child(zombie)
		zombie.begin_roaming(_rng.randf_range(0.25, 1.2))
		zombie.global_position = point
		if near_player and index == 0:
			var toward_player := player.global_position - point
			toward_player.y = 0.0
			zombie.rotation.y = atan2(-toward_player.x, -toward_player.z)
		else:
			zombie.rotation.y = _rng.randf_range(-PI, PI)
		if index % 7 == 6:
			zombie.configure_archetype(&"brute")
	print("ZOMBIE_DIRECTOR spawned=", opening_count, " nearby=", mini(local_count, opening_count), " settlements=", city_locations.size(), " around=", player.name)


func _physics_process(delta: float) -> void:
	_alvos_t -= delta
	if _alvos_t <= 0.0:
		_alvos_t = 1.0
		_registrar_alvos()
	_lod_quadro += 1
	if _lod_quadro % LOD_INTERVALO != 0:
		return
	var n := get_child_count()
	if n == 0:
		return
	var refs: Array[Vector3] = []
	var cam := get_viewport().get_camera_3d()
	if cam:
		refs.append(cam.global_position)
	for t in get_tree().get_nodes_in_group("zombie_targets"):
		if t is Node3D and is_instance_valid(t) and (t as Node3D).is_inside_tree():
			refs.append((t as Node3D).global_position)
	for k in mini(LOD_ORCAMENTO, n):
		_lod_cursor = (_lod_cursor + 1) % n
		var z := get_child(_lod_cursor) as ZombieEnemy
		if z == null:
			continue
		z.set_lod(_lod_para(z, refs, cam))


func _lod_para(z: ZombieEnemy, refs: Array[Vector3], cam: Camera3D) -> int:
	var d2 := INF
	var p := z.global_position
	for r in refs:
		d2 = minf(d2, Vector2(r.x - p.x, r.z - p.z).length_squared())
	var d := sqrt(d2)
	if z.state == ZombieEnemy.State.DEAD:   # corpo: animação de morte lisa perto; longe some
		return 0 if d < PERTO else (1 if d < LONGE else 2)
	var cacando := z.state in [ZombieEnemy.State.CHASE, ZombieEnemy.State.ATTACK, ZombieEnemy.State.ALERT]
	if d < PERTO or (cacando and d < MEDIO):
		return 0
	var na_vista := cam != null and cam.is_position_in_frustum(p + Vector3.UP)
	# caçando/investigando (ex.: ouviu um tiro de longe): nunca dorme até ALCANCE_ATIVO
	if d < MEDIO or (na_vista and d < LONGE) or ((cacando or z.state == ZombieEnemy.State.INVESTIGATE) and d < ALCANCE_ATIVO):
		return 1
	return 2


## O jogador e os bots da partida viram alvos dos zumbis (antes só o Explorador do tour entrava no grupo, e na
## partida ele é apagado: os zumbis nunca enxergavam o jogador).
func _registrar_alvos() -> void:
	var m = Game.current_match
	if m == null or not is_instance_valid(m) or not "soldiers" in m:
		return
	for s in m.soldiers:
		if is_instance_valid(s) and not s.is_in_group("zombie_targets"):
			s.add_to_group("zombie_targets")


func _nearest_city_index() -> int:
	var nearest := -1
	var nearest_distance := INF
	for index in city_locations.size():
		var distance := Vector2(city_locations[index].x - player.global_position.x, city_locations[index].z - player.global_position.z).length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func _find_grounded_point(center: Vector3, angle: float, distance: float, min_distance: float, max_distance: float, require_player_sight: bool = false, max_height_delta: float = INF) -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	for attempt in (48 if require_player_sight else 12):
		var candidate_angle := angle + float(attempt) * 2.39996323
		var candidate_distance := lerpf(min_distance, max_distance, fposmod(distance / maxf(max_distance, 0.01) + float(attempt) * 0.137, 1.0))
		var x := center.x + cos(candidate_angle) * candidate_distance
		var z := center.z + sin(candidate_angle) * candidate_distance
		var ground_y := float(terrain.call("height_world", x, z))
		if space:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, ground_y + 7.0, z), Vector3(x, ground_y - 3.0, z))
			query.collision_mask = 1
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var collider: Object = hit.get("collider")
				if collider is Node and terrain.is_ancestor_of(collider):
					ground_y = (hit.get("position") as Vector3).y
					if absf(ground_y + 0.06 - player.global_position.y) > max_height_delta:
						continue
					if require_player_sight:
						var sight_query := PhysicsRayQueryParameters3D.create(
							Vector3(x, ground_y + 1.0, z), player.global_position + Vector3.UP * 1.15)
						sight_query.collision_mask = 1
						var sight_hit := space.intersect_ray(sight_query)
						var sight_collider: Object = sight_hit.get("collider") if not sight_hit.is_empty() else null
						if sight_collider != player and not (sight_collider is Node and player.is_ancestor_of(sight_collider)):
							continue
					return Vector3(x, ground_y + 0.06, z)
				continue
		return Vector3(x, ground_y + 0.06, z)
	return Vector3(center.x + cos(angle) * distance, float(terrain.call("height_world", center.x + cos(angle) * distance, center.z + sin(angle) * distance)) + 0.06, center.z + sin(angle) * distance)
