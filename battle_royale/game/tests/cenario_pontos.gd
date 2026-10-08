extends Node
## Teste de dados (sem subir a partida): os pontos de interesse autorais (maps/ilha/cenario_pontos.json) só usam assets
## existentes, caem em terra firme (altura do height.bin, sem mar nem represa), em terreno suave, longe das casas, e o
## detalhes.gd carrega o arquivo. Pega regressão de coordenada, asset renomeado e ponto dentro d'água.

const ARQ := "res://maps/ilha/cenario_pontos.json"
const N := 601
const STEP := 2.0
const ORIGIN := -600.0
const MIN_PROPS := 40
const MAX_PROPS := 250          # orçamento de draw calls: total de props do arquivo (fundidos em MultiMesh por célula)
const MAX_RAIO := 45.0          # mancha: nenhum prop a mais de 45 m do centro da área
const ARQ_LORE := "res://data/lore/pontos.json"
const MIN_AREAS := 18

var _falhas: Array[String] = []


func _ready() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(ARQ))
	_checar(dados is Dictionary and dados.has("areas"), "cenario_pontos.json precisa de 'areas'")
	if not (dados is Dictionary):
		_terminar()
		return
	var alturas := FileAccess.get_file_as_bytes("res://maps/ilha/height.bin").to_float32_array()
	_checar(alturas.size() == N * N, "height.bin deve ter %d amostras" % (N * N))
	var casas: Array = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/casas_pacote.json")).get("casas", [])

	var props := 0
	var cercas := 0
	var areas: Array = dados.areas
	_checar(areas.size() >= MIN_AREAS, "esperadas >= %d áreas, há %d" % [MIN_AREAS, areas.size()])
	for area in areas:
		var pts: Array = area.get("props", [])
		var dispersa := bool(area.get("disperso", false))   # áreas costeiras de propósito espalhadas (sem raio de mancha)
		_checar(pts.size() >= (1 if dispersa else 3), "área '%s' com poucos props" % area.get("nome", "?"))
		_checar(area.has("lore") and not String(area.get("lore", "")).is_empty(), "área '%s' sem id de lore" % area.get("nome", "?"))
		if not pts.is_empty() and not dispersa:
			var mx := 0.0
			var my := 0.0
			for p in pts:
				mx += float(p.x)
				my += float(p.y)
			mx /= pts.size()
			my /= pts.size()
			var raio := 0.0
			for p in pts:
				raio = maxf(raio, Vector2(float(p.x) - mx, float(p.y) - my).length())
			_checar(raio <= MAX_RAIO, "área '%s' espalhada demais (raio %.1f m): agrupar em mancha" % [area.get("nome", "?"), raio])
		for p in pts:
			props += 1
			var tipo := String(p.tipo)
			_checar(ResourceLoader.exists(_caminho(tipo)), "asset inexistente: %s" % _caminho(tipo))
			var x := float(p.x)
			var zw := -float(p.y)   # design (x leste, y norte) -> mundo (x, z = -y)
			_checar(absf(x) <= 600.0 and absf(float(p.y)) <= 600.0, "%s fora do mapa" % tipo)
			var centro := _altura(alturas, x, zw)
			var minimo := INF
			var maximo := -INF
			for dx in [-3.0, 3.0]:
				for dz in [-3.0, 3.0]:
					var h := _altura(alturas, x + dx, zw + dz)
					minimo = minf(minimo, h)
					maximo = maxf(maximo, h)
			_checar(centro >= .3, "%s em (%.0f, %.0f) sem terra: h=%.2f" % [tipo, x, p.y, centro])
			_checar(minimo >= -.2, "%s em (%.0f, %.0f) com metade na água: min=%.2f" % [tipo, x, p.y, minimo])
			_checar(maximo - minimo <= 3.0, "%s em (%.0f, %.0f) em declive forte: %.2f m" % [tipo, x, p.y, maximo - minimo])
			for c in casas:
				var local := Vector2(x - float(c.x), zw - (-float(c.y))).rotated(-float(c.get("rot_deg", 0.0)) * PI / 180.0)
				_checar(absf(local.x) > 8.0 or absf(local.y) > 8.2, "%s cai dentro de uma casa do pacote" % tipo)
			if p.has("tomba"):
				_checar(absf(float(p.tomba)) <= 180.0, "tomba fora de faixa em %s" % tipo)
		for c in area.get("cercas", []):
			cercas += 1
			_checar(ResourceLoader.exists(_caminho(String(c.tipo))), "cerca sem asset: %s" % c.tipo)
			for pt in c.pontos:
				_checar(_altura(alturas, float(pt[0]), -float(pt[1])) >= .3, "cerca passa pela água em (%s, %s)" % [pt[0], pt[1]])
	_checar(props >= MIN_PROPS, "esperados >= %d props, há %d" % [MIN_PROPS, props])
	_checar(cercas >= 1, "esperada ao menos uma cerca autoral")
	_checar(props <= MAX_PROPS, "orçamento estourado: %d props (teto %d)" % [props, MAX_PROPS])
	_checar_lore(areas)

	var detalhes := FileAccess.get_file_as_string("res://maps/ilha/detalhes.gd")
	_checar(detalhes.contains("res://maps/ilha/cenario_pontos.json"), "detalhes.gd deve carregar cenario_pontos.json")
	_checar(detalhes.contains("float(p.get(\"tomba\", 0.0))"), "detalhes.gd deve aplicar 'tomba'")
	if _falhas.is_empty():
		print("CENARIO_PONTOS_OK areas=%d props=%d cercas=%d" % [areas.size(), props, cercas])
	_terminar()


