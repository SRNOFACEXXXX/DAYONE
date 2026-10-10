extends Node
## Ferramentas na mão e fogueira (sem class_name; PlayerController cria com preload).
## Tecla do atalho (1–5) com uma ferramenta/kit liga "na mão": o viewmodel da arma some, o modelo do item aparece na câmera
## e o clique esquerdo age (machado = golpe; kit_fogueira, ou 3 gravetos + 1 tora = monta fogueira). F = atalho do machado.
## Fogueira: segurar E perto dela = acender (fósforos) / cozinhar carne crua (barra); V = pôr lenha.

const ArvoreCorte := preload("res://core/arvore_corte.gd")
const Fogueira := preload("res://core/fogueira.gd")

const SWING_S := 0.62
const IMPACTO_S := 0.30
const ALCANCE_FOGO := 2.6

var pc: PlayerController
var m: Match
var corte: Node
var em_id := ""
var em_uid := -1
var _mao: Node3D
var _swing := -1.0
var _acertou := false
var _cd := 0.0
var _dica: Label
var _barra: Control
var _barra_fill: ColorRect
var _bloqueio := false   # clique ainda apertado depois de largar o item: não deixa a arma atirar
var _prog := 0.0
var _modo := ""
var _t_dica := 0.0


func setup(p: PlayerController, mt: Match) -> void:
	pc = p
	m = mt
	name = "FerramentasMao"
	corte = ArvoreCorte.new()
	corte.setup(mt)
	mt.add_child(corte)
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_dica = Label.new()
	_dica.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.offset_top = -250.0
	_dica.offset_bottom = -210.0
	_dica.offset_left = -300.0
	_dica.offset_right = 300.0
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.add_theme_font_size_override("font_size", 22)
	_dica.add_theme_color_override("font_color", Color("FFE27A"))
	_dica.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_dica.add_theme_constant_override("outline_size", 6)
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.visible = false
	layer.add_child(_dica)
	_barra = Control.new()
	_barra.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_barra.offset_top = -205.0
	_barra.offset_bottom = -193.0
	_barra.offset_left = -110.0
	_barra.offset_right = 110.0
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.visible = false
	layer.add_child(_barra)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.add_child(fundo)
	_barra_fill = ColorRect.new()
	_barra_fill.color = Color("e8a33a")
	_barra_fill.anchor_bottom = 1.0
	_barra_fill.offset_left = 2.0
	_barra_fill.offset_top = 2.0
	_barra_fill.offset_bottom = -2.0
	_barra_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.add_child(_barra_fill)


func _bag() -> BRInventory:
	return m.get("br_bag")


func contar(id: String) -> int:
	var b := _bag()
	var n := 0
	if b != null:
		for it in b.items:
			if String(it.id) == id:
				n += int(it.qty)
	return n


func consumir(id: String, qtd: int) -> bool:
	if contar(id) < qtd:
		return false
	var b := _bag()
	var falta := qtd
	for it in b.items.duplicate(true):
		if String(it.id) != id or falta <= 0:
			continue
		falta -= b.remove_item(int(it.uid), mini(falta, int(it.qty)))
	return falta == 0


func ocupa_mao() -> bool:
	return em_id != "" or _bloqueio


func _livre() -> bool:
	return pc != null and pc.soldier != null and pc.soldier.alive and not pc.ui_blocking and pc.active_vehicle == null \
		and m.get("br_ui") != null and not m.br_ui.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ mão
