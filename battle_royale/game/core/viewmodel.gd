class_name ViewModel
extends Node3D
## First-person arms + weapon. Plays authored clips from <weapon>_fp.tscn when present and layers
## sway, bob, recoil kick and landing on top (the usual FPS "feel" layer).

const VM_SHADER := preload("res://shaders/viewmodel.gdshader")
## Braços do soldado de docs/ref/ak47_fps.jpg (tools/build_fp_bracos.py): mãos cor de pele facetadas + manga camuflada,
## no mesmo esqueleto dos *_fp.glb. Trocam, em tempo de execução, as malhas de braço originais do pacote.
const ARMS_SCENE := "res://assets/models/weapons/fp_bracos.glb"
const SLEEVE_TEX := "res://assets/models/characters/soldado_camo.png"
const OLD_ARM_MESHES := ["Adult_Male_Body", "Outwear_Adult_Male"]

var soldier: Soldier
var viewmodel_enabled := true
var pivot: Node3D
var holder: Node3D
var current_id: StringName = &""
var scene_root: Node3D
var anim: AnimationPlayer
var muzzle: Node3D
var eject: Node3D
var bolt: Node3D
var optic: Node3D
var _bolt_t := -1.0
var _bolt_rest := Vector3.ZERO
var ads_amount := 0.0
var ads_acog := false
var acog_installed := false
var reddot_installed := false        # mira holográfica (wf/reddot.glb): janela aberta, retículo desenhado na tela
var acog_dot := false            # ACOG em red dot: arma continua visível (só o ponto no centro, sem máscara de luneta)
var _flash: Node3D
var _flash_t := 0.0
var _flash_quadros := 0
var _flash_light: OmniLight3D

var _sway := Vector2.ZERO
var _sway_target := Vector2.ZERO
var _bob_phase := 0.0
var gait_phase := 0.0       # passada vinda do controlador (mesma fase do balanço da câmera)
var gait_amount := 0.0
var _bob_amount := 0.0
var _kick := 0.0
var _kick_vel := 0.0
var _kick_rot := 0.0
var _kick_rot_vel := 0.0
var _land := 0.0
var _land_vel := 0.0
var _draw_t := 1.0
var _draw_len := 0.5
var _reload_t := -1.0
var _reload_len := 1.0
var _recarga_dip := 0.0
var _carregador: Node3D          # carregador/tambor do modelo novo: desce e volta na recarga
var _carregador_rest := Vector3.ZERO
var _mao_e: Node3D                # mão de apoio (MaoE do maos_wf_*.glb): vai ao carregador na recarga
var _mao_e_rest := Transform3D.IDENTITY
var _hip_pivo := Vector3.ZERO
var _swing_t := -1.0
var _swing_heavy := false
var _swing_side := 1.0
var _lower := 0.0
var _sprint_w := 0.0
var _inspect_t := -1.0
var _time := 0.0
var _casings: Array[Node3D] = []
var _casing_vel: Array[Vector3] = []
var _casing_life: Array[float] = []
var _casing_i := 0
var _casing_mesh: Mesh
# mira calculada (assets/models/weapons/miras.json): alça/massa no espaço do nó da arma -> pose de ADS do Holder
const MIRAS_PATH := "res://assets/models/weapons/miras.json"
static var _miras: Dictionary = {}
var _mira_no: Node3D
var _alca := Vector3.ZERO
var _massa := Vector3.ZERO
var _alivio := 0.2
var _hip := Transform3D.IDENTITY
var _ads_pose := Transform3D.IDENTITY
var _ads_ok := false
var _wf := false                  # arma do pacote Weapons FREE (Assets/)
var luneta := false               # mira pela luneta da própria arma (overlay de tela, arma some no fim do ADS)
var _acog_node: Node3D
var _alca_ferro := Vector3.ZERO
var _massa_ferro := Vector3.ZERO
var _alivio_ferro := 0.2
# ACOG (wf/acog.glb) no trilho: base 5,3 cm abaixo do eixo óptico; [altura do trilho, z do centro] no espaço da Arma
const ACOG_TRILHO := {"ak47": [0.176, -0.03, -0.0044], "m4": [0.03, 0.02, -0.004], "m107": [0.05, -0.05, -0.025], "m249": [0.058, 0.05, -0.0097], "uzi": [0.05, -0.02, 0.0]}   # [y do trilho, z, x do centro do trilho]
const ACOG_ESCALA := 0.55           # o modelo do pacote é grande demais em primeira pessoa


func setup(s: Soldier) -> void:
	soldier = s
	pivot = Node3D.new(); pivot.name = "Pivot"; add_child(pivot)
	holder = Node3D.new(); holder.name = "Holder"; pivot.add_child(holder)
	_build_flash()
	_build_casings()
	s.weapon_switched.connect(_on_switch)
	s.fired.connect(_on_fired)
	s.reload_started.connect(_on_reload)
	s.knife_swung.connect(_on_knife)
	s.landed.connect(_on_landed)
	_on_switch(s.current_def())


func _build_flash() -> void:
	_flash = Node3D.new()
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.22, 0.22)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/viewmodel_flash.gdshader")
	var tp := "res://fx/textures/muzzle_flash.png"
	if ResourceLoader.exists(tp):
		m.set_shader_parameter("tex", load(tp))
	m.set_shader_parameter("viewmodel_fov", _vm_fov())   # mesmo FOV da arma: o clarão nasce na boca do cano
	qm.material = m
	mi.mesh = qm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 1 << 10
	_flash.add_child(mi)
	var mi2 := mi.duplicate()
	mi2.rotation.y = PI * 0.5
	_flash.add_child(mi2)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.72, 0.42)
	_flash_light.omni_range = 5.0
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	_flash.add_child(_flash_light)
	_flash.visible = false
	pivot.add_child(_flash)


func _build_casings() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0045
	cm.bottom_radius = 0.0045
	cm.height = 0.022
	cm.radial_segments = 6
	cm.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.66, 0.3)
	mat.metallic = 0.8
	mat.roughness = 0.35
	cm.material = mat
	_casing_mesh = cm
	for i in 10:
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.top_level = true
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_casings.append(mi)
		_casing_vel.append(Vector3.ZERO)
		_casing_life.append(0.0)


func _on_switch(def: WeaponDef) -> void:
	if def == null:
		# mãos vazias: some com o modelo e esquece o id (reequipar a mesma arma recarrega tudo)
		current_id = &""
		if scene_root:
			scene_root.queue_free()
		scene_root = null
		anim = null
		muzzle = null
		eject = null
		bolt = null
		optic = null
		_rig_skel = null
		return
	if def.id != current_id or scene_root == null:
		_load_weapon(def)
	_draw_len = def.draw_time
	_draw_t = 0.0
	_reload_t = -1.0
	_inspect_t = -1.0
	_ferrolho_t = -1.0
	_mosin_rec_t = -1.0
	_ferrolho_peso = 0.0
	_ferrolho_giro = 0.0
	_ferrolho_recuo = 0.0
	if _mosin_clip:
		_mosin_clip.visible = false
	if anim and anim.has_animation("draw"):
		anim.stop()
		anim.play("draw", 0.0, anim.get_animation("draw").length / maxf(def.draw_time, 0.1))
		anim.queue("idle")
		_draw_t = 1.0
	if soldier.is_local:
		var snd := "draw_" + String(def.id)
		Audio.play(snd if Audio.has_sound(snd) else "draw_generic", {"volume_db": -8.0})


func _load_weapon(def: WeaponDef) -> void:
	current_id = def.id
	if scene_root:
		scene_root.queue_free()
	scene_root = null
	anim = null
	muzzle = null
	eject = null
	bolt = null
	optic = null
	_ferrolho = null          # peças da Mosin morrem com o scene_root antigo
	_ferrolho_ik = null
	_mosin_clip = null
	var novo := _mira_cfg(def)
	_rig_skel = null
	if novo.has("rig") and ResourceLoader.exists(String(novo.rig)):
		_load_rig(def, novo)
		return
	var fp_path := def.model_path.replace(".tscn", "_fp.tscn")
	_wf = novo.has("modelo") and ResourceLoader.exists("res://assets/models/weapons/wf/%s_fp.tscn" % novo.modelo)
	if _wf:
		fp_path = "res://assets/models/weapons/wf/%s_fp.tscn" % novo.modelo   # armas do pacote Weapons FREE (Assets/)
	# C4: sem braços (a pegada central com os braços curtos do modelo cortava a manga na frente da câmera)
	var path := fp_path if ResourceLoader.exists(fp_path) and def.slot != WeaponDef.Slot.BOMB else def.model_path
	if not ResourceLoader.exists(path):
		return
	scene_root = load(path).instantiate()
	holder.add_child(scene_root)
	if path == fp_path and not novo.has("modelo"):
		if not _maos_rigidas(def):
			_swap_arms(scene_root)
	if path == def.model_path:
		# arma sem braços: posição de quadril padrão
		scene_root.position = Vector3(0.2, -0.21, -0.42) if def.slot != WeaponDef.Slot.KNIFE else Vector3(0.24, -0.24, -0.38)
		if def.slot == WeaponDef.Slot.BOMB:
			scene_root.position = Vector3(0.07, -0.21, -0.5)
			scene_root.scale = Vector3.ONE * 0.75
			scene_root.rotation = Vector3(deg_to_rad(28.0), deg_to_rad(-12.0), 0.0)
	anim = _find_anim(scene_root)
	muzzle = scene_root.find_child("Muzzle", true, false)
	eject = scene_root.find_child("Eject", true, false)
	bolt = scene_root.find_child("BoltAssembly", true, false)
	optic = scene_root.find_child("Optic", true, false)
	if bolt:
		_bolt_rest = bolt.position
	_carregador = null
	for n in scene_root.find_children("*", "Node3D", true, false):
		var nm := String(n.name).to_lower()
		if "magazine" in nm or "drum" in nm:
			_carregador = n as Node3D
			_carregador_rest = _carregador.position
			break
	_mao_e = scene_root.find_child("MaoE", true, false) as Node3D
	if _mao_e:
		_mao_e_rest = _mao_e.transform
	_setup_mira(def)
	_bolt_t = -1.0
	_convert_materials(scene_root)
	if anim and anim.has_animation("idle"):
		anim.play("idle")


## Rig de pack FPS (tools/lowpolyfy.py: braços + arma + animações reais, low poly). A câmera do pack (osso *Camera*) fica na
## origem do Holder (= olho), com deslocamento "rig_off" [x, y, z] m; "Arma" = BoneAttachment3D no osso da arma (cm do pack).
## Animações renomeadas para idle / fire / reload / reload_empty / draw. Sons/flash/coice continuam do ViewModel.
var _rig_skel: Skeleton3D


