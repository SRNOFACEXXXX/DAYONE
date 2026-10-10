class_name CriadorPersonagem
extends Control
## Tela PERSONAGEM (entre JOGAR e a partida): monta o boneco modular do pack creative_character
## (assets/models/atualizacao/player/dayone_base.glb — todas as peças skinned no MESMO Skeleton3D;
## trocar peça = alternar visible). Slots com setas < >, ALEATÓRIO, CONFIRMAR / JOGAR, boneco girando por arraste.
## Salva em user://personagem.json. Enquanto o jogador monta, Loading aquece shaders/recursos da partida atrás.

signal voltar
signal confirmado(dados: Dictionary)

const MODELO := "res://assets/models/atualizacao/player/dayone_base.glb"
const ARQUIVO := "user://personagem.json"
const ALTURA := 1.8
## Peças fora do criador (fantasias/acessórios bobos do pack): sempre escondidas.
const OCULTAS := ["Costume_6_001", "Costume_10_001", "Clown_nose_001", "Pacifier_001", "Hat_049"]
## slot -> [rótulo, [[malha ou "", nome da opção], ...]]
const SLOTS := [
	["rosto", "ROSTO", [["Male_emotion_usual_001", "SÉRIO"], ["Male_emotion_happy_002", "SORRIDENTE"], ["Male_emotion_angry_003", "BRAVO"]]],
	["cabelo", "CABELO", [["Hairstyle_male_010", "CURTO"], ["Hairstyle_male_012", "TOPETE"], ["", "RASPADO"]]],
	["bigode", "BIGODE", [["", "NENHUM"], ["Moustache_001", "CHEIO"], ["Moustache_002", "FINO"]]],
	["cabeca", "CHAPÉU / CAPACETE", [["Hat_057", "CAPACETE"], ["Hat_010", "CHAPÉU DE PALHA"], ["Headphones_002", "FONE"], ["", "NENHUM"]]],
	["oculos", "ÓCULOS", [["", "NENHUM"], ["Glasses_004", "ARMAÇÃO"], ["Glasses_006", "ESCURO"]]],
	["tronco", "TRONCO", [["Outerwear_029", "JAQUETA"], ["Outerwear_036", "MOLETOM"], ["T_Shirt_009", "CAMISETA"]]],
	["luvas", "LUVAS", [["Gloves_014", "TÁTICA"], ["Gloves_006", "SIMPLES"], ["", "SEM LUVA"]]],
	["pernas", "PERNAS", [["Pants_010", "CALÇA CARGO"], ["Pants_014", "CALÇA PRETA"], ["Shorts_003", "BERMUDA"]]],
	["pes", "PÉS", [["Shoe_Sneakers_009", "TÊNIS"], ["Shoe_Slippers_002", "CHINELO"], ["Shoe_Slippers_005", "SANDÁLIA"]]],
]
## Tom de pele: cor lisa no corpo (o corpo do pack é manequim de uma cor só no atlas).
const TONS := [["CLARO", Color(0.96, 0.8, 0.68)], ["MÉDIO", Color(0.86, 0.64, 0.48)], ["MORENO", Color(0.68, 0.47, 0.33)],
		["ESCURO", Color(0.47, 0.31, 0.21)], ["RETINTO", Color(0.3, 0.2, 0.14)]]

var stage: MenuStage
var boneco: Node3D
var anim: AnimationPlayer
var escolha := {}                 # slot -> índice da opção ("pele" -> índice do tom)
var _malhas := {}                 # nome -> MeshInstance3D
var _mat_pele: StandardMaterial3D
var _valores := {}                # slot -> Label
var _yaw := -18.0
var _arrastando := false
var _prep_lbl: Label
var _prep_bar: ProgressBar
var _btn_jogar: Button
var _confirmado := false


func _init(p_stage: MenuStage) -> void:
	stage = p_stage
	name = "CriadorPersonagem"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in SLOTS:
		escolha[s[0]] = 0
	escolha["pele"] = 1
	_carregar()
	_montar_boneco()
	_montar_ui()
	_aplicar()


