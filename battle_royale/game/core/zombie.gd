class_name ZombieEnemy
extends CharacterBody3D
## Polyart visuals use the free Animated-Zombie pack's complete animation rig.

signal state_changed(state_name: StringName)
signal attacked(target_node: Node3D, damage: int)
## Emitido UMA vez, na transição para DEAD. headshot = último golpe na cabeça.
signal died(zombie: ZombieEnemy, headshot: bool, attacker: Node3D)
signal hit_taken(zone: StringName, amount: int, attacker: Node3D)

enum State { IDLE, PATROL, ALERT, INVESTIGATE, CHASE, ATTACK, DEAD }

const ANIMATION_SCENE := "res://assets/models/zombies/free_animated_pack/scene.gltf"
const POSE_COPY_SCRIPT := preload("res://core/zombie_pose_copy.gd")
const POLYART_VARIANTS := [
	"res://assets/models/zombies/polyart_pack/variants/zombie_00.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_01.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_02.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_03.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_04.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_05.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_06.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_07.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_08.tscn",
	"res://assets/models/zombies/polyart_pack/variants/zombie_09.tscn",
]
const HUMANOID_MAP := {
	"mixamorig_Hips": "Hips", "mixamorig_Spine": "Spine", "mixamorig_Spine1": "Chest",
	"mixamorig_Spine2": "UpperChest", "mixamorig_Neck": "Neck", "mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "LeftShoulder", "mixamorig_LeftArm": "LeftUpperArm",
	"mixamorig_LeftForeArm": "LeftLowerArm", "mixamorig_LeftHand": "LeftHand",
	"mixamorig_RightShoulder": "RightShoulder", "mixamorig_RightArm": "RightUpperArm",
	"mixamorig_RightForeArm": "RightLowerArm", "mixamorig_RightHand": "RightHand",
	"mixamorig_LeftUpLeg": "LeftUpperLeg", "mixamorig_LeftLeg": "LeftLowerLeg",
	"mixamorig_LeftFoot": "LeftFoot", "mixamorig_LeftToeBase": "LeftToes",
	"mixamorig_RightUpLeg": "RightUpperLeg", "mixamorig_RightLeg": "RightLowerLeg",
	"mixamorig_RightFoot": "RightFoot", "mixamorig_RightToeBase": "RightToes",
}
const FREE_PACK_BONE_MAP := {
	"Hips_02": "Hips", "Spine_01_03": "Spine", "Spine_02_04": "Chest",
	"Spine_03_05": "UpperChest", "Neck_06": "Neck", "Head_07": "Head",
	"Clavicle_L_015": "LeftShoulder", "Shoulder_L_016": "LeftUpperArm",
	"Elbow_L_017": "LeftLowerArm", "Hand_L_018": "LeftHand",
	"Clavicle_R_030": "RightShoulder", "Shoulder_R_031": "RightUpperArm",
	"Elbow_R_032": "RightLowerArm", "Hand_R_033": "RightHand",
	"UpperLeg_L_050": "LeftUpperLeg", "LowerLeg_L_051": "LeftLowerLeg",
	"Ankle_L_052": "LeftFoot", "Toes_L_054": "LeftToes",
	"UpperLeg_R_045": "RightUpperLeg", "LowerLeg_R_046": "RightLowerLeg",
	"Ankle_R_047": "RightFoot", "Toes_R_049": "RightToes",
}
const CLIPS := {
	&"idle": "IDLE", &"walk": "WALK", &"scream": "HIT", &"run": "RUN",
	&"attack": "ATK", &"death": "DEAD", &"neck_bite": "ATK_HEAD",
	&"crawl": "WALK", &"bite": "ATK_HEAD", &"bite_alt": "ATK",
	&"dying": "DEAD", &"running_crawl": "RUN",
}
## Soldier.STAND_HEIGHT = 1,83 m; zumbi ligeiramente mais alto (1,90 m medido por AABB da malha).
const ALTURA_ALVO := 1.90
## Camada física dos hitboxes de zumbi (Area3D); balas do Soldier a incluem na máscara. Layer 6 = valor 32.
const LAYER_HIT := 32
## Cabeça = fração superior da cápsula (>= 80% da altura). Dano por arma: WeaponDB.ZUMBI_DANO.
const CABECA_FRACAO := 0.80
const CAPSULA_ALTURA := 1.88
## Velocidade do pé de apoio (m/s, animação a 1x) medida por tests/zombie_measure.gd com a malha em 1,72 m
## (escala linear com a altura). Usada para casar a velocidade da animação com o deslocamento real (sem patinar).
const PASSADA_REF_ALTURA := 1.72
const PASSADA_WALK_REF := 0.883
const PASSADA_RUN_REF := 3.135
const BLEND_WALK := 0.58
const BLEND_RUN := 2.75
const VISIVEL_ATE := 110.0
const OUVE_TIRO_MAX := 150.0
const LOOPING_CLIPS := [&"idle", &"walk", &"run", &"crawl", &"running_crawl"]
static var _shared_animation_library: AnimationLibrary

@export var detection_range := 35.0   # visão (cone frontal + linha de visada)
@export var hearing_range := 10.0     # ouve passos em qualquer direção
@export_range(30.0, 160.0, 1.0) var field_of_view_degrees := 105.0
@export var vertical_sight_limit := 5.5
@export var lose_range := 45.0
@export var attack_range := 1.75
@export var walk_speed := 0.58
@export var run_speed := 2.75
@export var attack_damage := 16
@export var attack_cooldown := 1.35
@export var turn_speed := 5.5
@export_range(0.0, 0.5, 0.01) var locomotion_stop_threshold := 0.14
@export_range(0.0, 0.6, 0.01) var locomotion_resume_threshold := 0.22

