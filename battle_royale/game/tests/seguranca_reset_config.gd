extends Node
## Game.reset_config() volta a config de partida ao padrão, no mesmo dicionário. Uso: --path game res://tests/seguranca_reset_config.tscn
## Linhas SEGURANCA_RESET ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_RESET %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	var ref: Dictionary = Game.config
	Game.config["bots_per_team"] = 99
	Game.config["map"] = "poeira"
	Game.reset_config()
	_ok(Game.config == Game.CONFIG_PADRAO, "config volta ao padrão")
	_ok(is_same(ref, Game.config), "mesma referência do dicionário")
	print("SEGURANCA_RESET ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
