# -*- coding: utf-8 -*-
"""
Desenha o radar/minimapa da Ilha do Tauá (1024x1024) a partir de
docs/design/ilha_layout.json -> docs/design/ilha_radar.png

Camadas: mar (com faixa rasa), relevo hipsométrico + sombreamento, curvas de nível
(10 m; mestras a cada 50 m), vegetação autoral, rio e represa, estradas/trilhas/pista,
pontes, prédios, POIs com nomes, grade 100 m (A–L / 1–12), rota de avião R1, escala e norte.

Uso:  python tools/render_ilha.py [--sem-grade] [--saida caminho.png]
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ilha_terreno import carregar, Terreno, dentro, RAIZ

N = 1024
MUNDO = 1200.0
S = N / MUNDO
SAIDA = os.path.join(RAIZ, "docs", "design", "ilha_radar.png")


def px(x, y):
    return ((x + MUNDO / 2) * S, (MUNDO / 2 - y) * S)


def fonte(tam, negrito=False):
    nomes = ["arialbd.ttf" if negrito else "arial.ttf", "DejaVuSans-Bold.ttf" if negrito else "DejaVuSans.ttf"]
    for n in nomes:
        for base in ("C:/Windows/Fonts/", ""):
            try:
                return ImageFont.truetype(base + n, tam)
            except OSError:
                pass
    return ImageFont.load_default()


# Rampa hipsométrica (altura m -> cor)
RAMPA = [(0, (226, 211, 160)), (4, (214, 205, 150)), (8, (150, 178, 104)), (30, (118, 160, 88)),
         (60, (98, 140, 76)), (100, (128, 132, 84)), (140, (146, 124, 92)), (185, (176, 160, 140))]


def colorir(z):
    zs = np.array([r[0] for r in RAMPA], float)
    cs = np.array([r[1] for r in RAMPA], float)
    out = np.zeros(z.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(z, zs, cs[:, c])
    return out


VEG_COR = {
    "mata_atlantica_densa": ((34, 92, 48), 120), "mata_atlantica_media": ((52, 110, 58), 95),
    "mata_ciliar": ((40, 100, 60), 110), "capoeira": ((96, 130, 60), 90), "canavial": ((170, 190, 70), 120),
    "bananal": ((120, 170, 60), 110), "manguezal": ((70, 100, 80), 120), "coqueiral": ((120, 160, 80), 80),
    "restinga": ((150, 165, 100), 80), "eucalipto_linha": ((60, 90, 70), 160), "pasto_aberto": ((200, 210, 120), 45),
}
ESTRADA_EST = {
    "estrada_terra": ((196, 160, 110), (90, 64, 40)), "estrada_calcamento": ((200, 200, 196), (70, 70, 70)),
    "trilha": ((235, 220, 180), None), "pista_pouso": ((208, 180, 130), (110, 84, 50)),
}


def main():
    args = sys.argv[1:]
    saida = SAIDA
    if "--saida" in args:
        saida = args[args.index("--saida") + 1]
    dados = carregar()
    ter = Terreno(dados)

    # --- grade de alturas no centro de cada pixel
    c = (np.arange(N) + 0.5) / S - MUNDO / 2
    X, Y = np.meshgrid(c, -c)
    Z = ter.altura(X, Y)
    terra = Z > -1

    # --- mar com faixa rasa
    img = np.zeros((N, N, 3))
    mask_img = Image.fromarray((terra * 255).astype(np.uint8))
    raso = np.array(mask_img.filter(ImageFilter.MaxFilter(31))) > 0
    raso2 = np.array(mask_img.filter(ImageFilter.MaxFilter(13))) > 0
    img[:] = (38, 84, 124)
    img[raso] = (52, 110, 150)
    img[raso2] = (74, 140, 170)

    # --- relevo + sombreamento (luz de NO)
    gy, gx = np.gradient(Z, 1 / S)
    nx, ny, nz = -gx, gy, np.ones_like(Z) * 1.0
    nrm = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    L = np.array([-1, 1, 1.4]); L = L / np.linalg.norm(L)
    sh = (nx * L[0] + ny * L[1] + nz * L[2]) / nrm
    sh = np.clip(0.55 + 0.6 * (sh - 0.7), 0.45, 1.15)
    land = colorir(Z) * sh[..., None]
    img[terra] = land[terra]

    base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")

    # --- vegetação (camada translúcida)
    veg = Image.new("RGBA", (N, N), (0, 0, 0, 0)); dv = ImageDraw.Draw(veg)
    for m in dados["vegetacao"]:
        cor, a = VEG_COR.get(m["tipo"], ((80, 120, 60), 90))
        dv.polygon([px(*p) for p in m["poligono"]], fill=cor + (a,))
        if m["tipo"] == "canavial":  # hachura de fileiras
            xs = [px(*p) for p in m["poligono"]]
            x0, x1 = min(p[0] for p in xs), max(p[0] for p in xs)
            y0, y1 = min(p[1] for p in xs), max(p[1] for p in xs)
            hach = Image.new("L", (N, N), 0); dh = ImageDraw.Draw(hach)
            for yy in range(int(y0), int(y1), 4):
                dh.line([(x0, yy), (x1, yy)], fill=255)
            pm = Image.new("L", (N, N), 0); ImageDraw.Draw(pm).polygon(xs, fill=255)
            hm = Image.fromarray((np.array(hach) & np.array(pm)))
            veg.paste((120, 140, 40, 150), (0, 0), hm)
    base = Image.alpha_composite(base, veg)

    # --- curvas de nível
    Zc = np.where(terra, Z, -100)
    b10 = np.floor(Zc / 10); b50 = np.floor(Zc / 50)
    edge10 = np.zeros_like(terra); edge50 = np.zeros_like(terra)
    edge10[:-1, :] |= b10[:-1, :] != b10[1:, :]; edge10[:, :-1] |= b10[:, :-1] != b10[:, 1:]
    edge50[:-1, :] |= b50[:-1, :] != b50[1:, :]; edge50[:, :-1] |= b50[:, :-1] != b50[:, 1:]
    edge10 &= terra & (Z > 1); edge50 &= terra & (Z > 1)
    cont = np.zeros((N, N, 4), np.uint8)
    cont[edge10] = (70, 50, 30, 95)
    e50 = np.array(Image.fromarray((edge50 * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    cont[e50 & terra] = (70, 45, 25, 175)
    base = Image.alpha_composite(base, Image.fromarray(cont))

    # --- linha de costa
    d = ImageDraw.Draw(base)
    costa = [px(*p) for p in dados["costa"]]
    d.line(costa + [costa[0]], fill=(250, 245, 220, 255), width=2)
    for f in dados["terreno"]["falesias"]:
        pts = [px(*p) for p in f["pontos"]]
        d.line(pts, fill=(120, 70, 40, 255), width=4)
        for i in range(len(pts) - 1):  # dentes de falésia
            (x1, y1), (x2, y2) = pts[i], pts[i + 1]
            Lh = math.hypot(x2 - x1, y2 - y1)
            if Lh < 1: continue
            ux, uy = (x2 - x1) / Lh, (y2 - y1) / Lh
            for t in np.arange(0, Lh, 6):
                bx, by = x1 + ux * t, y1 + uy * t
                d.line([(bx, by), (bx - uy * 5, by + ux * 5)], fill=(120, 70, 40, 255), width=1)

    # --- água doce
    agua = (70, 140, 190, 255)
    rep = dados["agua"]["represa"]
    d.polygon([px(*p) for p in rep["contorno"]], fill=agua, outline=(40, 90, 140, 255))
    for t in dados["agua"]["rio"]["trechos"]:
        w = max(2, int(round(t["largura_m"] * S)))
        d.line([px(p[0], p[1]) for p in t["pontos"]], fill=agua, width=w, joint="curve")
    bg = rep["barragem"]
    d.line([px(*bg["de"]), px(*bg["ate"])], fill=(215, 215, 210, 255), width=max(4, int(bg["largura_crista_m"] * S) + 2))

    # --- estradas (contorno primeiro, depois miolo)
    ordem = ["pista_pouso", "estrada_terra", "estrada_calcamento", "trilha"]
    for tipo in ordem:
        for e in dados["estradas"]:
            if e["tipo"] != tipo: continue
            cor, borda = ESTRADA_EST[tipo]
            pts = [px(*p) for p in e["pontos"]]
            w = max(2, int(round(e["largura_m"] * S)))
            if tipo == "trilha":
                for i in range(len(pts) - 1):
                    (x1, y1), (x2, y2) = pts[i], pts[i + 1]
                    Lh = math.hypot(x2 - x1, y2 - y1)
                    for t0 in np.arange(0, Lh, 7):
                        t1 = min(Lh, t0 + 4)
                        d.line([(x1 + (x2 - x1) * t0 / Lh, y1 + (y2 - y1) * t0 / Lh),
                                (x1 + (x2 - x1) * t1 / Lh, y1 + (y2 - y1) * t1 / Lh)], fill=(250, 238, 200, 255), width=2)
                continue
            if borda:
                d.line(pts, fill=borda + (255,), width=w + 2, joint="curve")
            d.line(pts, fill=cor + (255,), width=w, joint="curve")
            if tipo == "pista_pouso":  # faixa central
                d.line(pts, fill=(245, 235, 210, 255), width=1)

    for b in dados["pontes"]:
        x, y = b["pos"]; r = math.radians(b["rot_deg"])
        hl = b["comprimento_m"] / 2
        a = px(x - hl * math.cos(r), y - hl * math.sin(r)); c2 = px(x + hl * math.cos(r), y + hl * math.sin(r))
        cor = {"concreto": (230, 230, 225), "madeira": (150, 100, 60), "barragem": (230, 230, 225)}.get(b["tipo"], (170, 170, 160))
        d.line([a, c2], fill=(30, 30, 30, 255), width=max(3, int(b["largura_m"] * S)) + 2)
        d.line([a, c2], fill=cor + (255,), width=max(2, int(b["largura_m"] * S)))

    # --- muros e terreiros
    for p in dados["pois"]:
        if "terreiro" in p:
            d.polygon([px(*q) for q in p["terreiro"]], fill=(215, 200, 170, 255), outline=(120, 100, 70, 255))
        if "muro" in p:
            m = [px(*q) for q in p["muro"]]
            d.line(m + [m[0]], fill=(90, 90, 90, 255), width=2)

    # --- prédios
    for p in dados["pois"] + dados["marcos"]:
        for b in p["predios"]:
            w, dd, h = b["tamanho_m"]; x, y = b["pos"]; r = math.radians(b["rot_deg"])
            cs, sn = math.cos(r), math.sin(r)
            cantos = []
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                lx, ly = sx * w / 2, sy * dd / 2
                cantos.append(px(x + lx * cs - ly * sn, y + lx * sn + ly * cs))
            if b["tipo"] in ("heliponto", "curral"):
                d.polygon(cantos, fill=None, outline=(60, 60, 60, 255))
            else:
                alto = h >= 12
                d.polygon(cantos, fill=(55, 50, 50, 255) if alto else (92, 84, 80, 255), outline=(25, 25, 25, 255))

    # --- cobertura em campo aberto (pontinhos)
    for cv in dados["cobertura_campo_aberto"]:
        x, y = px(*cv["pos"])
        d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(60, 60, 60, 220))

    # --- grade 100 m estilo radar
    over = Image.new("RGBA", (N, N), (0, 0, 0, 0)); do = ImageDraw.Draw(over)
    f_g = fonte(12, True)
    letras = "ABCDEFGHIJKL"
    for i in range(13):
        v = i * 100 * S
        do.line([(v, 0), (v, N)], fill=(255, 255, 255, 38), width=1)
        do.line([(0, v), (N, v)], fill=(255, 255, 255, 38), width=1)
    for i in range(12):
        do.text((i * 100 * S + 37, 4), letras[i], font=f_g, fill=(255, 255, 255, 170))
        do.text((4, i * 100 * S + 36), str(i + 1), font=f_g, fill=(255, 255, 255, 170))
    # rota do avião R1 (exemplo)
    r1 = dados["aviao"]["rotas"][0]
    a, b2 = px(*r1["de"]), px(*r1["ate"])
    Lh = math.hypot(b2[0] - a[0], b2[1] - a[1])
    for t0 in np.arange(0, Lh, 14):
        t1 = min(Lh, t0 + 8)
        do.line([(a[0] + (b2[0] - a[0]) * t0 / Lh, a[1] + (b2[1] - a[1]) * t0 / Lh),
                 (a[0] + (b2[0] - a[0]) * t1 / Lh, a[1] + (b2[1] - a[1]) * t1 / Lh)], fill=(255, 255, 255, 120), width=2)
    base = Image.alpha_composite(base, over)
    d = ImageDraw.Draw(base)
    d.text((px(420, 470)[0], px(420, 470)[1]), "✈ rota R1", font=fonte(12), fill=(255, 255, 255, 200))

    # --- rótulos dos POIs
    f_poi = fonte(15, True); f_sub = fonte(11)
    TIER_COR = {"alto": (200, 60, 200), "medio": (70, 130, 230), "baixo": (150, 150, 150)}
    OFFS = {"vila_caicara": (0, 70), "morro_cruzeiro": (-10, -62), "usina_santa_cruz": (0, -68),
            "farol_ponta_norte": (-70, 30), "quartel": (0, -84), "pedreira": (40, -62), "pista_pouso": (10, 40),
            "represa": (60, 40), "fazenda_boa_esperanca": (30, 75), "praia_quiosques": (0, 50), "pico_taua": (0, -34)}

    def rotulo(texto, x, y, f, cor=(255, 255, 255), halo=(20, 20, 20)):
        bb = d.textbbox((0, 0), texto, font=f)
        tx, ty = x - (bb[2] - bb[0]) / 2, y - (bb[3] - bb[1]) / 2
        d.text((tx, ty), texto, font=f, fill=cor, stroke_width=3, stroke_fill=halo)

    for p in dados["pois"] + dados["marcos"]:
        cx, cy = px(*p["centro"])
        cor = TIER_COR[p["tier"]]
        d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=cor + (255,), outline=(255, 255, 255, 255), width=2)
        ox, oy = OFFS.get(p["id"], (0, -30))
        rotulo(p["nome"], cx + ox, cy - oy * 0.6 if oy < 0 else cy + oy * 0.6, f_poi)
        sub = f'{p["altura_m"][0]}–{p["altura_m"][1]} m · saque {p["tier"]}'
        rotulo(sub, cx + ox, (cy - oy * 0.6 if oy < 0 else cy + oy * 0.6) + 15, f_sub, cor=(235, 235, 235))

    # nomes de feições
    f_f = fonte(12)
    rotulo("Represa", *px(-40, -25), fonte(10), cor=(220, 240, 255), halo=(30, 70, 110))
    rotulo("Rio Tauá", *px(-230, -170), fonte(10), cor=(220, 240, 255), halo=(30, 70, 110))
    rotulo("Serra do Tauá", *px(-80, 195), f_f, cor=(240, 230, 200), halo=(40, 60, 30))
    rotulo("Morro do Sul", *px(130, -60), f_f, cor=(240, 230, 200), halo=(40, 60, 30))
    rotulo("Falésias", *px(455, -110), f_f, cor=(250, 220, 190), halo=(90, 50, 30))
    rotulo("Oceano Atlântico", *px(-420, -540), fonte(14, True), cor=(200, 225, 245), halo=(30, 60, 100))

    # --- título, escala, norte
    d.rectangle([12, N - 58, 330, N - 12], fill=(15, 25, 35, 190))
    d.text((22, N - 54), "ILHA DO TAUÁ — radar", font=fonte(16, True), fill=(255, 255, 255))
    d.text((22, N - 33), "1,2 × 1,2 km · curvas 10 m (mestra 50 m)", font=fonte(11), fill=(220, 220, 220))
    x0, y0 = N - 190, N - 30
    d.rectangle([x0 - 10, y0 - 22, x0 + 175, y0 + 16], fill=(15, 25, 35, 190))
    for i in range(4):
        d.rectangle([x0 + i * 50 * S, y0, x0 + (i + 1) * 50 * S, y0 + 6], fill=(255, 255, 255) if i % 2 == 0 else (60, 60, 60))
    d.text((x0, y0 - 18), "0     50    100   150   200 m", font=fonte(11), fill=(255, 255, 255))
    nx0, ny0 = N - 40, 60
    d.polygon([(nx0, ny0 - 26), (nx0 - 10, ny0 + 4), (nx0, ny0 - 3), (nx0 + 10, ny0 + 4)], fill=(255, 255, 255), outline=(20, 20, 20))
    rotulo("N", nx0, ny0 + 16, fonte(14, True))
    # legenda de tier
    lx, ly = N - 180, 100
    d.rectangle([lx - 8, ly - 8, lx + 165, ly + 58], fill=(15, 25, 35, 170))
    for i, (t, c3) in enumerate(TIER_COR.items()):
        d.ellipse([lx, ly + i * 17, lx + 10, ly + 10 + i * 17], fill=c3)
        d.text((lx + 16, ly - 2 + i * 17), f"saque {t}", font=fonte(12), fill=(255, 255, 255))

    base.convert("RGB").save(saida, optimize=True)
    print("radar gravado em", saida, "| z min/max terra:", round(float(Z[terra].min()), 1), round(float(Z[terra].max()), 1))


if __name__ == "__main__":
    main()