var state: State = State.IDLE
var target: Node3D
var health := 100
var max_health := 100
var _hit_area: Area3D
var _flinch := 0.0
var mortes_emitidas := 0
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _source_skeleton: Skeleton3D
var _target_skeleton: Skeleton3D
var _navigation: NavigationAgent3D
var _state_time := 0.0
var _attack_time := 0.0
var _repath_time := 0.0
var _patrol_time := 0.0
var _idle_duration := 2.5
var _patrol_direction := Vector3.FORWARD
var _patrol_destination := Vector3.ZERO
var _last_known_position := Vector3.ZERO
var _sense_timer := 0.0
var _time_without_sight := 0.0
var _groan_timer := 0.0
var _hurt_ms := 0
var _stuck_time := 0.0
var _last_patrol_position := Vector3.ZERO
var _demo_locked := false
var _demo_locomotion_speed := 0.0
var _locomotion_is_moving := false
var _has_entered_state := false
var _death_finished := false
var _ultima_zona: StringName = &""
var _golpe_dir := Vector3.ZERO     # direção (mundo, plana) do último golpe: define para onde o corpo cai
var _hips_alto := 0.95            # altura dos quadris do modelo de pé (medida na hora da morte)
var _morte_ativa := false
var _visual_root: Node3D
var _fitted_visual_height := 0.0
var archetype: StringName = &"walker"
var _attack_animation: StringName = &"attack"
var _death_animation: StringName = &"death"
var _variant_index := -1
## LOD de IA/física/animação (definido pelo ZombieDirector): 0 = completo; 1 = médio (tick a cada LOD1_PASSO quadros
## de física com delta acumulado, animação avançada só no tick); 2 = dormindo (sem física, sem animação, invisível).
const LOD1_PASSO := 4
var lod := 0
var _lod_acc := 0.0
var _lod_quadro := 0
var _lod_escala := 1.0
var _pose_copy: SkeletonModifier3D
## preso ao perseguir (mureta, degrau, cerca baixa): pula por cima; se não adiantar, contorna de lado
var _pos_perseguicao := Vector3.ZERO
## Steering local (sem navmesh na ilha): whiskers, contorno de parede com lado memorizado, detecção de travamento.
const SONDA_ALCANCE := 1.6
const SALTO_ALTURA_MAX := 1.05
const SONDA_ALTURAS := [0.3, 1.3]
const SONDA_ANGULO := 0.61   # ~35 graus
var _sonda_t := 0.0
var _sonda_livre := {"c": SONDA_ALCANCE, "e": SONDA_ALCANCE, "d": SONDA_ALCANCE}
var _sonda_normal_c := Vector3.ZERO
var _sonda_baixo := false   # obstáculo à frente é baixo e saltável
var _sonda_porta: Node = null
var _lado := 0.0            # lado de contorno memorizado (+1/-1); 0 = nenhum
var _lado_t := 0.0
var _seguindo := false      # modo contorno de parede (Bug2): só sai quando a linha até a meta está livre e mais perto que o ponto de impacto
var _n_parede := Vector3.ZERO
var _dist_impacto := 0.0
var _seguindo_t := 0.0
var _recuo_t := 0.0
var _salto_cd := 0.0
var _prog_t := 0.0
var _prog_dist := 0.0
var _prog_pos := Vector3.ZERO
var _porta_cd := 0.0
var contagem_travamentos := 0
var contagem_saltos := 0
const SALTO_V := 6.8   # sobe ~1,15 m com a gravidade de 20 m/s²


func _ready() -> void:
	name = "Zombie"
	add_to_group("zombie")
	_build_collision()
	_build_rig()
	_build_navigation()
	_apply_archetype()
	_sense_timer = randf_range(0.05, 0.25)
	_groan_timer = randf_range(1.0, 7.0)
	if not Audio.barulho.is_connected(_on_world_noise):
		Audio.barulho.connect(_on_world_noise)
	_set_state(State.IDLE)


func _build_collision() -> void:
	collision_layer = 1 << 1
	collision_mask = 1
	var shape_node := CollisionShape3D.new()
	shape_node.name = "BodyCollider"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = CAPSULA_ALTURA
	shape_node.shape = capsule
	shape_node.position.y = CAPSULA_ALTURA * 0.5
	add_child(shape_node)
	# hitbox de tiro: Area3D só na camada LAYER_HIT (não bloqueia movimento); cabeça/corpo vêm da altura do impacto
	_hit_area = Area3D.new()
	_hit_area.name = "HitArea"
	_hit_area.collision_layer = LAYER_HIT
	_hit_area.collision_mask = 0
	_hit_area.monitoring = false
	_hit_area.set_meta("zombie", self)
	var hs := CollisionShape3D.new()
	var hc := CapsuleShape3D.new()
	hc.radius = 0.34
	hc.height = CAPSULA_ALTURA + 0.04
	hs.shape = hc
	hs.position.y = CAPSULA_ALTURA * 0.5
	_hit_area.add_child(hs)
	add_child(_hit_area)


func _build_rig() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	var animation_scene := load(ANIMATION_SCENE) as PackedScene
	if animation_scene == null:
		push_error("Free animated zombie rig failed to import")
		return
	var animation_root := animation_scene.instantiate()
	_visual_root.add_child(animation_root)
	_animation_player = animation_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_source_skeleton = animation_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if _animation_player == null or _source_skeleton == null:
		push_error("Free animated zombie must provide its AnimationPlayer and Skeleton3D")
		return
	# Keep only the animation skeleton. The source mesh is not part of the final
	# appearance, and removing it avoids rendering both characters together.
	for visual in animation_root.find_children("*", "MeshInstance3D", true, false):
		visual.free()
	_rename_source_bones()
	_load_animation_library()
	_build_animation_controller()
	if _variant_index < 0:
		_variant_index = randi_range(0, POLYART_VARIANTS.size() - 1)
	var model_scene := load(POLYART_VARIANTS[_variant_index]) as PackedScene
	if model_scene == null:
		push_error("Polyart zombie appearance failed to load: " + POLYART_VARIANTS[_variant_index])
		return
	var model_root := model_scene.instantiate()
	_visual_root.add_child(model_root)
	_target_skeleton = model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if _target_skeleton == null:
		push_error("Polyart appearance has no Skeleton3D")
		return
	_fit_visual_height(model_root)
	# Keep the Polyart skeleton, skinned mesh and its import-axis conversion intact.
	# Copy only calibrated world-space rotation deltas from the animation rig.
	var pose_copy := POSE_COPY_SCRIPT.new()
	pose_copy.name = "AnimatedZombiePose"
	pose_copy.source_skeleton = _source_skeleton
	_target_skeleton.add_child(pose_copy)
	_pose_copy = pose_copy
	# longe do jogador o zumbi some (a IA continua no LOD do diretor); sombra só perto
	for g in model_root.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = VISIVEL_ATE
		(g as GeometryInstance3D).visibility_range_end_margin = 6.0
	# Imported Polyart scenes carry the Z-up -> Y-up conversion under rig_CharRoot.
	# This yaw aligns its forward direction with the gameplay -Z axis.
	_visual_root.rotation.y = PI


