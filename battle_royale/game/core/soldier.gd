class_name Soldier
extends CharacterBody3D
## A combatant (human or bot). Controllers write the in_* intents and yaw/pitch;
## the soldier runs Source-style movement, weapons, damage and death identically for everyone.

signal died(victim: Soldier, killer: Soldier, weapon: WeaponDef, headshot: bool, wallbang: bool)
signal damaged(amount: int, attacker: Soldier, from_dir: Vector3)
signal fired(def: WeaponDef)
signal weapon_switched(def: WeaponDef)
signal reload_started(def: WeaponDef)
signal reload_finished(def: WeaponDef)
signal knife_swung(heavy: bool, hit: bool)
signal inventory_changed
signal plate_started(seconds: float)
signal plate_applied
signal cura_started(item_id: String, seconds: float)
signal cura_finished(item_id: String, healed: int)
signal cura_cancelled(item_id: String, motivo: String)
signal landed(impact: float)
signal footstep(surface: String)
signal plant_progress(p: float)
signal defuse_progress(p: float)
signal nado_mudou(nadando: bool)
signal bala_impacto(info: Dictionary)   # projétil simulado tocou algo: pos, t_voo, vel, dist, (victim, group | surface)

const GRAVITY := 20.0
const JUMP_VELOCITY := 6.85
const ACCEL := 8.5                  # com FRICTION 8: 90% da velocidade em ~0,24 s; para em ~0,25 s
const AIR_ACCEL := 12.0
const AIR_WISH_CAP := 0.76
const FRICTION := 8.0
const STOP_SPEED := 2.03
const STAND_HEIGHT := 1.83
const CROUCH_HEIGHT := 1.37
const RADIUS := 0.4
const EYE_STAND := 1.63
const EYE_CROUCH := 1.17
const DUCK_SPEED := 6.0            # 1/segundos para agachar por completo
const STEP_HEIGHT := 0.46
const WALK_MULT := 0.52
const CROUCH_MULT := 0.34
const SPRINT_MULT := 1.25           # Shift: corrida rápida (arma baixa, sem tiro/ADS)
const SPRINT_BLOCK := 0.22          # s sem atirar/mirar depois de parar de correr
const ADS_SPEED_MULT := 0.55        # mirando pela alça anda a 55%
const PLANT_TIME := 3.2
const DEFUSE_TIME := 10.0
const DEFUSE_TIME_KIT := 5.0

const LAYER_WORLD := 1
const LAYER_SOLDIER := 2
const LAYER_HITBOX := 4
const LAYER_TRIGGER := 8
const LAYER_PICKUP := 16

var team := 0
var display_name := "Bot"
var is_bot := true
var is_local := false
var alive := true
var health := 100
var armor := 0
var godmode := false            # painel de administrador (F10)
var fly_admin := false
# sobrevivência: colete de placas (3 placas de 33 = 99 de colete) e regeneração lenta fora de combate
const PLACAS_ATIVAS := false      # colete de placas (B) desativado: voltará como coletes tier 1/2/3
const PLATE_ARMOR := 33
const MAX_PLATES := 3
const PLATE_TIME := 1.6
const REGEN_DELAY := 120.0
const REGEN_STEP := 1.2           # s por ponto de vida depois do atraso
var has_vest := false
var plates := 0                   # placas carregadas, ainda não encaixadas
var plate_left := 0.0
var aim_amount := 0.0              # 0..1 mirando pela alça (ADS): reduz o espalhamento
var combat_t := -1000.0           # último instante em que levou ou deu tiro
var _regen_acc := 0.0
var has_helmet := false
var has_defuser := false
var money := 800
var kills := 0
var deaths := 0
var assists := 0
var mvps := 0
var round_damage: Dictionary = {}    # atacante(Soldier) -> dano causado a mim nesta rodada
var round_kills := 0

# --- intenções (escritas pelo controlador) ---
var in_move := Vector2.ZERO          # x: direita, y: frente
var in_jump := false
var in_crouch := false
var in_walk := false
var in_sprint := false
var is_sprinting := false            # leitura para viewmodel/corpo: arma abaixada enquanto corre
var sprint_block_until := 0.0        # relógio t até quando tiro/ADS seguem bloqueados após o sprint
var in_fire := false
var in_alt := false
var in_reload := false
var in_use := false
var yaw := 0.0
var pitch := 0.0
var frozen := false                  # tempo de congelamento da rodada
var external_motion := false         # BRMatch possui o movimento; descida usa a cápsula com varredura

# --- estado de movimento ---
var crouch := 0.0                    # 0 em pé · 1 agachado
var was_on_floor := true
var fall_speed := 0.0
var step_accum := 0.0
var jump_released := true
var jump_penalty := 0.0              # reduz velocidade após pulos seguidos (como CS)
var eye_offset_smooth := 0.0         # suaviza a câmera ao subir degraus
var escada: Node = null              # EscadaVertical em uso (null = não está escalando)
var escadas_perto: Array = []        # EscadaVertical cujas áreas contêm este corpo
var climb_v := 0.0                   # velocidade vertical na escada (m/s), usada pela animação do corpo

# --- armas ---
var inventory: Dictionary = {}       # slot(int) -> WeaponState
var active_slot := 3
var last_slot := 2
var t := 0.0                         # relógio local da simulação
var next_attack := 0.0
var ready_at := 0.0                  # fim do saque
var reload_end := 0.0
var shots_fired := 0.0
var last_shot := -10.0
var fire_inacc := 0.0
var trigger_down := false
var aim_punch := Vector2.ZERO        # graus (x yaw, y pitch) mostrados na câmera
var punch_vel := Vector2.ZERO
var knife_quick := 0
var planting := 0.0
var defusing := 0.0
var defuse_target: Node3D = null
var last_hit_by: Soldier = null
var is_carrying_bomb := false

var match_ref: Node = null           # Match
var controller: Node = null
var body_model: Node3D = null        # visual em terceira pessoa (BodyModel)
var hitboxes: Array[Area3D] = []
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _hb_head: CollisionShape3D
var _hb_chest: CollisionShape3D
var _hb_stomach: CollisionShape3D
var _hb_legs: CollisionShape3D


func _ready() -> void:
	collision_layer = LAYER_SOLDIER
	collision_mask = LAYER_WORLD | LAYER_SOLDIER
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	floor_constant_speed = true
	max_slides = 6
	safe_margin = 0.02
	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)
	_build_hitboxes()
	fired.connect(func(_d: WeaponDef) -> void: cura_cancelar("atirou"))
	weapon_switched.connect(func(_d: WeaponDef) -> void: cura_cancelar("trocou de arma"))


# ------------------------------------------------------------------ hitboxes
func _build_hitboxes() -> void:
	_hb_head = _add_hitbox("head", _sphere(0.16))
	_hb_chest = _add_hitbox("chest", _box(Vector3(0.52, 0.42, 0.34)))
	_hb_stomach = _add_hitbox("stomach", _box(Vector3(0.46, 0.3, 0.3)))
	_hb_legs = _add_hitbox("legs", _box(Vector3(0.46, 0.85, 0.3)))
	_update_hitboxes()


func _sphere(r: float) -> Shape3D:
	var s := SphereShape3D.new(); s.radius = r; return s


func _box(sz: Vector3) -> Shape3D:
	var b := BoxShape3D.new(); b.size = sz; return b


func _add_hitbox(group: String, shape: Shape3D) -> CollisionShape3D:
	var a := Area3D.new()
	a.collision_layer = LAYER_HITBOX
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = false
	a.set_meta("soldier", self)
	a.set_meta("group", group)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	a.add_child(cs)
	add_child(a)
	hitboxes.append(a)
	return cs


## Hitboxes follow the posture analytically (stance + yaw). Body-bone hitboxes can override.
func _update_hitboxes() -> void:
	var h := lerpf(STAND_HEIGHT, CROUCH_HEIGHT, crouch)
	var eye := lerpf(EYE_STAND, EYE_CROUCH, crouch)
	var b := Basis(Vector3.UP, yaw)
	var fwd := -b.z
	_hb_head.get_parent().transform = Transform3D(b, Vector3(0, eye + 0.06, 0) + fwd * 0.03)
	_hb_chest.get_parent().transform = Transform3D(b, Vector3(0, h * 0.72, 0))
	_hb_stomach.get_parent().transform = Transform3D(b, Vector3(0, h * 0.53, 0))
	# com personagem animado, cabeça/peito/barriga seguem os ossos (o que se vê é o que se acerta)
	if body_model and body_model.has_method("hitbox_points"):
		var pts: Dictionary = body_model.hitbox_points()
		if not pts.is_empty():
			var inv := global_transform.affine_inverse()
			# os pontos já seguem a posição física atual do soldado (só a pose é do quadro anterior): sem projeção
			var lead := Vector3.ZERO
			_hb_head.get_parent().transform = Transform3D(b, inv * ((pts.head as Vector3) + lead))
			_hb_chest.get_parent().transform = Transform3D(b, inv * ((pts.chest as Vector3) + lead))
			_hb_stomach.get_parent().transform = Transform3D(b, inv * ((pts.stomach as Vector3) + lead))
	var legs_h := h * 0.46
	(_hb_legs.shape as BoxShape3D).size.y = legs_h
	_hb_legs.get_parent().transform = Transform3D(b, Vector3(0, legs_h * 0.5, 0))