# --------------------------------------------------------------------------- dados
func dados() -> Dictionary:
	var d := {"versao": 1}
	for s in SLOTS:
		d[s[0]] = String(s[2][int(escolha[s[0]])][0])
	d["pele"] = int(escolha["pele"])
	d["pele_cor"] = (TONS[int(escolha["pele"])][1] as Color).to_html(false)
	return d


func _carregar() -> void:
	if not FileAccess.file_exists(ARQUIVO):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if d is Dictionary:
		escolha.merge(validar_escolhas(d), true)


## Escolhas válidas de um personagem.json: slot -> índice da opção, "pele" -> índice do tom.
## Valor de tipo errado (lista, texto onde é número, opção desconhecida) é ignorado, não quebra o menu.
static func validar_escolhas(d: Dictionary) -> Dictionary:
	var out := {}
	for s in SLOTS:
		var v: Variant = d.get(s[0])
		if v is String:
			for i in (s[2] as Array).size():
				if String(s[2][i][0]) == v:
					out[s[0]] = i
	var p: Variant = d.get("pele")
	if p is float or p is int:
		out["pele"] = clampi(int(p), 0, TONS.size() - 1)
	return out


## Texto de uma chave do personagem.json, ou o padrão se não for String.
static func texto_de(d: Dictionary, chave: String, padrao: String) -> String:
	var v: Variant = d.get(chave)
	return v if v is String else padrao


func salvar() -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados(), " "))
		f.close()


# --------------------------------------------------------------------------- boneco
## Instancia o boneco base e aplica um dicionário de escolha (reutilizável fora do menu, ex.: corpo de 3ª pessoa).
static func instanciar_base() -> Node3D:
	if not ResourceLoader.exists(MODELO):
		return null
	var n := (load(MODELO) as PackedScene).instantiate() as Node3D
	var corpo := n.find_child("Body_010", true, false) as MeshInstance3D
	if corpo:
		var h := corpo.get_aabb().size.y
		if h > 0.01:
			n.scale = Vector3.ONE * (ALTURA / h)
	return n


static func aplicar_dados(n: Node3D, d: Dictionary) -> void:
	var visiveis := {"Body_010": true}
	for s in SLOTS:
		var m := texto_de(d, s[0], String(s[2][0][0]))
		if m != "":
			visiveis[m] = true
	if texto_de(d, "pernas", "") == "Shorts_003":
		visiveis["Socks_008"] = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = visiveis.has(String(mi.name))


## Escolha salva (user://personagem.json) ou vazio se o jogador nunca passou pelo criador.
static func carregar_dados() -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	return d if d is Dictionary else {}


## Tom de pele: material próprio só no corpo (mesmo shader do atlas, sem textura, cor lisa).
static func aplicar_pele(n: Node3D, cor: Color) -> void:
	var corpo := n.find_child("Body_010", true, false) as MeshInstance3D
	if corpo == null or corpo.mesh == null:
		return
	var base := corpo.mesh.surface_get_material(0)
	if base is StandardMaterial3D:
		var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_texture = null
		m.albedo_color = cor
		corpo.material_override = m


## Boneco do jogo (escala 1 = mesmo esqueleto/altura do soldado.glb): peças + pele do json. null se faltar o modelo.
static func boneco_jogo(d: Dictionary, animar_idle := false) -> Node3D:
	if not ResourceLoader.exists(MODELO):
		return null
	var n := (load(MODELO) as PackedScene).instantiate() as Node3D
	aplicar_dados(n, d)
	var cor := Color(String(d.get("pele_cor", (TONS[1][1] as Color).to_html(false))))
	aplicar_pele(n, cor)
	if animar_idle:
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("Idle_Breathing"):
			ap.get_animation("Idle_Breathing").loop_mode = Animation.LOOP_LINEAR
			ap.play("Idle_Breathing")
	return n


