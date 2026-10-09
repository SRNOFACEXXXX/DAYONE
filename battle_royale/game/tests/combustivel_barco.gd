extends Node
## Combustível e fuga no jogo real: (1) carro com tanque quase vazio + galão na mochila + F real -> tanque sobe e o galão some;
## (2) barco de fuga: entrega peças pela API e confirma que a fuga dispara só com todas. --out=<pasta>
func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null or m.br_bag == null:
		await get_tree().process_frame
	for i in 240:
		await get_tree().physics_frame
	var p: Soldier = m.local_player
	var falhas := 0
	var car := get_tree().get_nodes_in_group("drivable_vehicle")[0] as DrivableVehicle
	p.global_position = car.global_position + car.global_basis.x * 2.2
	p.reset_physics_interpolation()
	car._trem.combustivel_l = 3.0
	var antes := car.combustivel_frac()
	m.br_bag.add_item("galao", 1)
	for i in 90:
		await get_tree().physics_frame
	Input.action_press("inspect")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("inspect")
	for i in 20:
		await get_tree().physics_frame
	var galoes := 0
	for it in m.br_bag.items:
		if String(it.id) == "galao":
			galoes += int(it.qty)
	var depois := car.combustivel_frac()
	print("COMB antes=%.2f depois=%.2f galoes_restantes=%d consumo_ligado=%s" % [antes, depois, galoes, car.usar_combustivel])
	if depois <= antes + 0.3 or galoes != 0 or not car.usar_combustivel:
		falhas += 1
	# barco de fuga
	var barco := get_tree().get_first_node_in_group("barco_fuga")
	print("BARCO existe=%s faltando=%s" % [barco != null, str(barco.faltando()) if barco else "-"])
	if barco == null:
		falhas += 1
	else:
		var bag := BRInventory.new()
		bag.base_kg = 1000.0
		bag.add_item("galao", 2)
		bag.add_item("bateria_carro", 1)
		var n1: int = barco.entregar(bag)
		print("BARCO entregou=%d faltando=%s fugiu=%s" % [n1, str(barco.faltando()), barco._fugiu])
		if n1 != 3 or barco._fugiu:
			falhas += 1
		bag.add_item("kit_reparo", 2)
		bag.add_item("corda", 2)
		bag.add_item("tora", 4)
		var n2: int = barco.entregar(bag)
		print("BARCO entregou=%d faltando=%s fugiu=%s" % [n2, str(barco.faltando()), barco._fugiu])
		if not barco._fugiu:
			falhas += 1
	print("COMB_RESULT falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)
