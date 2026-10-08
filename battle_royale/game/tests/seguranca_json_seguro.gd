extends Node
## JsonSeguro: arquivo ausente/inválido/de outro tipo vira padrão (sem erro); JSON válido é lido igual. Uso: --path game res://tests/seguranca_json_seguro.tscn
## Linhas SEGURANCA_JSON ok/FAIL; falha = exit code 1.

var falhas := 0
const TMP := "user://seguranca_json_teste/"


func _ok(cond: bool, msg: String) -> void:
	print("SEGURANCA_JSON %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		falhas += 1


func _escrever(nome: String, texto: String) -> String:
	DirAccess.make_dir_recursive_absolute(TMP)
	var p := TMP + nome
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(texto)
	f.close()
	return p


func _ready() -> void:
	var lista := _escrever("lista.json", "[1, 2]")
	var quebrado := _escrever("quebrado.json", "{ nao fecha")
	var vazio := _escrever("vazio.json", "")
	var dic := _escrever("dic.json", "{\"a\": {\"x\": 1}, \"b\": [3]}")
	_ok(JsonSeguro.ler(lista, TYPE_DICTIONARY) == null, "lista onde se espera dicionário vira null")
	_ok(JsonSeguro.dict(lista) == {}, "dict() de lista vira {}")
	# JSON do Godot entrega números como float; comparar com inteiros literais falhou nesta suíte
	_ok(JsonSeguro.array(lista) == [1.0, 2.0], "array() lê lista válida")
	_ok(JsonSeguro.dict(quebrado) == {}, "JSON quebrado vira {}")
	_ok(JsonSeguro.dict(vazio) == {}, "arquivo vazio vira {}")
	_ok(JsonSeguro.dict("user://nao_existe_xyz.json") == {}, "arquivo ausente vira {} sem erro")
	_ok(JsonSeguro.array("user://nao_existe_xyz.json") == [], "array() ausente vira []")
	var d := JsonSeguro.dict(dic)
	_ok(d.get("b") == [3.0] and JsonSeguro.mapa(d, "a") == {"x": 1.0}, "dicionário válido é lido igual")
	_ok(JsonSeguro.lista(d, "a") == [], "lista() de campo que é dicionário vira []")
	_ok(JsonSeguro.lista(d, "b") == [3.0], "lista() de campo que é lista passa")
	_ok(JsonSeguro.lista(null, "b") == [], "lista() de null vira []")
	_ok(JsonSeguro.mapa(d, "b") == {}, "mapa() de campo que é lista vira {}")
	# arquivos reais do mapa continuam lendo como antes
	_ok(JsonSeguro.dict("res://maps/ilha/ilha_layout.json").size() > 0, "ilha_layout.json lê como dicionário")
	_ok(JsonSeguro.dict("res://maps/ilha/detalhes_refino.json").has("props"), "detalhes_refino.json tem 'props'")
	_ok(JsonSeguro.dict("res://maps/ilha/casas_pacote.json").has("casas"), "casas_pacote.json tem 'casas'")
	_ok(JsonSeguro.dict("res://maps/ilha/cenario_atualizacao.json").has("pontes"), "cenario_atualizacao.json tem 'pontes'")
	for f in ["lista.json", "quebrado.json", "vazio.json", "dic.json"]:
		DirAccess.remove_absolute(TMP + f)
	DirAccess.remove_absolute(TMP)
	print("SEGURANCA_JSON ", "TUDO_OK" if falhas == 0 else "FALHAS=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
