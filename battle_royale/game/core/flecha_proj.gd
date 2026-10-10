extends Node3D
## Flecha em voo (arco): balística simples (gravidade), segmento por quadro contra o mundo e as caixas de acerto de zumbis/animais.
## Acerto em criatura: ferida pela tabela de dano do arco (cabeça pesa muito) e a flecha some; no cenário, crava e fica 25 s.
## Sem class_name (preload em ferramentas_mao).
const GRAVIDADE := 9.8
const VIDA_S := 6.0
static var _def_arco: WeaponDef

var vel := Vector3.ZERO
var autor: Soldier
var escala_dano := 1.0
var _t := 0.0
var _cravada := false


static func def_arco() -> WeaponDef:
	if _def_arco == null:
		_def_arco = WeaponDef.new()
		_def_arco.id = &"arco"
		_def_arco.display_name = "Arco"
		_def_arco.damage = 1.0
		_def_arco.zumbi_cabeca = 0.95
		_def_arco.zumbi_corpo = 0.42
	return _def_arco


static func disparar(raiz: Node, de: Soldier, origem: Vector3, direcao: Vector3, forca: float, modelo: PackedScene) -> Node3D:
	var f: Node3D = load("res://core/flecha_proj.gd").new()
	raiz.add_child(f)
	f.global_position = origem
	f.vel = direcao.normalized() * (16.0 + 44.0 * clampf(forca, 0.0, 1.0))
	f.autor = de
	f.escala_dano = 0.45 + 0.75 * clampf(forca, 0.0, 1.0)
	if modelo != null:
		var vis: Node3D = modelo.instantiate()
		f.add_child(vis)
		vis.name = "Modelo"
		for g in vis.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f._orientar()
	return f


func _orientar() -> void:
	var m := get_node_or_null("Modelo") as Node3D
	if m == null or vel.length_squared() < 0.01:
		return
	# o modelo tem o comprimento em +Y (ponta para cima): alinha +Y à velocidade
	var y := vel.normalized()
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	m.global_basis = Basis(x, y, x.cross(y))


func _physics_process(dt: float) -> void:
	_t += dt
	if _cravada:
		if _t > 25.0:
			queue_free()
		return
	if _t > VIDA_S + 25.0:
		queue_free()
		return
	var p := global_position
	vel.y -= GRAVIDADE * dt
	var np := p + vel * dt
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p, np, Soldier.LAYER_WORLD | ZombieEnemy.LAYER_HIT, [autor.get_rid()] if autor != null else [])
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		global_position = np
		_orientar()
		return
	var col: Object = hit.collider
	global_position = hit.position
	if col is Area3D and (col as Area3D).has_meta("zombie"):
		var alvo = (col as Area3D).get_meta("zombie")
		if is_instance_valid(alvo) and alvo.state != 6:   # 6 == DEAD (zumbi e animal)
			alvo.hit_by_bullet(hit.position, vel.normalized(), def_arco(), escala_dano, autor)
			queue_free()
			return
		# atravessa carcaça
		global_position = np
		return
	_cravada = true
	_t = 0.0
	# crava um pouco para dentro da superfície
	global_position = hit.position + vel.normalized() * 0.12
	if Audio.has_sound("impact_wood"):
		Audio.play_at("impact_wood", global_position, {"volume_db": -2.0, "max_distance": 40.0})