func equipar(uid: int) -> bool:
	var b := _bag()
	var it := b.get_item(uid) if b != null else {}
	if it.is_empty():
		return false
	desequipar()
	em_uid = uid
	em_id = String(it.id)
	pc.viewmodel.set_viewmodel_enabled(false)
	_mao = Node3D.new()
	_mao.name = "ItemNaMao"
	var path := String(BRInventory.definition(em_id).get("model_path", ""))
	if path != "" and ResourceLoader.exists(path):
		var sc: Node3D = (load(path) as PackedScene).instantiate()
		var cfg: Dictionary = BRInventory.definition(em_id).get("mao", {})
		sc.scale = Vector3.ONE * float(cfg.get("escala", ESCALA_MAO.get(em_id, 0.65)))
		if cfg.has("rot"):
			var r: Array = cfg.rot
			sc.rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))
		_mao.add_child(sc)
		if MAOS.has(em_id):
			_por_maos(sc, MAOS[em_id])
		elif String(BRInventory.definition(em_id).get("acao", "")) != "":
			_por_maos(sc, [_centro_y(sc) / maxf(sc.scale.y, 0.001)])   # props: uma mão fechada no meio do objeto
		for g in sc.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var acao_i := String(BRInventory.definition(em_id).get("acao", ""))
	_ajuste = Vector3(-0.07, 0.12, 0.02) if acao_i != "" and acao_i != "golpe" and acao_i != "melee" else Vector3.ZERO
	pc.camera.add_child(_mao)
	if String(BRInventory.definition(em_id).get("acao", "")) == "luz":
		_ligar_lanterna(true)
	_pose(0.0)
	m.hud_message.emit("%s na mão" % String(BRInventory.definition(em_id).get("name", em_id)), 1.4)
	return true


func desequipar() -> void:
	if em_id == "":
		return
	em_id = ""
	em_uid = -1
	_bloqueio = Input.is_action_pressed("fire")
	_swing = -1.0
	var bm := pc.soldier.body_model as BodyModel if pc != null and pc.soldier != null else null
	if bm != null and bm.has_meta(MxRetarget.META):
		MxRetarget.parar(bm)
	_ligar_lanterna(false)
	if _mao != null and is_instance_valid(_mao):
		_mao.queue_free()
	_mao = null
	if pc != null and pc.viewmodel != null:
		pc.viewmodel.set_viewmodel_enabled(true)


## Escala do modelo na mão e onde as mãos seguram o cabo (altura em metros do modelo, a partir da base do cabo).
const ESCALA_MAO := {"machado": 0.95, "picareta": 0.8, "martelo": 0.9}
const MAOS := {"machado": [0.07, 0.27], "picareta": [0.10, 0.40], "martelo": [0.07, 0.25]}
const COR_PELE := Color(0.80, 0.60, 0.46)
const COR_MANGA := Color(0.26, 0.33, 0.20)
## Quadros-chave do golpe (k = 0..1): [k, posição na câmera, rotação em graus (x = ponta para trás/frente, y, z)]. O impacto cai em
## k = IMPACTO_S / SWING_S (0,48); antes, o recuo para cima e para a direita; depois, o arrasto e a volta ao descanso.
const GOLPE := [
	[0.00, Vector3(0.30, -0.42, -0.58), Vector3(-8.0, -14.0, -10.0)],
	[0.10, Vector3(0.28, -0.32, -0.54), Vector3(8.0, -12.0, -14.0)],
	[0.30, Vector3(0.20, -0.12, -0.50), Vector3(48.0, -8.0, -24.0)],
	[0.40, Vector3(0.21, -0.10, -0.49), Vector3(52.0, -8.0, -26.0)],
	[0.48, Vector3(0.10, -0.30, -0.64), Vector3(-62.0, -16.0, 8.0)],
	[0.60, Vector3(0.12, -0.27, -0.62), Vector3(-54.0, -15.0, 6.0)],
	[0.80, Vector3(0.22, -0.38, -0.64), Vector3(-30.0, -14.0, -4.0)],
	[1.00, Vector3(0.30, -0.42, -0.58), Vector3(-8.0, -14.0, -10.0)],
]


## Mãos de luva (pele) seguram o cabo e os antebraços de manga (cor da manga dos braços da arma) ligam cada mão a um ombro FIXO
## na câmera (IK simples: o cilindro é esticado da mão ao ombro a cada quadro, então o braço nunca "gira" junto com a ferramenta).
## `alturas` = onde cada mão agarra (m, no modelo); a mão de baixo é a direita.
const OMBROS := [Vector3(0.34, -0.70, 0.30), Vector3(-0.30, -0.72, 0.28)]   # no espaço da câmera (z>0 = atrás do plano de visão)
var _ajuste := Vector3.ZERO   # props (garrafa, dinamite...) ficam mais para dentro da tela que as ferramentas
var _punhos: Array[Node3D] = []
var _bracos: Array[MeshInstance3D] = []