func set_hitboxes_enabled(on: bool) -> void:
	for a in hitboxes:
		a.collision_layer = LAYER_HITBOX if on else 0


# ------------------------------------------------------------------ helpers
func eye_height() -> float:
	return lerpf(EYE_STAND, EYE_CROUCH, crouch)


func eye_position() -> Vector3:
	return global_position + Vector3(0, eye_height(), 0)


func aim_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ)


func aim_dir() -> Vector3:
	return -aim_basis().z


## Última arma anunciada ao viewmodel/corpo por weapon_switched (detecta troca no mesmo slot).
var announced_id: StringName = &""


func current() -> WeaponState:
	return inventory.get(active_slot)


func current_def() -> WeaponDef:
	var w := current()
	return w.def if w else null


func max_speed() -> float:
	var d := current_def()
	var s := d.move_speed if d else 6.35
	if is_carrying_bomb and active_slot == WeaponDef.Slot.BOMB:
		s = 6.35
	if crouch > 0.5:
		s *= CROUCH_MULT
	elif in_walk:
		s *= WALK_MULT
	elif is_sprinting:
		s *= SPRINT_MULT
	s *= lerpf(1.0, ADS_SPEED_MULT, clampf(aim_amount, 0.0, 1.0))
	return s * (1.0 - jump_penalty * 0.35)


## Sprint ativo ou ainda na janela de recuperação: sem tiro nem ADS.
func sprint_bloqueado() -> bool:
	return is_sprinting or t < sprint_block_until


func _update_sprint() -> void:
	if nadando:
		# nadando: arma abaixada, sem tiro/ADS/faca (mesmo bloqueio do sprint)
		is_sprinting = true
		sprint_block_until = t + SPRINT_BLOCK
		return
	var quer := in_sprint and not in_walk and not frozen and crouch < 0.5 and in_move.y > 0.3 and escada == null
	if is_on_floor() or not quer:
		is_sprinting = quer
	if is_sprinting:
		sprint_block_until = t + SPRINT_BLOCK


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_reloading() -> bool:
	return reload_end > 0.0


# ------------------------------------------------------------------ simulação
func _physics_process(dt: float) -> void:
	t += dt
	_cura_tick(dt)
	_sim(dt)
	_balas_passo(dt)


func _sim(dt: float) -> void:
	if not alive:
		# die() desativa a cápsula: mover este corpo faria o cadáver cair pelo mapa.
		return
	if external_motion:
		_update_hitboxes()
		if body_model and body_model.has_method("sync_pose"):
			body_model.sync_pose(self, dt)
		return
	if escada != null:
		_subir_escada(dt)
		_update_hitboxes()
		if body_model and body_model.has_method("sync_pose"):
			body_model.sync_pose(self, dt)
		return
	if not _mantle_on:
		mantle_fx = mantle_fx.lerp(Vector3.ZERO, clampf(dt * 10.0, 0.0, 1.0))
	if _mantle_on:
		_mantle_passo(dt)
		_update_hitboxes()
		_update_weapon(dt)
		if body_model and body_model.has_method("sync_pose"):
			body_model.sync_pose(self, dt)
		return
	_update_crouch(dt)
	_update_sprint()
	_move(dt)
	_update_hitboxes()
	_update_weapon(dt)
	_update_objective(dt)
	_survival_tick(dt)
	if body_model and body_model.has_method("sync_pose"):
		body_model.sync_pose(self, dt)


## Regeneração lenta depois de 2 min sem combate e aplicação de placa (tecla B) — só no modo sobrevivência.
func _survival_tick(dt: float) -> void:
	if match_ref == null or not match_ref.is_survival():
		return
	if plate_left > 0.0:
		plate_left -= dt
		if plate_left <= 0.0:
			plate_left = 0.0
			plates -= 1
			armor = mini(PLATE_ARMOR * MAX_PLATES, armor + PLATE_ARMOR)
			plate_applied.emit()
			inventory_changed.emit()
	if health < 100 and t - combat_t > REGEN_DELAY:
		_regen_acc += dt
		if _regen_acc >= REGEN_STEP:
			_regen_acc -= REGEN_STEP
			health += 1
	else:
		_regen_acc = 0.0


# ------------------------------------------------------------------ cura (bandagem / kit médico; tecla H)
## Definições vêm de BRInventory.DEFINITIONS (kind "heal": heal, time, stop_bleed). Só interrompe se atirar ou trocar de arma
## (mover/levar dano NÃO interrompe). A cura é aplicada e o item consumido ao terminar; respeita MAX_HEALTH.
const MAX_HEALTH := 100
const SANGRAMENTO_PASSO := 2.0    # s por ponto de vida perdido enquanto sangra (nunca mata: para em 1 HP)
var cura_id := ""
var cura_left := 0.0
var cura_total := 0.0
var sangrando := false
var cura_bag: BRInventory = null   # bots/testes: inventário de onde sai o item (padrão: match_ref.br_bag; nenhum = cura grátis)
var _sangue_acc := 0.0


func cura_ativa() -> bool:
	return cura_id != ""


## 0..1 do progresso da cura em andamento (HUD).
func cura_progresso() -> float:
	return 1.0 - cura_left / cura_total if cura_id != "" and cura_total > 0.0 else 0.0


func _cura_inventario() -> BRInventory:
	if cura_bag != null:
		return cura_bag
	if match_ref != null and "br_bag" in match_ref and match_ref.br_bag is BRInventory and is_local:
		return match_ref.br_bag
	return null


func _cura_contar(item_id: String) -> int:
	var bag := _cura_inventario()
	if bag == null:
		return 1
	var n := 0
	for it in bag.items:
		if String(it.id) == item_id:
			n += int(it.qty)
	return n


func iniciar_sangramento() -> void:
	sangrando = true


## Começa a usar uma cura. false se: item inválido, morto, já curando, sem o item, ou nada a curar (vida cheia e sem sangramento).
func usar_cura(item_id: String) -> bool:
	var def := BRInventory.definition(item_id)
	if not alive or cura_id != "" or String(def.get("kind", "")) != "heal":
		return false
	if health >= MAX_HEALTH and not (sangrando and bool(def.get("stop_bleed", false))):
		return false
	if _cura_contar(item_id) < 1:
		return false
	cura_id = item_id
	cura_total = float(def.get("time", 3.0))
	cura_left = cura_total
	Audio.play_at("heal_use", eye_position(), {"volume_db": -4.0, "max_distance": 18.0})
	cura_started.emit(item_id, cura_total)
	return true


## H: usa a melhor cura disponível (kit se sangra e há kit; senão bandagem; senão kit).
func usar_cura_auto() -> bool:
	var ordem: Array = ["kit_medico", "bandagem"] if sangrando else ["bandagem", "kit_medico"]
	for id in ordem:
		if _cura_contar(String(id)) > 0 and usar_cura(String(id)):
			return true
	return false


func cura_cancelar(motivo := "cancelada") -> void:
	if cura_id == "":
		return
	var id := cura_id
	cura_id = ""
	cura_left = 0.0
	cura_total = 0.0
	cura_cancelled.emit(id, motivo)


func _cura_tick(dt: float) -> void:
	if not alive:
		cura_id = ""
		return
	if sangrando and cura_id == "":   # o curativo em andamento estanca a perda enquanto é aplicado
		_sangue_acc += dt
		while _sangue_acc >= SANGRAMENTO_PASSO:
			_sangue_acc -= SANGRAMENTO_PASSO
			health = maxi(1, health - 1)
	if cura_id == "":
		return
	if in_fire:
		cura_cancelar("atirou")
		return
	cura_left -= dt
	if cura_left > 0.0:
		return
	var id := cura_id
	var def := BRInventory.definition(id)
	var bag := _cura_inventario()
	if bag != null:
		var uid := -1
		for it in bag.items:
			if String(it.id) == id:
				uid = int(it.uid)
				break
		if uid < 0:
			cura_cancelar("sem item")
			return
		bag.remove_item(uid, 1)
	cura_id = ""
	cura_left = 0.0
	cura_total = 0.0
	var antes := health
	health = mini(MAX_HEALTH, health + int(def.get("heal", 0)))
	if bool(def.get("stop_bleed", false)):
		sangrando = false
	Audio.play_at("heal_done", eye_position(), {"volume_db": -6.0, "max_distance": 14.0})
	cura_finished.emit(id, health - antes)


