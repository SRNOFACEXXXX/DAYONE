# -*- coding: utf-8 -*-
"""Terreno da Ilha do Tauá a partir dos DADOS AUTORAIS de docs/design/ilha_layout.json (nada aleatório):
  1. altura base: spline sobre os 180 pontos de altura desenhados + costa em z=0 (tools/ilha_terreno.py)
  2. fundo do mar: cai até -10 m em 60 m além da costa
  3. cortes feitos à mão pelos dados: platôs dos prédios (média sob a planta + borda suave),
     leito das estradas (corte transversal plano), leito do rio (1,5 m abaixo, com margens), represa (fundo e barragem)
  4. mapa de materiais (splat RGBA): R areia, G grama, B rocha, A terra batida (estradas/terreiros)
Saídas em game/maps/ilha/: height.exr-equivalente como PNG 16 bits (height16.png) + height.bin (float32),
splat.png, meta.json (escala). Grade de 2 m (601 x 601).
Uso: python tools/bake_ilha.py
"""
import json, os, math
import numpy as np
from PIL import Image
import ilha_terreno as IT

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RAIZ, "game", "maps", "ilha")
os.makedirs(OUT, exist_ok=True)
PASSO = 2.0
N = 601
H_MIN, H_MAX = -20.0, 220.0

D = IT.carregar()
T = IT.Terreno(D)
xs = np.linspace(-600, 600, N)
ys = np.linspace(-600, 600, N)
X, Y = np.meshgrid(xs, ys)            # linha = y (sul -> norte), coluna = x (oeste -> leste)
print("amostrando spline...")
H = T.altura(X, Y).reshape(X.shape).astype(np.float64)

# ---------------------------------------------------------------- mar
costa = D["costa"]
dentro = IT.dentro(costa, X, Y)


def dist_polilinha(px, py, pts):
    """Distância de cada ponto da grade a uma polilinha (vetorizado)."""
    d = np.full(px.shape, 1e9)
    for (x1, y1), (x2, y2) in zip(pts[:-1], pts[1:]):
        vx, vy = x2 - x1, y2 - y1
        L2 = vx * vx + vy * vy or 1e-9
        t = np.clip(((px - x1) * vx + (py - y1) * vy) / L2, 0, 1)
        d = np.minimum(d, np.hypot(px - (x1 + t * vx), py - (y1 + t * vy)))
    return d


print("mar...")
dc = dist_polilinha(X, Y, costa + [costa[0]])
mar = ~dentro
H[mar] = np.minimum(H[mar], 0.0) - np.clip(dc[mar] / 60.0, 0, 1) * 10.0
# praia: faixa de 0 a 25 m da costa sobe devagar (evita degrau)
praia = dentro & (dc < 25)
H[praia] = np.minimum(H[praia], 0.3 + dc[praia] * 0.12 + np.maximum(H[praia] - 3.0, 0) * (dc[praia] / 25.0))


def suave(x):
    return x * x * (3 - 2 * x)


def achatar_faixa(pts_xyz, largura, borda, profundidade=0.0, usar_z=False):
    """Corte transversal plano ao longo de uma polilinha: altura do eixo (interpolada) - profundidade."""
    global H
    pts = [(p[0], p[1]) for p in pts_xyz]
    # altura do eixo: do dado (rio) ou do próprio terreno amostrado no eixo
    eixo = []
    for p in pts_xyz:
        if usar_z and len(p) > 2:
            eixo.append(p[2])
        else:
            eixo.append(float(T.altura(np.array([p[0]]), np.array([p[1]]))[0]))
    best_d = np.full(X.shape, 1e9)
    best_h = np.zeros(X.shape)
    for i in range(len(pts) - 1):
        (x1, y1), (x2, y2) = pts[i], pts[i + 1]
        vx, vy = x2 - x1, y2 - y1
        L2 = vx * vx + vy * vy or 1e-9
        t = np.clip(((X - x1) * vx + (Y - y1) * vy) / L2, 0, 1)
        d = np.hypot(X - (x1 + t * vx), Y - (y1 + t * vy))
        h = eixo[i] + (eixo[i + 1] - eixo[i]) * t
        m = d < best_d
        best_d[m] = d[m]
        best_h[m] = h[m]
    alvo = best_h - profundidade
    w = np.clip((best_d - largura / 2) / borda, 0, 1)
    k = 1.0 - suave(w)
    m = best_d < largura / 2 + borda
    H[m] = H[m] * (1 - k[m]) + alvo[m] * k[m]
    return best_d


