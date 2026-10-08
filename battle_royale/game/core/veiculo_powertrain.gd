extends RefCounted
## Transmissão simulada do sedã: curva de torque, 5 marchas automáticas, RPM (som/HUD) e combustível.
## Estado puro (não é nó). DrivableVehicle chama atualizar() a cada quadro de física.
## Carregado por preload (sem class_name) para não depender do cache global de classes.

## Relação de cada marcha (1ª..5ª). Com RELACAO_FINAL, a 1ª total ~13,9 e a 5ª ~4,6.
const RELACOES := [4.34, 3.10, 2.61, 1.97, 1.44]
const RELACAO_FINAL := 3.2
const RAIO_RODA := 0.35538
const RPM_LENTA := 850.0
const RPM_LIMITE := 6600.0
const RPM_SUBIR := 5600.0
const RPM_DESCER := 2000.0
## Rotação que o motor atinge ao arrancar parado com acelerador cheio (embreagem patinando).
const RPM_ARRANQUE := 4200.0
## Corte de torque durante a troca de marcha (s).
const TEMPO_TROCA := 0.28
const TANQUE_L := 40.0
const CONSUMO_MARCHA_LENTA_LPS := 0.0012
const CONSUMO_PLENO_LPS := 0.012
## Curva de torque normalizada: [rpm, fração do torque máximo].
const CURVA_TORQUE := [[850.0, 0.55], [2000.0, 0.85], [3800.0, 1.0], [5200.0, 0.94], [6600.0, 0.72]]

## Índice da marcha (0 = 1ª). Use marcha_humana() para exibir.
var marcha := 0
var rpm := RPM_LENTA
var combustivel_l := TANQUE_L * 0.75
var _troca := 0.0


## Rotação do motor se a roda girasse na velocidade dada (m/s) com a marcha indicada.
func rpm_da_velocidade(velocidade: float, indice: int) -> float:
	var rad_s := velocidade / RAIO_RODA
	return rad_s * 60.0 / TAU * RELACOES[indice] * RELACAO_FINAL


## Fração do torque máximo (0..1) para uma rotação, por interpolação linear da curva.
func torque_norm(r: float) -> float:
	if r <= CURVA_TORQUE[0][0]:
		return CURVA_TORQUE[0][1]
	for i in range(1, CURVA_TORQUE.size()):
		var a: Array = CURVA_TORQUE[i - 1]
		var b: Array = CURVA_TORQUE[i]
		if r <= b[0]:
			var t: float = (r - a[0]) / (b[0] - a[0])
			return lerpf(a[1], b[1], t)
	return CURVA_TORQUE[CURVA_TORQUE.size() - 1][1]


## Câmbio automático + rotação. ligado = motor com combustível e vida.
func atualizar(dt: float, velocidade: float, acelerador: float, ligado: bool) -> void:
	if _troca > 0.0:
		_troca = maxf(_troca - dt, 0.0)
	if ligado and _troca <= 0.0:
		var ultima := RELACOES.size() - 1
		var rot_atual := rpm_da_velocidade(velocidade, marcha)
		if marcha < ultima and rot_atual > RPM_SUBIR:
			marcha += 1
			_troca = TEMPO_TROCA
		elif marcha > 0 and rot_atual < RPM_DESCER:
			var rot_abaixo := rpm_da_velocidade(velocidade, marcha - 1)
			if rot_abaixo < RPM_LIMITE * 0.9:
				marcha -= 1
				_troca = TEMPO_TROCA
	var alvo := 0.0
	if ligado:
		alvo = maxf(RPM_LENTA, rpm_da_velocidade(velocidade, marcha))
		# Arranque: com o acelerador aberto e quase parado, o motor sobe acima da marcha lenta.
		if velocidade < 4.0 and acelerador > 0.05:
			alvo = maxf(alvo, RPM_LENTA + (RPM_ARRANQUE - RPM_LENTA) * clampf(acelerador, 0.0, 1.0))
		alvo = minf(alvo, RPM_LIMITE)
	# Inércia do motor: sobe mais devagar do que cai.
	var taxa := 7000.0 if alvo > rpm else 4500.0
	rpm = move_toward(rpm, alvo, dt * taxa)


## Multiplicador de torque do quadro (0..1). Corta a força durante a troca de marcha.
func fator_torque() -> float:
	if _troca > 0.0:
		return 0.2
	return torque_norm(rpm)


func rpm_norm() -> float:
	return clampf(rpm / RPM_LIMITE, 0.0, 1.0)


func consumir(dt: float, acelerador: float) -> void:
	var taxa := CONSUMO_MARCHA_LENTA_LPS + CONSUMO_PLENO_LPS * clampf(acelerador, 0.0, 1.0) * rpm_norm()
	combustivel_l = maxf(combustivel_l - taxa * dt, 0.0)


func tem_combustivel() -> bool:
	return combustivel_l > 0.001


func fracao_combustivel() -> float:
	return clampf(combustivel_l / TANQUE_L, 0.0, 1.0)


func abastecer(litros: float) -> void:
	combustivel_l = minf(combustivel_l + maxf(litros, 0.0), TANQUE_L)


func marcha_humana() -> int:
	return marcha + 1