func _por_maos(modelo: Node3D, alturas: Array) -> void:
	_punhos.clear()
	_bracos.clear()
	var pele := StandardMaterial3D.new()
	pele.albedo_color = COR_PELE
	pele.roughness = 1.0
	var manga := StandardMaterial3D.new()
	manga.albedo_color = COR_MANGA
	manga.roughness = 1.0
	for i in alturas.size():
		var punho := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.065, 0.085)
		punho.mesh = bm
		punho.material_override = pele
		punho.position = Vector3(0.0, float(alturas[i]), 0.0)
		punho.scale = Vector3.ONE / modelo.scale   # tamanho de mão fixo, qualquer que seja a escala do modelo
		punho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		modelo.add_child(punho)
		_punhos.append(punho)
		var braco := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.034
		cm.bottom_radius = 0.034
		cm.height = 1.0
		cm.radial_segments = 6
		braco.mesh = cm
		braco.material_override = manga
		braco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		braco.top_level = true   # transformação em mundo: calculada da mão ao ombro
		_mao.add_child(braco)
		_bracos.append(braco)


func _esticar_bracos() -> void:
	if _bracos.is_empty() or pc == null or pc.camera == null:
		return
	var cam := pc.camera.global_transform
	for i in _bracos.size():
		if not is_instance_valid(_punhos[i]):
			continue
		var mao_w: Vector3 = _punhos[i].global_position
		var ombro_w: Vector3 = cam * (OMBROS[i % 2] as Vector3)
		var v := ombro_w - mao_w
		var L := v.length()
		if L < 0.01:
			continue
		var d := v / L
		var ref := Vector3.RIGHT if absf(d.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x := ref.cross(d).normalized()
		var z := x.cross(d).normalized()
		_bracos[i].global_transform = Transform3D(Basis(x, d * L, z), mao_w + v * 0.5)


## Pose do item na câmera. `k` = 0 repouso … 1 fim do golpe (animação própria, sem rig): interpola os quadros-chave GOLPE com
## suavização (aceleração na descida, parada seca no impacto).
func _pose(k: float) -> void:
	if _mao == null:
		return
	k = clampf(k, 0.0, 1.0)
	var a: Array = GOLPE[0]
	var b: Array = GOLPE[GOLPE.size() - 1]
	for i in GOLPE.size() - 1:
		if k <= float((GOLPE[i + 1] as Array)[0]):
			a = GOLPE[i]
			b = GOLPE[i + 1]
			break
	var t := clampf((k - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_mao.position = (a[1] as Vector3).lerp(b[1] as Vector3, t) + _ajuste
	_mao.rotation_degrees = (a[2] as Vector3).lerp(b[2] as Vector3, t)
	_esticar_bracos()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo or not _livre():
		return
	var kc := int((ev as InputEventKey).physical_keycode)
	if kc >= KEY_1 and kc <= KEY_5:
		var b := _bag()
		var it := b.quick_item(kc - int(KEY_1)) if b != null else {}
		var tipo := _tipo_mao(it)
		if tipo != "":
			if int(it.uid) == em_uid:
				desequipar()
				m.hud_message.emit("Mãos livres", 1.0)
			else:
				equipar(int(it.uid))
			get_viewport().set_input_as_handled()
		elif em_id != "":
			desequipar()   # tecla de arma/cura: solta a ferramenta e deixa o fluxo normal seguir
	elif kc == KEY_F:
		if em_id == "":
			var b2 := _bag()
			if b2 != null:
				for it2 in b2.items:
					if String(it2.id) == "machado":
						equipar(int(it2.uid))
						break
		if em_id == "machado":
			_iniciar_golpe()
			get_viewport().set_input_as_handled()
	elif kc == KEY_V:
		_por_lenha(Fogueira.qualquer_perto(get_tree(), pc.soldier.global_position, ALCANCE_FOGO))
		get_viewport().set_input_as_handled()


## "" = não é item de mão; senão o tipo.
func _tipo_mao(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var id := String(it.id)
	var kind := String(BRInventory.definition(id).get("kind", ""))
	if kind == "ferramenta" or kind == "fogueira":
		return kind
	if id == "graveto" or id == "tora":
		return "fogueira"
	return ""


# ------------------------------------------------------------------ quadro
func _physics_process(dt: float) -> void:
	if pc == null or pc.soldier == null:
		return
	_cd = maxf(0.0, _cd - dt)
	if _bloqueio and not Input.is_action_pressed("fire"):
		_bloqueio = false
	var b := _bag()
	if em_id != "":
		if b == null or b.get_item(em_uid).is_empty() or not pc.soldier.alive or pc.active_vehicle != null:
			desequipar()
		elif _livre() and Input.is_action_pressed("fire") and _cd <= 0.0 and _swing < 0.0:
			_acao_principal()
	_fogueira_hold(dt)
	_t_dica -= dt
	if _t_dica <= 0.0:
		_t_dica = 0.12
		_atualizar_dica()


func _process(dt: float) -> void:
	if _swing < 0.0 or _mao == null:
		return
	_swing += dt
	_pose(_swing / SWING_S)
	if not _acertou and _swing >= IMPACTO_S:
		_acertou = true
		_impacto()
	if _swing >= SWING_S:
		_swing = -1.0
		_pose(0.0)
		_anim_corpo(false)


func _acao_principal() -> void:
	var def := BRInventory.definition(em_id)
	var kind := String(def.get("kind", ""))
	if kind == "ferramenta":
		match String(def.get("acao", "golpe")):
			"arremesso":
				_arremessar(def)
			"plantar":
				_plantar_mina(def)
			"abrir":
				_abrir(def)
			"luz":
				_ligar_lanterna(_lanterna == null or not _lanterna.visible)
				_cd = 0.35
			"escada":
				_apoiar_escada()
			_:
				_iniciar_golpe()
	elif kind == "fogueira" or em_id == "graveto" or em_id == "tora":
		_montar_fogueira()
		_cd = 0.6


func _iniciar_golpe() -> void:
	if _swing >= 0.0 or _cd > 0.0 or _mao == null:
		return
	_swing = 0.0
	_acertou = false
	_cd = SWING_S + 0.12
	_anim_corpo(true)


## Terceira pessoa: se o clipe Mixamo da ferramenta existir (assets/anim_mixamo/leve/<Clipe>.glb), o corpo toca o golpe real
## (retarget MxRetarget); sem o arquivo, só o item balança. Clipes: Axe_Chop.glb (machado) e Pickaxe_Mine.glb (picareta).
const CLIPES := {"machado": "Axe_Chop", "picareta": "Pickaxe_Mine"}


func _anim_corpo(ligar: bool) -> void:
	var bm := pc.soldier.body_model as BodyModel
	if bm == null or not CLIPES.has(em_id):
		return
	var nome: String = CLIPES[em_id]
	if ligar:
		if ResourceLoader.exists("res://assets/anim_mixamo/leve/%s.glb" % nome):
			MxRetarget.tocar(bm, nome, false, 1.0)
	elif bm.has_meta(MxRetarget.META):
		MxRetarget.parar(bm)


# ------------------------------------------------------------------ props: arremesso, mina, cofrinho, luz, melee
## Panela ou frigideira na bolsa (definição com `cozinha`): a carne cozinha na metade do tempo.
func _tem_utensilio() -> bool:
	var b := _bag()
	if b == null:
		return false
	for it in b.items:
		if bool(BRInventory.definition(String(it.id)).get("cozinha", false)):
			return true
	return false


func _centro_y(n: Node3D) -> float:
	var ab := AABB()
	var primeiro := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
		ab = b if primeiro else ab.merge(b)
		primeiro = false
	return (ab.position.y + ab.size.y * 0.5) * n.scale.y


## Gasta 1 do item da mão e devolve a quantidade que sobrou (-1 se o item não estava na mochila).
func _gastar_da_mao() -> int:
	var b := _bag()
	if b == null or b.get_item(em_uid).is_empty():
		return -1
	b.remove_item(em_uid, 1)
	var resto := b.get_item(em_uid)
	return int(resto.qty) if not resto.is_empty() else 0


func _modelo_do_item(def: Dictionary) -> PackedScene:
	var path := String(def.get("model_path", ""))
	return load(path) as PackedScene if path != "" and ResourceLoader.exists(path) else null


## Dinamite, bomba e itens de barulho (garrafa, moeda, ídolo...): saem da câmera em arco (Grenade com parâmetros do item).
func _arremessar(def: Dictionary) -> void:
	var cam := pc.camera
	var dir := -cam.global_transform.basis.z
	var params := {"pavio": float(def.get("pavio", 3.0)), "raio": float(def.get("raio", 7.0)), "dano": float(def.get("dano", 100.0)),
		"ruido": float(def.get("ruido", 0.0)), "modelo": _modelo_do_item(def)}
	if _gastar_da_mao() < 0:
		return
	Grenade.lancar(m, pc.soldier, cam.global_position + dir * 0.7 + Vector3(0, -0.15, 0), dir, params)
	pc.shake(0.1)
	_cd = 0.7
	m.hud_message.emit("%s arremessad%s" % [String(def.get("name", em_id)), "a" if String(def.get("name", "")).ends_with("a") else "o"], 1.0)


func _plantar_mina(def: Dictionary) -> void:
	var pos := _ponto_no_chao()
	if pos.y < 0.3:
		m.hud_message.emit("Não dá para plantar na água", 1.4)
		return
	if _gastar_da_mao() < 0:
		return
	Grenade.lancar(m, pc.soldier, pos + Vector3(0, 0.2, 0), Vector3.ZERO, {"mina": true, "raio": float(def.get("raio", 11.0)),
		"dano": float(def.get("dano", 300.0)), "modelo": _modelo_do_item(def)})
	_cd = 1.0
	m.hud_message.emit("Mina plantada. Armada em 2 s. Afaste-se.", 2.0)


func _abrir(def: Dictionary) -> void:
	var b := _bag()
	if b == null or _gastar_da_mao() < 0:
		return
	var txt: PackedStringArray = []
	for par in def.get("loot", []):
		var id := String(par[0])
		var n: int = b.add_item(id, int(par[1]))
		if n > 0:
			txt.append("%dx %s" % [n, String(BRInventory.definition(id).get("name", id))])
	m.hud_message.emit("Quebrou: " + (", ".join(txt) if not txt.is_empty() else "vazio (ou sem espaço)"), 2.2)
	if Audio.has_sound("impact_stone"):
		Audio.play("impact_stone", {"volume_db": -2.0})
	_cd = 0.8


var _lanterna: SpotLight3D


func _ligar_lanterna(ligar: bool) -> void:
	if ligar:
		if _lanterna == null or not is_instance_valid(_lanterna):
			_lanterna = SpotLight3D.new()
			_lanterna.spot_range = 32.0
			_lanterna.spot_angle = 34.0
			_lanterna.spot_attenuation = 0.8
			_lanterna.light_energy = 4.0
			_lanterna.shadow_enabled = false
			pc.camera.add_child(_lanterna)
		_lanterna.visible = true
	elif _lanterna != null and is_instance_valid(_lanterna):
		_lanterna.queue_free()
		_lanterna = null


## Frigideira/ancinho: acerta o que está no cone à frente (zumbis e animais a ≤ 2 m).
func _golpe_melee(def: Dictionary) -> void:
	var s := pc.soldier
	var cam := pc.camera
	var origem := cam.global_position
	var dir := -cam.global_transform.basis.z
	var faca := WeaponDB.get_def(&"knife")
	var esc := float(def.get("dano_melee", 1.0))
	var acertou := 0
	var alvos: Array = get_tree().get_nodes_in_group("zombie") + get_tree().get_nodes_in_group("animal")
	for z in alvos:
		var n := z as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var peito := n.global_position + Vector3.UP * 1.1
		var v := peito - origem
		if v.length() > 2.1 or v.normalized().dot(dir) < 0.6:
			continue
		if n.has_method("hit_by_bullet"):
			n.hit_by_bullet(peito, dir, faca, esc, s)
			acertou += 1
	if acertou > 0:
		pc.shake(0.35)
		if Audio.has_sound("knife_hit_flesh"):
			Audio.play_at("knife_hit_flesh", origem + dir, {"volume_db": -2.0, "max_distance": 25.0})
	elif Audio.has_sound("knife_swing"):
		Audio.play_at("knife_swing", origem, {"volume_db": -8.0, "max_distance": 18.0})


## Escada telescópica: apoia na parede à frente (3 m de alcance) e cria uma EscadaVertical do chão até o topo da parede (1,6 a 3,8 m
## de altura, com plataforma em cima). "E — subir" funciona como nas torres do mapa. A escada fica no mundo e o item é gasto.
func _apoiar_escada() -> void:
	var cam := pc.camera
	var s := pc.soldier
	var ss := s.get_world_3d().direct_space_state
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var hit := ss.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 3.2, Soldier.LAYER_WORLD, [s.get_rid()]))
	if hit.is_empty() or absf(float(hit.normal.y)) > 0.4:
		m.hud_message.emit("Aponte para uma parede (até 3 m)", 1.6)
		return
	var n := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
	var base_xz: Vector3 = hit.position + n * 0.45
	var chao := ss.intersect_ray(PhysicsRayQueryParameters3D.create(base_xz + Vector3(0, 1.5, 0), base_xz + Vector3(0, -4.0, 0), Soldier.LAYER_WORLD, [s.get_rid()]))
	if chao.is_empty():
		m.hud_message.emit("Sem chão firme aqui", 1.4)
		return
	var y0: float = chao.position.y
	var topo_xz: Vector3 = hit.position - n * 0.5
	var cima := ss.intersect_ray(PhysicsRayQueryParameters3D.create(topo_xz + Vector3(0, y0 + 4.4 - topo_xz.y, 0), topo_xz + Vector3(0, y0 - 1.0 - topo_xz.y, 0), Soldier.LAYER_WORLD, [s.get_rid()]))
	if cima.is_empty() or float(cima.normal.y) < 0.7:
		m.hud_message.emit("A escada precisa de uma plataforma no alto da parede", 2.0)
		return
	var altura: float = float(cima.position.y) - y0
	if altura < 1.6 or altura > 3.8:
		m.hud_message.emit("Parede de %.1f m: a escada serve de 1,6 a 3,8 m" % altura, 2.0)
		return
	if _gastar_da_mao() < 0:
		return
	var e := EscadaVertical.new()
	e.name = "EscadaTelescopica"
	e.base_local = Vector3(base_xz.x, y0, base_xz.z)
	e.topo_local = Vector3(topo_xz.x, cima.position.y, topo_xz.z)
	e.collision_layer = Soldier.LAYER_TRIGGER
	e.collision_mask = Soldier.LAYER_SOLDIER
	e.monitoring = true
	e.monitorable = false
	m.add_child(e)
	e._forma(e.base_local + Vector3(0, 1.0, 0), Vector3(1.6, 2.4, 1.6))
	e._forma(e.topo_local + Vector3(0, 0.9, 0), Vector3(1.8, 2.0, 1.8))
	e.body_entered.connect(e._entrou)
	e.body_exited.connect(e._saiu)
	e.add_to_group("escadas_verticais")
	var vis: Node3D = (_modelo_do_item(BRInventory.definition("escada_telescopica"))).instantiate()
	vis.scale = Vector3(1.9, (altura + 0.3) / 0.85, 1.9)
	vis.position = Vector3(base_xz.x, y0, base_xz.z) - n * 0.12
	vis.look_at_from_position(vis.position, vis.position - n, Vector3.UP)   # frente do modelo para a parede
	e.add_child(vis)
	for g in vis.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cd = 1.0
	m.hud_message.emit("Escada apoiada (%.1f m). Chegue perto e aperte E." % altura, 2.4)


func _impacto() -> void:
	var s := pc.soldier
	if String(BRInventory.definition(em_id).get("acao", "")) == "melee":
		_golpe_melee(BRInventory.definition(em_id))
		return
	if em_id == "machado":
		if corte.golpear(s.global_position, s.aim_dir()):
			pc.shake(0.3)
		else:
			m.hud_message.emit("Chegue perto de uma árvore", 1.0)
	elif em_id == "picareta":
		_minerar(s)


## Picareta: a pedra pequena mais próxima à frente rende 1 pedra a cada GOLPES_PEDRA golpes (3 pedras por rocha).
const GOLPES_PEDRA := 3
var _golpes_pedra := {}


func _minerar(s: Soldier) -> void:
	var ilha = m.get("ilha")
	var veg: IlhaVegetation = ilha.get_node_or_null("Vegetacao") if ilha != null else null
	if veg == null:
		return
	var f := s.aim_dir()
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var i := veg.pedra_mais_proxima(s.global_position + f * 1.2, 2.0)
	if i < 0:
		m.hud_message.emit("Pedra esgotada" if veg.ha_pedra_perto(s.global_position + f * 1.2, 2.0) else "Chegue perto de uma pedra", 1.0)
		return
	var r: Dictionary = veg.pedras[i]
	var n: int = int(_golpes_pedra.get(i, 0)) + 1
	var som := "impact_stone" if Audio.has_sound("impact_stone") else "impact_metal"
	Audio.play_at(som, r.pos, {"volume_db": 2.0, "pitch": 0.9 + 0.05 * (n % 3), "max_distance": 50.0})
	Audio.emitir_barulho(r.pos, 22.0, null)
	pc.shake(0.2)
	if n >= GOLPES_PEDRA:
		_golpes_pedra.erase(i)
		r.restante = int(r.restante) - 1
		m.criar_drop("pedra", 1, s.global_position + f * 1.0 + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)))
		m.hud_message.emit("+1 pedra", 1.0)
	else:
		_golpes_pedra[i] = n