func _montar_boneco() -> void:
	boneco = instanciar_base()
	if boneco == null:
		return
	boneco.name = "BonecoDayone"
	for mi in boneco.find_children("*", "MeshInstance3D", true, false):
		_malhas[String(mi.name)] = mi
	# tom de pele: material próprio só do corpo (mesma configuração do material do atlas = mesmo shader)
	var corpo := _malhas.get("Body_010") as MeshInstance3D
	if corpo and corpo.mesh:
		var base := corpo.mesh.surface_get_material(0)
		if base is StandardMaterial3D:
			_mat_pele = (base as StandardMaterial3D).duplicate()
			_mat_pele.albedo_texture = null
			corpo.material_override = _mat_pele
	anim = boneco.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for nome in ["Idle_Breathing", "Idle_Relaxed"]:
			if anim.has_animation(nome):
				anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
				anim.play(nome)
				break
	boneco.rotation_degrees.y = _yaw


func _aplicar() -> void:
	for s in SLOTS:
		var op: Array = s[2][int(escolha[s[0]])]
		if _valores.has(s[0]):
			(_valores[s[0]] as Label).text = String(op[1])
	if _valores.has("pele"):
		(_valores["pele"] as Label).text = String(TONS[int(escolha["pele"])][0])
	if boneco == null:
		return
	aplicar_dados(boneco, dados())
	if _mat_pele:
		_mat_pele.albedo_color = TONS[int(escolha["pele"])][1]


func trocar(slot: String, passo: int) -> void:
	var n := TONS.size() if slot == "pele" else _opcoes(slot).size()
	escolha[slot] = posmod(int(escolha[slot]) + passo, n)
	_aplicar()
	Audio.ui("ui_click")


func _opcoes(slot: String) -> Array:
	for s in SLOTS:
		if s[0] == slot:
			return s[2]
	return []


func aleatorio() -> void:
	for s in SLOTS:
		escolha[s[0]] = randi() % (s[2] as Array).size()
	escolha["pele"] = randi() % TONS.size()
	_aplicar()


func confirmar() -> void:
	if _confirmado:
		return
	_confirmado = true
	salvar()
	Audio.ui("ui_click")
	# partida pré-montada atrás do criador: entra direto nela (sem passar pelo Game.start_match do menu)
	if Loading.has_method("tem_pre_montagem") and Loading.tem_pre_montagem():
		Loading.entrar_pre_montada()
		return
	confirmado.emit(dados())


# --------------------------------------------------------------------------- interface
func abrir() -> void:
	visible = true
	_confirmado = false
	if Loading.has_method("pre_montar") and not Game.test_args.has("sem_pre"):
		Loading.pre_montar()   # monta a partida escondida enquanto o jogador escolhe o boneco
	if boneco:
		stage.mostrar_boneco(boneco)
		boneco.position = Vector3.ZERO
		boneco.rotation_degrees.y = _yaw
	stage.enquadrar(-0.55, 1.0, 4.3)


func fechar() -> void:
	visible = false
	stage.mostrar_boneco(null)
	stage.enquadrar_padrao()