func _load_rig(def: WeaponDef, cfg: Dictionary) -> void:
	scene_root = Node3D.new()
	scene_root.name = "Rig"
	holder.add_child(scene_root)
	var pack: Node3D = load(String(cfg.rig)).instantiate()
	pack.name = "Pack"
	scene_root.add_child(pack)
	var sk := pack.find_children("*", "Skeleton3D", true, false)
	_rig_skel = sk[0] if sk.size() > 0 else null
	anim = _find_anim(pack)
	if anim:
		var lib := anim.get_animation_library("")
		var nomes := {"idle": "|idle|", "fire": "|fire|", "reload": "|reload|", "reload_empty": "|reload_empty|", "draw": "|draw|"}
		for curto in nomes:
			for a in anim.get_animation_list():
				var low := "|" + String(a).to_lower().replace("reloadempty", "reload_empty") + "|"
				if String(nomes[curto]) in low.replace("|baselayer|", "|") and not lib.has_animation(curto):
					lib.add_animation(curto, anim.get_animation(a))
		if anim.has_animation("idle"):
			anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("idle")
			anim.seek(0.0, true)
	if _rig_skel:
		var cb := -1
		var wb := -1
		for i in _rig_skel.get_bone_count():
			var n := _rig_skel.get_bone_name(i)
			if "camera" in n.to_lower():
				cb = i
			if n == String(cfg.get("osso", "Main")) + "_j" or (wb < 0 and n.begins_with(String(cfg.get("osso", "Main")))):
				wb = i
		var off: Array = cfg.get("rig_off", [0, 0, 0])
		_rig_cb = cb
		_rig_pack = pack
		_rig_off = Vector3(off[0], off[1], off[2])
		_rig_seguir_camera()
		if wb >= 0:
			var att := BoneAttachment3D.new()
			att.name = "Arma"
			_rig_skel.add_child(att)
			att.bone_name = _rig_skel.get_bone_name(wb)
			var mz: Array = cfg.get("muzzle", [0, 0, 50])
			var mk := Marker3D.new()
			mk.name = "Muzzle"
			mk.position = Vector3(mz[0], mz[1], mz[2])
			att.add_child(mk)
			muzzle = mk
			var ej: Array = cfg.get("eject", [2.5, 4, 2])
			var ek := Marker3D.new()
			ek.name = "Eject"
			ek.position = Vector3(ej[0], ej[1], ej[2])
			att.add_child(ek)
			eject = ek
	if cfg.has("troca") and _rig_skel and _rig_skel.has_node("Arma"):
		_rig_trocar_arma(cfg.troca)
	_ferrolho = null
	_ferrolho_ik = null
	if cfg.has("ferrolho_cfg") and _rig_skel and _rig_skel.has_node("Arma"):
		_mosin_montar(cfg.ferrolho_cfg)
	_carregador = null
	_mao_e = null
	var c2 := cfg.duplicate()
	if _rig_skel and _rig_skel.has_node("Arma"):
		c2["no"] = String(scene_root.get_path_to(_rig_skel.get_node("Arma")))
	_miras_rig = c2
	_setup_mira(def)
	_bolt_t = -1.0
	_convert_materials(scene_root)


var _miras_rig := {}
var _rig_cb := -1
var _rig_pack: Node3D
var _rig_off := Vector3.ZERO
var _rig_rec_w := 0.0


## Troca a arma do pack por outro modelo (mesmo esqueleto/animações: a mão direita no cabo, a esquerda no guarda-mão).
## troca = {"glb": modelo (frame wf: -Z boca, m), "t": [x,y,z] cm no osso Main, "mag": nó do carregador do modelo}.
## Peças do pack presas aos ossos da arma somem; o carregador do modelo vai para o osso Mag1 (o que sai) e uma cópia para o Mag2
## (o que entra), com o mesmo encaixe.
func _rig_trocar_arma(tr: Dictionary) -> void:
	var arma := _rig_skel.get_node("Arma") as BoneAttachment3D
	for mi in _rig_pack.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name != "Hand_Mesh":
			m.visible = false
	var modelo: Node3D = load(String(tr.glb)).instantiate()
	modelo.name = "Modelo"
	var esc := 100.0 * float(tr.get("esc", 1.0))
	var b := Basis(Vector3.UP, PI).scaled(Vector3.ONE * esc)
	var pos := Vector3.ZERO
	if tr.has("cabo"):   # a mão direita do pack (centro do punho, medido em tests/fp_rig_maos.gd) vai para o cabo do modelo
		var cb: Array = tr.cabo
		var punho: Array = tr.get("punho", [0.3, -11.0, -5.0])
		pos = Vector3(punho[0], punho[1], punho[2]) - b * Vector3(cb[0], cb[1], cb[2])
	else:
		var t: Array = tr.get("t", [0, 0, 0])
		pos = Vector3(t[0], t[1], t[2])
	modelo.transform = Transform3D(b, pos)
	arma.add_child(modelo)
	var k := float(tr.get("escurecer", 1.0))
	if k != 1.0:
		for g in modelo.find_children("*", "MeshInstance3D", true, false):
			var mi2 := g as MeshInstance3D
			for i in mi2.mesh.get_surface_count():
				var bm := mi2.get_active_material(i) as BaseMaterial3D
				if bm:
					var d2 := bm.duplicate() as BaseMaterial3D
					d2.albedo_color = Color(bm.albedo_color.r * k, bm.albedo_color.g * k, bm.albedo_color.b * k, bm.albedo_color.a)
					mi2.set_surface_override_material(i, d2)
	var nome_mag := String(tr.get("mag", ""))
	var mag := modelo.find_child(nome_mag, true, false) as Node3D if nome_mag != "" else null
	if mag == null:
		return
	# poses de descanso (Idle t=0) dos ossos
	var bm := -1
	var b1 := -1
	var b2 := -1
	for i in _rig_skel.get_bone_count():
		match _rig_skel.get_bone_name(i):
			"Main_j": bm = i
			"Mag1_j": b1 = i
			"Mag2_j": b2 = i
	if bm < 0 or b1 < 0:
		return
	var em_main := _rel(mag, arma)                                   # carregador no espaço do osso Main
	var main_g := _rig_skel.get_bone_global_pose(bm)
	var mag1_g := _rig_skel.get_bone_global_pose(b1)
	var local_mag := mag1_g.affine_inverse() * main_g * em_main       # encaixe relativo ao osso Mag1
	mag.get_parent().remove_child(mag)
	var a1 := BoneAttachment3D.new()
	a1.name = "Mag1"
	_rig_skel.add_child(a1)
	a1.bone_name = "Mag1_j"
	a1.add_child(mag)
	mag.transform = local_mag
	if b2 >= 0:
		var a2 := BoneAttachment3D.new()
		a2.name = "Mag2"
		_rig_skel.add_child(a2)
		a2.bone_name = "Mag2_j"
		var copia := mag.duplicate() as Node3D
		a2.add_child(copia)
		copia.transform = local_mag


## O osso da câmera do pack fica sempre no olho (os animadores enquadraram a recarga pela câmera deles: a arma vem à tela).
func _rig_seguir_camera() -> void:
	if _rig_skel == null or _rig_cb < 0 or _rig_pack == null:
		return
	var tc := _rel(_rig_skel, _rig_pack) * _rig_skel.get_bone_global_pose(_rig_cb)
	tc = Transform3D(tc.basis.orthonormalized(), tc.origin)
	# na recarga a arma volta ao enquadramento original do animador (rig_reload): troca de carregador e mãos à vista
	var recarregando := anim != null and anim.is_playing() and String(anim.current_animation).begins_with("reload")
	_rig_rec_w = move_toward(_rig_rec_w, 1.0 if recarregando else 0.0, get_process_delta_time() * 4.0)
	var ro: Array = _miras_rig.get("rig_reload", [0.0, 0.0, 0.0])
	var k := _rig_rec_w * _rig_rec_w * (3.0 - 2.0 * _rig_rec_w)
	var off := _rig_off.lerp(Vector3(ro[0], ro[1], ro[2]), k)
	_rig_pack.transform = Transform3D(Basis(), off) * tc.affine_inverse()


## Mãos/antebraços rígidos presos ao nó "Arma" (tools/build_fp_maos.py): esconde todo braço com esqueleto,
## assim nenhum ombro/braço cruza a linha de mira no ADS.
func _maos_rigidas(def: WeaponDef) -> bool:
	var base := def.model_path.get_file().get_basename()
	var p := "res://assets/models/weapons/maos_%s.glb" % base
	var arma := scene_root.find_child("Arma", true, false) as Node3D
	if not ResourceLoader.exists(p) or arma == null:
		return false
	var sk := scene_root.find_child("Skeleton3D", true, false)
	if sk:
		for c in sk.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
	var maos: Node3D = load(p).instantiate()
	maos.name = "MaosFP"
	arma.add_child(maos)
	return true


## Esconde os braços antigos e prende os do soldado ao Skeleton3D do próprio *_fp (mesmos 44 ossos, mesma pose de descanso).
func _swap_arms(root: Node) -> void:
	if not ResourceLoader.exists(ARMS_SCENE):
		return
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).name in OLD_ARM_MESHES:
			(c as MeshInstance3D).visible = false
			c.name = "_antigo_" + String(c.name)
	var src: Node = load(ARMS_SCENE).instantiate()
	var mi := src.find_child("BracosFP", true, false) as MeshInstance3D
	if mi:
		mi.get_parent().remove_child(mi)
		mi.owner = null
		sk.add_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.skeleton = NodePath("..")
		mi.name = "BracosSoldado"
	src.free()


static func _mira_cfg(def: WeaponDef) -> Dictionary:
	if _miras.is_empty() and FileAccess.file_exists(MIRAS_PATH):
		_miras = JSON.parse_string(FileAccess.get_file_as_string(MIRAS_PATH))
	return _miras.get(String(def.id), {})


