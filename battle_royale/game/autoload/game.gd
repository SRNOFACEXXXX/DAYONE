extends Node
## Global configuration shared between menu and match.

const TEAM_NAMES := ["Terroristas", "Contra-Terroristas"]
const TEAM_SHORT := ["TR", "CT"]
const TEAM_COLORS := [Color("e2a33d"), Color("6aa7e8")]
const DIFFICULTY_NAMES := ["Fácil", "Normal", "Difícil", "Especialista"]

const MAPS := {
	"ilha": {
		"name": "Ilha do Tauá",
		"scene": "res://maps/ilha/ilha.tscn",
		"desc": "Ilha de 1,2 km no litoral brasileiro: vila caiçara, usina, quartel, farol e pista.",
		"thumb": "",
	},
	"poeira": {
		"name": "Poeira",
		"scene": "res://maps/poeira/poeira.tscn",
		"desc": "Cidade de adobe no deserto. Long A, Meio e Túneis até o B.",
		"thumb": "res://maps/poeira/thumb.png",
	},
	"vila": {
		"name": "Vila",
		"scene": "res://maps/vila/vila.tscn",
		"desc": "Vilarejo rural de galpões e casas de madeira.",
		"thumb": "res://maps/vila/thumb.png",
	},
}

var config := {
	"map": "ilha",
	"team": 0,              # 0 TR · 1 CT · -1 automático
	"bots_per_team": 4,     # 5x5 com o jogador
	"difficulty": 1,
	"rounds_to_win": 8,
	"round_time": 115.0,
	"freeze_time": 8.0,
	"buy_time": 20.0,
	"bomb_timer": 40.0,
	"friendly_fire": false,
	"halftime": true,
}

var current_match: Node = null
var test_mode := false        # usado pelos testes automatizados
var test_args: Dictionary = {}

const BOT_NAMES_T := ["Zé Pólvora", "Faísca", "Cabral", "Tijolo", "Caolho", "Sombra", "Lobo", "Brasa", "Poeira", "Carcará"]
const BOT_NAMES_CT := ["Sargento Lima", "Falcão", "Rocha", "Tenente Vidal", "Bravo", "Neblina", "Delta", "Coruja", "Aço", "Guará"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrar_dados_antigos()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			test_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if test_args.has("map"):
		config["map"] = test_args["map"]
	if test_args.has("team"):
		config["team"] = int(test_args["team"])
	if test_args.has("bots"):
		config["bots_per_team"] = int(test_args["bots"])
	if test_args.has("difficulty"):
		config["difficulty"] = int(test_args["difficulty"])


## O jogo virou DAYONE (config/name) e o user:// mudou de pasta: traz configurações e caches da pasta antiga
## ("Ilha Brava — GPT") na primeira execução, sem apagar nada lá.
func _migrar_dados_antigos() -> void:
	if FileAccess.file_exists("user://settings.cfg"):
		return
	var antiga := OS.get_user_data_dir().get_base_dir().path_join("Ilha Brava — GPT")
	if not DirAccess.dir_exists_absolute(antiga):
		return
	var da := DirAccess.open(antiga)
	if da == null:
		return
	for f in da.get_files():
		if f.get_extension() in ["cfg", "png", "json"]:
			DirAccess.copy_absolute(antiga.path_join(f), OS.get_user_data_dir().path_join(f))
	Settings.load_settings()
	Settings.apply_display()
	Settings.apply_audio()


func start_match() -> void:
	get_tree().paused = false
	Loading.show_progress("Abrindo partida...", 2.0)
	get_tree().change_scene_to_file("res://core/br_match.tscn")


func back_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Loading.show_progress("Voltando ao menu...", 98.0)
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	Loading.hide_after_render()
