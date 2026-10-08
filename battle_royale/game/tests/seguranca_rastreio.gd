extends Node
## Rastreio.gravar() grava o .txt e o .json em user://rastreio/ e devolve o caminho (regressão do null-check). Uso: --path game res://tests/seguranca_rastreio.tscn
## Linhas SEGURANCA_RASTREIO ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_RASTREIO %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	await get_tree().process_frame
	var txt: String = Rastreio.gravar()
	_ok(txt.begins_with("user://rastreio/") and txt.ends_with(".txt"), "gravar devolve o .txt")
	_ok(FileAccess.file_exists(txt), "o .txt existe no disco")
	_ok(FileAccess.file_exists(txt.get_basename() + ".json"), "o .json existe no disco")
	print("SEGURANCA_RASTREIO ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
