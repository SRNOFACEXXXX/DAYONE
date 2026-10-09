extends Node
## Construção paga em TORAS (5 = fundação, 3 = parede): sem toras não deixa, com 5 deixa e consome da mochila.
func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null:
		await get_tree().process_frame
	var cs: ConstructionSystem = m.construction_system
	var bag: BRInventory = m.br_bag
	var fund: Dictionary = ConstructionSystem.PIECES[0]
	var parede: Dictionary = ConstructionSystem.PIECES[2]
	var falhas := 0
	var def_tora := BRInventory.definition("tora")
	print("CUSTO tora_definida=%s nome=%s livre=%s" % [not def_tora.is_empty(), def_tora.get("name", "?"), ConstructionSystem.livre()])
	var sem: bool = cs._has_cost(fund)
	var aceitas := bag.add_item("tora", 4)
	var com4: bool = cs._has_cost(fund)
	var aceitas2 := bag.add_item("tora", 1)
	var com5: bool = cs._has_cost(fund)
	var texto: String = cs._cost_text(fund)
	cs._consume_cost(fund)
	var resto: int = cs._material_count("tora")
	print("CUSTO sem_toras=%s com4=%s com5=%s texto='%s' sobrou=%d aceitas=%d+%d parede_custa=%s" % [sem, com4, com5, texto, resto, aceitas, aceitas2, str(parede.cost)])
	if sem or com4 or not com5 or resto != 0 or def_tora.is_empty():
		falhas += 1
	print("CUSTO_RESULT falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)
