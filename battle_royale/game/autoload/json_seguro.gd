class_name JsonSeguro
extends RefCounted
## Leitura de JSON com checagem de tipo. Arquivo ausente -> null sem aviso (quem chama decide, como antes);
## arquivo que não é JSON ou tem outro formato -> push_warning e null. Com dados válidos devolve exatamente o que o JSON tem.
## Use tipo = TYPE_DICTIONARY / TYPE_ARRAY, ou -1 para aceitar qualquer valor não nulo.


static func ler(caminho: String, tipo: int = -1) -> Variant:
	if not FileAccess.file_exists(caminho):
		return null
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if v == null or (tipo >= 0 and typeof(v) != tipo):
		push_warning("JSON ignorado (formato inesperado): %s" % caminho)
		return null
	return v


## Dictionary do arquivo, ou {} (ausente ou inválido).
static func dict(caminho: String) -> Dictionary:
	var v: Variant = ler(caminho, TYPE_DICTIONARY)
	return v if v != null else {}


## Array do arquivo, ou [] (ausente ou inválido).
static func array(caminho: String) -> Array:
	var v: Variant = ler(caminho, TYPE_ARRAY)
	return v if v != null else []


## d[chave] se for Array; senão []. Para `for x in JsonSeguro.lista(d, "areas")` sem quebrar com campo errado.
static func lista(d: Variant, chave: String) -> Array:
	var v: Variant = d.get(chave) if d is Dictionary else null
	return v if v is Array else []


## d[chave] se for Dictionary; senão {}.
static func mapa(d: Variant, chave: String) -> Dictionary:
	var v: Variant = d.get(chave) if d is Dictionary else null
	return v if v is Dictionary else {}