func give_vest(n_plates := 2) -> void:
	if not PLACAS_ATIVAS:
		return
	has_vest = true
	plates = mini(MAX_PLATES, plates + n_plates)
	inventory_changed.emit()


## B: encaixa uma placa (leva PLATE_TIME s; 3 placas = 3 barras cheias).
func use_plate() -> bool:
	if not PLACAS_ATIVAS or not alive or not has_vest or plates <= 0 or plate_left > 0.0 or armor >= PLATE_ARMOR * MAX_PLATES:
		return false
	plate_left = PLATE_TIME
	plate_started.emit(PLATE_TIME)
	return true


func _update_crouch(dt: float) -> void:
	var want := 1.0 if (in_crouch and not nadando) else 0.0
	if want < crouch and not nadando and not _can_unduck():
		want = crouch
	var prev := crouch
	crouch = move_toward(crouch, want, dt * DUCK_SPEED)
	if absf(prev - crouch) > 0.0:
		var h := lerpf(STAND_HEIGHT, CROUCH_HEIGHT, crouch)
		var prev_h := lerpf(STAND_HEIGHT, CROUCH_HEIGHT, prev)
		_capsule.height = h
		_shape.position.y = h * 0.5
		if not is_on_floor():
			# no ar os pés recolhem: a cabeça fica no lugar (agachar-pulo do CS)
			global_position.y += prev_h - h


func _can_unduck() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS - 0.02
	cap.height = STAND_HEIGHT - 0.04
	params.shape = cap
	params.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.03, 0))
	params.collision_mask = LAYER_WORLD
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Voo do administrador: sem gravidade; WASD no plano do olhar (inclui pitch), espaço sobe, agachar desce, sprint acelera.
func _fly(dt: float) -> void:
	var look := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var wish := look * Vector3(in_move.x, 0.0, -in_move.y)
	if in_jump:
		wish += Vector3.UP
	if in_crouch:
		wish += Vector3.DOWN
	var spd := 22.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 9.0
	velocity = velocity.lerp(wish.limit_length(1.0) * spd, clampf(dt * 8.0, 0.0, 1.0))
	fall_speed = 0.0
	move_and_slide()


func _move(dt: float) -> void:
	if fly_admin:
		_fly(dt)
		return
	_agua_estado(dt)
	if nadando:
		_nado_mover(dt)
		return
	var on_floor := is_on_floor()
	var locked := frozen or planting > 0.0 or defusing > 0.0
	var move := Vector2.ZERO if locked else in_move
	var b := Basis(Vector3.UP, yaw)
	var wish := b * Vector3(move.x, 0.0, -move.y)
	var wish_len := wish.length()
	if wish_len > 1.0:
		wish /= wish_len
	var wish_speed := max_speed() * minf(wish_len, 1.0)
	jump_penalty = move_toward(jump_penalty, 0.0, dt * 1.6)

	_mantle_cool = maxf(_mantle_cool - dt, 0.0)
	if in_jump and not locked and _mantle_cool <= 0.0 and wish_len > 0.1 and ((on_floor and jump_released) or (not on_floor and velocity.y < 3.0)):
		if _tentar_mantle(wish / wish_len):
			jump_released = false
			return
	if on_floor:
		if in_jump and jump_released and not locked:
			velocity.y = JUMP_VELOCITY
			jump_released = false
			jump_penalty = minf(jump_penalty + 0.45, 1.0)
			on_floor = false
			_emit_jump_sound()
		else:
			_friction(dt)
			_accelerate(wish.normalized() if wish_len > 0.0 else Vector3.ZERO, wish_speed, ACCEL, dt)
			velocity.y = minf(velocity.y, 0.0)
	if not on_floor:
		_air_accelerate(wish.normalized() if wish_len > 0.0 else Vector3.ZERO, wish_speed, dt)
		velocity.y -= GRAVITY * dt
	if not in_jump:
		jump_released = true

	fall_speed = -velocity.y
	var pre_vel := velocity
	var pre_pos := global_position
	move_and_slide()
	if on_floor and get_slide_collision_count() > 0:
		_try_step(pre_pos, pre_vel, dt)

	var now_floor := is_on_floor()
	if now_floor and not was_on_floor:
		landed.emit(fall_speed)
		if fall_speed > 7.0:
			_emit_footstep(true)
		if fall_speed > 4.5 and Audio.has_sound("land"):
			var lv := clampf(-14.0 + (fall_speed - 4.5) * 1.6, -14.0, -2.0)
			if is_local:
				Audio.play("land", {"volume_db": lv, "pitch_var": 0.06})
			else:
				Audio.play_at("land", global_position, {"volume_db": lv + 6.0, "unit_size": 4.0, "max_distance": 34.0, "pitch_var": 0.06})
		if fall_speed > 11.0 and match_ref:
			# dano de queda (CS: acima de ~580 u/s)
			var dmg := int((fall_speed - 11.0) * 9.0)
			if dmg > 0:
				take_damage(dmg, null, null, "legs", Vector3.DOWN)
	was_on_floor = now_floor
	_update_footsteps(dt, now_floor)


# ------------------------------------------------------------------ nado e fôlego
const NADO_ENTRA := 1.15             # m de água sobre os pés para começar a nadar (peito)
const NADO_SAI := 0.95               # histerese: volta a andar quando os pés tocam o fundo com menos água que isto
const NADO_VEL := 1.6                # m/s
const NADO_VEL_RAPIDO := 2.6         # m/s com Shift
const NADO_FLUTUA := 1.3             # pés abaixo da superfície com o corpo meio submerso (olhos ~0,33 m acima da água)
const NADO_VERT := 1.6               # m/s subindo (pulo) / descendo (agachar)
const FOLEGO_MAX := 15.0             # s de ar com a cabeça submersa
const FOLEGO_REGEN := 6.0            # s de ar recuperados por segundo fora d'água
const AFOGAR_HPS := 5.0              # dano por segundo sem fôlego

## Função (x, z) -> nível da superfície d'água ali (m), ou -1e9 sem água. O mapa registra a sua (ilha.gd).
static var agua_fn := Callable()

var nadando := false
var submerso := false                # câmera abaixo da superfície
var agua_y := -1e9                   # superfície sob o soldado neste quadro
var folego := FOLEGO_MAX
var _afogar_acc := 0.0


func nivel_agua() -> float:
	if agua_fn.is_valid():
		return float(agua_fn.call(global_position.x, global_position.z))
	return -1e9


func _agua_estado(dt: float) -> void:
	agua_y = nivel_agua()
	var prof := agua_y - global_position.y
	if not nadando and agua_y > -1e8 and prof > NADO_ENTRA and alive:
		_nado_iniciar()
	elif nadando and (agua_y < -1e8 or (is_on_floor() and prof < NADO_SAI)):
		_nado_parar()
	submerso = nadando and eye_position().y < agua_y - 0.03
	if submerso:
		folego = maxf(folego - dt, 0.0)
		if folego <= 0.0:
			_afogar_acc += dt
			var passo := 1.0 / AFOGAR_HPS
			while _afogar_acc >= passo and alive:
				_afogar_acc -= passo
				take_damage(1.0, null, null, "legs", Vector3.UP)
	else:
		_afogar_acc = 0.0
		folego = minf(folego + dt * FOLEGO_REGEN, FOLEGO_MAX)


func _nado_iniciar() -> void:
	nadando = true
	_cancel_reload()
	crouch = 0.0
	_capsule.height = STAND_HEIGHT
	_shape.position.y = STAND_HEIGHT * 0.5
	floor_snap_length = 0.0
	fall_speed = 0.0
	velocity.y *= 0.3
	if is_local and Audio.has_sound("splash"):
		Audio.play("splash", {"volume_db": -6.0, "pitch_var": 0.08})
	elif Audio.has_sound("splash"):
		Audio.play_at("splash", global_position, {"volume_db": 0.0, "max_distance": 40.0})
	nado_mudou.emit(true)


func _nado_parar() -> void:
	nadando = false
	submerso = false
	floor_snap_length = 0.35
	was_on_floor = true
	velocity.y = minf(velocity.y, 0.0)
	nado_mudou.emit(false)


