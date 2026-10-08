# -*- coding: utf-8 -*-
"""Fazenda Boa Esperança, passe 02: jardim da frente do casarão, adro da capela, quintais dos colonos, pátio da tulha e do paiol."""
from cenario_02_src import *
from cen02_vila import kit_lavadeira, kit_obra, kit_horta


def kit_colono(c, s):
    # colono: lenha para o fogão, tábuas do cercado novo, barril de água e o carrinho de mão
    N("lenha", *c.W(c.xs(s, 1.6), c.yb(0.9)), c.rot)
    N("lenha", *c.W(c.xs(s, 1.6), c.yb(1.6)), c.rot + 35)
    N("pilha_tabuas", *c.W(c.xs(-s, 1.9), c.yb(1.6)), c.rot + 15)
    c.p("barril", c.xs(s, 1.6), c.yf(1.6))
    c.p("carrinho_mao", c.xs(-s, 1.8), c.yf(2.2), 55)


def montar():
    area("Fazenda: casarão, colonos e capela",
         "A fazenda ganha hierarquia: o casarão tem jardim cercado de ripas com vão no eixo da porta, sebe de arbustos e duas "
         "sombras de carvalho; os três colonos têm lote próprio com a vida de roça; a capela tem adro com bancos; a tulha e o paiol "
         "têm pátio de trabalho.")
    # --- jardim da frente do casarão (porta a sul, x = -110)
    # (casarão = 2 casas lado a lado, portas a 7 m do centro: dois portões, em x = -117 e x = -103)
    cerca((-130, -304), (-90, -304), "L", pular=[(11.5, 14.5), (25.5, 28.5)])
    cerca((-130, -304), (-130, -291), "L")
    cerca((-90, -304), (-90, -291), "L")
    for i, x in enumerate((-126, -123, -112, -110, -108, -97, -94)):
        N("arbusto_a" if i % 2 == 0 else "arbusto_b", x, -298.2, 10 * i)
    P(NAT + "carvalho", -127, -299.5, 20)
    P(NAT + "carvalho", -93, -299.5, 200)
    D("banco_praca", -124, -301.0, 0)
    D("banco_praca", -96, -301.0, 0)
    N("samambaia_a", -128.2, -294.5, 40)
    N("samambaia_b", -91.8, -294.5, 100)
    # --- colonos
    for bid, kit, s, mb in (("fazenda_boa_esperanca_05", kit_colono, 1, 7.5), ("fazenda_boa_esperanca_06", kit_lavadeira, -1, 7.5),
                            ("fazenda_boa_esperanca_07", kit_horta, 1, 7.5)):
        c = B(bid)
        c.lote(4.0, 4.0, 4.0, 4.0, vao=3.0, lados=(True, True, False, True))
        kit(c, s)
    # --- adro da capela (porta a sul, x = -150)
    c = B("fazenda_boa_esperanca_02")
    c.lote(4.0, 4.0, 5.0, 0.0, vao=3.6, modos=("C", "C", "C", "C"), lados=(True, False, False, False))
    c.p("banco_praca", -3.4, c.yf(2.2), 0)
    c.p("banco_praca", 3.4, c.yf(2.2), 0)
    c.p("lixeira", 5.6, c.yf(3.6), 0)
    N("carvalho", *c.W(-7.0, c.yf(3.0)), 0)
    N("arbusto_a", *c.W(-5.4, c.yf(1.4)), 0)
    N("arbusto_b", *c.W(5.4, c.yf(1.4)), 0)
    # --- pátio da tulha (porta a leste)
    c = B("fazenda_boa_esperanca_03")
    N("pilha_troncos", *c.W(-5.5, c.yf(3.2)), c.rot + 90)
    N("pilha_tabuas", *c.W(5.0, c.yf(2.4)), c.rot + 100)
    c.p("barril", 3.6, c.yf(1.2))
    c.p("barril", 3.6, c.yf(2.4))
    c.p("carrinho_mao", -3.4, c.yf(1.8), 60)
    c.p("caixote_peixe", -7.0, c.yf(1.5), 90)
    # --- paiol (porta a sul)
    c = B("fazenda_boa_esperanca_08")
    c.p("tambor", c.xr(1.6), c.yf(1.2))
    c.p("tambor", c.xr(2.7), c.yf(1.2))
    c.p("pilha_tijolo", c.xr(1.8), c.yb(1.4), 0)
    N("entulho", *c.W(c.xl(2.0), c.yb(1.5)), c.rot)


montar()