# ------------------------------------------------------------------ fogueira
func _ponto_no_chao() -> Vector3:
	var s := pc.soldier
	var f := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	var o := s.global_position + f * 1.8 + Vector3(0, 2.5, 0)
	var q := PhysicsRayQueryParameters3D.create(o, o + Vector3(0, -8.0, 0), Soldier.LAYER_WORLD)
	var hit := s.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	var t = m.ilha.get("terrain")
	return Vector3(o.x, t.height_world(o.x, o.z) if t != null else s.global_position.y, o.z)


func _montar_fogueira() -> void:
	var min_lenha := 0.0
	var gasta_kit := em_id == "kit_fogueira"
	if gasta_kit:
		min_lenha = float(BRInventory.definition("kit_fogueira").get("combustivel_min", 8.0))
	elif contar("graveto") >= 3 and contar("tora") >= 1:
		min_lenha = 3.0 * float(BRInventory.definition("graveto").get("combustivel_min", 2.0)) \
			+ float(BRInventory.definition("tora").get("combustivel_min", 10.0))
	else:
		m.hud_message.emit("Precisa de kit de fogueira ou 3 gravetos + 1 tora", 2.0)
		return
	var pos := _ponto_no_chao()
	if pos.y < 0.4:
		m.hud_message.emit("Não dá para montar fogueira na água", 1.6)
		return
	if Fogueira.qualquer_perto(get_tree(), pos, 1.4) != null:
		m.hud_message.emit("Já há uma fogueira aqui", 1.4)
		return
	if gasta_kit:
		consumir("kit_fogueira", 1)
	else:
		consumir("graveto", 3)
		consumir("tora", 1)
	var f: Node3D = Fogueira.criar(m, pos, min_lenha)
	Audio.play_at("impact_wood", pos, {"volume_db": 0.0, "pitch": 1.1, "max_distance": 30.0})
	if contar("fosforos") > 0:
		consumir("fosforos", 1)
		f.acender()
		m.hud_message.emit("Fogueira acesa (%d min de lenha)" % int(f.minutos()), 2.2)
	else:
		m.hud_message.emit("Fogueira montada. Sem fósforos para acender", 2.2)
	if em_id != "" and (b_vazio(em_uid)):
		desequipar()


