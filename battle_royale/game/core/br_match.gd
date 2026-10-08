class_name BRMatch
extends Match
## Partida de battle royale na Ilha do Tauá, sobre o combate do Linha de Fogo (Soldier, armas, viewmodel, HUD).
## Fase 1 (jogável): o jogador desce na praça da Vila com faca + pistola; armas no chão em todos os pontos de
## saque autorais do layout (tier -> arma, sem sorteio); rodada única sem tempo; morte -> fim da partida.
## Fase 2: avião de salto numa das rotas autorais (layout.aviao, 300 m, 45 m/s) -> queda livre -> paraquedas -> chão.
## Fase 3: zona que fecha (layout.zona): o final é um dos candidatos autorais; o centro de cada fase anda do centro
## anterior em direção ao final até o limite R_ant - R (círculo sempre dentro do anterior, final sempre dentro).
## Próxima fase: bots com navmesh por POI.

const SPAWN_JOGADOR := Vector2(-338.0, -348.0)   # adro da Capela da Vila (autoral; o ponto antigo caía na beira do rio)
const ARMA_POR_TIER := {"alto": [&"ak47", &"mosin", &"m4"], "medio": [&"ak47", &"glock", &"m4", &"usp", &"mosin"], "baixo": [&"glock", &"usp"]}

const QUEDA_V := 50.0          # m/s descendo em queda livre (mergulho)
const QUEDA_H := 25.0          # m/s de deslocamento horizontal em queda livre
const PARA_ALTURA := 110.0     # abre o paraquedas a esta altura do chão
const PARA_V := 7.0
const PARA_H := 11.0
const OLHO_VOO := Vector3(-26.0, 6.0, 0.0)   # no avião o jogador vê de fora, atrás e acima da cauda (câmera de perseguição)
const AVIAO_CENA := preload("res://assets/models/veiculos/aviao_salto.glb")
const RAMPA := Vector3(-6.0, -2.5, 0.0)      # ponto de saída do salto: abaixo da rampa aberta (local do avião, frente = +X)

var ilha: Node3D
var saques := 0
var pontos_saque: Array[Vector3] = []   # posições dos pontos de saque (objetivos dos bots)
var aviao: Node3D
var rota_de := Vector3.ZERO
var rota_ate := Vector3.ZERO
var voo_t := 0.0
var voo_dur := 1.0
var voo_terra := Vector2(0.0, 1.0)   # [início, fim] (s) do trecho da rota sobre terra firme: salto só aí, forçado no fim
var estado := {}               # Soldier -> "aviao" | "queda" | "para" | "chao"
# zona: eventos [t_espera_ini, t_fecha_ini, t_fecha_fim, centro(Vector2 xz), raio, dano] por fase 1..N
var zona_fases: Array = []
var zona_final := ""
var zona_c := Vector2.ZERO
var zona_r := 640.0
var zona_prox_c := Vector2.ZERO
var zona_prox_r := 640.0
var zona_dano := 0.0
var zona_msg := -1
var _zona_tick := 0.0
var _parede: MeshInstance3D
var br_bag: BRInventory
var construction_system: ConstructionSystem
var br_ui: BRInventoryUI
var br_loot_root: Node3D
var br_loot_hint: Label
var bau_aberto: StorageChest   # baú de base aberto no inventário (PROXIMIDADE mostra o conteúdo mesmo se o alcance mudar um pouco)
const RESPAWN_S := 6.0


func is_survival() -> bool:
	return true


func _ready() -> void:
	super()
	if not local_player:
		await match_initialized
	await _setup_survival_async()
	if local_player and estado.get(local_player, "") == "aviao" and not pre_montando():
		Audio.ambient("propeller_cartoon_loop", -13.0)
	montada = true
	print("BATTLE_ROYALE_PRONTO saque_armas=", saques, " caches=", br_loot_root.get_child_count())
	partida_montada.emit()


signal partida_montada
var montada := false


## Pré-montada atrás do criador: o boneco foi escolhido depois da montagem do corpo; reaplica no corpo e no retrato.
func ativar_pre_montada() -> void:
	super()
	var pc := local_player.controller as PlayerController if local_player else null
	if pc and pc.camera:
		pc.camera.far = 6000.0   # mesmo ajuste de _spawn_soldiers_async (controle criado agora, no CONFIRMAR)
	if local_player and local_player.body_model and local_player.body_model.has_method("atualizar_personagem"):
		local_player.body_model.atualizar_personagem()
	if br_ui:
		_retrato_personagem()


func _setup_survival_async() -> void:
	br_bag = BRInventory.new()
	var starter: WeaponState = local_player.inventory.get(WeaponDef.Slot.PISTOL)
	if starter:
		br_bag.add_item(String(starter.def.id), 1, Vector2i(-1, -1), {"mag": starter.mag})
		for item in br_bag.items:
			if String(item.id) == String(starter.def.id):
				starter.br_uid = int(item.uid)
				break
		br_bag.add_item("ammo_9mm", 45)
		# Kit inicial de construção só quando a construção é paga por material; no modo livre (testes) ele só
		# ocupava 8 kg dos 12 kg do bolso e impedia pegar qualquer arma.
		if not ConstructionSystem.FREE_BUILD_MODE:
			br_bag.add_item("wood", 120)
			br_bag.add_item("stone", 40)
		if starter.br_uid >= 0:
			br_bag.assign_quick_slot(0, starter.br_uid)
	br_bag.changed.connect(_sync_br_reserve)
	br_bag.changed.connect(_consumir_itens)
	_sync_br_reserve()
	local_player.fired.connect(_sync_br_mag)
	local_player.reload_finished.connect(_consume_br_ammo)
	Loading.marcar_passo("br_inventario_ui")
	br_ui = load("res://ui/br_inventory_ui.tscn").instantiate()
	hud.add_child(br_ui)
	br_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	br_ui.closed.connect(_ao_fechar_inventario)
	br_ui.fonte_proximos = itens_proximos
	br_ui.drop_requested.connect(_dropar_item)
	br_ui.quick_assigned.connect(func() -> void: pass)
	br_ui.weapon_equipped.connect(_equip_br_weapon)
	br_ui.attachment_changed.connect(_sync_br_reserve)
	_retrato_personagem()
	br_loot_hint = UIStyle.label("", 16, UIStyle.TEXT, 600)
	hud.add_child(br_loot_hint)
	br_loot_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	br_loot_hint.offset_left = -250.0
	br_loot_hint.offset_right = 250.0
	br_loot_hint.offset_top = -130.0
	br_loot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	br_loot_root = Node3D.new()
	br_loot_root.name = "SaqueDeSobrevivencia"
	add_child(br_loot_root)
	Loading.marcar_passo("br_caixas")
	await _spawn_br_loot_async()
	construction_system = ConstructionSystem.new()
	construction_system.name = "ConstructionSystem"
	add_child(construction_system)
	construction_system.setup(self)