## Nado: sem gravidade nem andar no fundo; WASD no plano, Shift acelera, pulo sobe e agachar mergulha; flutua com o corpo meio submerso.
func _nado_mover(dt: float) -> void:
	var locked := frozen or planting > 0.0 or defusing > 0.0
	var mv := Vector2.ZERO if locked else in_move
	var wish := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0.0, -mv.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var vel := NADO_VEL_RAPIDO if (in_sprint and mv.y > 0.3) else NADO_VEL
	var k := 1.0 - exp(-dt * 3.5)
	velocity.x = lerpf(velocity.x, wish.x * vel, k)
	velocity.z = lerpf(velocity.z, wish.z * vel, k)
	var topo := agua_y - NADO_FLUTUA
	var alvo := clampf((topo - global_position.y) * 2.5, -NADO_VERT, NADO_VERT)
	if not locked and in_crouch:
		alvo = -NADO_VERT
	elif not locked and in_jump and global_position.y < topo - 0.02:
		alvo = NADO_VERT
	velocity.y = lerpf(velocity.y, alvo, 1.0 - exp(-dt * 5.0))
	if global_position.y <= topo and global_position.y + velocity.y * dt > topo:
		velocity.y = (topo - global_position.y) / maxf(dt, 0.0001)
	jump_released = not in_jump
	fall_speed = 0.0
	move_and_slide()


func _friction(dt: float) -> void:
	var v := Vector2(velocity.x, velocity.z)
	var speed := v.length()
	if speed < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var control := maxf(speed, STOP_SPEED)
	var drop := control * FRICTION * dt
	var ns := maxf(speed - drop, 0.0) / speed
	velocity.x *= ns
	velocity.z *= ns


func _accelerate(dir: Vector3, wish_speed: float, accel: float, dt: float) -> void:
	if dir == Vector3.ZERO:
		return
	var cur := velocity.x * dir.x + velocity.z * dir.z
	var add := wish_speed - cur
	if add <= 0.0:
		return
	# aceleração pela velocidade da arma (sem o fator de agachar/andar): senão o atrito vence e agachado quase não sai do lugar
	var d := current_def()
	var ref := maxf(wish_speed, (d.move_speed if d else 6.35) * 0.52)
	var acc := minf(accel * dt * ref, add)
	velocity.x += acc * dir.x
	velocity.z += acc * dir.z


func _air_accelerate(dir: Vector3, wish_speed: float, dt: float) -> void:
	if dir == Vector3.ZERO:
		return
	var capped := minf(wish_speed, AIR_WISH_CAP)
	var cur := velocity.x * dir.x + velocity.z * dir.z
	var add := capped - cur
	if add <= 0.0:
		return
	var acc := minf(AIR_ACCEL * wish_speed * dt, add)
	velocity.x += acc * dir.x
	velocity.z += acc * dir.z


## Sobe degraus/meio-fios de até STEP_HEIGHT sem pular.
func _try_step(pre_pos: Vector3, pre_vel: Vector3, dt: float) -> void:
	var horiz := Vector3(pre_vel.x, 0.0, pre_vel.z)
	if horiz.length() < 0.3:
		return
	var moved := global_position - pre_pos
	if Vector2(moved.x, moved.z).length() > horiz.length() * dt * 0.9:
		return
	# avanço mínimo de 14 cm por tique: parado ao pé de uma escada a velocidade nunca passa de ~0,5 m/s (o choque zera a cada
	# tique) e o avanço de 1 cm não levava a cápsula para cima do degrau.
	var motion := horiz.normalized() * maxf(horiz.length() * dt, 0.14)
	var start := Transform3D(global_transform.basis, pre_pos)
	# Ao tocar a quina, a margem da cápsula pode já invadir o degrau por
	# milímetros. Recuar a consulta mantém o volume livre para subir.
	var recuo := horiz.normalized() * 0.08
	start.origin -= recuo
	motion += recuo
	# sobe o que houver de vão livre (teto baixo junto à escada não impede degraus de 20 cm)
	var up_h := STEP_HEIGHT
	var col_up := KinematicCollision3D.new()
	if test_move(start, Vector3(0, STEP_HEIGHT, 0), col_up):
		up_h = col_up.get_travel().y
	if up_h < 0.1:
		return
	var up := Vector3(0, up_h, 0)
	var raised := start.translated(up)
	if test_move(raised, motion):
		return
	var fwd := raised.translated(motion)
	var col := KinematicCollision3D.new()
	if not test_move(fwd, -up - Vector3(0, 0.05, 0), col):
		return
	if col.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		# Jolt pode tocar a quina arredondada da cápsula antes do tampo do
		# degrau. Só aceita a subida se uma sonda adiante encontrar um tampo.
		var probe_at := pre_pos + horiz.normalized() * (RADIUS + 0.12)
		var query := PhysicsRayQueryParameters3D.create(
			probe_at + Vector3.UP * (STEP_HEIGHT + 0.3),
			probe_at - Vector3.UP * 0.12, LAYER_WORLD)
		var top := get_world_3d().direct_space_state.intersect_ray(query)
		if top.is_empty() or top.normal.dot(Vector3.UP) < cos(floor_max_angle):
			return
		var rise: float = top.position.y - pre_pos.y
		if rise < 0.02 or rise > up_h:
			return
		var elevated := fwd.origin
		elevated.y = maxf(elevated.y, top.position.y + 0.02)
		if elevated.distance_to(pre_pos) > up_h + motion.length() + 0.1:
			return
		eye_offset_smooth -= elevated.y - global_position.y
		global_position = elevated
		velocity.x = pre_vel.x
		velocity.z = pre_vel.z
		return
	var target := fwd.origin + col.get_travel()
	var subida := target.y - pre_pos.y
	if subida < 0.02 or subida > up_h + 0.001:
		return
	# Não aceita recuperação de penetração como um degrau nem perde progresso lateral.
	var delta := target - pre_pos
	if Vector2(delta.x, delta.z).length() > motion.length() + 0.001:
		return
	if Vector2(delta.x, delta.z).dot(Vector2(motion.x, motion.z)) <= Vector2(moved.x, moved.z).dot(Vector2(motion.x, motion.z)):
		return
	eye_offset_smooth -= target.y - global_position.y
	global_position = target
	velocity.x = pre_vel.x
	velocity.z = pre_vel.z


# ------------------------------------------------------------------ escalar (mantle): muros, cercas e caixas
const MANTLE_MIN := 0.5              # abaixo disto o degrau automático resolve
const MANTLE_MAX := 1.65             # altura máxima escalável (muro baixo / cerca)
const MANTLE_ALCANCE := 0.85         # distância máxima da borda da cápsula até o obstáculo
var _mantle_on := false
var _mantle_cool := 0.0
var _mantle_t := 0.0
var _mantle_pts: Array[Vector3] = []
var _mantle_dur: Array[float] = []
var mantle_fx := Vector3.ZERO        # efeito de câmera do pulo: x = pitch (rad), y = roll (rad), z = FOV extra (graus); decai sozinho