func _setup_mira(def: WeaponDef) -> void:
	_mira_no = null
	_ads_ok = false
	_hip = Transform3D.IDENTITY
	luneta = false
	_acog_node = null
	var m: Dictionary = _miras_rig if _rig_skel != null else _mira_cfg(def)
	if m.is_empty() or scene_root == null:
		return
	_mira_no = scene_root.get_node_or_null(NodePath(String(m.no))) as Node3D
	if _mira_no == null:
		return
	var q: Dictionary = m.get("quadril", {})
	var qp: Array = q.get("pos", [0, 0, 0])
	var qr: Array = q.get("rot", [0, 0, 0])
	var qb := Basis.from_euler(Vector3(deg_to_rad(qr[0]), deg_to_rad(qr[1]), deg_to_rad(qr[2]))).scaled(Vector3.ONE * float(q.get("escala", 1.0)))
	_hip = Transform3D(qb, Vector3(qp[0], qp[1], qp[2]))
	if q.has("pivo"):   # gira em torno da alça (a arma "entra" na tela sem sair do lugar)
		var pv := Vector3(q.pivo[0], q.pivo[1], q.pivo[2])
		_hip_pivo = pv
		_hip = Transform3D(Basis(), Vector3(qp[0], qp[1], qp[2]) + pv) * Transform3D(qb, Vector3.ZERO) * Transform3D(Basis(), -pv)
	_alivio = float(m.get("alivio", 0.2))
	luneta = bool(m.get("luneta", false))
	if bool(m.get("auto", false)):
		_mira_auto(_mira_no as MeshInstance3D)
	else:
		_alca = Vector3(m.alca[0], m.alca[1], m.alca[2])
		_massa = Vector3(m.massa[0], m.massa[1], m.massa[2])
	_alca_ferro = _alca
	_massa_ferro = _massa
	_alivio_ferro = _alivio
	_aplicar_acog()


## ACOG instalada: modelo no trilho e linha de visada = eixo óptico (o overlay de tela faz o retículo).
func _aplicar_acog() -> void:
	if _acog_node:
		_acog_node.queue_free()
		_acog_node = null
	_alca = _alca_ferro
	_massa = _massa_ferro
	_alivio = _alivio_ferro
	_alternar_miras_abertas(true)
	if _rig_skel != null:
		_rig_ferro(true)
		_aplicar_mira_rig()
		return
	var t: Array = ACOG_TRILHO.get(String(current_id), [])
	var arq := "res://assets/models/weapons/wf/%s.glb" % ("acog" if acog_installed else "reddot")
	if not (acog_installed or reddot_installed) or t.is_empty() or _mira_no == null or not ResourceLoader.exists(arq):
		return
	_acog_node = load(arq).instantiate()
	_mira_no.add_child(_acog_node)
	_convert_materials(_acog_node)
	_alternar_miras_abertas(false)   # uma só mira: com ACOG/holográfica instalada, alça e massa do modelo somem
	if reddot_installed:
		_acog_node.position = Vector3(float(t[2]), float(t[0]) - 0.008, float(t[1]))   # base do modelo no trilho (tamanho real, 10 cm)
		var janela := _acog_node.position + Vector3(0, 0.047, 0.0443)             # centro da janela (medido no modelo)
		_alca = janela
		_massa = janela + Vector3(0, 0, -0.2)
		_alivio = 0.2
	else:
		_acog_node.scale = Vector3.ONE * ACOG_ESCALA
		_acog_node.position = Vector3(float(t[2]), float(t[0]) + 0.038 * ACOG_ESCALA, float(t[1]))   # base no trilho
		var eixo := _acog_node.position + Vector3(0, 0.011 * ACOG_ESCALA, 0)   # eixo óptico (centro do tubo)
		_alca = eixo + Vector3(0, 0, 0.1)
		_massa = eixo + Vector3(0, 0, -0.1)
		_alivio = 0.1
	_assentar_mira()
	_ads_ok = false


## Miras no rig de pack (espaço do osso da arma em cm, +Z = boca, +Y = cima). "trilho" = [x, y do topo do trilho, z] cm.
## Holográfica: wf/../fp/holo_lp.glb (Fab "Holographic Sight", low poly) — eixo do modelo = +X, base em y -0,0388 m,
## centro da janela em y 0,0511 m. ACOG: wf/acog.glb (eixo -Z, base 3,8 cm abaixo do eixo óptico).
const HOLO_GLB := "res://assets/models/fp/holo_lp.glb"
const HOLO_ESC := Vector3(0.9, 0.9, 0.9)   # modelo em tamanho real (EXPS3 ~7,2 cm de altura com a base)


func _aplicar_mira_rig() -> void:
	var t: Array = _miras_rig.get("trilho", [])
	if t.is_empty() or _mira_no == null or not (acog_installed or reddot_installed):
		return
	var base := Vector3(float(t[0]), float(t[1]), float(t[2]))
	if reddot_installed:
		_acog_node = load(HOLO_GLB).instantiate()
		var k := HOLO_ESC * 100.0
		# medidas do modelo (tests/ver_modelo.tscn, vista frontal, pixels -> m): base visível em y 0 (a AABB vai a -0,039 por
		# vértices soltos invisíveis), centro da janela em y 0,0509, janela 3,7 x 2,8 cm
		base.y += float(_miras_rig.get("holo_riser", 0.0)) + float(Game.test_args.get("hdy", "0"))
		_acog_node.scale = k
		_acog_node.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		_acog_node.position = base
		var janela := base + Vector3(0.0, 0.0509 * k.y, 0.0)
		_alca = janela
		_massa = janela + Vector3(0, 0, 20.0)
		_alivio = float(_miras_rig.get("alivio_holo", 0.26))
	else:
		_acog_node = load("res://assets/models/weapons/wf/acog.glb").instantiate()
		var k2 := 100.0 * ACOG_ESCALA
		_acog_node.scale = Vector3.ONE * k2
		_acog_node.rotation = Vector3(0.0, PI, 0.0)
		_acog_node.position = base + Vector3(0.0, 0.038 * k2, 0.0)
		var eixo := _acog_node.position + Vector3(0, 0.011 * k2, 0)
		_alca = eixo
		_massa = eixo + Vector3(0, 0, 20.0)
		_alivio = float(_miras_rig.get("alivio_acog", 0.12))
	_mira_no.add_child(_acog_node)
	_convert_materials(_acog_node)
	_rig_ferro(false)
	_alternar_miras_abertas(false)
	_assentar_mira()
	_ads_ok = false


## Assenta a óptica instalada (_acog_node) na arma, medindo a malha (nada de medida chutada; tests/holo_offset.tscn confere):
## (1) a base da óptica (vértice mais baixo usado por triângulos — o glb tem vértices soltos) desce/sobe até a superfície mais
## alta da arma sob a pegada (raio vertical contra os triângulos numa grade 7x9), e (2) o centro da óptica vai para o eixo do
## cano (centro x da ponta do cano, últimos 4 cm). A linha de visada (_alca/_massa) acompanha. Cache por arma + tipo de óptica.
static var _assento_cache := {}


func _assentar_mira() -> void:
	if _acog_node == null or _mira_no == null:
		return
	var chave := "%s|%s" % [current_id, "holo" if reddot_installed else "acog"]
	var d: Vector3
	if _assento_cache.has(chave):
		d = _assento_cache[chave]
	else:
		d = _medir_assento()
		_assento_cache[chave] = d
	_acog_node.position += d
	_alca += d
	_massa += d


func _medir_assento() -> Vector3:
	var k := 1.0 if _rig_skel != null else 100.0   # unidades do nó da arma por cm (rig do pack em cm, wf em m)
	var inv := _mira_no.global_transform.affine_inverse()
	var mv := PackedVector3Array()
	for mi in _acog_node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var xf := inv * m.global_transform
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
			for i in ix:
				mv.append(xf * vs[i])
	if mv.is_empty():
		return Vector3.ZERO
	var ymin := INF
	for v in mv:
		ymin = minf(ymin, v.y)
	var x0 := INF; var x1 := -INF; var z0 := INF; var z1 := -INF
	for v in mv:
		if v.y < ymin + 0.6 / k:
			x0 = minf(x0, v.x); x1 = maxf(x1, v.x); z0 = minf(z0, v.z); z1 = maxf(z1, v.z)
	# triângulos da arma no espaço do nó da arma (malha com skin do pack: bind do osso da arma; sem mãos, sem a óptica)
	var tris := []
	var osso := String(_miras_rig.get("osso", "Main"))
	for g in scene_root.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or _acog_node.is_ancestor_of(mi) or not _visivel_em(mi, scene_root):
			continue
		var nm := String(mi.name).to_lower()
		if "hand" in nm or "mao" in nm:
			continue
		var xf := inv * mi.global_transform
		if mi.skin != null:
			if String(mi.name) != "Main":
				continue
			for i in mi.skin.get_bind_count():
				if String(mi.skin.get_bind_name(i)).begins_with(osso):
					xf = mi.skin.get_bind_pose(i)
		elif not _mira_no.is_ancestor_of(mi):
			continue
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
			for t in range(0, ix.size() - 2, 3):
				tris.append([xf * vs[ix[t]], xf * vs[ix[t + 1]], xf * vs[ix[t + 2]]])
	if tris.is_empty():
		return Vector3.ZERO
	# eixo do cano: centro x da ponta (rig: +Z boca; wf: -Z boca)
	var fr := 1.0 if _rig_skel != null else -1.0
	var zf := -INF
	for t in tris:
		for v: Vector3 in t:
			zf = maxf(zf, v.z * fr)
	var bx0 := INF; var bx1 := -INF
	for t in tris:
		for v: Vector3 in t:
			if v.z * fr > zf - 4.0 / k:
				bx0 = minf(bx0, v.x); bx1 = maxf(bx1, v.x)
	var dx := (bx0 + bx1) * 0.5 - (x0 + x1) * 0.5
	# superfície sob a pegada já deslocada para o eixo do cano
	var topo := -INF
	for ia in 7:
		for ib in 9:
			var px := lerpf(x0, x1, 0.1 + 0.8 * ia / 6.0) + dx
			var pz := lerpf(z0, z1, 0.1 + 0.8 * ib / 8.0)
			topo = maxf(topo, _altura_sob(tris, px, pz, ymin + 3.0 / k))
	var dy := 0.0 if topo == -INF else topo - ymin
	return Vector3(dx, dy, 0.0)


static func _visivel_em(n: Node, raiz: Node) -> bool:
	var c := n
	while c != null and c != raiz:
		if c is Node3D and not (c as Node3D).visible:
			return false
		c = c.get_parent()
	return true


