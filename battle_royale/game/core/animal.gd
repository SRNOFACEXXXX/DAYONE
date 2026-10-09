extends CharacterBody3D
## Animal vivo (cervo, galinha, lobo, cachorro). Modelos animados gerados por tools/blender/animar_animais.py
## (clipes: parado, andar, correr, comer, morrer). IA leve, sem pathfinding (campo aberto): pasta/anda à toa, foge do
## jogador/tiro (presas), caça o jogador (lobo). Leva tiro pelo mesmo caminho do zumbi (Area3D com meta "zombie" e
## hit_by_bullet), morre e vira carcaça: E com FACA esfola (carne crua, pele, gordura, osso -> chão, inventário de
## proximidade). Sem class_name: carregado por preload (core/animal_director.gd).

const DEAD := 6                      # == ZombieEnemy.State.DEAD (o tiro do Soldier compara com isso)
const LAYER_HIT := 32                # == ZombieEnemy.LAYER_HIT
const GRAVIDADE := 18.0
## espécie: modelo, vida, velocidades (andar, correr), distância que nota o jogador, se é predador, rendimento ao esfolar
const ESPECIES := {
	"cervo": {"modelo": "res://assets/models/animais/cervo.glb", "vida": 90, "andar": 1.3, "correr": 9.5, "nota": 32.0,
		"predador": false, "altura": 1.6, "raio": 0.45, "esfolar": {"carne_crua": 4, "pele": 1, "gordura": 1, "osso": 2}},
	"galinha": {"modelo": "res://assets/models/animais/galinha.glb", "vida": 15, "andar": 0.7, "correr": 4.0, "nota": 9.0,
		"predador": false, "altura": 0.4, "raio": 0.18, "esfolar": {"carne_crua": 1, "osso": 1}},
	"lobo": {"modelo": "res://assets/models/animais/lobo.glb", "vida": 70, "andar": 1.4, "correr": 8.0, "nota": 38.0,
		"predador": true, "altura": 0.9, "raio": 0.35, "dano": 14, "esfolar": {"carne_crua": 2, "pele": 1, "gordura": 1, "osso": 2}},
	"cachorro": {"modelo": "res://assets/models/animais/cachorro.glb", "vida": 50, "andar": 1.2, "correr": 7.0, "nota": 18.0,
		"predador": false, "altura": 0.7, "raio": 0.3, "esfolar": {"carne_crua": 2, "osso": 1}},
}
enum Modo { PASTAR, ANDAR, FUGIR, CACAR, ATACAR }

var especie := "cervo"
var state := 0                       # 0 vivo, DEAD morto (compatível com o tiro do Soldier)
var vida := 90
var esfolado := false
var _cfg: Dictionary
var _modo := Modo.PASTAR
var _t_modo := 0.0
var _rumo := Vector3.FORWARD
var _alvo: Node3D
var _anim: AnimationPlayer
var _clip := ""
var _t_ataque := 0.0
var _rng := RandomNumberGenerator.new()
var terrain: Node


func configurar(nome: String, terreno: Node) -> void:
	especie = nome
	terrain = terreno
	_cfg = ESPECIES[nome]
	vida = int(_cfg.vida)


func _ready() -> void:
	_rng.randomize()
	if _cfg.is_empty():
		_cfg = ESPECIES[especie]
	add_to_group("animal")
	collision_layer = 1 << 1          # como o zumbi: corpo que bloqueia
	collision_mask = 1
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(_cfg.raio)
	cap.height = maxf(float(_cfg.altura), cap.radius * 2.0 + 0.01)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	var hit := Area3D.new()
	hit.name = "HitArea"
	hit.collision_layer = LAYER_HIT
	hit.collision_mask = 0
	hit.monitoring = false
	hit.set_meta("zombie", self)
	var hs := CollisionShape3D.new()
	var hb := CapsuleShape3D.new()
	hb.radius = float(_cfg.raio) * 1.15
	hb.height = maxf(float(_cfg.altura), hb.radius * 2.0 + 0.01)
	hs.shape = hb
	hs.position.y = hb.height * 0.5
	hit.add_child(hs)
	add_child(hit)
	var cena: PackedScene = load(String(_cfg.modelo))
	if cena:
		var m := cena.instantiate()
		add_child(m)
		for g in m.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = 140.0
		_anim = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_rumo = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	_t_modo = _rng.randf_range(2.0, 6.0)
	if Audio.barulho.is_connected(_ouviu) == false:
		Audio.barulho.connect(_ouviu)
	_tocar("parado")


func _tocar(clip: String, vel := 1.0) -> void:
	if _anim == null or _clip == clip:
		if _anim:
			_anim.speed_scale = vel
		return
	_clip = clip
	if _anim.has_animation(clip):
		var a := _anim.get_animation(clip)
		a.loop_mode = Animation.LOOP_NONE if clip == "morrer" else Animation.LOOP_LINEAR
		_anim.play(clip, 0.2)
		_anim.speed_scale = vel


func _jogador() -> Node3D:
	var m = Game.current_match
	if m and is_instance_valid(m) and "local_player" in m and is_instance_valid(m.local_player) and m.local_player.alive:
		return m.local_player
	return null


func _ouviu(pos: Vector3, raio: float, fonte: Node) -> void:
	if state == DEAD or fonte == self:
		return
	if global_position.distance_to(pos) > minf(raio, 160.0):
		return
	if bool(_cfg.predador):
		if fonte is Node3D:
			_alvo = fonte
			_mudar(Modo.CACAR, 12.0)
	else:
		_rumo = (global_position - pos)
		_rumo.y = 0
		_rumo = _rumo.normalized() if _rumo.length_squared() > 0.01 else _rumo
		_mudar(Modo.FUGIR, _rng.randf_range(6.0, 10.0))


