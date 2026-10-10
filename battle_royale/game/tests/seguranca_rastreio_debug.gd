extends Node
## F9 do rastreio só ativo em build de depuração. Uso: --path game res://tests/seguranca_rastreio_debug.tscn
## Linhas SEGURANCA_RASTREIO_DBG ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_RASTREIO_DBG %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	_ok(Rastreio.is_processing_input() == OS.is_debug_build(), "entrada do F9 segue OS.is_debug_build() = %s" % OS.is_debug_build())
	print("SEGURANCA_RASTREIO_DBG ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