## Maior altura de superfície (y) dos triângulos no ponto (x, z), abaixo de y_max.
static func _altura_sob(tris: Array, x: float, z: float, y_max: float) -> float:
	var best := -INF
	for t in tris:
		var a: Vector3 = t[0]; var b: Vector3 = t[1]; var c: Vector3 = t[2]
		var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-9:
			continue
		var u := ((b.x - x) * (c.z - z) - (c.x - x) * (b.z - z)) / d
		var v := ((c.x - x) * (a.z - z) - (a.x - x) * (c.z - z)) / d
		var w := 1.0 - u - v
		if u < 0.0 or v < 0.0 or w < 0.0:
			continue
		var y := u * a.y + v * b.y + w * c.y
		if y <= y_max and y > best:
			best = y
	return best


## Rebate a alça e a massa da própria arma do pack quando há óptica (caixas em cm no osso da arma: "ferro_caixas").
var _ferro_orig := {}


func _rig_ferro(mostrar: bool) -> void:
	var caixas: Array = _miras_rig.get("ferro_caixas", [])
	if caixas.is_empty() or _rig_pack == null:
		return
	for g in _rig_pack.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.name != "Main" or mi.skin == null:
			continue
		if not _ferro_orig.has(mi):
			_ferro_orig[mi] = mi.mesh
		var orig: ArrayMesh = _ferro_orig[mi]
		if mostrar:
			mi.mesh = orig
			continue
		var bind := Transform3D.IDENTITY
		for i in mi.skin.get_bind_count():
			if mi.skin.get_bind_name(i) == "Main_j":
				bind = mi.skin.get_bind_pose(i)
		var novo := ArrayMesh.new()
		for si in orig.get_surface_count():
			var arr := orig.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var fica := PackedInt32Array()
			for t in range(0, ix.size(), 3):
				var dentro := true
				for q in 3:
					var v := bind * vs[ix[t + q]]
					var ok := false
					for c in caixas:
						if v.x >= c[0] and v.y >= c[1] and v.z >= c[2] and v.x <= c[3] and v.y <= c[4] and v.z <= c[5]:
							ok = true
					dentro = dentro and ok
				if not dentro:
					fica.append_array([ix[t], ix[t + 1], ix[t + 2]])
			arr[Mesh.ARRAY_INDEX] = fica
			novo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			novo.surface_set_material(si, orig.surface_get_material(si))
		mi.mesh = novo
		for si in novo.get_surface_count():
			var ov := mi.get_surface_override_material(si)
			if ov == null:
				pass


## Liga/desliga as malhas de mira aberta do modelo (peças separadas: iron_*, *Sight*).
func _alternar_miras_abertas(ligar: bool) -> void:
	if _mira_no == null:
		return
	for g in _mira_no.find_children("*", "MeshInstance3D", true, false):
		var nm := String(g.name).to_lower()
		if nm.begins_with("iron_") or nm.ends_with("sight") or nm.ends_with("rear_sight"):
			(g as MeshInstance3D).visible = ligar


