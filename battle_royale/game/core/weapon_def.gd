class_name WeaponDef
extends RefCounted
## Static definition of a weapon (numbers inspired by CS:GO, converted to meters).

enum Slot { PRIMARY = 1, PISTOL = 2, KNIFE = 3, BOMB = 4 }

var id: StringName
var display_name := ""
var slot := Slot.PRIMARY
var team := -1                 # -1 ambos, 0 TR, 1 CT
var price := 0
var kill_reward := 300
var damage := 30.0
var armor_ratio := 0.5         # fração do dano que vai para a vida quando há colete
var range_mod := 0.98          # multiplicador por 12,7 m (500 unidades)
var fire_interval := 0.1
var automatic := false
var mag_size := 30
var reserve_max := 90
var reload_time := 2.5
var draw_time := 1.0
var move_speed := 5.46         # m/s
var headshot_mult := 4.0
# dano em ZUMBIS: fração da vida máxima por tiro (tabela em WeaponDB.ZUMBI_DANO)
var zumbi_cabeca := 0.5
var zumbi_corpo := 0.2
var penetration := 1.0         # 0 nada, 1 madeira/chapa, 2 rebocos finos
var max_range := 200.0          # hitscan (faca); armas de fogo usam projétil (muzzle_velocity)
# precisão (graus)
var spread_stand := 0.3
var spread_crouch := 0.2
var spread_move := 6.0
var spread_air := 14.0
var spread_fire := 0.4
var spread_fire_max := 5.0
var spread_recover := 0.35
var recoil_pattern := PackedVector2Array()   # deslocamento acumulado por disparo (x direita, y cima)
var recoil_recover := 0.45     # s para zerar o spray depois de soltar o gatilho
var view_kick := 0.5           # fração do padrão aplicada na câmera
var recoil_random := 0.12
# apresentação
var model_path := ""
var fire_sound := ""
var tracer_every := 3
var shell_eject := true
var casing_scale := 1.0
var muzzle_scale := 1.0
var kill_icon := ""

# ADS is presentation data consumed by the local controller. The magazine and
# reserve still live in WeaponState, so drops/pickups retain their ammunition.
var ads_iron_fov := 0.0       # 0 disables ADS for this weapon
var ads_acog_fov := 0.0       # 0 means iron sights only
var ads_transition := 0.16
var ammo_type: StringName = &"" # integration key for BR ammo/loot

# --- balística (estilo DayZ/Arma: projétil simulado com gravidade + arrasto a = -k·|v|·v) ---
# muzzle_velocity 0 = hitscan (faca/bomba). air_friction = k (1/m), equivalente ao -airFriction do Arma:
# v(x) ≈ v0·e^{-k·x} no tiro horizontal. zero_range: distância em que a trajetória cruza a linha de visada.
var caliber := ""
var muzzle_velocity := 0.0     # m/s
var air_friction := 0.0012     # 1/m
var zero_range := 100.0        # m
var sight_height := 0.06       # m entre a linha de visada (olho) e o eixo do cano
var bullet_max_time := 4.0     # s de voo antes de descartar o projétil
# --- coice de câmera (impulso por tiro numa mola criticamente amortecida, exata por passo) ---
var kick_deg := 0.0            # pico de subida da câmera num tiro isolado (graus); 0 = só o padrão antigo
var kick_omega := 26.0         # rigidez da mola (rad/s): retorno a 10% ≈ 5,3/ω s depois do disparo
var kick_yaw := 0.25           # fração lateral aleatória do impulso

const GRAVIDADE := 9.81
const BAL_DT := 1.0 / 128.0    # subpasso máximo da integração (2 por tique de 64 Hz)
var _zero_cache := NAN


## Um subpasso de ponto médio (RK2) da equação dv/dt = g - k·|v|·v. Erro < 0,5% de queda a 400 m.
static func passo_balistico(p: Vector3, v: Vector3, k: float, dt: float) -> Array:
	var a1 := Vector3(0.0, -GRAVIDADE, 0.0) - v * (k * v.length())
	var vm := v + a1 * (dt * 0.5)
	var a2 := Vector3(0.0, -GRAVIDADE, 0.0) - vm * (k * vm.length())
	return [p + vm * dt, v + a2 * dt]


## Ângulo (rad, para cima) entre a linha de visada e o cano para que a bala, saindo sight_height abaixo
## do olho, cruze a visada em zero_range (tiro nivelado). Calculado uma vez com a mesma integração do jogo.
func zero_angle() -> float:
	if not is_nan(_zero_cache):
		return _zero_cache
	if muzzle_velocity <= 0.0 or zero_range <= 0.0:
		_zero_cache = 0.0
		return 0.0
	var lo := -0.01
	var hi := 0.06
	for _i in 36:
		var mid := (lo + hi) * 0.5
		if _altura_em(mid, zero_range) < 0.0:
			lo = mid
		else:
			hi = mid
	_zero_cache = (lo + hi) * 0.5
	return _zero_cache


## Altura (m) da bala em relação à linha de visada ao atingir a distância x, com ângulo de cano theta.
func _altura_em(theta: float, x: float) -> float:
	var p := Vector3(0.0, -sight_height, 0.0)
	var v := Vector3(0.0, sin(theta), -cos(theta)) * muzzle_velocity
	var t := 0.0
	while -p.z < x and t < bullet_max_time:
		var r := passo_balistico(p, v, air_friction, BAL_DT)
		var np: Vector3 = r[0]
		if -np.z >= x:
			var f := (x + p.z) / (p.z - np.z)
			return lerpf(p.y, np.y, f)
		p = np
		v = r[1]
		t += BAL_DT
	return -INF


## Padrão do CS encolhido (estilo DayZ: a bala vai para onde a arma aponta; a câmera sobe ~1° em 10 tiros, então o
## padrão não pode levar a bala a 5–6°). AK: 10 tiros ~2° em vez de 5,8°.
const SPRAY_ESCALA := 0.35


func pattern_offset(shots: float) -> Vector2:
	if recoil_pattern.is_empty():
		return Vector2.ZERO
	var n := recoil_pattern.size()
	var s := clampf(shots, 0.0, float(n - 1))
	var i := int(floor(s))
	var j := mini(i + 1, n - 1)
	return recoil_pattern[i].lerp(recoil_pattern[j], s - float(i)) * SPRAY_ESCALA


func is_gun() -> bool:
	return slot == Slot.PRIMARY or slot == Slot.PISTOL
