class_name Match
extends Node3D
## Bomb-defusal match: rounds, economy, bomb, kill feed, spawning and effects routing.

signal phase_changed(phase: int)
signal killfeed(entry: Dictionary)
signal round_ended(winner: int, reason: String)
signal bomb_event(kind: String)
signal hud_message(text: String, seconds: float)
signal scores_changed
signal local_player_changed(s: Soldier)
signal damage_dealt(attacker: Soldier, victim: Soldier, amount: int, group: String)
signal match_initialized

enum Phase { FREEZE, LIVE, PLANTED, ROUND_END, MATCH_END }

const WIN_ELIM := 3250
const WIN_BOMB := 3500
const LOSS_BASE := 1400
const LOSS_STEP := 500
const LOSS_MAX := 3400
const PLANT_TEAM_BONUS := 800
const OBJECTIVE_BONUS := 300
const ROUND_END_TIME := 6.0

var map: Node3D
var soldiers: Array[Soldier] = []
var local_player: Soldier
var phase := Phase.FREEZE
var phase_left := 0.0
var buy_left := 0.0
var round_number := 0
var score := [0, 0]
var loss_streak := [0, 0]
var bomb_node: Node3D = null
var bomb_site := ""
var bomb_planter: Soldier = null
var last_winner := -1
var last_reason := ""
var halftime_done := false
var match_winner := -1
var clock := 0.0

var fx_root: Node3D
var pickups_root: Node3D
var soldiers_root: Node3D
var hud: CanvasLayer
var fx: FxManager


## PRÉ-MONTAGEM (Loading.pre_montar): a partida é montada numa SubViewport oculta enquanto o jogador está no criador
## de personagem. Sem áudio, sem mouse capturado, sem Game.current_match; ao confirmar, Loading move a partida
## para a árvore principal e chama ativar_pre_montada().
func pre_montando() -> bool:
	return has_meta("pre_montagem")


func _enter_tree() -> void:
	if is_node_ready() and not pre_montando():
		Game.current_match = self


func _criar_controle(s: Soldier) -> PlayerController:
	Loading.marcar_passo("soldado_controle")
	var pc: PlayerController = load("res://core/player_controller.tscn").instantiate()
	s.add_child(pc)
	pc.setup(s, self)
	s.controller = pc
	return pc


func ativar_pre_montada() -> void:
	for s0 in soldiers:
		s0.process_mode = Node.PROCESS_MODE_INHERIT
	if local_player and local_player.has_meta("corpo_adiado"):
		local_player.remove_meta("corpo_adiado")
		Loading.marcar_passo("soldado_corpo")
		(local_player.body_model as BodyModel).setup(local_player)
	if local_player and local_player.has_meta("controle_adiado"):
		local_player.remove_meta("controle_adiado")
		var pc0 := _criar_controle(local_player)
		pc0.on_round_start()
	Game.current_match = self
	if map and map.has_method("ativar_ambiente"):
		map.ativar_ambiente(local_player)
	if local_player:
		local_player.frozen = false
		local_player.reset_physics_interpolation()
		var pc := local_player.controller as PlayerController
		if pc and pc.camera:
			pc.camera.make_current()
	for s in soldiers:
		s.reset_physics_interpolation()
	if not Game.test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.ambient("amb_desert" if Game.config.map == "poeira" else "amb_village", -14.0)


func _ready() -> void:
	if not pre_montando():
		Game.current_match = self
	fx_root = Node3D.new(); fx_root.name = "Fx"; add_child(fx_root)
	pickups_root = Node3D.new(); pickups_root.name = "Pickups"; add_child(pickups_root)
	soldiers_root = Node3D.new(); soldiers_root.name = "Soldiers"; add_child(soldiers_root)
	fx = FxManager.new()
	fx.name = "FxManager"
	fx_root.add_child(fx)
	_load_map()


