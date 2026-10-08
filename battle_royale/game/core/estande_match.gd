class_name EstandeMatch
extends Match
## Estande de tiro (maps/estande): só o jogador, na baia em z = 0,3 olhando para -Z, com todas as armas e munição infinita.
## Registra os impactos para o gate de mira (tests/estande_gate.gd). Teclas 1–5: AK, M4, Mosin, Glock, USP; R recarrega.

const ARMAS := [&"ak47", &"m4", &"mosin", &"glock", &"usp", &"uzi", &"m249", &"m107"]
const POS := Vector3(0.0, 0.05, 0.3)

var estande: Estande
var impactos: Array[Vector3] = []
var acog := false   # tecla 0 (ou o teste) instala/remove a ACOG da AK/M4


func _load_map() -> void:
	estande = Estande.new()
	estande.name = "Map"
	map = estande
	add_child(estande)
	_finish_match_setup.call_deferred()


func _spawn_soldiers_async() -> void:
	local_player = _make_soldier(0, Settings.player_name, false)
	await get_tree().process_frame


func start_round() -> void:
	round_number = 1
	var s := local_player
	s.reset_for_round(false)
	s.global_position = POS
	s.yaw = 0.0
	s.pitch = 0.0
	s.reset_physics_interpolation()
	equipar(&"ak47")
	phase = Phase.LIVE
	phase_left = 0.0
	buy_left = 0.0
	if s.controller and s.controller.has_method("on_round_start"):
		s.controller.on_round_start()
	phase_changed.emit(phase)
	if hud and hud.has_method("modo_sobrevivencia"):
		hud.modo_sobrevivencia()
	hud_message.emit("ESTANDE — 1 AK · 2 M4 · 3 Mosin · 4 Glock · 5 USP · 0 ACOG · botão direito mira", 8.0)


## Troca a arma do slot pela pedida (primária ou pistola) e entra com ela na mão, carregada.
func equipar(id: StringName) -> void:
	var s := local_player
	var def := WeaponDB.get_def(id)
	if def == null:
		return
	s.inventory.erase(def.slot)
	var ws := s.give_weapon(id, true)
	ws.mag = def.mag_size
	ws.reserve = 999
	# mesmo slot da arma anterior: passa pela faca para o viewmodel recarregar o modelo (weapon_switched)
	if s.active_slot == def.slot:
		s.switch_to(WeaponDef.Slot.KNIFE)
	s.switch_to(def.slot)


func _process(dt: float) -> void:
	clock += dt
	var s := local_player
	if s:
		var ws: WeaponState = s.current()
		if ws and ws.def.is_gun():
			ws.reserve = 999


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_0:
			acog = not acog
			hud_message.emit("ACOG " + ("instalada" if acog else "removida"), 2.0)
			get_viewport().set_input_as_handled()
			return
		var i: int = int(event.physical_keycode) - KEY_1
		if i >= 0 and i < ARMAS.size():
			equipar(ARMAS[i])
			get_viewport().set_input_as_handled()


func on_impact(pos: Vector3, normal: Vector3, surface: String, dir: Vector3) -> void:
	impactos.append(pos)
	super(pos, normal, surface, dir)


func has_acog_for(s: Soldier) -> bool:
	var d := s.current_def()
	return acog and d != null and d.ads_acog_fov > 0.0 and d.id != &"mosin"


func can_buy(_s: Soldier) -> bool:
	return false


func is_survival() -> bool:
	return true


func friendly_fire() -> bool:
	return false


func _check_elimination() -> void:
	pass
