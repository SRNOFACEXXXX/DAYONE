class_name BodyModel
extends Node3D
## Third-person visual of a soldier: animated character (AnimationTree built in code from named clips),
## weapon in the right hand, aim pitch on the spine, death animation. Falls back to a simple mannequin.

const CHAR_PATHS := ["res://assets/models/characters/terrorist.glb", "res://assets/models/characters/counter.glb"]
const OFFSET_PATHS := ["res://assets/models/characters/terrorist_weapon_offsets.json", "res://assets/models/characters/counter_weapon_offsets.json"]
## PONTO DE CONFIGURAÇÃO do modelo: no modo sobrevivência todos (jogador e bots) usam o soldado de docs/ref/personagem.jpg
## (tools/build_soldado.py). Para voltar aos modelos por time (CS), ponha SOLDIER_FOR_ALL = false.
const SOLDIER_PATH := "res://assets/models/characters/soldado.glb"
const BLOOD_SPLAT := preload("res://fx/textures/blood_splat.png")   # ferida por tiro: antes load() a cada ferida
const SOLDIER_OFFSETS := "res://assets/models/characters/soldado_weapon_offsets.json"
static var SOLDIER_FOR_ALL := true
const UPPER_BONES := ["Spine", "Spine1", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"LeftHandIndex1", "LeftHandIndex2", "LeftHandMiddle1", "LeftHandMiddle2", "LeftHandPinky1", "LeftHandPinky2",
	"LeftHandRing1", "LeftHandRing2", "LeftHandThumb1", "LeftHandThumb2", "RightHandIndex1", "RightHandIndex2",
	"RightHandMiddle1", "RightHandMiddle2", "RightHandPinky1", "RightHandPinky2", "RightHandRing1", "RightHandRing2",
	"RightHandThumb1", "RightHandThumb2", "RightHandProp", "LeftHandProp"]

## Pegada em 3ª pessoa (espaço da arma: -Z = cano, +Y = cima, +X = direita). r/l = ponto da palma;
## rf/lf = direção dos dedos (pulso -> nós); rp/lp = para onde a palma olha; anchor = arma relativa ao pescoço na mira.
## Pegas das armas novas (wf/*.glb, origem no centro do comprimento; r/l = mão direita/esquerda no espaço da arma, medidas nas
## vistas de tools/vista_arma.py). anchor = origem da arma no quadro de mira; escolhida para a mão direita ficar onde já ficava.
const GRIPS := {
	&"ak47": {"anchor": Vector3(0.12, -0.185, -0.325), "r": Vector3(0, 0.05, 0.15), "rf": Vector3(0, -0.55, -0.83), "rp": Vector3(-1, 0, 0),
		"l": Vector3(0, 0.06, -0.18), "lf": Vector3(0.3, 0.2, -0.93), "lp": Vector3(0.45, 0.89, 0)},
	&"m4": {"anchor": Vector3(0.12, -0.048, -0.314), "r": Vector3(0, -0.092, 0.144), "rf": Vector3(0, -0.55, -0.83), "rp": Vector3(-1, 0, 0),
		"l": Vector3(0, -0.045, -0.15), "lf": Vector3(0.3, 0.2, -0.93), "lp": Vector3(0.45, 0.89, 0)},
	&"mosin": {"anchor": Vector3(0.12, -0.163, -0.613), "r": Vector3(0, 0.013, 0.228), "rf": Vector3(0, -0.6, -0.8), "rp": Vector3(-1, 0, 0),
		"l": Vector3(0, 0.02, -0.08), "lf": Vector3(0.3, 0.2, -0.93), "lp": Vector3(0.45, 0.89, 0)},
	&"uzi": {"anchor": Vector3(0.12, -0.055, -0.235), "r": Vector3(0, -0.085, 0.065), "rf": Vector3(0, -0.55, -0.83), "rp": Vector3(-1, 0, 0), "l": Vector3(0, 0.0, -0.081), "lf": Vector3(0.3, 0.2, -0.93), "lp": Vector3(0.45, 0.89, 0)},
	&"m249": {"anchor": Vector3(0.12, -0.011, -0.366), "r": Vector3(0, -0.129, 0.196), "rf": Vector3(0, -0.55, -0.83), "rp": Vector3(-1, 0, 0), "l": Vector3(0, -0.02, -0.133), "lf": Vector3(0.3, 0.2, -0.93), "lp": Vector3(0.45, 0.89, 0)},
	&"m107": {"anchor": Vector3(0.12, 0.004, -0.494), "r": Vector3(0, -0.144, 0.324), "rf": Vector3(0, -0.55, -0.83), "rp": Vector3(-1, 0, 0), "l": Vector3(0, 0.0, -0.284), "lf": Vector3(0.3, 0.2, -0.93), "lp": Vector3(0.45, 0.89, 0)},
	# faca em guarda: lâmina à frente/direita, cabo (z -0,05..+0,07) na palma; mão esquerda livre, recolhida e meio fechada
	&"knife": {"anchor": Vector3(0.2, -0.33, -0.3), "r": Vector3(0, 0, 0.006), "rf": Vector3(0, -1, 0.15), "rp": Vector3(-1, 0, 0),
		"lfree": Vector3(-0.1, -0.3, -0.16), "lf": Vector3(0.35, -0.3, -0.88), "lp": Vector3(0.8, 0.2, 0.2), "lcurl": 0.5,
		"wrot": Vector3(deg_to_rad(10.0), deg_to_rad(-25.0), 0.0)},   # lâmina 25° para fora e 10° para cima: visível de frente
	&"glock": {"anchor": Vector3(0.03, -0.08, -0.431), "r": Vector3(0, -0.07, 0.076), "rf": Vector3(0, -0.45, -0.89), "rp": Vector3(-1, 0, 0),
		"l": Vector3(-0.035, -0.085, 0.08), "lf": Vector3(0.35, -0.45, -0.82), "lp": Vector3(1, 0.1, 0)},
	&"usp": {"anchor": Vector3(0.03, -0.15, -0.476), "r": Vector3(0, 0.0, 0.121), "rf": Vector3(0, -0.45, -0.89), "rp": Vector3(-1, 0, 0),
		"l": Vector3(-0.035, -0.015, 0.125), "lf": Vector3(0.35, -0.45, -0.82), "lp": Vector3(1, 0.1, 0)},
}

## Escala do modelo de mundo em 3ª pessoa (o GRIP da arma é descrito já na escala reduzida).
const WEAPON_SCALE := {}

