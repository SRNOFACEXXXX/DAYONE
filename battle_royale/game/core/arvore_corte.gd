extends Node
## Cortar árvores: golpes do machado, tombo animado e 5 toras no chão (itens de PROXIMIDADE do inventário).
## Sem class_name (use preload). Vive como filho da partida; só a árvore golpeada vira nó, nada roda por quadro quando ocioso.
## As árvores são MultiMesh (maps/ilha/vegetation.gd): `arvore_mais_proxima` / `derrubar` / `restaurar` escondem a instância e a colisão.

const GOLPES_ARVORE := 6
const TEMPO_QUEDA := 1.6
const TORAS_POR_ARVORE := 5
const RESPAWN_S := 900.0
const MAX_CAIDAS := 6

var match_ref: Match
var veg: IlhaVegetation
var _golpes := {}              # índice da árvore -> golpes recebidos
var _tocos := {}               # índice -> MeshInstance3D
var _caidas: Array[Node3D] = []
var _mat_toco: StandardMaterial3D
var _mat_lasca: StandardMaterial3D
var _mat_folha: StandardMaterial3D


func setup(m: Match) -> void:
	match_ref = m
	name = "ArvoreCorte"


func _vegetacao() -> IlhaVegetation:
	if veg == null or not is_instance_valid(veg):
		var ilha = match_ref.get("ilha")
		veg = ilha.get_node_or_null("Vegetacao") if ilha != null else null
	return veg


## Um golpe de machado: procura a árvore viva à frente de `de` (olhos/pés do jogador) e a fere. true se atingiu uma árvore.
## `dano` = golpes que contam (1 = normal). Na última a árvore tomba na direção oposta ao jogador.
func golpear(de: Vector3, frente: Vector3, dano := 1) -> bool:
	var v := _vegetacao()
	if v == null:
		return false
	var f := Vector3(frente.x, 0.0, frente.z)
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var i := v.arvore_mais_proxima(de + f * 1.2, 2.0)
	if i < 0:
		return false
	var a: Dictionary = v.arvores[i]
	var n: int = int(_golpes.get(i, 0)) + dano
	_golpes[i] = n
	var topo: Vector3 = (a.pos as Vector3) + Vector3(0, 1.3, 0)
	var para_jogador := Vector3(de.x - topo.x, 0, de.z - topo.z)
	para_jogador = para_jogador.normalized() if para_jogador.length() > 0.01 else Vector3.BACK
	_lascas(topo + para_jogador * (float(a.raio) + 0.05))
	Audio.play_at("impact_wood", topo, {"volume_db": 4.0, "pitch": 0.75 + 0.05 * float(n % 3), "max_distance": 60.0})
	Audio.emitir_barulho(topo, 24.0, null)
	if n >= GOLPES_ARVORE:
		_golpes.erase(i)
		var dir := -para_jogador
		_tombar(i, dir)
	return true