func b_vazio(uid: int) -> bool:
	var b := _bag()
	return b == null or b.get_item(uid).is_empty()


func _por_lenha(f: Node3D) -> bool:
	if f == null:
		return false
	var id := "graveto" if contar("graveto") > 0 else ("tora" if contar("tora") > 0 else "")
	if id == "":
		m.hud_message.emit("Sem lenha (graveto ou tora)", 1.5)
		return false
	if f.minutos() > 28.0:
		m.hud_message.emit("A fogueira já está cheia de lenha", 1.5)
		return false
	consumir(id, 1)
	var add: float = f.adicionar(float(BRInventory.definition(id).get("combustivel_min", 2.0)))
	m.hud_message.emit("+%d min de lenha (%d min)" % [int(round(add)), int(f.minutos())], 1.6)
	return true


## Decide o que segurar E faz perto de uma fogueira. {} = nada. {modo, tempo}
func _modo_fogo(f: Node3D) -> Dictionary:
	if f == null:
		return {}
	if not f.acesa:
		if f.combustivel_s > 0.0 and contar("fosforos") > 0:
			return {"modo": "acender", "tempo": Fogueira.ACENDE_S}
		return {}
	if contar("carne_crua") > 0:
		return {"modo": "cozinhar", "tempo": Fogueira.COZINHA_S * (Fogueira.COZINHA_UTENSILIO if _tem_utensilio() else 1.0)}
	return {}


