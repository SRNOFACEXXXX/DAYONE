# -*- coding: utf-8 -*-
"""
Fonte AUTORAL do cenário por área 02 (docs/design/cenario_areas_02.json).

Nada aqui sorteia: cada peça vem de uma decisão escrita neste arquivo (coordenada, ângulo, tipo).
Os ajudantes só expandem decisões geométricas determinísticas (ex.: "cerca de A até B com vão de portão em tal ponto"
vira N peças contíguas de 4,5 m / 2,2 m; "alameda de X a Y, a Z m do eixo, a cada W m" vira N árvores).
Convenções: x leste, y norte, rot_deg anti-horário; a porta dos prédios fica na face -Y local (voltada para rot-90).
Quem confere é tools/checa_cenario.py.

Biblioteca de ajudantes. Uso:  python tools/cenario_02_gerar.py   (monta os módulos cen02_*.py e grava docs/design/cenario_areas_02.json e game/maps/ilha/cenario_areas_02.json)
"""
import json
import math
import os
import shutil
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ILHA = os.path.join(RAIZ, "game", "maps", "ilha")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

NAT = "cenario/natureza/"
PED = "cenario/pedras/"
CAR = "cenario/carros/"
RUA = "cenario/rua/"
CERCA_L = NAT + "cerca_madeira"        # 4,5 m
CERCA_C = NAT + "cerca_madeira_curta"  # 2,2 m

AREAS = []
_cur = None


def area(nome, intencao):
    global _cur
    _cur = {"nome": nome, "intencao": intencao, "props": []}
    AREAS.append(_cur)


def P(tipo, x, y, rot=0.0, esc=None):
    d = {"tipo": tipo, "x": round(x, 2), "y": round(y, 2), "rot_deg": round(rot % 360, 1)}
    if esc is not None and abs(esc - 1.0) > 1e-6:
        d["escala"] = round(esc, 2)
    _cur["props"].append(d)


def N(nome, x, y, rot=0.0, esc=None):
    P(NAT + nome, x, y, rot, esc)


def R(nome, x, y, rot=0.0, esc=None):
    P(PED + nome, x, y, rot, esc)


def U(nome, x, y, rot=0.0, esc=None):
    P(RUA + "rua_" + nome, x, y, rot, esc)


def Car(nome, x, y, rot):
    P(CAR + "carro_" + nome, x, y, rot)


def D(nome, x, y, rot=0.0, esc=None):
    """tipos antigos (assets/models/detalhes)."""
    P(nome, x, y, rot, esc)


# ---------------------------------------------------------------- cercas
def _melhor(L, modo):
    """combinação 4,5 m / 2,2 m cuja escala uniforme fique mais perto de 1."""
    melhor = None
    for a in range(0, 14):
        for b in range(0, 14):
            if a + b == 0:
                continue
            if modo == "L" and b:
                continue
            if modo == "C" and a:
                continue
            tot = 4.5 * a + 2.2 * b
            e = L / tot
            if melhor is None or abs(e - 1) < abs(melhor[0] - 1) - 1e-9:
                melhor = (e, a, b)
    return melhor


def cerca(a, b, modo="L", pular=()):
    """cerca contígua de a até b (pontos do mundo). pular = lista de (t0, t1) em metros ao longo do trecho (vão de portão)."""
    L = math.dist(a, b)
    ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    ang = math.degrees(math.atan2(uy, ux))
    cortes = [0.0]
    segs = []
    pos = 0.0
    for (t0, t1) in sorted(pular):
        if t0 > pos:
            segs.append((pos, t0))
        pos = max(pos, t1)
    if pos < L:
        segs.append((pos, L))
    for (s0, s1) in segs:
        SL = s1 - s0
        if SL < 1.0:
            continue
        e, na, nb = _melhor(SL, modo)
        lista = [(CERCA_L, 4.5)] * na + [(CERCA_C, 2.2)] * nb
        t = s0
        for (tp, comp) in lista:
            c = comp * e
            m = t + c / 2
            P(tp, a[0] + ux * m, a[1] + uy * m, ang, e)
            t += c