var soldier: Soldier
var ik: ArmsIK
var _vis_yaw := 0.0
var _leg_yaw := 0.0
var _prev_vel := Vector3.ZERO
var _lean := Vector2.ZERO
var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var tree: AnimationTree
var hand: Node3D
var weapon_node: Node3D
var weapon_id: StringName = &""
var first_person := false
var dead := false
var _loco := Vector2.ZERO
## Velocidade animada em espaço local (m/s). Mantém inércia visual por alguns passos
## depois que a física começa a frear, evitando o corte direto de corrida para idle.
var _anim_velocity := Vector2.ZERO
var _air := 0.0
var _crouch := 0.0
var _spine_idx := -1
var _spine1_idx := -1
var _aim_pitch := 0.0
var _mannequin := false
var _fire_flash := 0.0
var _anim_prefix := ""
var _offsets: Dictionary = {}
var _hold_yaw := 0.0
var _hold_yaw_target := 0.0
var _upper_tracks: Array[NodePath] = []


## Offsets de arma (JSON): só Dictionary é aceito; texto inválido ou null vira {} em vez de quebrar _offsets (tipado).
static func ler_offsets(texto: String) -> Dictionary:
	var j: Variant = JSON.parse_string(texto)
	return j if j is Dictionary else {}


func setup(s: Soldier) -> void:
	soldier = s
	s.weapon_switched.connect(_on_weapon)
	s.fired.connect(_on_fired)
	s.reload_started.connect(_on_reload)
	s.knife_swung.connect(func(_h: bool, _x: bool) -> void: _one_shot("knife"))
	rebuild(s)


func rebuild(s: Soldier) -> void:
	_vis_yaw = s.yaw
	if model:
		model.queue_free()
	model = null
	skeleton = null
	anim_player = null
	tree = null
	hand = null
	weapon_node = null
	weapon_id = &""
	var use_soldier := SOLDIER_FOR_ALL and ResourceLoader.exists(SOLDIER_PATH)
	var path: String = SOLDIER_PATH if use_soldier else CHAR_PATHS[s.team]
	personagem = false
	var _t0 := Time.get_ticks_usec()
	var boneco: Node3D = _boneco_do_jogador(s)
	var _t1 := Time.get_ticks_usec()
	if boneco or ResourceLoader.exists(path):
		if boneco:
			model = boneco
			personagem = true
		else:
			model = load(path).instantiate()
		model.rotation.y = PI          # o glTF olha para +Z; o soldado olha para -Z
		add_child(model)
		skeleton = _find(model, "Skeleton3D") as Skeleton3D
		anim_player = _find(model, "AnimationPlayer") as AnimationPlayer
		var _t2 := Time.get_ticks_usec()
		if personagem and anim_player:
			_remapear_animacoes(anim_player)
		var _t3 := Time.get_ticks_usec()
		_offsets = {}
		var op: String = OFFSET_PATHS[s.team]
		if FileAccess.file_exists(op):
			_offsets = ler_offsets(FileAccess.get_file_as_string(op))
		if skeleton and skeleton.find_bone("RightHandProp") >= 0:
			var ba := BoneAttachment3D.new()
			ba.name = "RightHandAttach"
			ba.bone_name = "RightHandProp"
			skeleton.add_child(ba)
			hand = ba
		if skeleton and skeleton.find_bone("LeftHandProp") >= 0:
			var bl := BoneAttachment3D.new()
			bl.name = "LeftHandAttach"
			bl.bone_name = "LeftHandProp"
			skeleton.add_child(bl)
		if skeleton:
			# pontos de hitbox presos aos ossos (a hitbox da cabeça segue a cabeça desenhada, inclusive agachado/correndo)
			for bn in ["Head", "Spine1", "Neck"]:
				if skeleton.find_bone(bn) >= 0:
					var hb_att := BoneAttachment3D.new()
					hb_att.name = "HB_" + bn
					hb_att.bone_name = bn
					skeleton.add_child(hb_att)
			ik = ArmsIK.new()
			ik.name = "ArmsIK"
			skeleton.add_child(ik)
			ik.setup(skeleton)
			ik.body = self
			ik.soldier = s
			_spine_idx = skeleton.find_bone("Spine")
			_spine1_idx = skeleton.find_bone("Spine1")
		if anim_player:
			_set_loops()
			var _t4 := Time.get_ticks_usec()
			_build_tree()
			if Game.test_args.has("medir_corpo"):
				print("CORPO_MS boneco=%.1f add=%.1f remap=%.1f loops=%.1f arvore=%.1f" % [(_t1 - _t0) / 1000.0, (_t2 - _t1) / 1000.0,
					(_t3 - _t2) / 1000.0, (_t4 - _t3) / 1000.0, (Time.get_ticks_usec() - _t4) / 1000.0])
		_mannequin = false
	else:
		model = _build_mannequin(s.team)
		add_child(model)
		_mannequin = true
	for n in _all_geometry(model):
		n.layers = 2
	set_first_person(first_person)
	_on_weapon(s.current_def())


# ------------------------------------------------------------------ personagem do criador (jogador local)
## Jogador local usa o boneco montado no criador (user://personagem.json, dayone_base.glb). O esqueleto do pack é o
## MESMO do soldado.glb (44 ossos, mesmo descanso), então hitboxes, IK de mira e pegas das armas valem igual.
## Bots continuam com o soldado. Desligar: BodyModel.PERSONAGEM_JOGADOR = false.
static var PERSONAGEM_JOGADOR := true
var personagem := false
## nome usado pelo corpo -> clipe do dayone_base.glb (locomoção, pulo, morte remapeados para o pack novo)
const MAPA_DAYONE := {
	"idle": "Idle_Breathing", "walk_f": "Walk_Forward", "walk_b": "Walk_Backward", "walk_l": "Strafe_Left",
	"walk_r": "Strafe_Right", "run_f": "Run_Forward", "run_b": "run(back)", "run_l": "Run_Left", "run_r": "Run_Right",
	"crouch_f": "Crouch_Walk_Forward", "crouch_b": "Crouch_Walk_Backward", "crouch_l": "Crouch_Walk_Left",
	"crouch_r": "Crouch_Walk_Right", "jump": "Jump", "death": "Death_Backward", "death_head": "Death_Forward",
}
## Sem equivalente no pack: vêm do soldado.glb (mesmo esqueleto), com o caminho das trilhas trocado.
## Inclui as poses de segurar arma (hold_*), que definem a pose de rifle atual, e a corrida Adult_Run (sprint_a).
const DO_SOLDADO := ["hold_rifle", "hold_pistol", "hold_knife", "crouch_idle", "fire", "reload", "knife", "plant", "sprint_a"]
static var _lib_dayone: AnimationLibrary


