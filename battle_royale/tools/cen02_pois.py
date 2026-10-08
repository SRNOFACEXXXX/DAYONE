# -*- coding: utf-8 -*-
"""Passe 02 nos demais POIs: Usina, Quartel, Pedreira, Pista, Farol, Represa, Praia, Vila (margens/praia) e praça do Cruzeiro.
Tudo à mão; o que é relativo a um prédio usa o referencial dele (porta na face -Y local)."""
from cenario_02_src import *


def montar():
    # ------------------------------------------------------------ USINA
    area("Usina Santa Cruz: vila operária e pátio",
         "Quem trabalhava na usina deixou rastro: varal e bicicleta na vila operária, barris de melaço na moenda, tijolos "
         "da chaminé que desabou, tambores vazando junto ao tanque e o posto de guarda com barreiras no acostamento.")
    for bid, s in (("usina_santa_cruz_07", 1), ("usina_santa_cruz_08", 1), ("usina_santa_cruz_09", 1)):
        c = B(bid)
        # duas casas lado a lado (duas portas, a 6,5 m do centro): bicicleta e lixeira nas pontas da fachada, barril entre as portas
        c.p("bicicleta", -10.0 * s, c.yf(1.8), 100)
        c.p("barril", 0.0, c.yf(1.5))
        c.p("lixeira", 10.0 * s, c.yf(1.8), 0)
        c.p("varal", -2.0 * s, c.yb(2.4), 0)
        N("tufo_capim", *c.W(8.0 * s, c.yb(1.4)), c.rot)
    c = B("usina_santa_cruz_01")                      # casa da moenda
    N("pilha_troncos", *c.W(-5.0, c.yf(3.4)), c.rot + 90)
    N("pilha_troncos", *c.W(5.2, c.yf(3.8)), c.rot + 80)
    c.p("barril", -2.8, c.yf(2.0))
    c.p("barril", -3.9, c.yf(2.6))
    c.p("carrinho_mao", 3.3, c.yf(2.2), 70)
    c = B("usina_santa_cruz_02")                      # chaminé: tijolos do coroamento caído
    N("entulho", *c.W(3.8, -1.0), 20)
    N("entulho", *c.W(-3.6, 2.4), 110)
    c.p("pilha_tijolo", 4.2, 3.4, 30)
    c.p("pilha_tijolo", -4.0, -3.0, 80)
    c = B("usina_santa_cruz_11")                      # tanque
    c.p("tambor", c.xr(1.6), c.yf(1.2))
    c.p("tambor", c.xr(1.6), c.yf(2.4))
    c.p("tambor", c.xl(1.6), c.yb(1.4))
    N("entulho", *c.W(c.xl(2.4), c.yf(1.6)), 15)
    c = B("usina_santa_cruz_06")                      # escritório
    c.p("mesa_bar_cadeiras", c.xr(2.6), c.yf(2.2), 15)
    c.p("banco_praca", c.xl(2.4), c.yf(1.6), 0)
    N("arvore_d", *c.W(c.xr(4.0), c.yb(2.0)), 0)
    # posto de guarda: barreiras no acostamento (a via fica livre)
    U("road_barrier_01", -226.0, 256.5, 70)
    U("road_barrier_01", -218.0, 247.0, 20)
    U("roadcone_01", -224.0, 261.0, 0)
    U("roadcone_01", -217.0, 258.0, 0)

    # ------------------------------------------------------------ QUARTEL
    area("Quartel do 7º BIL: rancho, paiol e heliponto",
         "A vida do pátio militar: mesas do rancho ao ar livre, caixas de rancho empilhadas, tambores alinhados no paiol, "
         "bancos na frente do comando e cones demarcando o heliponto.")
    c = B("quartel_04")                               # refeitório
    c.p("mesa_bar_cadeiras", -7.0, c.yf(3.0), 0)
    c.p("mesa_bar_cadeiras", 7.0, c.yf(3.0), 20)
    c.p("mesa_bar_cadeiras", -7.0, c.yf(6.2), 0)
    U("box_01", *c.W(-4.6, c.yf(1.4)), c.rot + 15)
    U("box_02", *c.W(-5.6, c.yf(1.6)), c.rot + 340)
    U("box_01", *c.W(4.6, c.yf(1.4)), c.rot + 350)
    c = B("quartel_01")                               # comando
    c.p("banco_praca", -5.0, c.yf(2.0), 0)
    c.p("banco_praca", 5.0, c.yf(2.0), 0)
    N("arbusto_a", *c.W(-8.4, c.yf(1.2)), 0)
    N("arbusto_b", *c.W(8.4, c.yf(1.2)), 0)
    c.p("lixeira", 8.0, c.yf(2.6), 0)
    c = B("quartel_06")                               # paiol
    for i in range(4):
        c.p("tambor", c.xr(1.6), c.yf(0.8 + 1.2 * i), 0)
    c.p("barril", c.xl(1.6), c.yf(1.2))
    c.p("pilha_tijolo", c.xl(1.6), c.yf(3.0), 0)
    c = B("quartel_05")                               # garagem
    c.p("tambor", c.xr(1.6), c.yf(1.2))
    c.p("tambor", c.xr(1.6), c.yf(2.3))
    c.p("tambor", c.xr(2.7), c.yf(1.2))
    N("entulho", *c.W(c.xl(2.2), c.yf(2.0)), 70)
    c = B("quartel_02")                               # alojamento oeste (porta a leste, sobre o pátio): o banco e a lixeira do pacote antigo já estão lá
    c.p("tambor", 6.0, c.yf(1.4))
    c = B("quartel_03")                               # alojamento leste
    c.p("barril", 6.0, c.yf(1.4))
    for (x, y) in ((382.0, 325.0), (402.0, 325.0), (382.0, 345.0), (402.0, 345.0)):   # cantos do heliponto
        U("roadcone_01", x, y, 0)
    N("arvore_d", 296.0, 238.0, 0)
    N("pinheiro_medio", 372.0, 368.0, 0)
    N("pinheiro_medio", 236.0, 368.0, 0)

    # ------------------------------------------------------------ PEDREIRA
    area("Pedreira São Jorge: cava e britador",
         "A cava ganha cones na borda, a pilha de brita sob o britador, tambores de óleo no galpão e um canto de lanche "
         "dos operários nos contêineres.")
    c = B("pedreira_01")                              # britador
    R("pedra_03", *c.W(5.0, c.yf(4.0)), 0, 1.0)
    R("pedra_04", *c.W(-3.0, c.yf(5.4)), 90, 1.0)
    N("monte_terra", *c.W(2.0, c.yf(3.2)), c.rot + 90)
    N("monte_terra", *c.W(-6.0, c.yf(3.0)), c.rot + 20)
    c = B("pedreira_05")                              # galpão
    c.p("tambor", c.xr(1.6), c.yf(1.2))
    c.p("tambor", c.xr(1.6), c.yf(2.4))
    c.p("tambor", c.xr(2.8), c.yf(1.8))
    c.p("pilha_tijolo", c.xl(2.0), c.yf(1.6), 20)
    c = B("pedreira_03")                              # contêineres: canto do lanche
    c.p("mesa_bar_cadeiras", c.xl(2.6), c.yf(1.4), 0)
    c.p("banco_praca", c.xr(2.4), c.yf(1.6), 90)
    c.p("lixeira", c.xr(2.0), c.yb(1.0), 0)
    c = B("pedreira_06")                              # paiol de explosivos
    U("road_barrier_02", *c.W(0, c.yf(4.5)), c.rot)
    U("roadcone_02", *c.W(-3.0, c.yf(4.5)), 0)
    U("roadcone_02", *c.W(3.0, c.yf(4.5)), 0)
    for (x, y) in ((320.0, 12.0), (331.0, 15.5), (346.0, 15.0)):                     # borda norte da cava
        U("roadcone_01", x, y, 0)
    R("pedra_05", 305.0, 2.0, 40)
    R("pedra_03", 312.0, -30.0, 100)

    # ------------------------------------------------------------ PISTA
    area("Pista do Tauá: balizamento e hangar",
         "A pista tem balizas na borda sul, o hangar tem tambores de combustível alinhados e a casa do piloto, lenha e bicicleta.")
    c = B("pista_pouso_01")                           # hangar
    for i in range(4):
        c.p("tambor", c.xl(1.8), c.yf(1.0 + 1.2 * i), 0)
    c.p("barril", c.xr(1.8), c.yf(1.6))
    U("box_01", *c.W(c.xr(1.8), c.yf(3.0)), c.rot + 20)
    c = B("pista_pouso_03")                           # casa do piloto
    N("lenha", *c.W(c.xr(1.4), c.yb(1.0)), c.rot)
    N("lenha", *c.W(c.xr(1.4), c.yb(1.7)), c.rot + 30)
    c.p("bicicleta", c.xl(1.4), c.yf(1.8), 100)
    c = B("pista_pouso_04")                           # tanque
    c.p("tambor", c.xl(1.6), c.yf(1.4))
    c.p("tambor", c.xl(1.6), c.yf(2.5))
    # balizas na borda sul da pista (eixo de (200,-340) a (470,-270), 12,5 m de meia largura; 14,5 m de afastamento)
    for (x, y) in ((228.0, -361.0), (268.0, -350.7), (308.0, -340.4), (348.0, -330.0), (388.0, -319.7), (428.0, -309.4)):
        U("roadcone_02", x, y, 0)

    # ------------------------------------------------------------ FAROL
    area("Farol da Ponta Norte: vigia e ventania",
         "O faroleiro vive de lenha, barril e vento: banco de olhar o mar, varal no fundo da casa, tambores do gerador.")
    c = B("farol_ponta_norte_02")                     # casa do faroleiro
    c.p("varal", -3.0, c.yb(2.4), 0)
    N("lenha", *c.W(c.xr(1.4), c.yb(1.0)), c.rot)
    N("lenha", *c.W(c.xr(1.4), c.yb(1.7)), c.rot + 30)
    c.p("barril", c.xl(1.4), c.yf(1.4))
    c.p("bicicleta", c.xr(1.8), c.yf(1.8), 100)
    c = B("farol_ponta_norte_03")                     # gerador
    c.p("tambor", c.xr(1.4), c.yf(1.2))
    c.p("tambor", c.xr(1.4), c.yf(2.3))
    c.p("tambor", c.xl(1.4), c.yb(1.2))
    D("banco_praca", 62.0, 522.0, 0)
    D("banco_praca", 86.0, 520.0, 0)
    N("arbusto_a", 56.0, 521.0, 0)
    N("arbusto_b", 92.0, 518.0, 40)
    N("tufo_capim", 70.0, 524.0, 0)

    # ------------------------------------------------------------ REPRESA
    area("Represa do Tauá: casa de força e subestação",
         "Área pequena de propósito (a vista da barragem é a mais pesada): tambores na subestação, barris na casa de força, "
         "banco do operador de frente para o remanso.")
    c = B("represa_03")                               # subestação
    c.p("tambor", c.xr(1.6), c.yf(1.2))
    c.p("tambor", c.xr(1.6), c.yf(2.3))
    U("box_01", *c.W(c.xl(1.8), c.yf(1.6)), c.rot + 30)
    c = B("represa_01")                               # casa de força
    c.p("barril", c.xl(2.0), c.yf(1.5))
    c.p("barril", c.xl(2.0), c.yf(2.6))
    c.p("lixeira", c.xr(2.0), c.yf(2.0), 0)
    c = B("represa_02")                               # casa do operador
    c.p("banco_praca", c.xl(2.4), c.yf(1.6), 0)
    N("arbusto_a", *c.W(c.xl(1.8), c.yf(2.4)), 0)

    # ------------------------------------------------------------ PRAIA
    area("Praia dos Quiosques: mesas e redes",
         "Cada quiosque estende o seu varejo pela areia: mesas do lado de fora, caixotes de peixe e barris na parte de trás, "
         "canoas arrastadas ao pé da maré, bancos e lixeiras na orla.")
    for i, x in enumerate((30, 65, 100, 135, 170)):
        c = B("praia_quiosques_0%d" % (i + 1))       # as mesas do pacote antigo já estão nas portas: aqui entram caixotes e lixeira
        c.p("caixote_peixe", 6.6, c.yf(1.5), 90)
        c.p("caixote_peixe", 6.6, c.yf(2.6), 80 if i % 2 else 100)
        U("trash_bin" if i % 2 else "bin", *c.W(-6.4, c.yf(2.0)), 0)
        c.p("barril", -3.4, c.yb(1.4))
    c = B("praia_quiosques_07")                       # restaurante
    c.p("mesa_bar_cadeiras", -4.6, c.yf(4.6), 0)
    c.p("mesa_bar_cadeiras", 4.6, c.yf(4.6), 25)
    c.p("mesa_bar_cadeiras", 8.8, c.yf(2.6), 0)
    c.p("lixeira", 7.0, c.yf(4.4), 0)
    D("banco_praca", 82.0, -468.0, 0)
    D("banco_praca", 118.0, -468.0, 0)
    D("lixeira", 100.0, -468.5, 0)
    D("canoa_praia", 48.0, -499.0, 4)
    D("canoa_praia", 118.0, -500.0, 356)
    c = B("praia_quiosques_08")                       # posto salva-vidas
    c.p("canoa_praia", 4.4, c.yf(1.0), 0)
    c.p("barril", -2.4, c.yf(1.4))


montar()