func _montar_ui() -> void:
	# área de giro: tudo à direita do painel
	var giro := Control.new()
	giro.name = "AreaGiro"
	giro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	giro.offset_left = 44 + 360
	giro.mouse_filter = Control.MOUSE_FILTER_STOP
	giro.mouse_default_cursor_shape = Control.CURSOR_DRAG
	giro.gui_input.connect(_giro_input)
	add_child(giro)

	var painel := YPanel.new("PERSONAGEM", true)
	painel.name = "PainelPersonagem"
	painel.anchor_bottom = 1.0
	painel.offset_left = 44
	painel.offset_right = 44 + 350
	painel.offset_top = 40
	painel.offset_bottom = -40
	add_child(painel)
	var sub := YUI.label("MONTE SEU SOBREVIVENTE", 15, YUI.YELLOW)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	painel.body.add_child(sub)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 3)
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	painel.body.add_child(lista)
	for s in SLOTS:
		lista.add_child(_linha(String(s[0]), String(s[1])))
	lista.add_child(_linha("pele", "TOM DE PELE"))

	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", 6)
	painel.body.add_child(acoes)
	var b_rand := _botao("ALEATÓRIO", false, 18)
	b_rand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_rand.pressed.connect(aleatorio)
	acoes.add_child(b_rand)
	var b_voltar := _botao("VOLTAR", false, 18)
	b_voltar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_voltar.pressed.connect(func() -> void: voltar.emit())
	acoes.add_child(b_voltar)
	_btn_jogar = _botao("CONFIRMAR  ·  JOGAR", true, 24)
	_btn_jogar.name = "Confirmar"
	_btn_jogar.custom_minimum_size = Vector2(0, 50)
	_btn_jogar.pressed.connect(confirmar)
	painel.body.add_child(_btn_jogar)

	# rodapé: preparo do mundo em segundo plano
	var rod := YPanel.new("", false)
	rod.name = "PreparoMundo"
	rod.anchor_left = 1.0
	rod.anchor_right = 1.0
	rod.anchor_top = 1.0
	rod.anchor_bottom = 1.0
	rod.offset_left = -44 - 300
	rod.offset_right = -44
	rod.offset_top = -40 - 56
	rod.offset_bottom = -40
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rod)
	_prep_lbl = YUI.label("Preparando o mundo…", 14, YUI.TEXT, false)
	rod.body.add_child(_prep_lbl)
	_prep_bar = ProgressBar.new()
	_prep_bar.show_percentage = false
	_prep_bar.custom_minimum_size = Vector2(0, 6)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(1, 1, 1, 0.12)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = YUI.YELLOW
	_prep_bar.add_theme_stylebox_override("background", fundo)
	_prep_bar.add_theme_stylebox_override("fill", cheio)
	rod.body.add_child(_prep_bar)

	var dica := YUI.label("Arraste para girar", 14, YUI.DIM, false)
	dica.anchor_left = 0.5
	dica.anchor_right = 0.5
	dica.anchor_top = 1.0
	dica.anchor_bottom = 1.0
	dica.offset_left = 0
	dica.offset_right = 300
	dica.offset_top = -34
	dica.offset_bottom = -12
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dica)


func _linha(slot: String, rotulo: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var cab := YUI.label(rotulo, 12, YUI.DIM, false)
	col.add_child(cab)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	var esq := _seta("<")
	esq.pressed.connect(trocar.bind(slot, -1))
	row.add_child(esq)
	var fundo := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06)
	sb.set_corner_radius_all(2)
	fundo.add_theme_stylebox_override("panel", sb)
	fundo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fundo)
	var v := YUI.label("", 18, YUI.TEXT)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fundo.add_child(v)
	_valores[slot] = v
	var dir := _seta(">")
	dir.pressed.connect(trocar.bind(slot, 1))
	row.add_child(dir)
	return col


func _seta(t: String) -> Button:
	var b := _botao(t, false, 20)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(34, 30)
	var n := b.get_theme_stylebox("normal") as StyleBoxFlat
	n.content_margin_left = 0
	return b


func _botao(t: String, primario: bool, tam: int) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_override("font", UIStyle.font(700, "title"))
	b.add_theme_font_size_override("font_size", tam)
	b.add_theme_color_override("font_color", YUI.INK if primario else YUI.TEXT)
	b.add_theme_color_override("font_hover_color", YUI.INK if primario else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", YUI.INK if primario else YUI.YELLOW)
	var normal := StyleBoxFlat.new()
	normal.bg_color = YUI.YELLOW if primario else Color(1, 1, 1, 0.08)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = YUI.YELLOW.lightened(0.25) if primario else Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.mouse_entered.connect(func() -> void: Audio.ui("ui_hover"))
	return b


func _giro_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_arrastando = (ev as InputEventMouseButton).pressed
	elif ev is InputEventMouseMotion and _arrastando:
		_yaw += (ev as InputEventMouseMotion).relative.x * 0.5
		if boneco:
			boneco.rotation_degrees.y = _yaw


func girar(graus: float) -> void:
	_yaw += graus
	if boneco:
		boneco.rotation_degrees.y = _yaw


func _process(delta: float) -> void:
	if not visible:
		return
	if boneco and not _arrastando and Input.is_action_pressed("ui_left"):
		girar(-90.0 * delta)
	elif boneco and not _arrastando and Input.is_action_pressed("ui_right"):
		girar(90.0 * delta)
	var p := Loading.preparo_progresso()
	_prep_bar.value = p * 100.0
	_prep_lbl.text = "Mundo pronto — pode jogar" if Loading.preparo_pronto() else "Preparando o mundo…  %d%%" % int(p * 100.0)