func _boneco_do_jogador(s: Soldier) -> Node3D:
	if not PERSONAGEM_JOGADOR or s == null or not s.is_local:
		return null
	var d := {} if String(Game.test_args.get("personagem", "")) == "padrao" else CriadorPersonagem.carregar_dados()
	if d.is_empty() and not Game.test_args.has("personagem"):
		return null
	dados_personagem = d
	var n := CriadorPersonagem.boneco_jogo(d)
	# partida pré-montada: o jogador ainda pode trocar de peça no criador, então mantém todas até atualizar_personagem()
	var pre: bool = s.match_ref != null and s.match_ref.has_method("pre_montando") and s.match_ref.pre_montando()
	if n and not pre:
		_podar_pecas(n)
	return n


## Libera as malhas skinned do pack que não foram escolhidas (o glb traz as 30; só ~8 ficam ligadas).
static func _podar_pecas(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).visible:
			mi.get_parent().remove_child(mi)
			mi.queue_free()


## Em 1ª pessoa o corpo só projeta sombra: peças pequenas (rosto, cabelo, bigode, óculos, luvas, calçados, meias)
## não mudam a sombra e custam skinning + passe de sombra. Ficam ligados só corpo, tronco, pernas e chapéu.


func _pecas_1p(on: bool) -> void:
	if not personagem or model == null:
		return
	var manter := {"Body_010": true}
	for slot in ["tronco", "pernas", "cabeca"]:
		var m := String(dados_personagem.get(slot, ""))
		if m != "":
			manter[m] = true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var nome := String(mi.name)
		if on:
			if not manter.has(nome) and (mi as MeshInstance3D).visible:
				(mi as MeshInstance3D).visible = false
				mi.set_meta("oculta_1p", true)
		elif mi.has_meta("oculta_1p"):
			(mi as MeshInstance3D).visible = true
			mi.remove_meta("oculta_1p")


var dados_personagem := {}


## Partida pré-montada antes do CONFIRMAR: reaplica peças/pele do json salvo agora (barato: só visible + material).
## Se o corpo ainda era o soldado (json não existia na montagem), reconstrói.
func atualizar_personagem() -> void:
	if soldier == null or not soldier.is_local or not PERSONAGEM_JOGADOR:
		return
	if not personagem:
		if not CriadorPersonagem.carregar_dados().is_empty():
			rebuild(soldier)
		return
	var d := CriadorPersonagem.carregar_dados()
	if d.is_empty():
		return
	dados_personagem = d
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.remove_meta("oculta_1p")
	CriadorPersonagem.aplicar_dados(model, d)
	CriadorPersonagem.aplicar_pele(model, Color(String(d.get("pele_cor", "dba37a"))))
	_podar_pecas(model)
	set_first_person(first_person)


## Retrato do inventário (ou qualquer palco): cópia do boneco do jogador em idle; null se o corpo não é o do criador.
func boneco_retrato() -> Node3D:
	if not personagem:
		return null
	var n := CriadorPersonagem.boneco_jogo(dados_personagem, true)
	if n:
		_podar_pecas(n)
	return n


func _remapear_animacoes(ap: AnimationPlayer) -> void:
	if _lib_dayone == null:
		_lib_dayone = AnimationLibrary.new()
		var prefixo := ""
		for n in MAPA_DAYONE:
			if ap.has_animation(MAPA_DAYONE[n]):
				var a := ap.get_animation(MAPA_DAYONE[n]).duplicate(true) as Animation
				_lib_dayone.add_animation(n, a)
				if prefixo == "" and a.get_track_count() > 0:
					prefixo = String(a.track_get_path(0)).split(":")[0]
		if prefixo == "":
			prefixo = "Skeleton/Skeleton3D"
		if ResourceLoader.exists(SOLDIER_PATH):
			var sold := (load(SOLDIER_PATH) as PackedScene).instantiate()
			var sap := _find(sold, "AnimationPlayer") as AnimationPlayer
			if sap:
				for n in DO_SOLDADO:
					for lib in sap.get_animation_library_list():
						var full: String = (String(lib) + "/" + String(n)) if String(lib) != "" else String(n)
						if not sap.has_animation(full):
							continue
						var a := sap.get_animation(full).duplicate(true) as Animation
						for i in a.get_track_count():
							var tp := String(a.track_get_path(i))
							var k := tp.find(":")
							if k > 0:
								a.track_set_path(i, NodePath(prefixo + tp.substr(k)))
						_lib_dayone.add_animation(n, a)
						break
			sold.free()
	if not ap.has_animation_library(&"corpo"):
		ap.add_animation_library(&"corpo", _lib_dayone)
	# _clip() procura as bibliotecas em ordem: a do corpo tem de vencer os nomes do pack (nenhum colide, mas garante)


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


func _all_geometry(n: Node, out: Array[GeometryInstance3D] = []) -> Array[GeometryInstance3D]:
	if n is GeometryInstance3D:
		out.append(n)
	for c in n.get_children():
		_all_geometry(c, out)
	return out


## Local player's own body: invisible to its camera but still casts a shadow.
func set_first_person(on: bool) -> void:
	first_person = on
	if model == null:
		return
	_pecas_1p(on)
	for g in _all_geometry(model):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if weapon_node:
		for g in _all_geometry(weapon_node):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


# ------------------------------------------------------------------ animação
func _clip(name: String) -> String:
	if anim_player == null:
		return ""
	for lib_name in anim_player.get_animation_library_list():
		var full := (String(lib_name) + "/" + name) if String(lib_name) != "" else name
		if anim_player.has_animation(full):
			return full
	return ""


## O glTF importa tudo sem laço: locomoção e poses de segurar precisam repetir, senão congelam no último quadro.
const LOOPED := ["sprint_a", "idle", "walk_f", "walk_b", "walk_l", "walk_r", "run_f", "run_b", "run_l", "run_r", "crouch_idle",
	"crouch_f", "crouch_b", "crouch_l", "crouch_r", "hold_rifle", "hold_pistol", "hold_knife"]


## Poses estáticas e golpes curtos saíram do Blender com um quadro extra no fim que pertence a outra pose;
## com laço isso fazia cabeça e tronco alternarem 15x/s (tremor). Poses: fica só o 1º quadro; golpes: cai o último.
const POSES := ["hold_rifle", "hold_pistol", "hold_knife", "crouch_idle"]
const SHORT_ACTIONS := ["fire", "reload", "knife", "plant"]
static var _sanitized := {}


