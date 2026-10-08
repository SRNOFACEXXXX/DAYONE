# Ajusta a posição/giro de cada casa do pacote (toda casa residencial do layout + casas_pacote.json): sai da estrada (terra batida),
# do mar/rio, de declives e de outros prédios; a porta passa a olhar para a estrada/rua mais próxima (ou o centro do POI).
# Determinístico: varre deslocamentos de 0 a 16 m e escolhe o de menor custo. Saída: game/maps/ilha/casas_ajuste.json
#   {"<id do prédio>": {"dx": m_leste, "dy": m_norte, "yaw_deg": giro Godot}}  (ids "extra_N" para casas_pacote.json)
import json, math, os
import numpy as np
from PIL import Image
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ILHA = os.path.join(RAIZ, "game", "maps", "ilha")
H = np.fromfile(os.path.join(ILHA, "height.bin"), dtype=np.float32).reshape(601, 601)
SP = np.asarray(Image.open(os.path.join(ILHA, "splat.png")).convert("RGB")).astype(np.float32) / 255.0   # linha 0 = norte
L = json.load(open(os.path.join(ILHA, "ilha_layout.json"), encoding="utf-8"))
EXTRA = json.load(open(os.path.join(ILHA, "casas_pacote.json"), encoding="utf-8")).get("casas", [])
TIPOS = ["casa_laje", "casa_caicara", "casa_colono", "sobrado", "casa_faroleiro", "casa_piloto", "casa_operador", "vila_operaria", "casarao"]
MEIO = 6.6   # meia pegada (casa 12,9 x 13,3 m)


def alt(x, z):   # x leste, z sul (Godot)
    c = (x + 600) / 2; r = (z + 600) / 2
    return float(H[min(600, max(0, int(round(r)))), min(600, max(0, int(round(c))))])


def terra(x, z):
    u = (x + 600) / 1200; v = (z + 600) / 1200
    px = SP[min(SP.shape[0] - 1, max(0, int(v * SP.shape[0]))), min(SP.shape[1] - 1, max(0, int(u * SP.shape[1])))]
    return max(0.0, 1.0 - float(px.sum()))


estradas = [[(p[0], -p[1]) for p in e["pontos"]] for e in L["estradas"]]   # (x, z)


def dist_estrada(x, z):
    best = (1e9, 0.0, 0.0)
    for e in estradas:
        for a, b in zip(e, e[1:]):
            ax, az = a; bx, bz = b
            dx, dz = bx - ax, bz - az
            t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / max(dx * dx + dz * dz, 1e-9)))
            px, pz = ax + t * dx, az + t * dz
            d = math.hypot(x - px, z - pz)
            if d < best[0]:
                best = (d, px, pz)
    return best


pred = []    # (x, z, raio) de todos os prédios NÃO substituídos
casas = []   # (id, x, z, yaw_layout, cx, cz)
for poi in L["pois"] + L.get("marcos", []):
    ps = poi.get("predios", [])
    cx = sum(float(p["pos"][0]) for p in ps) / max(1, len(ps)); cz = sum(-float(p["pos"][1]) for p in ps) / max(1, len(ps))
    for p in ps:
        x, z = float(p["pos"][0]), -float(p["pos"][1])
        if p["tipo"] in TIPOS:
            n = 2 if p["tipo"] in ("vila_operaria", "casarao") else 1
            casas.append((p["id"], x, z, n, math.radians(float(p.get("rot_deg", 0))), cx, cz, p["tipo"]))
        else:
            sz = p["tamanho_m"]
            pred.append((x, z, 0.5 * math.hypot(sz[0], sz[1])))
for i, c in enumerate(EXTRA):
    casas.append(("extra_%d" % i, float(c["x"]), -float(c["y"]), 1, 0.0, float(c["x"]), -float(c["y"]) + 20, "extra"))

colocadas = []   # (x, z) já fixadas
saida = {}
movidas = 0
for (cid, x0, z0, n, rot_l, cx, cz, tipo) in sorted(casas, key=lambda c: c[0]):
    def pegada(x, z):
        pts = [(x, z)]
        if tipo == "vila_operaria":
            pts = [(x + math.sin(rot_l) * -6.9, z + math.cos(rot_l) * -6.9), (x + math.sin(rot_l) * 6.9, z + math.cos(rot_l) * 6.9)]
        elif tipo == "casarao":
            pts = [(x - math.cos(rot_l) * 7.2, z + math.sin(rot_l) * 7.2), (x + math.cos(rot_l) * 7.2, z - math.sin(rot_l) * 7.2)]
        return pts

    def custo(x, z):
        c = 0.0
        for (px, pz) in pegada(x, z):
            hs = []; t = 0.0; k = 0
            for a in np.arange(-MEIO - 1.2, MEIO + 1.3, 2.0):
                for b in np.arange(-MEIO - 1.2, MEIO + 1.3, 2.0):
                    hs.append(alt(px + a, pz + b)); t += terra(px + a, pz + b); k += 1
            if min(hs) < 1.6:
                return 1e9
            c += 30.0 * (t / k) + 3.0 * (max(hs) - min(hs))
            d, _, _ = dist_estrada(px, pz)
            if d < MEIO + 3.5:
                c += 8.0 * (MEIO + 3.5 - d)
            for (ox, oz, r) in pred:
                dd = math.hypot(px - ox, pz - oz)
                if dd < MEIO + 1.5 + r:
                    c += 40.0
            for (ox, oz) in colocadas:
                if math.hypot(px - ox, pz - oz) < 2 * MEIO + 3.0:
                    c += 40.0
        return c
    melhor = (custo(x0, z0), 0.0, 0.0)
    if melhor[0] > 6.0:
        for r in np.arange(2.0, 16.1, 2.0):
            for k in range(16):
                a = k * math.pi / 8
                dx, dz = r * math.cos(a), r * math.sin(a)
                c = custo(x0 + dx, z0 + dz) + 0.6 * r
                if c < melhor[0]:
                    melhor = (c, dx, dz)
    c, dx, dz = melhor
    x, z = x0 + dx, z0 + dz
    colocadas += pegada(x, z)
    d, px, pz = dist_estrada(x, z)
    if tipo in ("vila_operaria", "casarao"):
        yaw = rot_l + (math.pi / 2 if tipo == "vila_operaria" else 0.0)
    elif d < 30:
        yaw = math.atan2(px - x, pz - z)           # porta (+Z) para a estrada mais próxima
    else:
        yaw = math.atan2(cx - x, cz - z)
    if abs(dx) + abs(dz) > 0.01:
        movidas += 1
    saida[cid] = {"dx": round(dx, 1), "dy": round(-dz, 1), "yaw_deg": round(math.degrees(yaw), 1), "custo": round(c, 1)}
json.dump(saida, open(os.path.join(ILHA, "casas_ajuste.json"), "w", encoding="utf-8"), indent=1)
json.dump(saida, open(os.path.join(RAIZ, "docs", "design", "casas_ajuste.json"), "w", encoding="utf-8"), indent=1)
ruins = [k for k, v in saida.items() if v["custo"] > 25]
print("casas=%d movidas=%d ainda_ruins=%d %s" % (len(saida), movidas, len(ruins), ruins[:12]))
