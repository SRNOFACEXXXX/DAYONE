extends Node
## Miras (JSON): só Dictionary entra; entrada de arma que não é dicionário vira {}. Uso: --path game res://tests/seguranca_viewmodel_miras.tscn
## Linhas SEGURANCA_MIRAS ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_MIRAS %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	_ok(ViewModel.ler_miras("[1]") == {}, "lista vira {}")
	_ok(ViewModel.ler_miras("") == {}, "texto vazio vira {}")
	var m := ViewModel.ler_miras("{\"ak\": {\"x\": 1}, \"m4\": 5}")
	_ok(ViewModel.cfg_da_arma(m, "ak").get("x") == 1, "arma com dicionário passa")
	_ok(ViewModel.cfg_da_arma(m, "m4") == {}, "arma com número vira {}")
	_ok(ViewModel.cfg_da_arma(m, "nao_existe") == {}, "arma ausente vira {}")
	print("SEGURANCA_MIRAS ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
