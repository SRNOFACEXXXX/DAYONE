extends Node
## --map=<desconhecido> é ignorado (não quebra a partida); mapa válido é aceito. Uso: --path game res://tests/seguranca_args.tscn
## Linhas SEGURANCA_ARGS ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_ARGS %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	var antes: String = Game.config["map"]
	Game.aplicar_argumentos(["--map=nao_existe"])
	_ok(Game.config["map"] == antes, "mapa desconhecido não altera config (%s)" % Game.config["map"])
	Game.aplicar_argumentos(["--map=../../x"])
	_ok(Game.config["map"] == antes, "mapa com caminho não altera config")
	Game.aplicar_argumentos(["--map=poeira"])
	_ok(Game.config["map"] == "poeira", "mapa válido é aceito")
	Game.config["map"] = antes
	print("SEGURANCA_ARGS ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
