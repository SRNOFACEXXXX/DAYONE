extends Node
## Voltar ao menu solta as cenas da partida do cache e mantém GLB/shaders. Uso: --path game res://tests/seguranca_cache_cenas.tscn
## Linhas SEGURANCA_CACHE ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_CACHE %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	Loading._cache["res://fake/partida.tscn"] = 1
	Loading._cache["res://fake/modelo.glb"] = 2
	Loading.soltar_cenas()
	_ok(not Loading._cache.has("res://fake/partida.tscn"), "cena (.tscn) é solta")
	_ok(Loading._cache.has("res://fake/modelo.glb"), "GLB continua no cache (aquecimento)")
	Loading._cache.erase("res://fake/modelo.glb")
	print("SEGURANCA_CACHE ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
