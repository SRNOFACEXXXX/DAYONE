extends Node
## Combustível com sentido: liga o consumo nos carros da partida e deixa o jogador reabastecer com um GALÃO da mochila
## (F perto do carro, +20 L, gasta o galão). Sem class_name (preload em maps/ilha/ilha.gd).
const LITROS_GALAO := 20.0
const ALCANCE := 3.6
## Itens que consertam o carro (F perto dele), do melhor ao pior: [id, pontos de lataria].
const REPAROS := [["kit_reparo", 50.0], ["chaves", 25.0], ["fita", 10.0]]
var _dica: Label3D
var _t := 0.0


func _ready() -> void:
	_dica = Label3D.new()
	_dica.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dica.font_size = 26
	_dica.pixel_size = 0.0028
	_dica.outline_size = 8
	_dica.visible = false
	add_child(_dica)


func _process(dt: float) -> void:
	var m = Game.current_match
	if m == null or not is_instance_valid(m) or not "local_player" in m or not is_instance_valid(m.local_player):
		return
	_t -= dt
	if _t <= 0.0:
		_t = 1.0
		for v in get_tree().get_nodes_in_group("drivable_vehicle"):
			if not v.has_meta("combustivel_ligado"):
				v.set_meta("combustivel_ligado", true)
				v.usar_combustivel = true
	var p: Soldier = m.local_player
	var bag: BRInventory = m.br_bag if "br_bag" in m else null
	var alvo: Node3D = null
	for v in get_tree().get_nodes_in_group("drivable_vehicle"):
		if v.driver == null and (v as Node3D).global_position.distance_to(p.global_position) < ALCANCE:
			alvo = v
			break
	_dica.visible = alvo != null and p.alive
	if alvo == null or bag == null:
		return
	var tem := _galoes(bag) > 0
	var cheio: bool = alvo.combustivel_frac() > 0.97
	var kit := _melhor_reparo(bag) != ""
	var batido: bool = alvo.vida_frac() < 0.98
	_dica.global_position = alvo.global_position + Vector3.UP * 1.8
	var linhas: PackedStringArray = []
	linhas.append(("Tanque cheio" if cheio else "[F] Abastecer (galão)") if tem else "Tanque %d%% — precisa de um GALÃO" % int(alvo.combustivel_frac() * 100.0))
	if batido:
		linhas.append("[F] Consertar (%s)" % String(BRInventory.definition(_melhor_reparo(bag)).get("name", "")) if kit else "Lataria %d%% — precisa de KIT, CHAVES ou FITA" % int(alvo.vida_frac() * 100.0))
	_dica.text = "\n".join(linhas)
	if Input.is_action_just_pressed("inspect"):
		if tem and not cheio:
			abastecer(alvo, bag)
		elif kit and batido:
			consertar(alvo, bag)


## Primeiro item de REPAROS que a mochila tem ("" se nenhum).
static func _melhor_reparo(bag: BRInventory) -> String:
	for par in REPAROS:
		if _contar(bag, String(par[0])) > 0:
			return String(par[0])
	return ""


## Gasta 1 do melhor item de reparo e devolve seus pontos de vida ao carro. Devolve true se consertou.
func consertar(carro: Node, bag: BRInventory) -> bool:
	var id := _melhor_reparo(bag)
	if id == "":
		return false
	var pontos := 0.0
	for par in REPAROS:
		if String(par[0]) == id:
			pontos = float(par[1])
	for it in bag.items:
		if String(it.id) == id:
			bag.remove_item(int(it.uid), 1)
			carro.reparar(pontos)
			if Audio.has_sound("loot_open"):
				Audio.play("loot_open", {"volume_db": -3.0})
			return true
	return false


## Gasta 1 galão da mochila e põe LITROS_GALAO no tanque. Devolve true se abasteceu.
func abastecer(carro: Node, bag: BRInventory) -> bool:
	for it in bag.items:
		if String(it.id) == "galao":
			bag.remove_item(int(it.uid), 1)
			carro.abastecer(LITROS_GALAO)
			if Audio.has_sound("loot_open"):
				Audio.play("loot_open", {"volume_db": -3.0})
			return true
	return false


static func _galoes(bag: BRInventory) -> int:
	return _contar(bag, "galao")


static func _contar(bag: BRInventory, id: String) -> int:
	var n := 0
	for it in bag.items:
		if String(it.id) == id:
			n += int(it.qty)
	return n