func _fogueira_hold(dt: float) -> void:
	var f: Node3D = null
	if _livre() and Input.is_action_pressed("use"):
		f = Fogueira.qualquer_perto(get_tree(), pc.soldier.global_position, ALCANCE_FOGO)
	var md := _modo_fogo(f)
	if md.is_empty():
		_prog = 0.0
		_modo = ""
		_barra.visible = false
		return
	if String(md.modo) != _modo:
		_modo = String(md.modo)
		_prog = 0.0
	_prog += dt
	_barra.visible = true
	_barra_fill.offset_right = -2.0 - (216.0 * (1.0 - clampf(_prog / float(md.tempo), 0.0, 1.0)))
	if _prog >= float(md.tempo):
		_prog = 0.0
		if _modo == "acender":
			consumir("fosforos", 1)
			if f.acender():
				m.hud_message.emit("Fogueira acesa", 1.6)
		elif _modo == "cozinhar":
			if consumir("carne_crua", 1):
				var ok := _bag().add_item("carne_cozida", 1)
				if ok == 0:
					ArvoreCorte.drop_com_modelo(m, "carne_cozida", 1, pc.soldier.global_position + Vector3(0.6, 0, 0))
				m.hud_message.emit("Carne cozida", 1.6)
				Audio.play_at("impact_sand", f.global_position, {"volume_db": -8.0, "pitch": 1.6, "max_distance": 20.0})


func _atualizar_dica() -> void:
	var txt := ""
	if _livre():
		var s := pc.soldier
		var f: Node3D = Fogueira.qualquer_perto(get_tree(), s.global_position, ALCANCE_FOGO)
		var md := _modo_fogo(f)
		if not md.is_empty():
			txt = ("Segure E: acender fogueira" if md.modo == "acender" else "Segure E: cozinhar carne") + "   ·   V: pôr lenha"
		elif f != null:
			txt = ("Fogueira acesa: %d min" % int(f.minutos()) if f.acesa else "Fogueira apagada (precisa de fósforos e lenha: V)") + "   ·   V: pôr lenha"
		elif em_id == "machado":
			var v = corte._vegetacao()
			var j: int = v.arvore_mais_proxima(s.global_position + Vector3(-sin(s.yaw), 0, -cos(s.yaw)) * 1.2, 2.0) if v != null else -1
			txt = "Clique: cortar árvore" if j >= 0 else "Machado na mão: chegue perto de uma árvore"
		elif em_id == "kit_fogueira" or em_id == "graveto" or em_id == "tora":
			txt = "Clique: montar fogueira"
	_dica.text = txt
	_dica.visible = txt != ""
