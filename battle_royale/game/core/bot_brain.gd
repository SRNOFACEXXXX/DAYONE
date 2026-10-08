class_name BotBrain
extends Node
## Bot controller. Perception (FOV + line of sight + hearing), reaction time, human-like aim with
## recoil control, and bomb-defusal objectives driven by map-authored routes and hold spots.

enum Task { IDLE, ROUTE, HOLD, PLANT, GUARD_BOMB, RETAKE, DEFUSE, FETCH_BOMB, HUNT }

const REACTION := [0.55, 0.36, 0.24, 0.16]
const TURN_SPEED := [200.0, 330.0, 520.0, 760.0]         # graus/s
const AIM_ERR_START := [7.0, 4.5, 2.8, 1.6]
const AIM_ERR_END := [1.6, 0.9, 0.5, 0.22]
const HEAD_CHANCE := [0.06, 0.15, 0.28, 0.45]
const RECOIL_COMP := [0.25, 0.55, 0.75, 0.92]
const VIEW_DIST := 95.0
const FOV_DOT := 0.25                                      # ~150° de campo de visão

var s: Soldier
var m: Match
var agent: NavigationAgent3D
var diff := 1
var task := Task.IDLE
var goal := Vector3.ZERO
var goal_look := Vector3.ZERO
var has_goal := false
var route: Array[Vector3] = []
var route_i := 0
var plan_site := "A"
var hold_node: Node3D = null

var target: Soldier = null
var target_since := -1.0
var aim_err := Vector2.ZERO
var aim_point_head := false
var memory: Dictionary = {}      # Soldier -> {"pos": Vector3, "t": float}
var alert_pos := Vector3.ZERO
var alert_t := -100.0
var burst_left := 0
var pause_until := 0.0
var strafe_sign := 1.0
var strafe_until := 0.0
var crouch_spray := false
var think_acc := 0.0
var stuck_t := 0.0
var unstuck_until := 0.0
var unstuck_dir := Vector2.ZERO
var last_pos := Vector3.ZERO
var wait_until := 0.0
var bought := false
var repath_at := 0.0
var no_path_t := 0.0
var _desired_yaw := 0.0
var _desired_pitch := 0.0
var _now := 0.0
var _rng := RandomNumberGenerator.new()


func setup(soldier: Soldier, match_node: Match) -> void:
	s = soldier
	m = match_node
	diff = int(Game.config.difficulty)
	_rng.randomize()
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.7
	agent.target_desired_distance = 0.9
	agent.radius = 0.4
	agent.height = 1.8
	agent.max_speed = 6.5
	agent.avoidance_enabled = false
	s.add_child.call_deferred(agent)


# ------------------------------------------------------------------ eventos
func on_round_start() -> void:
	target = null
	memory.clear()
	alert_t = -100.0
	has_goal = false
	route.clear()
	bought = false
	task = Task.IDLE
	wait_until = _now + _rng.randf_range(0.3, 2.2)


func on_round_end(_w: int) -> void:
	task = Task.IDLE
	has_goal = false


func on_soldier_died(victim: Soldier, killer: Soldier) -> void:
	memory.erase(victim)
	if victim == target:
		target = null
	if m.is_ally(victim, s) and killer and not m.is_ally(killer, s):
		_remember(killer, killer.global_position)


func on_damaged(attacker: Soldier, _amount: int) -> void:
	if attacker and not m.is_ally(attacker, s):
		_remember(attacker, attacker.global_position)
		alert_pos = attacker.global_position
		alert_t = _now


func on_noise(source: Soldier, pos: Vector3) -> void:
	if m.is_ally(source, s):
		return
	alert_pos = pos
	alert_t = _now
	_remember(source, pos)


func on_bomb_planted(bomb: Node3D, site: String) -> void:
	has_goal = false
	if s.team == 0:
		task = Task.GUARD_BOMB
	else:
		task = Task.RETAKE
	plan_site = site


