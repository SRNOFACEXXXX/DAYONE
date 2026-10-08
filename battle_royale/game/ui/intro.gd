extends Control
## Cutscene de abertura (trailer). Por baixo do vídeo o Loading já aquece shaders e recursos da partida (aquecimento em
## segundo plano, com orçamento por quadro para não travar o vídeo). Qualquer tecla/clique pula e vai para o menu.

const VIDEO := "res://assets/video/intro.ogv"
const MENU := "res://ui/main_menu.tscn"

var _player: VideoStreamPlayer
var _dica: Label
var _saindo := false
var _t := 0.0
var _pulavel_em := 0.35     # ignora o clique/tecla que abriu o jogo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	# sem vídeo (ou em teste automatizado): vai direto ao menu
	if Game.test_mode or not Game.test_args.is_empty() or not ResourceLoader.exists(VIDEO):
		_ir_menu.call_deferred()
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_player = VideoStreamPlayer.new()
	_player.stream = load(VIDEO)
	_player.expand = true
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_ir_menu)
	add_child(_player)
	_player.play()
	_dica = Label.new()
	_dica.text = "Pressione qualquer tecla para pular"
	_dica.add_theme_font_size_override("font_size", 16)
	_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_dica.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_dica.offset_left = -380.0
	_dica.offset_top = -44.0
	_dica.offset_right = -20.0
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dica.modulate.a = 0.0
	add_child(_dica)
	# aquecimento de shaders/recursos em segundo plano enquanto o vídeo toca
	get_tree().create_timer(0.8).timeout.connect(Loading.iniciar_aquecimento)


func _process(dt: float) -> void:
	_t += dt
	if _dica:
		_dica.modulate.a = clampf((_t - 1.5) / 1.0, 0.0, 1.0) * (0.6 + 0.4 * sin(_t * 2.5))


func _input(e: InputEvent) -> void:
	if _saindo or _t < _pulavel_em:
		return
	var pula: bool = (e is InputEventKey and e.pressed and not e.echo) \
		or (e is InputEventMouseButton and e.pressed) \
		or (e is InputEventJoypadButton and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed)
	if pula:
		get_viewport().set_input_as_handled()
		_ir_menu()


func _ir_menu() -> void:
	if _saindo:
		return
	_saindo = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _player:
		var tw := create_tween()
		tw.tween_property(_player, "modulate:a", 0.0, 0.25)
		await tw.finished
		_player.stop()
	get_tree().change_scene_to_file(MENU)