class Casa:
    def __init__(self, b):
        self.b = b
        self.portas = b.get("portas", [0.0])
        self.x, self.y = b["pos"]
        self.rot = b["rot_deg"]
        self.w, self.d, self.h = b["tamanho_m"]
        r = math.radians(self.rot)
        self.c, self.s = math.cos(r), math.sin(r)

    def W(self, lx, ly):
        return (self.x + lx * self.c - ly * self.s, self.y + lx * self.s + ly * self.c)

    def L(self, x, y):
        """ponto do mundo -> referencial local da casa."""
        dx, dy = x - self.x, y - self.y
        return (dx * self.c + dy * self.s, -dx * self.s + dy * self.c)

    def p(self, tipo, lx, ly, rl=0.0, esc=None):
        x, y = self.W(lx, ly)
        P(tipo, x, y, self.rot + rl, esc)

    # ajudantes de coordenada local relativas às paredes
    def xs(self, s, o): return s * (self.w / 2 + o)   # s=+1 direita, -1 esquerda
    def xl(self, o): return -(self.w / 2 + o)
    def xr(self, o): return self.w / 2 + o
    def yb(self, o): return self.d / 2 + o       # fundos
    def yf(self, o): return -(self.d / 2 + o)    # frente (porta)

    def lote(self, ml, mr, mf, mb, vao=3.0, modos=("C", "L", "L", "L"), lados=(True, True, True, True), vao_x=None, extra_vaos=None, abrir=()):
        """cerca fechando o lote. modos = (frente, direita, fundos, esquerda); lados = quais lados existem.
        Vão de portão na frente, centrado em vao_x (alinhado com a porta). extra_vaos: {lado: [(t0,t1)]} em m ao longo do lado."""
        xl, xr = -(self.w / 2 + ml), self.w / 2 + mr
        yf, yb = -(self.d / 2 + mf), self.d / 2 + mb
        extra_vaos = extra_vaos or {}
        # cada lado percorre o lote no sentido anti-horário: frente (xl->xr), direita (yf->yb), fundos (xr->xl), esquerda (yb->yf)
        cantos = [(xl, yf), (xr, yf), (xr, yb), (xl, yb)]
        nomes = ["frente", "direita", "fundos", "esquerda"]
        for i in range(4):
            if not lados[i]:
                continue
            a = self.W(*cantos[i])
            b = self.W(*cantos[(i + 1) % 4])
            pul = list(extra_vaos.get(nomes[i], []))
            # abrir = [(x, y, m)]: abre um vão de m metros para cada lado do ponto do mundo (x, y) se ele estiver sobre este lado
            for (ax, ay, am) in abrir:
                A, Bp = cantos[i], cantos[(i + 1) % 4]
                lx, ly = self.L(ax, ay)
                vx, vy = Bp[0] - A[0], Bp[1] - A[1]
                Ls = math.hypot(vx, vy)
                t = ((lx - A[0]) * vx + (ly - A[1]) * vy) / Ls
                dd = abs((lx - A[0]) * vy - (ly - A[1]) * vx) / Ls
                if dd < 2.0 and -am < t < Ls + am:
                    pul.append((t - am, t + am))
            if i == 0:
                for px in (self.portas if vao_x is None else [vao_x]):
                    g0 = (px - vao / 2) - xl
                    pul.append((g0, g0 + vao))
            cerca(a, b, modos[i], pul)


_LAYOUT = None


def B(bid):
    global _LAYOUT
    if _LAYOUT is None:
        with open(os.path.join(ILHA, "ilha_layout.json"), encoding="utf-8") as f:
            _LAYOUT = json.load(f)
    import checa_cenario as CC
    for p in _LAYOUT["pois"]:
        for b in p["predios"]:
            if b["id"] == bid:
                return Casa(CC.forma_demo(b, p["centro"]))
    raise KeyError(bid)


def ao_longo(a, b, passo, off, lado, tipos, ini=0.0, fim=None, rot_extra=0.0, esc=None):
    """peças alinhadas ao longo do trecho a->b, a 'off' metros do eixo (lado +1 = esquerda de a->b, -1 = direita),
    uma a cada 'passo' m, ciclando 'tipos' (lista de nomes de natureza ou tipos completos)."""
    L = math.dist(a, b)
    ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    nx, ny = -uy * lado, ux * lado
    fim = L if fim is None else fim
    t = ini
    k = 0
    while t <= fim + 1e-6:
        tp = tipos[k % len(tipos)]
        x, y = a[0] + ux * t + nx * off, a[1] + uy * t + ny * off
        re = rot_extra[k % len(rot_extra)] if isinstance(rot_extra, (list, tuple)) else rot_extra
        sc = esc[k % len(esc)] if isinstance(esc, (list, tuple)) else esc
        P(tp if "/" in tp else NAT + tp, x, y, math.degrees(math.atan2(uy, ux)) + re, sc)
        t += passo
        k += 1


def gravar():
    saida = os.path.join(RAIZ, "docs", "design", "cenario_areas_02.json")
    n = sum(len(a["props"]) for a in AREAS)
    doc = {"versao": 1, "fonte": "tools/cenario_02_src.py (decisões autorais; sem sorteio)", "total": n, "areas": AREAS}
    with open(saida, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    shutil.copyfile(saida, os.path.join(ILHA, "cenario_areas_02.json"))
    print("gravado", saida, n, "peças em", len(AREAS), "áreas")
    for a in AREAS:
        print("  %-30s %4d" % (a["nome"], len(a["props"])))
