# -*- coding: utf-8 -*-
"""
Conferência do cenário por área (só VALIDA; não gera nem move posições).

Lê docs/design/cenario_areas_02.json (ou os arquivos dados na linha de comando) e confere cada peça contra os
dados reais da ilha (game/maps/ilha): relevo (height.bin), prédios (ilha_layout), estradas/trilhas/pista, rio,
represa, props existentes (detalhes, refino, cenario_areas 01/02, cercas, fiação, coberturas, vegetação, saques).

Regras (ERRO = deve ser corrigido; AVISO = revisar à mão):
  - dentro de prédio (planta + 0,3 m)                       -> ERRO
  - na frente da porta (retângulo 2,4 x 3,2 m)              -> ERRO (bloqueia a entrada)
  - no meio da estrada/trilha/pista (exceto barreira/cone)  -> ERRO
  - no leito do rio ou na represa                           -> ERRO
  - na água/mar (altura < 0,3 m)                            -> ERRO
  - declive > 35 graus                                      -> ERRO
  - sobreposta a outra peça (< 1 m; cercas contíguas ok)    -> ERRO se com peça nova, AVISO se com peça antiga/árvore
  - carro a menos de 60 m de outro carro                    -> AVISO
  - árvore dentro de 1,2 m de árvore da vegetação           -> AVISO

Uso:  python tools/checa_cenario.py [arquivo.json ...] [--quiet] [--png x0,y0,x1,y1,saida.png]
Saída != 0 se houver ERRO.
"""
import json
import math
import os
import sys

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ILHA = os.path.join(RAIZ, "game", "maps", "ilha")
PADRAO = [os.path.join(RAIZ, "docs", "design", "cenario_areas_02.json")]


def jl(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------- relevo
class Relevo:
    def __init__(self):
        self.h = np.fromfile(os.path.join(ILHA, "height.bin"), dtype="<f4").reshape(601, 601)

    def z(self, x, y):
        c = (x + 600.0) / 2.0
        r = (600.0 - y) / 2.0
        c = min(max(c, 0.0), 599.999)
        r = min(max(r, 0.0), 599.999)
        i, j = int(r), int(c)
        fr, fc = r - i, c - j
        h = self.h
        return float((h[i, j] * (1 - fc) + h[i, j + 1] * fc) * (1 - fr) + (h[i + 1, j] * (1 - fc) + h[i + 1, j + 1] * fc) * fr)

    def declive_graus(self, x, y, d=1.0):
        gx = (self.z(x + d, y) - self.z(x - d, y)) / (2 * d)
        gy = (self.z(x, y + d) - self.z(x, y - d)) / (2 * d)
        return math.degrees(math.atan(math.hypot(gx, gy)))


# ---------------------------------------------------------------- geometria
def dist_seg(p, a, b):
    vx, vy = b[0] - a[0], b[1] - a[1]
    L2 = vx * vx + vy * vy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * vx + (p[1] - a[1]) * vy) / L2))
    return math.hypot(p[0] - (a[0] + t * vx), p[1] - (a[1] + t * vy))


