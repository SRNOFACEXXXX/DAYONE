extends Node
## Valores do settings.cfg são validados (tipo, faixa, NaN, objeto, nome longo). Uso: --path game res://tests/seguranca_settings.tscn
## Linhas SEGURANCA_SETTINGS ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_SETTINGS %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	_ok(Settings.valor_seguro("quality", 9) == 2, "quality acima da faixa vira 2")
	_ok(Settings.valor_seguro("quality", -4) == 0, "quality abaixo da faixa vira 0")
	_ok(Settings.valor_seguro("quality", "lixo") == null, "quality texto é rejeitado")
	_ok(typeof(Settings.valor_seguro("quality", 1.0)) == TYPE_INT, "quality float vira int")
	_ok(Settings.valor_seguro("fov", 500.0) == 120.0, "fov limitado a 120")
	_ok(Settings.valor_seguro("fov", -3) == 60.0, "fov int vira float limitado a 60")
	_ok(Settings.valor_seguro("render_scale", 0.1) == 0.5, "render_scale mínimo 0,5")
	_ok(Settings.valor_seguro("sensitivity", NAN) == null, "NaN é rejeitado")
	_ok(Settings.valor_seguro("sensitivity", INF) == null, "infinito é rejeitado")
	_ok(Settings.valor_seguro("invert_y", "sim") == null, "bool com texto é rejeitado")
	_ok(Settings.valor_seguro("invert_y", true) == true, "bool válido passa")
	_ok(Settings.valor_seguro("crosshair_color", "red") == null, "cor como texto é rejeitada")
	_ok(Settings.valor_seguro("crosshair_color", Color.RED) == Color.RED, "cor válida passa")
	_ok(Settings.valor_seguro("max_fps", [1, 2]) == null, "array em número é rejeitado")
	_ok(Settings.valor_seguro("max_fps", Settings) == null, "objeto em número é rejeitado")
	_ok(Settings.valor_seguro("max_fps", -5) == 0, "max_fps negativo vira 0")
	var nome: Variant = Settings.valor_seguro("player_name", "n".repeat(100))
	_ok(String(nome).length() == Settings.NOME_MAX, "nome longo cortado em %d" % Settings.NOME_MAX)
	print("SEGURANCA_SETTINGS ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
