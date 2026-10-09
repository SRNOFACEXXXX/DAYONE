extends Node
## Sobrevivência do jogador LOCAL (filho do Soldier): fome, sede, temperatura corporal e "molhado".
## Sem class_name de propósito (carregue com preload). Taxas em tempo REAL do jogo; `escala` acelera (testes).
##   fome: 100 -> 0 em ~90 min parado/andando; sede: 100 -> 0 em ~60 min. Correr gasta ~2,5x (sede) / ~2x (fome).
##   frio: noite, chuva, estar molhado e nadar baixam a temperatura; fogueira acesa (grupo "fogueira_acesa") aquece e seca.
## API: comer(v, cru), beber(v), aquecer(graus), secar(), estado(), frac_temp(). Sinais: aviso(texto), mudou.

signal aviso(texto: String)
signal mudou
signal consumiu(item_id: String)

const FOME_MIN := 90.0                 # minutos reais da barra cheia até zero (parado)
const SEDE_MIN := 60.0
const CORRER_FOME := 2.0
const CORRER_SEDE := 2.5
const BAIXO := 20.0                    # abaixo disso avisa e a HUD destaca
const DANO_INTERVALO := 4.0            # s por 1 ponto de vida com fome/sede zeradas (sede dói mais: x1.5)
const TEMP_NORMAL := 36.5
const TEMP_FRIO := 35.5                # abaixo: "com frio" (aviso)
const TEMP_HIPO := 34.0                # abaixo: hipotermia, tira vida
const TEMP_MIN := 31.0
const TEMP_MAX := 38.5
const TAU_TEMP := 120.0                # s para a temperatura chegar a ~63% do alvo
const RAIO_FOGUEIRA := 6.0

var soldier: Soldier
var energia := 100.0                   # fome (100 = saciado)
var hidratacao := 100.0                # sede (100 = hidratado)
var temperatura := TEMP_NORMAL
var molhado := 0.0                     # 0..1
var escala := 1.0                      # multiplicador de tempo (testes)
var perto_fogueira := false
var ambiente_c := 20.0                 # leitura da temperatura ambiente (depuração/HUD)
var isolamento := 0.0                  # 0..1 reservado para roupas (reduz o frio)

var _t_fogo := 0.0
var _dano_f := 0.0
var _dano_s := 0.0
var _dano_t := 0.0
var _avisou := {"fome": 0, "sede": 0, "frio": false}   # 0 ok, 1 baixo, 2 zerado
var _emit_acc := 0.0


func setup(s: Soldier) -> void:
	soldier = s
	name = "Sobrevivencia"
	s.add_child(self)


func _physics_process(dt: float) -> void:
	if soldier == null or not soldier.alive:
		return
	dt *= escala
	var correndo := soldier.is_sprinting and soldier.horizontal_speed() > 1.0
	energia = maxf(0.0, energia - dt * (100.0 / (FOME_MIN * 60.0)) * (CORRER_FOME if correndo else 1.0))
	hidratacao = maxf(0.0, hidratacao - dt * (100.0 / (SEDE_MIN * 60.0)) * (CORRER_SEDE if correndo else 1.0))
	_ambiente(dt, correndo)
	_dano(dt)
	_avisos()
	_emit_acc += dt
	if _emit_acc >= 1.0:
		_emit_acc = 0.0
		mudou.emit()


func _ambiente(dt: float, correndo: bool) -> void:
	_t_fogo -= dt
	if _t_fogo <= 0.0:
		_t_fogo = 0.5
		perto_fogueira = false
		for f in get_tree().get_nodes_in_group("fogueira_acesa"):
			if f is Node3D and (f as Node3D).global_position.distance_to(soldier.global_position) <= RAIO_FOGUEIRA:
				perto_fogueira = true
				break
	var luz := clampf((Clima.elevacao_sol + 5.0) / 25.0, 0.0, 1.0)
	var chuva := 0.0 if Clima.coberto else clampf(Clima.chuva, 0.0, 1.0)
	var na_agua: bool = soldier.nadando
	# molhado: chuva e água molham; sol e fogueira secam
	if na_agua:
		molhado = minf(1.0, molhado + dt / 6.0)
	elif chuva > 0.05:
		molhado = minf(1.0, molhado + dt * chuva / 90.0)
	else:
		molhado = maxf(0.0, molhado - dt / (240.0 if not perto_fogueira else 25.0) * (1.0 + luz * 0.5))
	if perto_fogueira and chuva <= 0.05:
		molhado = maxf(0.0, molhado - dt / 25.0)
	# temperatura ambiente efetiva (graus C "sentidos") e alvo do corpo
	ambiente_c = lerp(9.0, 24.0, luz) - chuva * 6.0 - molhado * 6.0
	if na_agua:
		ambiente_c = 3.0
	if perto_fogueira:
		ambiente_c += 20.0
	var frio_sentido := ambiente_c - 16.0
	frio_sentido *= (1.0 - isolamento) if frio_sentido < 0.0 else 1.0
	var alvo := TEMP_NORMAL + clampf(frio_sentido * 0.15, -5.0, 1.2) + (0.4 if correndo else 0.0)
	if energia <= 0.0:
		alvo -= 0.8   # sem comida o corpo esfria mais fácil
	temperatura = clampf(temperatura + (alvo - temperatura) * (1.0 - exp(-dt / TAU_TEMP)), TEMP_MIN, TEMP_MAX)