func _fit_visual_height(model_root: Node3D) -> void:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var root_inverse := model_root.global_transform.affine_inverse()
	for mesh_instance in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance as MeshInstance3D
		var bounds := mesh.get_aabb()
		var relative := root_inverse * mesh.global_transform
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point: Vector3 = relative * Vector3(x, y, z)
					low = low.min(point)
					high = high.max(point)
	var measured_height := high.y - low.y
	if measured_height > 0.1:
		var fit := clampf(ALTURA_ALVO / measured_height, 0.55, 1.8)
		model_root.scale *= Vector3.ONE * fit
		model_root.position.y -= low.y * fit
		_fitted_visual_height = measured_height * fit


func _rename_source_bones() -> void:
	for bone_index in _source_skeleton.get_bone_count():
		var bone_name := String(_source_skeleton.get_bone_name(bone_index))
		if FREE_PACK_BONE_MAP.has(bone_name):
			_source_skeleton.set_bone_name(bone_index, StringName(FREE_PACK_BONE_MAP[bone_name]))

func _load_animation_library() -> void:
	var current_library := _animation_player.get_animation_library(&"")
	if _shared_animation_library != null:
		if current_library != null:
			_animation_player.remove_animation_library(&"")
		_animation_player.add_animation_library(&"", _shared_animation_library)
		return
	var source_animations: Dictionary = {}
	for clip_name in CLIPS:
		var source_clip := StringName(CLIPS[clip_name])
		if not source_animations.has(source_clip) and _animation_player.has_animation(source_clip):
			source_animations[source_clip] = (_animation_player.get_animation(source_clip) as Animation).duplicate(true)
	if current_library != null:
		_animation_player.remove_animation_library(&"")
	var library := AnimationLibrary.new()
	for clip_name in CLIPS:
		var source_clip := StringName(CLIPS[clip_name])
		if not source_animations.has(source_clip):
			push_error("Free zombie animation is missing: " + String(source_clip))
			continue
		var animation := (source_animations[source_clip] as Animation).duplicate(true)
		for track_index in animation.get_track_count():
			var track_path := String(animation.track_get_path(track_index))
			for source_bone in FREE_PACK_BONE_MAP:
				track_path = track_path.replace(":" + source_bone, ":" + String(FREE_PACK_BONE_MAP[source_bone]))
			animation.track_set_path(track_index, NodePath(track_path))
		animation.loop_mode = Animation.LOOP_LINEAR if clip_name in LOOPING_CLIPS else Animation.LOOP_NONE
		library.add_animation(clip_name, animation)
	_shared_animation_library = library
	_animation_player.add_animation_library(&"", library)


func _build_animation_controller() -> void:
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 3.2
	locomotion.add_blend_point(_animation_node(&"idle"), 0.0, -1, &"idle")
	locomotion.add_blend_point(_animation_node(&"walk"), 0.58, -1, &"walk")
	locomotion.add_blend_point(_animation_node(&"run"), 2.75, -1, &"run")
	_animation_tree = AnimationTree.new()
	_animation_tree.name = "AnimationTree"
	var tempo := AnimationNodeTimeScale.new()
	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node(&"Locomotion", locomotion, Vector2(0, 0))
	blend_tree.add_node(&"TimeScale", tempo, Vector2(300, 0))
	blend_tree.connect_node(&"TimeScale", 0, &"Locomotion")
	blend_tree.connect_node(&"output", 0, &"TimeScale")
	_animation_tree.tree_root = blend_tree
	_animation_player.get_parent().add_child(_animation_tree)
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)
	_animation_tree.active = true
	_animation_tree.set(&"parameters/Locomotion/blend_position", 0.0)
	_animation_tree.set(&"parameters/TimeScale/scale", 1.0)


func _animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node


func _build_navigation() -> void:
	_navigation = NavigationAgent3D.new()
	_navigation.name = "NavigationAgent3D"
	_navigation.radius = 0.36
	_navigation.height = CAPSULA_ALTURA
	_navigation.path_desired_distance = 0.45
	_navigation.target_desired_distance = attack_range * 0.8
	_navigation.max_speed = run_speed
	_navigation.avoidance_enabled = false
	add_child(_navigation)


func set_target(target_node: Node3D) -> void:
	target = target_node
	if is_instance_valid(target):
		_last_known_position = target.global_position


func begin_roaming(initial_pause: float = 0.6) -> void:
	# Spawned city zombies should begin their patrol almost immediately; the longer
	# randomized pauses are reserved for later idle moments between patrol legs.
	if state == State.IDLE:
		_idle_duration = maxf(initial_pause, 0.0)


func configure_archetype(kind: StringName) -> void:
	archetype = kind
	if is_inside_tree():
		_apply_archetype()


func _apply_archetype() -> void:
	var collider := get_node_or_null("BodyCollider") as CollisionShape3D
	if archetype == &"crawler":
		walk_speed = 0.48
		run_speed = 2.25
		attack_damage = 13
		attack_cooldown = 1.2
		_attack_animation = &"attack"
		_death_animation = &"death"
		# This pack contains no crawl cycle, so keep the capsule around the upright
		# model instead of pretending the standing mesh is a floor crawler.
		if collider and collider.shape is CapsuleShape3D:
			(collider.shape as CapsuleShape3D).height = CAPSULA_ALTURA
			(collider.shape as CapsuleShape3D).radius = 0.36
			collider.position.y = CAPSULA_ALTURA * 0.5
	elif archetype == &"brute":
		walk_speed = 0.58
		run_speed = 2.5
		attack_damage = 24
		attack_cooldown = 1.7
		_attack_animation = &"neck_bite"
		_death_animation = &"death"
	else:
		walk_speed = 0.58
		run_speed = 2.75
		attack_damage = 17
		attack_cooldown = 1.25
		_attack_animation = &"attack"
		_death_animation = &"death"


func set_demo_state(state_name: StringName) -> void:
	_demo_locked = true
	_demo_locomotion_speed = 0.0
	match state_name:
		&"idle": _set_state(State.IDLE)
		&"walk", &"patrol":
			_demo_locomotion_speed = walk_speed
			_set_state(State.PATROL)
		&"alert", &"scream": _set_state(State.ALERT)
		&"run", &"chase":
			_demo_locomotion_speed = run_speed
			_set_state(State.CHASE)
		&"attack": _set_state(State.ATTACK)
		&"death", &"dead": _set_state(State.DEAD)
		&"neck_bite": _set_state(State.ATTACK, &"neck_bite")
		&"bite": _set_state(State.ATTACK, &"bite")
		&"bite_alt": _set_state(State.ATTACK, &"bite_alt")
		&"dying": _set_state(State.DEAD, &"dying")
		&"crawl": _set_state(State.PATROL, &"crawl")
		&"running_crawl": _set_state(State.CHASE, &"running_crawl")


