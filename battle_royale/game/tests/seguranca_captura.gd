extends Node
## Caminho de captura de tela: só user://; caminho externo cai na pasta padrão. Uso: --path game res://tests/seguranca_captura.tscn
## Linhas SEGURANCA_CAPTURA ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_CAPTURA %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	var a: String = Settings.caminho_captura("res://teste.png")
	_ok(a.begins_with("user://capturas/") and a.ends_with(".png"), "res:// vira pasta padrão: %s" % a)
	var b: String = Settings.caminho_captura("/tmp/x.png")
	_ok(b.begins_with("user://capturas/"), "caminho absoluto vira pasta padrão")
	var c: String = Settings.caminho_captura("user://../../x.png")
	_ok(c.begins_with("user://capturas/"), "traversal com .. vira pasta padrão")
	_ok(Settings.caminho_captura("user://minha.png") == "user://minha.png", "user:// válido é mantido")
	print("SEGURANCA_CAPTURA ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