func _cap_livre(pos: Vector3, raio := RADIUS - 0.04, altura := STAND_HEIGHT - 0.08) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = raio
	cap.height = altura
	params.shape = cap
	params.transform = Transform3D(Basis(), pos + Vector3(0, altura * 0.5 + 0.06, 0))
	params.collision_mask = LAYER_WORLD
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _raio(de: Vector3, ate: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, ate, LAYER_WORLD, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


## Procura um obstáculo à frente entre MANTLE_MIN e MANTLE_MAX de altura e um pouso livre (em cima ou do outro lado).
func _tentar_mantle(dir: Vector3) -> bool:
	var pos := global_position
	# 1) parede/cerca à frente: varredura da própria cápsula (erguida acima do degrau) acha cerca de ripas/arame
	var col := KinematicCollision3D.new()
	var alto := Vector3(0, STEP_HEIGHT + 0.06, 0)
	if not test_move(Transform3D(Basis(), pos + alto), dir * (MANTLE_ALCANCE + 0.1), col):
		return false
	if absf(col.get_normal().y) > 0.65:
		return false
	var dist := col.get_travel().length() + RADIUS
	# 2) topo: a cápsula desce de cima sobre o obstáculo e pára na superfície mais alta (trilho, ripa, coroamento)
	var inicio: Vector3 = pos + dir * (dist + 0.05) + Vector3(0, MANTLE_MAX + 0.1, 0)
	var col2 := KinematicCollision3D.new()
	if not test_move(Transform3D(Basis(), inicio), Vector3(0, -(MANTLE_MAX - 0.3), 0), col2):
		return false
	var topo := inicio.y - col2.get_travel().length()
	# altura medida desde o chão sob os pés (no ar o salto não "soma" ao alcance do muro)
	var gy := pos.y
	if not is_on_floor():
		var g0 := _raio(pos + Vector3(0, 0.1, 0), pos - Vector3(0, 3.0, 0))
		gy = g0.position.y if not g0.is_empty() else pos.y - 1.2
	var h_rel := topo - gy
	if h_rel < MANTLE_MIN or h_rel > MANTLE_MAX:
		return false
	# 3) vão livre acima do obstáculo e caminho vertical livre
	var p1 := Vector3(pos.x, topo + 0.04, pos.z)
	var apex: Vector3 = pos + dir * (dist + 0.05)
	apex.y = topo + 0.04
	if not _cap_livre(apex, RADIUS - 0.08):
		return false
	if test_move(Transform3D(Basis(), pos), p1 - pos):
		return false
	# 4) pouso: em cima do obstáculo se for largo; senão do outro lado (primeiro ponto livre)
	var pouso := Vector3.INF
	var candidatos: Array[float] = [dist + RADIUS + 0.1]
	for d in [0.5, 0.8, 1.1, 1.5, 2.0]:
		candidatos.append(dist + d)
	for i in candidatos.size():
		var d: float = candidatos[i]
		var xz: Vector3 = pos + dir * d
		var g := _raio(xz + Vector3(0, topo + 0.6, 0), xz + Vector3(0, -2.5, 0))
		if g.is_empty() or g.normal.y < cos(floor_max_angle) or not _cap_livre(g.position + Vector3(0, 0.02, 0)):
			continue
		if i == 0 and absf(g.position.y - topo) > 0.12:
			continue                      # o primeiro candidato só vale se for o topo do obstáculo
		var p3: Vector3 = g.position + Vector3(0, 0.02, 0)
		var p2 := Vector3(p3.x, topo + 0.04, p3.z)
		if test_move(Transform3D(Basis(), p1), p2 - p1):
			continue
		if p3.y < p2.y and test_move(Transform3D(Basis(), p2), p3 - p2):
			continue
		pouso = p3
		break
	if pouso == Vector3.INF:
		return false
	var p2v := Vector3(pouso.x, topo + 0.04, pouso.z)
	_mantle_pts = [pos, p1, p2v, pouso]
	_mantle_dur = [clampf(h_rel / 3.4, 0.22, 0.55), maxf(0.14, Vector2(p2v.x - p1.x, p2v.z - p1.z).length() / 3.2), maxf(0.05, (p2v.y - pouso.y) / 6.0)]
	_mantle_t = 0.0
	_mantle_on = true
	velocity = Vector3.ZERO
	_mantle_cool = 0.5
	_emit_jump_sound()
	return true


func _mantle_passo(dt: float) -> void:
	_mantle_t += dt
	var total := _mantle_dur[0] + _mantle_dur[1] + _mantle_dur[2]
	var prog := clampf(_mantle_t / maxf(total, 0.001), 0.0, 1.0)
	# câmera (técnica de FPS: olha o apoio, inclina a cabeça ao passar a perna e abre o FOV no impulso)
	mantle_fx = Vector3(-0.24 * sin(PI * clampf(prog * 1.25, 0.0, 1.0)), 0.075 * sin(TAU * prog), 5.0 * sin(PI * prog))
	var t_acc := _mantle_t
	var idx := 0
	while idx < 3 and t_acc > _mantle_dur[idx]:
		t_acc -= _mantle_dur[idx]
		idx += 1
	if idx >= 3:
		global_position = _mantle_pts[3]
		_mantle_on = false
		var dir_h := Vector3(_mantle_pts[3].x - _mantle_pts[1].x, 0, _mantle_pts[3].z - _mantle_pts[1].z).normalized()
		velocity = dir_h * 1.2
		_mantle_cool = 0.35
		was_on_floor = false
		return
	var k := clampf(t_acc / maxf(_mantle_dur[idx], 0.001), 0.0, 1.0)
	var pos: Vector3
	match idx:
		0:   # puxada: sobe acelerando e desacelera ao chegar ao apoio (ease-out) com leve arrasto para a frente
			k = 1.0 - (1.0 - k) * (1.0 - k)
			pos = _mantle_pts[0].lerp(_mantle_pts[1], k)
			pos += (_mantle_pts[2] - _mantle_pts[1]).normalized() * 0.1 * sin(PI * k)
		1:   # travessia por cima: ease in-out com arco (quadril sobe um pouco ao passar a perna)
			k = k * k * (3.0 - 2.0 * k)
			pos = _mantle_pts[1].lerp(_mantle_pts[2], k)
			pos.y += 0.1 * sin(PI * k)
		_:   # descida ao pouso: acelera (gravidade)
			k = k * k
			pos = _mantle_pts[2].lerp(_mantle_pts[3], k)
	global_position = pos
	velocity = Vector3.ZERO


# ------------------------------------------------------------------ escada vertical (90°)
const ESCADA_VEL := 2.3
var _esc_estado := 0                 # 1 entrando · 2 subindo · 3 saindo
var _esc_t := 0.0
var _esc_de := Vector3.ZERO
var _esc_para := Vector3.ZERO
var _esc_final := Vector3.ZERO
var _esc_use_prev := true


func escada_mais_proxima() -> Node:
	var melhor: Node = null
	var md := INF
	for e in escadas_perto:
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < md:
			md = d
			melhor = e
	return melhor


## Começa a escalar. Por baixo: entra na linha da escada no pé; por cima: sai da plataforma para a linha e desce.
func iniciar_escada(e: Node) -> void:
	if escada != null or not alive:
		return
	var meio: float = (e.base_world().y + e.topo_world().y) * 0.5
	var de_cima: bool = global_position.y > meio
	escada = e
	climb_v = 0.0
	velocity = Vector3.ZERO
	_esc_de = global_position
	_esc_para = e.linha_world(e.topo_world().y if de_cima else e.base_world().y)
	_esc_estado = 1
	_esc_t = 0.0
	_esc_use_prev = true
	var f: Vector3 = e.frente()
	yaw = atan2(-f.x, -f.z)
	pitch = 0.0


func soltar_escada(queda := true) -> void:
	if escada == null:
		return
	var f: Vector3 = escada.frente()
	escada = null
	_esc_estado = 0
	climb_v = 0.0
	if queda:
		velocity = -f * 2.0
	was_on_floor = false
	_mantle_cool = 0.3


func _subir_escada(dt: float) -> void:
	var e: Node = escada
	if not is_instance_valid(e):
		soltar_escada(false)
		return
	var f: Vector3 = e.frente()
	var yaw_f := atan2(-f.x, -f.z)
	yaw = yaw_f + clampf(wrapf(yaw - yaw_f, -PI, PI), -deg_to_rad(65.0), deg_to_rad(65.0))
	velocity = Vector3.ZERO
	var topo: Vector3 = e.topo_world()
	var base: Vector3 = e.base_world()
	if _esc_estado == 1:
		_esc_t += dt / 0.3
		global_position = _esc_de.lerp(_esc_para, smoothstep(0.0, 1.0, minf(_esc_t, 1.0)))
		if _esc_t >= 1.0:
			_esc_estado = 2
		return
	if _esc_estado == 3:
		_esc_t += dt / 0.45
		var k := smoothstep(0.0, 1.0, minf(_esc_t, 1.0))
		var p := _esc_de.lerp(_esc_final, k)
		p.y += sin(k * PI) * 0.25           # passa por cima da borda
		global_position = p
		if _esc_t >= 1.0:
			global_position = _esc_final
			escada = null
			_esc_estado = 0
			climb_v = 0.0
			was_on_floor = false
			_mantle_cool = 0.3
		return
	# subindo / descendo
	var use_novo := in_use and not _esc_use_prev
	_esc_use_prev = in_use
	if in_jump or use_novo:
		soltar_escada(true)
		return
	climb_v = in_move.y * ESCADA_VEL
	var pos := global_position
	pos.y += climb_v * dt
	var linha: Vector3 = e.linha_world(pos.y)
	pos.x = linha.x
	pos.z = linha.z
	if pos.y >= topo.y and in_move.y > 0.1:
		global_position = Vector3(pos.x, topo.y, pos.z)
		_esc_estado = 3
		_esc_t = 0.0
		_esc_de = global_position
		_esc_final = topo
		return
	if pos.y <= base.y and in_move.y < -0.1:
		global_position = base
		escada = null
		_esc_estado = 0
		climb_v = 0.0
		was_on_floor = false
		return
	pos.y = clampf(pos.y, base.y, topo.y)
	global_position = pos


func _update_footsteps(dt: float, on_floor: bool) -> void:
	if not on_floor:
		return
	var sp := horizontal_speed()
	# andar com Shift e agachado são silenciosos (como no CS)
	if sp < 3.5 or in_walk or crouch > 0.5:
		step_accum = 0.0
		return
	step_accum += sp * dt
	if step_accum > 2.05:
		step_accum = 0.0
		_emit_footstep(false)


func surface_below() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.4, LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "sand"
	var c: Object = hit.collider
	return str(c.get_meta("surface", "stone")) if c else "stone"


func _emit_footstep(heavy: bool) -> void:
	var s := surface_below()
	footstep.emit(s)
	var id := "step_" + s
	if not Audio.has_sound(id):
		id = "step_stone"
	var vol := -4.0 if heavy else -9.0
	if is_local:
		Audio.play(id, {"volume_db": vol - 4.0, "pitch_var": 0.08})
	else:
		Audio.play_at(id, global_position, {"volume_db": vol + 4.0, "unit_size": 4.0, "max_distance": 38.0, "pitch_var": 0.08})
	if match_ref:
		match_ref.report_noise(self, global_position, 30.0 if not heavy else 34.0)


func _emit_jump_sound() -> void:
	if is_local:
		Audio.play("jump", {"volume_db": -10.0})
	elif match_ref:
		match_ref.report_noise(self, global_position, 18.0)


# ------------------------------------------------------------------ inventário
func give_weapon(id: StringName, silent := false) -> WeaponState:
	var def := WeaponDB.get_def(id)
	if def == null:
		return null
	var ws := WeaponState.new(def)
	inventory[def.slot] = ws
	if def.slot == WeaponDef.Slot.BOMB:
		is_carrying_bomb = true
	inventory_changed.emit()
	if not silent:
		switch_to(def.slot)
	return ws


func remove_slot(slot: int) -> WeaponState:
	var ws: WeaponState = inventory.get(slot)
	if ws == null:
		return null
	inventory.erase(slot)
	if slot == WeaponDef.Slot.BOMB:
		is_carrying_bomb = false
	if active_slot == slot:
		_cancel_reload()
		var order := [WeaponDef.Slot.PRIMARY, WeaponDef.Slot.PISTOL, WeaponDef.Slot.KNIFE]
		var achou := false
		for s in order:
			if inventory.has(s):
				_do_switch(s)
				achou = true
				break
		if not achou:
			# sem nada na mão: o slot ativo não pode continuar apontando para a arma que saiu
			# (senão equipar outra no mesmo slot era ignorado e o viewmodel ficava com o modelo antigo)
			active_slot = -1
			announced_id = &""
			weapon_switched.emit(null)
	inventory_changed.emit()
	return ws


func switch_to(slot: int) -> void:
	if not inventory.has(slot) or not alive:
		return
	var d_novo: WeaponDef = (inventory[slot] as WeaponState).def
	if slot == active_slot and ready_at > 0.0 and d_novo.id == announced_id:
		return
	if slot != active_slot:
		last_slot = active_slot
	_do_switch(slot)


func _do_switch(slot: int) -> void:
	_cancel_reload()
	planting = 0.0
	active_slot = slot
	var def := current_def()
	announced_id = def.id if def else &""
	ready_at = t + (def.draw_time if def else 0.5)
	next_attack = maxf(next_attack, ready_at)
	shots_fired = 0.0
	weapon_switched.emit(def)


func cycle_weapon(dir: int) -> void:
	var slots := inventory.keys()
	slots.sort()
	if slots.is_empty():
		return
	var idx := slots.find(active_slot)
	idx = wrapi(idx + dir, 0, slots.size())
	switch_to(slots[idx])


func reset_for_round(keep_weapons: bool) -> void:
	escada = null
	_esc_estado = 0
	_mantle_on = false
	alive = true
	external_motion = false
	frozen = false
	visible = true
	was_on_floor = false
	fall_speed = 0.0
	eye_offset_smooth = 0.0
	step_accum = 0.0
	jump_released = true
	jump_penalty = 0.0
	health = 100
	cura_cancelar("reiniciou")
	sangrando = false
	velocity = Vector3.ZERO
	crouch = 0.0
	_capsule.height = STAND_HEIGHT
	_shape.position.y = STAND_HEIGHT * 0.5
	_shape.disabled = false
	set_hitboxes_enabled(true)
	planting = 0.0
	defusing = 0.0
	round_damage.clear()
	round_kills = 0
	last_hit_by = null
	shots_fired = 0.0
	fire_inacc = 0.0
	aim_punch = Vector2.ZERO
	punch_vel = Vector2.ZERO
	reload_end = 0.0
	is_sprinting = false
	sprint_block_until = 0.0
	_balas.clear()
	if not keep_weapons:
		inventory.clear()
		is_carrying_bomb = false
		has_defuser = false
		armor = 0
		has_helmet = false
		has_vest = false
		plates = 0
		plate_left = 0.0
	else:
		inventory.erase(WeaponDef.Slot.BOMB)
		is_carrying_bomb = false
	if not inventory.has(WeaponDef.Slot.KNIFE):
		give_weapon(&"knife", true)
	if not inventory.has(WeaponDef.Slot.PISTOL):
		give_weapon(&"glock" if team == 0 else &"usp", true)
	for ws: WeaponState in inventory.values():
		ws.refill()
	var best := WeaponDef.Slot.PRIMARY if inventory.has(WeaponDef.Slot.PRIMARY) else WeaponDef.Slot.PISTOL
	active_slot = -1
	_do_switch(best)
	ready_at = t
	next_attack = t
	if body_model and body_model.has_method("on_respawn"):
		body_model.on_respawn(self)
	inventory_changed.emit()


# ------------------------------------------------------------------ armas
func _update_weapon(dt: float) -> void:
	var ws := current()
	# spray e imprecisão se recuperam
	var def := ws.def if ws else null
	if def and def.is_gun():
		if t - last_shot > def.fire_interval * 1.6:
			var n := float(maxi(def.recoil_pattern.size(), 1))
			shots_fired = move_toward(shots_fired, 0.0, dt * n / maxf(def.recoil_recover, 0.05))
		fire_inacc = move_toward(fire_inacc, 0.0, dt * def.spread_fire_max / maxf(def.spread_recover, 0.05))
		var target := def.pattern_offset(shots_fired) * def.view_kick
		if t - last_shot > def.fire_interval * 1.6:
			target *= 0.0
		# mola criticamente amortecida com solução exata por passo (estável em qualquer dt):
		# o impulso de cada tiro (_fire_bullet) sobe kick_deg e volta a 10% em ~5,3/ω s
		var w := def.kick_omega if def.kick_deg > 0.0 else 9.49
		var y := aim_punch - target
		var e := exp(-w * dt)
		var q := punch_vel + y * w
		aim_punch = target + (y + q * dt) * e
		punch_vel = (punch_vel - q * (w * dt)) * e
	else:
		aim_punch = aim_punch.lerp(Vector2.ZERO, clampf(dt * 10.0, 0.0, 1.0))

	if ws == null:
		return
	if reload_end > 0.0 and t >= reload_end:
		_finish_reload()
	if frozen:
		trigger_down = in_fire
		return
	if not in_fire:
		trigger_down = false

	match def.slot:
		WeaponDef.Slot.KNIFE:
			if t >= next_attack and t >= ready_at and not sprint_bloqueado():
				if in_fire:
					_knife_attack(false)
				elif in_alt:
					_knife_attack(true)
		WeaponDef.Slot.BOMB:
			pass
		_:
			if in_reload and not is_reloading():
				start_reload()
			if in_fire and t >= next_attack and t >= ready_at and not is_reloading() and not sprint_bloqueado():
				if def.automatic or not trigger_down:
					if ws.mag > 0:
						_fire_bullet(ws)
					else:
						trigger_down = true
						next_attack = t + 0.25
						if is_local:
							Audio.play("dry_fire", {"volume_db": -6.0})
						if ws.reserve > 0:
							start_reload()
	if in_fire:
		trigger_down = true


func start_reload() -> void:
	var ws := current()
	if ws == null or not ws.def.is_gun() or is_reloading() or nadando:
		return
	if ws.mag >= ws.def.mag_size or ws.reserve <= 0:
		return
	reload_end = t + ws.def.reload_time
	shots_fired = 0.0
	reload_started.emit(ws.def)
	if not is_local and match_ref:
		Audio.play_at("reload_" + String(ws.def.id), global_position, {"volume_db": -6.0, "max_distance": 20.0})


func _finish_reload() -> void:
	reload_end = 0.0
	var ws := current()
	if ws == null:
		return
	var need := ws.def.mag_size - ws.mag
	var take := mini(need, ws.reserve)
	ws.mag += take
	ws.reserve -= take
	reload_finished.emit(ws.def)
	inventory_changed.emit()


func _cancel_reload() -> void:
	reload_end = 0.0


func current_spread() -> float:
	var def := current_def()
	if def == null or not def.is_gun():
		return 0.0
	var base := lerpf(def.spread_stand, def.spread_crouch, crouch)
	var ratio := horizontal_speed() / maxf(def.move_speed, 0.1)
	var move_pen := def.spread_move * pow(clampf((ratio - 0.34) / 0.66, 0.0, 1.0), 1.25)
	var air := def.spread_air if not is_on_floor() else 0.0
	# ADS: alça/massa firmes -> espalhamento parado e de movimento cai para 30%, o do tiro seguido para 60%
	var k := aim_amount
	return (base + move_pen) * lerpf(1.0, 0.3, k) + air + fire_inacc * lerpf(1.0, 0.6, k)


func _fire_bullet(ws: WeaponState) -> void:
	var def := ws.def
	ws.mag -= 1
	next_attack = t + def.fire_interval
	var spread := current_spread()
	var pat := def.pattern_offset(shots_fired)
	var rnd := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * def.recoil_random * minf(shots_fired, 3.0) / 3.0
	var off := pat + rnd
	# cone aleatório (distribuição concentrada no centro, como o CS)
	var ang := randf() * TAU
	var r := randf() * spread
	off += Vector2(cos(ang), sin(ang)) * r
	var b := Basis.from_euler(Vector3(pitch + deg_to_rad(off.y), yaw - deg_to_rad(off.x), 0.0), EULER_ORDER_YXZ)
	var dir := -b.z
	shots_fired += 1.0
	last_shot = t
	fire_inacc = minf(fire_inacc + def.spread_fire, def.spread_fire_max)
	if def.kick_deg > 0.0:
		# impulso de coice: numa mola crítica o pico é v0/(ω·e) -> v0 = pico·e·ω
		var kv := def.kick_deg * exp(1.0) * def.kick_omega
		punch_vel += Vector2(randf_range(-1.0, 1.0) * def.kick_yaw, 1.0) * kv
	var hit_info: Dictionary
	if def.muzzle_velocity > 0.0 and not Game.test_args.has("hitscan"):   # --hitscan: comparação A/B do custo
		hit_info = _disparar_projetil(b, off, def)
	else:
		hit_info = trace_bullet(eye_position(), dir, def)
	combat_t = t
	fired.emit(def)
	if match_ref:
		match_ref.on_shot(self, def, eye_position(), hit_info)
		match_ref.report_noise(self, global_position, 70.0)
	inventory_changed.emit()


# ------------------------------------------------------------------ balística (projétil simulado, sem nós)
# Cada bala é um Dictionary avançado em subpassos RK2 (2 por tique de 64 Hz, um raycast por subpasso).
# Mesma lógica de hitbox/penetração do hitscan antigo, mas o dano chega depois do tempo de voo.
var _balas: Array = []
var _excl_base: Array[RID] = []


func balas_em_voo() -> int:
	return _balas.size()


func _disparar_projetil(b: Basis, off: Vector2, def: WeaponDef) -> Dictionary:
	var theta := def.zero_angle()
	var eye := eye_position()
	var origin := eye - b.y * def.sight_height
	var bb := Basis.from_euler(Vector3(pitch + deg_to_rad(off.y) + theta, yaw - deg_to_rad(off.x), 0.0), EULER_ORDER_YXZ)
	var dir := -bb.z
	if _excl_base.is_empty():
		_excl_base.append(get_rid())
		for a in hitboxes:
			_excl_base.append(a.get_rid())
	_balas.append({"p": origin, "v": dir * def.muzzle_velocity, "def": def, "dmg": def.damage,
		"pen": def.penetration, "wb": false, "dist": 0.0, "t": 0.0, "excl": _excl_base})
	# traçante: raio curto até a primeira parede (o impacto real vem depois, pela simulação)
	var vis := eye + (-b.z) * 80.0
	var q := PhysicsRayQueryParameters3D.create(eye, vis, LAYER_WORLD, _excl_base)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return {"end": h.position if not h.is_empty() else vis, "hit": false, "projetil": true}


func _balas_passo(dt: float) -> void:
	if _balas.is_empty() or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var n := maxi(1, ceili(dt / WeaponDef.BAL_DT - 0.001))
	var h := dt / float(n)
	for i in range(_balas.size() - 1, -1, -1):
		if _bala_avancar(_balas[i], h, n, space):
			_balas.remove_at(i)


## Avança uma bala n subpassos de h s. Retorna true quando ela acaba (acertou, parou ou expirou).
func _bala_avancar(bl: Dictionary, h: float, n: int, space: PhysicsDirectSpaceState3D) -> bool:
	var def: WeaponDef = bl.def
	for _s in n:
		var p: Vector3 = bl.p
		var v: Vector3 = bl.v
		var r := WeaponDef.passo_balistico(p, v, def.air_friction, h)
		var np: Vector3 = r[0]
		var nv: Vector3 = r[1]
		var seg := p.distance_to(np)
		var de := p
		for _tentativa in 6:
			var q := PhysicsRayQueryParameters3D.create(de, np, LAYER_WORLD | LAYER_HITBOX | ZombieEnemy.LAYER_HIT, bl.excl)
			q.collide_with_areas = true
			q.hit_back_faces = false
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var pos: Vector3 = hit.position
			var f := clampf(p.distance_to(pos) / maxf(seg, 0.0001), 0.0, 1.0)
			var vel := v.lerp(nv, f)
			var dirn := vel.normalized()
			var dist: float = float(bl.dist) + p.distance_to(pos)
			var info := {"pos": pos, "t_voo": float(bl.t) + h * f, "vel": vel.length(), "dist": dist, "normal": hit.normal}
			var col: Object = hit.collider
			if col is Area3D:
				if col.has_meta("zombie"):
					var zumbi = col.get_meta("zombie")
					if is_instance_valid(zumbi) and zumbi.state != ZombieEnemy.State.DEAD:
						# dano por tabela da arma (cabeça/corpo); dmg residual (parede atravessada) escala o resultado
						var res: Dictionary = zumbi.hit_by_bullet(pos, dirn, def, float(bl.dmg) / maxf(def.damage, 0.001), self)
						info["zombie"] = zumbi
						info["group"] = String(res.zone)
						info["surface"] = "flesh"
						bala_impacto.emit(info)
						return true
				elif col.has_meta("soldier"):
					var victim: Soldier = col.get_meta("soldier")
					if victim != self and victim.alive:
						var group: String = col.get_meta("group")
						var mult := 1.0
						match group:
							"head": mult = def.headshot_mult
							"stomach": mult = 1.25
							"legs": mult = 0.75
						var final: float = float(bl.dmg) * pow(def.range_mod, dist / 12.7) * mult
						victim.take_damage(final, self, def, group, dirn, bool(bl.wb))
						info["victim"] = victim
						info["group"] = group
						var fx = match_ref.get("fx") if match_ref else null
						if fx:
							fx.blood(pos, dirn, group == "head", final)
							if victim.body_model and victim.body_model.has_method("add_wound"):
								victim.body_model.add_wound(pos, -dirn)
						bala_impacto.emit(info)
						return true
				var ex: Array[RID] = []
				ex.assign(bl.excl)
				ex.append(col.get_rid())
				bl.excl = ex
				de = pos
				continue
			var surface := str(col.get_meta("surface", "stone")) if col else "stone"
			info["surface"] = surface
			if match_ref:
				match_ref.on_impact(pos, hit.normal, surface, dirn)
			bala_impacto.emit(info)
			var max_thick := 0.0
			match surface:
				"wood": max_thick = 0.45
				"metal": max_thick = 0.12
				"plaster": max_thick = 0.3
				"cloth": max_thick = 1.0
			if float(bl.pen) <= 0.0 or max_thick <= 0.0:
				return true
			var far := pos + dirn * (max_thick + 0.02)
			var bh := space.intersect_ray(PhysicsRayQueryParameters3D.create(far, pos, LAYER_WORLD))
			if bh.is_empty() or pos.distance_to(bh.position) > max_thick:
				return true
			var exit_pos: Vector3 = bh.position
			bl.dmg = float(bl.dmg) * (0.55 if surface != "cloth" else 0.9)
			bl.pen = float(bl.pen) - 1.0
			bl.wb = true
			nv *= 0.75 if surface != "cloth" else 0.95
			if match_ref:
				match_ref.on_impact(exit_pos, -dirn, surface, dirn)
			de = exit_pos + dirn * 0.02
			if p.distance_to(de) >= seg:
				# atravessou além do fim do subpasso: segue do ponto de saída no próximo
				np = de
				break
		bl.p = np
		bl.v = nv
		bl.t = float(bl.t) + h
		bl.dist = float(bl.dist) + seg
		if float(bl.t) > def.bullet_max_time or nv.length() < 60.0 or np.y < -300.0:
			return true
	return false


## Hitscan com penetração simples em paredes finas. Retorna o último ponto atingido.
func trace_bullet(origin: Vector3, dir: Vector3, def: WeaponDef) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	for a in hitboxes:
		exclude.append(a.get_rid())
	var from := origin
	var dmg := def.damage
	var pen_left := def.penetration
	var travelled := 0.0
	var wallbang := false
	var result := {"end": origin + dir * def.max_range, "hit": false}
	for i in 5:
		var q := PhysicsRayQueryParameters3D.create(from, origin + dir * def.max_range, LAYER_WORLD | LAYER_HITBOX | ZombieEnemy.LAYER_HIT, exclude)
		q.collide_with_areas = true
		q.hit_back_faces = false
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var col: Object = hit.collider
		var pos: Vector3 = hit.position
		travelled = origin.distance_to(pos)
		result["end"] = pos
		result["hit"] = true
		result["normal"] = hit.normal
		if col is Area3D and col.has_meta("zombie"):
			var zumbi = col.get_meta("zombie")
			if is_instance_valid(zumbi) and zumbi.state != ZombieEnemy.State.DEAD:
				var res: Dictionary = zumbi.hit_by_bullet(pos, dir, def, dmg / maxf(def.damage, 0.001), self)
				result["group"] = String(res.zone)
				result["surface"] = "flesh"
				return result
			exclude.append(col.get_rid())
			continue
		if col is Area3D and col.has_meta("soldier"):
			var victim: Soldier = col.get_meta("soldier")
			var group: String = col.get_meta("group")
			if victim != self and victim.alive:
				var mult := 1.0
				match group:
					"head": mult = def.headshot_mult
					"stomach": mult = 1.25
					"legs": mult = 0.75
				var final := dmg * pow(def.range_mod, travelled / 12.7) * mult
				victim.take_damage(final, self, def, group, dir, wallbang)
				result["victim"] = victim
				result["group"] = group
				result["surface"] = "flesh"
				return result
			exclude.append(col.get_rid())
			continue
		var surface := str(col.get_meta("surface", "stone")) if col else "stone"
		result["surface"] = surface
		if match_ref:
			match_ref.on_impact(pos, hit.normal, surface, dir)
		var max_thick := 0.0
		match surface:
			"wood": max_thick = 0.45
			"metal": max_thick = 0.12
			"plaster": max_thick = 0.3
			"cloth": max_thick = 1.0
		if pen_left <= 0.0 or max_thick <= 0.0:
			break
		# mede a espessura atirando de volta a partir do outro lado
		var far := pos + dir * (max_thick + 0.02)
		var back := PhysicsRayQueryParameters3D.create(far, pos, LAYER_WORLD)
		var bh := space.intersect_ray(back)
		if bh.is_empty():
			break
		var exit_pos: Vector3 = bh.position
		var thick := pos.distance_to(exit_pos)
		if thick > max_thick:
			break
		dmg *= 0.55 if surface != "cloth" else 0.9
		pen_left -= 1.0
		wallbang = true
		from = exit_pos + dir * 0.02
		if match_ref:
			match_ref.on_impact(exit_pos, -dir, surface, dir)
	return result


func _knife_attack(heavy: bool) -> void:
	next_attack = t + (1.0 if heavy else 0.5)
	var reach := 1.0 if heavy else 1.5
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	for a in hitboxes:
		exclude.append(a.get_rid())
	var origin := eye_position()
	var best: Dictionary = {}
	for off: Vector2 in [Vector2.ZERO, Vector2(6, 0), Vector2(-6, 0), Vector2(0, -6), Vector2(0, 5)]:
		var b := Basis.from_euler(Vector3(pitch + deg_to_rad(off.y), yaw + deg_to_rad(off.x), 0.0), EULER_ORDER_YXZ)
		var q := PhysicsRayQueryParameters3D.create(origin, origin - b.z * reach, LAYER_WORLD | LAYER_HITBOX, exclude)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		if hit.collider is Area3D:
			best = hit
			break
		if best.is_empty():
			best = hit
	var hit_something := not best.is_empty()
	if hit_something and best.collider is Area3D and best.collider.has_meta("soldier"):
		var victim: Soldier = best.collider.get_meta("soldier")
		if victim.alive and victim != self:
			var to_victim := (victim.global_position - global_position)
			to_victim.y = 0.0
			var victim_fwd := -Basis(Vector3.UP, victim.yaw).z
			var backstab := to_victim.normalized().dot(victim_fwd) > 0.45
			var dmg := 0.0
			if heavy:
				dmg = 180.0 if backstab else 65.0
			else:
				dmg = (90.0 if backstab else (40.0 if knife_quick == 0 else 25.0))
			knife_quick = 1
			victim.take_damage(dmg, self, WeaponDB.get_def(&"knife"), "chest", -to_victim.normalized(), false)
			Audio.play_at("knife_hit_flesh", best.position, {"volume_db": -2.0, "max_distance": 25.0})
			# sangue da facada: jato no sentido do golpe e ferimento no corpo
			if match_ref and match_ref.get("fx"):
				var kdir := aim_dir()
				match_ref.fx.blood(best.position, kdir, false, dmg)
				if victim.body_model and victim.body_model.has_method("add_wound"):
					victim.body_model.add_wound(best.position, -kdir)
	elif hit_something:
		Audio.play_at("knife_hit_wall", best.position, {"volume_db": -4.0, "max_distance": 25.0})
		if match_ref:
			match_ref.on_impact(best.position, best.normal, "knife", aim_dir())
	if not hit_something:
		knife_quick = 0
	knife_swung.emit(heavy, hit_something)
	if not is_local:
		Audio.play_at("knife_swing", global_position, {"volume_db": -8.0, "max_distance": 18.0})


# ------------------------------------------------------------------ bomba
func _update_objective(dt: float) -> void:
	if match_ref == null:
		return
	# plantar: TR com a bomba em mãos, dentro do bombsite, no chão, segurando ataque
	if active_slot == WeaponDef.Slot.BOMB and is_carrying_bomb:
		var site: String = match_ref.site_at(global_position)
		if in_fire and site != "" and is_on_floor() and match_ref.can_plant():
			if planting == 0.0:
				match_ref.on_plant_started(self)
			planting += dt
			plant_progress.emit(planting / PLANT_TIME)
			if planting >= PLANT_TIME:
				planting = 0.0
				match_ref.plant_bomb(self, site)
		elif planting > 0.0:
			planting = 0.0
			plant_progress.emit(0.0)
	elif planting > 0.0:
		planting = 0.0
		plant_progress.emit(0.0)
	# desarmar: CT segurando USAR perto da bomba
	if team == 1:
		var bomb: Node3D = match_ref.planted_bomb()
		var close := bomb != null and bomb.global_position.distance_to(global_position + Vector3.UP * 0.5) < 1.9
		if in_use and close and is_on_floor():
			if defusing == 0.0:
				match_ref.on_defuse_started(self)
			defusing += dt
			var need := DEFUSE_TIME_KIT if has_defuser else DEFUSE_TIME
			defuse_progress.emit(defusing / need)
			if defusing >= need:
				defusing = 0.0
				match_ref.defuse_bomb(self)
		elif defusing > 0.0:
			defusing = 0.0
			defuse_progress.emit(0.0)


# ------------------------------------------------------------------ dano e morte
func take_damage(amount: float, attacker: Soldier, def: WeaponDef, group: String, dir: Vector3, wallbang := false) -> void:
	if not alive or godmode:
		return
	if attacker and attacker != self and attacker.team == team and match_ref and not match_ref.friendly_fire():
		return
	var dmg := amount
	combat_t = t
	if attacker and attacker != self:
		attacker.combat_t = attacker.t
	var armored := armor > 0 and group != "legs" and (group != "head" or has_helmet)
	if armored and def:
		var to_health := dmg * def.armor_ratio
		var armor_loss := (dmg - to_health) * 0.5
		if armor_loss > armor:
			to_health = dmg - armor * 2.0
			armor_loss = armor
		armor = maxi(0, armor - int(armor_loss))
		dmg = to_health
	var final := int(maxf(dmg, 1.0))
	final = mini(final, health)
	health -= final
	if attacker and attacker != self:
		round_damage[attacker] = int(round_damage.get(attacker, 0)) + final
		last_hit_by = attacker
	damaged.emit(final, attacker, dir)
	if attacker and def and def.is_gun():
		# "tagging": levar tiro freia (como no CS)
		velocity.x *= 0.55
		velocity.z *= 0.55
	if body_model and body_model.has_method("on_hit"):
		body_model.on_hit(group, dir)
	if match_ref:
		match_ref.on_damage(self, attacker, final, group)
	if health <= 0:
		die(attacker, def, group == "head", wallbang, dir)
	elif group == "head":
		Audio.play_at("hit_helmet" if has_helmet else "hit_head", eye_position(), {"volume_db": 0.0, "max_distance": 40.0})


func die(killer: Soldier, def: WeaponDef, headshot := false, wallbang := false, dir := Vector3.ZERO) -> void:
	if not alive:
		return
	alive = false
	escada = null
	_mantle_on = false
	health = 0
	planting = 0.0
	defusing = 0.0
	deaths += 1
	_shape.disabled = true
	set_hitboxes_enabled(false)
	velocity = Vector3(dir.x, 0.0, dir.z) * 2.0
	if match_ref:
		match_ref.drop_on_death(self)
	if body_model and body_model.has_method("on_death"):
		body_model.on_death(dir, headshot)
	died.emit(self, killer, def, headshot, wallbang)


func add_money(v: int) -> void:
	money = clampi(money + v, 0, 16000)
	inventory_changed.emit()
