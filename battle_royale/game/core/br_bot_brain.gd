class_name BRBotBrain
extends BotBrain
## Bot do battle royale: reaproveita percepção, mira e tiro do BotBrain (todos contra todos via Match.is_ally)
## e troca os objetivos de CS por: pousar num ponto de saque escolhido -> pegar arma -> fugir da zona -> rodar
## entre pontos de saque dentro da próxima zona. Sem navmesh na ilha: condução direta ao alvo + destravar do BotBrain.

var pouso := Vector3.ZERO        # ponto de saque onde o bot quer pousar (escolhido no avião)
var salto_t := 0.0               # instante do voo em que ele salta
var _proximo_giro := 0.0


## Depois da ação do BotBrain: não anda para barranco (> 2 m a 1,5 m ou > 3 m a 3 m à frente) nem para o mar — sem navmesh,
## a condução direta levava bots pedreira/falésia abaixo (morte por queda). Troca de objetivo quando isso acontece.
func _physics_process(dt: float) -> void:
	# Não usa combate/destravar do CS durante voo; a mira não deve desviar o pouso.
	if s != null and s.alive and s.external_motion:
		_now += dt
		s.in_fire = false
		s.in_jump = false
		s.in_move = Vector2.ZERO
		var br_voo := m as BRMatch
		if br_voo != null and br_voo.estado.get(s, "aviao") != "aviao":
			var delta := pouso - s.global_position
			delta.y = 0.0
			var local := Basis(Vector3.UP, s.yaw).inverse() * delta.limit_length(1.0)
			s.in_move = Vector2(local.x, -local.z)
		return
	super(dt)
	if s == null or not s.alive or s.in_move.length() < 0.1 or not s.is_on_floor():
		return
	var br := m as BRMatch
	if br == null or br.estado.get(s, "chao") != "chao":
		return
	var b := Basis(Vector3.UP, s.yaw)
	var dir := (b * Vector3(s.in_move.x, 0.0, -s.in_move.y)).normalized()
	var p := s.global_position
	var t: IlhaTerrain = br.ilha.terrain
	var aqui := p.y   # inclui lajes e pontes; o heightmap pode estar muito abaixo
	var perto := p + dir * 1.5
	var frente := p + dir * 3.0
	var h1 := br._piso(perto + Vector3.UP * 0.5, t.height_world(perto.x, perto.z))
	var h2 := br._piso(frente + Vector3.UP * 0.5, t.height_world(frente.x, frente.z))
	# barranco (queda > ~2 m logo à frente) ou mar (sem natação): para e escolhe outro objetivo
	if aqui - h1 > 2.0 or aqui - h2 > 3.0 or h1 < -0.3 or h2 < -0.3:
		s.in_move = Vector2.ZERO
		s.in_jump = false
		s.velocity.x = 0.0
		s.velocity.z = 0.0
		has_goal = false
		_proximo_giro = 0.0


func _update_objective() -> void:
	var br := m as BRMatch
	if br == null:
		return
	no_path_t = 9.0   # condução direta (não espera caminho de navmesh que não existe)
	var est: String = br.estado.get(s, "chao")
	if est != "chao":
		_set_goal(pouso, Task.HOLD)
		return
	var p := s.global_position
	# 1) zona: se estiver fora da próxima zona (com folga), corre para dentro dela
	var c: Vector2 = br.zona_prox_c
	var r: float = br.zona_prox_r
	var d := Vector2(p.x, p.z).distance_to(c)
	if d > r * 0.85 + 2.0:
		var alvo := c + (Vector2(p.x, p.z) - c).limit_length(r * 0.5)
		_set_goal(_no_chao(alvo), Task.HUNT)
		return
	# 2) sem arma primária: caixa de suprimento mais próxima (até 250 m); abre e pega a arma ao chegar
	if not s.inventory.has(WeaponDef.Slot.PRIMARY):
		var melhor: BRCrate = null
		var md := 250.0
		for node in br.br_loot_root.get_children():
			var cr := node as BRCrate
			if cr == null or cr.contents.items.is_empty():
				continue
			var dd := cr.global_position.distance_to(p)
			if dd < md:
				md = dd
				melhor = cr
		if melhor:
			if md < 2.2:
				br.bot_saquear(s, melhor)
			else:
				_set_goal(melhor.global_position, Task.HUNT)
				return
	# 3) roda entre pontos de saque dentro da próxima zona
	if not has_goal or p.distance_to(goal) < 3.0 or _now > _proximo_giro:
		_proximo_giro = _now + _rng.randf_range(25.0, 45.0)
		var pontos: Array = br.pontos_saque
		for tentativa in 12:
			var q: Vector3 = pontos[_rng.randi() % pontos.size()]
			if Vector2(q.x, q.z).distance_to(c) < r * 0.8 and q.distance_to(p) < 220.0:
				_set_goal(q, Task.HUNT)
				return
		_set_goal(_no_chao(c), Task.HUNT)


func _no_chao(xz: Vector2) -> Vector3:
	var t: IlhaTerrain = (m as BRMatch).ilha.terrain
	return Vector3(xz.x, t.height_world(xz.x, xz.y), xz.y)