## Pistolas: alça = vértice mais alto do quarto traseiro da malha, massa = mais alto dos 15% dianteiros (no eixo x = 0).
func _mira_auto(mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null:
		_mira_no = null
		return
	var bb := mi.mesh.get_aabb()
	var z0 := bb.position.z
	var z1 := bb.end.z
	var frente := -INF
	var tras := -INF
	var zf := z0
	var zt := z1
	for si in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			if v.z < z0 + (z1 - z0) * 0.15 and v.y > frente:
				frente = v.y
				zf = v.z
			elif v.z > z1 - (z1 - z0) * 0.25 and v.y > tras:
				tras = v.y
				zt = v.z
	_massa = Vector3(0.0, frente, zf)
	_alca = Vector3(0.0, tras, zt)


## Pose do Holder que põe a alça no eixo da câmera a _alivio m do olho e a linha alça->massa exatamente em -Z (centro
## da tela, independente do FOV). Calculada com o Holder na pose de quadril e a arma na pose atual (idle).
func _calc_ads_pose() -> void:
	if _mira_no == null or scene_root == null:
		return
	var rel := _rel(_mira_no, holder)
	var r := rel * _alca
	var f := rel * _massa
	var fwd := (f - r).normalized()
	var up := (rel.basis * Vector3.UP).normalized()
	var zb := -fwd
	var yb := (up - zb * up.dot(zb)).normalized()
	var xb := yb.cross(zb)
	var b := Basis(xb, yb, zb).transposed()   # leva o referencial da mira ao da câmera
	_ads_pose = Transform3D(b, Vector3(0.0, 0.0, -_alivio) - b * r)
	_ads_ok = true


## Marcas de mira no espaço da câmera (para o gate M1 e depuração).
func sight_points_camera() -> Array:
	if _mira_no == null:
		return []
	var t := _rel(_mira_no, self)
	return [t * _alca, t * _massa]


## Transformação de n no espaço do ancestral (encadeando as locais; não depende do cache global da câmera top_level).
static func _rel(n: Node, ancestral: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != ancestral and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _find_anim(c)
		if a:
			return a
	return null


func _convert_materials(n: Node) -> void:
	if n is MeshInstance3D and not n.has_meta("vm_convertido"):   # a ACOG é convertida ao ser acoplada; converter de novo perdia a textura (bloco branco)
		var mi := n as MeshInstance3D
		mi.set_meta("vm_convertido", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 1 << 10
		for i in mi.mesh.get_surface_count() if mi.mesh else 0:
			var src: Material = mi.get_active_material(i)
			var sm := ShaderMaterial.new()
			sm.shader = VM_SHADER
			if src is BaseMaterial3D:
				var b := src as BaseMaterial3D
				sm.set_shader_parameter("albedo_color", b.albedo_color)
				if VM_ESCURECER.has(String(current_id)) and _sob_modelo(mi):
					sm.set_shader_parameter("albedo_color", Color(b.albedo_color.r, b.albedo_color.g, b.albedo_color.b, b.albedo_color.a) * VM_ESCURECER[String(current_id)])
				if b.albedo_texture:
					sm.set_shader_parameter("albedo_tex", b.albedo_texture)
				# manga sempre na cor do time de quem segura (faca/C4 e armas pegadas do chão vêm com a de outro time)
				if b.resource_name.begins_with("Manga"):
					var sleeve := "res://assets/models/weapons/manga_%s.png" % ("counter" if soldier.team == 1 else "terrorist")
					if BodyModel.SOLDIER_FOR_ALL and ResourceLoader.exists(SLEEVE_TEX):
						sleeve = SLEEVE_TEX        # manga camuflada do soldado (mata geométrica)
						sm.set_shader_parameter("albedo_color", Color(1.25, 1.25, 1.2))
						sm.set_shader_parameter("emission_color", Color(0.20, 0.22, 0.15))   # manga sempre legível (sol nas costas deixa o antebraço no escuro)
					if ResourceLoader.exists(sleeve):
						sm.set_shader_parameter("albedo_tex", load(sleeve))
				sm.set_shader_parameter("roughness", b.roughness)
				sm.set_shader_parameter("metallic", b.metallic)
				var orm_t: Texture2D = b.roughness_texture if b.roughness_texture else b.metallic_texture
				if orm_t:
					sm.set_shader_parameter("orm_tex", orm_t)
					sm.set_shader_parameter("use_orm", true)
				if b.emission_enabled:
					sm.set_shader_parameter("emission_color", b.emission * b.emission_energy_multiplier)
			sm.set_shader_parameter("viewmodel_fov", _vm_fov())
			mi.set_surface_override_material(i, sm)
	for c in n.get_children():
		_convert_materials(c)


const VM_ESCURECER := {"ak47": Color(0.34, 0.37, 0.43, 1.0)}     # a cobertura/guarda-mão claros estouravam para branco sob o sol (referência: AK cinza-azulado escuro)


func _sob_modelo(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p.name == "Modelo":
			return true
		p = p.get_parent()
	return false


## Retículo da holográfica como colimador de verdade: o ponto fica no infinito ao longo do eixo óptico da mira
## (direção alça -> massa no nó da arma), projetado com o FOV do viewmodel (o mesmo do shader que desenha a arma).
## Coice/balanço que giram a arma movem o ponto; translação pura não (infinito). Também devolve a janela da mira
## projetada (3,3 x 2,5 cm, holográfica em tamanho real), para o ponto só aparecer através do vidro.
const HOLO_JANELA_M := Vector2(0.0167, 0.0126)   # meia largura/altura da janela (m, já na escala 0,9)


func reticulo_holo(cam: Camera3D, tela: Vector2) -> Dictionary:
	if not reddot_installed or _mira_no == null or cam == null or _acog_node == null:
		return {"ok": false}
	var inv := cam.global_transform.affine_inverse()
	var g := _mira_no.global_transform
	var d := inv.basis * (g.basis * (_massa - _alca)).normalized()
	if d.z >= -0.01:
		return {"ok": false}
	var f := 1.0 / tan(deg_to_rad(_vm_fov()) * 0.5)
	var meio := tela * 0.5
	var proj := func(v: Vector3) -> Vector2:
		return meio + Vector2(v.x / -v.z, -v.y / -v.z) * f * tela.y * 0.5
	var pos: Vector2 = proj.call(d)
	var u := 100.0 if _rig_skel != null else 1.0
	var c := inv * (g * _alca)
	var dx := inv * (g * (_alca + Vector3(HOLO_JANELA_M.x * u, 0, 0)))
	var dy := inv * (g * (_alca + Vector3(0, HOLO_JANELA_M.y * u, 0)))
	if c.z >= -0.01:
		return {"ok": false}
	var pc: Vector2 = proj.call(c)
	var hw := absf((proj.call(dx) as Vector2).x - pc.x)
	var hh := absf((proj.call(dy) as Vector2).y - pc.y)
	return {"ok": true, "pos": pos, "janela": Rect2(pc - Vector2(hw, hh), Vector2(hw, hh) * 2.0)}


func _vm_fov() -> float:
	return Settings.vertical_fov(Settings.viewmodel_fov)


func _on_fired(def: WeaponDef) -> void:
	if def.id == &"mosin":
		_bolt_t = 0.0
		if _ferrolho:
			_ferrolho_t = 0.0          # ciclo do ferrolho com a mão direita (_mosin_process)
			_ferrolho_ejetou = false
			_mosin_rec_t = -1.0
	# referência: pistola sobe ~5° e recua ~3,5 cm (pico 0,03 s, volta 0,18 s); rifle menos por tiro (rajada soma)
	var pistol := def.slot == WeaponDef.Slot.PISTOL
	# a animação "fire" do viewmodel já sobe ~4°: a mola soma pouco e é limitada (QA: pistola passava de 30°)
	_kick_vel += 7.0 if pistol else 5.0
	# coice angular por mola: sobe em ~70 ms e volta em ~200 ms (pico ~1,2 por tiro; rajada soma até o limite)
	_kick_rot_vel += 48.0 if pistol else 40.0
	_inspect_t = -1.0
	if anim:
		var name := "fire"
		if anim.has_animation(name):
			anim.stop()
			anim.play(name)
			anim.queue("idle")
	_show_flash(def)
	if def.shell_eject and not (_ferrolho and def.id == &"mosin"):   # Mosin: a cápsula sai quando o ferrolho recua
		_eject_casing(def)
	if soldier.is_local and TiroSom.tem(def):
		TiroSom.tocar(self, soldier, def, true, Vector3.ZERO)
	elif soldier.is_local:
		Audio.play(def.fire_sound + "_1p" if Audio.has_sound(def.fire_sound + "_1p") else def.fire_sound, {"volume_db": -1.0, "pitch_var": 0.025})
		# camadas de simulador (tools/sintetizar_tiros.py): estampido grave no peito + cauda com ecos do terreno
		var fam := _familia_som(def)
		if Audio.has_sound(fam + "_boom"):
			Audio.play(fam + "_boom", {"volume_db": 1.5, "pitch_var": 0.04})
		if Audio.has_sound(fam + "_cauda"):
			Audio.play(fam + "_cauda", {"volume_db": -7.0, "pitch_var": 0.05})
		if soldier.current() and soldier.current().mag <= 3 and soldier.current().mag >= 0:
			Audio.play("low_ammo_click", {"volume_db": -12.0})


static func _familia_som(def: WeaponDef) -> String:
	match def.id:
		&"ak47", &"m4", &"m249", &"uzi", &"glock", &"usp", &"mosin", &"m107":
			return "reais"      # tiros gravados (tools/audio_usuario.py) já são completos: sem camadas *_boom/*_cauda sintetizadas
	return "pistol"


func _show_flash(def: WeaponDef) -> void:
	var t := Transform3D.IDENTITY
	if muzzle:
		t = _rel(muzzle, pivot)   # cadeia local (o global de filhos da câmera top_level chega defasado)
	else:
		t.origin = Vector3(0.2, -0.14, -0.95)
	_flash.transform = t
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * def.muzzle_scale * randf_range(0.85, 1.15)
	_flash.visible = true
	_flash_t = 0.06
	_flash_quadros = 2   # aparece em pelo menos 2 quadros mesmo com quadro lento
	_flash_light.light_energy = 2.2


func _eject_casing(def: WeaponDef) -> void:
	var c := _casings[_casing_i]
	_casing_life[_casing_i] = 1.2
	var origin: Vector3
	if eject:
		origin = eject.global_position
	else:
		origin = global_transform * Vector3(0.18, -0.1, -0.35)
	var right := global_transform.basis.x
	var up := global_transform.basis.y
	var back := global_transform.basis.z
	c.global_position = origin
	c.scale = Vector3.ONE * def.casing_scale
	c.global_basis = Basis(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
	_casing_vel[_casing_i] = right * randf_range(1.6, 2.4) + up * randf_range(1.2, 2.0) + back * randf_range(0.2, 0.7) + soldier.velocity
	c.visible = true
	_casing_i = (_casing_i + 1) % _casings.size()


func _on_reload(def: WeaponDef) -> void:
	_reload_len = def.reload_time
	_reload_t = 0.0
	_inspect_t = -1.0
	_bolt_t = -1.0
	if bolt:
		bolt.position = _bolt_rest
	if _ferrolho and def.id == &"mosin":
		# recarga por clip (ferrolho/clip/polegar em _mosin_recarga_passo); a recarga de carregador da M4 não roda
		_reload_t = -1.0
		_mosin_recarga_iniciar(def)
		if soldier.is_local:
			Audio.play("reload_mosin" if Audio.has_sound("reload_mosin") else "reload_generic", {"volume_db": -4.0})
		return
	if anim and anim.has_animation("reload"):
		anim.stop()
		anim.play("reload", 0.05, anim.get_animation("reload").length / maxf(def.reload_time, 0.1))
		anim.queue("idle")
		_reload_t = -1.0
	if soldier.is_local:
		var snd := "reload_" + String(def.id)
		Audio.play(snd if Audio.has_sound(snd) else "reload_generic", {"volume_db": -4.0})


## Recarga com movimento extraído do pack "m4 - fps weapon animations" (Assets, Reload 24 fps; tools raw/reddot/extrair_recarga.py):
## arma (deslocamento + rotação, até 33°), mão de apoio (posição relativa ao guarda-mão) e carregador, em eixos da arma
## (x direita, y cima, z trás). Os 71 primeiros quadros (a parte ativa) são esticados para def.reload_time.
static var _rec: Dictionary = {}


static func _recarga_dados() -> Dictionary:
	if _rec.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/weapons/recarga_fps.json"))
		if j is Dictionary:
			_rec = j
	return _rec


static func _amostra(arr: Array, f: float) -> Array:
	var i := clampi(int(floor(f)), 0, arr.size() - 1)
	var j := mini(i + 1, arr.size() - 1)
	var t: float = f - float(i)
	var a: Array = arr[i]
	var b: Array = arr[j]
	var r: Array = []
	for k in a.size():
		r.append(lerpf(float(a[k]), float(b[k]), t))
	return r


var _recarga_q := Quaternion.IDENTITY


func _recarga_maos(p: float, off: Vector3) -> Vector3:
	var d := _recarga_dados()
	if d.is_empty():
		return off
	var f := clampf(p, 0.0, 1.0) * float(int(d.n) - 1)
	var ap := _amostra(d.arma_p, f)
	var aq := _amostra(d.arma_q, f)
	var q := Quaternion(aq[0], aq[1], aq[2], aq[3]).normalized()
	var peso := smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.96, 1.0, p))      # entra/sai suave do quadril
	_recarga_q = Quaternion.IDENTITY.slerp(q, peso * 0.3)
	var arma := _mao_e.get_parent().get_parent() as Node3D
	var pai := _carregador.get_parent() as Node3D
	var pm := _rel(pai, arma)
	var mp := _amostra(d.mao_p, f)
	_mao_e.transform = Transform3D(_mao_e_rest.basis, _mao_e_rest.origin + Vector3(mp[0], mp[1], mp[2]) * peso)
	var gp := _amostra(d.mag_p, f)
	var visivel := not (f > 27.0 and f < 33.0)          # o antigo cai e o novo aparece de baixo (cruzamento dos dois caminhos)
	_carregador.visible = visivel
	_carregador.position = _carregador_rest + pm.basis.inverse() * (Vector3(gp[0], gp[1], gp[2]) * peso)
	return off + (Vector3(ap[0], ap[1], ap[2]) + Vector3(-0.05, 0.05, 0.05)) * peso   # leve levantada: a mão de apoio entra no quadro


func _on_knife(heavy: bool, hit: bool) -> void:
	_swing_heavy = heavy
	_swing_t = 0.0
	_swing_side = -_swing_side
	if anim:
		var name := "stab" if heavy else ("slash_a" if _swing_side > 0.0 else "slash_b")
		if anim.has_animation(name):
			anim.stop()
			anim.play(name)
			anim.queue("idle")
			_swing_t = -1.0
	if soldier.is_local:
		Audio.play("knife_swing", {"volume_db": -6.0, "pitch_var": 0.08})


func _on_landed(impact: float) -> void:
	_land_vel -= clampf(impact * 0.012, 0.0, 0.12)


func inspect() -> void:
	if anim and anim.has_animation("inspect"):
		anim.play("inspect")
		anim.queue("idle")
	else:
		_inspect_t = 0.0


func look_delta(d: Vector2) -> void:
	_sway_target += d


func set_ads(amount: float, acog: bool) -> void:
	ads_amount = clampf(amount, 0.0, 1.0)
	ads_acog = acog
	_update_optic_visibility()


## Mira instalada na arma da mão: "", "acog" ou "reddot".
func set_mira(kind: String) -> void:
	var a := kind == "acog"
	var r := kind == "reddot"
	if a != acog_installed or r != reddot_installed:
		acog_installed = a
		reddot_installed = r
		_aplicar_acog()
	_update_optic_visibility()


func _update_optic_visibility() -> void:
	if optic:
		# uma só mira: com a ACOG em uso a imagem é a do overlay de tela (luneta); o modelo 3D da ACOG some ao mirar
		optic.visible = acog_installed and ads_amount < 0.3


func set_viewmodel_enabled(enabled: bool) -> void:
	viewmodel_enabled = enabled
	visible = enabled and (soldier == null or soldier.alive)


func _process(dt: float) -> void:
	if soldier == null:
		return
	_time += dt
	if current_id == &"mosin":
		_update_optic_visibility()
		if bolt and _bolt_t >= 0.0:
			_bolt_t += dt
			var cycle := clampf((_bolt_t - 0.13) / 0.72, 0.0, 1.0)
			bolt.position = _bolt_rest + Vector3(0, 0, 0.085 * sin(cycle * PI))
			if cycle >= 1.0:
				_bolt_t = -1.0
		_mosin_process(dt)
	_rig_seguir_camera()
	if _mira_no:
		# recalcula com a arma na pose de repouso (idle, inclusive em ADS: anula o balanço do idle e a mira fica parada);
		# durante tiro/recarga/saque congela a pose, para o coice da animação continuar visível
		if anim == null or not anim.is_playing() or anim.current_animation == "idle":
			_calc_ads_pose()
		var k := ads_amount * ads_amount * (3.0 - 2.0 * ads_amount)
		holder.transform = _hip.interpolate_with(_ads_pose, k) if _ads_ok else _hip
		if _recarga_dip > 0.001:
			# recarga: arma cantada ~30° para a direita e boca um pouco para cima, girando em volta da alça
			var b := Basis(Vector3.BACK, -0.5 * _recarga_dip) * Basis(Vector3.RIGHT, 0.12 * _recarga_dip)
			if _mao_e and _carregador:
				b = Basis(_recarga_q)
			holder.transform = Transform3D(b, _hip_pivo - b * _hip_pivo) * holder.transform
		if current_id == &"mosin" and (absf(_mosin_rolo) > 0.0001 or _mosin_rot.length() > 0.0001):
			# Mosin: cantar o rifle em volta do próprio cano (no receptor), não em volta do olho
			var eixo_c := (holder.transform.basis * Vector3(0, 0, 1)).normalized()
			var rec_c := holder.transform * _hip_pivo
			var k_m := 1.0 - ads_amount
			var rb := Basis.from_euler(Vector3(_mosin_rot.x, _mosin_rot.y, 0.0) * k_m) * Basis(eixo_c, _mosin_rolo * k_m)
			holder.transform = Transform3D(rb, rec_c - rb * rec_c) * holder.transform
	else:
		holder.transform = Transform3D.IDENTITY
	visible = soldier.alive and viewmodel_enabled and not ((luneta or (ads_acog and not acog_dot and _acog_node != null)) and ads_amount > 0.92)
	# --- sway (atraso do mouse) ---
	_sway_target = _sway_target.lerp(Vector2.ZERO, clampf(dt * 10.0, 0.0, 1.0))
	_sway = _sway.lerp(_sway_target.limit_length(40.0), clampf(dt * 12.0, 0.0, 1.0))
	# --- bob ---
	var grounded := soldier.is_on_floor()
	# balanço da arma na passada (referência: ±1 cm vertical, ±1,5 cm lateral, ±1° pitch, ±1,2° yaw, ±2° roll, abaixa 1,5 cm correndo)
	var mira_fixa := 1.0 - 0.9 * ads_amount   # em ADS a alça/massa não pode dançar na tela
	var ga := gait_amount * Settings.viewmodel_bob * mira_fixa
	var ph := gait_phase
	var bob := Vector3(sin(ph) * 0.015, (absf(sin(ph)) - 0.637) * 0.02 - 0.015 * ga, 0.0) * ga
	if not grounded:
		bob.y -= 0.004
	var bob_rot := Vector3(sin(ph * 2.0) * deg_to_rad(1.0), sin(ph) * deg_to_rad(1.2), sin(ph) * deg_to_rad(2.0)) * ga
	var breath := Vector3(0.0, sin(_time * 1.6) * 0.0022, 0.0) * mira_fixa
	# --- kick (mola) ---
	_molas(dt)
	# --- estados ---
	var off := Vector3.ZERO
	var rot := Vector3.ZERO
	if _draw_t < 1.0:
		_draw_t = minf(_draw_t + dt / maxf(_draw_len * 0.6, 0.05), 1.0)
		var e := 1.0 - pow(1.0 - _draw_t, 3.0)
		off.y -= (1.0 - e) * 0.22
		rot.x -= (1.0 - e) * 0.9
	if _reload_t >= 0.0:
		_reload_t += dt
		var p := clampf(_reload_t / _reload_len, 0.0, 1.0)
		var dip := sin(p * PI)
		# a inclinação é em volta da própria arma (ver _recarga_inclina); aqui só aproxima e desce um pouco
		if _mao_e and _carregador and current_id != &"usp":
			off = _recarga_maos(p, off)
			_recarga_dip = 1.0
		else:
			off.y -= dip * 0.02
			off.z += dip * 0.02
		if p > 0.82 and not _mao_e:   # 3ª fase: puxa o ferrolho/encaixa — solavanco curto para cima no fim da recarga
			off.z += sin((p - 0.82) / 0.18 * PI) * 0.035
			rot.x += sin((p - 0.82) / 0.18 * PI) * 0.07
		if _carregador and not _mao_e and current_id != &"usp":
			# 15–40%: carregador sai para baixo e some; 55–80%: o novo sobe e encaixa (-Z do nó importado = baixo)
			var saida := smoothstep(0.15, 0.4, p) * (1.0 - smoothstep(0.55, 0.8, p))
			_carregador.position = _carregador_rest + Vector3(0.0, 0.0, -0.35) * saida
			_carregador.visible = saida < 0.9
		if p >= 1.0:
			_reload_t = -1.0
			_recarga_dip = 0.0
			if _carregador:
				_carregador.position = _carregador_rest
				_carregador.visible = true
			if _mao_e:
				_mao_e.transform = _mao_e_rest
			_recarga_q = Quaternion.IDENTITY
	if _swing_t >= 0.0:
		_swing_t += dt
		var dur := 0.55 if _swing_heavy else 0.32
		var p2 := clampf(_swing_t / dur, 0.0, 1.0)
		var arc := sin(p2 * PI)
		if _swing_heavy:
			off.z -= arc * 0.18
			rot.x -= arc * 0.25
		else:
			off.x -= arc * 0.12 * _swing_side
			rot.y += arc * 0.9 * _swing_side
			rot.z += arc * 0.5 * _swing_side
		if p2 >= 1.0:
			_swing_t = -1.0
	if _inspect_t >= 0.0:
		_inspect_t += dt
		var p3 := clampf(_inspect_t / 2.4, 0.0, 1.0)
		var e3 := sin(p3 * PI)
		rot.z += e3 * 0.9
		rot.y += e3 * 0.5
		off.x -= e3 * 0.05
		if p3 >= 1.0:
			_inspect_t = -1.0
	var planting := soldier.planting > 0.0
	_lower = lerpf(_lower, 1.0 if planting else 0.0, clampf(dt * 8.0, 0.0, 1.0))
	off.y -= _lower * 0.12
	rot.x -= _lower * 0.6
	# sprint: arma abaixada e cantada para dentro (pose de corrida); volta em ~0,2 s, o mesmo bloqueio de tiro do Soldier
	var corre := bool(soldier.get("is_sprinting")) and ads_amount < 0.05
	_sprint_w = move_toward(_sprint_w, 1.0 if corre else 0.0, dt / 0.18)
	var spw := _sprint_w * _sprint_w * (3.0 - 2.0 * _sprint_w)
	off += Vector3(-0.035, -0.012, 0.02) * spw
	rot += Vector3(-0.07, 0.3, 0.14) * spw
	# crouch aproxima a arma
	off += Vector3(-0.01, 0.006, 0.01) * soldier.crouch
	if current_id == &"mosin":
		off += _mosin_off * (1.0 - ads_amount)
	var sw := _sway * mira_fixa
	pivot.position = off + bob + breath + Vector3(0.0, _land, _kick * 0.12) + Vector3(-sw.x, sw.y, 0.0) * 0.0009
	pivot.rotation = rot + bob_rot + Vector3(_kick_rot * 0.028 + sw.y * 0.0015, sw.x * 0.0025, sw.x * 0.002)
	# --- flash ---
	if _flash_t > 0.0 or _flash_quadros > 0:
		_flash_t -= dt
		_flash_quadros -= 1
		_flash_light.light_energy = maxf(_flash_light.light_energy - dt * 60.0, 0.0)
		if _flash_t <= 0.0 and _flash_quadros <= 0:
			_flash.visible = false
			_flash_light.light_energy = 0.0
	_update_casings(dt)


## Molas do coice e da aterrissagem em subpassos fixos de 1/240 s: com um passo só, um quadro lento (> ~70 ms:
## engasgo, carregamento, captura de tela) fazia a integração divergir e a arma voava metros atrás da câmera.
func _molas(dt: float) -> void:
	var k := 420.0   # mola mais rígida: volta em ~0,18 s (referência)
	var c := 2.0 * sqrt(k) * 0.72
	var resto := minf(dt, 0.1)
	while resto > 0.0:
		var h := minf(resto, 1.0 / 240.0)
		resto -= h
		_kick_vel += (-_kick * k - _kick_vel * c) * h
		_kick += _kick_vel * h
		_land_vel += (-_land * 160.0 - _land_vel * 18.0) * h
		_land += _land_vel * h
		_kick_rot_vel += (-_kick_rot * 200.0 - _kick_rot_vel * 22.6) * h
		_kick_rot += _kick_rot_vel * h
	_kick = clampf(_kick, -0.6, 0.6)
	_land = clampf(_land, -0.15, 0.15)
	_kick_rot = clampf(_kick_rot, -0.5, 3.0)


func _update_casings(dt: float) -> void:
	for i in _casings.size():
		if _casing_life[i] <= 0.0:
			continue
		_casing_life[i] -= dt
		var c := _casings[i]
		_casing_vel[i].y -= 9.8 * dt
		var np := c.global_position + _casing_vel[i] * dt
		c.global_position = np
		c.rotate(Vector3(1, 0.3, 0.2).normalized(), dt * 25.0)
		if _casing_life[i] <= 0.0:
			c.visible = false
			if soldier.is_local and randf() < 0.8:
				var snd := "shell_" + soldier.surface_below()
				if not Audio.has_sound(snd):
					snd = "shell_stone"
				Audio.play_at(snd, np, {"volume_db": -14.0, "max_distance": 10.0, "pitch_var": 0.15})


func muzzle_world_position() -> Vector3:
	if muzzle:
		return muzzle.global_position
	return global_transform * Vector3(0.2, -0.14, -0.95)


# ================================================================ Mosin-Nagant: ferrolho, clip e mão direita (IK)
## Ferrolho separado da malha do modelo (triângulos dentro das caixas "ferrolho_cfg.caixas", coordenadas do glb em m:
## +X direita, +Y cima, -Z boca). Gira em volta do eixo do cano ("eixo") e recua ao longo de +Z. A mão direita vai à
## bola do ferrolho por TwoBoneIK3D (RightArm -> RightForeArm -> RightHand); o rifle fica com a animação idle do pack.
## Ciclo após o tiro: alcança, sobe, recua (cápsula sai), avança, desce, volta ao punho (~1 s, cabe em fire_interval 1,45 s).
## Recarga: ferrolho aberto, clip de 5 cartuchos entra por cima, o polegar empurra, ferrolho fecha (clip é ejetado).
var _ferrolho: Node3D
var _ferrolho_knob: Node3D
var _ferrolho_cfg := {}
var _ferrolho_t := -1.0
var _ferrolho_ik: TwoBoneIK3D
var _ferrolho_alvo: Node3D
var _ferrolho_polo: Node3D
var _ferrolho_peso := 0.0          # influência da IK (0 = mão no punho pela animação)
var _ferrolho_giro := 0.0          # 0..1 do giro (1 = "ang" graus, alavanca para cima)
var _ferrolho_recuo := 0.0         # 0..1 do recuo (1 = "curso" m do glb)
var _ferrolho_ejetou := false
var _mosin_modelo: Node3D
var _mosin_modelo_rest := Transform3D.IDENTITY
static var _ferrolho_malhas := {}   # chave da malha de origem -> [resto, peça do ferrolho, materiais...]
var _mosin_rec_t := -1.0
var _mosin_rec_len := 3.2
var _mosin_clip: Node3D
var _mosin_cart: Array[Node3D] = []
var _mosin_off := Vector3.ZERO     # somados ao pivô em _process (inclinação do rifle no ciclo/recarga)
var _mosin_rot := Vector3.ZERO
var _mosin_rolo := 0.0          # giro (rad) em volta do eixo do cano, no receptor (positivo = topo para a esquerda)
var _mosin_alvo_override := false  # alvo da mão definido pela recarga (clip / bolso) em vez da bola do ferrolho
var _mosin_alvo_m := Vector3.ZERO  # alvo da palma no espaço do Modelo (glb, m)
var _mosin_fase := ""


func _mosin_montar(fc: Dictionary) -> void:
	_ferrolho = null
	_ferrolho_ik = null
	_mosin_clip = null
	_mosin_cart.clear()
	_ferrolho_cfg = fc
	_ferrolho_t = -1.0
	_mosin_rec_t = -1.0
	var arma := _rig_skel.get_node_or_null("Arma") as Node3D
	_mosin_modelo = arma.get_node_or_null("Modelo") as Node3D if arma else null
	if _mosin_modelo == null:
		return
	_mosin_modelo_rest = _mosin_modelo.transform
	var mi := _mosin_modelo.find_child(String(fc.get("malha", "sniper_rifle_001")), true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var caixas: Array = fc.get("caixas", [])
	var xf := _rel(mi, _mosin_modelo)
	var resto := ArrayMesh.new()
	var peca := ArrayMesh.new()
	var mats_resto := []
	var mats_peca := []
	# a separação é feita UMA vez por malha de origem (cache estático): trocar de arma/equipar de novo só reaproveita
	var chave := "%s|%s" % [mi.mesh.resource_path if mi.mesh.resource_path != "" else str(mi.mesh.get_instance_id()), JSON.stringify(caixas)]
	if _ferrolho_malhas.has(chave):
		var c0: Array = _ferrolho_malhas[chave]
		resto = c0[0]; peca = c0[1]; mats_resto = c0[2]; mats_peca = c0[3]
	for si in (0 if _ferrolho_malhas.has(chave) else mi.mesh.get_surface_count()):
		var arr := mi.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
		var fica := PackedInt32Array()
		var sai := PackedInt32Array()
		for t in range(0, ix.size() - 2, 3):
			var dentro := true
			for q in 3:
				var v := xf * vs[ix[t + q]]
				var ok := false
				for c in caixas:
					if v.x >= c[0] and v.y >= c[1] and v.z >= c[2] and v.x <= c[3] and v.y <= c[4] and v.z <= c[5]:
						ok = true
				dentro = dentro and ok
			if dentro:
				sai.append_array([ix[t], ix[t + 1], ix[t + 2]])
			else:
				fica.append_array([ix[t], ix[t + 1], ix[t + 2]])
		var mat := mi.get_active_material(si)
		if fica.size() > 0:
			var a1 := arr.duplicate()
			a1[Mesh.ARRAY_INDEX] = fica
			resto.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a1)
			mats_resto.append(mat)
		if sai.size() > 0:
			var a2 := arr.duplicate()
			a2[Mesh.ARRAY_INDEX] = sai
			peca.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			mats_peca.append(mat)
	if peca.get_surface_count() == 0:
		return
	_ferrolho_malhas[chave] = [resto, peca, mats_resto, mats_peca]
	mi.mesh = resto
	for i in mats_resto.size():
		mi.set_surface_override_material(i, mats_resto[i])
	var e: Array = fc.get("eixo", [0, 0, 0])
	var eixo := Vector3(e[0], e[1], e[2])
	_ferrolho = Node3D.new()
	_ferrolho.name = "Ferrolho"
	_mosin_modelo.add_child(_ferrolho)
	_ferrolho.position = eixo
	var pm := MeshInstance3D.new()
	pm.name = "FerrolhoMalha"
	pm.mesh = peca
	_ferrolho.add_child(pm)
	pm.transform = Transform3D(Basis(), -eixo) * xf
	for i in mats_peca.size():
		pm.set_surface_override_material(i, mats_peca[i])
	# corpo do ferrolho (cilindro escondido dentro da caixa da culatra em repouso; aparece quando recua)
	var corpo: Array = fc.get("corpo", [])   # [raio, comprimento, z da frente da peça traseira relativo ao eixo]
	if corpo.size() == 3:
		var cm := CylinderMesh.new()
		cm.top_radius = float(corpo[0]); cm.bottom_radius = float(corpo[0]); cm.height = float(corpo[1])
		cm.radial_segments = 8; cm.rings = 1
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.16, 0.16, 0.17); sm.metallic = 0.7; sm.roughness = 0.4
		cm.material = sm
		var cmi := MeshInstance3D.new()
		cmi.name = "FerrolhoCorpo"
		cmi.mesh = cm
		_ferrolho.add_child(cmi)
		cmi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, float(corpo[2]) - float(corpo[1]) * 0.5))
	var k: Array = fc.get("bola", [0, 0, 0])
	_ferrolho_knob = Marker3D.new()
	_ferrolho_knob.name = "FerrolhoBola"
	_ferrolho.add_child(_ferrolho_knob)
	_ferrolho_knob.position = Vector3(k[0], k[1], k[2]) - eixo
	_mosin_montar_clip(fc)
	_ferrolho_montar_ik()