func handle_construction_input(event: InputEvent) -> bool:
	if construction_system == null or local_player == null or not local_player.alive:
		return false
	if br_ui and br_ui.visible and not construction_system.wheel_open:
		return false
	return construction_system.handle_input(event)


## Retrato do inventário: o boneco montado no criador no lugar do soldado (palco MenuStage do br_inventory_ui).
func _retrato_personagem() -> void:
	var bm := local_player.body_model as BodyModel
	var ret = br_ui.get("_retrato")
	if bm == null or ret == null or not ret.has_method("mostrar_boneco"):
		return
	var bon := bm.boneco_retrato()
	if bon:
		bon.rotation_degrees.y = -14.0
		ret.mostrar_boneco(bon)
		if is_instance_valid(_retrato_boneco):
			_retrato_boneco.queue_free()
		_retrato_boneco = bon
		# retrato só anima com o inventário aberto (o soldado escondido do palco também para)
		if ret.get("soldier") is Node:
			(ret.soldier as Node).process_mode = Node.PROCESS_MODE_DISABLED
		bon.process_mode = Node.PROCESS_MODE_INHERIT if br_ui.visible else Node.PROCESS_MODE_DISABLED
		if not br_ui.visibility_changed.is_connected(_retrato_visibilidade):
			br_ui.visibility_changed.connect(_retrato_visibilidade)


func _retrato_visibilidade() -> void:
	if is_instance_valid(_retrato_boneco):
		_retrato_boneco.process_mode = Node.PROCESS_MODE_INHERIT if br_ui.visible else Node.PROCESS_MODE_DISABLED


var _retrato_boneco: Node3D


## Caixas de suprimento: posições autorais DENTRO dos prédios (pontos_loot.json, coordenadas locais do prédio).
## Nunca em telhado. Sem o arquivo (ou prédio), cai no conjunto de teste junto ao spawn.
func _spawn_br_loot_async() -> void:
	var blk := ilha.get_node_or_null("Blockout")
	var n := 0
	var arq := "res://maps/ilha/pontos_loot.json"
	if FileAccess.file_exists(arq) and blk:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arq))
		for id in data.get("predios", {}):
			var corpo := blk.get_node_or_null(NodePath(String(id))) as Node3D
			if corpo == null or corpo.has_meta("casa_pacote"):
				continue   # casas do pacote têm saque nos móveis
			var k := 0
			for pt in data.predios[id]:
				# casas têm saque nos móveis (BRMovel); caixa de suprimento só em galpão/container/prédio militar (tier alto)
				if String(pt.get("sala", "")) in ["quarto", "cozinha", "sala"] and String(pt.get("tier", "medio")) != "alto":
					continue
				var c := BRCrate.new()
				br_loot_root.add_child(c)
				c.name = "%s_caixa%d" % [id, k]
				k += 1
				c.global_position = corpo.to_global(Vector3(float(pt.x), float(pt.get("y", 0.0)) + 0.02, float(pt.z)))
				c.rotation.y = corpo.rotation.y + deg_to_rad(float(pt.get("rot_deg", 0.0)))
				c.setup_crate(c.name, String(pt.get("tier", "medio")))
				n += 1
				if n % 12 == 0:
					Loading.set_progress("Guardando suprimentos nos prédios...", 94.0 + 4.0 * minf(1.0, float(n) / 300.0))
					await get_tree().process_frame
	if n == 0:
		var t: IlhaTerrain = ilha.terrain
		for k in 4:
			var x := SPAWN_JOGADOR.x + 4.0 + 3.0 * k
			var z := -SPAWN_JOGADOR.y + 4.0
			var c := BRCrate.new()
			br_loot_root.add_child(c)
			c.global_position = Vector3(x, _piso(Vector3(x, t.height_world(x, z) + 30.0, z), t.height_world(x, z)) + 0.02, z)
			c.setup_crate("teste_%d" % k, ["alto", "medio", "baixo", "medio"][k])
	for shelter in get_tree().get_nodes_in_group("gpt_refugio"):
		var crate := BRCrate.new()
		crate.name = String(shelter.name) + "_suprimentos"
		br_loot_root.add_child(crate)
		crate.global_position = shelter.to_global(shelter.get_meta("loot_local"))
		crate.rotation.y = shelter.rotation.y
		crate.setup_crate(crate.name, String(shelter.get_meta("loot_tier")))


## Itens que agem ao entrar na mochila: colete (vira 2 placas) e granada (contador para a tecla G).
func _consumir_itens() -> void:
	if br_bag == null or local_player == null:
		return
	if br_bag.backpack_id.is_empty():
		for item in br_bag.items.duplicate(true):
			if String(BRInventory.definition(String(item.id)).get("kind", "")) == "backpack":
				br_bag.equip_backpack(int(item.uid))
				hud_message.emit("Mochila equipada", 2.0)
				return
	for item in br_bag.items.duplicate(true):
		if String(item.id) == "vest":
			br_bag.remove_item(int(item.uid))
			local_player.give_vest(2)
			hud_message.emit("Colete guardado (coletes por tier virão depois)", 3.0)
			return   # remove_item emite changed: reentra e segue a lista


## Bot junto da caixa: abre e leva as armas (equipa e recebe munição de reserva).
func bot_saquear(b: Soldier, crate: BRCrate) -> void:
	crate.abrir()
	for item in crate.contents.items.duplicate(true):
		var def: WeaponDef = WeaponDB.get_def(StringName(item.id))
		if def and def.is_gun():
			var ws := b.give_weapon(def.id, true)
			if ws:
				ws.mag = int(item.mag) if int(item.mag) > 0 else def.mag_size
				ws.reserve = def.mag_size * 2
			crate.contents.remove_item(int(item.uid))
	b.switch_to(WeaponDef.Slot.PRIMARY if b.inventory.has(WeaponDef.Slot.PRIMARY) else b.active_slot)


func granadas() -> int:
	var n := 0
	for item in br_bag.items:
		if String(item.id) == "grenade":
			n += int(item.qty)
	return n


func _lancar_granada() -> void:
	for item in br_bag.items:
		if String(item.id) == "grenade":
			br_bag.remove_item(int(item.uid), 1)
			var cam := local_player.controller.camera as Camera3D if local_player.controller and "camera" in local_player.controller else null
			var dir := -cam.global_transform.basis.z if cam else Vector3.FORWARD
			var origem := (cam.global_position if cam else local_player.global_position + Vector3.UP * 1.6) + dir * 0.6
			Grenade.lancar(self, local_player, origem, dir)
			hud_message.emit("Granadas: %d" % granadas(), 1.5)
			return
	hud_message.emit("Sem granadas", 1.5)