## Lore: um bilhete por área (campo "lore" = id). Só dados: a UI ainda não lê o arquivo.
func _checar_lore(areas: Array) -> void:
	var lore = JSON.parse_string(FileAccess.get_file_as_string(ARQ_LORE))
	_checar(lore is Dictionary and lore.has("entradas"), "data/lore/pontos.json precisa de 'entradas'")
	if not (lore is Dictionary):
		return
	var ids := {}
	for e in lore.entradas:
		var id := String(e.get("id", ""))
		_checar(not id.is_empty() and not ids.has(id), "lore sem id ou duplicado: '%s'" % id)
		ids[id] = true
		_checar(not String(e.get("titulo", "")).is_empty() and not String(e.get("corpo", "")).is_empty(), "lore '%s' sem título ou corpo" % id)
		_checar(String(e.get("corpo", "")).length() <= 400, "lore '%s' longa demais para um bilhete" % id)
	for area in areas:
		_checar(ids.has(String(area.get("lore", ""))), "área '%s' aponta para lore inexistente: %s" % [area.get("nome", "?"), area.get("lore", "")])
	_checar(lore.entradas.size() == areas.size(), "lore deveria ter uma entrada por área (%d x %d)" % [lore.entradas.size(), areas.size()])


func _caminho(tipo: String) -> String:
	if tipo.begins_with("cenario/carros/carro_"):
		return "res://assets/models/%s_aberto.fbx" % tipo
	if "/" in tipo:
		return "res://assets/models/%s.glb" % tipo
	return "res://assets/models/detalhes/%s.glb" % tipo


func _altura(alturas: PackedFloat32Array, x: float, zw: float) -> float:
	var c := clampi(int(round((x - ORIGIN) / STEP)), 0, N - 1)
	var r := clampi(int(round((zw - ORIGIN) / STEP)), 0, N - 1)
	return alturas[r * N + c]


func _checar(ok: bool, msg: String) -> void:
	if not ok:
		_falhas.append(msg)
		push_error("CENARIO_PONTOS: " + msg)


func _terminar() -> void:
	for f in _falhas:
		print("FALHA: " + f)
	get_tree().quit(0 if _falhas.is_empty() else 1)
