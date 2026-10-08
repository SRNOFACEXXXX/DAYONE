extends Node
## Aquecimento só aceita recursos res:// (nada de user:// ou caminho com ..). Uso: --path game res://tests/seguranca_aquecimento.tscn
## Linhas SEGURANCA_AQUECIMENTO ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_AQUECIMENTO %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	var out: Array[String] = []
	var vistos := {}
	Loading._add(out, vistos, "user://evil.glb")
	Loading._add(out, vistos, "/etc/passwd")
	Loading._add(out, vistos, "res://../evil.glb")
	_ok(out.is_empty(), "caminhos fora de res:// são ignorados")
	Loading._add(out, vistos, "res://autoload/settings.gd")
	_ok(out == ["res://autoload/settings.gd"], "res:// existente é aceito")
	var todos_res := true
	for p in Loading._lista_recursos():
		if not String(p).begins_with("res://"):
			todos_res = false
	_ok(todos_res, "lista de aquecimento só tem res://")
	print("SEGURANCA_AQUECIMENTO ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
