extends Node
## Persistent user settings, input map and display/quality application.

signal changed

const PATH := "user://settings.cfg"

# --- controles ---
var sensitivity := 2.0            # estilo CS: graus por contagem = sens * 0.022
var invert_y := false
var fov := 90.0                   # FOV horizontal em 4:3 (padrão do CS)
var viewmodel_fov := 62.0
var viewmodel_bob := 1.0
var camera_bob := 1.0   # 0–1: balanço da câmera ao andar (a arma balança à parte)

# --- áudio (0..1) ---
var master_volume := 0.85
var sfx_volume := 1.0
var music_volume := 0.55
var voice_volume := 0.9

# --- vídeo ---
var quality := 0                  # 0 baixo · 1 médio · 2 alto (ilha de 1,2 km na GT 730: começa no baixo)
var render_scale := 1.0
var fullscreen := true
var vsync := true
var show_fps := false
var max_fps := 0

# --- mira ---
var crosshair_color := Color("9BFF7A")
var crosshair_size := 5.0
var crosshair_gap := 3.0
var crosshair_thickness := 2.0
var crosshair_dot := false
var crosshair_dynamic := true

var player_name := "Você"

const BINDINGS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"jump": [KEY_SPACE], "crouch": [KEY_CTRL], "walk": [KEY_ALT], "sprint": [KEY_SHIFT],
	"fire": [MOUSE_BUTTON_LEFT], "alt_fire": [MOUSE_BUTTON_RIGHT],
	"reload": [KEY_R], "use": [KEY_E], "drop": [KEY_G], "inspect": [KEY_F],
	"heal": [KEY_H],   # H: usa a melhor cura (bandagem 2,5 s / kit médico 5 s); só interrompe ao atirar ou trocar de arma
	"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5],
	"next_weapon": [MOUSE_BUTTON_WHEEL_DOWN], "prev_weapon": [MOUSE_BUTTON_WHEEL_UP],
	"last_weapon": [KEY_Q], "buy_menu": [KEY_B], "scoreboard": [KEY_TAB],
	"camera_toggle": [KEY_C], "toggle_optic": [KEY_V], "pause": [KEY_ESCAPE], "toggle_fps": [KEY_F9], "screenshot": [KEY_F12],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	apply_display()
	apply_audio()


func _setup_input() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for code: int in BINDINGS[action]:
			var ev: InputEvent
			if action in ["fire", "alt_fire", "next_weapon", "prev_weapon"]:
				var mb := InputEventMouseButton.new()
				mb.button_index = code as MouseButton
				ev = mb
			else:
				var k := InputEventKey.new()
				k.physical_keycode = code as Key
				ev = k
			InputMap.action_add_event(action, ev)


## Faixas aceitas para valores numéricos lidos do disco (um settings.cfg editado à mão não pode quebrar o jogo).
const LIMITES := {
	"sensitivity": Vector2(0.2, 8.0), "fov": Vector2(60.0, 120.0), "viewmodel_fov": Vector2(40.0, 90.0),
	"viewmodel_bob": Vector2(0.0, 2.0), "camera_bob": Vector2(0.0, 2.0),
	"master_volume": Vector2(0.0, 1.0), "sfx_volume": Vector2(0.0, 1.0),
	"music_volume": Vector2(0.0, 1.0), "voice_volume": Vector2(0.0, 1.0),
	"quality": Vector2(0.0, 2.0), "render_scale": Vector2(0.5, 1.0), "max_fps": Vector2(0.0, 500.0),
	"crosshair_size": Vector2(0.0, 40.0), "crosshair_gap": Vector2(0.0, 40.0), "crosshair_thickness": Vector2(0.0, 20.0),
}
const NOME_MAX := 24


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for key in _keys():
		if cf.has_section_key("s", key):
			var v: Variant = valor_seguro(key, cf.get_value("s", key))
			if v != null:
				set(key, v)


## Devolve o valor lido do disco já validado: mesmo tipo do padrão (int/float convertidos entre si), sem NaN/infinito,
## limitado à faixa de LIMITES e nome com até NOME_MAX caracteres. Tipo errado (objeto, texto onde há número...) -> null.
func valor_seguro(key: String, v: Variant) -> Variant:
	if v == null:
		return null
	var tipo := typeof(get(key))
	if tipo == TYPE_FLOAT and typeof(v) == TYPE_INT:
		v = float(v)
	elif tipo == TYPE_INT and typeof(v) == TYPE_FLOAT:
		v = int(v)
	if typeof(v) != tipo:
		return null
	if tipo == TYPE_FLOAT and (is_nan(v) or is_inf(v)):
		return null
	if tipo == TYPE_STRING:
		return String(v).substr(0, NOME_MAX) if key == "player_name" else v
	if LIMITES.has(key):
		var lim: Vector2 = LIMITES[key]
		var c := clampf(float(v), lim.x, lim.y)
		return int(c) if tipo == TYPE_INT else c
	return v


func save_settings() -> void:
	var cf := ConfigFile.new()
	for key in _keys():
		cf.set_value("s", key, get(key))
	cf.save(PATH)
	changed.emit()


func _keys() -> Array[String]:
	return ["sensitivity", "invert_y", "fov", "viewmodel_fov", "viewmodel_bob", "camera_bob", "master_volume",
		"sfx_volume", "music_volume", "voice_volume", "quality", "render_scale", "fullscreen",
		"vsync", "show_fps", "max_fps", "crosshair_color", "crosshair_size", "crosshair_gap",
		"crosshair_thickness", "crosshair_dot", "crosshair_dynamic", "player_name"]


## Vertical FOV for Camera3D (keep_height) from the CS-style horizontal 4:3 FOV.
func vertical_fov(h_fov_43: float = -1.0) -> float:
	var h := fov if h_fov_43 < 0.0 else h_fov_43
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(h) * 0.5) * 0.75))


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out"):   # capturas de teste (tour): janela 1024x768 sem MSAA, fixada pelo próprio teste
			return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			# FXAA de viewport não está disponível no renderer Compatibility usado pela GT 730.
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
	changed.emit()


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Music", music_volume)
	_set_bus("Voice", voice_volume)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		show_fps = not show_fps
		changed.emit()
	elif event.is_action_pressed("screenshot"):
		take_screenshot()


func take_screenshot(path: String = "") -> String:
	var img := get_viewport().get_texture().get_image()
	path = caminho_captura(path)
	if path.get_base_dir() == "user://capturas":
		DirAccess.make_dir_recursive_absolute("user://capturas")
	img.save_png(path)
	return path


## Caminho seguro da captura: vazio ou fora de user:// (ex.: res://, caminho absoluto, ../) cai na pasta padrão.
func caminho_captura(path: String = "") -> String:
	if path != "" and path.begins_with("user://") and not path.contains(".."):
		return path
	if path != "":
		push_warning("Captura fora de user:// ignorada: %s" % path)
	return "user://capturas/%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