func _finish_match_setup() -> void:
	Loading.set_progress("Preparando jogadores e personagens...", 82.0)
	Loading.marcar_passo("soldados")
	await _spawn_soldiers_async()
	if pre_montando():
		await get_tree().process_frame
	Loading.marcar_passo("hud")
	hud = load("res://ui/hud.tscn").instantiate()
	add_child(hud)
	hud.setup(self)
	if pre_montando():
		await get_tree().process_frame
	Loading.marcar_passo("start_round")
	start_round()
	if pre_montando():
		if local_player:
			local_player.frozen = true   # não anda com o teclado do menu enquanto a partida espera escondida
		print("PARTIDA_PRONTA (pre-montagem) mapa=", Game.config.map, " jogadores=", soldiers.size())
		match_initialized.emit()
		return
	Audio.ambient("amb_desert" if Game.config.map == "poeira" else "amb_village", -14.0)
	print("PARTIDA_PRONTA mapa=", Game.config.map, " jogadores=", soldiers.size())
	match_initialized.emit()
	Loading.set_progress("Compilando e preparando a primeira imagem...", 98.0)
	# Dá tempo para a subclasse montar seus elementos de sobrevivência e para os shaders renderizarem.
	# Com o aquecimento feito no menu (shaders já compilados), bastam poucos quadros.
	for _i in (4 if Loading.aquecido else 20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not Loading.aquecido:
		await RenderingServer.frame_post_draw
	Loading.hide_after_render()


func _exit_tree() -> void:
	if Game.current_match == self:
		Game.current_match = null
	Audio.stop_ambient()


# ------------------------------------------------------------------ mapa
func _load_map() -> void:
	var info: Dictionary = Game.MAPS.get(Game.config.map, Game.MAPS["poeira"])
	var path: String = info.scene
	if not ResourceLoader.exists(path):
		path = "res://maps/test/test_map.tscn"
	map = load(path).instantiate()
	map.name = "Map"
	if map.has_signal("map_ready"):
		map.connect("map_ready", _finish_match_setup, CONNECT_ONE_SHOT)
	add_child(map)
	if not map.has_signal("map_ready"):
		_finish_match_setup()


func spawns_for(team: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var group := "spawn_t" if team == 0 else "spawn_ct"
	for n in get_tree().get_nodes_in_group(group):
		out.append(n)
	return out


func zones(kind: int) -> Array:
	var out := []
	for z in get_tree().get_nodes_in_group("zones"):
		if z.kind == kind:
			out.append(z)
	return out


func site_at(p: Vector3) -> String:
	for z in zones(Zone.Kind.BOMBSITE):
		if z.contains(p):
			return z.label
	return ""


func bombsite(label: String) -> Zone:
	for z in zones(Zone.Kind.BOMBSITE):
		if z.label == label:
			return z
	return null


func is_survival() -> bool:
	return false


func in_buyzone(s: Soldier) -> bool:
	var kind := Zone.Kind.BUYZONE_T if s.team == 0 else Zone.Kind.BUYZONE_CT
	for z in zones(kind):
		if z.contains(s.global_position):
			return true
	return false


func callout_at(p: Vector3) -> String:
	for z in zones(Zone.Kind.CALLOUT):
		if z.contains(p):
			return z.label
	return ""


func can_buy(s: Soldier) -> bool:
	return s.alive and buy_left > 0.0 and in_buyzone(s) and phase in [Phase.FREEZE, Phase.LIVE]


func friendly_fire() -> bool:
	return bool(Game.config.friendly_fire)


## Todos contra todos (battle royale): o time só escolhe o modelo do personagem.
func is_ffa() -> bool:
	return false


func is_ally(a: Soldier, b: Soldier) -> bool:
	return a == b or (not is_ffa() and a.team == b.team)


# ------------------------------------------------------------------ soldados
func _spawn_soldiers_async() -> void:
	var team: int = Game.config.team
	if team < 0:
		team = randi() % 2
	var per_team: int = Game.config.bots_per_team
	var human_counts := [0, 0]
	if not Game.test_args.has("spectate"):
		local_player = _make_soldier(team, Settings.player_name, false)
		human_counts[team] = 1
		await get_tree().process_frame
	for tm in 2:
		var names: Array = (Game.BOT_NAMES_T if tm == 0 else Game.BOT_NAMES_CT).duplicate()
		names.shuffle()
		var n: int = per_team + (1 - human_counts[tm])
		if Game.test_args.has("spectate"):
			n = per_team + 1
		for i in n:
			_make_soldier(tm, names[i % names.size()], true)
			await get_tree().process_frame


func _make_soldier(team: int, pname: String, bot: bool) -> Soldier:
	var _t0 := Time.get_ticks_usec()
	var s := Soldier.new()
	var _t1 := Time.get_ticks_usec()
	s.name = ("Bot_" if bot else "Player_") + pname.replace(" ", "_")
	s.team = team
	s.display_name = pname
	s.is_bot = bot
	s.is_local = not bot
	s.match_ref = self
	if pre_montando():
		s.process_mode = Node.PROCESS_MODE_DISABLED   # sem física até o CONFIRMAR (1º passo do corpo cinemático custava ~3,4 s)
	soldiers_root.add_child(s)
	if Game.test_args.has("medir_corpo"):
		print("SOLDADO_MS new=%.1f add=%.1f" % [(_t1 - _t0) / 1000.0, (Time.get_ticks_usec() - _t1) / 1000.0])
	Loading.marcar_passo("soldado_corpo")
	var body := BodyModel.new()
	body.name = "Body"
	s.add_child(body)
	if pre_montando() and not bot:
		s.set_meta("corpo_adiado", true)   # boneco do criador (~0,5–3,6 s num quadro): montado no CONFIRMAR
	else:
		body.setup(s)
	s.body_model = body
	if bot:
		var brain := BotBrain.new()
		brain.name = "Brain"
		s.add_child(brain)
		brain.setup(s, self)
		s.controller = brain
	elif pre_montando():
		# pré-montagem: o controle (câmera + viewmodel, ~3,5 s num quadro só) é criado no CONFIRMAR, debaixo da tela de
		# carregamento (ativar_pre_montada); o criador não trava
		s.set_meta("controle_adiado", true)
	else:
		_criar_controle(s)
	s.died.connect(_on_soldier_died)
	soldiers.append(s)
	if Game.test_args.has("medir_corpo"):
		print("SOLDADO_MS total=%.1f" % ((Time.get_ticks_usec() - _t0) / 1000.0))
	Loading.marcar_passo("soldado_fim")
	return s


func team_members(team: int, only_alive := false) -> Array[Soldier]:
	var out: Array[Soldier] = []
	for s in soldiers:
		if s.team == team and (s.alive or not only_alive):
			out.append(s)
	return out


func alive_count(team: int) -> int:
	return team_members(team, true).size()


# ------------------------------------------------------------------ rodadas
func start_round() -> void:
	round_number += 1
	for c in pickups_root.get_children():
		c.queue_free()
	if bomb_node:
		bomb_node.queue_free()
		bomb_node = null
	bomb_site = ""
	bomb_planter = null
	fx.clear_round()
	for tm in 2:
		var spots := spawns_for(tm)
		spots.shuffle()
		var i := 0
		for s in team_members(tm):
			var keep := s.alive and round_number > 1
			s.reset_for_round(keep)
			var spot: Node3D = spots[i % maxi(spots.size(), 1)] if not spots.is_empty() else null
			if spot:
				s.global_position = spot.global_position + Vector3(0, 0.05, 0)
				s.yaw = spot.global_rotation.y
			s.pitch = 0.0
			s.frozen = true
			s.reset_physics_interpolation()
			i += 1
	var ts := team_members(0)
	if not ts.is_empty():
		var carrier: Soldier = ts[randi() % ts.size()]
		carrier.give_weapon(&"bomb", true)
	phase = Phase.FREEZE
	phase_left = float(Game.config.freeze_time)
	buy_left = float(Game.config.buy_time) + phase_left
	last_winner = -1
	for s in soldiers:
		if s.controller and s.controller.has_method("on_round_start"):
			s.controller.on_round_start()
	phase_changed.emit(phase)
	scores_changed.emit()
	Audio.play("round_start", {"bus": "UI", "volume_db": -4.0})


func _process(dt: float) -> void:
	clock += dt
	if phase == Phase.MATCH_END:
		return
	phase_left -= dt
	buy_left = maxf(buy_left - dt, 0.0)
	match phase:
		Phase.FREEZE:
			if phase_left <= 0.0:
				phase = Phase.LIVE
				phase_left = float(Game.config.round_time)
				for s in soldiers:
					s.frozen = false
				phase_changed.emit(phase)
				Audio.voice("go_go_go" if randf() < 0.5 else "lets_move")
		Phase.LIVE:
			if phase_left <= 0.0:
				end_round(1, "O tempo acabou — alvo protegido")
		Phase.PLANTED:
			if bomb_node:
				bomb_node.set_time_left(phase_left)
			if phase_left <= 0.0:
				_explode_bomb()
		Phase.ROUND_END:
			if phase_left <= 0.0:
				_next_round()


func end_round(winner: int, reason: String, bomb_win := false) -> void:
	if phase == Phase.ROUND_END or phase == Phase.MATCH_END:
		return
	last_winner = winner
	last_reason = reason
	score[winner] += 1
	var loser := 1 - winner
	loss_streak[winner] = 0
	loss_streak[loser] += 1
	var win_money := WIN_BOMB if bomb_win else WIN_ELIM
	var loss_money := mini(LOSS_BASE + LOSS_STEP * (loss_streak[loser] - 1), LOSS_MAX)
	for s in soldiers:
		if s.team == winner:
			s.add_money(win_money)
		else:
			var bonus := loss_money
			if loser == 0 and bomb_node != null:
				bonus += PLANT_TEAM_BONUS
			s.add_money(bonus)
	# MVP: quem mais matou no time vencedor (ou quem plantou/desarmou)
	var mvp: Soldier = null
	for s in team_members(winner):
		if mvp == null or s.round_kills > mvp.round_kills:
			mvp = s
	if mvp:
		mvp.mvps += 1
	phase = Phase.ROUND_END
	phase_left = ROUND_END_TIME
	round_ended.emit(winner, reason)
	phase_changed.emit(phase)
	scores_changed.emit()
	Audio.voice("win_t" if winner == 0 else "win_ct")
	Audio.play("round_win_t" if winner == 0 else "round_win_ct", {"bus": "Music", "volume_db": -6.0})
	for s in soldiers:
		if s.controller and s.controller.has_method("on_round_end"):
			s.controller.on_round_end(winner)


func _next_round() -> void:
	var to_win: int = Game.config.rounds_to_win
	if score[0] >= to_win or score[1] >= to_win:
		match_winner = 0 if score[0] > score[1] else 1
		phase = Phase.MATCH_END
		phase_changed.emit(phase)
		Audio.play("match_end", {"bus": "Music"})
		return
	var half := to_win - 1
	if Game.config.halftime and not halftime_done and round_number == half:
		_halftime()
	start_round()


func _halftime() -> void:
	halftime_done = true
	for s in soldiers:
		s.team = 1 - s.team
		s.money = 800
		s.inventory.clear()
		s.armor = 0
		s.has_helmet = false
		s.has_defuser = false
		s.alive = false   # força reset completo do inventário
		if s.body_model and s.body_model.has_method("rebuild"):
			s.body_model.rebuild(s)
	var tmp: int = score[0]
	score[0] = score[1]
	score[1] = tmp
	loss_streak = [0, 0]
	hud_message.emit("Intervalo — os times trocaram de lado", 4.0)


# ------------------------------------------------------------------ mortes e dano
func _on_soldier_died(victim: Soldier, killer: Soldier, def: WeaponDef, headshot: bool, wallbang: bool) -> void:
	var assister: Soldier = null
	var best := 40
	for a: Soldier in victim.round_damage.keys():
		if a != killer and not is_ally(a, victim) and int(victim.round_damage[a]) > best:
			best = int(victim.round_damage[a])
			assister = a
	if assister:
		assister.assists += 1
	if killer and killer != victim:
		if not is_ally(killer, victim):
			killer.kills += 1
			killer.round_kills += 1
			killer.add_money(def.kill_reward if def else 300)
		else:
			killer.kills -= 1
			killer.add_money(-300)
	var entry := {
		"killer": killer.display_name if killer and killer != victim else "",
		"killer_team": killer.team if killer else -1,
		"assist": assister.display_name if assister else "",
		"victim": victim.display_name,
		"victim_team": victim.team,
		"weapon": def.display_name if def else ("Zona" if victim.has_meta("dano_zona_t") and clock - float(victim.get_meta("dano_zona_t")) < 1.5 else ("Queda" if killer == null else "Mundo")),
		"weapon_id": String(def.id) if def else "",
		"headshot": headshot,
		"wallbang": wallbang,
		"local": (killer == local_player) or (victim == local_player),
	}
	killfeed.emit(entry)
	for s in soldiers:
		if s.controller and s.controller.has_method("on_soldier_died"):
			s.controller.on_soldier_died(victim, killer)
	scores_changed.emit()
	_check_elimination()


func _check_elimination() -> void:
	if phase != Phase.LIVE and phase != Phase.PLANTED:
		return
	var t_alive := alive_count(0)
	var ct_alive := alive_count(1)
	if ct_alive == 0:
		end_round(0, "Todos os Contra-Terroristas eliminados")
	elif t_alive == 0 and phase == Phase.LIVE:
		end_round(1, "Todos os Terroristas eliminados")


func on_damage(victim: Soldier, attacker: Soldier, amount: int, group: String) -> void:
	damage_dealt.emit(attacker, victim, amount, group)
	if victim.controller and victim.controller.has_method("on_damaged"):
		victim.controller.on_damaged(attacker, amount)


# ------------------------------------------------------------------ bomba
func can_plant() -> bool:
	return phase == Phase.LIVE and bomb_node == null


func planted_bomb() -> Node3D:
	return bomb_node


func on_plant_started(s: Soldier) -> void:
	Audio.play_at("bomb_plant_start", s.global_position, {"volume_db": -2.0, "max_distance": 30.0})


func on_defuse_started(s: Soldier) -> void:
	Audio.play_at("bomb_defuse_start", s.global_position, {"volume_db": -2.0, "max_distance": 30.0})
	if s.controller and s.controller.has_method("on_defuse_started"):
		s.controller.on_defuse_started()
	for o in soldiers:
		if o.controller and o.controller.has_method("on_heard_defuse"):
			o.controller.on_heard_defuse(s)


func plant_bomb(s: Soldier, site: String) -> void:
	if not can_plant():
		return
	s.remove_slot(WeaponDef.Slot.BOMB)
	var b: PlantedBomb = PlantedBomb.new()
	b.name = "PlantedBomb"
	add_child(b)
	var p := s.global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 2.0, Soldier.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		p = hit.position
	b.global_position = p
	b.rotation.y = s.yaw
	b.setup(self, float(Game.config.bomb_timer))
	bomb_node = b
	bomb_site = site
	bomb_planter = s
	s.add_money(OBJECTIVE_BONUS)
	phase = Phase.PLANTED
	phase_left = float(Game.config.bomb_timer)
	bomb_event.emit("planted")
	phase_changed.emit(phase)
	Audio.voice("bomb_planted")
	for o in soldiers:
		if o.controller and o.controller.has_method("on_bomb_planted"):
			o.controller.on_bomb_planted(b, site)


func defuse_bomb(s: Soldier) -> void:
	if bomb_node == null or phase != Phase.PLANTED:
		return
	s.add_money(OBJECTIVE_BONUS)
	bomb_node.defused()
	bomb_event.emit("defused")
	Audio.voice("bomb_defused")
	end_round(1, "A bomba foi desarmada", true)


func _explode_bomb() -> void:
	if bomb_node == null:
		return
	var origin := bomb_node.global_position
	bomb_node.explode()
	fx.explosion(origin)
	# encerra primeiro: as mortes da explosão não contam como eliminação
	end_round(0, "O alvo foi destruído", true)
	for s in soldiers:
		if not s.alive:
			continue
		var d := s.global_position.distance_to(origin)
		# raio letal ~ 15 m, cai até ~ 44 m (1750 unidades)
		var dmg := 500.0 * exp(-pow(d / 15.2, 2.0))
		if dmg >= 1.0:
			s.take_damage(dmg, null, null, "chest", (s.global_position - origin).normalized())
	ZombieEnemy.explosao(self, origin, 20.0, 400)
	bomb_event.emit("exploded")


# ------------------------------------------------------------------ itens no chão
func drop_on_death(s: Soldier) -> void:
	if s.inventory.has(WeaponDef.Slot.BOMB):
		drop_item(s, WeaponDef.Slot.BOMB, false)
	if s.inventory.has(WeaponDef.Slot.PRIMARY):
		drop_item(s, WeaponDef.Slot.PRIMARY, false)
	elif s.inventory.has(WeaponDef.Slot.PISTOL):
		drop_item(s, WeaponDef.Slot.PISTOL, false)


func drop_item(s: Soldier, slot: int, thrown := true) -> void:
	if slot == WeaponDef.Slot.KNIFE:
		return
	var ws := s.remove_slot(slot)
	if ws == null:
		return
	var p := Pickup.new()
	pickups_root.add_child(p)
	var vel := s.aim_dir() * (4.5 if thrown else 1.2) + Vector3.UP * (1.5 if thrown else 0.8) + s.velocity * 0.5
	p.setup(self, ws, s.eye_position() - Vector3.UP * 0.35, vel, s)
	if slot == WeaponDef.Slot.BOMB:
		bomb_event.emit("dropped")
		for o in soldiers:
			if o.controller and o.controller.has_method("on_bomb_dropped"):
				o.controller.on_bomb_dropped(p)


func dropped_bomb() -> Pickup:
	for p in pickups_root.get_children():
		if p is Pickup and p.state and p.state.def.slot == WeaponDef.Slot.BOMB:
			return p
	return null


func on_pickup(s: Soldier, p: Pickup) -> void:
	if p.state.def.slot == WeaponDef.Slot.BOMB:
		bomb_event.emit("picked")


# ------------------------------------------------------------------ compras
func try_buy(s: Soldier, item: String) -> bool:
	if not can_buy(s):
		return false
	var def := WeaponDB.get_def(StringName(item))
	if def:
		if def.team != -1 and def.team != s.team:
			return false
		if s.money < def.price:
			return false
		var has: WeaponState = s.inventory.get(def.slot)
		if has and has.def == def:
			return false
		if has and def.slot != WeaponDef.Slot.KNIFE:
			drop_item(s, def.slot, true)
		s.add_money(-def.price)
		s.give_weapon(def.id)
		if s.is_local:
			Audio.ui("buy")
		else:
			Audio.play_at("buy", s.global_position, {"volume_db": -6.0, "max_distance": 12.0})
		return true
	match item:
		"kevlar":
			if s.armor >= 100 or s.money < 650:
				return false
			s.add_money(-650)
			s.armor = 100
		"helmet":
			var cost := 1000
			if s.armor >= 100 and not s.has_helmet:
				cost = 350
			if (s.armor >= 100 and s.has_helmet) or s.money < cost:
				return false
			s.add_money(-cost)
			s.armor = 100
			s.has_helmet = true
		"defuser":
			if s.team != 1 or s.has_defuser or s.money < 400:
				return false
			s.add_money(-400)
			s.has_defuser = true
		_:
			return false
	if s.is_local:
		Audio.ui("buy")
	s.inventory_changed.emit()
	return true


# ------------------------------------------------------------------ efeitos e ruído
func on_shot(s: Soldier, def: WeaponDef, origin: Vector3, hit: Dictionary) -> void:
	fx.shot(s, def, origin, hit)
	if not s.is_local and TiroSom.tem(def):
		TiroSom.tocar(self, s, def, false, s.eye_position())
	elif not s.is_local:
		Audio.play_at(def.fire_sound, s.eye_position(), {"volume_db": 2.0, "unit_size": 14.0, "max_distance": 160.0, "pitch_var": 0.03})
		if Audio.has_sound(def.fire_sound + "_far"):
			var lp := local_player
			if lp and lp.global_position.distance_to(s.global_position) > 35.0:
				Audio.play_at(def.fire_sound + "_far", s.eye_position(), {"volume_db": -2.0, "unit_size": 40.0, "max_distance": 250.0})
		# cauda com ecos: tiro alheio ouvido de longe (até 600 m) — dá medo e mostra a direção
		var cauda := ViewModel._familia_som(def) + "_cauda"
		if Audio.has_sound(cauda):
			Audio.play_at(cauda, s.eye_position(), {"volume_db": 4.0, "unit_size": 60.0, "max_distance": 600.0, "pitch_var": 0.05})


func on_impact(pos: Vector3, normal: Vector3, surface: String, dir: Vector3) -> void:
	fx.impact(pos, normal, surface, dir)


func report_noise(source: Soldier, pos: Vector3, radius: float) -> void:
	for s in soldiers:
		if s == source or not s.alive or s.team == source.team:
			continue
		if s.is_bot and s.global_position.distance_to(pos) <= radius:
			s.controller.on_noise(source, pos)
