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
## alvos (grupo zombie_targets) lidos uma vez por segundo, junto com _registrar_alvos: evita alocar a lista a cada LOD
var _alvos_cache: Array = []

## População por cidade (pedido do dono: no mínimo 20 zumbis em cada cidade). Cidades a menos de CIDADE_ATIVA m de um alvo
## (jogador/bots) ficam cheias: nasce 1 zumbi a cada SPAWN_INTERVALO s, fora da vista do jogador, até `por_cidade` vivos
## dentro do raio da cidade. Cidade que fica a mais de CIDADE_SOLTA m perde os zumbis que não estão caçando (memória/CPU:
## no máximo umas 2-3 cidades ativas ao mesmo tempo). Mortos voltam aos poucos (1 a cada RESPAWN_S s por cidade).
@export_range(0, 60, 1) var por_cidade := 20
@export_range(10, 200, 1) var max_vivos := 70
const CIDADE_ATIVA := 210.0
const CIDADE_SOLTA := 330.0
const SPAWN_INTERVALO := 0.22
const RESPAWN_S := 120.0
var city_radii: Array[float] = []
var _mortos: Array[float] = []
var _spawn_t := 0.0
var _cidades_t := 0.0
var _spawnados := 0


func setup(terrain_node: Node, player_node: Node3D, settlement_centers: Array[Vector3] = []) -> void:
	terrain = terrain_node
	player = player_node
	city_locations = settlement_centers.duplicate()
	city_radii.clear()
	_mortos.clear()
	for c in city_locations:
		city_radii.append(45.0)
		_mortos.append(0.0)
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
		_alvos_cache = get_tree().get_nodes_in_group("zombie_targets")
	_cidades_t -= delta
	_spawn_t -= delta
	if _cidades_t <= 0.0:
		_cidades_t = 0.5
		_atualizar_cidades(delta if delta > 0.5 else 0.5)
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
	for t in _alvos_cache:
		if is_instance_valid(t) and t is Node3D and (t as Node3D).is_inside_tree():
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
					if max_height_delta < INF and is_instance_valid(player) and absf(ground_y + 0.06 - player.global_position.y) > max_height_delta:
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


## Raios das cidades (metade da extensão dos prédios + margem), vindos do layout. Sem isso, 45 m.
func definir_raios(raios: Array) -> void:
	for i in mini(raios.size(), city_radii.size()):
		city_radii[i] = clampf(float(raios[i]), 25.0, 90.0)


func _dist_alvo_mais_perto(p: Vector3) -> float:
	var d2 := INF
	for t in _alvos_cache:
		if is_instance_valid(t) and t is Node3D and (t as Node3D).is_inside_tree():
			var q := (t as Node3D).global_position
			d2 = minf(d2, Vector2(q.x - p.x, q.z - p.z).length_squared())
	if is_instance_valid(player):
		var q := player.global_position
		d2 = minf(d2, Vector2(q.x - p.x, q.z - p.z).length_squared())
	return sqrt(d2)


## O `player` do setup pode ser o Explorador do tour, apagado quando a partida começa: troca por um alvo válido.
func _jogador_valido() -> bool:
	if is_instance_valid(player) and player.is_inside_tree():
		return true
	for t in _alvos_cache:
		if is_instance_valid(t) and t is Node3D and (t as Node3D).is_inside_tree():
			player = t
			return true
	return false


func _atualizar_cidades(dt: float) -> void:
	_jogador_valido()
	if city_locations.is_empty() or not is_instance_valid(terrain) or por_cidade <= 0:
		return
	var vivos_total := 0
	var por_cid: Array[int] = []
	por_cid.resize(city_locations.size())
	por_cid.fill(0)
	var zumbis := get_children()
	for z in zumbis:
		var zz := z as ZombieEnemy
		if zz == null or zz.state == ZombieEnemy.State.DEAD:
			continue
		vivos_total += 1
		for i in city_locations.size():
			var c := city_locations[i]
			if Vector2(zz.global_position.x - c.x, zz.global_position.z - c.z).length() <= city_radii[i] + 12.0:
				por_cid[i] += 1
				break
	for i in city_locations.size():
		_mortos[i] = maxf(_mortos[i] - dt / RESPAWN_S, 0.0)
		var c := city_locations[i]
		var d := _dist_alvo_mais_perto(c)
		if d > CIDADE_SOLTA + city_radii[i]:
			_soltar_cidade(i)
			continue
		if d > CIDADE_ATIVA + city_radii[i]:
			continue
		var alvo := por_cidade - int(floor(_mortos[i]))
		if por_cid[i] < alvo and vivos_total < max_vivos and _spawn_t <= 0.0:
			if _spawn_na_cidade(i):
				_spawn_t = SPAWN_INTERVALO
				vivos_total += 1
				por_cid[i] += 1


func _soltar_cidade(i: int) -> void:
	var c := city_locations[i]
	for z in get_children():
		var zz := z as ZombieEnemy
		if zz == null or not zz.has_meta("cidade") or int(zz.get_meta("cidade")) != i:
			continue
		if zz.state in [ZombieEnemy.State.CHASE, ZombieEnemy.State.ATTACK, ZombieEnemy.State.ALERT]:
			continue
		if Vector2(zz.global_position.x - c.x, zz.global_position.z - c.z).length() <= city_radii[i] + 40.0:
			zz.queue_free()


func _spawn_na_cidade(i: int) -> bool:
	var c := city_locations[i]
	var r := city_radii[i]
	var cam := get_viewport().get_camera_3d()
	for tentativa in 6:
		var ang := _rng.randf_range(-PI, PI)
		var dist := _rng.randf_range(4.0, r)
		var ponto := _find_grounded_point(c, ang, dist, 4.0, r)
		# nada de zumbi brotando na frente/perto do jogador
		if is_instance_valid(player):
			var dp := ponto.distance_to(player.global_position)
			if dp < 25.0:
				continue
			if cam and dp < 90.0 and cam.is_position_in_frustum(ponto + Vector3.UP):
				continue
		var zombie := ZOMBIE_SCENE.instantiate() as ZombieEnemy
		_spawnados += 1
		zombie.name = "ZombieCidade_%d_%d" % [i, _spawnados]
		zombie.set_meta("cidade", i)
		add_child(zombie)
		zombie.global_position = ponto
		zombie.rotation.y = _rng.randf_range(-PI, PI)
		zombie.begin_roaming(_rng.randf_range(0.25, 1.5))
		if _spawnados % 7 == 6:
			zombie.configure_archetype(&"brute")
		zombie.set_lod(2)   # nasce dormindo; o LOD acorda conforme a distância
		zombie.died.connect(func(_z, _h, _a): _mortos[i] += 1.0)
		return true
	return false