# ---------------------------------------------------------------- estradas
print("estradas...")
d_estrada = np.full(X.shape, 1e9)
for e in D["estradas"]:
    larg = float(e.get("largura_m", 5))
    d = achatar_faixa(e["pontos"], larg, 10.0)   # talude em rampa (6 m deixava barranco íngreme)
    d_estrada = np.minimum(d_estrada, d - larg / 2)

# ---------------------------------------------------------------- rio e represa
print("rio e represa...")
d_rio = np.full(X.shape, 1e9)
for tr in D["agua"]["rio"]["trechos"]:
    larg = float(tr["largura_m"])
    d = achatar_faixa(tr["pontos"], larg, 4.0, profundidade=1.6, usar_z=True)
    d_rio = np.minimum(d_rio, d - larg / 2)
rep = D["agua"]["represa"]
dentro_rep = IT.dentro(rep["contorno"], X, Y)
d_rep = dist_polilinha(X, Y, rep["contorno"] + [rep["contorno"][0]])
fundo = rep["nivel_agua_m"] - rep["profundidade_max_m"] * np.clip(d_rep / 25.0, 0.2, 1.0)
H[dentro_rep] = np.minimum(H[dentro_rep], fundo[dentro_rep])
# margens: até 22 m fora do contorno o terreno desce suave até 1 m acima da água (sem paredão)
fora = (~dentro_rep) & (d_rep < 22.0)
k_m = 1.0 - suave(np.clip(d_rep[fora] / 22.0, 0, 1))
alvo_m = rep["nivel_agua_m"] + 1.0
H[fora] = np.where(H[fora] > alvo_m, H[fora] * (1 - k_m) + alvo_m * k_m, H[fora])
b = rep["barragem"]
achatar_faixa([b["de"] + [b["altura_crista_m"]], b["ate"] + [b["altura_crista_m"]]], b["largura_crista_m"] + 8, 10.0, usar_z=True)

# ---------------------------------------------------------------- platôs dos prédios
print("platôs...")
d_predio = np.full(X.shape, 1e9)
predios = [pr for poi in D["pois"] for pr in poi["predios"]] + [pr for mk in D.get("marcos", []) for pr in mk.get("predios", [])]
for pr in predios:
    cx, cy = pr["pos"]
    sx, sy = pr["tamanho_m"][0], pr["tamanho_m"][1]
    a = math.radians(pr.get("rot_deg", 0))
    ca, sa = math.cos(a), math.sin(a)
    lx = (X - cx) * ca + (Y - cy) * sa
    ly = -(X - cx) * sa + (Y - cy) * ca
    ex = np.maximum(np.abs(lx) - sx / 2 - 1.5, 0)
    ey = np.maximum(np.abs(ly) - sy / 2 - 1.5, 0)
    d = np.hypot(ex, ey)
    m0 = d == 0
    if not m0.any():
        continue
    alvo = float(np.median(H[m0]))
    borda = 8.0
    w = np.clip(d / borda, 0, 1)
    k = 1 - suave(w)
    m = d < borda
    H[m] = H[m] * (1 - k[m]) + alvo * k[m]
    d_predio = np.minimum(d_predio, d)

H = np.clip(H, H_MIN, H_MAX)