func _dano(dt: float) -> void:
	_dano_f = _acumula(_dano_f, dt, energia <= 0.0, DANO_INTERVALO)
	_dano_s = _acumula(_dano_s, dt, hidratacao <= 0.0, DANO_INTERVALO / 1.5)
	var hipo := temperatura < TEMP_HIPO
	_dano_t = _acumula(_dano_t, dt, hipo, DANO_INTERVALO if temperatura >= TEMP_HIPO - 1.0 else DANO_INTERVALO / 2.0)


func _acumula(acc: float, dt: float, ativo: bool, intervalo: float) -> float:
	if not ativo:
		return 0.0
	acc += dt
	while acc >= intervalo and soldier.alive:
		acc -= intervalo
		soldier.take_damage(1.0, null, null, "legs", Vector3.UP)
	return acc


func _avisos() -> void:
	_checa("fome", energia, "Você está com fome", "Você está faminto - coma algo", "Está morrendo de fome!")
	_checa("sede", hidratacao, "Você está com sede", "Você está desidratado - beba água", "Está morrendo de sede!")
	var frio := temperatura < TEMP_FRIO
	if frio and not _avisou["frio"]:
		_avisou["frio"] = true
		aviso.emit("Você está com frio - procure uma fogueira ou abrigo" if temperatura >= TEMP_HIPO else "Hipotermia! Aqueça-se agora")
	elif not frio and temperatura > TEMP_FRIO + 0.4:
		_avisou["frio"] = false


func _checa(chave: String, v: float, msg_baixo: String, _msg_critico: String, msg_zero: String) -> void:
	var nivel: int = _avisou[chave]
	if v <= 0.0 and nivel < 2:
		_avisou[chave] = 2
		aviso.emit(msg_zero)
	elif v > 0.0 and v < BAIXO and nivel == 0:
		_avisou[chave] = 1
		aviso.emit(msg_baixo)
	elif v > BAIXO + 5.0:
		_avisou[chave] = 0


# ------------------------------------------------------------------ API
func comer(valor: float, cru := false) -> void:
	energia = clampf(energia + valor, 0.0, 100.0)
	if cru:
		aviso.emit("Carne crua... pode fazer mal. Cozinhe na fogueira.")
	mudou.emit()


func beber(valor: float) -> void:
	hidratacao = clampf(hidratacao + valor, 0.0, 100.0)
	mudou.emit()


## Aquece (ou esfria, se negativo) o corpo em `graus` °C de uma vez (fogueira própria, roupa, bebida quente).
func aquecer(graus: float) -> void:
	temperatura = clampf(temperatura + graus, TEMP_MIN, TEMP_MAX)
	mudou.emit()


func secar() -> void:
	molhado = 0.0


## 0..1 para a HUD: 0 = congelando (TEMP_MIN), 1 = normal ou mais.
func frac_temp() -> float:
	return clampf((temperatura - TEMP_MIN - 1.0) / (TEMP_NORMAL - TEMP_MIN - 1.0), 0.0, 1.0)


## Consome o efeito de um item (kind comida/bebida): usado por Soldier ao terminar o tempo de uso.
func consumir_item(item_id: String) -> void:
	var def := BRInventory.definition(item_id)
	var agua := float(def.get("agua", 0.0))
	var en := float(def.get("energia", 0.0))
	if en != 0.0 or bool(def.get("cru", false)):
		comer(en, bool(def.get("cru", false)))
	if agua != 0.0:
		beber(agua)
	consumiu.emit(item_id)


## O item ainda ajuda? (false se tudo que ele daria já está no máximo)
func precisa(item_id: String) -> bool:
	var def := BRInventory.definition(item_id)
	return (float(def.get("energia", 0.0)) > 0.0 and energia < 99.5) or (float(def.get("agua", 0.0)) > 0.0 and hidratacao < 99.5)


func estado() -> Dictionary:
	return {"energia": energia, "hidratacao": hidratacao, "temperatura": temperatura, "molhado": molhado,
		"perto_fogueira": perto_fogueira, "ambiente_c": ambiente_c, "com_frio": temperatura < TEMP_FRIO,
		"fome": energia < BAIXO, "sede": hidratacao < BAIXO}
