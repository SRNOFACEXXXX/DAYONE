# Lote 3: prédios-marco dos POIs (geometria explícita com o Kit de build_predios). Medidas do design (tipos_predio).
# Portas com vão mínimo de 1,1 x 2,15 m; interiores mobiliados (interior.py); escadas caminháveis (degraus <= 0,3 m)
# e escadas de mão jogáveis (Kit.escada_mao -> Empties ESCADA_<id>_base/_topo).
import math
import interior


def construir(Kit, quer):
    C = interior.Comodo
    mob = {"sala": interior.mob_sala, "cozinha": interior.mob_cozinha, "quarto": interior.mob_quarto, "escritorio": interior.mob_escritorio,
           "reuniao": interior.mob_reuniao, "salao": interior.mob_salao, "hall": interior.mob_hall, "dormitorio": interior.mob_dormitorio}

    # ------------------------------------------------------------------ peças genéricas (medidas passadas explicitamente)
    def bloco(nome, W, D, andares, parede, janela_cor, telhado="laje", telha="telha", porta_frente=0.0,
              jan_frente=(), jan_lado=(), pe=3.0, platibanda=0.6, escada_int=True):
        """Prédio retangular de 1+ andares: porta na frente (-Y, vão 1,4 x 2,3), janelas nas fachadas, laje entre pisos,
        escada interna encostada na parede do fundo (degraus de pe/12 m), cobertura em laje com platibanda ou duas águas."""
        k = Kit(nome)
        e = 0.2
        x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
        k.caixa(x0 - 0.2, y0 - 0.8, -0.3, x1 + 0.2, y1 + 0.2, 0.15, "concreto_escuro")
        for a in range(andares):
            z0 = 0.15 + a * pe
            z1 = z0 + pe
            vf = [(c, 1.3, z0 + 1.0, z0 + 2.2) for c in jan_frente]
            if a == 0:
                vf = [(porta_frente, 1.4, z0, z0 + 2.3)] + [v for v in vf if abs(v[0] - porta_frente) > 1.4]
            k.parede("x", x0, x1, y0, z0, z1, e, parede, vaos=vf, lado=1)
            k.parede("x", x0, x1, y1, z0, z1, e, parede, vaos=[(c, 1.3, z0 + 1.0, z0 + 2.2) for c in jan_frente], lado=-1)
            for f, lado in ((x0, 1), (x1, -1)):
                k.parede("y", y0 + e, y1 - e, f, z0, z1, e, parede, vaos=[(c, 1.3, z0 + 1.0, z0 + 2.2) for c in jan_lado], lado=lado)
            for c in jan_frente:
                if a > 0 or abs(c - porta_frente) > 1.4:
                    k.janela("x", c, y0, z0 + 1.0, z0 + 2.2, 1.3, janela_cor, lado=-1, venezianas=False)
            if a > 0 and escada_int:                                # piso com o vão da escada aberto
                k.caixa(x0 + e, y0 + e, z0 - 0.02, x1 - 3.2, y1 - e, z0 + 0.02, "piso")
                k.caixa(x1 - 3.2, y0 + e, z0 - 0.02, x1 - e, y1 - 4.2, z0 + 0.02, "piso")
            else:
                k.caixa(x0 + e, y0 + e, z0 - 0.02, x1 - e, y1 - e, z0 + 0.02, "piso")
            if a > 0:                                               # laje com vão da escada
                k.caixa(x0, y0, z0 - 0.18, x1 - 3.2, y1, z0, "concreto")
                k.caixa(x1 - 3.2, y0, z0 - 0.18, x1, y1 - 4.2, z0, "concreto")
            if escada_int and a < andares - 1:
                for i in range(12):                                     # lance de 12 degraus (0,25-0,3 m) com patamar de 0,8 m no pé
                    z = z0 + (i + 1) * pe / 12
                    yy = y1 - 1.0 - i * 0.26
                    k.caixa(x1 - 1.4, yy - 0.26, z - 0.18, x1 - 0.25, yy, z, "concreto")
                k.caixa(x1 - 1.4, y1 - 4.2, z0 + pe - 0.18, x1 - 0.25, y1 - 4.12, z0 + pe, "concreto")      # patamar do último degrau
                k.lance_teste(x1 - 0.83, y1 - 0.6, 0, -1, z0 + pe + 0.02, x1 - 0.83, y1 - 4.7)
        k.folha("x", porta_frente, y0, 1.4, 2.3, janela_cor, 1, z0=0.15, dir=1)
        zt = 0.15 + andares * pe
        if telhado == "laje":
            k.caixa(x0 - 0.1, y0 - 0.1, zt, x1 + 0.1, y1 + 0.1, zt + 0.2, "concreto")
            if platibanda > 0:
                for (a0, a1, f, eixo, lado) in ((x0, x1, y0, "x", 1), (x0, x1, y1, "x", -1), (y0, y1, x0, "y", 1), (y0, y1, x1, "y", -1)):
                    k.parede(eixo, a0, a1, f, zt + 0.2, zt + 0.2 + platibanda, 0.15, parede, lado=lado)
        else:
            k.telhado_duas_aguas(x0, x1, y0, y1, zt, min(W, D) * 0.22, 0.5, telha, parede, cumeeira_x=W > D)
            k.caixa(x0 + e, y0 + e, zt - 0.12, x1 - e, y1 - e, zt, "reboco_branco")        # forro
        k.g = dict(x0=x0, x1=x1, y0=y0, y1=y1, e=e, pe=pe, andares=andares, parede=parede, porta=porta_frente,
                   zf=[0.17 + a * pe for a in range(andares)], zc=[0.15 + (a + 1) * pe for a in range(andares)],
                   jf=tuple(jan_frente), jl=tuple(jan_lado), escada=escada_int)
        return k

    def plano_bloco(k, tipos, frac=0.5, loot=(), mobilia=None):
        """Divide cada andar em frente | fundos-esquerda | hall da escada (direita). tipos[a] = (frente, fundos, hall).
        Portas de 1,1 m: frente->hall (divisória em Y) e hall->fundos (divisória em X)."""
        g = k.g
        x0, x1, y0, y1, e, par = g["x0"], g["x1"], g["y0"], g["y1"], g["e"], g["parede"]
        ym = round(y0 + frac * (y1 - y0), 2)
        xs = x1 - 3.5
        dfh = xs + 1.1                                    # porta frente <-> hall
        dhf = ym + 0.85                                   # porta hall <-> fundos
        rooms = {}
        for a in range(g["andares"]):
            zf, zc = g["zf"][a], g["zc"][a]
            k.parede("x", x0 + e, x1 - e, ym, zf, zc, 0.1, par, vaos=[(dfh, 1.1, zf, zf + 2.1)])
            k.parede("y", ym + 0.1, y1 - e, xs, zf, zc, 0.1, par, vaos=[(dhf, 1.1, zf, zf + 2.1)])
            tf, tb, th = tipos[a]
            jan_f = [(c, y0 + e, 1.3) for c in g["jf"]]
            jan_b = [(c, y1 - e, 1.3) for c in g["jf"] if c < xs - 0.7]
            jan_lf = [(x0 + e, c, 1.3) for c in g["jl"] if c < ym - 0.7] + [(x1 - e, c, 1.3) for c in g["jl"] if c < ym - 0.7]
            jan_lb = [(x0 + e, c, 1.3) for c in g["jl"] if c > ym + 0.7]
            pf = [(dfh, ym)] + ([(g["porta"], y0 + e, 1.4)] if a == 0 else [])
            fr = C(k, tf, (x0 + e, y0 + e, x1 - e, ym), zf, portas=pf, janelas=jan_f + jan_lf, tipo=tf)
            fu = C(k, tb, (x0 + e, ym + 0.1, xs, y1 - e), zf, portas=[(xs, dhf)], janelas=jan_b + jan_lb, tipo=tb)
            ha = C(k, th, (xs + 0.1, ym + 0.1, x1 - e, y1 - e), zf, portas=[(dfh, ym + 0.1), (xs + 0.1, dhf)], tipo=th)
            if g["andares"] == 1:
                pass
            elif a == 0:
                ha.ocupado.append((x1 - 1.5, y1 - 4.2, x1 - 0.2, y1 - 1.0))                # lance da escada (o patamar do pé fica livre)
            else:
                ha.ocupado.append((x1 - 3.3, y1 - 4.3, x1 - 0.2, y1 - 0.2))                # vão da escada
                k.caixa(x1 - 3.3, y1 - 4.2, zf, x1 - 3.2, y1 - e, zf + 0.95, "ferro")        # guarda-corpo do vão (oeste)
                k.caixa(x1 - 3.2, y1 - 4.25, zf, x1 - 1.5, y1 - 4.2, zf + 0.95, "ferro")    # e (sul); a saída do lance fica aberta
            rooms[(a, "frente")], rooms[(a, "fundos")], rooms[(a, "hall")] = fr, fu, ha
        for a, nomes in enumerate(tipos):
            for nome_c, c in zip(("frente", "fundos", "hall"), nomes):
                if c in mob:
                    mob[c](rooms[(a, nome_c)], **(mobilia or {}).get((a, nome_c), {}))
        for (a, lugar, parede_l, fr_, tier) in loot:
            rooms[(a, lugar)].loot(parede_l, fr_, tier)
        return rooms

    def galpao_vao(nome, W, D, H, parede, telha, portao_larg=6.0, janelas=True, portao_fundo=True, e=0.2):
        k = Kit(nome)
        x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
        zp = 0.12
        k.caixa(x0, y0, -0.3, x1, y1, zp, "concreto_escuro")
        k.parede("x", x0, x1, y0, zp, H, e, parede, vaos=[(0.0, portao_larg, zp, min(H - 0.8, 5.0))], lado=1)
        k.parede("x", x0, x1, y1, zp, H, e, parede, vaos=[(0.0, portao_larg, zp, min(H - 0.8, 5.0))] if portao_fundo else [(x1 - 2, 1.1, zp, zp + 2.15)], lado=-1)
        n = max(2, int(D // 6))
        jan = [(y0 + (i + 0.5) * D / n, 1.6, H * 0.55, H * 0.8) for i in range(n)] if janelas else []
        for f, lado in ((x0, 1), (x1, -1)):
            k.parede("y", y0 + e, y1 - e, f, zp, H, e, parede, vaos=jan, lado=lado)
            for (c, lg, zb, zt) in jan:                                   # caixilho + vidro nos vãos (crítica 03, ajuste 6)
                k.janela("y", c, f, zb, zt, lg, "janela_verde", lado=lado, venezianas=False)
        k.telhado_duas_aguas(x0, x1, y0, y1, H, W * 0.12, 0.6, telha, parede, cumeeira_x=False)
        k.entrada(0.0, y0 - 1.3, 0, 1)
        k.entrada(0.0 if portao_fundo else x1 - 2, y1 + 1.3, 0, -1)
        portas = [(0.0, y0 + e, portao_larg)] + ([(0.0, y1 - e, portao_larg)] if portao_fundo else [(x1 - 2, y1 - e, 1.1)])
        k.c = C(k, nome, (x0 + e, y0 + e, x1 - e, y1 - e), zp, portas=portas, tipo="galpao")
        k.dim = (x0, x1, y0, y1, zp, e)
        return k

    def torre_quadrada(k, lado, z0, z1, cor, porta=None):
        h = lado / 2
        for (a0, a1, f, eixo, ld) in ((-h, h, -h, "x", 1), (-h, h, h, "x", -1), (-h + 0.2, h - 0.2, -h, "y", 1), (-h + 0.2, h - 0.2, h, "y", -1)):
            vaos = [(0.0, 0.9, z1 - 2.2, z1 - 0.8)]
            if porta and eixo == "x" and f == -h:
                vaos = [porta]
            k.parede(eixo, a0, a1, f, z0, z1, 0.2, cor, vaos=vaos, lado=ld)

    # ------------------------------------------------------------------ Vila / Morro / Praia
    if quer("capela"):
        k = Kit("capela_a")
        W, D, H = 8.0, 16.0, 6.0
        k.caixa(-4.4, -9.5, -0.3, 4.4, 8.4, 0.3, "concreto_escuro")
        for i, (y0, h) in enumerate(((-9.4, 0.1), (-9.0, 0.2))):         # adro com 2 degraus
            k.caixa(-2.2, y0 - 0.4, 0.0, 2.2, y0, 0.3 - i * 0.1, "concreto")
        k.parede("x", -4, 4, -8, 0.3, 4.2, 0.3, "reboco_branco", vaos=[(0.0, 1.8, 0.3, 3.4)], lado=1)     # portal (vão livre 1,8 x 3,1 m)
        k.parede("x", -4, 4, -8, 4.2, H, 0.3, "reboco_branco", vaos=[(0.0, 1.2, 4.2, 5.4)], lado=1)     # rosácea acima
        k.parede("x", -4, 4, 8, 0.3, H, 0.3, "reboco_branco", vaos=[], lado=-1)
        for f, ld in ((-4, 1), (4, -1)):
            k.parede("y", -7.7, 7.7, f, 0.3, H, 0.3, "reboco_branco", vaos=[(c, 1.0, 2.6, 4.6) for c in (-4.5, 0.0, 4.5)], lado=ld)
        k.caixa(-4.05, -8.05, 0.3, -0.9, -7.7, 1.0, "barra_azul")         # barra azul (vão da porta livre)
        k.caixa(0.9, -8.05, 0.3, 4.05, -7.7, 1.0, "barra_azul")
        k.telhado_duas_aguas(-4, 4, -8, 8, H, 3.2, 0.5, "telha", "reboco_branco", cumeeira_x=False)
        # frontão com cruz
        k.prisma([(-4, -8.2, H), (4, -8.2, H), (0, -8.2, H + 3.6)], (0, 0.3, 0), "reboco_branco")
        k.caixa(-0.1, -8.35, H + 3.6, 0.1, -8.15, H + 5.0, "madeira")
        k.caixa(-0.5, -8.35, H + 4.4, 0.5, -8.15, H + 4.6, "madeira")
        # bancos
        for y in (-5.5, -3.5, -1.5, 0.5, 2.5):
            for s in (-1, 1):
                k.caixa(s * 0.8, y, 0.3, s * 3.3, y + 0.4, 0.75, "madeira")
        k.caixa(-1.5, 6.0, 0.3, 1.5, 7.2, 1.2, "reboco_branco")           # altar
        k.entrada(0.0, -9.3, 0, 1)
        k.ponto(-3.0, 5.0, 0.3, 90.0, "baixo", "sala")
        k.ponto(3.0, 5.0, 0.3, 270.0, "baixo", "sala")
        k.fim()

    if quer("sobrado"):
        k = bloco("sobrado_a", 8, 10, 2, "reboco_azul", "janela_azul", telhado="duas", jan_frente=(-2.2, 2.2), jan_lado=(-2.5, 2.5))
        plano_bloco(k, [("sala", "cozinha", "hall"), ("quarto", "quarto", "hall")], frac=0.44,
                    loot=[(0, "frente", "W", 0.1, "baixo"), (0, "fundos", "S", 0.2, "medio"), (1, "frente", "E", 0.3, "baixo"), (1, "fundos", "N", 0.6, "baixo")])
        k.fim()
        k = bloco("sobrado_b", 8, 10, 2, "reboco_rosa", "janela_verde", telhado="duas", jan_frente=(-2.2, 2.2), jan_lado=(-3.0, 3.0))
        plano_bloco(k, [("sala", "cozinha", "hall"), ("quarto", "quarto", "hall")], frac=0.44,
                    loot=[(0, "frente", "W", 0.1, "baixo"), (0, "fundos", "S", 0.2, "medio"), (1, "frente", "E", 0.3, "baixo"), (1, "fundos", "N", 0.6, "baixo")])
        k.fim()

    if quer("cruzeiro"):
        k = Kit("cruzeiro_a")
        k.caixa(-1.0, -1.0, -0.3, 1.0, 1.0, 0.6, "concreto")
        k.caixa(-0.18, -0.18, 0.6, 0.18, 0.18, 8.0, "madeira")
        k.caixa(-1.6, -0.16, 5.6, 1.6, 0.16, 5.95, "madeira")
        k.fim()

    if quer("banheiro_praia"):
        k = bloco("banheiro_praia_a", 6, 4, 1, "reboco_azul", "ferro", jan_lado=(0.0,), platibanda=0.0, escada_int=False)
        b = C(k, "banheiro", (-2.8, -1.8, 2.8, 1.8), 0.17, portas=[(0.0, -1.8, 1.4)], janelas=[(-2.8, 0.0, 1.3), (2.8, 0.0, 1.3)], tipo="sala")
        b.enc("vaso", "N", 0.1, w=0.4)
        b.enc("vaso", "N", 0.4, w=0.4)
        b.enc("vaso", "N", 0.7, w=0.4)
        b.enc("lavatorio", "S", 0.95, w=0.6)
        b.enc("lavatorio", "S", 0.75, w=0.6)
        k.fim()

    if quer("restaurante_praia"):
        k = bloco("restaurante_praia_a", 10, 12, 2, "reboco_amarelo", "janela_azul", telhado="duas", jan_frente=(-3.0, 3.0), jan_lado=(-3.5, 3.5))
        for x in (-4.6, 4.6):                                       # deck de madeira na frente
            k.caixa(x - 0.12, -9.0, 0.15, x + 0.12, -8.76, 3.0, "madeira")
        k.caixa(-5.2, -9.2, 0.15, 5.2, -6.0, 0.3, "madeira_clara")
        k.caixa(-5.2, -9.2, 3.0, 5.2, -6.0, 3.15, "sape")
        plano_bloco(k, [("salao", "cozinha", "hall"), ("quarto", "sala", "hall")], frac=0.5,
                    loot=[(0, "frente", "W", 0.5, "baixo"), (0, "fundos", "N", 0.85, "medio"), (1, "frente", "E", 0.3, "baixo")])
        k.fim()

    if quer("posto_salvavidas"):
        k = Kit("posto_salvavidas_a")
        for x, y in ((-1.3, -1.3), (1.3, -1.3), (-1.3, 1.3), (1.3, 1.3)):
            k.caixa(x - 0.1, y - 0.1, 0.0, x + 0.1, y + 0.1, 2.6, "madeira")
        k.caixa(-1.5, -1.5, 2.6, 1.5, 1.5, 2.75, "madeira_clara")
        k.parede("x", -1.5, 1.5, 1.5, 2.75, 4.6, 0.08, "placa", lado=-1)
        k.parede("y", -1.4, 1.4, -1.5, 2.75, 3.6, 0.08, "reboco_amarelo", lado=1)
        k.parede("y", -1.4, 1.4, 1.5, 2.75, 3.6, 0.08, "reboco_amarelo", lado=-1)
        k.caixa(-1.8, -1.8, 4.6, 1.8, 1.8, 4.75, "placa")                       # telhado (2,1 m de pé-direito sobre a plataforma)
        k.lance((-0.5, -4.2, 0.5, -1.5), "+y", 9, 0.0, 2.55, "madeira_clara", macico=False, espessura=0.12)   # escada inclinada até a plataforma
        k.lance_teste(0.0, -4.9, 0, 1, 2.75, 0.0, -0.8)
        k.fim()

    # ------------------------------------------------------------------ Usina Santa Cruz
    if quer("casa_moenda"):
        k = galpao_vao("casa_moenda_a", 15, 25, 9, "tijolo", "telha", portao_larg=5.0)
        k.caixa(-6.5, -2, 4.0, 6.5, 10.0, 4.2, "concreto")                  # mezanino da moenda
        for i in range(14):                                                 # escada até o mezanino: degraus de 0,29 m
            z = 0.12 + (i + 1) * 0.29
            k.caixa(-7.0, -2 - (14 - i) * 0.3, z - 0.2, -5.8, -2 - (13 - i) * 0.3, z, "concreto")
        k.caixa(-6.45, -2.05, 4.2, 6.45, -2.0, 5.1, "ferro")                # guarda-corpo do mezanino (lado da escada aberto)
        k.lance_teste(-6.4, -7.2, 0, 1, 4.2, -6.4, -1.0)
        for x in (-3.0, 0.0, 3.0):                                      # moendas (rolos) sob o mezanino
            k.caixa(x - 1.0, 4.0, 0.12, x + 1.0, 7.0, 2.2, "ferro")
        c = k.c
        c.ocupado.append((-7.3, -6.4, -5.6, -1.9))
        c.ocupado.append((-4.2, 3.8, 4.2, 7.2))
        c.ocupado.append((-1.5, -12.3, 1.5, 12.3))
        for f in (0.15, 0.5, 0.85):
            c.enc("estante_carga", "E", f, w=1.6)
        c.enc("estante_carga", "W", 0.9, w=1.6)
        c.livre("pallet", 4.5, -9.0, 0)
        c.livre("pallet", -4.5, -9.5, 90)
        c.livre("caixotes", 5.0, 9.5, 0)
        c.livre("tambores", -5.5, 9.5, 0)
        c.loot("E", 0.3, "medio")
        c.loot("E", 0.75, "medio")
        c.loot("W", 0.88, "medio")
        c.loot_livre(4.5, -6.0, 180.0, "medio")
        k.fim()

    if quer("chamine"):
        k = Kit("chamine_a")
        k.caixa(-2.2, -2.2, -0.3, 2.2, 2.2, 2.0, "tijolo_escuro")
        segs = [(2.0, 1.8), (10.0, 1.55), (20.0, 1.3), (30.0, 1.1), (39.0, 0.95)]
        for (z0, r0), (z1, r1) in zip(segs[:-1], segs[1:]):
            k.prisma([(-r0, -r0, z0), (r0, -r0, z0), (r0, r0, z0), (-r0, r0, z0)], (0, 0, z1 - z0), "tijolo")
        k.caixa(-1.15, -1.15, 39.0, 1.15, 1.15, 40.0, "tijolo_escuro")
        k.fim()

    if quer("armazem_acucar"):
        k = galpao_vao("armazem_acucar_a", 15, 40, 9, "reboco_branco", "telha_escura", portao_larg=5.0)
        c = k.c
        c.ocupado.append((-1.5, -19.8, 1.5, 19.8))
        for f in (0.1, 0.3, 0.5, 0.7, 0.9):
            c.enc("estante_carga", "W", f, w=1.6)
        for i in range(5):
            y = -16.0 + i * 7.0
            c.livre("fardos", 4.4, y, 0)
            c.livre("pallet", -4.4, y + 1.5, 90 if i % 2 else 0)
        c.loot("W", 0.2, "medio")
        c.loot("W", 0.6, "medio")
        c.loot_livre(5.5, -12.0, 270.0, "medio")
        c.loot_livre(5.5, 2.0, 270.0, "medio")
        c.loot_livre(-5.5, 14.0, 90.0, "medio")
        k.fim()

    if quer("escritorio"):
        k = bloco("escritorio_a", 10, 14, 2, "reboco_amarelo", "janela_verde", telhado="duas", jan_frente=(-3.0, 3.0), jan_lado=(-4.0, 4.5))
        plano_bloco(k, [("escritorio", "cozinha", "hall"), ("reuniao", "escritorio", "hall")], frac=0.5,
                    loot=[(0, "frente", "W", 0.5, "medio"), (0, "fundos", "N", 0.9, "medio"), (1, "fundos", "W", 0.5, "medio")])
        k.fim()

    # ------------------------------------------------------------------ Farol
    if quer("farol_torre"):
        k = Kit("farol_torre_a")
        k.caixa(-3.2, -3.2, -0.3, 3.2, 3.2, 0.3, "concreto")
        lados = 8
        rr = {}
        for z0, z1, r0, r1, cor in ((0.3, 7.0, 2.6, 2.3, "reboco_branco"), (7.0, 13.0, 2.3, 2.0, "placa"), (13.0, 19.0, 2.0, 1.75, "reboco_branco")):
            base = [(r0 * math.cos(a), r0 * math.sin(a), z0) for a in [i * math.tau / lados for i in range(lados)]]
            k.prisma(base, (0, 0, z1 - z0), cor)
            rr[(z0, z1)] = r0
        k.caixa(-2.6, -2.6, 19.0, 2.6, 2.6, 19.25, "concreto")               # varanda
        for i in range(12):
            if i == 0:
                continue                                                     # abertura do guarda-corpo onde chega a escada (leste)
            a = i * math.tau / 12
            k.caixa(2.45 * math.cos(a) - 0.04, 2.45 * math.sin(a) - 0.04, 19.25, 2.45 * math.cos(a) + 0.04, 2.45 * math.sin(a) + 0.04, 20.3, "ferro")
        base = [(1.3 * math.cos(a), 1.3 * math.sin(a), 19.25) for a in [i * math.tau / lados for i in range(lados)]]
        k.prisma(base, (0, 0, 2.0), "vidro")
        k.prisma([(1.5 * math.cos(a), 1.5 * math.sin(a), 21.25) for a in [i * math.tau / lados for i in range(lados)]], (0, 0, 0.3), "placa")
        k.caixa(-0.9, -2.75, 0.3, 0.9, -2.3, 2.5, "madeira")                   # porta (relevo)
        # escada de marinheiro externa (face leste, 19 m) até a varanda; suportes a cada 3 m ligam os degraus ao fuste
        for z, r in ((3.0, 2.6), (6.0, 2.6), (9.0, 2.3), (12.0, 2.3), (15.0, 2.0), (18.0, 2.0)):
            k.caixa(r - 0.05, -0.3, z, 2.75, 0.3, z + 0.06, "ferro")
        k.escada_mao("f1", 2.7, 0.0, 0.3, 19.25, 1, 0, sai=0.9)
        k.fim()

    if quer("casa_faroleiro"):
        k = bloco("casa_faroleiro_a", 8, 10, 1, "reboco_branco", "janela_azul", telhado="duas", jan_frente=(-2.5, 2.5), jan_lado=(-2.5, 2.5))
        plano_bloco(k, [("sala", "cozinha", "quarto")], frac=0.5, loot=[(0, "frente", "W", 0.2, "baixo"), (0, "fundos", "S", 0.3, "medio"), (0, "hall", "E", 0.5, "baixo")])
        k.fim()
    if quer("casa_gerador"):
        k = bloco("casa_gerador_a", 5, 6, 1, "concreto", "ferro", jan_lado=(-1.6, 1.8), platibanda=0.0, escada_int=False)
        pequena(k, C, "Sala de controle")
        k.fim()

    # ------------------------------------------------------------------ Quartel do 7º BIL
    if quer("comando"):
        k = bloco("comando_a", 24, 14, 2, "reboco_ocre", "janela_verde", jan_frente=(-9.0, -6.0, -3.0, 3.0, 6.0, 10.0), jan_lado=(-4.0, 3.0))
        k.caixa(-3.0, -8.5, 0.15, 3.0, -7.0, 0.35, "concreto")               # pórtico de entrada
        for x in (-2.8, 2.8):
            k.caixa(x - 0.25, -8.4, 0.35, x + 0.25, -7.9, 6.2, "reboco_branco")
        k.caixa(-3.2, -8.8, 6.2, 3.2, -7.0, 6.6, "reboco_branco")
        k.caixa(-0.05, -8.6, 6.6, 0.05, -8.5, 12.0, "ferro")                   # mastro
        k.caixa(0.05, -8.58, 10.8, 1.6, -8.52, 11.8, "barra_verde")
        plano_bloco(k, [("escritorio", "reuniao", "hall"), ("escritorio", "quarto", "hall")], frac=0.45,
                    mobilia={(0, "frente"): {"mesas": 5}, (1, "frente"): {"mesas": 5}, (1, "fundos"): {"largura": 1.1}},
                    loot=[(0, "frente", "W", 0.5, "alto"), (0, "frente", "E", 0.3, "alto"), (0, "fundos", "S", 0.4, "alto"), (1, "frente", "N", 0.6, "alto"), (1, "fundos", "W", 0.3, "alto")])
        k.fim()
    if quer("alojamento"):
        k = galpao_vao("alojamento_a", 12, 30, 4, "reboco_ocre", "telha", portao_larg=1.4)
        x0, x1, y0, y1, zp, e = k.dim
        k.parede("x", x0 + e, x1 - e, 0.0, zp, 4.0, 0.1, "reboco_ocre", vaos=[(0.0, 1.4, zp, zp + 2.2)])
        a = C(k, "dormitorio_a", (x0 + e, y0 + e, x1 - e, -0.05), zp, portas=[(0.0, y0 + e, 1.4), (0.0, -0.05, 1.4)], tipo="quarto")
        b = C(k, "dormitorio_b", (x0 + e, 0.15, x1 - e, y1 - e), zp, portas=[(0.0, 0.15, 1.4), (0.0, y1 - e, 1.4)], tipo="quarto")
        for c in (a, b):
            interior.mob_dormitorio(c, n=4)
        a.loot("W", 0.4, "alto")
        b.loot("E", 0.4, "alto")
        a.loot("N", 0.9, "alto")
        b.loot("S", 0.9, "alto")
        k.fim()
    if quer("refeitorio"):
        k = galpao_vao("refeitorio_a", 20, 12, 5, "reboco_ocre", "telha", portao_larg=2.4)
        x0, x1, y0, y1, zp, e = k.dim
        k.parede("x", x0 + e, x1 - e, 2.0, zp, 5.0, 0.1, "reboco_ocre", vaos=[(-3.0, 1.4, zp, zp + 2.1), (4.0, 1.4, zp, zp + 2.1)])
        sal = C(k, "salao", (x0 + e, y0 + e, x1 - e, 1.95), zp, portas=[(0.0, y0 + e, 2.4), (-3.0, 1.95, 1.4), (4.0, 1.95, 1.4)], tipo="sala")
        coz = C(k, "cozinha", (x0 + e, 2.1, x1 - e, y1 - e), zp, portas=[(0.0, y1 - e, 2.4), (-3.0, 2.1, 1.4), (4.0, 2.1, 1.4)], tipo="cozinha")
        for yy in (-4.3, -2.3, -0.3):
            for xx in (-5.5, 5.5):
                sal.livre("mesa_longa", xx, yy, 0, w=3.0, d=0.8)
                sal.livre("banco_longo", xx, yy + 0.65, 0)
                sal.livre("banco_longo", xx, yy - 0.65, 180)
        coz.enc("pia", "N", 0.1, w=1.6)
        coz.enc("fogao", "N", 0.3)
        coz.enc("fogao", "N", 0.45)
        coz.enc("geladeira", "N", 0.7)
        coz.enc("geladeira", "N", 0.85)
        coz.enc("armario_baixo", "W", 0.5, w=1.4)
        coz.livre("balcao", 4.0, 4.2, 0, w=3.0, d=0.7)
        sal.loot("W", 0.5, "alto")
        sal.loot("E", 0.5, "alto")
        coz.loot("W", 0.8, "alto")
        coz.loot("E", 0.3, "alto")
        k.fim()
    if quer("garagem_viaturas"):
        k = galpao_vao("garagem_viaturas_a", 25, 15, 6, "verde_militar", "zinco", portao_larg=9.0, janelas=False, portao_fundo=False)
        c = k.c
        c.ocupado.append((-7.0, -7.3, 7.0, 3.0))                                # vaga das viaturas (área livre central)
        for f in (0.2, 0.5, 0.8):
            c.enc("bancada", "N", f, w=2.4)
        c.enc("estante_carga", "W", 0.2, w=1.6)
        c.enc("estante_carga", "W", 0.5, w=1.6)
        c.enc("estante_carga", "W", 0.8, w=1.6)
        c.enc("estante_carga", "E", 0.2, w=1.6)
        c.enc("estante_carga", "E", 0.5, w=1.6)
        c.enc("tambores", "S", 0.05)
        c.enc("tambores", "S", 0.95)
        c.enc("caixotes", "E", 0.8)
        c.loot("N", 0.12, "alto")
        c.loot("N", 0.88, "alto")
        c.loot("W", 0.95, "alto")
        c.loot_livre(-7.6, 4.5, 0.0, "alto")                                   # junto às viaturas
        c.loot_livre(7.6, 4.5, 0.0, "alto")
        k.fim()
    if quer("heliponto"):
        k = Kit("heliponto_a")
        k.caixa(-10, -10, -0.3, 10, 10, 0.3, "concreto")
        k.caixa(-7, -7, 0.3, 7, -6.6, 0.32, "reboco_amarelo")
        k.caixa(-7, 6.6, 0.3, 7, 7, 0.32, "reboco_amarelo")
        k.caixa(-7, -6.6, 0.3, -6.6, 6.6, 0.32, "reboco_amarelo")
        k.caixa(6.6, -6.6, 0.3, 7, 6.6, 0.32, "reboco_amarelo")
        for x in (-2.0, 2.0):                                             # letra H
            k.caixa(x - 0.4, -3.0, 0.3, x + 0.4, 3.0, 0.33, "reboco_branco")
        k.caixa(-1.6, -0.4, 0.3, 1.6, 0.4, 0.33, "reboco_branco")
        k.fim()
    if quer("tanque"):
        k = Kit("tanque_a")
        k.prisma([(3.0 * math.cos(a), 3.0 * math.sin(a), 0.0) for a in [i * math.tau / 12 for i in range(12)]], (0, 0, 5.2), "zinco")
        k.prisma([(3.1 * math.cos(a), 3.1 * math.sin(a), 5.2) for a in [i * math.tau / 12 for i in range(12)]], (0, 0, 0.3), "concreto_escuro")
        k.escada_mao("t1", 3.0, 0.0, 0.0, 5.5, 1, 0, sai=1.0)            # escada de marinheiro até o topo do tanque
        k.fim()

    # ------------------------------------------------------------------ Pista do Tauá
    if quer("hangar"):
        k = galpao_vao("hangar_a", 24, 20, 8, "zinco", "zinco_ferrugem", portao_larg=18.0, janelas=True, portao_fundo=False)
        c = k.c
        c.ocupado.append((-8.0, -9.5, 8.0, 6.0))                                # vaga da aeronave
        for f in (0.15, 0.4, 0.65, 0.9):
            c.enc("estante_carga", "W", f, w=1.6)
        for f in (0.2, 0.5, 0.8):
            c.enc("estante_carga", "E", f, w=1.6)
        c.enc("bancada", "N", 0.2, w=2.4)
        c.enc("bancada", "N", 0.5, w=2.4)
        c.enc("tambores", "N", 0.85)
        c.enc("caixotes", "E", 0.95)
        c.loot("W", 0.3, "alto")
        c.loot("E", 0.65, "alto")
        c.loot("N", 0.35, "alto")
        c.loot_livre(-9.0, -4.0, 90.0, "alto")                                 # junto à aeronave
        c.loot_livre(9.0, -4.0, 270.0, "alto")
        k.fim()
    if quer("torre_controle"):
        k = Kit("torre_controle_a")
        k.caixa(-2.6, -2.6, -0.3, 2.6, 2.6, 0.15, "concreto_escuro")
        torre_quadrada(k, 5.0, 0.15, 9.0, "reboco_branco", porta=(1.0, 1.1, 0.15, 2.3))
        k.folha("x", 1.0, -2.5, 1.1, 2.15, "porta_aco", 1, z0=0.15, dir=-1)
        # laje da cabine com alçapão (x -1,5..-0,5 / y 1,2..2,3) para a escada de mão que sobe pela parede norte
        k.caixa(-3.0, -3.0, 9.0, -1.5, 3.0, 9.2, "concreto")
        k.caixa(-0.5, -3.0, 9.0, 3.0, 3.0, 9.2, "concreto")
        k.caixa(-1.5, -3.0, 9.0, -0.5, 1.2, 9.2, "concreto")
        k.caixa(-1.5, 2.3, 9.0, -0.5, 3.0, 9.2, "concreto")
        k.escada_mao("tc1", -1.0, 2.15, 0.15, 9.2, 0, -1, saida=(0.3, 1.73))
        for (a0, a1, f, eixo, ld) in ((-3, 3, -3, "x", 1), (-3, 3, 3, "x", -1), (-2.8, 2.8, -3, "y", 1), (-2.8, 2.8, 3, "y", -1)):
            k.parede(eixo, a0, a1, f, 9.2, 11.8, 0.15, "reboco_branco", vaos=[(0.0, 5.0, 10.0, 11.6)], lado=ld)
            k.janela(eixo, 0.0, f, 10.0, 11.6, 5.0, "ferro", lado=-ld, venezianas=False)
        k.caixa(-3.2, -3.2, 11.8, 3.2, 3.2, 12.1, "concreto")
        t = C(k, "torre", (-2.3, -2.3, 2.3, 2.3), 0.15, portas=[(1.0, -2.3)], tipo="sala")
        t.ocupado.append((-1.6, 1.0, -0.4, 2.35))                               # pé da escada de mão
        t.enc("mesa_escritorio", "E", 0.5, w=1.3, d=0.7)
        t.enc("arquivo", "E", 0.9)
        t.loot("W", 0.3, "medio")
        t.loot("E", 0.05, "medio")
        k.fim()
    if quer("casa_piloto"):
        k = bloco("casa_piloto_a", 7, 9, 1, "reboco_azul", "janela_azul", telhado="duas", jan_frente=(2.0,), jan_lado=(-2.0, 2.2))
        plano_bloco(k, [("sala", "cozinha", "quarto")], frac=0.5, loot=[(0, "frente", "W", 0.3, "baixo"), (0, "fundos", "S", 0.4, "medio"), (0, "hall", "E", 0.8, "baixo")])
        k.fim()

    # ------------------------------------------------------------------ Represa
    if quer("casa_forca"):
        k = galpao_vao("casa_forca_a", 12, 18, 9, "concreto", "telha_escura", portao_larg=4.0)
        for x in (-3.0, 3.0):                                             # turbinas
            k.prisma([(x + 1.3 * math.cos(a), 2 + 1.3 * math.sin(a), 0.12) for a in [i * math.tau / 10 for i in range(10)]], (0, 0, 2.4), "barra_azul")
        c = k.c
        c.ocupado.append((-4.5, 0.5, 4.5, 3.5))
        c.ocupado.append((-2.2, -8.8, 2.2, 8.8))
        c.enc("bancada", "N", 0.2, w=2.4)
        c.enc("bancada", "N", 0.8, w=2.4)
        c.enc("estante_carga", "W", 0.25, w=1.6)
        c.enc("estante_carga", "E", 0.25, w=1.6)
        c.enc("arquivo", "E", 0.7)
        c.livre("pallet", -4.0, -6.0, 0)
        c.livre("caixotes", 4.0, -6.5, 0)
        c.loot("W", 0.6, "medio")
        c.loot("E", 0.5, "medio")
        c.loot("N", 0.5, "medio")
        c.loot_livre(-4.5, -3.0, 90.0, "medio")
        k.fim()
    if quer("casa_operador"):
        k = bloco("casa_operador_a", 7, 9, 1, "reboco_branco", "janela_verde", telhado="duas", jan_frente=(2.0,), jan_lado=(-2.0, 2.2))
        plano_bloco(k, [("sala", "cozinha", "quarto")], frac=0.5, loot=[(0, "frente", "W", 0.3, "baixo"), (0, "fundos", "S", 0.4, "medio"), (0, "hall", "E", 0.8, "baixo")])
        k.fim()
    if quer("subestacao"):
        k = Kit("subestacao_a")
        k.caixa(-7, -5, -0.3, 7, 5, 0.1, "concreto_escuro")
        for x in (-4.5, 0.0, 4.5):
            k.caixa(x - 1.0, -1.2, 0.1, x + 1.0, 1.2, 2.4, "zinco")             # transformadores
            for dx in (-0.6, 0.0, 0.6):
                k.caixa(x + dx - 0.08, -0.08, 2.4, x + dx + 0.08, 0.08, 3.4, "reboco_branco")
        for x in (-6.5, 6.5):                                              # pórticos de linha
            for y in (-4.5, 4.5):
                k.caixa(x - 0.15, y - 0.15, 0.1, x + 0.15, y + 0.15, 6.0, "ferro")
            k.caixa(x - 0.15, -4.5, 5.8, x + 0.15, 4.5, 6.0, "ferro")
        for (a0, a1, f, eixo, ld) in ((-7, 7, -5, "x", 1), (-7, 7, 5, "x", -1), (-4.9, 4.9, -7, "y", 1), (-4.9, 4.9, 7, "y", -1)):
            k.parede(eixo, a0, a1, f, 0.1, 2.0, 0.05, "ferro", vaos=[(0.0, 3.0, 0.1, 2.0)] if f == -5 else [], lado=ld)
        k.fim()
    if quer("torre_tomada"):
        k = Kit("torre_tomada_a")
        torre_quadrada(k, 5.0, -6.0, 12.0, "concreto")
        k.caixa(-2.8, -2.8, 12.0, 2.8, 2.8, 12.3, "concreto_escuro")
        k.parede("x", -2.8, 2.8, -2.8, 12.3, 13.4, 0.08, "ferro", lado=1)
        k.caixa(-0.8, 2.5, 11.8, 0.8, 30.0, 12.0, "concreto")                   # passarela até a crista
        for x in (-0.8, 0.8):
            k.caixa(x - 0.03, 2.5, 12.0, x + 0.03, 30.0, 13.0, "ferro")
        k.fim()

    # ------------------------------------------------------------------ Fazenda Boa Esperança
    if quer("casarao"):
        casarao(bloco, C, mob)
    if quer("tulha"):
        k = galpao_vao("tulha_a", 8, 20, 5, "tabua", "telha", portao_larg=2.4)
        c = k.c
        c.ocupado.append((-1.3, -9.8, 1.3, 9.8))
        for i in range(4):
            c.livre("fardos", -2.6, -7.5 + i * 4.5, 90)
            c.livre("fardos", 2.6, -7.5 + i * 4.5, 90)
        c.enc("estante_carga", "W", 0.95, w=1.6)
        c.enc("caixotes", "E", 0.95)
        c.loot("W", 0.05, "medio")
        c.loot("E", 0.05, "medio")
        c.loot("W", 0.6, "medio")
        c.loot("E", 0.6, "medio")
        k.fim()
    if quer("curral"):
        k = Kit("curral_a")
        for (a0, a1, f, eixo) in ((-10, 10, -10, "x"), (-10, 10, 10, "x"), (-10, 10, -10, "y"), (-10, 10, 10, "y")):
            n = 11
            for i in range(n):
                u = a0 + i * (a1 - a0) / (n - 1)
                if eixo == "x" and f == -10 and abs(u) < 2.0:
                    continue                                                # porteira aberta
                if eixo == "x":
                    k.caixa(u - 0.1, f - 0.1, 0.0, u + 0.1, f + 0.1, 1.6, "madeira")
                else:
                    k.caixa(f - 0.1, u - 0.1, 0.0, f + 0.1, u + 0.1, 1.6, "madeira")
            for z in (0.5, 1.0, 1.45):
                if eixo == "x":
                    for (u0, u1) in (((a0, -2.0), (2.0, a1)) if f == -10 else ((a0, a1),)):
                        k.caixa(u0, f - 0.05, z, u1, f + 0.05, z + 0.1, "madeira_clara")
                else:
                    k.caixa(f - 0.05, a0, z, f + 0.05, a1, z + 0.1, "madeira_clara")
        k.fim()

    # ------------------------------------------------------------------ Pedreira
    if quer("container_escritorio"):
        k = Kit("container_escritorio_a")
        k.caixa(-1.25, -6.0, 0.0, 1.25, 6.0, 0.2, "ferro")
        k.parede("x", -1.25, 1.25, -6.0, 0.2, 2.6, 0.06, "barra_azul", vaos=[(0.0, 1.1, 0.2, 2.35)], lado=1)
        k.parede("x", -1.25, 1.25, 6.0, 0.2, 2.6, 0.06, "barra_azul", lado=-1)
        for f, ld in ((-1.25, 1), (1.25, -1)):
            k.parede("y", -5.94, 5.94, f, 0.2, 2.6, 0.06, "barra_azul", vaos=[(-3.0, 1.2, 1.1, 2.0), (3.0, 1.2, 1.1, 2.0)], lado=ld)
        k.caixa(-1.3, -6.05, 2.6, 1.3, 6.05, 2.75, "barra_azul")
        for i in range(12):                                                  # nervuras do contêiner
            y = -5.5 + i * 1.0
            for x in (-1.3, 1.26):
                k.caixa(x, y - 0.05, 0.2, x + 0.04, y + 0.05, 2.6, "ferro")
        k.entrada(0.0, -7.3, 0, 1)
        c = C(k, "container", (-1.19, -5.94, 1.19, 5.94), 0.2, portas=[(0.0, -5.94, 1.1)], janelas=[(-1.19, -3.0, 1.2), (-1.19, 3.0, 1.2), (1.19, -3.0, 1.2), (1.19, 3.0, 1.2)], tipo="container")
        c.enc("mesa_escritorio", "W", 0.25, w=1.3, d=0.7)
        c.enc("arquivo", "W", 0.6)
        c.enc("estante_carga", "E", 0.3, w=1.6, d=0.45)
        c.enc("estante_carga", "E", 0.75, w=1.6, d=0.45)
        c.enc("caixotes", "N", 0.5)
        c.loot("E", 0.03, "medio")
        c.loot("W", 0.85, "medio")
        c.loot("N", 0.5, "medio")
        k.fim()
    if quer("britador"):
        k = Kit("britador_a")
        for x, y in ((-5, -6), (5, -6), (-5, 6), (5, 6)):
            k.caixa(x - 0.3, y - 0.3, 0.0, x + 0.3, y + 0.3, 10.0, "ferro")
        for z in (4.0, 8.0):                                                 # 2 plataformas com guarda-corpo
            if z == 8.0:                                                     # alçapão (x 4,6..5,5) para a escada de mão
                k.caixa(-5.5, -6.5, z, 4.6, 6.5, z + 0.15, "zinco_ferrugem")
                k.caixa(4.6, -6.5, z, 5.5, -0.6, z + 0.15, "zinco_ferrugem")
                k.caixa(4.6, 0.6, z, 5.5, 6.5, z + 0.15, "zinco_ferrugem")
            else:
                k.caixa(-5.5, -6.5, z, 5.5, 6.5, z + 0.15, "zinco_ferrugem")
            for (a0, a1, f, eixo, ld) in ((-5.5, 5.5, -6.5, "x", 1), (-5.5, 5.5, 6.5, "x", -1)):
                k.parede(eixo, a0, a1, f, z + 0.15, z + 1.1, 0.05, "ferro", lado=ld)
        k.prisma([(-3.5, -3.5, 10.0), (3.5, -3.5, 10.0), (3.5, 3.5, 10.0), (-3.5, 3.5, 10.0)], (0, 0, 3.5), "zinco_ferrugem")   # funil
        k.caixa(-2.0, -2.0, 0.0, 2.0, 2.0, 3.0, "zinco")                         # britador
        k.lance((5.6, -6.0, 6.6, -1.8), "+y", 14, 0.0, 3.99, "ferro", macico=False, espessura=0.08)     # escada até a 1ª plataforma
        k.escada_mao("b1", 5.0, 0.0, 4.15, 8.15, 1, 0, sai=0.9)            # escada de mão da 1ª para a 2ª plataforma (lado leste)
        k.lance_teste(6.1, -6.8, 0, 1, 3.95, 4.0, -1.0)
        k.fim()
    if quer("correia"):
        k = Kit("correia_a")
        k.prisma([(-0.9, -20, 1.0), (0.9, -20, 1.0), (0.9, 20, 9.0), (-0.9, 20, 9.0)], (0, 0, 0.25), "concreto_escuro")
        for y in (-15, -5, 5, 15):
            z = 1.0 + (y + 20) / 40 * 8.0
            k.caixa(-0.8, y - 0.15, 0.0, -0.6, y + 0.15, z, "ferro")
            k.caixa(0.6, y - 0.15, 0.0, 0.8, y + 0.15, z, "ferro")
        k.fim()

    # ------------------------------------------------------------------ Pico
    if quer("antena"):
        k = Kit("antena_a")
        k.caixa(-2.2, -2.2, -0.3, 2.2, 2.2, 0.3, "concreto")
        for z0 in range(0, 30, 3):                                        # treliça: 4 montantes + travessas em X
            r0 = 1.9 - z0 * 0.035
            r1 = 1.9 - (z0 + 3) * 0.035
            for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
                k.caixa(sx * r0 - 0.06, sy * r0 - 0.06, z0 + 0.3, sx * r0 + 0.06, sy * r0 + 0.06, z0 + 3.3, "placa" if (z0 // 3) % 2 else "reboco_branco")
            k.caixa(-r1, -r1 - 0.03, z0 + 3.2, r1, -r1 + 0.03, z0 + 3.28, "ferro")
            k.caixa(-r1, r1 - 0.03, z0 + 3.2, r1, r1 + 0.03, z0 + 3.28, "ferro")
        for z in (10.0, 20.0):                                            # patamares escaláveis
            r = 1.9 - z * 0.035 + 0.5
            k.caixa(-r, -r, z, r, r, z + 0.12, "zinco")
        k.caixa(-1.2, -1.2, 30.3, 1.2, 1.2, 30.42, "zinco")              # plataforma do topo
        # três lances de escada de marinheiro: solo -> patamar 10 m -> patamar 20 m -> topo
        k.escada_mao("a1", 0.0, -2.0, 0.3, 10.12, 0, -1, sai=0.9)
        k.escada_mao("a2", 0.0, -1.5, 10.12, 20.12, 0, -1, sai=0.9)
        k.escada_mao("a3", 0.0, -1.0, 20.12, 30.42, 0, -1, sai=0.9)
        k.fim()
    if quer("casa_radio"):
        k = bloco("casa_radio_a", 5, 6, 1, "concreto", "ferro", jan_lado=(-1.6, 1.8), platibanda=0.3, escada_int=False)
        pequena(k, C, "Sala de rádio")
        k.fim()


def pequena(k, C, nome_sala):
    """Casa técnica de 5 x 6 m: sala (frente), quarto de plantão (fundos esq.) e copa-cozinha (fundos dir.)."""
    g = k.g
    x0, x1, y0, y1, e = g["x0"], g["x1"], g["y0"], g["y1"], g["e"]
    zf, zc = g["zf"][0], g["zc"][0]
    par = g["parede"]
    YD = 0.3
    k.parede("x", x0 + e, x1 - e, YD, zf, zc, 0.1, par, vaos=[(-1.2, 1.1, zf, zf + 2.1), (1.2, 1.1, zf, zf + 2.1)])
    k.parede("y", YD + 0.1, y1 - e, 0.0, zf, zc, 0.1, par)
    sala = C(k, "sala", (x0 + e, y0 + e, x1 - e, YD), zf, portas=[(0.0, y0 + e, 1.4), (-1.2, YD), (1.2, YD)], janelas=[(x0 + e, -1.6, 1.3), (x1 - e, -1.6, 1.3)], tipo="sala")
    quarto = C(k, "quarto", (x0 + e, YD + 0.1, 0.0, y1 - e), zf, portas=[(-1.2, YD + 0.1)], janelas=[(x0 + e, 1.8, 1.3)], tipo="quarto")
    coz = C(k, "cozinha", (0.1, YD + 0.1, x1 - e, y1 - e), zf, portas=[(1.2, YD + 0.1)], janelas=[(x1 - e, 1.8, 1.3)], tipo="cozinha")
    sala.enc("mesa_escritorio", "N", 0.5, w=1.2, d=0.7)
    sala.enc("estante", "W", 0.2, w=1.0)
    sala.enc("arquivo", "E", 0.3)
    sala.enc("sofa", "S", 0.9, w=1.5)
    sala.enc("mesa_centro", "S", 0.2, w=0.8, d=0.45)
    quarto.enc("cama", "W", 1.0, w=0.95)
    quarto.enc("guarda_roupa", "N", 0.6, w=1.0)
    coz.enc("pia", "N", 0.0, w=1.0)
    coz.enc("fogao", "N", 0.55)
    coz.enc("geladeira", "N", 1.0, w=0.7)
    coz.enc("mesa", "S", 0.8, w=0.8, d=0.7)
    sala.loot("W", 0.9, "medio")
    quarto.loot("E", 0.85, "baixo")
    coz.loot("E", 0.4, "medio")


def casarao(bloco, C, mob):
    """Casarão da fazenda 26 x 18 m, 2 andares: sala central, cozinha, 2 quartos no térreo; 4 quartos no andar de cima."""
    k = bloco("casarao_a", 26, 18, 2, "reboco_branco", "janela_azul", telhado="duas",
              jan_frente=(-11.0, -8.6, -6.4, -1.8, 1.8, 6.4, 8.6, 11.0), jan_lado=(-6.0, -3.0, 3.0, 6.0), pe=3.6)
    # varanda em volta (térreo): esteios + piso de tábua + telhado de meia-água
    for x in [-13.8 + i * 2.3 for i in range(13)]:
        for y in (-10.8, 10.8):
            k.caixa(x - 0.12, y - 0.12, 0.15, x + 0.12, y + 0.12, 3.4, "madeira")
    k.caixa(-14.2, -11.2, 0.15, 14.2, -9.0, 0.35, "madeira_clara")
    k.prisma([(-14.3, -9.0, 3.9), (14.3, -9.0, 3.9), (14.3, -11.3, 3.3), (-14.3, -11.3, 3.3)], (0, 0, 0.12), "telha")
    k.caixa(-14.2, 9.0, 0.15, 14.2, 11.2, 0.35, "madeira_clara")
    k.prisma([(-14.3, 9.0, 3.9), (14.3, 9.0, 3.9), (14.3, 11.3, 3.3), (-14.3, 11.3, 3.3)], (0, 0, 0.12), "telha")
    for i in range(4):                                                  # escadaria da entrada (degraus de 0,07..0,28 m)
        k.caixa(-2.5, -11.2 - (4 - i) * 0.35, 0.0, 2.5, -11.2 - (3 - i) * 0.35, 0.1 + i * 0.07, "concreto")
    g = k.g
    x0, x1, y0, y1, e, par = g["x0"], g["x1"], g["y0"], g["y1"], g["e"], g["parede"]
    XA, XB, YM = -4.4, 4.3, -0.4
    for a in range(2):
        zf, zc = g["zf"][a], g["zc"][a]
        k.parede("y", y0 + e, y1 - e, XA, zf, zc, 0.1, par, vaos=[(-4.6, 1.1, zf, zf + 2.1), (4.4, 1.1, zf, zf + 2.1)])
        k.parede("y", y0 + e, y1 - e, XB, zf, zc, 0.1, par, vaos=[(-4.6, 1.1, zf, zf + 2.1), (4.4, 1.1, zf, zf + 2.1)])
        k.parede("x", x0 + e, XA, YM, zf, zc, 0.1, par)                                           # asa esquerda: frente | fundos
        k.parede("x", XA + 0.1, XB, YM, zf, zc, 0.1, par, vaos=[(0.0, 1.4, zf, zf + 2.1)])       # centro: sala | cozinha
        k.parede("x", XB + 0.1, x1 - e, YM, zf, zc, 0.1, par, vaos=[(6.0, 1.1, zf, zf + 2.1)])  # asa direita
    # estas divisórias são comuns aos dois andares; os cômodos mudam
    jf = [(c, y0 + 0.2, 1.3) for c in g["jf"]]
    jb = [(c, y1 - 0.2, 1.3) for c in g["jf"]]
    for a in range(2):
        zf = g["zf"][a]
        porta_f = [(g["porta"], y0 + e, 1.4)] if a == 0 else []
        sala_c = C(k, "sala" if a == 0 else "quarto", (XA + 0.1, y0 + e, XB, YM), zf, portas=[(0.0, YM), (XA + 0.1, -4.6), (XB, -4.6)] + porta_f, janelas=[(c, y0 + e, 1.3) for c in (-1.8, 1.8)])
        coz_c = C(k, "cozinha" if a == 0 else "quarto", (XA + 0.1, YM + 0.1, XB, y1 - e), zf, portas=[(0.0, YM + 0.1), (XA + 0.1, 4.4), (XB, 4.4)], janelas=[(c, y1 - e, 1.3) for c in (-1.8, 1.8)])
        q1 = C(k, "quarto", (x0 + e, y0 + e, XA, YM), zf, portas=[(XA, -4.6)], janelas=[(c, y0 + e, 1.3) for c in (-11.0, -8.6, -6.4)] + [(x0 + e, -6.0, 1.3), (x0 + e, -3.0, 1.3)])
        q2 = C(k, "quarto", (x0 + e, YM + 0.1, XA, y1 - e), zf, portas=[(XA, 4.4)], janelas=[(c, y1 - e, 1.3) for c in (-11.0, -8.6, -6.4)] + [(x0 + e, 3.0, 1.3), (x0 + e, 6.0, 1.3)])
        f3 = C(k, "sala" if a == 0 else "quarto", (XB + 0.1, y0 + e, x1 - e, YM), zf, portas=[(XB + 0.1, -4.6), (XB + 0.1, -0.0)] if False else [(XB + 0.1, -4.6)],
               janelas=[(c, y0 + e, 1.3) for c in (6.4, 8.6, 11.0)] + [(x1 - e, -6.0, 1.3), (x1 - e, -3.0, 1.3)])
        f4 = C(k, "hall" if a == 0 else "quarto", (XB + 0.1, YM + 0.1, x1 - e, y1 - e), zf, portas=[(XB + 0.1, 4.4), (6.0, YM + 0.1)],
               janelas=[(c, y1 - e, 1.3) for c in (6.4, 8.6, 11.0)] + [(x1 - e, 3.0, 1.3)])
        if a == 0:
            f4.ocupado.append((x1 - 1.5, y1 - 4.2, x1 - 0.2, y1 - 1.0))                              # lance da escada
        else:
            f4.ocupado.append((x1 - 3.3, y1 - 4.3, x1 - 0.2, y1 - 0.2))
            k.caixa(x1 - 3.3, y1 - 4.2, zf, x1 - 3.2, y1 - e, zf + 0.95, "ferro")
            k.caixa(x1 - 3.2, y1 - 4.25, zf, x1 - 1.5, y1 - 4.2, zf + 0.95, "ferro")
        if a == 0:
            mob["sala"](sala_c, largura=2.2)
            mob["cozinha"](coz_c)
            sala_c.enc("mesa_longa", "N", 0.5, w=2.6, d=0.9) if False else None
            mob["quarto"](q1, largura=1.3)
            mob["quarto"](q2, largura=1.3, cama="S")
            mob["sala"](f3, sofa="N", tv="S")
            mob["hall"](f4)
            sala_c.loot("W", 0.5, "medio")
            coz_c.loot("E", 0.4, "medio")
            q1.loot("S", 0.8, "baixo")
            q2.loot("N", 0.7, "baixo")
            f3.loot("E", 0.5, "medio")
        else:
            for c_, kw in ((sala_c, dict(largura=1.6)), (coz_c, dict(largura=1.6)), (q1, dict(largura=1.3)), (q2, dict(largura=1.3, cama="S")), (f3, dict(largura=1.1)), (f4, dict(largura=1.1))):
                mob["quarto"](c_, **kw)
            sala_c.loot("W", 0.6, "baixo")
            q1.loot("S", 0.9, "medio")
            q2.loot("N", 0.5, "medio")
            f3.loot("E", 0.4, "medio")
    k.fim()
