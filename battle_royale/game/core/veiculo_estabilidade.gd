extends RefCounted
## Regras de direção, aderência por superfície, dano por impacto e fumaça do sedã.
## Funções estáticas puras (sem estado). Carregado por preload em drivable_vehicle.gd;
## testado em tests/vehicle_arcade_rules.gd.

const DIRECAO_PLENA_KMH := 8.0
const DIRECAO_MINIMA_KMH := 70.0
const FATOR_DIRECAO_ALTA := 0.24
const LIMIAR_FUMACA := 0.30

## Perfil por superfície: [aderência lateral, tração]. Nome desconhecido = asfalto (1, 1),
## o mesmo comportamento de antes para estradas e chão sem tag.
const SUPERFICIES := {
	"asfalto": [1.0, 1.0],
	"concreto": [1.0, 1.0],
	"madeira": [0.92, 0.95],
	"terra": [0.80, 0.85],
	"grama": [0.72, 0.80],
	"areia": [0.55, 0.60],
	"sand": [0.55, 0.60],
	"agua": [0.45, 0.50],
	"water": [0.45, 0.50],
}


## Multiplicador do esterço máximo: 1,0 parado e 0,24 a partir de 70 km/h.
static func fator_direcao(kmh: float) -> float:
	return lerpf(1.0, FATOR_DIRECAO_ALTA, smoothstep(DIRECAO_PLENA_KMH, DIRECAO_MINIMA_KMH, kmh))


## Velocidade (rad/s) com que o volante se move. Girar é mais lento que voltar ao centro,
## e os dois ficam mais suaves em alta velocidade.
static func taxa_direcao(virando: float, kmh: float) -> float:
	var t := clampf(kmh / 120.0, 0.0, 1.0)
	if absf(virando) > 0.05:
		return lerpf(2.6, 1.6, t)
	return lerpf(2.0, 1.3, t)


## Vector2(aderência lateral, tração) da superfície.
static func perfil_superficie(nome: String) -> Vector2:
	if SUPERFICIES.has(nome):
		var p: Array = SUPERFICIES[nome]
		return Vector2(float(p[0]), float(p[1]))
	return Vector2.ONE


## Dano (% da vida) de uma batida com variação de velocidade dv (m/s). Zero abaixo do limiar.
static func dano_impacto(variacao_mps: float, limiar_mps: float, fator_por_mps: float) -> float:
	return maxf(variacao_mps - limiar_mps, 0.0) * fator_por_mps


## Colisor do terreno da ilha (maps/ilha/terrain.gd cria "TerrenoColisao"). Contato com ele é relevo, não batida.
static func e_terreno(nome_no: String) -> bool:
	return nome_no.begins_with("TerrenoColisao")


## Dano de colisão a partir da variação de velocidade do carro (vetor, m/s). Quicada vertical (chão, buraco,
## queda) não conta: só a parte horizontal (lateral/frontal) da variação. Abaixo do limiar = 0.
static func dano_colisao(dv: Vector3, limiar_mps: float, fator_por_mps: float) -> float:
	var horizontal := Vector2(dv.x, dv.z).length()
	if horizontal < absf(dv.y):
		return 0.0
	return dano_impacto(horizontal, limiar_mps, fator_por_mps)


## Fumaça do motor aparece abaixo de 30% de vida.
static func fumaca_ligada(vida_frac: float) -> bool:
	return vida_frac < LIMIAR_FUMACA


## 0 acima de 30% de vida, subindo até 1 com a vida zerada.
static func intensidade_fumaca(vida_frac: float) -> float:
	return clampf((LIMIAR_FUMACA - vida_frac) / LIMIAR_FUMACA, 0.0, 1.0)


## produto escalar entre o eixo "cima" do carro e Vector3.UP; abaixo de 0,25 o carro está capotado.
static func esta_capotado(produto_cima: float) -> bool:
	return produto_cima < 0.25