func on_bomb_dropped(_p: Node3D) -> void:
	if s.team == 0:
		has_goal = false


func on_heard_defuse(defuser: Soldier) -> void:
	if s.team == 0:
		_remember(defuser, defuser.global_position)
		alert_pos = defuser.global_position
		alert_t = _now


func on_defuse_started() -> void:
	pass


func _remember(e: Soldier, pos: Vector3) -> void:
	memory[e] = {"pos": pos, "t": _now}


# ------------------------------------------------------------------ laço principal
func _physics_process(dt: float) -> void:
	_now += dt
	if s == null or not s.alive or agent == null or not agent.is_inside_tree():
		if s:
			s.in_fire = false
			s.in_move = Vector2.ZERO
		return
	think_acc += dt
	if think_acc >= 0.1:
		think_acc = 0.0
		_perceive()
		_think()
	_act(dt)


func _perceive() -> void:
	var best: Soldier = null
	var best_d := INF
	var eye := s.eye_position()
	var fwd := s.aim_dir()
	for e in m.soldiers:
		if m.is_ally(e, s) or not e.alive:
			continue
		var to := e.eye_position() - eye
		var d := to.length()
		if d > VIEW_DIST:
			continue
		var facing := to.normalized().dot(fwd)
		var recently_known: bool = memory.has(e) and _now - memory[e].t < 1.5
		if facing < FOV_DOT and not (recently_known and d < 25.0):
			continue
		if not _visible(eye, e):
			continue
		_remember(e, e.global_position)
		var score := d * (1.0 if facing > 0.8 else 1.6)
		if score < best_d:
			best_d = score
			best = e
	if best != target:
		if best != null and target == null:
			target_since = _now
			var err: float = AIM_ERR_START[diff] * _rng.randf_range(0.6, 1.3)
			aim_err = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1.0)).normalized() * err
			aim_point_head = _rng.randf() < HEAD_CHANCE[diff]
			burst_left = 0
		elif best != null:
			target_since = _now - REACTION[diff] * 0.5
		target = best