func _mudar(m: int, dur: float) -> void:
	_modo = m
	_t_modo = dur


func _physics_process(dt: float) -> void:
	if state == DEAD:
		if not is_on_floor():
			velocity.y -= GRAVIDADE * dt
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
		return
	_t_modo -= dt
	_t_ataque = maxf(_t_ataque - dt, 0.0)
	var p := _jogador()
	var d := global_position.distance_to(p.global_position) if p else INF
	# percepção: presa foge, predador caça
	if p and d < float(_cfg.nota) and _modo in [Modo.PASTAR, Modo.ANDAR]:
		if bool(_cfg.predador):
			_alvo = p
			_mudar(Modo.CACAR, 15.0)
		else:
			_rumo = global_position - p.global_position
			_rumo.y = 0
			_rumo = _rumo.normalized()
			_mudar(Modo.FUGIR, _rng.randf_range(5.0, 9.0))
	var vel_alvo := 0.0
	match _modo:
		Modo.PASTAR:
			_tocar("comer" if int(_t_modo * 0.5) % 2 == 0 else "parado")
			if _t_modo <= 0.0:
				_rumo = _rumo.rotated(Vector3.UP, _rng.randf_range(-1.5, 1.5))
				_mudar(Modo.ANDAR, _rng.randf_range(3.0, 8.0))
		Modo.ANDAR:
			vel_alvo = float(_cfg.andar)
			_tocar("andar", 1.0)
			if _t_modo <= 0.0:
				_mudar(Modo.PASTAR, _rng.randf_range(4.0, 10.0))
		Modo.FUGIR:
			vel_alvo = float(_cfg.correr)
			_tocar("correr", 1.1)
			if _t_modo <= 0.0:
				_mudar(Modo.PASTAR, _rng.randf_range(3.0, 6.0))
		Modo.CACAR, Modo.ATACAR:
			if not is_instance_valid(_alvo) or (_alvo is Soldier and not (_alvo as Soldier).alive) or _t_modo <= 0.0 or d > 90.0:
				_mudar(Modo.ANDAR, 4.0)
			else:
				var para := _alvo.global_position - global_position
				para.y = 0
				var dist := para.length()
				_rumo = para / maxf(dist, 0.01)
				if dist < 1.6:
					vel_alvo = 0.0
					_tocar("comer", 1.6)   # mordida
					if _t_ataque <= 0.0:
						_t_ataque = 1.1
						var dano := float(_cfg.get("dano", 10))
						if _alvo is Soldier:   # mesmo caminho do ataque do zumbi (zombie.gd)
							(_alvo as Soldier).take_damage(dano, null, null, "legs", (_alvo.global_position - global_position).normalized())
						elif _alvo.has_method("take_damage"):
							_alvo.call("take_damage", int(dano))
						if Audio.has_sound("zombie_attack"):
							Audio.play_at("zombie_attack", global_position, {"volume_db": -4.0, "pitch": 1.35, "max_distance": 30.0})
				else:
					vel_alvo = float(_cfg.correr)
					_tocar("correr", 1.15)
	# água/borda: presa não entra no mar
	if terrain and terrain.has_method("height_world"):
		var a_frente := global_position + _rumo * 3.0
		if float(terrain.height_world(a_frente.x, a_frente.z)) < 0.6:
			_rumo = -_rumo
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(_rumo * vel_alvo, 14.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = velocity.y - GRAVIDADE * dt if not is_on_floor() else -0.5
	move_and_slide()
	if is_on_wall() and _modo in [Modo.ANDAR, Modo.FUGIR]:
		_rumo = _rumo.rotated(Vector3.UP, _rng.randf_range(1.2, 2.4))
	if hv.length_squared() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(hv.x, hv.z), clampf(dt * 6.0, 0.0, 1.0))


## Tiro do Soldier (mesmo contrato do zumbi). Animal não tem zona de cabeça: dano pela fração de corpo da arma.
func hit_by_bullet(pos: Vector3, dir: Vector3, def: WeaponDef, escala := 1.0, attacker: Node3D = null) -> Dictionary:
	var frac: float = def.zumbi_corpo if def else 0.5
	var dano := maxi(1, roundi(float(_cfg.vida) * frac * 1.2 * escala))
	receber_dano(dano, attacker)
	if FxManager.shared:
		FxManager.shared.blood(pos, dir, false, float(dano))
	return {"zone": &"body", "damage": dano, "killed": state == DEAD}


func receber_dano(dano: int, attacker: Node3D = null) -> void:
	if state == DEAD:
		return
	vida -= dano
	if vida <= 0:
		_morrer()
		return
	if bool(_cfg.predador) and attacker:
		_alvo = attacker
		_mudar(Modo.CACAR, 15.0)
	else:
		_rumo = global_position - (attacker.global_position if attacker else global_position - _rumo)
		_rumo.y = 0
		_rumo = _rumo.normalized() if _rumo.length_squared() > 0.01 else Vector3.FORWARD
		_mudar(Modo.FUGIR, 10.0)


func _morrer() -> void:
	state = DEAD
	vida = 0
	velocity = Vector3.ZERO
	_tocar("morrer")
	var hit := get_node_or_null("HitArea")
	if hit:
		hit.collision_layer = 0
	collision_layer = 0
	add_to_group("carcaca")
	set_meta("interacao", "Esfolar (faca)")


## Esfolar a carcaça (precisa de faca). Devolve o que caiu (id -> qtd); o chamador põe no chão/inventário.
func esfolar(tem_faca: bool) -> Dictionary:
	if state != DEAD or esfolado or not tem_faca:
		return {}
	esfolado = true
	remove_from_group("carcaca")
	var r: Dictionary = _cfg.esfolar.duplicate()
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(queue_free)
	return r