func _sanitize(a: Animation, pose: bool) -> void:
	if _sanitized.has(a):
		return
	_sanitized[a] = true
	for i in a.get_track_count():
		var n := a.track_get_key_count(i)
		if pose:
			for k in range(n - 1, 0, -1):
				a.track_remove_key(i, k)
		elif n > 2 and a.track_get_key_time(i, n - 1) >= a.length - 0.0005:
			a.track_remove_key(i, n - 1)
	if not pose:
		var last := 0.0
		for i in a.get_track_count():
			if a.track_get_key_count(i) > 0:
				last = maxf(last, a.track_get_key_time(i, a.track_get_key_count(i) - 1))
		a.length = maxf(last, 0.05)


## Clipes de locomoção "quase no lugar": o quadril avança até 54 cm no ciclo e o corpo saltava de volta a cada volta.
## Tira a deriva linear horizontal (x/z) do Hips, mantendo o balanço dentro do ciclo.
static var _drift_fixed := {}


func _remove_drift(a: Animation) -> void:
	if _drift_fixed.has(a):
		return
	_drift_fixed[a] = true
	for i in a.get_track_count():
		var tpath := String(a.track_get_path(i))
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D or not (tpath.ends_with(":Hips") or tpath.ends_with(":Root")):
			continue
		var n := a.track_get_key_count(i)
		if n < 2:
			continue
		var t0 := a.track_get_key_time(i, 0)
		var t1 := a.track_get_key_time(i, n - 1)
		var d: Vector3 = a.track_get_key_value(i, n - 1) - a.track_get_key_value(i, 0)
		d.y = 0.0
		if d.length() < 0.01 or t1 <= t0:
			continue
		for k in n:
			var f := (a.track_get_key_time(i, k) - t0) / (t1 - t0)
			a.track_set_key_value(i, k, a.track_get_key_value(i, k) - d * f)


## Passada mais longa na corrida: amplia a rotação de coxas (1,5x) e joelhos (1,25x) em torno da pose média do ciclo.
## O clipe original anda 0,96 m por passo (2,4 m/s); ampliado ~1,45x, a 5,5 m/s a cadência fica ~3,4 passos/s.
const STRIDE_GAIN := {"UpLeg": 1.5, "Leg": 1.25}
const RUN_NATIVE_SPEED := 2.4   # ampliar a passada deixou joelhos altos/pés fora do chão: desativado (_lengthen_stride não é usado)
static var _stride_done := {}


func _lengthen_stride(a: Animation) -> void:
	if _stride_done.has(a):
		return
	_stride_done[a] = true
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(i).get_subname(0))
		var gain := 0.0
		for key in STRIDE_GAIN:
			if bone.ends_with(key) and (bone.begins_with("Left") or bone.begins_with("Right")):
				gain = STRIDE_GAIN[key]
		if bone.ends_with("UpLeg"):
			gain = STRIDE_GAIN["UpLeg"]
		if gain == 0.0:
			continue
		var n := a.track_get_key_count(i)
		if n < 2:
			continue
		# média aproximada: slerp acumulado das chaves
		var mean: Quaternion = a.track_get_key_value(i, 0)
		for k in range(1, n):
			mean = mean.slerp(a.track_get_key_value(i, k), 1.0 / float(k + 1))
		for k in n:
			var q: Quaternion = a.track_get_key_value(i, k)
			var d := (mean.inverse() * q).normalized()
			var ang := d.get_angle()
			if ang < 1e-5:
				continue
			a.track_set_key_value(i, k, (mean * Quaternion(d.get_axis(), ang * gain)).normalized())


func _set_loops() -> void:
	for n in POSES + SHORT_ACTIONS:
		var c0 := _clip(n)
		if c0 != "":
			_sanitize(anim_player.get_animation(c0), n in POSES)
	for n in LOOPED:
		var c1 := _clip(n)
		if c1 != "" and not n.begins_with("hold") and n != "crouch_idle":
			_remove_drift(anim_player.get_animation(c1))
	for n in LOOPED:
		var c := _clip(n)
		if c != "":
			var a := anim_player.get_animation(c)
			if a.loop_mode == Animation.LOOP_NONE:
				a.loop_mode = Animation.LOOP_LINEAR