func _sync_br_reserve() -> void:
	if br_bag == null or local_player == null:
		return
	for ws: WeaponState in local_player.inventory.values():
		var caliber := String(BRInventory.definition(String(ws.def.id)).get("caliber", ""))
		if not caliber.is_empty():
			ws.reserve = br_bag.count_ammo(caliber)
	local_player.inventory_changed.emit()


func _sync_br_mag(def: WeaponDef) -> void:
	var ws: WeaponState = local_player.current()
	if ws and ws.def == def and ws.br_uid >= 0:
		br_bag.set_weapon_mag(ws.br_uid, ws.mag)


func _consume_br_ammo(def: WeaponDef) -> void:
	var ws: WeaponState = local_player.current()
	if ws == null or ws.def != def:
		return
	var caliber := String(BRInventory.definition(String(def.id)).get("caliber", ""))
	if not caliber.is_empty():
		br_bag.take_ammo(caliber, maxi(0, br_bag.count_ammo(caliber) - ws.reserve))
	_sync_br_mag(def)


func _equip_br_weapon(uid: int) -> void:
	var item := br_bag.get_item(uid)
	if item.is_empty():
		return
	var def: WeaponDef = WeaponDB.get_def(StringName(item.id))
	if def == null or not def.is_gun():
		return
	var old: WeaponState = local_player.inventory.get(def.slot)
	if old and old.br_uid >= 0:
		br_bag.set_weapon_mag(old.br_uid, old.mag)
	if old:
		local_player.remove_slot(def.slot)
	var ws := WeaponState.new(def)
	ws.mag = int(item.mag)
	ws.br_uid = uid
	local_player.inventory[def.slot] = ws
	local_player.switch_to(def.slot)
	_sync_br_reserve()


## Teclas 1–5: usa o item arrastado para o atalho (arma = equipa e saca; granada = lança; resto = só avisa).
func use_quick_slot(slot: int) -> bool:
	if br_bag == null or slot < 0 or slot >= br_bag.quick_slots.size() or br_ui.visible:
		return false
	var item := br_bag.quick_item(slot)
	if item.is_empty():
		return false
	var def := BRInventory.definition(String(item.id))
	match String(def.get("kind", "")):
		"weapon":
			_equip_br_weapon(int(item.uid))
		"grenade":
			_lancar_granada()
		"heal":
			if not local_player.usar_cura(String(item.id)):
				hud_message.emit("%s: nada a curar ou já curando" % String(def.get("name", item.id)), 1.5)
		_:
			hud_message.emit("%s: abra o inventário (TAB) para usar" % String(def.get("name", item.id)), 1.5)
	return true


func _ao_fechar_inventario() -> void:
	bau_aberto = null
	(local_player.controller as PlayerController).ui_blocking = false
	if hud:
		hud.root.visible = true


## Itens ao alcance (≤ 3 m) para a coluna PROXIMIDADE: móveis/caixas já abertos e itens no chão.
func itens_proximos() -> Array:
	var out: Array = []
	if local_player == null:
		return out
	for n in get_tree().get_nodes_in_group("loot"):
		var l := n as BRLoot
		if l == null or not is_instance_valid(l) or l.contents == null or (l.contents.items.is_empty() and not l is StorageChest):
			continue
		if _precisa_abrir(l):
			continue
		if l.global_position.distance_to(local_player.global_position) <= 3.0:
			out.append(l.contents)
	if is_instance_valid(bau_aberto) and bau_aberto.contents != null and not out.has(bau_aberto.contents) 			and bau_aberto.global_position.distance_to(local_player.global_position) <= 4.5:
		out.append(bau_aberto.contents)
	return out


## Item da mochila → chão, 1 m à frente do jogador (sem atravessar o piso).
func _dropar_item(uid: int) -> void:
	var item := br_bag.get_item(uid)
	if item.is_empty():
		return
	var def := BRInventory.definition(String(item.id))
	if String(def.get("kind", "")) == "weapon":
		for sl in local_player.inventory.keys():
			var ws: WeaponState = local_player.inventory[sl]
			if ws.br_uid == uid:
				br_bag.set_weapon_mag(uid, ws.mag)
				local_player.remove_slot(sl)
				# solta a arma da mão: fica com a pistola se tiver, senão a faca (ou mãos vazias)
				local_player.switch_to(WeaponDef.Slot.PISTOL if local_player.inventory.has(WeaponDef.Slot.PISTOL) else WeaponDef.Slot.KNIFE)
	var fwd := Vector3(-sin(local_player.yaw), 0.0, -cos(local_player.yaw))
	var p := local_player.global_position + fwd * 1.0
	criar_drop(String(item.id), int(item.qty), p, {"mag": int(item.mag), "acog": bool(item.acog), "reddot": bool(item.get("reddot", false))})
	br_bag.remove_item(uid)


## Cria um item no chão em (x, z) do mundo, no piso real (terreno ou laje), sem atravessar o mapa.
func criar_drop(id: String, qtd: int, pos: Vector3, extra := {}) -> BRDrop:
	var t: IlhaTerrain = ilha.terrain
	var chao := t.height_world(pos.x, pos.z)
	var y := _piso(Vector3(pos.x, maxf(chao, pos.y) + 2.0, pos.z), chao)
	return BRDrop.criar(br_loot_root, id, qtd, Vector3(pos.x, y + 0.03, pos.z), extra)


## "acog", "reddot" ou "" para a arma na mão do jogador local.
func mira_para(s: Soldier) -> String:
	if s != local_player or br_bag == null:
		return ""
	var ws: WeaponState = s.current()
	if ws == null or ws.br_uid < 0:
		return ""
	var it := br_bag.get_item(ws.br_uid)
	return "acog" if bool(it.get("acog", false)) else ("reddot" if bool(it.get("reddot", false)) else "")


func has_acog_for(s: Soldier) -> bool:
	if s != local_player or br_bag == null:
		return false
	var ws: WeaponState = s.current()
	return ws != null and ws.br_uid >= 0 and bool(br_bag.get_item(ws.br_uid).get("acog", false))


var _loot_alvo: BRLoot
var _loot_t := 0.0           # tempo acumulado segurando E no alvo (0..TEMPO)
var _loot_busca := 0.0
var hold_circle: HoldCircle
var admin: AdminPanel


