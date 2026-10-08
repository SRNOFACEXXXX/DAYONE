# -*- coding: utf-8 -*-
"""
Validação simples de docs/design/ilha_layout.json.
ERRO = quebra o contrato de construção; AVISO = revisar à mão.
Saída != 0 se houver ERRO.

Uso:  python tools/validar_ilha.py
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ilha_terreno import carregar, Terreno, dentro, Z_MAX

erros, avisos, ok = [], [], []


def E(m): erros.append(m)
def A(m): avisos.append(m)
def OK(m): ok.append(m)


def dist_seg(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    vx, vy = bx - ax, by - ay
    L2 = vx * vx + vy * vy
    t = 0 if L2 == 0 else max(0, min(1, ((px - ax) * vx + (py - ay) * vy) / L2))
    return math.hypot(px - (ax + t * vx), py - (ay + t * vy))


def dist_poli(p, pts):
    return min(dist_seg(p, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def segs_cruzam(p1, p2, p3, p4):
    def o(a, b, c): return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    d1, d2, d3, d4 = o(p3, p4, p1), o(p3, p4, p2), o(p1, p2, p3), o(p1, p2, p4)
    return (d1 * d2 < 0) and (d3 * d4 < 0)


def cantos(b):
    w, d, _ = b["tamanho_m"]; x, y = b["pos"]; r = math.radians(b["rot_deg"])
    c, s = math.cos(r), math.sin(r)
    return [(x + sx * w / 2 * c - sy * d / 2 * s, y + sx * w / 2 * s + sy * d / 2 * c) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def obb_sobrepoe(c1, c2, folga=0.5):
    for poly in (c1, c2):
        for i in range(4):
            ex, ey = poly[(i + 1) % 4][0] - poly[i][0], poly[(i + 1) % 4][1] - poly[i][1]
            nx, ny = -ey, ex
            L = math.hypot(nx, ny); nx, ny = nx / L, ny / L
            p1 = [q[0] * nx + q[1] * ny for q in c1]; p2 = [q[0] * nx + q[1] * ny for q in c2]
            if max(p1) + folga <= min(p2) or max(p2) + folga <= min(p1):
                return False
    return True


def main():
    d = carregar()
    costa = d["costa"]
    ter = Terreno(d)
    rep = d["agua"]["represa"]["contorno"]

    # 1. Costa
    n = len(costa)
    (OK if 40 <= n <= 80 else E)(f"costa com {n} pontos (meta 40–80)")
    cruz = 0
    for i in range(n):
        for j in range(i + 2, n):
            if i == 0 and j == n - 1: continue
            if segs_cruzam(costa[i], costa[(i + 1) % n], costa[j], costa[(j + 1) % n]): cruz += 1
    (OK if cruz == 0 else E)(f"costa: {cruz} autointerseções")
    area = 0.5 * abs(sum(costa[i][0] * costa[(i + 1) % n][1] - costa[(i + 1) % n][0] * costa[i][1] for i in range(n)))
    OK(f"área da ilha ≈ {area/1e6:.2f} km² (mapa 1,44 km²)")
    if any(abs(x) > 600 or abs(y) > 600 for x, y in costa): E("costa fora do quadrado 1,2 km")

    # 2. Alturas
    hp = d["terreno"]["pontos_altura"]
    (OK if 100 <= len(hp) <= 200 else E)(f"{len(hp)} pontos de altura (meta 100–200)")
    fora = [p for p in hp if not dentro(costa, p["x"], p["y"])]
    (OK if not fora else E)(f"pontos de altura fora da ilha: {len(fora)} {[(p['x'], p['y']) for p in fora][:5]}")
    zr = [p["z"] for p in hp]
    (OK if 0 <= min(zr) and max(zr) <= 180 else E)(f"z autoral entre {min(zr)} e {max(zr)} m (plausível 0–~180)")
    xs = np.linspace(-600, 600, 241)
    X, Y = np.meshgrid(xs, xs)
    Z = ter.altura(X, Y)
    terra = Z > -1
    zmax = float(Z[terra].max())
    (OK if zmax <= Z_MAX else E)(f"terreno interpolado: máx {zmax:.1f} m (grade 5 m)")
    # declividade máxima
    gy, gx = np.gradient(np.where(terra, Z, 0), 5.0)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))[terra]
    OK(f"declividade: mediana {np.median(slope):.1f}°, p95 {np.percentile(slope, 95):.1f}°, máx {slope.max():.1f}° (falésias)")
    # conferência: interpolador reproduz os pontos
    zi = ter.altura(np.array([p["x"] for p in hp]), np.array([p["y"] for p in hp]))
    dif = np.abs(zi - np.array(zr))
    (OK if dif.max() < 1.0 else A)(f"interpolador reproduz pontos autorais (erro máx {dif.max():.2f} m)")

    # 3. POIs e prédios
    pois = d["pois"]; todos = pois + d.get("marcos", [])
    (OK if 8 <= len(pois) <= 10 else E)(f"{len(pois)} POIs (meta 8–10) + {len(d.get('marcos', []))} marco(s)")
    rio_trechos = d["agua"]["rio"]["trechos"]
    estradas = d["estradas"]
    todos_predios = []
    for p in todos:
        cx, cy = p["centro"]
        if not dentro(costa, cx, cy): E(f"POI {p['id']} com centro fora da ilha")
        zc = float(ter.altura(cx, cy))
        lo, hi = p["altura_m"]
        if not (lo - 6 <= zc <= hi + 6): A(f"POI {p['id']}: terreno no centro {zc:.1f} m fora da faixa declarada {lo}–{hi} m")
        for b in p["predios"]:
            cs = cantos(b)
            if not all(dentro(costa, *q) for q in cs): E(f"prédio {b['id']} ({b['tipo']}) sai da ilha")
            if b["tipo"] != "torre_tomada" and any(dentro(rep, *q) for q in cs): E(f"prédio {b['id']} dentro da represa")
            for t in rio_trechos:
                hw = t["largura_m"] / 2
                pts = [q[:2] for q in t["pontos"]]
                if min(dist_poli(q, pts) for q in cs + [tuple(b["pos"])]) < hw + 1.0:
                    E(f"prédio {b['id']} ({b['tipo']}) invade o rio ({t['trecho']})")
            for e in estradas:
                if e["tipo"] == "trilha": continue
                if dist_poli(tuple(b["pos"]), e["pontos"]) < e["largura_m"] / 2 + min(b["tamanho_m"][:2]) / 2 - 0.5 and b["tipo"] not in ("guarita",):
                    A(f"prédio {b['id']} ({b['tipo']}) encosta na via {e['id']}")
            zs = [float(ter.altura(*q)) for q in cs]
            desn = max(zs) - min(zs)
            if desn > 6 and b["tipo"] not in ("correia", "britador", "casa_forca", "subestacao", "chamine", "antena"):
                A(f"prédio {b['id']} ({b['tipo']}): desnível {desn:.1f} m sob a planta — precisa de platô/pilotis")
            todos_predios.append((b, cs))
    sobre = 0
    for i in range(len(todos_predios)):
        for j in range(i + 1, len(todos_predios)):
            bi, ci = todos_predios[i]; bj, cj = todos_predios[j]
            if math.dist(bi["pos"], bj["pos"]) > 60: continue
            if obb_sobrepoe(ci, cj):
                sobre += 1; E(f"prédios sobrepostos: {bi['id']} ({bi['tipo']}) x {bj['id']} ({bj['tipo']})")
    OK(f"{len(todos_predios)} prédios checados; {sobre} sobreposições")
    # espaçamento entre POIs
    for i in range(len(pois)):
        for j in range(i + 1, len(pois)):
            dd = math.dist(pois[i]["centro"], pois[j]["centro"])
            if dd < 200: A(f"POIs próximos: {pois[i]['id']} x {pois[j]['id']} = {dd:.0f} m")
            if dd < pois[i]["raio_m"] + pois[j]["raio_m"]: E(f"POIs se sobrepõem: {pois[i]['id']} x {pois[j]['id']}")
    dmin = min(math.dist(pois[i]["centro"], pois[j]["centro"]) for i in range(len(pois)) for j in range(i + 1, len(pois)))
    OK(f"menor distância entre POIs: {dmin:.0f} m")

    # 4. Estradas: dentro da ilha, fora d'água, conectividade
    for e in estradas:
        for q in e["pontos"]:
            if not dentro(costa, *q): E(f"via {e['id']} tem vértice fora da ilha {q}")
            if dentro(rep, *q): E(f"via {e['id']} tem vértice dentro da represa {q}")
        # segmentos atravessando a represa
        for k in range(len(e["pontos"]) - 1):
            a, b = e["pontos"][k], e["pontos"][k + 1]
            for t in np.linspace(0.05, 0.95, 10):
                q = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                if dentro(rep, *q): E(f"via {e['id']} atravessa a represa perto de {q}"); break
    # grafo
    nos = {}
    def no(nome): nos.setdefault(nome, set()); return nome
    for e in estradas: no(e["id"])
    for p in todos: no(p["id"])
    for i, e1 in enumerate(estradas):
        for e2 in estradas[i + 1:]:
            if min(dist_poli(q, e2["pontos"]) for q in (e1["pontos"][0], e1["pontos"][-1])) < 3 or \
               min(dist_poli(q, e1["pontos"]) for q in (e2["pontos"][0], e2["pontos"][-1])) < 3:
                nos[e1["id"]].add(e2["id"]); nos[e2["id"]].add(e1["id"])
    for p in todos:
        for e in estradas:
            if dist_poli(tuple(p["centro"]), e["pontos"]) <= p["raio_m"]:
                nos[p["id"]].add(e["id"]); nos[e["id"]].add(p["id"])
    # pontas soltas
    for e in estradas:
        for q in (e["pontos"][0], e["pontos"][-1]):
            liga = any(dist_poli(q, o["pontos"]) < 3 for o in estradas if o is not e) or \
                   any(math.dist(q, p["centro"]) <= p["raio_m"] for p in todos)
            if not liga: A(f"via {e['id']}: ponta solta em {q}")
    vis = set(); pilha = [pois[0]["id"]]
    while pilha:
        u = pilha.pop()
        if u in vis: continue
        vis.add(u); pilha.extend(nos[u] - vis)
    desconexos = [p["id"] for p in todos if p["id"] not in vis]
    (OK if not desconexos else E)(f"POIs desconectados da malha viária: {desconexos}")
    # só por estrada (sem trilha)
    so_estrada = {k: {v for v in vs if not (v.startswith("T"))} for k, vs in nos.items() if not k.startswith("T")}
    vis = set(); pilha = [pois[0]["id"]]
    while pilha:
        u = pilha.pop()
        if u in vis: continue
        vis.add(u); pilha.extend(so_estrada.get(u, set()) - vis)
    desc2 = [p["id"] for p in pois if p["id"] not in vis]
    (OK if not desc2 else A)(f"POIs sem acesso por estrada (só trilha): {desc2}")
    ncomp = sum(math.dist(e["pontos"][k], e["pontos"][k + 1]) for e in estradas for k in range(len(e["pontos"]) - 1))
    OK(f"{len(estradas)} vias, {ncomp:.0f} m no total")

    # pontes sobre o rio
    rio_j = [q[:2] for q in rio_trechos[1]["pontos"]]
    for b in d["pontes"]:
        dd = dist_poli(tuple(b["pos"]), rio_j) if b["tipo"] != "barragem" else 0
        (OK if dd < 6 else E)(f"ponte '{b['nome']}' a {dd:.1f} m do eixo do rio")
    # cruzamentos via x rio sem ponte
    for e in estradas:
        for k in range(len(e["pontos"]) - 1):
            for m in range(len(rio_j) - 1):
                if segs_cruzam(e["pontos"][k], e["pontos"][k + 1], rio_j[m], rio_j[m + 1]):
                    # ponto de cruzamento aproximado
                    tem_ponte = any(dist_seg(tuple(b["pos"]), e["pontos"][k], e["pontos"][k + 1]) < 8 for b in d["pontes"])
                    (OK if tem_ponte else E)(f"via {e['id']} cruza o rio {'com' if tem_ponte else 'SEM'} ponte/vau")

    # 5. Rio
    foz = rio_trechos[-1]["pontos"][-1]
    dcosta = min(dist_seg(tuple(foz[:2]), costa[i], costa[(i + 1) % n]) for i in range(n))
    (OK if dcosta < 5 else E)(f"foz do rio a {dcosta:.1f} m da costa")
    for t in rio_trechos:
        zs = [q[2] for q in t["pontos"]]
        (OK if all(zs[i] >= zs[i + 1] for i in range(len(zs) - 1)) else E)(f"rio ({t['trecho']}) sempre descendo: {zs}")

    # 6. Saque
    nsq = sum(len(p["saque"]) for p in todos)
    fora = sum(1 for p in todos for s in p["saque"] if not dentro(costa, *s["pos"]))
    (OK if fora == 0 else E)(f"{nsq} pontos de saque ({nsq/24:.1f} por jogador); {fora} fora da ilha")
    por_tier = {}
    for p in todos:
        for s in p["saque"]: por_tier[s["tier"]] = por_tier.get(s["tier"], 0) + 1
    OK(f"saque por tier: {por_tier}")
    for p in pois:
        OK(f"  {p['nome']:<24} {p['n_predios']:>3} prédios  {len(p['saque']):>3} saques  tier {p['tier']}")

    # 7. Zona
    f = d["zona"]["fases"]
    raios = [x["raio_m"] for x in f]
    (OK if all(raios[i] > raios[i + 1] for i in range(len(raios) - 1)) else E)(f"raios decrescentes {raios}")
    total = d["zona"]["tempo_voo_s"] + sum(x["espera_s"] + x["fechamento_s"] for x in f)
    (OK if 12 * 60 <= total <= 15 * 60 else E)(f"duração máxima da partida {total} s = {total/60:.1f} min (meta 12–15)")
    for c in d["zona"]["finais_candidatos"]:
        if not dentro(costa, *c["pos"]): E(f"final '{c['nome']}' fora da ilha")
        if dentro(rep, *c["pos"]): E(f"final '{c['nome']}' dentro da represa")
    # cobertura de finais: cada ponto de terra a <= 260 m (raio fase 2) de algum candidato
    pts_terra = np.column_stack([X[terra], Y[terra]])
    cand = np.array([c["pos"] for c in d["zona"]["finais_candidatos"]], float)
    dist_min = np.sqrt(((pts_terra[:, None, :] - cand[None, :, :]) ** 2).sum(-1)).min(1)
    OK(f"finais candidatos: {len(cand)}; maior distância de um ponto de terra ao final mais próximo = {dist_min.max():.0f} m")

    # 8. Avião
    for r in d["aviao"]["rotas"]:
        cruza = sum(segs_cruzam(r["de"], r["ate"], costa[i], costa[(i + 1) % n]) for i in range(n))
        L = math.dist(r["de"], r["ate"])
        (OK if cruza >= 2 else E)(f"rota {r['id']} cruza a costa {cruza}x; {L:.0f} m = {L/d['aviao']['velocidade_m_s']:.0f} s de voo")

    # 9. Vegetação dentro da ilha
    for m in d["vegetacao"]:
        fora = [q for q in m["poligono"] if not dentro(costa, *q)]
        if fora: A(f"mancha '{m['nome']}' com {len(fora)} vértice(s) fora da ilha")
    for c in d["cobertura_campo_aberto"]:
        if not dentro(costa, *c["pos"]): E(f"cobertura fora da ilha {c['pos']}")
    OK(f"{len(d['vegetacao'])} manchas de vegetação, {len(d['cobertura_campo_aberto'])} peças de cobertura")

    for m in ok: print("  ok   ", m)
    for m in avisos: print("  AVISO", m)
    for m in erros: print("  ERRO ", m)
    print(f"\nRESULTADO: {len(erros)} erro(s), {len(avisos)} aviso(s)")
    return 1 if erros else 0


if __name__ == "__main__":
    sys.exit(main())