func _anim_node(name: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = _clip(name)
	return a


func _build_tree() -> void:
	tree = AnimationTree.new()
	tree.name = "Tree"
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	var bt := AnimationNodeBlendTree.new()
	# locomoção em pé
	var stand := AnimationNodeBlendSpace2D.new()
	stand.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	stand.add_blend_point(_anim_node("idle"), Vector2(0, 0), -1, &"idle")
	stand.add_blend_point(_anim_node("walk_f"), Vector2(0, 0.5), -1, &"walk_f")
	stand.add_blend_point(_anim_node("walk_b"), Vector2(0, -0.5), -1, &"walk_b")
	stand.add_blend_point(_anim_node("walk_l"), Vector2(-0.5, 0), -1, &"walk_l")
	stand.add_blend_point(_anim_node("walk_r"), Vector2(0.5, 0), -1, &"walk_r")
	# corrida para a frente: Adult_Run (passada natural 4,33 m/s) quando existir; o run_f do pacote teen anda 2,4 m/s
	stand.add_blend_point(_anim_node("sprint_a" if _clip("sprint_a") != "" else "run_f"), Vector2(0, 1), -1, &"run_f")
	stand.add_blend_point(_anim_node("run_b"), Vector2(0, -1), -1, &"run_b")
	stand.add_blend_point(_anim_node("run_l"), Vector2(-1, 0), -1, &"run_l")
	stand.add_blend_point(_anim_node("run_r"), Vector2(1, 0), -1, &"run_r")
	bt.add_node("stand_src", stand, Vector2(-200, 0))
	var ts := AnimationNodeTimeScale.new()
	bt.add_node("stand", ts, Vector2(0, 0))
	bt.connect_node("stand", 0, "stand_src")
	var crouch := AnimationNodeBlendSpace2D.new()
	crouch.add_blend_point(_anim_node("crouch_idle"), Vector2(0, 0), -1, &"crouch_idle")
	crouch.add_blend_point(_anim_node("crouch_f"), Vector2(0, 1), -1, &"crouch_f")
	crouch.add_blend_point(_anim_node("crouch_b"), Vector2(0, -1), -1, &"crouch_b")
	crouch.add_blend_point(_anim_node("crouch_l"), Vector2(-1, 0), -1, &"crouch_l")
	crouch.add_blend_point(_anim_node("crouch_r"), Vector2(1, 0), -1, &"crouch_r")
	bt.add_node("crouch", crouch, Vector2(-200, 200))
	var cts := AnimationNodeTimeScale.new()
	bt.add_node("crouch_ts", cts, Vector2(0, 200))
	bt.connect_node("crouch_ts", 0, "crouch")
	var stance := AnimationNodeBlend2.new()
	bt.add_node("stance", stance, Vector2(250, 100))
	bt.connect_node("stance", 0, "stand")
	bt.connect_node("stance", 1, "crouch_ts")
	var air := AnimationNodeBlend2.new()
	bt.add_node("jump", _anim_node("jump"), Vector2(250, 300))
	bt.add_node("air", air, Vector2(450, 150))
	bt.connect_node("air", 0, "stance")
	bt.connect_node("air", 1, "jump")
	# parte de cima: pose de segurar a arma (filtrada nos ossos do tronco/braços)
	_upper_tracks.clear()
	var ref := anim_player.get_animation(_clip("hold_rifle")) if _clip("hold_rifle") != "" else null
	if ref:
		for i in ref.get_track_count():
			var tp := ref.track_get_path(i)
			if tp.get_subname_count() > 0 and String(tp.get_subname(0)) in UPPER_BONES:
				_upper_tracks.append(tp)
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for tp in _upper_tracks:
		upper.set_filter_path(tp, true)
	bt.add_node("hold_rifle", _anim_node("hold_rifle"), Vector2(450, 350))
	bt.add_node("hold_pistol", _anim_node("hold_pistol"), Vector2(450, 450))
	bt.add_node("hold_knife", _anim_node("hold_knife"), Vector2(450, 550))
	var hold := AnimationNodeTransition.new()
	hold.add_input("rifle")
	hold.add_input("pistol")
	hold.add_input("knife")
	hold.xfade_time = 0.18
	bt.add_node("hold", hold, Vector2(650, 450))
	bt.connect_node("hold", 0, "hold_rifle")
	bt.connect_node("hold", 1, "hold_pistol")
	bt.connect_node("hold", 2, "hold_knife")
	bt.add_node("upper", upper, Vector2(850, 200))
	bt.connect_node("upper", 0, "air")
	bt.connect_node("upper", 1, "hold")
	# disparos / recarga / faca como one-shots do tronco
	var shot := AnimationNodeOneShot.new()
	shot.filter_enabled = true
	shot.fadein_time = 0.03
	shot.fadeout_time = 0.12
	for tp in _upper_tracks:
		shot.set_filter_path(tp, true)
	var act := AnimationNodeTransition.new()
	for n in ["fire", "reload", "knife", "plant"]:
		act.add_input(n)
		bt.add_node("act_" + n, _anim_node(n), Vector2(850, 400 + act.get_input_count() * 90))
	bt.add_node("act", act, Vector2(1050, 450))
	var idx := 0
	for n in ["fire", "reload", "knife", "plant"]:
		bt.connect_node("act", idx, "act_" + n)
		idx += 1
	bt.add_node("shot", shot, Vector2(1250, 250))
	bt.connect_node("shot", 0, "upper")
	bt.connect_node("shot", 1, "act")
	bt.connect_node("output", 0, "shot")
	tree.tree_root = bt
	tree.active = true
	tree.set("parameters/upper/blend_amount", 1.0)


func _hold_for(def: WeaponDef) -> String:
	if def == null:
		return "knife"
	match def.slot:
		WeaponDef.Slot.PRIMARY: return "rifle"
		WeaponDef.Slot.PISTOL: return "pistol"
	return "knife"


func _one_shot(action: String) -> void:
	if tree == null:
		return
	tree.set("parameters/act/transition_request", action)
	tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Escalando escada vertical: corpo de frente para a escada, pose de "salto" (braços/pernas abertos) balançando no
## ritmo da subida. Sem clipe próprio de escalada no pacote de animações, então é um movimento procedural simples.
var _climb_phase := 0.0
var _climbing := false


func _sync_climb(s: Soldier, dt: float) -> bool:
	var on: bool = s.escada != null and not dead
	if not on:
		if _climbing:
			_climbing = false
			if model:
				model.position.y = 0.0
				model.rotation.z = 0.0
				model.rotation.x = 0.0
		return false
	_climbing = true
	_vis_yaw = s.yaw
	_leg_yaw = 0.0
	rotation.y = s.yaw
	_climb_phase += absf(s.climb_v) * dt * 2.6
	var amp := clampf(absf(s.climb_v) / 2.3, 0.0, 1.0)
	if model:
		model.position.y = absf(sin(_climb_phase)) * 0.05 * amp
		model.rotation.z = sin(_climb_phase) * 0.07 * amp
		model.rotation.x = -0.12              # inclina o tronco de encontro à escada
	_anim_velocity = Vector2.ZERO
	_air = lerpf(_air, 1.0, clampf(dt * 10.0, 0.0, 1.0))
	if ik:
		ik.lower = 1.0
		ik.lean = Vector2.ZERO
	if tree:
		tree.set("parameters/stand_src/blend_position", Vector2.ZERO)
		tree.set("parameters/air/blend_amount", _air)
	return true


func sync_pose(s: Soldier, dt: float) -> void:
	if _sync_climb(s, dt):
		return
	# postura de atirador: o tronco gira ~40° para a direita, então o corpo compensa para o cano seguir a mira
	_hold_yaw = lerp_angle(_hold_yaw, _hold_yaw_target, clampf(dt * 8.0, 0.0, 1.0))
	# giro visual suavizado: a mira dos bots corrige em passos pequenos a cada tique e fazia o corpo tremer
	_vis_yaw = lerp_angle(_vis_yaw, s.yaw, 1.0 - exp(-dt * 16.0))
	# pernas orientadas ao movimento (até ±60° de lado, ±45° de ré); o tronco gira de volta no IK e a arma fica na mira
	var vflat := Vector2(s.velocity.x, s.velocity.z)
	var want_leg := 0.0
	if not dead and vflat.length() > 1.0 and s.is_on_floor():
		var lv := Basis(Vector3.UP, -s.yaw) * s.velocity
		var a := atan2(lv.x, -lv.z)          # 0 = frente, +90° = direita
		if absf(a) <= deg_to_rad(115.0):
			want_leg = clampf(a, -deg_to_rad(60.0), deg_to_rad(60.0))
		else:
			want_leg = clampf(wrapf(a - PI, -PI, PI), -deg_to_rad(45.0), deg_to_rad(45.0))
	_leg_yaw = lerp_angle(_leg_yaw, want_leg, 1.0 - exp(-dt * 7.0))
	rotation.y = _vis_yaw - _leg_yaw + (_hold_yaw if not dead else 0.0)
	if ik:
		ik.twist = _leg_yaw
	if dead:
		return
	var local_v := Basis(Vector3.UP, -(s.yaw - _leg_yaw)) * s.velocity
	var run_speed := 5.5
	var physical_local := Vector2(local_v.x, -local_v.z)
	var target := physical_local.limit_length(run_speed)
	# A física Source para rápido por design; o corpo visual conserva um pouco da passada.
	# A arrancada responde em ~0,25 s; a frenagem anima o último passo em ~0,35 s.
	# Vetor, em vez de direção normalizada, faz curvas e inversões passarem por transição real.
	var changing_to_idle := target.length() < _anim_velocity.length()
	var response := 9.5 if changing_to_idle else 13.0
	_anim_velocity = _anim_velocity.move_toward(target, response * dt)
	_loco = _anim_velocity / run_speed
	_crouch = lerpf(_crouch, s.crouch, clampf(dt * 12.0, 0.0, 1.0))
	_air = lerpf(_air, 0.0 if s.is_on_floor() else 1.0, clampf(dt * 8.0, 0.0, 1.0))
	_aim_pitch = lerpf(_aim_pitch, s.pitch, 1.0 - exp(-dt * 12.0))
	if ik:
		ik.pitch = _aim_pitch
		ik.kick = move_toward(ik.kick, 0.0, dt / 0.12)
		# inclinação pela aceleração local (curva/strafe = lateral; arrancar/frear = frente/trás) + leve à frente correndo
		var acc_w := (s.velocity - _prev_vel) / maxf(dt, 0.001)
		_prev_vel = s.velocity
		var acc_l := Basis(Vector3.UP, -s.yaw) * acc_w
		var run_k := clampf(Vector2(s.velocity.x, s.velocity.z).length() / 5.5, 0.0, 1.0)
		var tgt := Vector2(clampf(acc_l.x * 0.012, -0.14, 0.14), clampf(-acc_l.z * 0.01, -0.12, 0.12) + 0.06 * run_k * (1.0 if s.is_on_floor() else 0.0))
		_lean = _lean.lerp(tgt, 1.0 - exp(-dt * 6.0))
		ik.lean = _lean
		if s._mantle_on:   # pulo de muro/cerca: tronco inclinado para o apoio, braços à frente
			ik.lean = Vector2(0.0, 0.42)
			ik.lower = 0.0
			_air = 1.0
		# low ready: correndo e sem atirar há 0,5 s o cano desce; volta rápido para mirar
		var since_shot := s.t - s.last_shot
		var want_lower := clampf((Vector2(s.velocity.x, s.velocity.z).length() - 3.0) / 2.0, 0.0, 1.0) if since_shot > 0.5 else 0.0
		# corpo do criador (tronco largo, jaqueta): com o cano todo baixo a arma some atrás do peito na câmera de 3ª pessoa
		# Para aparecer, ao correr o cano baixa menos e gira para fora (direita) do tronco.
		if personagem:
			want_lower *= 0.6
		ik.lower = move_toward(ik.lower, want_lower, dt * (2.5 if want_lower > ik.lower else 8.0))
		if personagem and ik.grip.has("r") and not ik.grip.has("lfree"):
			ik.grip["wrot"] = Vector3(0.0, -deg_to_rad(38.0) * ik.lower, 0.0)
		var is_rifle := weapon_id in [&"ak47", &"m4"]
		ik.cheek = move_toward(ik.cheek, (1.0 - ik.lower) if is_rifle else 0.0, dt * 5.0)
	if tree:
		tree.set("parameters/stand_src/blend_position", _loco)
		var spd := _anim_velocity.length()
		# stride matching (tests/stride_probe): walk_f nativo 1,5 m/s, run_f 2,4 m/s. Acelerar além de ~1,6x deixa
		# as pernas frenéticas (parece tremor); acima disso aceita-se um leve deslize, como no CS.
		var fwd_w := clampf(_loco.y / maxf(_loco.length(), 0.001), 0.0, 1.0) if _clip("sprint_a") != "" else 0.0
		var run_native := lerpf(RUN_NATIVE_SPEED, 4.33, fwd_w)
		var native := lerpf(1.5, run_native, clampf((_loco.length() - 0.5) / 0.5, 0.0, 1.0))
		tree.set("parameters/stand/scale", clampf(spd / native, 0.05, 1.6))
		tree.set("parameters/crouch/blend_position", _loco / 0.4)
		# agachado: clipe anda ~1,4 m/s de frente e ~1,0 de lado (tests/stride_probe); jogo agachado = 1,86 m/s
		var c_native := lerpf(1.0, 1.4, clampf(absf(_loco.y) / maxf(_loco.length(), 0.001), 0.0, 1.0))
		tree.set("parameters/crouch_ts/scale", clampf(spd / c_native, 0.05, 1.5))
		tree.set("parameters/stance/blend_amount", _crouch)
		tree.set("parameters/air/blend_amount", _air)
	elif _mannequin:
		_animate_mannequin(s, dt)


## LOD por distância (battle royale): 0 = perto (animação todo quadro + IK), 1 = médio (animação a cada 2 quadros, sem IK),
## 2 = longe (a cada 4 quadros, sem IK). A árvore passa a ser avançada à mão com o dt acumulado.
var lod := 0
var _lod_acc := 0.0
var _lod_n := 0


func set_lod(nivel: int) -> void:
	if nivel == lod or tree == null:
		return
	lod = nivel
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if nivel == 0 else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if ik:
		ik.active = nivel == 0
	_lod_acc = 0.0


## Arma presa nos ossos de pega: o IK leva o osso da MÃO até a pega com um desvio fixo de palma; os ossos
## RightHandProp/LeftHandProp do esqueleto ficavam ~6 cm fora do cabo/guarda-mão. Mede uma vez por arma (o erro é
## rígido no quadro da arma, pois a orientação da mão vem dos eixos da arma) e corrige o alvo do IK.
static var _pega_corrigida := {}
var _calib_passos := 0
var _calib_quadros := 0


func _calibrar_pega() -> void:
	if ik == null or ik.weapon == null or skeleton == null or ik.grip.is_empty() or dead or lod != 0:
		return
	var ra := skeleton.get_node_or_null("RightHandAttach") as Node3D
	var la := skeleton.get_node_or_null("LeftHandAttach") as Node3D
	if ra == null:
		_calib_passos = 0
		return
	var inv := ik.weapon.global_transform.affine_inverse()
	var g: Dictionary = ik.grip.duplicate()
	var alvo: Dictionary = GRIPS.get(weapon_id, g)
	g.r = (g.r as Vector3) - ((inv * ra.global_position) - (alvo.r as Vector3))
	if la and g.has("l") and not g.has("lfree"):
		g.l = (g.l as Vector3) - ((inv * la.global_position) - (alvo.l as Vector3))
	ik.grip = g
	_calib_passos -= 1
	_calib_quadros = 3
	if _calib_passos <= 0:
		_pega_corrigida[weapon_id] = g.duplicate()


func _process(dt: float) -> void:
	if _calib_passos > 0:
		_calib_quadros -= 1
		if _calib_quadros <= 0:
			_calibrar_pega()
	_mira_acc += dt
	if _mira_acc >= 0.3 and weapon_node != null:
		_mira_acc = 0.0
		var antes := mira
		_mira_do_jogo()
		if mira != antes:
			_sync_mira(false)
	if lod == 0 or tree == null or not tree.active:
		return
	_lod_acc += dt
	_lod_n += 1
	if _lod_n >= (2 if lod == 1 else 4):
		_lod_n = 0
		tree.advance(_lod_acc)
		_lod_acc = 0.0


## Inclinação do tronco pela mira: aplicada depois da animação (sinal skeleton_updated), sem acumular.
func _apply_aim_pitch() -> void:
	if skeleton == null or dead or _spine1_idx < 0:
		return
	var q := Quaternion(Vector3.RIGHT, _aim_pitch * 0.5)
	skeleton.set_bone_pose_rotation(_spine1_idx, skeleton.get_bone_pose_rotation(_spine1_idx) * q)


func _on_weapon(def: WeaponDef) -> void:
	if model == null:
		return   # corpo ainda não montado (pré-montagem: setup só no CONFIRMAR)
	if def:
		_hold_yaw_target = 0.0   # a arma segue a mira pelo IK; o corpo fica alinhado às pernas
	if tree:
		tree.set("parameters/hold/transition_request", _hold_for(def))
		# mãos vazias: braços soltos pela animação de locomoção (antes ficava a pose 'faca', cotovelos dobrados no peito)
		tree.set("parameters/upper/blend_amount", 0.0 if def == null else 1.0)
	if def == null:
		# mãos vazias: tira o modelo da mão (antes ficava a última arma 'fantasma')
		weapon_id = &""
		if weapon_node:
			weapon_node.queue_free()
			weapon_node = null
		if ik:
			ik.weapon = null
			ik.grip = {}
			ik.knife = null
		return
	if def.id == weapon_id and weapon_node != null:
		return
	weapon_id = def.id
	if weapon_node:
		weapon_node.queue_free()
		weapon_node = null
	var path := def.model_path.replace(".tscn", "_world.tscn")
	if not ResourceLoader.exists(path):
		path = def.model_path
	if not ResourceLoader.exists(path):
		return
	weapon_node = load(path).instantiate()
	if WEAPON_SCALE.has(def.id):
		for c in weapon_node.get_children():
			if c is Node3D:
				(c as Node3D).scale *= float(WEAPON_SCALE[def.id])
				(c as Node3D).position *= float(WEAPON_SCALE[def.id])
	var gkey: StringName = def.id
	if ik:
		ik.weapon = null
		ik.grip = {}
		ik.curl_right_only = def.slot == WeaponDef.Slot.KNIFE and not GRIPS.has(&"knife")
		ik.knife = null
	if ik and GRIPS.has(gkey):
		add_child(weapon_node)
		ik.weapon = weapon_node
		ik.grip = (_pega_corrigida.get(gkey, GRIPS[gkey]) as Dictionary).duplicate()
		_calib_passos = 0 if _pega_corrigida.has(gkey) else 2
		_calib_quadros = 3
	elif ik and def.slot == WeaponDef.Slot.KNIFE:
		add_child(weapon_node)
		ik.knife = weapon_node
	elif hand:
		hand.add_child(weapon_node)
		var key := "rifle" if def.slot == WeaponDef.Slot.PRIMARY else ("pistol" if def.slot == WeaponDef.Slot.PISTOL else "knife")
		if _offsets.has(key):
			weapon_node.transform = _blender_rel_to_godot(_offsets[key])
			weapon_node.scale = Vector3.ONE / float(_offsets.get("_scale", 1.0))
		if def.slot == WeaponDef.Slot.BOMB:
			weapon_node.visible = false
	elif _mannequin:
		model.get_node("Arms").add_child(weapon_node)
		weapon_node.position = Vector3(0.18, -0.05, -0.35)
	else:
		model.add_child(weapon_node)
	_mira_acc = 0.0
	_sync_mira(true)
	for g in _all_geometry(weapon_node):
		g.layers = 2
	set_first_person(first_person)


## Óptica instalada na arma da mão ("", "acog", "reddot"): aparece no modelo de 3ª pessoa (OpticaAssento).
var mira := ""
var _mira_acc := 0.0


func set_mira(tipo: String) -> void:
	mira = tipo
	if soldier:
		soldier.set_meta("mira", tipo)
	_sync_mira(false)


func _sync_mira(consultar: bool) -> void:
	if soldier and consultar:
		_mira_do_jogo()
	if weapon_node == null:
		return
	OpticaAssento.sincronizar(weapon_node, weapon_id, mira)
	if first_person:
		set_first_person(true)


## O jogador local lê a mira do inventário da partida; bots usam set_mira (ou o meta "mira" do soldado).
func _mira_do_jogo() -> void:
	var m = soldier.match_ref if soldier else null
	if m != null and m.get("local_player") == soldier and m.has_method("mira_para"):
		mira = String(m.call("mira_para", soldier))
	elif soldier and soldier.has_meta("mira"):
		mira = String(soldier.get_meta("mira"))


func _on_fired(_def: WeaponDef) -> void:
	# com IK, o tiro é um coice curto da arma/braços; o clipe "fire" girava o tronco 20° em 33 ms (sacudia a cabeça)
	if ik and ik.weapon:
		ik.kick = 1.0
	else:
		_one_shot("fire")


func _on_reload(_def: WeaponDef) -> void:
	_one_shot("reload")


func muzzle_position() -> Vector3:
	if weapon_node:
		var m := weapon_node.find_child("Muzzle", true, false) as Node3D
		if m:
			return m.global_position
		return weapon_node.global_transform * Vector3(0, 0.05, -0.6)
	return soldier.eye_position() + soldier.aim_dir() * 0.6 - Vector3.UP * 0.2


func on_hit(_group: String, _dir: Vector3) -> void:
	pass


func on_death(dir: Vector3, headshot: bool) -> void:
	dead = true
	# poça de sangue sob o corpo depois que ele cai
	if soldier and soldier.match_ref and soldier.match_ref.get("fx"):
		var fxm = soldier.match_ref.fx
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if is_instance_valid(fxm) and dead:
				# centro da poça: entre o quadril e o peito já caídos
				var at := global_position
				if skeleton:
					var hi := skeleton.find_bone("Spine1")
					if hi >= 0:
						at = skeleton.global_transform * skeleton.get_bone_global_pose(hi).origin
				fxm.blood_pool(at, 1.5 if headshot else 1.2))
	if tree:
		tree.active = false
	if anim_player:
		var clip := _clip("death_head" if headshot else "death")
		if clip == "":
			clip = _clip("death")
		if clip != "":
			anim_player.play(clip, 0.08)
	elif _mannequin:
		var tw := create_tween()
		var side := 1.0 if randf() < 0.5 else -1.0
		tw.tween_property(model, "rotation", Vector3(-PI * 0.5, 0, side * 0.3), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(model, "position", Vector3(0, 0.15, 0.4), 0.45)
	if weapon_node:
		weapon_node.visible = false


func on_respawn(s: Soldier) -> void:
	_clear_wounds()
	dead = false
	_vis_yaw = s.yaw
	if tree:
		tree.active = true
	if _mannequin and model:
		model.rotation = Vector3.ZERO
		model.position = Vector3.ZERO
	if weapon_node:
		weapon_node.visible = true
	_on_weapon(s.current_def())


# ------------------------------------------------------------------ manequim provisório
func _build_mannequin(team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Mannequin"
	var col: Color = Game.TEAM_COLORS[team].darkened(0.35)
	var skin := Color(0.78, 0.6, 0.47)
	root.add_child(_part(CapsuleMesh.new(), Vector3(0, 1.12, 0), Vector3(0.5, 0.62, 0.34), col, "Torso"))
	root.add_child(_part(SphereMesh.new(), Vector3(0, 1.66, 0), Vector3(0.24, 0.27, 0.25), skin, "Head"))
	root.add_child(_part(CapsuleMesh.new(), Vector3(-0.12, 0.45, 0), Vector3(0.18, 0.9, 0.18), col.darkened(0.3), "LegL"))
	root.add_child(_part(CapsuleMesh.new(), Vector3(0.12, 0.45, 0), Vector3(0.18, 0.9, 0.18), col.darkened(0.3), "LegR"))
	var arms := Node3D.new()
	arms.name = "Arms"
	arms.position = Vector3(0, 1.38, 0)
	root.add_child(arms)
	arms.add_child(_part(CapsuleMesh.new(), Vector3(0.22, -0.08, -0.2), Vector3(0.12, 0.5, 0.12), col, "ArmR", Vector3(1.3, 0, 0)))
	arms.add_child(_part(CapsuleMesh.new(), Vector3(-0.12, -0.08, -0.28), Vector3(0.12, 0.5, 0.12), col, "ArmL", Vector3(1.3, 0.5, 0)))
	return root


func _part(mesh: PrimitiveMesh, pos: Vector3, size: Vector3, color: Color, pname: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = pname
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	mi.material_override = m
	return mi


func _animate_mannequin(s: Soldier, _dt: float) -> void:
	var legs_amt := clampf(s.horizontal_speed() / 5.0, 0.0, 1.0)
	var ph := s.t * 9.0
	var ll := model.get_node("LegL") as Node3D
	var lr := model.get_node("LegR") as Node3D
	ll.rotation.x = sin(ph) * 0.6 * legs_amt
	lr.rotation.x = -sin(ph) * 0.6 * legs_amt
	model.position.y = -0.4 * _crouch
	(model.get_node("Arms") as Node3D).rotation.x = s.pitch



## Transformação relativa calculada no Blender (Z para cima) -> Godot (Y para cima): C * T * C^-1.
func _blender_rel_to_godot(rows: Array) -> Transform3D:
	var b := Basis(Vector3(rows[0][0], rows[1][0], rows[2][0]), Vector3(rows[0][1], rows[1][1], rows[2][1]), Vector3(rows[0][2], rows[1][2], rows[2][2]))
	var o := Vector3(rows[0][3], rows[1][3], rows[2][3])
	var C := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # colunas: x->x, y->-z, z->y
	var t := Transform3D(b, o)
	var cm := Transform3D(C, Vector3.ZERO)
	return cm * t * cm.affine_inverse()


## Centros (mundo) para as hitboxes; vazio se não houver esqueleto.
func hitbox_points() -> Dictionary:
	if skeleton == null or dead:
		return {}
	var h := skeleton.get_node_or_null("HB_Head") as Node3D
	var c := skeleton.get_node_or_null("HB_Spine1") as Node3D
	var n := skeleton.get_node_or_null("HB_Neck") as Node3D
	if h == null or c == null or n == null:
		return {}
	var head_up := h.global_transform.basis.y.normalized()
	return {"head": h.global_position + head_up * 0.11, "chest": c.global_position.lerp(n.global_position, 0.55), "stomach": c.global_position}


# ------------------------------------------------------------------ ferimentos
const WOUND_BONES := ["Head", "Neck", "Spine1", "Spine", "Hips", "LeftArm", "LeftForeArm", "RightArm", "RightForeArm",
	"LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"]
const MAX_WOUNDS := 10
var _wounds: Array[Node3D] = []
static var _wound_mat: StandardMaterial3D


## Mancha de ferimento presa ao osso mais próximo do impacto (segue a animação); some ao renascer.
func add_wound(world_pos: Vector3, normal: Vector3) -> void:
	if skeleton == null or first_person:
		return
	var best := -1
	var bd := 1e9
	for bn in WOUND_BONES:
		var i := skeleton.find_bone(bn)
		if i < 0:
			continue
		var d := (skeleton.global_transform * skeleton.get_bone_global_pose(i).origin).distance_squared_to(world_pos)
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return
	var att_name := "Wound_" + skeleton.get_bone_name(best)
	var att := skeleton.get_node_or_null(att_name) as BoneAttachment3D
	if att == null:
		att = BoneAttachment3D.new()
		att.name = att_name
		att.bone_name = skeleton.get_bone_name(best)
		skeleton.add_child(att)
	if _wound_mat == null:
		_wound_mat = StandardMaterial3D.new()
		_wound_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_wound_mat.alpha_scissor_threshold = 0.4
		_wound_mat.albedo_texture = BLOOD_SPLAT
		_wound_mat.roughness = 0.35
		_wound_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var sz := randf_range(0.13, 0.2)
	qm.size = Vector2(sz, sz)
	mi.mesh = qm
	mi.material_override = _wound_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	att.add_child(mi)
	var n := normal.normalized()
	var up := Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(n).normalized()
	var b := Basis(x, n.cross(x), n).rotated(n, randf() * TAU)
	mi.global_transform = Transform3D(b, world_pos + n * 0.01)
	_wounds.append(mi)
	if _wounds.size() > MAX_WOUNDS:
		var old: Node3D = _wounds.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _clear_wounds() -> void:
	for w in _wounds:
		if is_instance_valid(w):
			w.queue_free()
	_wounds.clear()
