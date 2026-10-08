extends Node
## Hand-tuned weapon table (CS:GO inspired). Recoil patterns are authored by hand.

const EQUIP := {
	"kevlar": {"name": "Colete", "price": 650},
	"helmet": {"name": "Colete + Capacete", "price": 1000},
	"defuser": {"name": "Kit de desarme", "price": 400},
}

var weapons: Dictionary = {}   # StringName -> WeaponDef

## DANO EM ZUMBIS (regra de negócio). Cada valor é a FRAÇÃO DA VIDA MÁXIMA do zumbi tirada por um tiro:
##   [cabeça, corpo]   (cabeça = ~20% superiores da cápsula; ver ZombieEnemy.zona_do_impacto)
## Base (AK/M4/M249): cabeça 50% (2 tiros matam), corpo 20% (5 tiros).
## Sniper/.50 e escopeta: cabeça mata na hora, corpo >= 50%. Pistola/Uzi: um pouco menos
## (cabeça >= 34% = 3 tiros; corpo 12-15% = 7-8 tiros). Sem queda por distância; parede atravessada
## reduz proporcionalmente ao dano residual da bala. Armas fora da tabela usam 0,50 / 0,20.
const ZUMBI_DANO := {
	&"ak47": [0.50, 0.20], &"m4": [0.50, 0.20], &"m249": [0.50, 0.20],
	&"glock": [0.34, 0.13], &"usp": [0.40, 0.15], &"uzi": [0.34, 0.12],
	&"mosin": [1.00, 0.55], &"m107": [1.00, 0.85],
	&"shotgun": [1.00, 0.50], &"knife": [0.50, 0.25],
}


func _ready() -> void:
	_add_ak47()
	_add_m4()
	_add_glock()
	_add_usp()
	_add_knife()
	_add_bomb()
	_add_mosin()
	_add_uzi()
	_add_m249()
	_add_m107()
	for id in ZUMBI_DANO:
		if weapons.has(id):
			weapons[id].zumbi_cabeca = ZUMBI_DANO[id][0]
			weapons[id].zumbi_corpo = ZUMBI_DANO[id][1]


func get_def(id: StringName) -> WeaponDef:
	return weapons.get(id)


## Loot hook: create a pickup-ready instance. Pass mag/reserve to preserve
## authored or dropped ammunition; omitted values use the weapon defaults.
func create_state(id: StringName, mag: int = -1, reserve: int = -1) -> WeaponState:
	var def := get_def(id)
	if def == null:
		return null
	var state := WeaponState.new(def)
	if mag >= 0:
		state.mag = mini(mag, def.mag_size)
	if reserve >= 0:
		state.reserve = mini(reserve, def.reserve_max)
	return state


## Ammo hook: returns how many rounds were accepted into reserve.
func add_ammo(state: WeaponState, ammo_id: StringName, rounds: int) -> int:
	if state == null or state.def.ammo_type != ammo_id or ammo_id == &"" or rounds <= 0:
		return 0
	var added := mini(rounds, state.def.reserve_max - state.reserve)
	state.reserve += added
	return added


func buyable_for(team: int) -> Array[WeaponDef]:
	var out: Array[WeaponDef] = []
	for w: WeaponDef in weapons.values():
		if w.price > 0 and (w.team == -1 or w.team == team):
			out.append(w)
	out.sort_custom(func(a, b): return a.slot < b.slot or (a.slot == b.slot and a.price < b.price))
	return out


