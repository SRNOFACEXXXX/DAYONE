class_name StorageChest
extends BRLoot
## Baú de base (peça "chest" da roda de construção). Guarda itens em uma grade 6 × 8 sem limite de peso; interagir (E) abre o
## inventário com o conteúdo na coluna PROXIMIDADE (títulado BAÚ): arraste para dentro e para fora.
## Persistência: Baus.serializar()/restaurar(). API para bots: depositar / retirar / contar / itens / abrir_para.

signal aberto(por: Node)

const LINHAS := 8                  # 6 colunas (BRInventory.COLUMNS) × 8 linhas = 48 células
const ALCANCE_ABRIR := 3.2
const TAMANHO := Vector3(0.9, 0.58, 0.55)
var _tag: Label3D


func _ready() -> void:
	super()
	add_to_group("bau")


## Chamado pelo ConstructionSystem logo depois de adicionar o nó à árvore. snap = BRInventory.snapshot() salvo (opcional).
func setup_bau(snap := {}) -> void:
	cache_id = "bau"
	contents = BRInventory.make_loot_container(LINHAS)
	contents.set_meta("bau", true)   # a UI reconhece o contêiner: arrastar para PROXIMIDADE guarda no baú em vez de soltar no chão
	if not snap.is_empty():
		contents.restore(snap)
		contents.base_rows = LINHAS
		contents.base_kg = 1000000.0
	contents.changed.connect(_refresh)
	_build_visual()
	_refresh()


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var madeira := _mat(Color("8a5a30"), 0.88)
	var tampa_mat := _mat(Color("a46b3a"), 0.85)
	var ferro := _mat(Color("3b3f44"), 0.55)
	var ouro := _mat(Color("c9a44a"), 0.4)
	var alt_corpo := TAMANHO.y * 0.62
	_caixa(Vector3(TAMANHO.x, alt_corpo, TAMANHO.z), Vector3(0, alt_corpo * 0.5, 0), madeira)
	# tampa em dois degraus (aproxima o arco com poucas faces)
	var alt_t := TAMANHO.y - alt_corpo
	_caixa(Vector3(TAMANHO.x, alt_t * 0.55, TAMANHO.z), Vector3(0, alt_corpo + alt_t * 0.275, 0), tampa_mat)
	_caixa(Vector3(TAMANHO.x - 0.04, alt_t * 0.45, TAMANHO.z - 0.12), Vector3(0, alt_corpo + alt_t * 0.55 + alt_t * 0.225, 0), tampa_mat)
	for sx in [-0.3, 0.3]:   # cintas de ferro
		_caixa(Vector3(0.07, TAMANHO.y * 0.98, TAMANHO.z + 0.02), Vector3(sx, TAMANHO.y * 0.5, 0), ferro)
	_caixa(Vector3(0.12, 0.1, 0.04), Vector3(0, alt_corpo, TAMANHO.z * 0.5 + 0.02), ouro)   # fecho
	for g in _visual.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(g as GeometryInstance3D).visibility_range_end = 60.0
	_tag = Label3D.new()
	_tag.font_size = 28
	_tag.pixel_size = 0.005
	_tag.outline_size = 8
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position.y = TAMANHO.y + 0.35
	_tag.visibility_range_end = 9.0
	add_child(_tag)


func _caixa(tam: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	_visual.add_child(mi)


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _refresh() -> void:
	if _tag:
		var n := contar_total()
		_tag.text = "BAÚ  [E]" + ("  (%d)" % n if n > 0 else "  vazio")


# ------------------------------------------------------------------ API pública (bot de sobrevivência)
## Guarda até `qtd` unidades de `item_id`; retorna quantas couberam (grade cheia = menos).
func depositar(item_id: String, qtd := 1, extra := {}) -> int:
	if contents == null or qtd <= 0:
		return 0
	return contents.add_item(item_id, qtd, Vector2i(-1, -1), extra)


## Tira até `qtd` unidades de `item_id` do baú (descarta); retorna quantas saíram. Para levar à mochila use retirar_para(bag, ...).
func retirar(item_id: String, qtd := 1) -> int:
	if contents == null or qtd <= 0:
		return 0
	var tirou := 0
	for it in contents.items.duplicate(true):
		if tirou >= qtd:
			break
		if String(it.id) == item_id:
			tirou += contents.remove_item(int(it.uid), qtd - tirou)
	return tirou


## Como retirar(), mas entrega ao inventário `bag`; retorna quantas chegaram lá (o que não couber fica no baú).
func retirar_para(bag: BRInventory, item_id: String, qtd := 1) -> int:
	if contents == null or bag == null or qtd <= 0:
		return 0
	var levou := 0
	for it in contents.items.duplicate(true):
		if levou >= qtd:
			break
		if String(it.id) == item_id:
			levou += contents.transfer_to(bag, int(it.uid), qtd - levou)
	return levou


func contar(item_id: String) -> int:
	var n := 0
	if contents:
		for it in contents.items:
			if String(it.id) == item_id:
				n += int(it.qty)
	return n


func contar_total() -> int:
	var n := 0
	if contents:
		for it in contents.items:
			n += int(it.qty)
	return n


## Conteúdo agregado por id: [{"id": String, "qty": int}, ...] (ordem de primeira aparição).
func itens() -> Array:
	var ordem: Array = []
	var soma := {}
	if contents:
		for it in contents.items:
			var id := String(it.id)
			if not soma.has(id):
				ordem.append(id)
				soma[id] = 0
			soma[id] = int(soma[id]) + int(it.qty)
	var out: Array = []
	for id in ordem:
		out.append({"id": id, "qty": int(soma[id])})
	return out


func vazio() -> bool:
	return contents == null or contents.items.is_empty()


## Abre o inventário do jogador com o baú em PROXIMIDADE. Falha (false) se o soldado está longe demais ou morto.
## Em BRMatch usa match.abrir_bau(self); sem partida (bots/testes) só confere o alcance e emite `aberto`.
func abrir_para(soldier: Node) -> bool:
	if soldier == null or not is_instance_valid(soldier) or contents == null:
		return false
	if "alive" in soldier and not soldier.alive:
		return false
	if (soldier as Node3D).global_position.distance_to(global_position) > ALCANCE_ABRIR:
		return false
	var m = soldier.get("match_ref")
	if soldier.get("is_local") == true and m != null and m.has_method("abrir_bau"):
		m.abrir_bau(self)
	aberto.emit(soldier)
	return true


## Os itens caem no chão (se a partida sabe criar drops); sem partida, mantém o baú e retorna false.
func derrubar_itens(m) -> bool:
	if vazio():
		return true
	if m == null or not m.has_method("criar_drop"):
		return false
	var base := global_position
	var k := 0
	for it in contents.items.duplicate(true):
		var ang := TAU * float(k) / 6.0
		m.criar_drop(String(it.id), int(it.qty), base + Vector3(cos(ang), 0.2, sin(ang)) * 0.7,
			{"mag": int(it.mag), "acog": bool(it.acog), "reddot": bool(it.get("reddot", false))})
		contents.remove_item(int(it.uid))
		k += 1
	return true


## Baú dono do colisor/nó atingido (raycast do jogador), ou null.
static func de_no(no: Node) -> StorageChest:
	while no != null:
		if no.has_meta("bau_node"):
			return no.get_meta("bau_node") as StorageChest
		no = no.get_parent()
	return null