## Contêiner que o jogador está olhando: o mais próximo do centro da mira dentro de 2,4 m (móvel/caixa), reavaliado a cada 0,1 s.
func _nearby_loot() -> BRLoot:
	if local_player == null or not local_player.alive:
		return null
	if clock - _loot_busca < 0.1 and is_instance_valid(_loot_alvo):
		return _loot_alvo
	_loot_busca = clock
	var cam := get_viewport().get_camera_3d()
	var olho := local_player.eye_position()
	var frente := -cam.global_transform.basis.z if cam else Vector3.FORWARD
	var melhor: BRLoot = null
	var pontos := 0.0
	for node in get_tree().get_nodes_in_group("loot"):
		var loot := node as BRLoot
		if loot == null or not is_instance_valid(loot):
			continue
		var alvo := loot.global_position + Vector3.UP * 0.3
		var v := alvo - olho
		var d := v.length()
		if d > 2.6:
			continue
		var cos_a := frente.dot(v / maxf(d, 0.01))
		if cos_a < 0.55:
			continue
		# sem visada livre (parede/porta fechada no meio) não dá para saquear: o armário atrás da porta não rouba o E dela
		var rq := PhysicsRayQueryParameters3D.create(olho, alvo, Soldier.LAYER_WORLD, [local_player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(rq)
		if not hit.is_empty() and olho.distance_to(hit.position) < d - 0.45 and not (loot is StorageChest and loot.get_parent().is_ancestor_of(hit.collider)):
			continue
		var pt := cos_a * 2.0 - d * 0.3
		if pt > pontos or melhor == null:
			pontos = pt
			melhor = loot
	_loot_alvo = melhor
	return melhor


## Porta e saque disputam o E quando ficam lado a lado (porta da cozinha ao lado do armário): vence quem está mais no centro da mira.
func _porta_vence(loot: BRLoot) -> bool:
	return _porta_vence_com(loot, _porta_alvo())


## Mesma disputa de _porta_vence, com a porta já escolhida (o HUD reaproveita a porta em cache).
func _porta_vence_com(loot: BRLoot, pt: PortaCasa) -> bool:
	if pt == null or loot == null:
		return pt != null
	var cam := get_viewport().get_camera_3d()
	var olho := local_player.eye_position()
	var frente := -cam.global_transform.basis.z if cam else Vector3.FORWARD
	var vl := (loot.global_position + Vector3.UP * 0.3) - olho
	var vp := pt.centro() - olho
	var sl := frente.dot(vl.normalized()) * 2.0 - vl.length() * 0.3
	var sp := frente.dot(vp.normalized()) * 2.0 - vp.length() * 0.3 + 0.45   # a porta é grande: leve preferência
	return sp > sl


var _porta_hint_t := -1.0
var _porta_hint: PortaCasa = null


## _porta_alvo() reavaliado a cada 0,1 s para o HUD (a tecla E continua consultando direto).
func _porta_alvo_hint() -> PortaCasa:
	if clock - _porta_hint_t < 0.1 and (_porta_hint == null or is_instance_valid(_porta_hint)):
		return _porta_hint
	_porta_hint_t = clock
	_porta_hint = _porta_alvo()
	return _porta_hint


## Porta que o jogador está olhando (até 2,4 m, dentro de ~55° da mira).
func _porta_alvo() -> PortaCasa:
	if local_player == null or not local_player.alive:
		return null
	var cam := get_viewport().get_camera_3d()
	var olho := local_player.eye_position()
	var frente := -cam.global_transform.basis.z if cam else Vector3.FORWARD
	var melhor: PortaCasa = null
	var pontos := -1e9
	for n in get_tree().get_nodes_in_group("porta"):
		var p := n as PortaCasa
		if p == null or not is_instance_valid(p):
			continue
		var v := p.centro() - olho
		var d := v.length()
		if d > 2.6:
			continue
		var cos_a := frente.dot(v / maxf(d, 0.01))
		if cos_a < 0.5:
			continue
		var pt := cos_a * 2.0 - d * 0.3
		if pt > pontos:
			pontos = pt
			melhor = p
	return melhor


func _precisa_abrir(l: BRLoot) -> bool:
	var c := l as BRCrate
	if c:
		return not c.aberta
	var mv := l as BRMovel
	return mv != null and not mv.aberto


func _nome_loot(l: BRLoot) -> String:
	if l is StorageChest:
		return "Baú"
	var mv := l as BRMovel
	return mv.nome_exibido if mv else "Caixa de suprimentos"


## Baú de base: abre o inventário com o conteúdo do baú em PROXIMIDADE (StorageChest.abrir_para chama aqui).
func abrir_bau(bau: StorageChest) -> void:
	if br_ui == null or br_ui.visible or local_player == null or not local_player.alive:
		return
	bau_aberto = bau
	abrir_inventario()
	Audio.play_at("buy", bau.global_position, {"volume_db": -6.0, "max_distance": 12.0})


func abrir_inventario() -> void:
	br_ui.open(br_bag, itens_proximos())
	(local_player.controller as PlayerController).ui_blocking = true
	hud.root.visible = false


## Segurar E 1 s num móvel/caixa fechado abre; E rápido num aberto recolhe. Atualiza barra circular e dica.
func _update_br_loot_hint() -> void:
	if br_loot_hint == null or local_player == null:
		return
	if hold_circle == null:
		hold_circle = HoldCircle.new()
		hud.add_child(hold_circle)
	var alvo := _nearby_loot()
	var pt_hint: PortaCasa = _porta_alvo_hint() if not br_ui.visible else null
	if alvo != null and _porta_vence_com(alvo, pt_hint):
		alvo = null
	if alvo == null or br_ui.visible or not local_player.alive:
		_loot_t = 0.0
		hold_circle.mostrar(0.0, "")
		var pt := pt_hint
		br_loot_hint.text = ("[E] %s a porta" % ("Fechar" if pt.aberta else "Abrir")) if pt else "[TAB] Inventário"
		return
	if alvo is StorageChest:
		_loot_t = 0.0
		hold_circle.mostrar(0.0, "")
		br_loot_hint.text = "[E] Abrir baú  •  %s" % ("vazio" if alvo.vazio() else "%d item(ns)" % alvo.contar_total())
		return
	if _precisa_abrir(alvo):
		br_loot_hint.text = "[segure E] Abrir %s" % _nome_loot(alvo).to_lower()
		if Input.is_physical_key_pressed(KEY_E):
			_loot_t += get_process_delta_time()
			hold_circle.mostrar(_loot_t / BRMovel.TEMPO_ABRIR, "Abrindo " + _nome_loot(alvo).to_lower() + "...")
			if _loot_t >= BRMovel.TEMPO_ABRIR:
				_loot_t = 0.0
				hold_circle.mostrar(0.0, "")
				_abrir_loot(alvo)
		else:
			_loot_t = 0.0
			hold_circle.mostrar(0.0, "")
	else:
		_loot_t = 0.0
		hold_circle.mostrar(0.0, "")
		var vazio := alvo.contents.items.is_empty()
		br_loot_hint.text = "%s vazio" % _nome_loot(alvo) if vazio else "[E] Recolher  •  [TAB] Inventário"


func _abrir_loot(l: BRLoot) -> void:
	var c := l as BRCrate
	if c:
		c.abrir()
		await get_tree().create_timer(0.55).timeout   # deixa a tampa abrir e a explosão sair antes do inventário
		if local_player and local_player.alive and not br_ui.visible:
			abrir_inventario()
		return
	var mv := l as BRMovel
	if mv == null:
		return
	# sorteia o conteúdo e abre o inventário: o que saiu aparece em PROXIMIDADE para o jogador pegar
	mv.abrir_sem_pegar()
	abrir_inventario()
	Audio.play_at("buy", mv.global_position, {"volume_db": -6.0, "max_distance": 12.0})


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or local_player == null or not local_player.alive:
		return
	match event.physical_keycode:
		KEY_TAB:
			if br_ui.visible:
				br_ui.close()
			elif not (admin and admin.visible):
				abrir_inventario()
			get_viewport().set_input_as_handled()
		KEY_F10:
			if admin == null:
				admin = AdminPanel.new()
				hud.add_child(admin)
				admin.setup(self)
			if admin.visible:
				admin.close()
			else:
				if br_ui.visible:
					br_ui.close()
				admin.open()
			get_viewport().set_input_as_handled()
		KEY_E:
			if br_ui.visible:
				return
			var loot := _nearby_loot()
			if loot != null and _porta_vence(loot):
				loot = null
			if loot == null:
				var pt := _porta_alvo()
				if pt:
					pt.alternar()
					get_viewport().set_input_as_handled()
				return
			if loot is StorageChest:
				(loot as StorageChest).abrir_para(local_player)   # baú de base: E abre direto (não recolhe tudo)
				get_viewport().set_input_as_handled()
				return
			if _precisa_abrir(loot):
				return   # abrir = segurar E 1 s (barra circular)
			var count := loot.take_all(br_bag)
			hud_message.emit("%d item(ns) recolhido(s)" % count if count > 0 else "Nada para pegar (ou mochila cheia — TAB)", 2.5)
			get_viewport().set_input_as_handled()
		KEY_G:
			_lancar_granada()
			get_viewport().set_input_as_handled()
		KEY_H:
			var pc_h := local_player.controller as PlayerController
			if br_ui.visible or (pc_h != null and pc_h.active_vehicle != null):
				return
			if local_player.usar_cura_auto():
				hud_message.emit("Usando %s..." % String(BRInventory.definition(local_player.cura_id).get("name", "cura")), 1.5)
			else:
				hud_message.emit("Sem cura utilizável (bandagem/kit médico) ou vida cheia", 1.8)
			get_viewport().set_input_as_handled()


func _conteudo_aberto(loot: BRLoot) -> BRInventory:
	if loot == null or _precisa_abrir(loot):
		return null
	return loot.contents


func _load_map() -> void:
	ilha = load("res://maps/ilha/ilha.tscn").instantiate()
	ilha.name = "Map"
	# radar: mapa do Design cobrindo x,z em [-600, 600]
	ilha.set_meta("radar_texture", "res://maps/ilha/radar.png")
	ilha.set_meta("radar_rect", Rect2(-600, -600, 1200, 1200))
	map = ilha
	ilha.connect("map_ready", _on_island_ready, CONNECT_ONE_SHOT)
	add_child(ilha)


func _on_island_ready() -> void:
	Loading.marcar_passo("br_limites_saque")
	_criar_limites()
	var ex := ilha.get_node_or_null("Explorador")   # câmera livre do tour: não existe na partida
	if ex:
		ex.queue_free()
	await _espalhar_saque_async()
	await _finish_match_setup()


## Paredes físicas dentro da cobertura do heightmap, inclusive durante o paraquedas.
## Não existe piso extrapolado fora da grade; height_world sozinho não prova colisão.
func _criar_limites() -> void:
	var lo := IlhaTerrain.ORIGIN
	var hi := lo + (IlhaTerrain.N - 1) * IlhaTerrain.STEP
	var centro := (lo + hi) * 0.5
	var largura := hi - lo
	var fundo := -100.0
	var topo := maxf(float(ilha.layout.aviao.get("altitude_m", 300.0)) + 100.0, 500.0)
	for i in 4:
		var body := StaticBody3D.new()
		body.name = "LimiteBR%d" % i
		body.collision_layer = Soldier.LAYER_WORLD
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, topo - fundo, largura) if i < 2 else Vector3(largura, topo - fundo, 2.0)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		body.position = Vector3(lo + 1.0 if i == 0 else hi - 1.0, (topo + fundo) * 0.5, centro) if i < 2 else Vector3(centro, (topo + fundo) * 0.5, lo + 1.0 if i == 2 else hi - 1.0)
		add_child(body)


## Pontos de saque do layout: só servem de destino para os bots circularem (sem armas soltas no chão).
func _espalhar_saque_async() -> void:
	var t: IlhaTerrain = ilha.terrain
	for poi in ilha.layout.pois:
		for sq in poi.get("saque", []):
			var x := float(sq.pos[0])
			var z := -float(sq.pos[1])
			var h: float = t.height_world(x, z)
			pontos_saque.append(Vector3(x, _piso(Vector3(x, h + 30.0, z), h), z))
	saques = pontos_saque.size()


func _piso(de_cima: Vector3, chao: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(de_cima, Vector3(de_cima.x, chao - 1.0, de_cima.z), 1)
	var hit := ilha.get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if hit else chao


func spawns_for(_team: int) -> Array[Node3D]:
	return []


func _spawn_soldiers_async() -> void:
	local_player = _make_soldier(0, Settings.player_name, false)
	var pc := local_player.controller as PlayerController
	if pc and pc.camera:
		pc.camera.far = 6000.0   # mar/céu até o horizonte (ilha usa 6 km)
	await get_tree().process_frame
	var n := int(Game.test_args.get("bots", "0"))
	var nomes: Array = Game.BOT_NAMES_T + Game.BOT_NAMES_CT
	for i in n:
		# time só escolhe o modelo (tr/ct); a luta é todos contra todos
		_make_soldier((i + 1) % 2, String(nomes[i % nomes.size()]) + ("" if i < nomes.size() else " %d" % (i / nomes.size() + 1)), true)
		Loading.set_progress("Carregando modelos dos jogadores...", 82.0 + 10.0 * float(i + 1) / maxf(1.0, float(n)))
		await get_tree().process_frame


## Bot do BR no lugar do BotBrain de CS.
func _make_soldier(team: int, pname: String, bot: bool) -> Soldier:
	var s := super(team, pname, bot)
	if bot:
		var velho := s.controller as Node
		var brain := BRBotBrain.new()
		brain.name = "BrainBR"
		s.add_child(brain)
		brain.setup(s, self)
		s.controller = brain
		velho.queue_free()
		# corpo dos bots: some além de 300 m e só faz sombra perto (a sombra do sol só vai a 70 m mesmo)
		for g in s.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = 300.0
	return s


func friendly_fire() -> bool:
	return true


func is_ffa() -> bool:
	return true


func start_round() -> void:
	round_number = 1
	fx.clear_round()
	var t: IlhaTerrain = ilha.terrain
	var no_chao := true   # sobrevivência: todos nascem no chão, perto da cidade (Vila)
	for s in soldiers:
		s.reset_for_round(false)
		s.pitch = 0.0
		if no_chao:
			var x := SPAWN_JOGADOR.x
			var z := -SPAWN_JOGADOR.y
			var yaw_nasc := deg_to_rad(90.0)
			if not s.is_local:
				var q := _ponto_bot()
				x = q.x
				z = q.z
			elif _spawn_costa_ativo():
				var sp := escolher_spawn_costa()
				x = sp.pos.x
				z = sp.pos.z
				yaw_nasc = sp.yaw
			s.global_position = Vector3(x, _piso(Vector3(x, t.height_world(x, z) + 30.0, z), t.height_world(x, z)) + 0.2, z)
			s.yaw = yaw_nasc
			estado[s] = "chao"
		else:
			estado[s] = "aviao"
			if s.controller is BRBotBrain:
				_planejar_salto(s.controller as BRBotBrain)
			var d := (rota_ate - rota_de).normalized()
			s.yaw = atan2(-d.x, -d.z)   # olhando para o avião, no sentido do voo
			s.pitch = deg_to_rad(-12.0)
			s.external_motion = true
			s.frozen = true
			s.visible = false
		s.reset_physics_interpolation()
	_sem_zona()
	phase = Phase.LIVE
	phase_left = 0.0
	buy_left = 0.0
	for s in soldiers:
		if s.controller and s.controller.has_method("on_round_start"):
			s.controller.on_round_start()
	phase_changed.emit(phase)
	scores_changed.emit()
	_hud_br()
	if no_chao:
		hud_message.emit("Sobreviva. Revire os móveis das casas (segure E) e abra as caixas dos galpões.", 6.0)
	else:
		hud_message.emit("ESPAÇO para saltar quando o avião estiver sobre a ilha", 6.0)


## Sobrevivência: sem zona — o círculo fica gigante e nunca causa dano (os bots só o consultam).
func _sem_zona() -> void:
	zona_c = Vector2.ZERO
	zona_r = 100000.0
	zona_prox_c = Vector2.ZERO
	zona_prox_r = 100000.0
	zona_dano = 0.0
	zona_fases.clear()


## Bots nascem espalhados perto de pontos de saque (autorais), nunca empilhados no jogador.
func _ponto_bot() -> Vector3:
	return pontos_saque[randi() % pontos_saque.size()]


## Spawn estilo DayZ: o jogador nasce numa praia sorteada ao redor da ilha (antes: sempre no mesmo adro da Vila,
## virado para o mesmo lado). Em testes automatizados o ponto continua fixo, salvo `--spawn_costa`.
var _ultimo_spawn := Vector3(1e6, 0.0, 1e6)


func _spawn_costa_ativo() -> bool:
	return not Game.test_mode or Game.test_args.has("spawn_costa")


## Ponto de praia válido: de 14 a 60 m para dentro da costa sorteada, terreno entre 0,6 e 9 m, inclinação < ~12°, sem geometria
## sólida na cápsula e longe de zumbis (> 45 m). Devolve {pos: Vector3, yaw: float (olhando para o interior), tentativas: int}.
func escolher_spawn_costa(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var t: IlhaTerrain = ilha.terrain
	var costa: Array = ilha.layout.get("costa", [])
	var melhor := {"pos": Vector3(SPAWN_JOGADOR.x, 0.0, -SPAWN_JOGADOR.y), "yaw": deg_to_rad(90.0), "tentativas": 0, "fixo": true}
	if costa.size() < 4:
		return melhor
	var space := ilha.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.8
	var zumbis := get_tree().get_nodes_in_group("zombie")
	var tem_colisao := t.get_node_or_null("TerrenoColisao") != null
	for tent in 120:
		var c: Array = costa[r.randi() % costa.size()]
		var costa_p := Vector3(float(c[0]), 0.0, -float(c[1]))
		var para_dentro := (Vector3.ZERO - costa_p).normalized()
		var d := r.randf_range(14.0, 60.0)
		var p := costa_p + para_dentro * d
		var h := t.height_world(p.x, p.z)
		if h < 0.6 or h > 9.0:
			continue
		var decl := 0.0
		for off in [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]:
			decl = maxf(decl, absf(t.height_world(p.x + off.x, p.z + off.z) - h) / 3.0)
		if decl > 0.21:
			continue
		if _ultimo_spawn.distance_to(Vector3(p.x, h, p.z)) < 80.0:
			continue   # não renasce em cima do ponto anterior
		var perto := false
		for z in zumbis:
			if (z as Node3D).global_position.distance_to(Vector3(p.x, h, p.z)) < 45.0:
				perto = true
				break
		if perto:
			continue
		if tem_colisao:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cap
			q.transform = Transform3D(Basis(), Vector3(p.x, h + 1.15, p.z))
			q.collision_mask = 1
			if not space.intersect_shape(q, 1).is_empty():
				continue
			# vista livre: nada sólido a 5 m à frente (tronco/cerca/parede na cara do jogador ao nascer)
			var rq := PhysicsRayQueryParameters3D.create(Vector3(p.x, h + 1.6, p.z), Vector3(p.x, h + 1.6, p.z) + para_dentro * 5.0, 1)
			if not space.intersect_ray(rq).is_empty():
				continue
		_ultimo_spawn = Vector3(p.x, h, p.z)
		return {"pos": Vector3(p.x, h, p.z), "yaw": atan2(-para_dentro.x, -para_dentro.z), "tentativas": tent + 1, "fixo": false}
	return melhor


func respawn(s: Soldier) -> void:
	var t: IlhaTerrain = ilha.terrain
	var x := SPAWN_JOGADOR.x + (0.0 if s.is_local else randf_range(-6.0, 6.0))
	var z := -SPAWN_JOGADOR.y
	var yaw_nasc := deg_to_rad(90.0)
	if not s.is_local:
		var q := _ponto_bot()
		x = q.x
		z = q.z
	elif _spawn_costa_ativo():
		var sp := escolher_spawn_costa()
		x = sp.pos.x
		z = sp.pos.z
		yaw_nasc = sp.yaw
	s.reset_for_round(false)
	s.yaw = yaw_nasc
	s.global_position = Vector3(x, _piso(Vector3(x, t.height_world(x, z) + 30.0, z), t.height_world(x, z)) + 0.2, z)
	s.reset_physics_interpolation()
	estado[s] = "chao"
	if s.is_local:
		s.frozen = false
		hud_message.emit("Você renasceu perto da cidade. Procure suprimentos.", 5.0)
		if s.controller and s.controller.has_method("on_round_start"):
			s.controller.on_round_start()


## Uma das rotas autorais do layout (o Design previu sorteio entre 4, com sentido invertível = 8 variações).
func _preparar_voo() -> void:
	var av: Dictionary = ilha.layout.aviao
	var rotas: Array = av.rotas
	var r: Dictionary = rotas[randi() % rotas.size()]
	var a := Vector2(float(r.de[0]), float(r.de[1]))
	var b := Vector2(float(r.ate[0]), float(r.ate[1]))
	if randi() % 2 == 1:
		var c := a
		a = b
		b = c
	var alt := float(av.get("altitude_m", 300.0))
	rota_de = Vector3(a.x, alt, -a.y)
	rota_ate = Vector3(b.x, alt, -b.y)
	voo_dur = rota_de.distance_to(rota_ate) / float(av.get("velocidade_m_s", 45.0))
	voo_t = 0.0
	# trecho sobre terra: amostra a rota a cada ~5 m no heightmap (terreno > 1 m = ilha)
	var t: IlhaTerrain = ilha.terrain
	var ini := -1.0
	var fim := -1.0
	var n := int(rota_de.distance_to(rota_ate) / 5.0)
	for i in n + 1:
		var q := rota_de.lerp(rota_ate, float(i) / n)
		if t.height_world(q.x, q.z) > 1.0:
			if ini < 0.0:
				ini = voo_dur * i / n
			fim = voo_dur * i / n
	voo_terra = Vector2(ini, fim) if ini >= 0.0 else Vector2(0.0, voo_dur)
	aviao = AVIAO_CENA.instantiate()
	aviao.name = "AviaoSalto"
	add_child(aviao)
	_posicionar_aviao()


## Bot: ponto de saque sorteado; salta no instante em que o avião passa mais perto dele (dentro do trecho sobre terra).
func _planejar_salto(b: BRBotBrain) -> void:
	b.pouso = pontos_saque[randi() % pontos_saque.size()]
	var dir := rota_ate - rota_de
	var k := clampf((b.pouso - rota_de).dot(dir) / dir.length_squared(), 0.0, 1.0)
	b.salto_t = clampf(k * voo_dur - randf_range(2.0, 6.0), voo_terra.x + 0.5, voo_terra.y - 0.5)


func _posicionar_aviao() -> void:
	var p := rota_de.lerp(rota_ate, clampf(voo_t / voo_dur, 0.0, 1.0))
	var dir := (rota_ate - rota_de).normalized()
	# frente do modelo = +X local
	var basis := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.UP, deg_to_rad(90.0))   # +X do modelo -> direção do voo
	aviao.global_transform = Transform3D(basis, p)


func _process(dt: float) -> void:
	clock += dt
	_update_br_loot_hint()
	_lod_corpos()


var _lod_corpos_t := -1.0

## LOD dos corpos pela distância à câmera: perto < 35 m, médio < 90 m, longe além.
func _lod_corpos() -> void:
	if clock - _lod_corpos_t < 0.2:
		return   # distâncias de LOD (35/90 m): 5 Hz bastam, não é quadro a quadro
	_lod_corpos_t = clock
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	for s: Soldier in soldiers:
		if s == local_player or s.body_model == null or not s.body_model.has_method("set_lod"):
			continue
		var d := s.global_position.distance_to(cp)
		s.body_model.set_lod(0 if d < 35.0 else (1 if d < 90.0 else 2))


# ------------------------------------------------------------------ zona
func _zona_iniciar(atraso: float) -> void:
	var z: Dictionary = ilha.layout.zona
	var finais: Array = z.finais_candidatos
	var f: Dictionary = finais[randi() % finais.size()]
	zona_final = String(f.nome)
	var alvo := Vector2(float(f.pos[0]), -float(f.pos[1]))   # xz do mundo
	var fases: Array = z.fases
	zona_r = float(fases[0].raio_m)
	zona_c = Vector2.ZERO
	var c := zona_c
	var r := zona_r
	var t := clock + atraso
	zona_fases.clear()
	for i in range(1, fases.size()):
		var fz: Dictionary = fases[i]
		var rn := float(fz.raio_m)
		var d := c.distance_to(alvo)
		var cn := c.move_toward(alvo, minf(d, maxf(r - rn, 0.0)))
		var t0 := t
		var t1 := t0 + float(fz.espera_s)
		var t2 := t1 + float(fz.fechamento_s)
		zona_fases.append([t0, t1, t2, cn, rn, float(fz.dano_hp_s)])
		c = cn
		r = rn
		t = t2
	zona_prox_c = zona_fases[0][3]
	zona_prox_r = zona_fases[0][4]
	_parede = MeshInstance3D.new()
	_parede.name = "ParedeZona"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 900.0
	cm.radial_segments = 96
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	_parede.mesh = cm
	var mt := ShaderMaterial.new()
	mt.shader = load("res://shaders/zona.gdshader")
	_parede.material_override = mt
	_parede.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_parede)
	_zona_visual()


func _zona_atualizar(dt: float) -> void:
	if zona_fases.is_empty():
		return
	var prev_c := Vector2.ZERO
	var prev_r := float(ilha.layout.zona.fases[0].raio_m)
	var ativa := -1
	for i in zona_fases.size():
		var e: Array = zona_fases[i]
		if clock < e[0]:
			break
		ativa = i
		if clock < e[2]:
			break
		prev_c = e[3]
		prev_r = e[4]
	if ativa < 0:
		# ainda no voo: ilha inteira
		zona_c = prev_c
		zona_r = prev_r
		zona_dano = 0.0
		phase_left = zona_fases[0][1] - clock
	else:
		var e: Array = zona_fases[ativa]
		zona_prox_c = e[3]
		zona_prox_r = e[4]
		if ativa > 0 and clock >= e[0]:
			prev_c = zona_fases[ativa - 1][3]
			prev_r = zona_fases[ativa - 1][4]
		if clock < e[1]:
			zona_c = prev_c
			zona_r = prev_r
			zona_dano = zona_fases[ativa - 1][5] if ativa > 0 else 0.0
			phase_left = e[1] - clock
			_zona_aviso(ativa * 2, "A zona vai fechar em %d s" % int(e[1] - clock))
		elif clock < e[2]:
			var k: float = (clock - float(e[1])) / (float(e[2]) - float(e[1]))
			zona_c = prev_c.lerp(e[3], k)
			zona_r = lerpf(prev_r, e[4], k)
			zona_dano = e[5]
			phase_left = e[2] - clock
			_zona_aviso(ativa * 2 + 1, "A ZONA ESTÁ FECHANDO — vá para o círculo branco no radar")
		else:
			zona_c = e[3]
			zona_r = e[4]
			zona_dano = e[5]
			phase_left = 0.0
	_zona_visual()
	_zona_tick += dt
	if _zona_tick >= 1.0:
		_zona_tick -= 1.0
		for s: Soldier in soldiers:
			if s.alive and estado.get(s, "chao") == "chao" and fora_da_zona(s.global_position) and zona_dano > 0.0:
				s.set_meta("dano_zona_t", clock)   # killfeed: morte pela zona, não "Queda"
				s.take_damage(zona_dano, null, null, "chest", Vector3.DOWN)


func _zona_aviso(id: int, texto: String) -> void:
	if id != zona_msg:
		zona_msg = id
		hud_message.emit(texto, 5.0)


func fora_da_zona(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(zona_c) > zona_r


func _zona_visual() -> void:
	if _parede:
		_parede.visible = zona_r > 0.5
		_parede.global_transform = Transform3D(Basis().scaled(Vector3(maxf(zona_r, 0.5), 1.0, maxf(zona_r, 0.5))), Vector3(zona_c.x, 300.0, zona_c.y))


## Para o radar: [centro atual, raio atual, próximo centro, próximo raio] no plano xz do mundo.
func zona_radar() -> Array:
	return [zona_c, zona_r, zona_prox_c, zona_prox_r]


func _physics_process(dt: float) -> void:
	if aviao:
		voo_t += dt
		_posicionar_aviao()
	for s: Soldier in soldiers:
		if not s.alive:
			continue
		match String(estado.get(s, "chao")):
			"aviao":
				s.global_position = aviao.global_transform * OLHO_VOO - Vector3(0, Soldier.EYE_STAND, 0)
				var liberado := voo_t > maxf(float(ilha.layout.aviao.get("salto_liberado_apos_s", 3)), voo_terra.x)
				var quer := s.is_local and Input.is_action_just_pressed("jump") and not Game.test_mode
				if s.controller is BRBotBrain:
					quer = voo_t >= (s.controller as BRBotBrain).salto_t
				if (liberado and quer) or voo_t >= voo_terra.y:
					saltar(s)
			"queda", "para":
				_descer(s, dt)
	if aviao and voo_t >= voo_dur + 5.0:
		aviao.queue_free()
		aviao = null


func pode_saltar() -> bool:
	return voo_t > voo_terra.x and voo_t < voo_terra.y


## A câmera local fica em terceira pessoa durante avião, queda livre e paraquedas.
func is_player_airborne(s: Soldier) -> bool:
	return estado.get(s, "chao") in ["aviao", "queda", "para"]


func saltar(s: Soldier) -> void:
	if estado.get(s) != "aviao":
		return
	estado[s] = "queda"
	s.visible = true
	s.global_position = aviao.global_transform * RAMPA
	s.reset_physics_interpolation()
	if s.is_local:
		Audio.ambient("wind_whoosh_loop", -8.0)
		hud_message.emit("WASD guia a queda — o paraquedas abre a %d m do chão" % int(PARA_ALTURA), 4.0)


## Queda livre / paraquedas: movimento guiado pelo WASD na direção do olhar; pousa no chão ou num telhado.
func _descer(s: Soldier, dt: float) -> void:
	var t: IlhaTerrain = ilha.terrain
	var p := s.global_position
	var chao := _piso(p + Vector3.UP * 0.5, t.height_world(p.x, p.z))
	var para: bool = estado[s] == "para"
	if not para and p.y - chao < PARA_ALTURA:
		estado[s] = "para"
		para = true
		if s.is_local:
			Audio.set_ambient_volume(-19.0)
		if s.is_local and Audio.has_sound("parachute_open"):
			Audio.play("parachute_open", {"volume_db": -5.0})
	var b := Basis(Vector3.UP, s.yaw)
	var mv := s.in_move
	var hor := b * Vector3(mv.x, 0.0, -mv.y)
	if hor.length() > 1.0:
		hor = hor.normalized()
	hor *= PARA_H if para else QUEDA_H
	var vy := -(PARA_V if para else QUEDA_V)
	# Varre a cápsula, em vez de atravessar telhados/encostas e corrigir a altura depois.
	# O nível visual do mar não é chão: a descida continua até o fundo físico.
	var restante := (hor + Vector3(0, vy, 0)) * dt
	for tentativa in 4:
		var hit := s.move_and_collide(restante)
		if hit == null:
			break
		var normal := hit.get_normal()
		if normal.dot(Vector3.UP) >= cos(s.floor_max_angle):
			estado[s] = "chao"
			if s.is_local:
				Audio.ambient("amb_village", -14.0)
			s.external_motion = false
			s.frozen = false
			s.velocity = Vector3.ZERO
			s.fall_speed = 0.0
			s.was_on_floor = true
			s.apply_floor_snap()
			return
		restante = hit.get_remainder().slide(normal)
		if restante.length_squared() < 0.000001:
			break



## HUD do CS -> sobrevivência: sem dinheiro, placar, cronômetro, radar nem killfeed.
func _hud_br() -> void:
	hud.modo_sobrevivencia()


func can_buy(_s: Soldier) -> bool:
	return false


func _check_elimination() -> void:
	# sobrevivência: sem fim de partida; quem morre renasce (bots rápido, jogador depois da tela de morte)
	for s: Soldier in soldiers:
		if not s.alive and not s.has_meta("respawn_agendado"):
			s.set_meta("respawn_agendado", true)
			var espera := RESPAWN_S if s.is_local else 25.0
			if s.is_local:
				hud_message.emit("Você morreu. Renascendo em %d s..." % int(espera), espera)
			get_tree().create_timer(espera).timeout.connect(func() -> void:
				s.remove_meta("respawn_agendado")
				respawn(s))