func _visible(eye: Vector3, e: Soldier) -> bool:
	var space := s.get_world_3d().direct_space_state
	for h in [e.eye_position(), e.global_position + Vector3.UP * (1.1 - e.crouch * 0.35)]:
		var q := PhysicsRayQueryParameters3D.create(eye, h, Soldier.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			return true
	return false


func _think() -> void:
	if m.phase == Match.Phase.FREEZE:
		if not bought:
			_buy()
		return
	if m.phase == Match.Phase.ROUND_END:
		return
	if _now < wait_until:
		return
	# recarregar quando seguro
	var ws := s.current()
	if target == null and ws and ws.def.is_gun() and ws.mag < ws.def.mag_size * 0.35 and ws.reserve > 0:
		s.in_reload = true
	else:
		s.in_reload = false
	# troca para a melhor arma
	if target != null or task != Task.PLANT:
		if s.inventory.has(WeaponDef.Slot.PRIMARY) and (s.inventory[WeaponDef.Slot.PRIMARY].mag > 0 or s.inventory[WeaponDef.Slot.PRIMARY].reserve > 0):
			if s.active_slot != WeaponDef.Slot.PRIMARY:
				s.switch_to(WeaponDef.Slot.PRIMARY)
		elif s.inventory.has(WeaponDef.Slot.PISTOL) and s.active_slot not in [WeaponDef.Slot.PISTOL]:
			if s.inventory[WeaponDef.Slot.PISTOL].mag > 0 or s.inventory[WeaponDef.Slot.PISTOL].reserve > 0:
				s.switch_to(WeaponDef.Slot.PISTOL)
	if target != null:
		return
	_update_objective()


func _buy() -> void:
	bought = true
	var primary := &"ak47" if s.team == 0 else &"m4"
	var def := WeaponDB.get_def(primary)
	var wants_rifle := not s.inventory.has(WeaponDef.Slot.PRIMARY)
	if wants_rifle and s.money >= def.price + 650:
		m.try_buy(s, String(primary))
	elif wants_rifle and s.money >= def.price and _rng.randf() < 0.5:
		m.try_buy(s, String(primary))
	if s.armor < 100 or not s.has_helmet:
		if s.money >= 1000:
			m.try_buy(s, "helmet")
		elif s.money >= 650 and s.armor < 50:
			m.try_buy(s, "kevlar")
	if s.team == 1 and s.money >= 400 and _rng.randf() < 0.6:
		m.try_buy(s, "defuser")


# ------------------------------------------------------------------ objetivos
func _update_objective() -> void:
	match m.phase:
		Match.Phase.PLANTED:
			var bomb := m.planted_bomb()
			if bomb == null:
				return
			if s.team == 1:
				_set_goal(bomb.global_position, Task.RETAKE)
				if s.global_position.distance_to(bomb.global_position) < 1.5:
					task = Task.DEFUSE
			else:
				if not has_goal or task != Task.GUARD_BOMB:
					var spot := _pick_marker("post_plant_" + m.bomb_site.to_lower())
					var p := spot.global_position if spot else bomb.global_position + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
					_set_goal(p, Task.GUARD_BOMB)
					if spot:
						goal_look = -spot.global_basis.z
			return
	# bomba no chão: TR mais próximo vai buscar
	var dropped := m.dropped_bomb()
	if s.team == 0 and dropped:
		var nearest: Soldier = null
		var nd := INF
		for mate in m.team_members(0, true):
			var d := mate.global_position.distance_to(dropped.global_position)
			if d < nd:
				nd = d
				nearest = mate
		if nearest == s:
			_set_goal(dropped.global_position, Task.FETCH_BOMB)
			return
	if s.team == 0:
		if s.is_carrying_bomb:
			_t_carrier()
		elif not has_goal:
			_t_follow_plan()
	else:
		if not has_goal:
			_ct_take_position()
	# chegou num ponto de espera?
	if has_goal and task in [Task.HOLD, Task.GUARD_BOMB] and s.global_position.distance_to(goal) < 1.2:
		pass


func _plan_for_team() -> String:
	# plano do time TR por rodada (todos seguem o mesmo site, com rotas diferentes)
	if not m.has_meta("t_plan_round") or m.get_meta("t_plan_round") != m.round_number:
		m.set_meta("t_plan_round", m.round_number)
		m.set_meta("t_plan_site", "A" if randf() < 0.5 else "B")
	return m.get_meta("t_plan_site")


func _t_follow_plan() -> void:
	plan_site = _plan_for_team()
	var routes := _routes_for("t_" + plan_site.to_lower())
	if not routes.is_empty():
		var r: Node3D = routes[_rng.randi() % routes.size()]
		route.clear()
		for c in r.get_children():
			if c is Node3D:
				route.append((c as Node3D).global_position)
		# retoma do ponto da rota mais próximo (não volta ao spawn ao replanejar)
		route_i = 0
		var bd := INF
		for k in route.size():
			var d := s.global_position.distance_to(route[k])
			if d < bd:
				bd = d
				route_i = k
		if route_i < route.size() - 1 and bd < 8.0:
			route_i += 1
		task = Task.ROUTE
		has_goal = true
		goal = route[route_i]
		agent.target_position = goal
	else:
		var z := m.bombsite(plan_site)
		if z:
			_set_goal(z.random_point_on_floor(1.0), Task.ROUTE)


func _t_carrier() -> void:
	plan_site = _plan_for_team()
	var site := m.site_at(s.global_position)
	if site != "" and m.can_plant():
		var plant := _pick_marker("plant_" + site.to_lower())
		if plant == null or s.global_position.distance_to(plant.global_position) < 1.5 or not has_goal:
			task = Task.PLANT
			has_goal = false
			return
	if not has_goal or task != Task.ROUTE:
		_t_follow_plan()
		# o carregador entra no site pelo ponto de plantar
		var plant2 := _pick_marker("plant_" + plan_site.to_lower())
		if plant2:
			route.append(plant2.global_position)


func _ct_take_position() -> void:
	# distribuição: 2 no A, 2 no B, 1 meio (pela ordem na lista do time)
	var mates := m.team_members(1)
	var idx := mates.find(s)
	var kind: String = ["hold_a", "hold_b", "hold_a", "hold_b", "hold_mid"][idx % 5]
	var spot := _pick_marker(kind, idx)
	if spot == null:
		spot = _pick_marker("hold_a" if idx % 2 == 0 else "hold_b", idx)
	if spot:
		_set_goal(spot.global_position, Task.HOLD)
		goal_look = -spot.global_basis.z
	else:
		var z := m.bombsite("A" if idx % 2 == 0 else "B")
		if z:
			_set_goal(z.random_point_on_floor(1.5), Task.HOLD)


func _routes_for(prefix: String) -> Array:
	var out := []
	for r in m.get_tree().get_nodes_in_group("bot_routes"):
		if String(r.name).to_lower().begins_with(prefix):
			out.append(r)
	return out


func _pick_marker(kind: String, seed_idx := -1) -> Node3D:
	var list := []
	for n in m.get_tree().get_nodes_in_group("bot_points"):
		if String(n.get_meta("kind", "")) == kind:
			list.append(n)
	if list.is_empty():
		return null
	if seed_idx >= 0:
		return list[seed_idx % list.size()]
	return list[_rng.randi() % list.size()]


func _set_goal(p: Vector3, t: Task) -> void:
	if has_goal and task == t and goal.distance_to(p) < 0.8:
		return
	goal = p
	task = t
	has_goal = true
	route.clear()
	agent.target_position = p


# ------------------------------------------------------------------ ação (a cada tick)
func _act(dt: float) -> void:
	s.in_fire = false
	s.in_use = false
	s.in_jump = false
	var move_dir := Vector3.ZERO
	var look_target := Vector3.ZERO
	var has_look := false
	var engaging := target != null and target.alive and m.phase != Match.Phase.FREEZE

	if m.phase == Match.Phase.FREEZE or m.phase == Match.Phase.ROUND_END and not engaging:
		s.in_move = Vector2.ZERO
		s.in_walk = false
		s.in_crouch = false
		return

	# --- movimento para o objetivo ---
	if has_goal and not (task == Task.PLANT or task == Task.DEFUSE):
		if task == Task.ROUTE and not route.is_empty() and s.global_position.distance_to(route[route_i]) < 2.2:
			route_i += 1
			if route_i >= route.size():
				route.clear()
				has_goal = false
				if s.team == 0 and not s.is_carrying_bomb:
					# chegou no site: segura uma posição de TR ali
					var z := m.bombsite(plan_site)
					if z:
						_set_goal(z.random_point_on_floor(2.0), Task.GUARD_BOMB)
			else:
				agent.target_position = route[route_i]
		if has_goal:
			var tgt := agent.target_position
			var flat_d := Vector2(tgt.x - s.global_position.x, tgt.z - s.global_position.z).length()
			var arrived := flat_d < 1.0
			if not arrived and agent.is_navigation_finished():
				# caminho vazio (navmesh ainda não pronto ou alvo fora da malha): repete o pedido
				if _now > repath_at:
					repath_at = _now + 0.5
					agent.target_position = tgt
				no_path_t += dt
			else:
				no_path_t = 0.0
			if not arrived:
				var nxt := agent.get_next_path_position()
				if no_path_t > 1.5 or nxt.distance_to(s.global_position) < 0.05:
					nxt = tgt
				move_dir = nxt - s.global_position
				move_dir.y = 0.0
				if move_dir.length() > 0.01:
					move_dir = move_dir.normalized()
				look_target = s.eye_position() + move_dir * 5.0
				has_look = true
			elif task in [Task.HOLD, Task.GUARD_BOMB] and goal_look != Vector3.ZERO:
				look_target = s.eye_position() + goal_look * 10.0
				has_look = true

	# --- plantar / desarmar ---
	if task == Task.PLANT:
		if s.is_carrying_bomb and m.site_at(s.global_position) != "" and m.can_plant():
			if s.active_slot != WeaponDef.Slot.BOMB:
				s.switch_to(WeaponDef.Slot.BOMB)
			move_dir = Vector3.ZERO
			if not engaging:
				s.in_fire = true
				s.pitch = move_toward(s.pitch, deg_to_rad(-35.0), dt * 2.0)
		else:
			task = Task.IDLE
			has_goal = false
	if task == Task.DEFUSE or (task == Task.RETAKE and m.planted_bomb() and s.global_position.distance_to(m.planted_bomb().global_position) < 1.6):
		var bomb := m.planted_bomb()
		if bomb:
			move_dir = Vector3.ZERO
			look_target = bomb.global_position
			has_look = true
			# desarma se não houver inimigo visível (ou se não houver tempo)
			if not engaging or m.phase_left < (Soldier.DEFUSE_TIME_KIT if s.has_defuser else Soldier.DEFUSE_TIME) + 0.5:
				s.in_use = true
				engaging = false

	# --- alerta: olhar para o último barulho ---
	if not engaging and _now - alert_t < 2.5 and not s.in_use:
		look_target = alert_pos + Vector3.UP * 1.4
		has_look = true
		if task != Task.ROUTE:
			move_dir *= 0.5

	# --- combate ---
	s.in_walk = false
	s.in_crouch = false
	if engaging:
		_combat(dt)
		var dist := s.global_position.distance_to(target.global_position)
		var def := s.current_def()
		var rifle := def != null and def.slot == WeaponDef.Slot.PRIMARY
		if rifle and dist > 12.0:
			# para de andar para atirar parado (contra-strafe)
			move_dir = Vector3.ZERO
			s.in_crouch = crouch_spray and burst_left > 4
		else:
			if _now > strafe_until:
				strafe_sign = -strafe_sign
				strafe_until = _now + _rng.randf_range(0.25, 0.7)
			var right := Basis(Vector3.UP, s.yaw).x
			move_dir = right * strafe_sign * (0.35 if rifle else 0.8)
	else:
		if has_look:
			var d := look_target - s.eye_position()
			if d.length() > 0.1:
				_desired_yaw = atan2(-d.x, -d.z)
				_desired_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)
		_turn_towards(dt, 0.55)

	# --- destravar ---
	if move_dir.length() > 0.1 and s.is_on_floor():
		if s.global_position.distance_to(last_pos) < 0.02:
			stuck_t += dt
		else:
			stuck_t = maxf(stuck_t - dt, 0.0)
		if stuck_t > 0.8:
			stuck_t = 0.0
			unstuck_until = _now + 0.6
			var r := Basis(Vector3.UP, s.yaw).x * (1.0 if _rng.randf() < 0.5 else -1.0)
			unstuck_dir = Vector2(r.x, r.z)
			s.in_jump = _rng.randf() < 0.5
			if has_goal:
				agent.target_position = agent.target_position
	last_pos = s.global_position
	if _now < unstuck_until:
		move_dir = Vector3(unstuck_dir.x, 0, unstuck_dir.y)

	# converte direção de mundo em intenção local (frente/direita)
	var b := Basis(Vector3.UP, s.yaw)
	var fwd := -b.z
	var right2 := b.x
	s.in_move = Vector2(move_dir.dot(right2), move_dir.dot(fwd))
	if not engaging and task == Task.HOLD and has_goal and s.global_position.distance_to(goal) < 5.0:
		s.in_walk = true