# ---------------------------------------------------------------- materiais
print("materiais...")
gy, gx = np.gradient(H, PASSO)
inclin = np.degrees(np.arctan(np.hypot(gx, gy)))
areia = (dentro & (dc < 22) & (H < 4.5)).astype(float)
areia = np.maximum(areia, ((H < 2.5) & (dc < 40)).astype(float))
rocha = np.clip((inclin - 42.0) / 10.0, 0, 1)   # encosta íngreme no litoral BR é mata; rocha nua só no quase vertical
for f in D["terreno"]["falesias"]:
    rocha = np.maximum(rocha, np.clip(1 - dist_polilinha(X, Y, f["pontos"]) / 14.0, 0, 1))
pedreira = next((p for p in D["pois"] if "pedreira" in p["id"]), None)
if pedreira:
    rocha = np.maximum(rocha, np.clip(1 - np.hypot(X - pedreira["centro"][0], Y - pedreira["centro"][1]) / pedreira["raio_m"], 0, 1) * 0.9)
terra = np.clip(1 - d_estrada / 1.5, 0, 1)
terra = np.maximum(terra, np.clip(1 - d_predio / 4.0, 0, 1) * 0.7)
terra = np.maximum(terra, np.clip(1 - d_rio / 2.0, 0, 1) * 0.8)
areia = np.clip(areia - rocha, 0, 1)
grama = np.clip(1 - np.maximum.reduce([areia, rocha, terra]), 0, 1)
for nome, arr in (("areia", areia), ("grama", grama), ("rocha", rocha), ("terra", terra), ("d_estrada", d_estrada), ("d_predio", d_predio), ("d_rio", d_rio)):
    print("DIAG", nome, "nan=%d" % int(np.isnan(arr).sum()), "min=%.3g max=%.3g media=%.3g" % (np.nanmin(arr), np.nanmax(arr), np.nanmean(arr)))
splat = np.stack([areia, grama, rocha, terra], -1)
splat = splat / np.maximum(splat.sum(-1, keepdims=True), 1e-6)
# linha 0 = norte na imagem (y maior no topo)
# só RGB (areia, grama, rocha): terra = 1 - soma, calculada no shader. Um PNG RGBA perde as cores onde alfa = 0
# (o resize do Pillow pré-multiplica e o importador do Godot "conserta" a borda do alfa).
img = Image.fromarray((splat[::-1, :, :3] * 255).round().astype(np.uint8), "RGB").resize((1024, 1024), Image.BILINEAR)
img.save(os.path.join(OUT, "splat.png"))
# máscara de mata (manchas autorais do design): o shader escurece o chão para "sub-bosque" -> a serra lê como mata de longe
mata = np.zeros(X.shape)
for v in D["vegetacao"]:
    if "mata" in v["tipo"] or "capoeira" in v["tipo"] or "restinga" in v["tipo"]:
        dens = 1.0 if "densa" in v["tipo"] else 0.6
        mata = np.maximum(mata, IT.dentro(v["poligono"], X, Y).astype(float) * dens)
mata[d_estrada < 2.0] = 0.0
cana = np.zeros(X.shape)
for v in D["vegetacao"]:
    if "canavial" in v["tipo"]:
        cana = np.maximum(cana, IT.dentro(v["poligono"], X, Y).astype(float))
