extends Node
## Troca de armas como o jogador: nasce sem nada, pega AK, solta, equipa M4, troca no mesmo slot, pistola etc.
## Confere a cada passo: arma ativa do Soldier == modelo no viewmodel == modelo no corpo (3ª pessoa).
## Uso: godot --path game res://tests/troca_armas.tscn   -> TROCA_ARMAS_OK / TROCA_ARMAS_FALHOU
var m: BRMatch
var s: Soldier
var pc: PlayerController
var falhas: Array = []


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func() -> void: print("TROCA_ARMAS_TIMEOUT"); get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	m = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	s = m.local_player
	pc = s.controller as PlayerController
	await _f(30)
	m.br_bag.add_item("backpack_medium")
	m.br_bag.equip_backpack(int(m.br_bag.items[0].uid))
	# começa sem nada (como no litoral)
	for sl in s.inventory.keys():
		s.remove_slot(sl)
	await _f(10)
	_conf("sem nada na mão", &"")
	for passo in [["ak47", false], ["m4", false], ["ak47", true], ["m4", false], ["glock", false], ["mosin", false],
			["m107", false], ["m249", false], ["uzi", false], ["m4", false], ["ak47", false]]:
		await _pegar(String(passo[0]))
		_conf("equipou %s" % passo[0], StringName(passo[0]))
		if passo[1]:
			await _soltar(String(passo[0]))
			_conf("soltou %s" % passo[0], _sobra())
	# solta tudo e equipa outra no mesmo slot
	await _pegar("ak47")
	await _soltar("ak47")
	_conf("depois de soltar a AK", _sobra())
	await _pegar("m4")
	_conf("M4 depois de soltar a AK (bug do dono)", &"m4")
	print("TROCA_ARMAS_OK" if falhas.is_empty() else "TROCA_ARMAS_FALHOU %d %s" % [falhas.size(), str(falhas)])
	get_tree().quit(0 if falhas.is_empty() else 1)


## Quando a arma da mão sai, entra a pistola (se houver) ou a faca; sem nenhuma, mãos vazias.
func _sobra() -> StringName:
	for sl in [WeaponDef.Slot.PRIMARY, WeaponDef.Slot.PISTOL, WeaponDef.Slot.KNIFE]:
		if s.inventory.has(sl):
			return (s.inventory[sl] as WeaponState).def.id
	return &""


func _f(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _pegar(id: String) -> void:
	var bag: BRInventory = m.br_bag
	var uid := -1
	for it in bag.items.duplicate():   # espaço na mochila não é o assunto deste teste: tira as outras armas dela
		var d := BRInventory.definition(String(it.id))
		if String(d.get("kind", "")) == "weapon" and String(it.id) != id:
			bag.remove_item(int(it.uid))
	for it in bag.items:
		if String(it.id) == id:
			uid = int(it.uid)
	if uid < 0:
		bag.add_item(id, 1, Vector2i(-1, -1), {"mag": 30})
		for it in bag.items:
			if String(it.id) == id:
				uid = int(it.uid)
	m._equip_br_weapon(uid)
	await _f(20)


func _soltar(id: String) -> void:
	for it in m.br_bag.items:
		if String(it.id) == id:
			m._dropar_item(int(it.uid))
			break
	await _f(20)


func _conf(nome: String, esperado: StringName) -> void:
	var vm: ViewModel = pc.viewmodel
	var ativo: StringName = s.current_def().id if s.current_def() else &""
	var no_vm: StringName = vm.current_id
	var no_corpo: StringName = s.body_model.weapon_id if s.body_model else &""
	var modelo_ok := (vm.scene_root != null) == (esperado != &"")
	var ok := ativo == esperado and no_vm == esperado and modelo_ok and (no_corpo == esperado or s.body_model == null)
	print("%s | ativo=%s vm=%s corpo=%s modelo_vm=%s -> %s" % [nome, ativo, no_vm, no_corpo, vm.scene_root != null, "ok" if ok else "FALHA"])
	if not ok:
		falhas.append(nome)