func _mosin_montar_clip(fc: Dictionary) -> void:
	var cl: Dictionary = fc.get("clip", {})
	if cl.is_empty():
		return
	_mosin_clip = Node3D.new()
	_mosin_clip.name = "Clip"
	_mosin_modelo.add_child(_mosin_clip)
	var comp := float(cl.get("comp", 0.075))
	var diam := float(cl.get("diam", 0.012))
	var lat := StandardMaterial3D.new()
	lat.albedo_color = Color(0.78, 0.6, 0.3); lat.metallic = 0.8; lat.roughness = 0.35
	var ponta := StandardMaterial3D.new()
	ponta.albedo_color = Color(0.55, 0.38, 0.22); ponta.metallic = 0.6; ponta.roughness = 0.4
	var aco := StandardMaterial3D.new()
	aco.albedo_color = Color(0.2, 0.2, 0.21); aco.metallic = 0.7; aco.roughness = 0.45
	for i in 5:
		var c := Node3D.new()
		c.name = "Cartucho%d" % i
		_mosin_clip.add_child(c)
		c.position = Vector3(0.0015 * (1 if i % 2 == 0 else -1), (i - 2) * diam * 0.92, 0.0)
		var corpo := CylinderMesh.new()
		corpo.top_radius = diam * 0.42; corpo.bottom_radius = diam * 0.5; corpo.height = comp * 0.7
		corpo.radial_segments = 6; corpo.rings = 1; corpo.material = lat
		var m1 := MeshInstance3D.new(); m1.mesh = corpo
		m1.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, comp * 0.15))
		c.add_child(m1)
		var bala := CylinderMesh.new()
		bala.top_radius = diam * 0.08; bala.bottom_radius = diam * 0.33; bala.height = comp * 0.3
		bala.radial_segments = 6; bala.rings = 1; bala.material = ponta
		var m2 := MeshInstance3D.new(); m2.mesh = bala
		m2.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -comp * 0.35))
		c.add_child(m2)
		_mosin_cart.append(c)
	var tira := BoxMesh.new()
	tira.size = Vector3(diam * 1.3, diam * 5.2, 0.003)
	tira.material = aco
	var mt := MeshInstance3D.new(); mt.name = "Tira"; mt.mesh = tira
	mt.position = Vector3(0, 0, comp * 0.5 + 0.0015)
	_mosin_clip.add_child(mt)
	_mosin_clip.visible = false


