# Lote 2 de prédios (importado por build_predios.py): quiosque, guarita, paiol, caixa d'água, galpão,
# casa de colono, vila operária, venda/bar, rancho de pesca. Geometria explícita com o Kit de build_predios.
# Portas com vão mínimo de 1,1 x 2,15 m; interiores mobiliados (interior.py); escadas de mão jogáveis (Kit.escada_mao).
import interior


def construir(Kit, quer):
    C = interior.Comodo

    def quiosque(v, cor_balcao):
        k = Kit("quiosque_%s" % v)
        k.caixa(-2.6, -2.6, -0.2, 2.6, 2.6, 0.15, "concreto_escuro")
        for x, y in ((-2.2, -2.2), (2.2, -2.2), (-2.2, 2.2), (2.2, 2.2)):
            k.caixa(x - 0.1, y - 0.1, 0.15, x + 0.1, y + 0.1, 2.6, "madeira")
        k.caixa(-2.1, -2.1, 0.15, 2.1, -1.8, 1.05, cor_balcao)          # balcão em U, entrada por trás
        k.caixa(-2.25, -2.25, 1.05, 2.25, -1.7, 1.12, "madeira_clara")
        k.caixa(-2.1, -1.8, 0.15, -1.8, 1.2, 1.05, cor_balcao)
        k.caixa(1.8, -1.8, 0.15, 2.1, 1.2, 1.05, cor_balcao)
        b, z0, z1 = 0.8, 2.6, 4.0                                       # sapê em pirâmide com beiral largo
        cantos = [(-2.5 - b, -2.5 - b), (2.5 + b, -2.5 - b), (2.5 + b, 2.5 + b), (-2.5 - b, 2.5 + b)]
        for i in range(4):
            a, c = cantos[i], cantos[(i + 1) % 4]
            k.prisma([(a[0], a[1], z0 - 0.35), (c[0], c[1], z0 - 0.35), (0, 0, z1)], (0, 0, 0.18), "sape")
        k.caixa(-0.15, -0.15, z1, 0.15, 0.15, z1 + 0.5, "madeira")
        k.fim()

    def guarita(v):
        k = Kit("guarita_%s" % v)
        e = 0.15
        k.caixa(-1.6, -1.6, -0.2, 1.6, 1.6, 0.1, "concreto_escuro")
        k.parede("x", -1.5, 1.5, -1.5, 0.1, 2.6, e, "concreto", vaos=[(0.0, 1.1, 0.1, 2.25)], lado=1)
        k.folha("x", 0.0, -1.5, 1.1, 2.15, "porta_aco", 1, z0=0.1, dir=1)
        k.parede("x", -1.5, 1.5, 1.5, 0.1, 2.6, e, "concreto", vaos=[(0.0, 1.0, 1.1, 2.0)], lado=-1)
        k.parede("y", -1.35, 1.35, -1.5, 0.1, 2.6, e, "concreto", vaos=[(0.0, 1.0, 1.1, 2.0)], lado=1)
        k.parede("y", -1.35, 1.35, 1.5, 0.1, 2.6, e, "concreto", vaos=[(0.0, 1.0, 1.1, 2.0)], lado=-1)
        k.caixa(-1.7, -1.7, 2.6, 1.7, 1.7, 2.75, "concreto_escuro")
        # sacada leste (2,3 m) com guarda-corpo aberto na escada de mão; o posto de vigia ganha porta para ela
        k.caixa(1.5, -0.9, 2.6, 2.3, 0.9, 2.75, "concreto_escuro")
        for (a0, a1, f, eixo) in ((-0.9, 0.9, -0.9, "x"), (-0.9, 0.9, 0.9, "x")):
            k.caixa(1.5, f - 0.03, 2.75, 2.3, f + 0.03, 3.6, "ferro")
        k.caixa(2.27, -0.9, 2.75, 2.33, -0.5, 3.6, "ferro")
        k.caixa(2.27, 0.5, 2.75, 2.33, 0.9, 3.6, "ferro")
        for f, lado in ((-1.5, 1), (1.5, -1)):                          # posto de vigia com janelas corridas
            k.parede("x", -1.5, 1.5, f, 2.75, 5.3, e, "verde_militar", vaos=[(0.0, 2.4, 3.8, 5.0)], lado=lado)
        k.parede("y", -1.35, 1.35, -1.5, 2.75, 5.3, e, "verde_militar", vaos=[(0.0, 2.2, 3.8, 5.0)], lado=1)
        k.parede("y", -1.35, 1.35, 1.5, 2.75, 5.3, e, "verde_militar", vaos=[(0.0, 1.1, 2.75, 4.9)], lado=-1)
        k.caixa(-1.4, -1.4, 2.75, 1.4, 1.4, 2.8, "piso")
        k.telhado_duas_aguas(-1.5, 1.5, -1.5, 1.5, 5.3, 0.8, 0.4, "zinco", "verde_militar")
        k.escada_mao("g1", 2.33, 0.0, 0.1, 2.75, 1, 0, sai=0.55)
        # interior do térreo: posto de guarda
        s = C(k, "guarita", (-1.35, -1.35, 1.35, 1.35), 0.1, portas=[(0.0, -1.35)], janelas=[(1.35, 0.0, 1.0), (-1.35, 0.0, 1.0), (0.0, 1.35, 1.0)], tipo="sala")
        s.enc("mesa_escritorio", "N", 0.5, w=1.1, d=0.65)
        s.enc("arquivo", "E", 0.9)
        s.enc("estante", "W", 0.9, w=0.9)
        s.loot("E", 0.2, "medio")
        s.loot("W", 0.15, "medio")
        k.fim()

    def paiol(v, madeira):
        k = Kit("paiol_%s" % v)
        H, zp = 3.2, 0.25
        k.caixa(-4.1, -5.1, -0.3, 4.1, 5.1, zp, "concreto_escuro")
        k.parede("x", -4, 4, -5, zp, H, 0.12, madeira, vaos=[(0.0, 2.4, zp, 2.6)], lado=1)
        k.parede("x", -4, 4, 5, zp, H, 0.12, madeira, vaos=[(2.2, 1.1, zp, zp + 2.15)], lado=-1)       # porta dos fundos
        k.parede("y", -4.88, 4.88, -4, zp, H, 0.12, madeira, vaos=[(1.0, 1.2, 1.2, 2.0)], lado=1)
        k.parede("y", -4.88, 4.88, 4, zp, H, 0.12, madeira, vaos=[], lado=-1)
        for i in range(9):                                              # ripas verticais na fachada
            x = -3.8 + i * 0.9
            if abs(x) > 1.3:
                k.caixa(x - 0.04, -5.08, zp, x + 0.04, -5.02, H, "tabua_escura")
        k.caixa(1.25, -5.18, zp, 3.6, -5.12, 2.6, "tabua")            # porta de correr aberta (por fora, rente à parede)
        k.telhado_duas_aguas(-4, 4, -5, 5, H, 1.4, 0.5, "telha", madeira)
        k.caixa(-3.88, -4.88, H - 0.1, 3.88, 4.88, H, "tabua_escura")   # forro
        # depósito de munição: estantes nas paredes, paletes e tambores no centro
        k.entrada(0.0, -6.3, 0, 1)
        k.entrada(2.2, 6.3, 0, -1)
        d = C(k, "paiol", (-3.88, -4.88, 3.88, 4.88), zp, portas=[(0.0, -4.88, 2.4), (2.2, 4.88, 1.1)], tipo="galpao")
        for f in (0.12, 0.5, 0.88):
            d.enc("estante_carga", "W", f, w=1.6)
        for f in (0.12, 0.5, 0.88):
            d.enc("estante_carga", "E", f, w=1.6)
        d.enc("estante_carga", "N", 0.1, w=1.6)
        d.livre("pallet", -1.6, -1.6, 0)
        d.livre("pallet", 1.6, -1.6, 0)
        d.livre("pallet", -1.6, 1.4, 90)
        d.livre("caixotes", 1.4, 0.8, 0)
        d.enc("tambores", "N", 0.5)
        d.loot("W", 0.3, "alto")
        d.loot("E", 0.3, "alto")
        d.loot("E", 0.7, "alto")
        d.loot("N", 0.45, "alto")
        d.loot_livre(0.0, 0.0, 0.0, "alto")
        k.fim()

    def caixa_dagua(v):
        k = Kit("caixa_dagua_%s" % v)
        H = 16.0
        for x, y in ((-1.8, -1.8), (1.8, -1.8), (-1.8, 1.8), (1.8, 1.8)):
            k.caixa(x - 0.2, y - 0.2, 0.0, x + 0.2, y + 0.2, H, "concreto")
        for z in (5.0, 10.0, 15.0):
            k.caixa(-2.0, -2.0, z, 2.0, -1.6, z + 0.35, "concreto")
            k.caixa(-2.0, 1.6, z, 2.0, 2.0, z + 0.35, "concreto")
            k.caixa(-2.0, -1.6, z, -1.6, 1.6, z + 0.35, "concreto")
            k.caixa(1.6, -1.6, z, 2.0, 1.6, z + 0.35, "concreto")
        k.caixa(-2.5, -2.5, H, 2.5, 2.5, H + 3.6, "concreto")
        k.caixa(-2.6, -2.6, H + 3.6, 2.6, 2.6, H + 3.8, "concreto_escuro")
        k.caixa(-2.6, -2.62, H + 3.8, -0.5, -2.5, H + 4.6, "ferro")        # guarda-corpo aberto na chegada da escada
        k.caixa(0.5, -2.62, H + 3.8, 2.6, -2.5, H + 4.6, "ferro")
        k.caixa(-2.6, 2.5, H + 3.8, 2.6, 2.62, H + 4.6, "ferro")
        k.escada_mao("c1", 0.0, -2.55, 0.0, H + 3.8, 0, -1, sai=0.9)     # escada de marinheiro até a laje superior
        k.fim()

    def galpao(v, telha):
        k = Kit("galpao_%s" % v)
        W, D, H = 20.0, 30.0, 6.0
        x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
        zp = 0.12
        k.caixa(x0, y0, -0.3, x1, y1, zp, "concreto_escuro")
        k.parede("x", x0, x1, y0, zp, H, 0.2, "concreto", vaos=[(0.0, 6.0, zp, 4.8), (-7.5, 1.1, zp, zp + 2.15)], lado=1)
        k.parede("x", x0, x1, y1, zp, H, 0.2, "concreto", vaos=[(0.0, 6.0, zp, 4.8)], lado=-1)
        for f, lado in ((x0, 1), (x1, -1)):
            k.parede("y", y0 + 0.2, y1 - 0.2, f, zp, H, 0.2, "concreto", vaos=[(c, 2.0, 3.6, 4.8) for c in (-10, -5, 0, 5, 10)], lado=lado)
        for y in (-7.5, 0.0, 7.5):
            k.caixa(x0, y - 0.1, H - 0.1, x1, y + 0.1, H + 0.1, "ferro")
        k.caixa(x0 + 0.2, y1 - 6, 3.0, x1 - 0.2, y1 - 0.2, 3.2, "concreto")   # mezanino
        for i in range(12):                                             # escada até o mezanino: degraus de 0,26 m
            z = zp + (i + 1) * 0.26
            k.caixa(x1 - 1.4, y1 - 6 - (12 - i) * 0.3, z - 0.2, x1 - 0.3, y1 - 6 - (11 - i) * 0.3, z, "concreto")
        k.caixa(x0 + 0.2, y1 - 6.05, 3.2, x1 - 1.5, y1 - 6.0, 4.1, "ferro")  # guarda-corpo do mezanino (aberto na escada)
        k.lance_teste(x1 - 0.85, y1 - 10.4, 0, 1, 3.2, x1 - 0.85, y1 - 5.0)
        k.telhado_duas_aguas(x0, x1, y0, y1, H, 2.2, 0.6, telha, "concreto", cumeeira_x=False)
        # interior: corredor central livre; prateleiras nas paredes; paletes e tambores
        k.entrada(0.0, y0 - 1.3, 0, 1)
        k.entrada(0.0, y1 + 1.3, 0, -1)
        k.entrada(-7.5, y0 - 1.3, 0, 1)
        g = C(k, "galpao", (x0 + 0.2, y0 + 0.2, x1 - 0.2, y1 - 0.2), zp, portas=[(0.0, y0 + 0.2, 6.0), (-7.5, y0 + 0.2, 1.1), (0.0, y1 - 0.2, 6.0)], tipo="galpao")
        g.ocupado.append((x1 - 1.6, y1 - 9.8, x1 - 0.2, y1 - 5.8))      # pé da escada do mezanino
        g.ocupado.append((-1.5, y0 + 0.2, 1.5, y1 - 0.2))                # corredor central (caminhões/empilhadeira)
        for f in (0.08, 0.22, 0.36, 0.5, 0.64):
            g.enc("estante_carga", "W", f, w=1.6)
        for f in (0.08, 0.22, 0.36, 0.5, 0.64):
            g.enc("estante_carga", "E", f, w=1.6)
        for (x, y, r) in ((-5.5, -10.0, 0), (-3.5, -10.0, 0), (-5.5, -6.0, 90), (4.5, -10.0, 0), (5.5, -5.0, 0), (-5.5, 2.0, 0), (4.5, 1.5, 90)):
            g.livre("pallet", x, y, r)
        g.livre("caixotes", -6.0, 6.0, 0)
        g.livre("caixotes", 6.0, 4.0, 0)
        g.livre("tambores", -7.5, -12.0, 0)
        g.livre("tambores", 7.8, -12.5, 0)
        g.loot("W", 0.85, "medio")
        g.loot("E", 0.92, "medio")
        g.loot_livre(-4.0, -12.5, 180.0, "medio")
        g.loot_livre(4.5, -8.0, 180.0, "medio")
        g.loot_livre(-4.0, 10.5, 0.0, "medio")
        k.fim()

    def casa_simples(nome, W, D, parede, barra, janela_cor):
        k = Kit(nome)
        H, e = 2.6, 0.15
        x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
        zp = 0.14
        YD, XD = 0.8, 0.1
        k.caixa(x0 - 0.1, y0 - 0.1, -0.3, x1 + 0.1, y1 + 0.1, 0.12, "concreto_escuro")
        k.caixa(x0 + e, y0 + e, 0.12, x1 - e, y1 - e, zp, "piso")
        k.parede("x", x0, x1, y0, 0.12, H, e, parede, vaos=[(-0.8, 1.1, 0.12, 2.27), (1.6, 1.0, 1.0, 2.0)], lado=1)
        k.caixa(x0, y0 - 0.02, 0.12, -1.35, y0 + 0.02, 0.8, barra)          # barra pintada (com o vão da porta livre)
        k.caixa(-0.25, y0 - 0.02, 0.12, x1, y0 + 0.02, 0.8, barra)
        k.janela("x", 1.6, y0, 1.0, 2.0, 1.0, janela_cor, lado=-1)
        k.folha("x", -0.8, y0, 1.1, 2.15, janela_cor, 1, z0=0.12, dir=1)
        k.parede("x", x0, x1, y1, 0.12, H, e, parede, vaos=[(2.0, 1.1, 0.12, 2.27), (-1.5, 1.0, 1.0, 2.0)], lado=-1)
        k.janela("x", -1.5, y1, 1.0, 2.0, 1.0, janela_cor, lado=1)
        k.parede("y", y0 + e, y1 - e, x0, 0.12, H, e, parede, vaos=[(-1.6, 1.0, 1.0, 2.0), (2.2, 1.0, 1.0, 2.0)], lado=1)
        for c in (-1.6, 2.2):
            k.janela("y", c, x0, 1.0, 2.0, 1.0, janela_cor, lado=-1)
        k.parede("y", y0 + e, y1 - e, x1, 0.12, H, e, parede, vaos=[(-1.6, 1.0, 1.0, 2.0)], lado=-1)
        k.janela("y", -1.6, x1, 1.0, 2.0, 1.0, janela_cor, lado=1)
        k.parede("x", x0 + e, x1 - e, YD, zp, H, 0.1, parede, vaos=[(-1.4, 1.1, zp, zp + 2.1), (1.4, 1.1, zp, zp + 2.1)])
        k.parede("y", YD + 0.1, y1 - e, XD - 0.1, zp, H, 0.1, parede)
        k.telhado_duas_aguas(x0, x1, y0, y1, H, 1.3, 0.4, "telha", parede, cumeeira_x=False)
        k.caixa(x0 + e, y0 + e, H - 0.1, x1 - e, y1 - e, H, "reboco_branco")                   # forro
        sala = C(k, "sala", (x0 + e, y0 + e, x1 - e, YD), zp, portas=[(-0.8, y0 + e), (-1.4, YD), (1.4, YD)], janelas=[(1.6, y0 + e, 1.0), (x0 + e, -1.6, 1.0), (x0 + e, 2.2, 1.0), (x1 - e, -1.6, 1.0)])
        quarto = C(k, "quarto", (x0 + e, YD + 0.1, XD - 0.1, y1 - e), zp, portas=[(-1.4, YD + 0.1)], janelas=[(-1.5, y1 - e, 1.0), (x0 + e, 2.2, 1.0)])
        coz = C(k, "cozinha", (XD, YD + 0.1, x1 - e, y1 - e), zp, portas=[(1.4, YD + 0.1), (2.0, y1 - e, 1.1)], janelas=[(x1 - e, -1.6, 1.0)])
        sala.enc("sofa", "E", 0.3, w=1.9)
        sala.enc("tv_rack", "N", 0.55, w=1.1)
        sala.enc("estante", "W", 0.25, w=1.0)
        sala.livre("tapete", 1.4, -1.6, 90, w=2.0, d=1.4)
        sala.livre("mesa_centro", 1.5, -1.6, 90, w=1.0, d=0.5)
        sala.enc("aparador", "S", 0.9, w=1.0)
        sala.loot("S", 0.1, "baixo")
        quarto.enc("cama", "W", 1.0, w=1.3)
        quarto.enc("guarda_roupa", "E", 1.0, w=1.2)
        quarto.enc("criado", "N", 0.9)
        quarto.loot("S", 0.0, "baixo")
        coz.enc("pia", "N", 0.0, w=1.1)
        coz.enc("fogao", "W", 0.6)
        coz.enc("geladeira", "E", 0.3)
        coz.enc("armario_alto", "N", 0.0, w=1.1)
        coz.livre("mesa", 0.75, 2.4, 0, w=0.8, d=0.7)
        coz.loot("E", 0.85, "medio")
        k.fim()

    def vila_operaria(v, cores):
        k = Kit("vila_operaria_%s" % v)
        W, D, H, e = 6.0, 24.0, 2.7, 0.15
        x0, x1 = -W / 2, W / 2
        zp = 0.14
        k.caixa(x0 - 1.2, -D / 2, -0.3, x1 + 0.1, D / 2, 0.12, "concreto_escuro")
        # cada unidade (6 x 6 m): sala na frente (-X), cozinha e quarto nos fundos; divisórias com portas de 1,1 m
        pontos = [("cozinha", "E", 0.3), ("quarto", "W", 0.0), ("sala", "E", 0.6), ("cozinha", "E", 0.3)]
        for i in range(4):                                              # 4 casas geminadas, frente para -X
            ya, yb = -D / 2 + i * 6, -D / 2 + (i + 1) * 6
            cor = cores[i % len(cores)]
            k.caixa(x0 + e, ya + e, 0.12, x1 - e, yb - e, zp, "piso")
            k.parede("y", ya, yb, x0, 0.12, H, e, cor, vaos=[(ya + 1.6, 1.1, 0.12, 2.27), (ya + 4.2, 1.1, 1.0, 2.0)], lado=1)
            k.caixa(x0 - 0.02, ya, 0.12, x0 + 0.02, ya + 1.05, 0.7, "barra_azul" if i % 2 else "barra_verde")
            k.caixa(x0 - 0.02, ya + 2.15, 0.12, x0 + 0.02, yb, 0.7, "barra_azul" if i % 2 else "barra_verde")
            k.janela("y", ya + 4.2, x0, 1.0, 2.0, 1.1, "janela_azul" if i % 2 else "janela_verde", lado=-1)
            k.folha("y", ya + 1.6, x0, 1.1, 2.15, "janela_azul" if i % 2 else "janela_verde", 1, z0=0.12, dir=-1)
            k.parede("y", ya, yb, x1, 0.12, H, e, cor, vaos=[(ya + 1.5, 1.1, 0.12, 2.27), (ya + 4.4, 1.0, 1.0, 2.0)], lado=-1)
            k.janela("y", ya + 4.4, x1, 1.0, 2.0, 1.0, "janela_azul" if i % 2 else "janela_verde", lado=1)
            k.parede("x", x0 + e, x1 - e, ya, 0.12, H, e, cor, vaos=[] if i else [(0.0, 1.0, 1.0, 2.0)], lado=1)
            # divisórias internas
            k.parede("y", ya + e, yb - e, 0.0, zp, H, 0.1, cor, vaos=[(ya + 1.5, 1.1, zp, zp + 2.1), (ya + 4.4, 1.1, zp, zp + 2.1)])
            k.parede("x", 0.1, x1 - e, ya + 3.0, zp, H, 0.1, cor)
            k.caixa(x0 + e, ya + e, H - 0.1, x1 - e, yb - e, H, "reboco_branco")                # forro
            sala = C(k, "sala", (x0 + e, ya + e, 0.0, yb - e), zp, portas=[(x0 + e, ya + 1.6), (0.0, ya + 1.5), (0.0, ya + 4.4)], janelas=[(x0 + e, ya + 4.2, 1.1)])
            coz = C(k, "cozinha", (0.1, ya + e, x1 - e, ya + 3.0), zp, portas=[(0.1, ya + 1.5), (x1 - e, ya + 1.5)])
            qua = C(k, "quarto", (0.1, ya + 3.1, x1 - e, yb - e), zp, portas=[(0.1, ya + 4.4)], janelas=[(x1 - e, ya + 4.4, 1.0)])
            sala.enc("sofa", "N", 0.4, w=1.8)
            sala.enc("tv_rack", "S", 0.4, w=1.1)
            sala.enc("estante", "W", 1.0, w=0.9)
            sala.livre("mesa_centro", -1.4, ya + 4.0, 0, w=1.0, d=0.5)
            qua.enc("cama", "N", 1.0, w=1.1)
            qua.enc("guarda_roupa", "S", 1.0, w=1.3)
            qua.enc("criado", "E", 0.3)
            coz.enc("pia", "N", 0.0, w=1.1)
            coz.enc("fogao", "N", 0.7)
            coz.enc("geladeira", "S", 1.0)
            coz.enc("armario_alto", "N", 0.0, w=1.1)
            coz.livre("mesa", 1.6, ya + 1.2, 0, w=0.8, d=0.7)
            lugar, parede_l, fr = pontos[i]
            {"sala": sala, "cozinha": coz, "quarto": qua}[lugar].loot(parede_l, fr, "baixo")
        k.parede("x", x0 + e, x1 - e, D / 2, 0.12, H, e, cores[0], vaos=[(0.0, 1.0, 1.0, 2.0)], lado=-1)
        k.telhado_duas_aguas(x0, x1, -D / 2, D / 2, H, 1.3, 0.45, "telha", cores[0])
        k.fim()

    def venda_bar(v, parede, placa):
        k = Kit("venda_bar_%s" % v)
        W, D, H, e = 7.0, 9.0, 3.2, 0.15
        x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
        zp = 0.17
        k.caixa(x0 - 0.1, y0 - 1.0, -0.3, x1 + 0.1, y1 + 0.1, 0.15, "concreto_escuro")
        k.caixa(x0 + e, y0 + e, 0.15, x1 - e, y1 - e, zp, "piso")
        k.parede("x", x0, x1, y0, 0.15, H, e, parede, vaos=[(0.0, 3.2, 0.15, 2.4)], lado=1)
        k.caixa(-1.6, y0 - 0.1, 2.4, 1.6, y0 + 0.05, 2.9, "porta_aco")          # porta de enrolar recolhida
        k.caixa(-2.8, y0 - 0.12, 3.0, 2.8, y0 - 0.02, 3.9, placa)              # placa
        k.parede("x", x0, x1, y1, 0.15, H, e, parede, vaos=[(2.3, 1.1, 0.15, 2.3)], lado=-1)
        k.parede("y", y0 + e, y1 - e, x0, 0.15, H, e, parede, vaos=[(1.5, 1.2, 1.1, 2.1)], lado=1)
        k.janela("y", 1.5, x0, 1.1, 2.1, 1.2, "ferro", lado=-1, venezianas=False)
        k.parede("y", y0 + e, y1 - e, x1, 0.15, H, e, parede, vaos=[], lado=-1)
        k.prisma([(x0 - 0.2, y0, H - 0.1), (x1 + 0.2, y0, H - 0.1), (x1 + 0.2, y0 - 1.6, H - 0.7), (x0 - 0.2, y0 - 1.6, H - 0.7)], (0, 0, 0.06), "zinco_ferrugem")
        k.caixa(x0 - 0.1, y0 - 0.1, H, x1 + 0.1, y1 + 0.1, H + 0.2, "concreto")
        k.entrada(0.0, y0 - 1.3, 0, 1)
        k.entrada(2.3, y1 + 1.3, 0, -1)
        b = C(k, "venda", (x0 + e, y0 + e, x1 - e, y1 - e), zp, portas=[(0.0, y0 + e, 3.2), (2.3, y1 - e, 1.1)], janelas=[(x0 + e, 1.5, 1.2)], tipo="sala")
        b.livre("balcao", 0.0, -2.0, 0, w=4.4, d=0.6)                              # balcão de atendimento (costas para o fundo)
        b.enc("estante_carga", "N", 0.0, w=1.8)
        b.enc("estante_carga", "N", 0.35, w=1.8)
        b.enc("geladeira", "W", 0.9, w=0.8)
        b.enc("estante", "E", 0.5, w=1.4)
        b.livre("mesa_bar", 2.0, 0.6, 0)
        b.livre("cadeira", 2.0, 1.4, 0)
        b.livre("cadeira", 2.0, -0.2, 180)
        b.livre("caixotes", -2.3, 1.5, 0)
        b.loot("W", 0.45, "medio")
        b.loot("E", 0.12, "medio")
        b.loot("N", 0.9, "medio")
        k.fim()

    def rancho_pesca(v):
        k = Kit("rancho_pesca_%s" % v)
        k.caixa(-4, -6, -0.2, 4, 6, 0.05, "sape")
        for x in (-3.8, 3.8):
            for y in (-5.8, -1.9, 1.9, 5.8):
                k.caixa(x - 0.12, y - 0.12, 0.0, x + 0.12, y + 0.12, 3.0, "madeira")
        k.telhado_duas_aguas(-4, 4, -6, 6, 3.0, 1.2, 0.6, "sape", "madeira_clara", cumeeira_x=False)
        k.prisma([(-0.6, -4.5, 0.05), (0.6, -4.5, 0.05), (0.7, 4.0, 0.05), (0.0, 4.8, 0.05), (-0.7, 4.0, 0.05)], (0, 0, 0.7), "barra_azul")
        k.caixa(1.4, -3.0, 0.05, 1.5, 1.0, 0.12, "madeira_clara")
        k.entrada(-5.4, -3.8, 1, 0)
        k.entrada(5.4, 3.8, -1, 0)
        r = C(k, "rancho", (-3.6, -5.6, 3.6, 5.6), 0.05, tipo="galpao")
        r.ocupado.append((-1.0, -5.0, 1.0, 5.2))                          # o barco
        r.enc("bancada", "W", 0.5, w=2.0)
        r.enc("caixotes", "E", 0.15)
        # (sem caixote em E 0,85: ficava no corredor da entrada leste — tests/ce_construcoes porta #2)
        r.enc("tambores", "W", 0.05)
        r.enc("estante_carga", "W", 0.95, w=1.6)
        r.loot("W", 0.25, "baixo")
        r.loot("E", 0.5, "baixo")
        r.loot("E", 0.0, "baixo")
        k.fim()

    if quer("quiosque"):
        quiosque("a", "reboco_azul"); quiosque("b", "reboco_amarelo")
    if quer("guarita"):
        guarita("a")
    if quer("paiol"):
        paiol("a", "tabua"); paiol("b", "tabua_escura")
    if quer("caixa_dagua"):
        caixa_dagua("a")
    if quer("galpao"):
        galpao("a", "zinco"); galpao("b", "zinco_ferrugem")
    if quer("casa_colono"):
        casa_simples("casa_colono_a", 6.0, 8.0, "reboco_ocre", "tijolo_escuro", "janela_verde")
        casa_simples("casa_colono_b", 6.0, 8.0, "reboco_branco", "barra_azul", "janela_azul")
    if quer("vila_operaria"):
        vila_operaria("a", ["reboco_amarelo", "reboco_azul", "reboco_rosa", "reboco_verde"])
    if quer("venda_bar"):
        venda_bar("a", "reboco_verde", "placa"); venda_bar("b", "reboco_amarelo", "barra_azul")
    if quer("rancho_pesca"):
        rancho_pesca("a")