cana[d_estrada < 2.0] = 0.0
# B = manchas de capim seco (chao_vivo.json, autorais)
seco = np.zeros(X.shape)
CV = os.path.join(RAIZ, "docs", "design", "chao_vivo.json")
if os.path.exists(CV):
    cvd = json.load(open(CV, encoding="utf-8"))
    for mcha in cvd.get("manchas_capim_seco", []):
        seco = np.maximum(seco, IT.dentro(mcha["poligono"], X, Y).astype(float))
    # trilhas de pé: máscara própria em alta resolução (0,59 m/px), lida por pixel no shader (as células de 4 m as apagariam)
    from PIL import ImageDraw
    R2 = 2048
    tr_img = Image.new("L", (R2, R2), 0)
    dr = ImageDraw.Draw(tr_img)
    esc = R2 / 1200.0
    for t in cvd.get("trilhas_pe", []):
        pts = [((x + 600) * esc, (600 - y) * esc) for x, y in t["pontos"]]
        w = max(2, int(round(float(t.get("largura_m", 1.2)) * esc)))
        dr.line(pts, fill=255, width=w, joint="curve")
        for q in pts:
            dr.ellipse((q[0] - w / 2, q[1] - w / 2, q[0] + w / 2, q[1] + w / 2), fill=255)
    # G = sulcos de roda (polilinhas autorais do Design, 0,35 m) sobre as estradas de terra
    # desenhado 4x maior e reduzido (antialias): linha de 0,35 m não vira "linguiça" de pixels
    SS = 4
    su_img = Image.new("L", (R2 * SS, R2 * SS), 0)
    ds = ImageDraw.Draw(su_img)
    for t in cvd.get("sulcos_roda", []):
        pts = [((x + 600) * esc * SS, (600 - y) * esc * SS) for x, y in t["pontos"]]
        w = max(1, int(round(max(0.55, float(t.get("largura_m", 0.35))) * esc * SS)))   # >= 1 texel (0,59 m) senão tracejava
        ds.line(pts, fill=255, width=w, joint="curve")
    su_img = su_img.resize((R2, R2), Image.BOX)
    Image.merge("RGB", (tr_img, su_img, Image.new("L", (R2, R2), 0))).save(os.path.join(OUT, "trilhas.png"))
# R = mata (sub-bosque), G = canavial (lido de longe pela cor; as touceiras só aparecem até 110 m)
Image.fromarray((np.stack([mata, cana, seco], -1)[::-1] * 255).astype(np.uint8), "RGB").resize((512, 512), Image.BILINEAR).save(os.path.join(OUT, "mata.png"))
# profundidade da água (R = mar, G = represa), 0..16 m -> 0..1: cor por profundidade + espuma na beira no shader
prof_mar = np.clip(-H / 16.0, 0, 1)
prof_rep = np.clip((rep["nivel_agua_m"] - H) / 16.0, 0, 1) * (dentro_rep | (d_rep < 30)).astype(float)
Image.fromarray((np.stack([prof_mar, prof_rep, np.zeros_like(H)], -1)[::-1] * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "agua.png"))
H[::-1].astype(np.float32).tofile(os.path.join(OUT, "height.bin"))
h16 = ((H - H_MIN) / (H_MAX - H_MIN) * 65535).round().astype(np.uint16)
Image.fromarray(h16[::-1], "I;16").save(os.path.join(OUT, "height16.png"))
json.dump({"size_px": N, "step_m": PASSO, "origin_m": [-600, -600], "h_min": H_MIN, "h_max": H_MAX,
           "row0": "norte (y=+600)", "agua_mar_m": 0.0, "represa_nivel_m": rep["nivel_agua_m"]},
          open(os.path.join(OUT, "meta.json"), "w"), indent=1)
# prévia: sombreamento + materiais
shade = np.clip(0.55 + 0.45 * (-gx * 0.7 + gy * 0.7) / np.maximum(np.hypot(gx, gy), 1e-3) * np.clip(inclin / 30, 0, 1), 0.2, 1.1)
cor = (splat[..., 0:1] * [214, 196, 150] + splat[..., 1:2] * [92, 128, 60] + splat[..., 2:3] * [120, 112, 100] + splat[..., 3:4] * [150, 112, 72])
cor = cor * shade[..., None]
cor[mar] = [40, 90, 130]
cor[dentro_rep] = [60, 120, 150]
Image.fromarray(np.clip(cor[::-1], 0, 255).astype(np.uint8)).save(os.path.join(RAIZ, "raw", "terreno_preview.png"))
print("OK", float(H.min()), float(H.max()))
