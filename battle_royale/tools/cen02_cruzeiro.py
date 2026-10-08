# -*- coding: utf-8 -*-
"""Morro do Cruzeiro, passe 02: lotes apertados de ladeira (cerca baixa na frente, ripas nos lados e fundos)
e um pequeno acervo de cada casa; praça do cruzeiro mais viva."""
from cenario_02_src import *


# Casas de 14 x 14 m viradas para o cruzeiro: o canto de cada casa é o quintal da frente (3,4 m entre a fachada e a cerca),
# lateral a 3 m ou mais do eixo da porta (vão do portão de 2,6 m).
def k_varal(c, s):
    # lenha empilhada para o fogão e um toco de sentar
    N("lenha", *c.W(4.6 * s, c.yf(1.7)), c.rot)
    N("lenha", *c.W(5.7 * s, c.yf(1.9)), c.rot + 40)
    N("toco", *c.W(-4.6 * s, c.yf(1.8)), c.rot)


def k_obra(c, s):
    # obra da próxima laje
    c.p("pilha_tijolo", 4.6 * s, c.yf(1.8), 15)
    N("pilha_tabuas", *c.W(-4.8 * s, c.yf(1.8)), c.rot + 10)
    c.p("carrinho_mao", 6.2 * s, c.yf(1.5), 30)


def k_horta(c, s):
    # canteiro de arbustos e banco de conversa
    N("arbusto_a", *c.W(-3.6 * s, c.yf(1.6)), c.rot)
    N("arbusto_b", *c.W(3.6 * s, c.yf(1.6)), c.rot + 50)
    c.p("banco_praca", 5.6 * s, c.yf(1.8), 0)


def k_oficina(c, s):
    # tambores de óleo e um caixote de ferramentas
    c.p("tambor", 4.6 * s, c.yf(1.5))
    c.p("tambor", 5.8 * s, c.yf(1.5))
    c.p("caixote_peixe", -4.6 * s, c.yf(1.8), 80)


def k_lenha(c, s):
    # entulho de reforma, barril d'água da chuva e um monte de areia
    N("entulho", *c.W(-4.8 * s, c.yf(1.8)), c.rot)
    c.p("barril", 4.6 * s, c.yf(1.6))
    N("monte_terra", *c.W(6.0 * s, c.yf(1.8)), c.rot + 90)


def k_canto(c, s):
    # casa espremida entre vizinhas: só um canto livre, lenha e um barril
    N("lenha", *c.W(4.6 * s, c.yf(1.7)), c.rot)
    N("lenha", *c.W(5.7 * s, c.yf(1.9)), c.rot + 40)
    c.p("barril", 6.4 * s, c.yf(1.2))


KITS = [k_varal, k_obra, k_horta, k_oficina, k_lenha, k_canto]


def montar():
    area("Cruzeiro: lotes da ladeira",
         "Casas de laje coladas na ladeira: cada lote tem cerca de ripas na frente e nos lados (o morro faz o muro dos fundos), vão no degrau da porta, e um canto "
         "com a vida de quem mora (roupa no varal, obra da próxima laje, horta, oficina, lenha do fogão).")
    # (id, kit, espelho, lados(frente, direita, fundos, esquerda))
    T, F = True, False
    casas = [
        ("morro_cruzeiro_01", 0, 1, (T, T, F, T)), ("morro_cruzeiro_02", 1, -1, (T, T, F, T)), ("morro_cruzeiro_03", 2, 1, (T, T, F, T)),
        ("morro_cruzeiro_04", 3, -1, (T, T, F, T)), ("morro_cruzeiro_05", 4, 1, (T, T, F, T)), ("morro_cruzeiro_06", 0, -1, (T, T, F, T)),
        ("morro_cruzeiro_07", 1, 1, (T, T, F, T)), ("morro_cruzeiro_08", 2, -1, (T, T, F, T)), ("morro_cruzeiro_09", 3, 1, (T, T, F, T)),
        ("morro_cruzeiro_10", 4, -1, (T, T, F, T)), ("morro_cruzeiro_11", 5, 1, (T, T, F, T)), ("morro_cruzeiro_12", 1, -1, (T, T, F, T)),
        ("morro_cruzeiro_13", 2, 1, (T, T, F, T)), ("morro_cruzeiro_14", 3, -1, (T, T, F, T)), ("morro_cruzeiro_15", 4, 1, (T, T, F, T)),
        ("morro_cruzeiro_16", 0, -1, (T, T, F, T)), ("morro_cruzeiro_17", 1, 1, (T, T, F, T)), ("morro_cruzeiro_18", 2, -1, (T, T, F, T)),
        ("morro_cruzeiro_19", 3, 1, (T, T, F, T)), ("morro_cruzeiro_20", 4, -1, (T, T, F, T)), ("morro_cruzeiro_21", 0, 1, (T, T, F, T)),
    ]
    for bid, k, s, lados in casas:
        c = B(bid)
        ev = None
        # vãos extras onde a cerca bateria na via V2 ou na casa vizinha (pontos lidos no relatório da conferência)
        ab = [(-308.5, 1.8, 2.6), (-359.6, 15.1, 2.6), (-339.8, 16.3, 2.6), (-321.7, 23.0, 2.6), (-320.2, 27.1, 2.6),
              (-296.2, 40.8, 2.6), (-297.9, 37.5, 2.6),
              (-311.3, -3.9, 2.6), (-308.7, -2.2, 2.6), (-341.0, 12.5, 2.6), (-321.3, 19.0, 2.6), (-292.2, 40.8, 2.6)]
        c.lote(1.7, 1.7, 3.4, -12.9, vao=2.6, lados=lados, modos=("L", "L", "L", "L"), extra_vaos=ev, abrir=ab)
        KITS[k](c, s)


montar()
