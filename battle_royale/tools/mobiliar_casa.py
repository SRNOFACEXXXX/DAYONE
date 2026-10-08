# Valida (e ajuda a escolher) a mobília da casa do pacote: lê a grade livre da casa SEM móveis (game/raw/casa_grade_livre.txt, gerada por
# tests/casa_alcance.tscn -- --sem_moveis), põe as pegadas dos móveis do moveis.json["casa_demo"] e roda BFS a partir da porta com
# folga de cápsula (r 0,3). Reprova: móvel sobre parede, cômodo/porta inalcançável, vão de porta fechado por móvel.
# Uso: python tools/mobiliar_casa.py            (valida o que está em game/maps/ilha/moveis.json)
#      python tools/mobiliar_casa.py --gravar   (grava a lista abaixo — decisões autorais — no moveis.json se passar)
import json, math, os, sys
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GRADE = os.path.join(RAIZ, "game", "raw", "casa_grade_livre.txt")
MOVEIS = os.path.join(RAIZ, "game", "maps", "ilha", "moveis.json")
DIMS = json.load(open(os.path.join(RAIZ, "game", "assets", "models", "moveis", "moveis.json"), encoding="utf-8"))

# Decisões de layout (x, z em metros Godot no sistema da casa; rot_y graus, frente do móvel = +Z local antes de girar).
# Cada cômodo mantém ≥ 1 m livre de passagem diante das portas (conferido pelo BFS).
LISTA = [
    # saídas da casa: frente (x -2,05; z 5,8), cozinha-norte (x -2,5; z -3,5), leste (x 5,5; z -0,7): 1,1 m livres diante de cada uma
    # quarto NE: cama na parede norte, guarda-roupa na parede leste, cômoda ao lado
    ("cama_a", 3.0, -4.75, 0), ("guarda_roupa_b", 5.0, -3.4, 270), ("comoda_d", 0.9, -5.55, 0),
    # sala (corredor leste-oeste z -1,6..0,1): sofá ao centro-oeste (portas 006/007 ao sul e 008 ao norte livres), estante no canto NE
    ("sofa_a", 2.0, -1.25, 0), ("estante_d", -0.4, -4.4, 90),
    # quarto SE: cama na parede leste, guarda-roupa na parede sul
    ("cama_c", 4.25, 2.8, 0), ("guarda_roupa_a", 3.1, 4.1, 180),
]


def carregar():
    linhas = open(GRADE, encoding="utf-8").read().split("\n")
    nx, nz, x0, z0, passo = linhas[0].split()
    nx, nz, x0, z0, passo = int(nx), int(nz), float(x0), float(z0), float(passo)
    g = [list(l) for l in linhas[1:1 + nz]]
    return nx, nz, x0, z0, passo, g


def pegada(m, x, z, rot):
    d = DIMS[m]["dim"]
    w, p = d[0], d[1]
    a = math.radians(rot)
    return (x, z, w, p, a)


def dentro(px, pz, f, folga):
    x, z, w, p, a = f
    dx, dz = px - x, pz - z
    # rot_y gira em torno de Y: x' = dx*cos + dz*sin ; z' = -dx*sin + dz*cos
    lx = dx * math.cos(a) - dz * math.sin(a)
    lz = dx * math.sin(a) + dz * math.cos(a)
    ex = max(abs(lx) - w / 2, 0.0)
    ez = max(abs(lz) - p / 2, 0.0)
    return math.hypot(ex, ez) < folga


def validar(lista):
    nx, nz, x0, z0, passo, g = carregar()
    livre = [[c != "#" for c in l] for l in g]
    fs = [pegada(*m) for m in lista]
    ok = True
    # 1) cada móvel precisa caber no espaço livre (núcleo da pegada, encolhido 0,3 m, dentro de células livres)
    for (m, x, z, rot), f in zip(lista, fs):
        ruim = 0
        for ix in range(nx):
            for iz in range(nz):
                px, pz = x0 + ix * passo, z0 + iz * passo
                if dentro(px, pz, f, -0.30) and not livre[iz][ix]:
                    ruim += 1
        if ruim > 2:
            print("  MÓVEL SOBRE PAREDE/OBSTÁCULO:", m, x, z, rot, "células", ruim)
            ok = False
    # 2) BFS com móveis
    bloq = [[False] * nx for _ in range(nz)]
    for ix in range(nx):
        for iz in range(nz):
            px, pz = x0 + ix * passo, z0 + iz * passo
            if any(dentro(px, pz, f, 0.30) for f in fs):
                bloq[iz][ix] = True
    ini = (int((-2.05 - x0) / passo), int((6.9 - z0) / passo))

    def bfs(usa_moveis):
        vis = {ini}
        fila = [ini]
        while fila:
            cx, cz = fila.pop()
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    n = (cx + dx, cz + dz)
                    if not (0 <= n[0] < nx and 0 <= n[1] < nz) or n in vis:
                        continue
                    if not livre[n[1]][n[0]] or (usa_moveis and bloq[n[1]][n[0]]):
                        continue
                    vis.add(n)
                    fila.append(n)
        return vis
    sem = bfs(False)
    com = bfs(True)
    perdidas = [c for c in sem if c not in com and not bloq[c[1]][c[0]]]
    # células que eram alcançáveis e deixaram de ser (e não estão sob o móvel): ambientes isolados pela mobília
    if len(perdidas) > 6:
        xs = [x0 + c[0] * passo for c in perdidas]; zs = [z0 + c[1] * passo for c in perdidas]
        print("  ISOLA %d células (%.1f m2) na região x %.1f..%.1f z %.1f..%.1f" % (len(perdidas), len(perdidas) * passo * passo, min(xs), max(xs), min(zs), max(zs)))
        ok = False
    # as 3 saídas (frente, cozinha-norte, leste) precisam estar alcançáveis de dentro, com os móveis
    for nome, (ex, ez) in {"cozinha-norte": (-2.5, -3.15), "leste": (5.0, -0.7)}.items():
        c = (int((ex - x0) / passo), int((ez - z0) / passo))
        if c not in com:
            print("  SAÍDA BLOQUEADA:", nome, "em", (ex, ez))
            ok = False
    print("  alcançável sem móveis=%d com móveis=%d perdidas=%d" % (len(sem), len(com), len(perdidas)))
    # mapa
    for iz in range(nz):
        l = ""
        for ix in range(nx):
            c = (ix, iz)
            if not livre[iz][ix]:
                l += "#"
            elif bloq[iz][ix]:
                l += "M"
            elif c in com:
                l += "."
            elif c in sem:
                l += "x"   # perdido
            else:
                l += "o"
        if "#" in l[8:] or "M" in l:
            print("  " + l)
    return ok


if __name__ == "__main__":
    existentes = json.load(open(MOVEIS, encoding="utf-8"))["casa_demo"]
    if "--gravar" in sys.argv:
        ok = validar(LISTA)
        if ok:
            d = json.load(open(MOVEIS, encoding="utf-8"))
            d["casa_demo"] = [{"m": m, "pos": [x, 0.08, z], "rot_y": rot, "esc": [1, 1, 1]} for (m, x, z, rot) in LISTA]
            json.dump(d, open(MOVEIS, "w", encoding="utf-8"), ensure_ascii=False)
            print("GRAVADO", len(LISTA), "móveis")
        else:
            print("REPROVADO: ajuste LISTA")
    else:
        lista = [(m["m"], m["pos"][0], m["pos"][2], m["rot_y"]) for m in existentes]
        print("validando o moveis.json atual:", "OK" if validar(lista) else "REPROVADO")