func _ferrolho_montar_ik() -> void:
	if _rig_skel.find_bone("RightHand") < 0:
		return
	_ferrolho_alvo = Node3D.new(); _ferrolho_alvo.name = "FerrolhoAlvo"
	_ferrolho_polo = Node3D.new(); _ferrolho_polo.name = "FerrolhoPolo"
	_rig_skel.add_child(_ferrolho_alvo)
	_rig_skel.add_child(_ferrolho_polo)
	_ferrolho_ik = TwoBoneIK3D.new()
	_ferrolho_ik.name = "FerrolhoIK"
	_rig_skel.add_child(_ferrolho_ik)
	_ferrolho_ik.set_setting_count(1)
	_ferrolho_ik.set_root_bone_name(0, "RightArm")
	_ferrolho_ik.set_middle_bone_name(0, "RightForeArm")
	_ferrolho_ik.set_end_bone_name(0, "RightHand")
	_ferrolho_ik.set_target_node(0, _ferrolho_ik.get_path_to(_ferrolho_alvo))
	_ferrolho_ik.set_pole_node(0, _ferrolho_ik.get_path_to(_ferrolho_polo))
	_ferrolho_ik.influence = 0.0
	_ferrolho_ik.active = false
	_ferrolho_ik.modification_processed.connect(_ferrolho_pos_ik)


## Pose depois da IK (get_bone_global_pose fora deste sinal devolve a pose da animação, sem a IK).
var _ferrolho_palma_ik := Vector3.INF
var _ferrolho_pulso_ik := Vector3.INF


func _ferrolho_pos_ik() -> void:
	_ferrolho_palma_ik = _ferrolho_palma_sk()
	_ferrolho_pulso_ik = _rig_skel.get_bone_global_pose(_rig_skel.find_bone("RightHand")).origin


static func _fase(t: float, a: float, b: float) -> float:
	return smoothstep(a, b, t)


## Ponto da palma (meio da mão) no espaço do esqueleto.
func _ferrolho_palma_sk() -> Vector3:
	var w := _rig_skel.find_bone("RightHand")
	var m := _rig_skel.find_bone(String(_ferrolho_cfg.get("osso_palma", "RightHandMiddle1")))
	var pw := _rig_skel.get_bone_global_pose(w).origin
	if m < 0:
		return pw
	return pw.lerp(_rig_skel.get_bone_global_pose(m).origin, float(_ferrolho_cfg.get("palma_k", 0.6)))


## Mosin trabalhando o ferrolho (ciclo após o tiro) ou recarregando o clip. Para o controlador tirar da luneta (ADS) nesse tempo.
func ferrolho_ocupado() -> bool:
	return _ferrolho != null and (_ferrolho_t >= 0.0 or _mosin_rec_t >= 0.0)


func mosin_palma_global() -> Vector3:
	if _rig_skel == null or _rig_skel.find_bone("RightHand") < 0:
		return Vector3.INF
	if _ferrolho_ik and _ferrolho_ik.active and _ferrolho_palma_ik != Vector3.INF:
		return _rig_skel.global_transform * _ferrolho_palma_ik
	return _rig_skel.global_transform * _ferrolho_palma_sk()