func release_demo_lock() -> void:
	_demo_locked = false
	_demo_locomotion_speed = 0.0


## amount = pontos de vida (0..max_health). zone = &"head"/&"body" (opcional; chamadas antigas continuam válidas).
func receive_damage(amount: int, attacker: Node3D = null, zone: StringName = &"") -> void:
	if state == State.DEAD:
		return
	health = maxi(health - maxi(amount, 0), 0)
	_ultima_zona = zone
	if amount > 0:
		hit_taken.emit(zone, amount, attacker)
		_flinch = 1.0
		if health > 0 and Time.get_ticks_msec() - _hurt_ms > 350:
			_hurt_ms = Time.get_ticks_msec()
			_voz(&"zombie_hurt", -3.0, 45.0)
		# acordado pelo tiro: vira para quem atirou (não interrompe ataque/perseguição em curso)
		if health > 0 and is_instance_valid(attacker) and state in [State.IDLE, State.PATROL, State.INVESTIGATE]:
			target = attacker
			_last_known_position = attacker.global_position
			_set_state(State.ALERT)
	if health == 0:
		mortes_emitidas += 1
		if _golpe_dir.length_squared() < 0.0001 and is_instance_valid(attacker):
			_golpe_dir = global_position - attacker.global_position
		_set_state(State.DEAD)
		died.emit(self, zone == &"head", attacker)


## Cabeça ou corpo pela altura do ponto de impacto (mundo) relativa ao pé do zumbi.
func zona_do_impacto(pos: Vector3) -> StringName:
	return &"head" if (pos.y - global_position.y) >= CAPSULA_ALTURA * CABECA_FRACAO else &"body"


## Caminho do projétil/hitscan do Soldier: decide a zona, aplica a tabela da arma, empurra, sangra.
## escala = dano residual da bala (1.0 sem parede atravessada). Retorna {zone, damage, killed}.
func hit_by_bullet(pos: Vector3, dir: Vector3, def: WeaponDef, escala := 1.0, attacker: Node3D = null) -> Dictionary:
	var zona := zona_do_impacto(pos)
	var frac: float = def.zumbi_cabeca if zona == &"head" else def.zumbi_corpo
	var dano := maxi(1, roundi(float(max_health) * frac * escala))
	var flat := Vector3(dir.x, 0.0, dir.z)
	_golpe_dir = flat
	if flat.length_squared() > 0.0001:
		velocity += flat.normalized() * (0.8 + frac * 1.6)   # empurrão curto; o movimento normal o dissipa em ~0,4 s
	receive_damage(dano, attacker, zona)
	var morreu := state == State.DEAD
	var fx: Node = FxManager.shared
	if fx:
		fx.blood(pos, dir, zona == &"head", float(dano))
		if morreu:
			fx.blood_kill(global_position, pos, dir, zona == &"head")
	return {"zone": zona, "damage": dano, "killed": morreu}


## Explosão (granada/C4): dano em pontos por distância; raio/linha de visada decididos por quem chama.
func hit_by_explosion(dano: int, centro: Vector3, attacker: Node3D = null) -> void:
	if state == State.DEAD:
		return
	var dir := global_position - centro
	dir.y = 0.0
	_golpe_dir = dir
	if dir.length_squared() > 0.0001:
		velocity += dir.normalized() * 3.0
	receive_damage(dano, attacker, &"body")
	var fx: Node = FxManager.shared
	if fx:
		var pos := global_position + Vector3.UP * 1.1
		fx.blood(pos, (dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP), false, float(dano))
		if state == State.DEAD:
			fx.blood_kill(global_position, pos, Vector3.UP, false)


## Explosão em área sobre todos os zumbis da árvore: dano linear até raio (visada livre no mundo).
static func explosao(no: Node, centro: Vector3, raio: float, dano_max: int, attacker: Node3D = null) -> int:
	var n := 0
	var space := (no as Node3D).get_world_3d().direct_space_state if no is Node3D else null
	for z in no.get_tree().get_nodes_in_group("zombie"):
		var zz := z as ZombieEnemy
		if zz == null or zz.state == State.DEAD:
			continue
		var d := zz.global_position.distance_to(centro)
		if d > raio:
			continue
		if space:
			var q := PhysicsRayQueryParameters3D.create(centro, zz.global_position + Vector3.UP * 1.0, 1)
			if not space.intersect_ray(q).is_empty():
				continue
		zz.hit_by_explosion(maxi(1, roundi(float(dano_max) * (1.0 - d / raio))), centro, attacker)
		n += 1
	return n


func kill() -> void:
	receive_damage(health)


