# -*- coding: utf-8 -*-
"""Campo aberto: sítios com história escolhidos nos vazios do mapa (sem mata, sem estrada, sem prédio num raio de 14 m),
árvores e pedras isoladas como cobertura natural, margem do rio e praça do Cruzeiro."""
from cenario_02_src import *


def montar():
    area("Campo aberto: sítios e vestígios",
         "Os vazios do mapa ganham motivo para parar: acampamento largado, curral em ruína, capoeira queimada, bosquete de "
         "pinheiros, naufrágio na praia, pedras do planalto. Cada sítio tem 5 a 8 peças e uma cena que se lê de longe.")
    # S1: acampamento abandonado, fogueira com toras de sentar
    N("fogueira", -170.0, 60.0, 0)
    N("toco", -172.3, 60.2, 0)
    N("toco", -168.0, 62.0, 90)
    N("toco", -168.6, 57.8, 200)
    N("tronco_caido", -164.0, 64.5, 20)
    D("caixote_peixe", -174.4, 56.4, 30)
    D("barril", -175.6, 57.8)
    D("lona_barraca", -177.0, 63.0, 20)      # a lona de 2,5 m aparece por cima do capim
    # S2: pasto com árvore de sombra
    N("carvalho", 150.0, 50.0, 30)
    R("pedra_03", 157.0, 46.0, 20)
    N("rocha_media", 143.5, 45.0, 100)
    N("toco_baixo", 153.5, 57.0, 60)
    N("tronco_caido", 142.5, 54.0, 160)
    # S3: curral de pedra em ruína ao norte do planalto
    N("muro_ruina", -44.0, 378.0, 0)
    N("muro_ruina", -39.0, 374.0, 90)
    N("muro_ruina", -44.0, 370.0, 0)
    N("entulho", -45.0, 374.2, 70)
    N("entulho", -36.5, 382.0, 150)
    N("arvore_seca", -34.0, 369.0, 40)
    N("toco_baixo", -49.5, 383.0, 0)
    # S4: capoeira queimada no leste
    N("arvore_seca", 296.0, -126.0, 10)
    N("arvore_seca", 306.0, -133.0, 100)
    N("arvore_seca", 312.0, -122.0, 200)
    N("arvore_seca_p", 301.0, -137.0, 0)
    N("arvore_seca_p", 316.0, -129.0, 130)
    N("tronco_caido", 304.0, -124.0, 30)
    N("tronco_caido", 311.0, -139.0, 100)
    R("pedra_04", 298.0, -131.0, 45)
    # S5: bosquete de sombra no pasto do sul
    N("carvalho", 80.0, -290.0, 0)
    N("carvalho", 94.0, -297.0, 140)
    N("arvore_d", 70.0, -298.0, 70)
    N("rocha_grande", 86.0, -283.0, 20)
    R("pedra_03", 101.0, -286.0, 80)
    # S6: barraca de pescador na costa oeste
    D("canoa_praia", -452.0, 12.0, 80)
    N("fogueira", -446.0, 8.0, 0)
    N("toco", -448.0, 5.8, 0)
    N("toco", -443.8, 9.5, 120)
    D("caixote_peixe", -456.0, 17.0, 60)
    D("barril", -457.4, 15.6)
    D("lona_barraca", -453.0, 3.0, 100)
    # S7: bosque de pinheiros jovens no norte
    for i, (x, y) in enumerate(((180, 415), (186, 420), (192, 412), (198, 421), (205, 414), (212, 419))):
        N("pinheiro_jovem" if i % 3 else "pinheiro_medio", x, y, 50 * i)
    R("pedra_05", 190.0, 426.0, 0)
    # S8: pedras do planalto
    N("rocha_grande", 60.0, -180.0, 10)
    N("rocha_media", 63.5, -183.0, 90)
    R("pedra_04", 56.0, -176.0, 60)
    R("pedra_09", 65.0, -176.0, 0)
    R("pedra_05", 58.0, -185.0, 120)
    # S9: naufrágio no litoral sudeste
    D("canoa_praia", 340.0, -362.0, 15)
    D("canoa_praia", 362.0, -358.0, 160)
    N("tronco_caido", 350.0, -366.0, 40)
    N("raiz", 354.0, -360.0, 70)
    N("raiz", 346.0, -356.0, 200)
    N("galho", 358.0, -364.0, 10)
    N("arvore_seca_p", 344.0, -368.0, 30)
    N("arvore_seca_p", 357.0, -354.0, 200)
    # S10: obra abandonada a oeste do planalto
    N("muro_ruina", -258.0, 196.0, 10)
    N("muro_ruina", -252.0, 190.0, 100)
    N("entulho", -254.0, 194.0, 30)
    N("entulho", -262.0, 190.0, 120)
    D("pilha_tijolo", -246.0, 197.0, 10)
    D("pilha_tijolo", -248.5, 186.0, 80)
    N("monte_terra", -264.0, 200.0, 90)
    N("arvore_seca", -266.0, 188.0, 0)
    # S11: árvores e pedras isoladas, cobertura natural no campo
    for (t, x, y, r) in (("carvalho", -200, 20, 0), ("arvore_d", -140, 80, 90), ("arvore_d", 100, 20, 180), ("carvalho", 208, -12, 40),
                         ("arvore_seca", -20, -200, 0), ("carvalho", 20, -280, 120), ("arvore_d", -280, -90, 60), ("arvore_seca", 360, -110, 150),
                         ("betula", -100, 420, 20), ("arvore_b", 130, -340, 100)):
        N(t, x, y, r)
    R("pedra_03", -197.0, 17.0, 30)
    R("pedra_04", 211.0, -15.0, 100)
    N("rocha_grande", -17.0, -203.0, 0)
    N("rocha_media", 133.0, -337.0, 70)

    area("Carros abandonados nas estradas",
         "Quatro carros largados no acostamento, a mais de 60 m de qualquer outro carro e fora da faixa de rodagem: o sedã do "
         "morador que não subiu o morro (E8), o táxi que quebrou na subida do quartel (E5), a viatura parada na reta da costa oeste (E9) "
         "e o sedã da subida do leste (E4). Todos paralelos à estrada, no mesmo sentido do eixo.")
    Car("sedan", -399.5, 100.0, 352.9)
    Car("taxi", 414.0, 111.4, 194.0)
    Car("policia", -406.0, -114.9, 341.6)
    Car("sedan", 420.3, -114.5, 188.1)

    area("Margens do rio e praça do Cruzeiro",
         "Samambaias, arbustos e pedras na margem do Rio Tauá no trecho aberto (1,5 m além da borda d'água) e um canteiro "
         "de arbustos em volta do cruzeiro, com duas pedras de sentar.")
    ao_longo((-200, -170), (-250, -210), 18.0, 7.0, 1, ["samambaia_a", "arbusto_b", "rocha_media", "samambaia_b"], ini=6, fim=34)
    ao_longo((-250, -210), (-300, -260), 18.0, 7.0, -1, ["samambaia_b", "arbusto_a", "samambaia_a", "rocha_media"], ini=8, fim=64)
    for i, (x, y) in enumerate(((-313, 62), (-316.5, 68), (-323.5, 68), (-327, 62), (-323.5, 56), (-316.5, 56))):
        N("arbusto_a" if i % 2 == 0 else "arbusto_b", x, y, 60 * i)
    R("pedra_05", -304.0, 56.0, 20)
    R("pedra_03", -331.0, 53.0, 100)


montar()