func _mosin_process(dt: float) -> void:
	_mosin_off = Vector3.ZERO
	_mosin_rot = Vector3.ZERO
	_mosin_rolo = 0.0
	if _ferrolho == null:
		return
	var ang := deg_to_rad(float(_ferrolho_cfg.get("ang", 85.0)))
	var curso := float(_ferrolho_cfg.get("curso", 0.1))
	_mosin_alvo_override = false
	if _mosin_rec_t >= 0.0:
		_mosin_rec_t += dt
		_mosin_recarga_passo(clampf(_mosin_rec_t / _mosin_rec_len, 0.0, 1.0))
		if _mosin_rec_t >= _mosin_rec_len:
			_mosin_rec_t = -1.0
			_mosin_fase = ""
			_ferrolho_peso = 0.0
			_ferrolho_giro = 0.0
			_ferrolho_recuo = 0.0
	elif _ferrolho_t >= 0.0:
		_ferrolho_t += dt
		var t := _ferrolho_t
		var tl: Array = _ferrolho_cfg.get("tempos", [0.2, 0.36, 0.48, 0.66, 0.84, 0.96, 1.2])
		_ferrolho_peso = _fase(t, tl[0], tl[1]) * (1.0 - _fase(t, tl[5], tl[6]))
		_ferrolho_giro = _fase(t, tl[1], tl[2]) * (1.0 - _fase(t, tl[4], tl[5]))
		_ferrolho_recuo = _fase(t, tl[2], tl[3]) * (1.0 - _fase(t, tl[3], tl[4]))
		_mosin_fase = "alcanca" if t < tl[1] else ("sobe" if t < tl[2] else ("recua" if t < tl[3] else ("avanca" if t < tl[4] else ("desce" if t < tl[5] else "volta"))))
		if not _ferrolho_ejetou and t >= lerpf(tl[2], tl[3], 0.7):
			_ferrolho_ejetou = true
			var def := soldier.current_def()
			if def and def.shell_eject:
				_eject_casing(def)
		# rifle cantado para a esquerda e um pouco erguido enquanto a mão trabalha (o ferrolho fica à vista)
		var w := _ferrolho_peso
		var inc: Array = _ferrolho_cfg.get("inclina_ciclo", [0.0, 0.0, 0.12, -0.01, 0.01, 0.0])
		_mosin_rot = Vector3(inc[0], inc[1], 0.0) * w
		_mosin_rolo = inc[2] * w
		_mosin_off = Vector3(inc[3], inc[4], inc[5]) * w
		if t >= tl[6]:
			_ferrolho_t = -1.0
			_ferrolho_peso = 0.0
			_ferrolho_giro = 0.0
			_ferrolho_recuo = 0.0
			_mosin_fase = ""
	_ferrolho.transform = Transform3D(Basis(Vector3.BACK, ang * _ferrolho_giro), Vector3(_ferrolho.position.x, _ferrolho.position.y, float(_ferrolho_cfg.eixo[2]) + curso * _ferrolho_recuo))
	# o braço (51 cm) não alcança a bola do ferrolho com o rifle na pose do pack: enquanto a mão direita trabalha, o rifle
	# desliza para trás na mão de apoio (para o ombro) e um pouco para a direita
	var rc: Array = _ferrolho_cfg.get("recolhe", [0.0, 0.0, 0.0])
	_mosin_modelo.transform = Transform3D(_mosin_modelo_rest.basis, _mosin_modelo_rest.origin + _mosin_modelo_rest.basis * (Vector3(rc[0], rc[1], rc[2]) * _ferrolho_peso))
	_ferrolho_atualizar_ik()


func _ferrolho_atualizar_ik() -> void:
	if _ferrolho_ik == null:
		return
	_ferrolho_ik.influence = _ferrolho_peso
	_ferrolho_ik.active = _ferrolho_peso > 0.001
	if not _ferrolho_ik.active:
		_ferrolho_palma_ik = Vector3.INF
		_ferrolho_pulso_ik = Vector3.INF
		return
	var m_sk := _rel(_mosin_modelo, _rig_skel)
	# a palma pega a bola por trás/baixo ("palma_off", m do glb no referencial do ferrolho): a bola continua à vista
	var po: Array = _ferrolho_cfg.get("palma_off", [0.0, 0.0, 0.0])
	var bola_m := _rel(_ferrolho_knob, _mosin_modelo) * Vector3(po[0], po[1], po[2])
	var alvo_palma := m_sk * (_mosin_alvo_m if _mosin_alvo_override else bola_m)
	var w := _rig_skel.find_bone("RightHand")
	var pw := _rig_skel.get_bone_global_pose(w).origin
	var palma := _ferrolho_palma_sk()
	if _ferrolho_palma_ik != Vector3.INF:   # orientação da mão já com a IK (quadro anterior)
		palma = _ferrolho_palma_ik
		pw = _ferrolho_pulso_ik
	_ferrolho_alvo.position = alvo_palma - (palma - pw)
	# polo do cotovelo: para baixo e para fora (direita) no espaço do Holder
	var hb := _rel(_rig_skel, holder)
	var ombro := hb * _rig_skel.get_bone_global_pose(_rig_skel.find_bone("RightArm")).origin
	var alvo_h := hb * _ferrolho_alvo.position
	var pl: Array = _ferrolho_cfg.get("polo", [0.25, -0.35, 0.05])
	_ferrolho_polo.position = hb.affine_inverse() * ((ombro + alvo_h) * 0.5 + Vector3(pl[0], pl[1], pl[2]))


func _mosin_recarga_iniciar(def: WeaponDef) -> void:
	_mosin_rec_len = def.reload_time
	_mosin_rec_t = 0.0
	_ferrolho_t = -1.0


## Recarga por clip (p = 0..1 de def.reload_time).
func _mosin_recarga_passo(p: float) -> void:
	var tl: Array = _ferrolho_cfg.get("rec_tempos", [0.0, 0.09, 0.15, 0.25, 0.33, 0.42, 0.5, 0.7, 0.76, 0.86, 0.9, 1.0])
	var cl: Dictionary = _ferrolho_cfg.get("clip", {})
	var tilt := _fase(p, 0.0, tl[1]) * (1.0 - _fase(p, tl[10], tl[11]))
	var inc: Array = _ferrolho_cfg.get("inclina_rec", [0.06, 0.0, 0.3, -0.03, 0.03, 0.02])
	_mosin_rot = Vector3(inc[0], inc[1], 0.0) * tilt
	_mosin_rolo = inc[2] * tilt
	_mosin_off = Vector3(inc[3], inc[4], inc[5]) * tilt
	_ferrolho_peso = _fase(p, tl[0], tl[1]) * (1.0 - _fase(p, tl[10], tl[11]))
	_ferrolho_giro = _fase(p, tl[1], tl[2]) * (1.0 - _fase(p, tl[9], tl[10]))
	_ferrolho_recuo = _fase(p, tl[2], tl[3]) * (1.0 - _fase(p, tl[8], tl[9]))
	var sl: Array = cl.get("slot", [0.02, 0.13, 0.11])
	var slot := Vector3(sl[0], sl[1], sl[2])
	var ec: Array = cl.get("empurra", [-0.012, -0.05, 0.0])
	var empurra := Vector3(ec[0], ec[1], ec[2])
	var bo: Array = cl.get("bolso", [0.12, -0.2, 0.05])
	var bolso := Vector3(bo[0], bo[1], bo[2])
	var gl: Array = cl.get("polegar", [0.0, 0.045, 0.0])
	var polegar := Vector3(gl[0], gl[1], gl[2])
	var giro_clip := deg_to_rad(float(cl.get("giro", 30.0)))
	var bola := _rel(_ferrolho_knob, _mosin_modelo).origin
	var push := _fase(p, tl[6], tl[7])
	if p >= tl[3] and p < tl[7]:
		_mosin_alvo_override = true
		if p < tl[4]:      # mão desce ao bolso
			_mosin_alvo_m = bola.lerp(bolso, _fase(p, tl[3], tl[4]))
			_mosin_fase = "pega_clip"
		elif p < tl[5]:    # volta com o clip até a guia
			_mosin_alvo_m = bolso.lerp(slot + polegar, _fase(p, tl[4], tl[5]))
			_mosin_fase = "traz_clip"
		elif p < tl[6]:
			_mosin_alvo_m = slot + polegar
			_mosin_fase = "encaixa"
		else:              # polegar empurra os cartuchos
			_mosin_alvo_m = slot + polegar + empurra * push
			_mosin_fase = "empurra"
	elif p >= tl[7] and p < tl[8]:
		_mosin_alvo_override = true
		_mosin_alvo_m = (slot + polegar + empurra).lerp(bola, _fase(p, tl[7], tl[8]))
		_mosin_fase = "vai_ferrolho"
	else:
		_mosin_fase = "abre" if p < tl[3] else ("fecha" if p < tl[10] else "volta")
	if _mosin_clip == null:
		return
	var vis := p > lerpf(tl[3], tl[4], 0.6) and p < lerpf(tl[8], tl[9], 0.5)
	_mosin_clip.visible = vis
	if not vis:
		return
	var b := Basis(Vector3.BACK, giro_clip)
	var pos: Vector3
	if p < tl[5]:      # na mão: segue a palma (espaço do Modelo)
		var m_sk := _rel(_mosin_modelo, _rig_skel)
		pos = m_sk.affine_inverse() * _ferrolho_palma_sk() - b * polegar
		pos = pos.lerp(slot, _fase(p, lerpf(tl[4], tl[5], 0.5), tl[5]))
	elif p < tl[8]:
		pos = slot + Vector3(ec[0], 0.0, 0.0) * push
	else:              # ferrolho fecha: o clip vazio é jogado para cima e para a direita
		var s := _fase(p, tl[8], lerpf(tl[8], tl[9], 0.5))
		pos = slot + Vector3(0.06, 0.08, 0.02) * s
		b = Basis(Vector3.BACK, giro_clip + 1.5 * s)
	_mosin_clip.transform = Transform3D(b, pos)
	# cartuchos descem para o depósito com o polegar; depois do empurrão ficam escondidos (dentro da arma)
	for i in _mosin_cart.size():
		var c := _mosin_cart[i]
		var base := Vector3(0.0015 * (1 if i % 2 == 0 else -1), (i - 2) * float(cl.get("diam", 0.012)) * 0.92, 0.0)
		c.position = base + b.inverse() * Vector3(0.0, empurra.y, 0.0) * push
		c.visible = p < tl[7]
