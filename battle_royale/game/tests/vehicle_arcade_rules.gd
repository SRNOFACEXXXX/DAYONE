extends Node
## Regras puras da dirigibilidade (core/veiculo_powertrain.gd e core/veiculo_estabilidade.gd):
## marchas e RPM, curva de torque, consumo, direção por velocidade, aderência por superfície,
## dano por batida e limiar de fumaça. Não carrega o mapa: roda em segundos.

const Transmissao = preload("res://core/veiculo_powertrain.gd")
const Estab = preload("res://core/veiculo_estabilidade.gd")

var failures := 0


func check(ok: bool, label: String) -> void:
	print("VEHICLE_CHECK ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _ready() -> void:
	_check_direcao()
	_check_superficies()
	_check_dano_e_fumaca()
	_check_colisao()
	_check_transmissao()
	_check_combustivel()
	print("VEHICLE_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _check_direcao() -> void:
	check(is_equal_approx(Estab.fator_direcao(0.0), 1.0), "direcao plena parado")
	check(is_equal_approx(Estab.fator_direcao(120.0), Estab.FATOR_DIRECAO_ALTA), "direcao minima em alta")
	check(Estab.fator_direcao(30.0) > Estab.fator_direcao(60.0), "esterço diminui com a velocidade")
	check(Estab.taxa_direcao(1.0, 0.0) > Estab.taxa_direcao(1.0, 120.0), "volante gira mais rapido em baixa")
	check(Estab.taxa_direcao(0.0, 0.0) > 0.0 and Estab.taxa_direcao(0.0, 120.0) > 0.0, "volante volta ao centro em qualquer velocidade")
	check(Estab.taxa_direcao(0.0, 0.0) < 3.0, "retorno ao centro nao e snap instantaneo")


func _check_superficies() -> void:
	var asf := Estab.perfil_superficie("asfalto")
	var areia := Estab.perfil_superficie("areia")
	var agua := Estab.perfil_superficie("agua")
	var grama := Estab.perfil_superficie("grama")
	check(areia.x < asf.x and areia.y < asf.y, "areia reduz aderencia e tracao")
	check(agua.x < grama.x, "agua reduz mais que grama")
	check(Estab.perfil_superficie("desconhecida") == Vector2.ONE, "superficie desconhecida mantem asfalto")
	check(Estab.perfil_superficie("sand") == areia, "alias ingles para areia")


func _check_dano_e_fumaca() -> void:
	check(Estab.dano_impacto(5.0, 7.5, 2.6) == 0.0, "batida leve nao causa dano")
	check(absf(Estab.dano_impacto(20.0, 7.5, 2.6) - 32.5) < 0.01, "batida de 20 m/s causa 32,5% (fator 2,6)")
	check(Estab.dano_impacto(30.0, 7.5, 2.6) > Estab.dano_impacto(15.0, 7.5, 2.6), "dano cresce com a velocidade do impacto")
	check(not Estab.fumaca_ligada(0.31), "sem fumaca acima de 30% de vida")
	check(Estab.fumaca_ligada(0.29), "fumaca abaixo de 30% de vida")
	check(is_equal_approx(Estab.intensidade_fumaca(0.3), 0.0), "intensidade zero no limiar")
	check(is_equal_approx(Estab.intensidade_fumaca(0.0), 1.0), "intensidade maxima com vida zero")
	check(Estab.esta_capotado(0.1) and not Estab.esta_capotado(0.9), "capotado detectado pelo eixo para cima")


func _check_colisao() -> void:
	check(Estab.e_terreno("TerrenoColisao"), "colisor do terreno e reconhecido")
	check(not Estab.e_terreno("Casa_01"), "casa nao e terreno")
	check(Estab.dano_colisao(Vector3(0, -14, 0), 9.0, 2.6) == 0.0, "quicada vertical de 14 m/s nao causa dano")
	check(Estab.dano_colisao(Vector3(8.9, 0, 0), 9.0, 2.6) == 0.0, "batida abaixo de 9 m/s nao causa dano")
	check(absf(Estab.dano_colisao(Vector3(0, 0, 19), 9.0, 2.6) - 26.0) < 0.01, "batida frontal de 19 m/s causa 26%")
	check(Estab.dano_colisao(Vector3(3, -2, 14), 9.0, 2.6) > 0.0, "batida lateral com pequena quicada ainda conta")


func _check_transmissao() -> void:
	var t = Transmissao.new()
	check(absf(t.torque_norm(850.0) - 0.55) < 0.001, "torque em marcha lenta 0,55")
	check(absf(t.torque_norm(3800.0) - 1.0) < 0.001, "torque maximo em 3800 rpm")
	check(absf(t.torque_norm(9000.0) - 0.72) < 0.001, "torque acima do limite fica na ultima faixa")
	var rpm_27 := float(t.rpm_da_velocidade(27.0, 4))
	check(rpm_27 > 3200.0 and rpm_27 < 3500.0, "5a marcha a 27 m/s ~3340 rpm (%.0f)" % rpm_27)
	# Arranque e aceleração até a velocidade máxima: sobe marchas, RPM dentro da faixa.
	var v := 0.0
	var marcha_max := 0
	var rpm_max := 0.0
	for _i in 1200:
		v = minf(v + 2.7 / 60.0, 27.0)
		t.atualizar(1.0 / 60.0, v, 1.0, true)
		marcha_max = maxi(marcha_max, t.marcha)
		rpm_max = maxf(rpm_max, t.rpm)
	check(marcha_max == 3, "aceleracao sobe ate a 4a marcha (indice %d)" % marcha_max)
	check(rpm_max <= Transmissao.RPM_LIMITE + 1.0, "RPM nao passa do limite (%.0f)" % rpm_max)
	check(t.fator_torque() > 0.0 and t.rpm_norm() > 0.0, "torque e RPM validos em velocidade maxima")
	# Desaceleração: reduz marchas até a 1a.
	for _i in 600:
		v = maxf(v - 3.0 / 60.0, 0.0)
		t.atualizar(1.0 / 60.0, v, 0.0, true)
	check(t.marcha == 0, "desaceleracao reduz ate a 1a marcha")
	# Motor desligado: RPM cai a zero.
	for _i in 120:
		t.atualizar(1.0 / 60.0, 0.0, 0.0, false)
	check(t.rpm < 1.0, "motor desligado zera o RPM")


func _check_combustivel() -> void:
	var t = Transmissao.new()
	t.combustivel_l = 1.0
	for _i in 3600:
		t.consumir(1.0 / 60.0, 1.0)
	check(t.combustivel_l < 1.0 and t.combustivel_l > 0.8, "consumo parcial em 60 s (%.3f L)" % t.combustivel_l)
	t.combustivel_l = 0.0
	check(not t.tem_combustivel(), "sem combustivel o motor nao liga")
	t.abastecer(1000.0)
	check(is_equal_approx(t.fracao_combustivel(), 1.0), "abastecer limita ao tanque")
