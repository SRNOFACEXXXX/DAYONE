# Lote 4: marcos verticais e mirante (crítica 01, item 21). Geometria explícita com o Kit de build_predios.
# Escadas: lances de degraus <= 0,3 m (Kit.lance) e escadas de mão jogáveis (Kit.escada_mao).
import math


def construir(Kit, quer):
    if quer("mirante"):
        # plataforma de madeira 6x6 m a 3 m, guarda-corpo, escada inclinada (oeste) + escada de mão (leste), cobertura de sapê
        k = Kit("mirante_a")
        for x, y in ((-2.8, -2.8), (2.8, -2.8), (-2.8, 2.8), (2.8, 2.8)):
            k.caixa(x - 0.15, y - 0.15, 0.0, x + 0.15, y + 0.15, 5.4, "madeira")
        k.caixa(-3.1, -3.1, 3.0, 3.1, 3.1, 3.18, "madeira_clara")
        for (a0, a1, f, eixo, ld) in ((-3, 3, -3, "x", 1), (-3, 3, 3, "x", -1), (-3, 1.8, -3, "y", 1)):
            k.parede(eixo, a0, a1, f, 3.18, 4.2, 0.08, "madeira", lado=ld)
        k.parede("y", -3, -0.5, 3, 3.18, 4.2, 0.08, "madeira", lado=-1)            # lado leste aberto onde chega a escada de mão
        k.parede("y", 0.5, 3, 3, 3.18, 4.2, 0.08, "madeira", lado=-1)
        k.lance((-6.4, 1.9, -3.1, 2.9), "+x", 11, 0.0, 3.0, "madeira_clara", espessura=0.12)     # degraus de 0,27 m
        cantos = [(-3.6, -3.6), (3.6, -3.6), (3.6, 3.6), (-3.6, 3.6)]
        for i in range(4):
            a, c = cantos[i], cantos[(i + 1) % 4]
            k.prisma([(a[0], a[1], 5.2), (c[0], c[1], 5.2), (0, 0, 6.6)], (0, 0, 0.16), "sape")
        k.escada_mao("m1", 3.15, 0.0, 0.0, 3.18, 1, 0, sai=0.9)
        k.lance_teste(-6.9, 2.4, 1, 0, 3.18, -2.0, 2.4)
        k.fim()

    if quer("torre_vigia_madeira"):
        k = Kit("torre_vigia_madeira_a")
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            k.prisma([(sx * 2.0 - 0.15, sy * 2.0 - 0.15, 0.0), (sx * 2.0 + 0.15, sy * 2.0 - 0.15, 0.0), (sx * 2.0 + 0.15, sy * 2.0 + 0.15, 0.0), (sx * 2.0 - 0.15, sy * 2.0 + 0.15, 0.0)],
                     (-sx * 0.8, -sy * 0.8, 15.0), "madeira")
        for z in (5.0, 10.0):                                      # travessas
            r = 2.0 - z / 15.0 * 0.8
            k.caixa(-r, -r - 0.06, z, r, -r + 0.06, z + 0.15, "madeira_clara")
            k.caixa(-r, r - 0.06, z, r, r + 0.06, z + 0.15, "madeira_clara")
        # piso da cabine com alçapão (x -0,5..0,5 / y -1,4..-0,5) por onde sobe a escada de mão
        k.caixa(-1.8, -1.8, 15.0, -0.5, 1.8, 15.2, "madeira_clara")
        k.caixa(0.5, -1.8, 15.0, 1.8, 1.8, 15.2, "madeira_clara")
        k.caixa(-0.5, -1.8, 15.0, 0.5, -1.4, 15.2, "madeira_clara")
        k.caixa(-0.5, -0.5, 15.0, 0.5, 1.8, 15.2, "madeira_clara")
        for (a0, a1, f, eixo, ld) in ((-1.8, 1.8, -1.8, "x", 1), (-1.8, 1.8, 1.8, "x", -1), (-1.8, 1.8, -1.8, "y", 1), (-1.8, 1.8, 1.8, "y", -1)):
            k.parede(eixo, a0, a1, f, 15.2, 16.2, 0.08, "tabua", lado=ld)
        k.telhado_duas_aguas(-1.8, 1.8, -1.8, 1.8, 17.6, 0.8, 0.3, "zinco_ferrugem", "tabua")
        for x in (-1.8, 1.8):
            for y in (-1.8, 1.8):
                k.caixa(x - 0.06, y - 0.06, 15.2, x + 0.06, y + 0.06, 17.7, "madeira")
        k.escada_mao("v1", 0.0, -0.75, 0.0, 15.2, 0, -1, sai=0.9)     # escada de mão por dentro da torre, pelo alçapão
        k.fim()

    if quer("cata_vento"):
        k = Kit("cata_vento_a")
        k.caixa(-2.0, -2.0, -0.2, 2.0, 2.0, 0.2, "concreto")
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            k.prisma([(sx * 1.8 - 0.06, sy * 1.8 - 0.06, 0.2), (sx * 1.8 + 0.06, sy * 1.8 - 0.06, 0.2), (sx * 1.8 + 0.06, sy * 1.8 + 0.06, 0.2), (sx * 1.8 - 0.06, sy * 1.8 + 0.06, 0.2)],
                     (-sx * 1.6, -sy * 1.6, 16.0), "zinco")
        for z in (4.0, 8.0, 12.0):
            r = 1.8 - z / 16.0 * 1.6
            k.caixa(-r, -r - 0.03, z, r, -r + 0.03, z + 0.06, "zinco")
            k.caixa(-r, r - 0.03, z, r, r + 0.03, z + 0.06, "zinco")
        k.caixa(-0.4, -0.3, 16.2, 0.4, 0.5, 16.8, "zinco_ferrugem")                    # cabeçote
        for i in range(12):                                                              # roda de pás
            a = i * math.tau / 12
            k.prisma([(0.1 * math.cos(a), -0.55, 16.5 + 0.1 * math.sin(a)), (2.4 * math.cos(a - 0.12), -0.55, 16.5 + 2.4 * math.sin(a - 0.12)),
                      (2.4 * math.cos(a + 0.12), -0.55, 16.5 + 2.4 * math.sin(a + 0.12))], (0, -0.04, 0), "zinco")
        k.prisma([(0, 0.5, 16.5), (0, 3.2, 16.5), (0, 3.2, 17.6), (0, 2.2, 17.6)], (0.04, 0, 0), "placa")   # leme
        k.fim()

    if quer("antena_celular"):
        k = Kit("antena_celular_a")
        k.caixa(-1.5, -1.5, -0.2, 1.5, 1.5, 0.3, "concreto")
        k.prisma([(0.45 * math.cos(a), 0.45 * math.sin(a), 0.3) for a in [i * math.tau / 8 for i in range(8)]], (0, 0, 25.0), "reboco_branco")
        for i in range(3):                                                               # 3 painéis a 120° (acima da plataforma)
            a = i * math.tau / 3
            cx, cy = 0.8 * math.cos(a), 0.8 * math.sin(a)
            k.caixa(cx - 0.2, cy - 0.2, 23.0, cx + 0.2, cy + 0.2, 25.0, "reboco_branco")
        # plataforma de serviço 2,4 x 2,4 m a 21,8 m com entalhe (x -0,4..0,4 / y -1,3..-0,4) onde passa a escada de mão
        k.caixa(-1.2, -1.2, 21.6, -0.4, 1.2, 21.8, "ferro")
        k.caixa(0.4, -1.2, 21.6, 1.2, 1.2, 21.8, "ferro")
        k.caixa(-0.4, -0.4, 21.6, 0.4, 1.2, 21.8, "ferro")
        k.escada_mao("c1", 0.0, -0.55, 0.3, 21.8, 0, -1, sai=0.9)
        k.fim()

    if quer("torre_igreja"):
        k = Kit("torre_igreja_a")
        k.caixa(-2.2, -2.2, -0.3, 2.2, 2.2, 0.3, "concreto_escuro")
        for (a0, a1, f, eixo, ld) in ((-2, 2, -2, "x", 1), (-2, 2, 2, "x", -1), (-1.8, 1.8, -2, "y", 1), (-1.8, 1.8, 2, "y", -1)):
            k.parede(eixo, a0, a1, f, 0.3, 14.0, 0.25, "reboco_branco", vaos=[(1.0, 1.1, 0.3, 2.45)] if f == -2 and eixo == "x" else [(0.0, 1.4, 11.0, 13.4)], lado=ld)
        k.folha("x", 1.0, -2.0, 1.1, 2.15, "madeira", 1, z0=0.3, dir=1, espessura=0.25)
        k.caixa(-2.1, -2.1, 14.0, 2.1, 2.1, 14.3, "reboco_branco")
        cantos = [(-2.1, -2.1), (2.1, -2.1), (2.1, 2.1), (-2.1, 2.1)]
        for i in range(4):
            a, c = cantos[i], cantos[(i + 1) % 4]
            k.prisma([(a[0], a[1], 14.3), (c[0], c[1], 14.3), (0, 0, 18.5)], (0, 0, 0.15), "telha")
        k.caixa(-0.06, -0.06, 18.5, 0.06, 0.06, 20.0, "ferro")
        k.caixa(-0.45, -0.06, 19.3, 0.45, 0.06, 19.42, "ferro")
        k.prisma([(0.5 * math.cos(a), 0.5 * math.sin(a), 11.4) for a in [i * math.tau / 8 for i in range(8)]], (0, 0, 0.8), "barra_suja")   # sino
        # piso do sino com alçapão (x -1,3..-0,3 / y 0,85..1,75) e escada de mão interna pela parede norte
        k.caixa(-1.75, -1.75, 10.8, -1.3, 1.75, 11.1, "concreto")
        k.caixa(-0.3, -1.75, 10.8, 1.75, 1.75, 11.1, "concreto")
        k.caixa(-1.3, -1.75, 10.8, -0.3, 0.85, 11.1, "concreto")
        k.escada_mao("i1", -0.8, 1.65, 0.3, 11.1, 0, -1, saida=(0.4, 1.25))
        k.fim()