func _turn_towards(dt: float, speed_scale: float) -> void:
	var max_step := deg_to_rad(TURN_SPEED[diff] * speed_scale) * dt
	var dy := wrapf(_desired_yaw - s.yaw, -PI, PI)
	s.yaw += clampf(dy, -max_step, max_step)
	s.pitch += clampf(_desired_pitch - s.pitch, -max_step, max_step)


func _combat(dt: float) -> void:
	var def := s.current_def()
	var aim_at := target.eye_position() + Vector3.UP * 0.02 if aim_point_head else target.global_position + Vector3.UP * (1.12 - target.crouch * 0.35)
	var eye := s.eye_position()
	var d := aim_at - eye
	var dist := d.length()
	# erro de mira diminui com o tempo de rastreio
	var tracking := clampf((_now - target_since) / 0.7, 0.0, 1.0)
	var err_now: float = lerpf(AIM_ERR_START[diff], AIM_ERR_END[diff], tracking)
	var err_vec := aim_err.normalized() * err_now if aim_err.length() > 0.0 else Vector2.ZERO
	var yaw_t := atan2(-d.x, -d.z) + deg_to_rad(err_vec.x) * 0.5
	var pitch_t := atan2(d.y, Vector2(d.x, d.z).length()) + deg_to_rad(err_vec.y) * 0.5
	# compensação de recuo: puxa a mira contra o padrão
	if def and def.is_gun():
		var pat := def.pattern_offset(s.shots_fired)
		pitch_t -= deg_to_rad(pat.y) * RECOIL_COMP[diff]
		yaw_t += deg_to_rad(pat.x) * RECOIL_COMP[diff]
	_desired_yaw = yaw_t
	_desired_pitch = pitch_t
	_turn_towards(dt, 1.0)
	if _now - target_since < REACTION[diff]:
		return
	if def == null:
		return
	if def.slot == WeaponDef.Slot.KNIFE:
		if dist < 1.6:
			s.in_fire = true
		return
	if not def.is_gun():
		s.switch_to(WeaponDef.Slot.PISTOL if s.inventory.has(WeaponDef.Slot.PISTOL) else WeaponDef.Slot.KNIFE)
		return
	var ws := s.current()
	if ws.mag <= 0:
		if ws.reserve > 0:
			s.in_reload = true
		elif s.inventory.has(WeaponDef.Slot.PISTOL) and s.active_slot != WeaponDef.Slot.PISTOL:
			s.switch_to(WeaponDef.Slot.PISTOL)
		else:
			s.switch_to(WeaponDef.Slot.KNIFE)
		return
	# só atira se a mira estiver perto do alvo
	var ang_err := absf(wrapf(yaw_t - s.yaw, -PI, PI)) + absf(pitch_t - s.pitch)
	var tolerance := maxf(atan2(0.35, dist), deg_to_rad(1.2))
	if ang_err > tolerance * 2.5:
		return
	if _now < pause_until:
		return
	if burst_left <= 0:
		if dist > 30.0:
			burst_left = _rng.randi_range(1, 3)
		elif dist > 14.0:
			burst_left = _rng.randi_range(3, 6)
		else:
			burst_left = _rng.randi_range(8, 14)
		crouch_spray = _rng.randf() < 0.25 + diff * 0.1
	if def.automatic:
		s.in_fire = true
		if s.t >= s.next_attack - 0.001:
			burst_left -= 1
			if burst_left <= 0:
				pause_until = _now + _rng.randf_range(0.18, 0.4) + (0.15 if dist > 30.0 else 0.0)
	else:
		# pistola: cliques com cadência humana
		if s.t >= s.next_attack and not s.trigger_down:
			s.in_fire = true
			burst_left -= 1
			pause_until = _now + _rng.randf_range(0.12, 0.28) + dist * 0.004