## Troca o nível de detalhe (chamado pelo ZombieDirector com orçamento por quadro).
func set_lod(novo: int) -> void:
	if novo == lod:
		return
	lod = novo
	_lod_acc = 0.0
	var manual := lod > 0
	for mixer in [_animation_player, _animation_tree]:
		if mixer:
			(mixer as AnimationMixer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if manual else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	if _pose_copy:
		_pose_copy.active = lod < 2
	if _visual_root:
		_visual_root.visible = lod < 2
	set_physics_process(lod < 2)
	if lod == 2:
		velocity = Vector3.ZERO


func _avancar_animacao(dt: float) -> void:
	if _animation_tree and _animation_tree.active:
		_animation_tree.advance(dt)
	elif _animation_player:
		_animation_player.advance(dt)


## move_and_slide com o delta acumulado do LOD médio (move_and_slide usa o passo físico fixo).
func _deslizar() -> void:
	if _lod_escala == 1.0:
		move_and_slide()
		return
	velocity *= _lod_escala
	move_and_slide()
	velocity /= _lod_escala


## O clipe DEAD só tem uma queda (para a frente). Para variar: o corpo gira antes de cair para a direção do golpe
## (tiro de frente = cai de costas, de trás = de bruços, de lado = tomba de lado), com velocidade e tempo diferentes
## (tiro na cabeça = queda seca e rápida). O modelo usa retarget só de rotação: os quadris ficavam na altura de pé e o
## corpo deitado flutuava ~0,9 m; _ajustar_corpo_ao_chao() leva os quadris do modelo aos quadris da animação.
var _morte_velocidade := 1.0


func _variar_morte() -> void:
	if _visual_root == null:
		return
	var d := _golpe_dir
	d.y = 0.0
	var yaw_extra := 0.0
	if d.length_squared() > 0.0001:
		var dl := global_basis.inverse() * d.normalized()
		yaw_extra = atan2(-dl.x, -dl.z)      # o clipe cai para -Z local: gira para cair na direção do golpe
	else:
		yaw_extra = randf_range(-0.6, 0.6)
	yaw_extra += randf_range(-0.25, 0.25)
	_visual_root.rotation.y = PI + yaw_extra
	var cabeca := _ultima_zona == &"head"
	_morte_velocidade = randf_range(1.15, 1.45) if cabeca else randf_range(0.8, 1.2)
	var ti := _target_skeleton.find_bone("Hips") if _target_skeleton else -1
	if ti >= 0:
		_hips_alto = to_local(_target_skeleton.global_transform * _target_skeleton.get_bone_global_pose(ti).origin).y - _visual_root.position.y
	_morte_ativa = true


func _ajustar_corpo_ao_chao() -> void:
	if _source_skeleton == null or _visual_root == null:
		return
	var si := _source_skeleton.find_bone("Hips")
	if si < 0:
		return
	var hs := to_local(_source_skeleton.global_transform * _source_skeleton.get_bone_global_pose(si).origin).y
	_visual_root.position.y = minf(maxf(hs, 0.13) - _hips_alto, 0.0)


func _physics_process(delta: float) -> void:
	if _morte_ativa:
		_ajustar_corpo_ao_chao()
	if _flinch > 0.0 and _visual_root:
		_flinch = maxf(_flinch - delta * 5.0, 0.0)
		_visual_root.rotation.x = -_flinch * 0.12   # recuo curto do tronco; não toca na máquina de estados
	if lod == 1:
		_lod_acc += delta
		_lod_quadro += 1
		if _lod_quadro % LOD1_PASSO != 0:
			return
		delta = _lod_acc
		_lod_acc = 0.0
		_lod_escala = delta / maxf(get_physics_process_delta_time(), 0.0001)
		_avancar_animacao(delta)
	else:
		_lod_escala = 1.0
	_state_time += delta
	_attack_time = maxf(_attack_time - delta, 0.0)
	_repath_time -= delta
	_sense_timer -= delta
	_groan_timer -= delta
	if state == State.DEAD:
		velocity = Vector3.ZERO
		return
	if _demo_locked:
		velocity = Vector3.ZERO
		_update_locomotion_blend(delta, _demo_locomotion_speed)
		return
	if _groan_timer <= 0.0:
		if state == State.CHASE:
			_voz(&"zombie_run", -3.0, 55.0)
			_groan_timer = randf_range(2.2, 4.2)
		else:
			_voz(&"zombie_groan", -7.0, 38.0)
			_groan_timer = randf_range(4.5, 9.5)
	if _sense_timer <= 0.0:
		_sense_timer = 0.22
		var visible_target := _find_target()
		if is_instance_valid(visible_target):
			if target != visible_target and state in [State.IDLE, State.PATROL, State.INVESTIGATE]:
				target = visible_target
				_set_state(State.ALERT)
			_time_without_sight = 0.0
			_last_known_position = visible_target.global_position
		elif state in [State.CHASE, State.ATTACK]:
			_time_without_sight += _sense_timer + 0.22
			if is_instance_valid(target) and _flat_distance_to(target) >= lose_range:
				_time_without_sight = 6.0
			if _time_without_sight >= 6.0:
				target = null
				_set_state(State.INVESTIGATE)
	if state == State.IDLE and _state_time >= _idle_duration:
		_set_state(State.PATROL)
	if state == State.ALERT:
		_face_target(delta)
		if _state_time >= _animation_length(&"scream"):
			_set_state(State.CHASE if is_instance_valid(target) else State.INVESTIGATE)
	elif state == State.ATTACK:
		if _state_time >= _animation_length(&"attack"):
			_set_state(State.CHASE)
	if state in [State.PATROL, State.INVESTIGATE, State.CHASE, State.ATTACK]:
		_move_toward_target(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		velocity.y -= 20.0 * delta
		_deslizar()
	_update_locomotion_blend(delta)


func _update_locomotion_blend(delta: float, forced_speed: float = -1.0) -> void:
	if _animation_tree == null:
		return
	var speed := forced_speed
	if speed < 0.0:
		speed = Vector2(velocity.x, velocity.z).length()
	# A real stop is an animation state, not a tiny movement blend. CharacterBody3D
	# deceleration leaves a little residual velocity as it settles; feeding that
	# directly into the BlendSpace makes feet twitch/slide after the body stopped.
	# Use hysteresis while walking so the blend has a clean, stable rest pose.
	if forced_speed >= 0.0:
		_locomotion_is_moving = forced_speed >= locomotion_resume_threshold
	else:
		if not _locomotion_is_moving and speed >= locomotion_resume_threshold:
			_locomotion_is_moving = true
		elif _locomotion_is_moving and speed <= locomotion_stop_threshold:
			_locomotion_is_moving = false
	if state in [State.IDLE, State.ALERT, State.ATTACK, State.DEAD]:
		speed = 0.0
	elif not _locomotion_is_moving:
		speed = 0.0
	if _animation_tree.active:
		speed = clampf(speed, 0.0, 3.2)
		_animation_tree.set(&"parameters/Locomotion/blend_position", speed)
		_animation_tree.set(&"parameters/TimeScale/scale", _escala_tempo_locomocao(speed))


## Escala de tempo da animação = velocidade real / velocidade de passada da animação no mesmo ponto do blend,
## para os pés acompanharem o chão (sem patinar). Parado/transição para idle: 1.
func _escala_tempo_locomocao(speed: float) -> float:
	if speed < 0.05:
		return 1.0
	var k := maxf(_fitted_visual_height, 0.5) / PASSADA_REF_ALTURA
	var v_walk := PASSADA_WALK_REF * k
	var v_run := PASSADA_RUN_REF * k
	var passada: float
	if speed <= BLEND_WALK:
		passada = v_walk * (speed / BLEND_WALK)   # blend idle->walk: a passada cresce com o peso do walk
	elif speed >= BLEND_RUN:
		passada = v_run
	else:
		passada = lerpf(v_walk, v_run, (speed - BLEND_WALK) / (BLEND_RUN - BLEND_WALK))
	return clampf(speed / maxf(passada, 0.05), 0.4, 1.6)


func _move_toward_target(delta: float) -> void:
	var destination: Vector3
	var speed := walk_speed
	if state == State.PATROL:
		_patrol_time -= delta
		if _patrol_time <= 0.0:
			_choose_patrol_destination()
		destination = _patrol_destination
		if global_position.distance_to(destination) < 0.65:
			_patrol_time = 0.0
			_set_state(State.IDLE)
			return
	elif state == State.INVESTIGATE:
		destination = _last_known_position
		speed = run_speed * 0.6   # vai conferir o barulho em passo apressado
		if global_position.distance_to(destination) < 1.25:
			target = null
			_set_state(State.IDLE)
			return
	elif is_instance_valid(target):
		destination = target.global_position
		speed = run_speed
		if _flat_distance_to(target) <= attack_range:
			if state != State.ATTACK:
				_set_state(State.ATTACK)
			_attack_target()
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			velocity.y -= 20.0 * delta
			_deslizar()
			return
	else:
		_set_state(State.IDLE)
		return
	if _navigation and _navigation.get_navigation_map().is_valid():
		if _repath_time <= 0.0:
			_navigation.target_position = destination
			_repath_time = 0.35 if state == State.CHASE else 1.2
		var next_point := _navigation.get_next_path_position()
		# A valid NavigationServer map can still contain no baked regions. In that
		# case get_next_path_position() reports the agent's current position, and
		# replacing the real destination with it silently freezes every zombie.
		# Follow a nav path only when it actually advances away from this agent.
		if not _navigation.is_navigation_finished() and _flat_distance_between(next_point, global_position) > 0.2:
			destination = next_point
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.02:
		direction = direction.normalized()
		direction = _steer(direction, speed, delta, _flat_distance_between(destination, global_position))
		var desired_yaw := atan2(-direction.x, -direction.z)
		rotation.y = rotate_toward(rotation.y, desired_yaw, turn_speed * delta)
		velocity.x = move_toward(velocity.x, direction.x * speed, 9.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 9.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	velocity.y -= 20.0 * delta
	_deslizar()
	_verificar_progresso(delta, speed, direction)
	if state == State.PATROL and direction.length_squared() > 0.02:
		if Vector2(global_position.x - _last_patrol_position.x, global_position.z - _last_patrol_position.z).length() < 0.015:
			_stuck_time += delta
			if _stuck_time > 1.4:
				_choose_patrol_destination()
		else:
			_stuck_time = 0.0
		_last_patrol_position = global_position


func _raio(from: Vector3, dir: Vector3, alcance: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * alcance, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and (r["normal"] as Vector3).y > 0.7:
		return {}   # rampa/chão caminhável
	return r


func _sondar(dir: Vector3) -> void:
	var base := global_position
	var dists := {"c": SONDA_ALCANCE, "e": SONDA_ALCANCE, "d": SONDA_ALCANCE}
	var alto_c := false
	var baixo_c := false
	var hit_c: Dictionary = {}
	_sonda_normal_c = Vector3.ZERO
	_sonda_porta = null
	var angs := {"c": 0.0, "e": SONDA_ANGULO, "d": -SONDA_ANGULO}
	for k in angs:
		var d: Vector3 = dir.rotated(Vector3.UP, angs[k])
		for hgt in SONDA_ALTURAS:
			var r := _raio(base + Vector3.UP * hgt, d, SONDA_ALCANCE)
			if r.is_empty():
				continue
			var dist := base.distance_to(Vector3(r["position"].x, base.y, r["position"].z))
			dists[k] = minf(dists[k], dist)
			if k == "c":
				if hgt > 1.0:
					alto_c = true
				else:
					baixo_c = true
				if hit_c.is_empty() or dist < hit_c["d"]:
					hit_c = {"d": dist, "n": r["normal"], "p": r["position"], "col": r["collider"]}
				_sonda_normal_c = Vector3(r["normal"].x, 0.0, r["normal"].z).normalized() if hgt > 1.0 or _sonda_normal_c == Vector3.ZERO else _sonda_normal_c
	_sonda_livre = dists
	_sonda_baixo = false
	if not hit_c.is_empty():
		var n: Vector3 = hit_c["n"]
		if _sonda_normal_c == Vector3.ZERO:
			_sonda_normal_c = Vector3(n.x, 0.0, n.z).normalized()
		var no: Node = hit_c["col"] as Node
		while no != null and not no.is_in_group("porta"):
			no = no.get_parent()
		_sonda_porta = no
		if baixo_c and not alto_c and no == null:
			# mede o topo do obstáculo com um raio vertical logo depois da face
			var topo_from: Vector3 = hit_c["p"] + dir * 0.3 + Vector3.UP * 2.0
			var rt := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(topo_from, topo_from + Vector3.DOWN * 2.2, 1))
			if not rt.is_empty() and rt["position"].y - base.y <= SALTO_ALTURA_MAX:
				_sonda_baixo = true


## Devolve a direção horizontal desejada já desviada de obstáculos (ou a original quando livre).
func _steer(dir: Vector3, speed: float, delta: float, dist_meta: float = 99.0) -> Vector3:
	_sonda_t -= delta
	_lado_t = maxf(_lado_t - delta, 0.0)
	_salto_cd = maxf(_salto_cd - delta, 0.0)
	_porta_cd = maxf(_porta_cd - delta, 0.0)
	if _lado_t <= 0.0 and not _seguindo:
		_lado = 0.0
	if _recuo_t > 0.0:
		_recuo_t -= delta
		var rn := _sonda_normal_c if _sonda_normal_c != Vector3.ZERO else -dir
		var tg := Vector3(-rn.z, 0.0, rn.x) * (_lado if _lado != 0.0 else 1.0)
		return (rn * 0.6 + tg).normalized()
	if _seguindo:
		var seg := _contornar(dir, dist_meta, delta)
		if seg != Vector3.ZERO:
			return seg
	if _sonda_t <= 0.0:
		_sonda_t = 0.07
		_sondar(dir)
	var dc: float = _sonda_livre["c"]
	var out := dir
	# repulsão suave de paredes laterais (cerca/muro raspando)
	var rep := Vector3.ZERO
	if _sonda_livre["e"] < SONDA_ALCANCE:
		rep += dir.rotated(Vector3.UP, -PI * 0.5) * (1.0 - _sonda_livre["e"] / SONDA_ALCANCE)
	if _sonda_livre["d"] < SONDA_ALCANCE:
		rep += dir.rotated(Vector3.UP, PI * 0.5) * (1.0 - _sonda_livre["d"] / SONDA_ALCANCE)
	if dc >= SONDA_ALCANCE:
		if rep != Vector3.ZERO and _lado != 0.0:
			out = (dir + rep * 0.7).normalized()
		return out
	# bloqueado à frente
	if _sonda_porta != null and dc < 1.2 and _porta_cd <= 0.0 and not bool(_sonda_porta.get("aberta")) and state != State.PATROL:
		_sonda_porta.call("alternar")   # zumbi abre a porta (empurra) e passa
		_porta_cd = 2.0
		return dir
	if _sonda_baixo:
		if dc < 1.0 and _salto_cd <= 0.0 and is_on_floor():
			velocity.y = SALTO_V
			_salto_cd = 0.9
			contagem_saltos += 1
		return dir
	var n := _sonda_normal_c if _sonda_normal_c != Vector3.ZERO else -dir
	if _lado == 0.0:
		var t_pos := Vector3(-n.z, 0.0, n.x)
		var score := t_pos.dot(dir) * 1.0 + (float(_sonda_livre["e"]) - float(_sonda_livre["d"])) * 0.15 * (t_pos.dot(dir.rotated(Vector3.UP, PI * 0.5)))
		_lado = 1.0 if score >= 0.0 else -1.0
	_lado_t = 3.0
	_seguindo = true
	_seguindo_t = 0.0
	_n_parede = n
	_dist_impacto = dist_meta
	var tang := Vector3(-n.z, 0.0, n.x) * _lado
	var aperto := clampf(1.0 - dc / SONDA_ALCANCE, 0.0, 1.0)
	return (tang + n * (0.25 + 0.5 * aperto) + rep * 0.4).normalized()


func _bloqueio(dirv: Vector3, alcance: float) -> Dictionary:
	var melhor: Dictionary = {}
	for hgt in SONDA_ALTURAS:
		var r := _raio(global_position + Vector3.UP * hgt, dirv, alcance)
		if not r.is_empty() and (melhor.is_empty() or r["position"].distance_to(global_position) < melhor["position"].distance_to(global_position)):
			melhor = r
	return melhor


## Contorno de parede (Bug2) com lado memorizado. Devolve ZERO quando o modo termina (linha até a meta livre e mais perto).
func _contornar(dir: Vector3, dist_meta: float, delta: float) -> Vector3:
	_seguindo_t += delta
	_lado_t = 3.0
	if _seguindo_t > 14.0 or dist_meta < 2.0:
		_seguindo = false
		return Vector3.ZERO
	if _seguindo_t > 0.4 and _bloqueio(dir, minf(dist_meta - 1.0, 18.0)).is_empty() and _bloqueio(dir.rotated(Vector3.UP, 0.3), 1.5).is_empty() and _bloqueio(dir.rotated(Vector3.UP, -0.3), 1.5).is_empty():
		_seguindo = false
		return Vector3.ZERO
	var tang := Vector3(-_n_parede.z, 0.0, _n_parede.x) * _lado
	var fr := _bloqueio(tang, 1.0)
	if not fr.is_empty():
		# parede à frente (quina interna): gira para a nova parede
		var nn := Vector3(fr["normal"].x, 0.0, fr["normal"].z)
		if nn.length_squared() > 0.01:
			_n_parede = nn.normalized()
			tang = Vector3(-_n_parede.z, 0.0, _n_parede.x) * _lado
		return (tang + _n_parede * 0.3).normalized()
	var lado_p := _bloqueio(-_n_parede, 1.1)
	if not lado_p.is_empty():
		var nn2 := Vector3(lado_p["normal"].x, 0.0, lado_p["normal"].z)
		if nn2.length_squared() > 0.01:
			_n_parede = nn2.normalized()
		var d: float = global_position.distance_to(Vector3(lado_p["position"].x, global_position.y, lado_p["position"].z))
		var tang2 := Vector3(-_n_parede.z, 0.0, _n_parede.x) * _lado
		var empurra := clampf((0.7 - d) * 1.5, -0.5, 0.6)   # mantém ~0,7 m da parede
		return (tang2 + _n_parede * empurra).normalized()
	# sem parede ao lado: quina externa, dá a volta
	return (tang * 0.6 - _n_parede * 0.9).normalized()


## Detecção de travamento: progresso < 30% do esperado por 0,8 s -> troca de lado, recua e tenta saltar.
func _verificar_progresso(delta: float, speed: float, direction: Vector3) -> void:
	if direction.length_squared() < 0.02 or not is_on_floor() or _recuo_t > 0.0:
		_prog_t = 0.0
		_prog_dist = 0.0
		_prog_pos = global_position
		return
	_prog_t += delta
	_prog_dist = _flat_distance_between(global_position, _prog_pos)
	if _prog_t < 0.8:
		return
	var esperado := speed * 0.8
	if _prog_dist < esperado * 0.3:
		contagem_travamentos += 1
		_lado = -_lado if _lado != 0.0 else 1.0
		_lado_t = 3.0
		_recuo_t = 0.5
		_dist_impacto = 1.0e6   # recomeça o contorno do outro lado sem exigir ganho de distância
		if _salto_cd <= 0.0:
			velocity.y = SALTO_V
			_salto_cd = 0.9
			contagem_saltos += 1
	_prog_t = 0.0
	_prog_pos = global_position


func _flat_distance_between(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()


func _attack_target() -> void:
	if _attack_time > 0.0 or not is_instance_valid(target):
		return
	_attack_time = attack_cooldown
	if target is Soldier:
		(target as Soldier).take_damage(float(attack_damage), null, null, "chest", (target.global_position - global_position).normalized())
	elif target.has_method("take_damage"):
		target.call("take_damage", attack_damage)
	elif target.has_method("receive_damage"):
		target.call("receive_damage", attack_damage, self)
	attacked.emit(target, attack_damage)


func _face_target(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.02:
		rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), turn_speed * delta)


func _find_target() -> Node3D:
	_registrar_soldados()
	var best: Node3D = target if _is_valid_target(target) and _can_see_target(target) else null
	var best_distance := _flat_distance_to(best) if best else detection_range
	for node in get_tree().get_nodes_in_group("zombie_targets"):
		if not node is Node3D or node == self or not _is_valid_target(node):
			continue
		var candidate := node as Node3D
		var distance := _flat_distance_to(candidate)
		if distance < best_distance and _can_see_target(candidate):
			best = candidate
			best_distance = distance
	return best


func _is_valid_target(node: Node3D) -> bool:
	if not is_instance_valid(node) or node == self:
		return false
	return not node is Soldier or (node as Soldier).alive


func _can_see_target(candidate: Node3D) -> bool:
	if not _is_valid_target(candidate):
		return false
	var offset := candidate.global_position - global_position
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	var distance := flat_offset.length()
	if absf(offset.y) > vertical_sight_limit:
		return false
	if distance <= hearing_range:   # perto: ouve os passos, em qualquer direção (atrás também)
		return true
	if distance > detection_range * Clima.fator_visao_zumbi():   # noite/chuva/nevoeiro encurtam a visão
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		var cosine_limit := cos(deg_to_rad(field_of_view_degrees * 0.5))
		if forward.normalized().dot(flat_offset / distance) < cosine_limit:
			return false
	var from := global_position + Vector3.UP * 1.35
	var to := candidate.global_position + Vector3.UP * 1.15
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	return collider == candidate or (collider is Node and (candidate.is_ancestor_of(collider) or collider.is_ancestor_of(candidate)))


## Soldados da partida são alvos (também para zumbis criados fora do ZombieDirector, ex.: testes).
func _registrar_soldados() -> void:
	var m = Game.current_match
	if m == null or not is_instance_valid(m) or not "soldiers" in m:
		return
	for sd in m.soldiers:
		if is_instance_valid(sd) and not sd.is_in_group("zombie_targets"):
			sd.add_to_group("zombie_targets")


func _choose_patrol_destination() -> void:
	_patrol_time = randf_range(48.0, 70.0)
	var angle := randf_range(-PI, PI)
	_patrol_direction = Vector3(sin(angle), 0.0, cos(angle))
	_patrol_destination = global_position + _patrol_direction * randf_range(10.0, 22.0)
	_stuck_time = 0.0


func _play_groan(volume_db: float = -15.0) -> void:
	_voz(&"zombie_groan", volume_db)


## Voz do zumbi (sons CC0 do OpenGameArt preparados por tools/prep_audio_net.py): groan = ocioso/patrulha,
## alert = viu o jogador, run = rosnado correndo, attack = golpe, hurt = levou tiro, die = morte.
## Posicional na altura da cabeça; alcance proporcional ao tipo para ouvir de longe a horda e perto o golpe.
func _voz(id: StringName, volume_db := -6.0, alcance := 40.0) -> void:
	if not Audio.has_sound(String(id)):
		return
	Audio.play_at(String(id), global_position + Vector3.UP * 1.5, {
		"volume_db": volume_db, "pitch": randf_range(0.9, 1.1) * (1.05 - float(_variant_index) * 0.01),
		"pitch_var": 0.04, "unit_size": 7.0, "max_distance": alcance, "bus": "SFX"})


func _on_world_noise(pos: Vector3, radius: float, source: Node) -> void:
	if state in [State.DEAD, State.CHASE, State.ATTACK, State.ALERT] or source == self:
		return
	# tiros têm raio de 400–950 m (o mapa inteiro): zumbi atende até OUVE_TIRO_MAX (horda local, física sob controle)
	if global_position.distance_to(pos) > minf(radius, OUVE_TIRO_MAX):
		return
	_last_known_position = pos
	_registrar_soldados()
	if source is Node3D and source.is_in_group("zombie_targets") and _is_valid_target(source):
		# tiro/barulho de um alvo: sabe de onde veio -> grita e corre atrás (perde se ficar 6 s sem ver)
		target = source
		_time_without_sight = 0.0
		_set_state(State.ALERT)
		return
	_set_state(State.INVESTIGATE)


func _flat_distance_to(node: Node3D) -> float:
	var delta := node.global_position - global_position
	delta.y = 0.0
	return delta.length()


func _set_state(next_state: State, clip_override: StringName = &"") -> void:
	if _has_entered_state and state == next_state and clip_override.is_empty() and _animation_player and _animation_player.is_playing():
		return
	_has_entered_state = true
	state = next_state
	_state_time = 0.0
	match state:
		State.IDLE, State.PATROL, State.INVESTIGATE, State.CHASE:
			if clip_override in [&"crawl", &"running_crawl"]:
				_animation_tree.active = false
				_play(clip_override, true)
			else:
				_animation_tree.active = true
		State.ALERT:
			_animation_tree.active = false
			_play(&"scream", false)
			_voz(&"zombie_alert", -1.0, 70.0)
		State.ATTACK:
			_attack_animation = clip_override if not clip_override.is_empty() else _attack_animation
			_animation_tree.active = false
			_play(_attack_animation, false)
			_voz(&"zombie_attack", -2.0, 45.0)
		State.DEAD:
			health = 0
			target = null
			collision_layer = 0
			if _hit_area:
				_hit_area.collision_layer = 0
			if _visual_root:
				_visual_root.rotation.x = 0.0
			get_node("BodyCollider").set_deferred("disabled", true)
			_death_animation = clip_override if not clip_override.is_empty() else _death_animation
			_animation_tree.active = false
			_variar_morte()
			_voz(&"zombie_die", -1.0, 55.0)
			_play(_death_animation, false)
			if _animation_player:
				_animation_player.speed_scale = _morte_velocidade
	if state == State.IDLE:
		_idle_duration = randf_range(1.8, 3.2)
	state_changed.emit(StringName(State.keys()[state].to_lower()))


func _play(animation_name: StringName, should_loop: bool) -> void:
	if not _animation_player or not _animation_player.has_animation(animation_name):
		return
	_animation_player.speed_scale = 1.0
	var animation := _animation_player.get_animation(animation_name)
	if should_loop and animation.loop_mode == Animation.LOOP_NONE:
		push_warning("Scary Zombie clip is not configured to loop: " + String(animation_name))
	_animation_player.play(animation_name, 0.15)


func _animation_length(animation_name: StringName) -> float:
	if _animation_player and _animation_player.has_animation(animation_name):
		return _animation_player.get_animation(animation_name).length
	return 0.85 if animation_name == &"scream" else 0.65
