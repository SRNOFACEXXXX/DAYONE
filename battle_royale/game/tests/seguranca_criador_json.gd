extends Node
## Personagem salvo (personagem.json) só aceita escolhas válidas de tipo certo. Uso: --path game res://tests/seguranca_criador_json.tscn
## Linhas SEGURANCA_CRIADOR ok/FAIL; falha = exit code 1.

var falhas := 0


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_CRIADOR %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _ready() -> void:
	var v := CriadorPersonagem.validar_escolhas({"rosto": ["x"], "cabelo": "Hairstyle_male_012", "pele": "lixo", "tronco": [1, 2]})
	_ok(v.get("cabelo") == 1, "opção de texto válida vira índice")
	_ok(not v.has("rosto") and not v.has("tronco"), "lista e opção desconhecida são ignoradas")
	_ok(not v.has("pele"), "pele em texto é ignorada")
	_ok(CriadorPersonagem.validar_escolhas({"pele": 99}).get("pele") == CriadorPersonagem.TONS.size() - 1, "pele fora da faixa é limitada")
	_ok(CriadorPersonagem.texto_de({"pernas": [1]}, "pernas", "x") == "x", "texto_de: não-String vira padrão")
	_ok(CriadorPersonagem.texto_de({"pernas": "Shorts_003"}, "pernas", "x") == "Shorts_003", "texto_de: String passa")
	print("SEGURANCA_CRIADOR ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