func _lascas(pos: Vector3) -> void:
	if _mat_lasca == null:
		_mat_lasca = StandardMaterial3D.new()
		_mat_lasca.albedo_color = Color("c9a06a")
		_mat_lasca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 10
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.0, 0)
	var q := BoxMesh.new()
	q.size = Vector3(0.07, 0.03, 0.12)
	p.mesh = q
	p.material_override = _mat_lasca
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match_ref.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _tombar(i: int, dir: Vector3) -> void:
	var v := _vegetacao()
	var a: Dictionary = v.derrubar(i)
	if a.is_empty():
		return
	var base: Vector3 = a.pos
	var r: float = clampf(float(a.raio), 0.2, 0.7)
	_toco(i, base, r)
	# tronco caído: gira em torno da base (eixo horizontal perpendicular à direção da queda) por ~1,6 s com aceleração
	var pivo := Node3D.new()
	pivo.name = "ArvoreCaindo"
	match_ref.add_child(pivo)
	pivo.global_position = base + Vector3(0, r * 0.8, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = a.mesh
	var xf: Transform3D = a.xf
	mi.transform = Transform3D(xf.basis, Vector3(0, -r * 0.8 - 0.05, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivo.add_child(mi)
	var eixo := Vector3.UP.cross(dir).normalized()
	var queda_total := deg_to_rad(89.0)
	_caidas.append(pivo)
	if _caidas.size() > MAX_CAIDAS:
		var velha: Node3D = _caidas.pop_front()
		if is_instance_valid(velha):
			velha.queue_free()
	Audio.play_at("impact_wood", base + Vector3(0, 2, 0), {"volume_db": 6.0, "pitch": 0.5, "max_distance": 90.0})
	var tw := create_tween()
	tw.tween_method(_girar.bind(pivo, eixo), 0.0, queda_total, TEMPO_QUEDA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_aterrissou.bind(pivo, base, dir, i))


func _girar(ang: float, pivo: Node3D, eixo: Vector3) -> void:
	if is_instance_valid(pivo):
		pivo.basis = Basis(eixo, ang)


func _aterrissou(pivo: Node3D, base: Vector3, dir: Vector3, i: int) -> void:
	if not is_instance_valid(pivo):
		return
	var fim := base + dir * 5.0
	Audio.play_at("impact_wood", fim, {"volume_db": 9.0, "pitch": 0.4, "max_distance": 100.0})
	Audio.play_at("impact_sand", fim, {"volume_db": 6.0, "pitch": 0.55, "max_distance": 100.0})
	Audio.emitir_barulho(fim, 40.0, null)
	var pc = match_ref.local_player.controller if match_ref.local_player else null
	if pc != null and pc.global_position.distance_to(base) < 25.0:
		pc.shake(0.35)
	_folhas(fim + Vector3(0, 1.0, 0))
	get_tree().create_timer(0.7).timeout.connect(_virar_toras.bind(pivo, base, dir, i))   # pausa curta e o tronco vira toras


func _virar_toras(pivo: Node3D, base: Vector3, dir: Vector3, i: int) -> void:
	if is_instance_valid(pivo):
		pivo.queue_free()
	_caidas.erase(pivo)
	_spawn_toras(base, dir)
	Audio.play_at("impact_wood", base, {"volume_db": 5.0, "pitch": 0.9, "max_distance": 60.0})
	get_tree().create_timer(RESPAWN_S).timeout.connect(_respawn.bind(i))


func _folhas(pos: Vector3) -> void:
	if _mat_folha == null:
		_mat_folha = StandardMaterial3D.new()
		_mat_folha.albedo_color = Color("4d7a32")
		_mat_folha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 16
	p.lifetime = 1.4
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -3.0, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.12)
	p.mesh = q
	p.material_override = _mat_folha
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match_ref.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _toco(i: int, base: Vector3, r: float) -> void:
	if _mat_toco == null:
		_mat_toco = StandardMaterial3D.new()
		_mat_toco.albedo_color = Color("6b4a2e")
		_mat_toco.roughness = 1.0
	var t := MeshInstance3D.new()
	t.name = "Toco"
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.8
	cm.bottom_radius = r * 1.05
	cm.height = 0.55
	cm.radial_segments = 8
	cm.rings = 1
	t.mesh = cm
	t.material_override = _mat_toco
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.visibility_range_end = 120.0
	match_ref.add_child(t)
	t.global_position = base + Vector3(0, 0.2, 0)
	_tocos[i] = t


func _respawn(i: int) -> void:
	var v := _vegetacao()
	if v != null:
		v.restaurar(i)
	var t = _tocos.get(i)
	if t != null and is_instance_valid(t):
		t.queue_free()
	_tocos.erase(i)


## 5 toras em leque em volta do toco, do lado de onde o lenhador cortou (ao alcance dos 3 m de PROXIMIDADE).
func _spawn_toras(base: Vector3, dir: Vector3) -> Array:
	var out: Array = []
	# em volta do toco, nos flancos e atrás (vistas de quem corta, a ≤ 3 m dele); ângulos medidos a partir da direção da queda
	var angs := [-105.0, -80.0, 80.0, 105.0, 180.0]
	for k in TORAS_POR_ARVORE:
		var d := dir.rotated(Vector3.UP, deg_to_rad(float(angs[k])))
		var pos := base + d * (1.15 + 0.12 * float(k % 2))
		out.append(drop_com_modelo(match_ref, "tora", 1, pos, randf() * TAU))
	return out


## Cria um BRDrop e troca a caixa genérica pelo modelo do item (`model_path` do JSON). BRDrop.MODELOS só conhece armas/munição/mochila.
static func drop_com_modelo(m: Match, id: String, qtd: int, pos: Vector3, yaw := 0.0) -> BRDrop:
	var d: BRDrop = m.criar_drop(id, qtd, pos)
	if d == null:
		return null
	var path := String(BRInventory.definition(id).get("model_path", ""))
	var vis = d.get("_visual")
	if path != "" and ResourceLoader.exists(path) and vis != null and (vis as Node3D).get_child_count() > 0:
		var velho := (vis as Node3D).get_child(0)
		if velho is MeshInstance3D and (velho as MeshInstance3D).mesh is BoxMesh:
			velho.queue_free()
			var sc: Node3D = (load(path) as PackedScene).instantiate()
			sc.rotation.y = yaw
			(vis as Node3D).add_child(sc)
			(vis as Node3D).move_child(sc, 0)
			for g in sc.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				(g as GeometryInstance3D).visibility_range_end = 70.0
	return d
