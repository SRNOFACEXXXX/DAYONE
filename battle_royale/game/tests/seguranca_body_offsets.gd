extends Node
## Offsets de arma (JSON): texto inválido ou não-Dictionary vira {} em vez de quebrar. Uso: --path game res://tests/seguranca_body_offsets.tscn
## Linhas SEGURANCA_OFFSETS ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_OFFSETS %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	_ok(BodyModel.ler_offsets("") == {}, "vazio vira {}")
	_ok(BodyModel.ler_offsets("null") == {}, "null vira {}")
	_ok(BodyModel.ler_offsets("[1, 2]") == {}, "lista vira {}")
	_ok(BodyModel.ler_offsets("{\"_scale\": 2.0}").get("_scale") == 2.0, "dicionário válido passa")
	_ok(BodyModel.ler_offsets("{ quebrado") == {}, "JSON quebrado vira {}")
	print("SEGURANCA_OFFSETS ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