def dist_poli(p, pts):
    return min(dist_seg(p, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def em_poligono(p, poly):
    x, y = p
    dentro = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            dentro = not dentro
    return dentro


def local(p, centro, rot_deg):
    """ponto no referencial do retângulo (x = largura local, y = profundidade local)."""
    r = math.radians(rot_deg)
    c, s = math.cos(r), math.sin(r)
    dx, dy = p[0] - centro[0], p[1] - centro[1]
    return dx * c + dy * s, -dx * s + dy * c


# ---------------------------------------------------------------- casas residenciais = modelo casa_demo
# Todas as casas residenciais do layout viram o modelo casa_demo (pegada 12,9 x 13,3 m, mesma posição, porta virada para o centro
# do POI). Para conferir tratamos cada uma como retângulo 14 x 14 m; vila_operaria = 2 casas no eixo longo (26 x 14) e casarao =
# 2 casas no eixo x (28 x 15). A porta fica na face -Y local, então rot_deg = ângulo(para o centro) + 90.
RESIDENCIAL = {"casa_laje": (14.0, 14.0), "casa_caicara": (14.0, 14.0), "casa_colono": (14.0, 14.0), "sobrado": (14.0, 14.0),
               "casa_faroleiro": (14.0, 14.0), "casa_piloto": (14.0, 14.0), "casa_operador": (14.0, 14.0),
               "vila_operaria": (26.0, 14.0), "casarao": (28.0, 15.0)}


def forma_demo(b, centro):
    t = b["tipo"]
    if t not in RESIDENCIAL:
        return b
    w, d = RESIDENCIAL[t]
    ux, uy = centro[0] - b["pos"][0], centro[1] - b["pos"][1]
    n = math.hypot(ux, uy) or 1.0
    ux, uy = ux / n, uy / n
    ang_u = math.degrees(math.atan2(uy, ux))
    if t in ("vila_operaria", "casarao"):
        base = b["rot_deg"] + (90.0 if t == "vila_operaria" else 0.0)   # eixo longo original
        rot = None
        for th in (base, base + 180.0):
            nx, ny = math.cos(math.radians(th - 90)), math.sin(math.radians(th - 90))   # normal da porta (-Y local)
            if nx * ux + ny * uy > 0:
                rot = th
        portas = [-w / 4, w / 4]
    else:
        rot = ang_u + 90.0
        portas = [0.0]
    nb = dict(b)
    nb["rot_deg"] = rot % 360
    nb["tamanho_m"] = [w, d, b["tamanho_m"][2]]
    nb["entravel"] = True
    nb["portas"] = portas
    nb["orig"] = b["tipo"]
    return nb


# ---------------------------------------------------------------- tipos
CERCA = {"cenario/natureza/cerca_madeira": 4.5, "cenario/natureza/cerca_madeira_curta": 2.2, "cenario/natureza/muro_ruina": 7.0,
         "cerca_madeira": 3.0, "muro_baixo": 3.0, "muro_alto": 3.0, "cerca_arame": 3.0}
ARVORES = {"carvalho", "arvore_b", "arvore_d", "betula", "betula_jovem", "pinheiro", "pinheiro_medio", "pinheiro_jovem",
           "salgueiro", "arvore_seca", "arvore_seca_p"}
# bloqueio de via é intencional nestas peças
BLOQUEIO = ("rua_road_barrier", "rua_roadcone")
# raio aproximado (m) para a regra de sobreposição
RAIO = {"carro": 2.7, "carvalho": 1.0, "salgueiro": 1.0, "arvore_d": 0.9, "arvore_b": 0.8, "arvore_seca": 0.8, "betula": 0.6,
        "pinheiro": 0.6, "pinheiro_medio": 0.6, "pinheiro_jovem": 0.5, "betula_jovem": 0.4, "arvore_seca_p": 0.5,
        "canoa_praia": 1.4, "pilha_troncos": 1.2, "tronco_caido": 1.2, "muro_ruina": 1.5, "rocha_grande": 0.9,
        "pedra_03": 0.8, "pedra_04": 0.7, "entulho": 0.8, "monte_terra": 0.6, "samambaia_a": 0.4, "toco_baixo": 0.6,
        "mesa_bar_cadeiras": 0.8, "banco_praca": 0.7, "rua_bank": 0.8, "rua_streetbank": 0.8}
# peças pequeninas, só visuais: podem ficar coladas em outra peça (>= 0,35 m)
MIUDAS = {"pedrisco_a", "pedrisco_b", "galho", "tufo_capim", "tufo_misto", "urtiga", "pedra_01", "pedra_02", "pedra_06",
          "pedra_07", "pedra_10", "lenha", "rua_manhole_01", "rua_manhole_02", "rua_manhole_03", "rua_manhole_04"}


def nome(t):
    return t.split("/")[-1]


def eh_carro(t):
    return t.startswith("cenario/carros/")


def raio(t):
    n = nome(t)
    if eh_carro(t):
        return RAIO["carro"]
    return RAIO.get(n, 0.35 if n in MIUDAS else 0.5)


# ---------------------------------------------------------------- mundo
class Mundo:
    def __init__(self):
        self.rel = Relevo()
        L = jl(os.path.join(ILHA, "ilha_layout.json"))
        self.layout = L
        self.predios = []
        for p in L["pois"] + L.get("marcos", []):
            for b in p["predios"]:
                self.predios.append(forma_demo(b, p["centro"]))
        pk = os.path.join(ILHA, "casas_pacote.json")
        if os.path.exists(pk):   # casas extras do pacote em terrenos planos (14 x 14, porta -Y local virada para o centro do POI)
            for i, c in enumerate(jl(pk)["casas"]):
                self.predios.append({"id": "casa_pacote_%d" % i, "tipo": "casa_demo", "pos": [c["x"], c["y"]], "rot_deg": c["rot_deg"],
                                     "tamanho_m": [14, 14, 6], "entravel": True, "portas": [0.0]})
        self.vias = []     # (nome, pontos, largura)
        for e in L["estradas"]:
            self.vias.append((e["id"], e["pontos"], float(e["largura_m"]), e["tipo"]))
        self.rio = []
        for t in L["agua"]["rio"]["trechos"]:
            self.rio.append(([[q[0], q[1]] for q in t["pontos"]], float(t["largura_m"])))
        self.represa = L["agua"]["represa"]["contorno"]
        self.ponte = L["pontes"]
        # props antigos (todos com centro, para sobreposição)
        self.antigos = []   # (x, y, tipo, origem)
        D = jl(os.path.join(ILHA, "detalhes.json"))
        for p in D["props"]:
            self.antigos.append((p["x"], p["y"], p["tipo"], "detalhes"))
        for c in D.get("cercas", []):
            pts = c["pontos"]
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                n = max(1, int(round(math.dist(a, b) / 3.0)))
                for k in range(n + 1):
                    t = k / n
                    self.antigos.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, "cerca_madeira", "cerca_antiga"))
        for l in D.get("linhas_fiacao", []):
            for q in l["postes"]:
                self.antigos.append((q[0], q[1], "poste_madeira", "fiacao"))
        if os.path.exists(os.path.join(ILHA, "detalhes_refino.json")):
            for p in jl(os.path.join(ILHA, "detalhes_refino.json"))["props"]:
                self.antigos.append((p["x"], p["y"], p["tipo"], "refino"))
        self.cenario01 = []
        p1 = os.path.join(ILHA, "cenario_areas.json")
        if os.path.exists(p1):
            for a in jl(p1)["areas"]:
                for p in a["props"]:
                    self.cenario01.append((p["x"], p["y"], p["tipo"], "cenario_01"))
        self.antigos += self.cenario01
        # coberturas (gameplay) e vegetação
        self.cob = []
        for c in L.get("cobertura_campo_aberto", []):
            self.cob.append((c["pos"][0], c["pos"][1]))
        gp = jl(os.path.join(ILHA, "gameplay_01.json"))
        for c in gp.get("coberturas_novas", []):
            self.cob.append((c["pos"][0], c["pos"][1]))
        V = jl(os.path.join(ILHA, "vegetacao.json"))
        self.veg = [(v["x"], v["y"], v["tipo"]) for v in V["instancias"]]
        # saques
        self.saques = []
        for c in jl(os.path.join(ILHA, "br_loot.json")).get("caches", []):
            self.saques.append(tuple(c["pos"]))
        PL = jl(os.path.join(ILHA, "pontos_loot.json"))
        self.veiculos_velhos = []
        for v in PL.get("externos_veiculos", []):
            self.veiculos_velhos.append((v["x"], v["y"]))
        self._grade = {}
        for i, (x, y, t, o) in enumerate(self.antigos):
            self._grade.setdefault((int(x // 8), int(y // 8)), []).append(i)
        self._gveg = {}
        for i, (x, y, t) in enumerate(self.veg):
            self._gveg.setdefault((int(x // 8), int(y // 8)), []).append(i)
        self._gcob = {}
        for i, (x, y) in enumerate(self.cob):
            self._gcob.setdefault((int(x // 8), int(y // 8)), []).append(i)

    def perto(self, grade, lista, x, y, r):
        out = []
        n = int(r // 8) + 1
        gx, gy = int(x // 8), int(y // 8)
        for i in range(gx - n, gx + n + 1):
            for j in range(gy - n, gy + n + 1):
                for k in grade.get((i, j), []):
                    q = lista[k]
                    if math.hypot(q[0] - x, q[1] - y) <= r:
                        out.append(q)
        return out

    def carros_antigos(self):
        out = [(x, y) for x, y, t, o in self.cenario01 if eh_carro(t)]
        return out + self.veiculos_velhos

    # --- consultas por prédio
    def predio_em(self, x, y, folga=0.3):
        for b in self.predios:
            w, d, _ = b["tamanho_m"]
            if b["tipo"] in ("heliponto",):
                continue
            lx, ly = local((x, y), b["pos"], b["rot_deg"])
            if abs(lx) <= w / 2 + folga and abs(ly) <= d / 2 + folga:
                return b
        return None

    def porta_em(self, x, y):
        """porta na face -Y local: retângulo 2,4 m de largura, 3,2 m para fora."""
        for b in self.predios:
            if not b.get("entravel"):
                continue
            w, d, _ = b["tamanho_m"]
            lx, ly = local((x, y), b["pos"], b["rot_deg"])
            for px in b.get("portas", [0.0]):
                if abs(lx - px) <= 1.2 and -d / 2 - 3.2 <= ly <= -d / 2:
                    return b
        return None

    def via_em(self, x, y, margem):
        for (nm, pts, larg, tipo) in self.vias:
            d = dist_poli((x, y), pts)
            if d < larg / 2.0 + margem:
                return nm, d
        for p in self.ponte:
            lx, ly = local((x, y), p["pos"], p["rot_deg"])
            if abs(lx) <= p["comprimento_m"] / 2 + margem and abs(ly) <= p["largura_m"] / 2 + margem:
                return p["nome"], 0.0
        return None

    def rio_em(self, x, y, margem=0.0):
        for pts, larg in self.rio:
            if dist_poli((x, y), pts) < larg / 2.0 + margem:
                return True
        return em_poligono((x, y), self.represa)


def carregar_pecas(arqs):
    pecas = []
    for arq in arqs:
        for a in jl(arq)["areas"]:
            for k, p in enumerate(a["props"]):
                pecas.append({"area": a["nome"], "i": k, "tipo": p["tipo"], "x": float(p["x"]), "y": float(p["y"]),
                              "rot": float(p.get("rot_deg", 0.0)), "esc": float(p.get("escala", 1.0))})
    return pecas


def conferir(pecas, M, quiet=False):
    erros, avisos = [], []

    def E(p, m):
        erros.append("[%s #%d %s (%.1f,%.1f)] %s" % (p["area"], p["i"], nome(p["tipo"]), p["x"], p["y"], m))

    def A(p, m):
        avisos.append("[%s #%d %s (%.1f,%.1f)] %s" % (p["area"], p["i"], nome(p["tipo"]), p["x"], p["y"], m))

    grade = {}
    for k, p in enumerate(pecas):
        grade.setdefault((int(p["x"] // 8), int(p["y"] // 8)), []).append(k)
    carros_novos = [p for p in pecas if eh_carro(p["tipo"])]
    carros_velhos = M.carros_antigos()
    for p in pecas:
        x, y, t = p["x"], p["y"], p["tipo"]
        n = nome(t)
        cerca = t in CERCA
        bloq = n.startswith(BLOQUEIO)
        z = M.rel.z(x, y)
        if abs(x) > 590 or abs(y) > 590:
            E(p, "fora do mapa")
        if z < 0.3:
            E(p, "na água/mar (altura %.2f m)" % z)
        dec = M.rel.declive_graus(x, y)
        if dec > 35:
            E(p, "declive %.0f graus" % dec)
        b = M.predio_em(x, y)
        if b:
            E(p, "dentro do prédio %s" % b["id"])
        elif M.porta_em(x, y) and not cerca:
            E(p, "na frente da porta de %s" % M.porta_em(x, y)["id"])
        elif M.porta_em(x, y) and cerca:
            E(p, "cerca na frente da porta de %s (falta vão de portão)" % M.porta_em(x, y)["id"])
        elif cerca:
            b2 = M.predio_em(x, y, 1.5)
            if b2 and (b2.get("orig") in RESIDENCIAL or b2["tipo"] == "casa_demo"):
                E(p, "cerca a menos de 1,5 m da casa %s" % b2["id"])
        if not bloq:
            margem = 0.4
            if eh_carro(t):
                margem = 1.5
            elif n in ARVORES:
                margem = 1.2
            v = M.via_em(x, y, margem)
            if v:
                E(p, "na via %s (a %.1f m do eixo)" % (v[0], v[1]))
        if M.rio_em(x, y, -0.5 if n in ("salgueiro", "samambaia_a", "samambaia_b", "arbusto_a", "arbusto_b", "pedra_03", "pedra_04", "pedra_05", "pedra_09", "rocha_grande", "rocha_media", "pedra_08") else 0.0):
            E(p, "no leito do rio/represa")
        for s in M.saques:
            if math.hypot(s[0] - x, s[1] - y) < 1.0:
                E(p, "em cima de ponto de saque %s" % (s,))
        # sobreposição com peças novas
        rp = raio(t)
        for k in grade.get((int(x // 8), int(y // 8)), []) + [kk for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx, dy) != (0, 0) for kk in grade.get((int(x // 8) + dx, int(y // 8) + dy), [])]:
            q = pecas[k]
            if q is p or id(q) < id(p):
                continue
            d = math.hypot(q["x"] - x, q["y"] - y)
            cerca_q = q["tipo"] in CERCA
            if cerca and cerca_q:
                # cercas: só reprova cruzamento franco (centros a menos de 0,6 m)
                if d < 0.6:
                    E(p, "cerca duplicada com #%d" % q["i"])
                continue
            lim = 1.0
            nq = nome(q["tipo"])
            if (n in MIUDAS and nq in MIUDAS) or (n in MIUDAS) or (nq in MIUDAS):
                lim = 0.45
            lim = max(lim, 0.55 * (rp + raio(q["tipo"])) if (rp > 0.9 or raio(q["tipo"]) > 0.9) else lim)
            if cerca or cerca_q:
                lim = min(lim, 0.9)
            if d < lim:
                E(p, "sobreposta a %s #%d da área %s (%.2f m)" % (nome(q["tipo"]), q["i"], q["area"], d))
        # antigos
        for (ax, ay, at, ao) in M.perto(M._grade, M.antigos, x, y, 4.0):
            d = math.hypot(ax - x, ay - y)
            na = nome(at)
            lim = 1.0
            if n in MIUDAS or na in MIUDAS:
                lim = 0.45
            if ao == "cerca_antiga":
                lim = 0.6
            if (eh_carro(t) or eh_carro(at)):
                lim = 3.4
            if d < lim:
                A(p, "perto de peça existente %s (%s) a %.2f m" % (na, ao, d))
        for (cx, cy) in M.perto(M._gcob, M.cob, x, y, 3.0):
            if math.hypot(cx - x, cy - y) < (1.5 if n not in MIUDAS else 0.8):
                A(p, "perto de cobertura do gameplay a %.1f m" % math.hypot(cx - x, cy - y))
        if n in ARVORES or n.startswith("rocha") or eh_carro(t):
            for (vx, vy, vt) in M.perto(M._gveg, M.veg, x, y, 3.0):
                if vt.startswith("arvore") or vt == "coqueiro":
                    if math.hypot(vx - x, vy - y) < 1.8:
                        A(p, "perto de árvore da vegetação (%s) a %.1f m" % (vt, math.hypot(vx - x, vy - y)))
                        break
        if n in ("pinheiro", "pinheiro_medio") and False:
            pass
    # cercas que se cruzam (cruzamento franco; encontros de ponta e cercas contíguas não contam)
    segs = []
    for k, p in enumerate(pecas):
        if p["tipo"] in CERCA:
            L = CERCA[p["tipo"]] * p["esc"] / 2.0
            r = math.radians(p["rot"])
            dx, dy = math.cos(r) * L * 0.92, math.sin(r) * L * 0.92
            segs.append((k, (p["x"] - dx, p["y"] - dy), (p["x"] + dx, p["y"] + dy)))

    def orient(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    gs = {}
    for (k, a, b) in segs:
        gs.setdefault((int(pecas[k]["x"] // 12), int(pecas[k]["y"] // 12)), []).append((k, a, b))
    for (gx, gy), lst in gs.items():
        viz = []
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                viz += gs.get((gx + dx, gy + dy), [])
        for (k, a, b) in lst:
            for (k2, c, d) in viz:
                if k2 <= k:
                    continue
                if orient(a, b, c) * orient(a, b, d) < -0.5 and orient(c, d, a) * orient(c, d, b) < -0.5:
                    E(pecas[k], "cerca cruza a cerca #%d (%s)" % (pecas[k2]["i"], pecas[k2]["area"]))
    # carros a cada 60 m
    for p in carros_novos:
        for q in carros_novos:
            if q is not p and id(q) > id(p) and math.hypot(p["x"] - q["x"], p["y"] - q["y"]) < 60:
                E(p, "carro a menos de 60 m do carro #%d (%s)" % (q["i"], q["area"]))
        for (cx, cy) in carros_velhos:
            if math.hypot(p["x"] - cx, p["y"] - cy) < 60:
                A(p, "carro a menos de 60 m de carro antigo em (%.0f,%.0f)" % (cx, cy))
    return erros, avisos


def desenhar(pecas, M, caixa, saida):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    x0, y0, x1, y1 = caixa
    fig, ax = plt.subplots(figsize=(12, 12 * (y1 - y0) / (x1 - x0)), dpi=80)
    xs = np.arange(x0, x1, 2.0)
    ys = np.arange(y0, y1, 2.0)
    Z = np.array([[M.rel.z(x, y) for x in xs] for y in ys])
    ax.imshow(Z, extent=(x0, x1, y0, y1), origin="lower", cmap="terrain", alpha=0.55)
    ax.contour(xs, ys, Z, levels=np.arange(0, 60, 2), colors="k", linewidths=0.25, alpha=0.4)
    for b in M.predios:
        w, d, _ = b["tamanho_m"]
        r = math.radians(b["rot_deg"])
        c, s = math.cos(r), math.sin(r)
        pts = [(b["pos"][0] + sx * w / 2 * c - sy * d / 2 * s, b["pos"][1] + sx * w / 2 * s + sy * d / 2 * c) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        ax.add_patch(plt.Polygon(pts, closed=True, fc="#c9a27e", ec="k", lw=0.8))
        # porta (face -Y local)
        px, py = b["pos"][0] + (0 * c + (d / 2) * s), b["pos"][1] + (0 * s - (d / 2) * c)
        ax.plot([px], [py], "r^", ms=4)
        ax.text(b["pos"][0], b["pos"][1], b["id"].split("_")[-1], fontsize=7, ha="center")
    for (nm, pts, larg, tipo) in M.vias:
        a = np.array(pts)
        ax.plot(a[:, 0], a[:, 1], color="#8a6d3b", lw=max(1, larg * 0.9), alpha=0.5, solid_capstyle="butt")
    for pts, larg in M.rio:
        a = np.array(pts)
        ax.plot(a[:, 0], a[:, 1], color="#3a7bd5", lw=max(1, larg * 0.9), alpha=0.6)
    ax.add_patch(plt.Polygon(M.represa, closed=True, fc="#3a7bd5", alpha=0.5))
    for (vx, vy, vt) in M.veg:
        if x0 <= vx <= x1 and y0 <= vy <= y1:
            ax.plot(vx, vy, ".", color="#2e7d32", ms=2, alpha=0.5)
    for (ax_, ay, at, ao) in M.antigos:
        if x0 <= ax_ <= x1 and y0 <= ay <= y1:
            ax.plot(ax_, ay, "s", color="#555", ms=2)
    for c in jl(os.path.join(ILHA, "detalhes.json")).get("cercas", []):
        a = np.array(c["pontos"])
        ax.plot(a[:, 0], a[:, 1], color="m", lw=1.5, ls="--")
    cor = {"carros": "#d32f2f", "cerca": "#6d4c41", "arv": "#1b5e20", "ped": "#757575", "rua": "#0277bd", "nat": "#ef6c00"}
    for p in pecas:
        if not (x0 <= p["x"] <= x1 and y0 <= p["y"] <= y1):
            continue
        t = p["tipo"]
        if t in CERCA:
            L = CERCA[t]
            r = math.radians(p["rot"])
            ax.plot([p["x"] - L / 2 * math.cos(r), p["x"] + L / 2 * math.cos(r)], [p["y"] - L / 2 * math.sin(r), p["y"] + L / 2 * math.sin(r)], color=cor["cerca"], lw=2)
        elif eh_carro(t):
            ax.plot(p["x"], p["y"], "s", color=cor["carros"], ms=7)
        elif nome(t) in ARVORES:
            ax.plot(p["x"], p["y"], "o", color=cor["arv"], ms=6)
        elif "/pedras/" in t or "rocha" in t:
            ax.plot(p["x"], p["y"], "D", color=cor["ped"], ms=4)
        elif "/rua/" in t:
            ax.plot(p["x"], p["y"], "^", color=cor["rua"], ms=4)
        else:
            ax.plot(p["x"], p["y"], "o", color=cor["nat"], ms=3)
    ax.set_xlim(x0, x1)
    ax.set_ylim(y0, y1)
    ax.set_aspect("equal")
    ax.grid(True, alpha=0.2)
    plt.tight_layout()
    plt.savefig(saida)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    quiet = "--quiet" in sys.argv
    png = None
    for a in sys.argv[1:]:
        if a.startswith("--png="):
            png = a[6:].split(",")
    arqs = args or PADRAO
    pecas = carregar_pecas(arqs)
    M = Mundo()
    erros, avisos = conferir(pecas, M, quiet)
    por_area = {}
    for p in pecas:
        por_area[p["area"]] = por_area.get(p["area"], 0) + 1
    print("PECAS %d em %d areas" % (len(pecas), len(por_area)))
    for k, v in por_area.items():
        print("  %-28s %4d" % (k, v))
    if not quiet:
        for m in avisos:
            print("AVISO", m)
    for m in erros:
        print("ERRO ", m)
    print("RESUMO: %d erros, %d avisos" % (len(erros), len(avisos)))
    if png:
        desenhar(pecas, M, [float(v) for v in png[:4]], png[4])
    return 1 if erros else 0


if __name__ == "__main__":
    sys.exit(main())