func _pat(values: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in values:
		p.append(Vector2(v[0], v[1]))
	return p


## Balística por calibre (ver raw/triagem/balistica.json): v0 m/s, k = arrasto 1/m (≈ -airFriction do Arma),
## zero em m, altura da mira sobre o cano em m.
func _bal(w: WeaponDef, cal: String, v0: float, k: float, zero: float, h: float) -> void:
	w.caliber = cal; w.muzzle_velocity = v0; w.air_friction = k; w.zero_range = zero; w.sight_height = h


## Coice de câmera: pico do tiro isolado (graus), rigidez da mola (rad/s) e fração do padrão que vira deriva lenta.
func _kick(w: WeaponDef, deg: float, omega: float, drift: float) -> void:
	w.kick_deg = deg; w.kick_omega = omega; w.view_kick = drift


func _add_ak47() -> void:
	var w := WeaponDef.new()
	w.id = &"ak47"; w.display_name = "AK-47"; w.slot = WeaponDef.Slot.PRIMARY; w.team = 0
	w.price = 2700; w.kill_reward = 300
	w.damage = 36.0; w.armor_ratio = 0.775; w.range_mod = 0.98; w.penetration = 2.0
	w.fire_interval = 0.0916; w.automatic = true; w.mag_size = 30; w.reserve_max = 90
	w.reload_time = 2.45; w.draw_time = 1.0; w.move_speed = 5.46
	w.spread_stand = 0.28; w.spread_crouch = 0.18; w.spread_move = 7.0; w.spread_air = 15.0
	w.spread_fire = 0.42; w.spread_fire_max = 4.5; w.spread_recover = 0.38
	w.recoil_recover = 0.55; w.view_kick = 0.5
	# Forma "7": sobe ~9 tiros, puxa para a esquerda, depois direita, depois oscila.
	w.recoil_pattern = _pat([[0, 0], [0.05, 0.55], [0.08, 1.2], [0.02, 1.95], [-0.05, 2.75], [-0.02, 3.5],
		[0.1, 4.2], [0.25, 4.8], [0.35, 5.3], [0.1, 5.65], [-0.45, 5.85], [-1.05, 6.0], [-1.6, 6.1],
		[-1.95, 6.15], [-1.9, 6.25], [-1.4, 6.3], [-0.7, 6.35], [0.1, 6.35], [0.8, 6.4], [1.35, 6.45],
		[1.6, 6.5], [1.45, 6.6], [1.0, 6.65], [0.4, 6.7], [-0.2, 6.7], [-0.7, 6.75], [-0.9, 6.8],
		[-0.6, 6.85], [-0.1, 6.9], [0.3, 6.9]])
	w.model_path = "res://assets/models/weapons/wf/ak47.tscn"
	w.ads_iron_fov = 56.0; w.ads_acog_fov = 32.0; w.ads_transition = 0.17
	w.fire_sound = "ak47u_fire"; w.kill_icon = "AK-47"
	_bal(w, "7,62x39", 715.0, 0.0015, 100.0, 0.055)
	_kick(w, 0.68, 28.0, 0.035)
	weapons[w.id] = w


func _add_m4() -> void:
	var w := WeaponDef.new()
	w.id = &"m4"; w.display_name = "M4"; w.slot = WeaponDef.Slot.PRIMARY; w.team = 1
	w.price = 3100; w.kill_reward = 300
	w.damage = 33.0; w.armor_ratio = 0.70; w.range_mod = 0.97; w.penetration = 2.0
	w.fire_interval = 0.0843; w.automatic = true; w.mag_size = 30; w.reserve_max = 90
	w.reload_time = 3.05; w.draw_time = 1.1; w.move_speed = 5.72
	w.spread_stand = 0.24; w.spread_crouch = 0.16; w.spread_move = 6.2; w.spread_air = 14.0
	w.spread_fire = 0.36; w.spread_fire_max = 4.0; w.spread_recover = 0.34
	w.recoil_recover = 0.5; w.view_kick = 0.5
	w.recoil_pattern = _pat([[0, 0], [0, 0.45], [-0.03, 1.0], [0.02, 1.6], [0.08, 2.2], [0.12, 2.75],
		[0.05, 3.25], [-0.08, 3.65], [-0.2, 4.0], [-0.1, 4.25], [0.3, 4.4], [0.75, 4.5], [1.1, 4.6],
		[1.3, 4.65], [1.2, 4.7], [0.8, 4.75], [0.3, 4.8], [-0.3, 4.85], [-0.8, 4.9], [-1.15, 4.95],
		[-1.25, 5.0], [-1.0, 5.05], [-0.55, 5.1], [-0.05, 5.1], [0.4, 5.15], [0.7, 5.2], [0.8, 5.2],
		[0.55, 5.25], [0.15, 5.3], [-0.2, 5.3]])
	w.model_path = "res://assets/models/weapons/wf/m4.tscn"
	w.ads_iron_fov = 56.0; w.ads_acog_fov = 32.0; w.ads_transition = 0.17
	w.fire_sound = "m4u_fire"; w.kill_icon = "M4"
	_bal(w, "5,56x45", 900.0, 0.0011, 100.0, 0.065)
	_kick(w, 0.74, 28.0, 0.03)
	weapons[w.id] = w


func _add_glock() -> void:
	var w := WeaponDef.new()
	w.id = &"glock"; w.display_name = "Glock-18"; w.slot = WeaponDef.Slot.PISTOL; w.team = 0
	w.price = 0; w.kill_reward = 300
	w.damage = 30.0; w.armor_ratio = 0.47; w.range_mod = 0.85; w.penetration = 1.0
	w.fire_interval = 0.15; w.automatic = false; w.mag_size = 20; w.reserve_max = 120
	w.reload_time = 2.2; w.draw_time = 0.8; w.move_speed = 6.1
	w.spread_stand = 0.85; w.spread_crouch = 0.65; w.spread_move = 2.2; w.spread_air = 6.0
	w.spread_fire = 1.1; w.spread_fire_max = 5.0; w.spread_recover = 0.28
	w.recoil_recover = 0.3; w.view_kick = 0.6; w.recoil_random = 0.25
	w.recoil_pattern = _pat([[0, 0], [0.05, 0.9], [-0.1, 1.75], [0.1, 2.5], [0.2, 3.1], [-0.05, 3.6],
		[-0.25, 4.0], [0.0, 4.3], [0.25, 4.5], [0.1, 4.7]])
	w.model_path = "res://assets/models/weapons/wf/m1911.tscn"
	w.ads_iron_fov = 62.0; w.ads_transition = 0.14
	w.fire_sound = "glock_fire"; w.kill_icon = "Glock-18"; w.casing_scale = 0.7; w.muzzle_scale = 0.7
	_bal(w, "9x19", 360.0, 0.0013, 25.0, 0.025)
	_kick(w, 0.5, 20.0, 0.04)
	weapons[w.id] = w


func _add_usp() -> void:
	var w := WeaponDef.new()
	w.id = &"usp"; w.display_name = "USP"; w.slot = WeaponDef.Slot.PISTOL; w.team = 1
	w.price = 0; w.kill_reward = 300
	w.damage = 35.0; w.armor_ratio = 0.505; w.range_mod = 0.99; w.penetration = 1.0
	w.fire_interval = 0.17; w.automatic = false; w.mag_size = 12; w.reserve_max = 24
	w.reload_time = 2.2; w.draw_time = 0.8; w.move_speed = 6.1
	w.spread_stand = 0.5; w.spread_crouch = 0.38; w.spread_move = 1.9; w.spread_air = 6.0
	w.spread_fire = 1.05; w.spread_fire_max = 4.5; w.spread_recover = 0.3
	w.recoil_recover = 0.32; w.view_kick = 0.6; w.recoil_random = 0.2
	w.recoil_pattern = _pat([[0, 0], [0.0, 1.05], [0.1, 2.0], [-0.1, 2.8], [0.15, 3.4], [0.0, 3.9],
		[-0.2, 4.3], [0.1, 4.6], [0.2, 4.8], [0.0, 5.0]])
	w.model_path = "res://assets/models/weapons/wf/revolver.tscn"
	w.ads_iron_fov = 62.0; w.ads_transition = 0.14
	w.fire_sound = "usp_fire"; w.kill_icon = "USP"; w.casing_scale = 0.7; w.muzzle_scale = 0.6
	_bal(w, ".45 ACP", 270.0, 0.0014, 25.0, 0.025)
	_kick(w, 0.55, 20.0, 0.04)
	weapons[w.id] = w


func _add_knife() -> void:
	var w := WeaponDef.new()
	w.id = &"knife"; w.display_name = "Faca"; w.slot = WeaponDef.Slot.KNIFE; w.team = -1
	w.price = 0; w.kill_reward = 1500
	w.damage = 40.0; w.armor_ratio = 0.85
	w.fire_interval = 0.5; w.automatic = true; w.mag_size = -1; w.reserve_max = 0
	w.draw_time = 0.6; w.move_speed = 6.35; w.max_range = 1.6
	w.model_path = "res://assets/models/weapons/knife.tscn"
	w.kill_icon = "Faca"
	weapons[w.id] = w


func _add_bomb() -> void:
	var w := WeaponDef.new()
	w.id = &"bomb"; w.display_name = "Bomba C4"; w.slot = WeaponDef.Slot.BOMB; w.team = 0
	w.price = 0; w.kill_reward = 0; w.mag_size = -1; w.reserve_max = 0
	w.draw_time = 0.6; w.move_speed = 6.35
	w.model_path = "res://assets/models/weapons/bomb.tscn"
	weapons[w.id] = w


## BR integration: WeaponDB.get_def(&"mosin") / WeaponState.new(def).
## Store a WeaponState in the inventory so mag/reserve survive drops.
func _add_mosin() -> void:
	var w := WeaponDef.new()
	w.id = &"mosin"; w.display_name = "Mosin-Nagant"; w.slot = WeaponDef.Slot.PRIMARY; w.team = -1
	w.price = 0; w.kill_reward = 300
	w.damage = 82.0; w.armor_ratio = 0.82; w.headshot_mult = 2.5
	w.range_mod = 0.99; w.penetration = 2.0; w.max_range = 400.0
	w.fire_interval = 1.45; w.automatic = false; w.mag_size = 5; w.reserve_max = 25
	w.reload_time = 3.2; w.draw_time = 1.0; w.move_speed = 5.15
	w.spread_stand = 0.10; w.spread_crouch = 0.07; w.spread_move = 4.5; w.spread_air = 12.0
	w.spread_fire = 0.6; w.spread_fire_max = 1.2; w.spread_recover = 0.8
	w.recoil_pattern = _pat([[0.0, 0.0], [0.1, 2.6], [-0.1, 4.3], [0.0, 5.0]])
	w.recoil_recover = 0.9; w.recoil_random = 0.08; w.view_kick = 0.6
	w.ads_iron_fov = 48.0; w.ads_acog_fov = 24.0; w.ads_transition = 0.17
	w.ammo_type = &"762x54r"
	w.model_path = "res://assets/models/weapons/wf/mosin.tscn"
	w.fire_sound = "mosin_fire"; w.kill_icon = "Mosin-Nagant"
	w.tracer_every = 1; w.casing_scale = 1.15; w.muzzle_scale = 1.2
	_bal(w, "7,62x54R", 830.0, 0.00095, 100.0, 0.04)
	_kick(w, 1.5, 11.0, 0.0)
	weapons[w.id] = w


## Armas extras do pacote Weapons FREE / Meshes (tools/armas_novas.json + tools/nova_arma.py).
func _add_uzi() -> void:
	var w := WeaponDef.new()
	w.id = &"uzi"; w.display_name = "Uzi"; w.slot = WeaponDef.Slot.PRIMARY; w.team = -1
	w.price = 0; w.kill_reward = 300
	w.damage = 24.0; w.armor_ratio = 0.55; w.range_mod = 0.92; w.penetration = 1.0
	w.fire_interval = 0.062; w.automatic = true; w.mag_size = 32; w.reserve_max = 96
	w.reload_time = 2.1; w.draw_time = 0.7; w.move_speed = 6.2
	w.spread_stand = 0.34; w.spread_crouch = 0.22; w.spread_move = 4.2; w.spread_air = 13.0
	w.spread_fire = 0.42; w.spread_fire_max = 5.2; w.spread_recover = 0.3
	w.recoil_recover = 0.55; w.view_kick = 0.45
	w.recoil_pattern = _pat([[0, 0], [0.1, 0.35], [-0.15, 0.8], [0.2, 1.3], [-0.25, 1.8], [0.3, 2.3], [-0.2, 2.7], [0.15, 3.1], [-0.3, 3.4], [0.35, 3.7]])
	w.model_path = "res://assets/models/weapons/wf/uzi.tscn"
	w.ads_iron_fov = 58.0; w.ads_acog_fov = 0.0; w.ads_transition = 0.15
	w.ammo_type = &"9mm"
	w.fire_sound = "uzi_fire"; w.kill_icon = "Uzi"; w.casing_scale = 0.7; w.muzzle_scale = 0.8
	_bal(w, "9x19", 400.0, 0.0013, 50.0, 0.03)
	_kick(w, 0.4, 32.0, 0.03)
	weapons[w.id] = w


func _add_m249() -> void:
	var w := WeaponDef.new()
	w.id = &"m249"; w.display_name = "M249"; w.slot = WeaponDef.Slot.PRIMARY; w.team = -1
	w.price = 0; w.kill_reward = 300
	w.damage = 31.0; w.armor_ratio = 0.8; w.range_mod = 0.97; w.penetration = 2.2
	w.fire_interval = 0.078; w.automatic = true; w.mag_size = 100; w.reserve_max = 200
	w.reload_time = 5.4; w.draw_time = 1.3; w.move_speed = 4.9
	w.spread_stand = 0.3; w.spread_crouch = 0.2; w.spread_move = 7.5; w.spread_air = 15.0
	w.spread_fire = 0.38; w.spread_fire_max = 4.8; w.spread_recover = 0.45
	w.recoil_recover = 0.45; w.view_kick = 0.5
	w.recoil_pattern = _pat([[0, 0], [0, 0.5], [0.05, 1.1], [0.1, 1.7], [0.05, 2.3], [-0.1, 2.8], [-0.25, 3.2], [-0.2, 3.6], [0.1, 3.9], [0.35, 4.1], [0.45, 4.3], [0.3, 4.5]])
	w.model_path = "res://assets/models/weapons/wf/m249.tscn"
	w.ads_iron_fov = 56.0; w.ads_acog_fov = 0.0; w.ads_transition = 0.22
	w.ammo_type = &"556"
	w.fire_sound = "m249u_fire"; w.kill_icon = "M249"; w.casing_scale = 1.0; w.muzzle_scale = 1.15
	_bal(w, "5,56x45", 915.0, 0.0011, 200.0, 0.065)
	_kick(w, 0.64, 30.0, 0.035)
	weapons[w.id] = w


func _add_m107() -> void:
	var w := WeaponDef.new()
	w.id = &"m107"; w.display_name = "M107"; w.slot = WeaponDef.Slot.PRIMARY; w.team = -1
	w.price = 0; w.kill_reward = 300
	w.damage = 118.0; w.armor_ratio = 0.9; w.headshot_mult = 2.0
	w.range_mod = 0.995; w.penetration = 3.5; w.max_range = 800.0
	w.fire_interval = 1.1; w.automatic = false; w.mag_size = 10; w.reserve_max = 30
	w.reload_time = 3.8; w.draw_time = 1.4; w.move_speed = 4.7
	w.spread_stand = 0.06; w.spread_crouch = 0.04; w.spread_move = 6.0; w.spread_air = 16.0
	w.spread_fire = 0.9; w.spread_fire_max = 1.8; w.spread_recover = 0.9
	w.recoil_pattern = _pat([[0.0, 0.0], [0.2, 3.4], [-0.2, 5.6], [0.1, 6.5]])
	w.recoil_recover = 0.8; w.recoil_random = 0.1; w.view_kick = 0.8
	w.ads_iron_fov = 40.0; w.ads_acog_fov = 16.0; w.ads_transition = 0.25
	w.ammo_type = &"127"
	w.model_path = "res://assets/models/weapons/wf/m107.tscn"
	w.fire_sound = "m107_fire"; w.kill_icon = "M107"; w.tracer_every = 1; w.casing_scale = 1.6; w.muzzle_scale = 1.6
	_bal(w, ".50 BMG", 880.0, 0.00048, 200.0, 0.07)
	_kick(w, 2.2, 11.0, 0.0)
	weapons[w.id] = w
