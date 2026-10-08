# -*- coding: utf-8 -*-
"""Vila Caiçara, passe 02: um quintal por casa, cada um com a sua história (coordenadas locais ao prédio).
Cada kit recebe s = +1/-1 para espelhar o agrupamento principal (lado direito/esquerdo da casa), decidido casa a casa."""
from cenario_02_src import *


def kit_pescador(c, s=1):
    # canoa virada no fundo do quintal, caixotes e barris de quem vive do mar
    D("canoa_praia", *c.W(-2.2 * s, c.yb(3.6)), c.rot)
    c.p("barril", c.xs(s, 1.5), c.yb(0.9))
    c.p("caixote_peixe", c.xs(-s, 1.6), c.yf(1.4), 20)
    c.p("caixote_peixe", c.xs(-s, 1.6), c.yf(2.6), -10)


def kit_lavadeira(c, s=1):
    # varal nos fundos, lenha empilhada, carrinho de mão encostado e a bicicleta da filha
    c.p("varal", -2.0, c.yb(3.4), 0)
    N("lenha", *c.W(c.xs(s, 1.6), c.yb(1.0)), c.rot)
    N("lenha", *c.W(c.xs(s, 1.6), c.yb(1.7)), c.rot + 30)
    c.p("carrinho_mao", c.xs(-s, 1.8), c.yb(1.4), 70)


def kit_obra(c, s=1):
    # puxadinho em construção: tijolo, tábua, entulho, um monte de areia
    c.p("pilha_tijolo", c.xs(s, 1.8), c.yb(1.2), 10)
    N("pilha_tabuas", *c.W(c.xs(-s, 1.9), c.yb(1.4)), c.rot + 15)
    N("entulho", *c.W(c.xs(-s, 1.9), c.yf(2.0)), c.rot + 100)
    c.p("carrinho_mao", c.xs(s, 1.8), c.yf(1.8), 35)


def kit_horta(c, s=1):
    # horta e jardim cuidado: arbustos em fila, samambaia, banco de espera
    for i, lx in enumerate((-3.0, -1.0, 1.0, 3.0)):
        N("arbusto_a" if i % 2 == 0 else "arbusto_b", *c.W(lx, c.yb(3.6)), c.rot + i * 40)
    N("samambaia_a", *c.W(c.xs(s, 1.5), c.yb(1.0)), c.rot)
    c.p("banco_praca", c.xs(s, 1.7), c.yf(1.2), 90)


def kit_oficina(c, s=1):
    # mecânico de motor de popa: tambores, barril de óleo, bicicleta sem roda
    c.p("tambor", c.xs(s, 1.6), c.yb(1.0))
    c.p("tambor", c.xs(s, 1.6), c.yb(2.0))
    c.p("barril", c.xs(s, 1.6), c.yb(3.2))
    c.p("bicicleta", c.xs(-s, 1.8), c.yf(1.9), 120)
    N("entulho", *c.W(c.xs(-s, 2.2), c.yb(2.4)), c.rot + 20)


def kit_jardim(c, s=1):
    # sobrado de quem mora fora: arbustos aparados, banco, bétula e a lixeira do portão
    N("arbusto_a", *c.W(c.xs(-s, 1.3), c.yf(1.6)), c.rot)
    N("arbusto_b", *c.W(c.xs(s, 1.3), c.yf(1.6)), c.rot + 30)
    c.p("banco_praca", 0, c.yb(1.6), 0)
    N("betula", *c.W(c.xs(s, 2.6), c.yb(3.0)), c.rot)


def kit_rancho(c, s=1):
    # rancho de rede e canoa: caixotes de peixe empilhados, tambores de isca, canoa de reserva
    D("canoa_praia", *c.W(c.xs(-s, 2.3), 0), c.rot + 90)
    c.p("caixote_peixe", c.xs(s, 1.6), c.yf(0.8), 90)
    c.p("caixote_peixe", c.xs(s, 1.6), c.yf(1.9), 80)
    c.p("tambor", c.xs(s, 1.6), c.yb(1.0))


def kit_bar(c, s=1):
    # mesas no pátio do Bar do Tião, barris e o caixote de cerveja
    c.p("mesa_bar_cadeiras", c.xs(-s, 2.0), c.yf(2.4), 0)
    c.p("mesa_bar_cadeiras", c.xs(s, 2.0), c.yf(2.4), 40)
    c.p("barril", c.xs(s, 1.6), c.yb(1.0))
    c.p("caixote_peixe", c.xs(-s, 1.6), c.yb(1.2), 90)
    N("arvore_d", *c.W(c.xs(-s, 1.8), c.yb(3.6)), c.rot)


def montar():
    area("Vila: quintais",
         "Cada casa da Vila ganha o seu lote cercado de ripas (frente com vão de portão na porta, laterais; os fundos já fecham com o cercado antigo), e um quintal que conta "
         "o ofício de quem mora: pesca, lavanderia, obra, horta, oficina.")
    # (id, kit, espelho, margem esquerda/direita, frente, fundos)
    casas = [("vila_caicara_01", kit_pescador, 1), ("vila_caicara_02", kit_lavadeira, 1), ("vila_caicara_06", kit_horta, 1),
             ("vila_caicara_09", kit_oficina, 1), ("vila_caicara_12", kit_obra, 1), ("vila_caicara_14", kit_pescador, -1),
             ("vila_caicara_15", kit_lavadeira, -1), ("vila_caicara_04", kit_obra, -1), ("vila_caicara_11", kit_horta, -1),
             ("vila_caicara_16", kit_oficina, -1), ("vila_caicara_08", kit_jardim, 1), ("vila_caicara_13", kit_jardim, -1)]
    for bid, kit, s in casas:
        c = B(bid)
        # casa_demo 14 x 14 m: quintal de 22 x 22 m (cerca 4 m fora da parede), 3 lados (os fundos ficam abertos para o terreiro)
        c.lote(4.0, 4.0, 4.0, 4.0, vao=3.0, lados=(True, True, False, True),
               abrir=[(-424.1, -316.5, 3.0), (-328.5, -300.4, 3.0), (-331.8, -303.3, 3.0)])   # V1 rente ao lote 01; barranco de 40 graus no 13
        kit(c, s)
    c = B("vila_caicara_03")
    c.lote(3.2, 3.2, 4.0, 5.5, vao=4.0, lados=(True, True, False, False), extra_vaos={"frente": [(10.0, 13.4)]})
    kit_bar(c, 1)
    for bid, s in (("vila_caicara_05", 1), ("vila_caicara_10", -1)):
        c = B(bid)
        c.lote(3.5, 3.5, 3.8, 4.5, vao=4.5, lados=(True, True, False, True))
        kit_rancho(c, s)


montar()
