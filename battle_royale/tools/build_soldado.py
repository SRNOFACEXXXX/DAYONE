# Soldado de infantaria low poly (folha docs/ref/personagem.jpg), modelado à mão com geometria explícita.
# Reaproveita o ESQUELETO e as ANIMAÇÕES de game/assets/models/characters/counter.glb (mesmos 44 ossos, mesmos clipes,
# compatível com BodyModel/ArmsIK e *_weapon_offsets.json); troca só a malha (antes ~16 mil tris) por uma de ~2 mil tris
# skinnada por pesos explícitos, com camuflagem "mata geométrica" (triângulos verde/bege/marrom desenhados à mão) + paleta.
# -> game/assets/models/characters/soldado.glb (+ soldado_camo.png, soldado_paleta.png, soldado_weapon_offsets.json)
# Uso: blender -b --factory-startup -P tools/build_soldado.py
# Convenções (espaço do armature, antes da escala 1,057): Z para cima, frente = -Y, esquerda do soldado = +X.
import bpy, bmesh, math, os, shutil
import numpy as np
from mathutils import Vector as V

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CHARS = os.path.join(ROOT, "game", "assets", "models", "characters")
SRC = os.path.join(CHARS, "counter.glb")
OUT = os.path.join(CHARS, "soldado.glb")

# ------------------------------------------------------------------ texturas
# Camuflagem: retícula 6x6 (tileável). Cada ponto tem deslocamento fixo (px, tabela à mão); cada célula vira 2 triângulos;
# a tabela de cores (0 verde-escuro, 1 oliva, 2 bege, 3 marrom, 4 caqui-verde) também é literal.
CAMO_COR = [(0x3E, 0x4C, 0x2C), (0x6A, 0x74, 0x3E), (0xB5, 0xA3, 0x76), (0x6E, 0x50, 0x34), (0x8A, 0x8A, 0x52)]
CAMO_DESLOC = [
    (-9, 7), (12, -10), (-6, -13), (10, 9), (-12, 4), (7, -8),
    (11, 10), (-8, 12), (9, -7), (-11, -9), (6, 13), (-10, -5),
    (-7, -11), (13, 6), (-12, 8), (8, -12), (-5, 10), (12, 7),
    (9, 12), (-10, -8), (7, 9), (-13, 5), (11, -11), (-6, -6),
    (-12, 5), (6, -12), (12, 11), (-8, -10), (10, 7), (-9, 12),
    (8, -9), (-11, 10), (-7, -6), (12, -12), (-10, 9), (9, 6),
]
CAMO_DIAG = "100110" "011001" "110100" "001011" "101001" "010110"
CAMO_TRI = ("0213412304" "3142031420" "2301432014" "4120314230" "1342013421" "3024130241"
            "2403142031" "0314230142" "4130241302" "1023401234" "3412041230" "2031420314"
            "4301243012" "1243012430" "3201423014" "0413204132" "2140312403" "1324031240")
PALETA = [  # 8 colunas x 4 linhas de células 8x8 px
    (0xD9, 0xA7, 0x7F), (0xB5, 0x84, 0x60), (0x2A, 0x26, 0x22), (0x3F, 0x7F, 0x78), (0x2F, 0x5F, 0x5A), (0x8A, 0x2C, 0x2C), (0x6B, 0x20, 0x24), (0x6E, 0x70, 0x48),
    (0x4B, 0x4E, 0x33), (0x4A, 0x4D, 0x50), (0x2B, 0x2B, 0x2D), (0x62, 0x66, 0x4F), (0x3D, 0x40, 0x33), (0x5A, 0x40, 0x28), (0x2A, 0x20, 0x19), (0x3A, 0x3A, 0x32),
    (0x3A, 0x2A, 0x20), (0x8C, 0x8F, 0x88), (0x33, 0x66, 0x33), (0xB0, 0x98, 0x60), (0x22, 0x22, 0x22), (0x88, 0x88, 0x78), (0x55, 0x55, 0x55), (0xFF, 0xFF, 0xFF),
    (0xA0, 0x7A, 0x52), (0x40, 0x48, 0x50), (0x26, 0x34, 0x22), (0x70, 0x70, 0x66), (0xC4, 0xC0, 0xA8), (0x9A, 0x5A, 0x3A), (0x33, 0x33, 0x2A), (0x7A, 0x6A, 0x4A),
]
C = {n: i for i, n in enumerate(["pele", "pele_s", "olho", "capacete", "cap_s", "lenco", "lenco_s", "colete", "bolso", "cinza", "preto", "mochila",
                                 "alca", "bota", "sola", "cinto", "cabelo", "metal", "verde", "areia", "noir", "cinzaclaro", "grafite", "branco",
                                 "couro", "azulado", "matoescuro", "pedra", "osso", "tijolo", "asfalto", "cafe"])}


def save_png(name, w, h, rgb):
    """rgb: array h x w x 3 uint8 (linha 0 = topo)."""
    img = bpy.data.images.new(name, w, h, alpha=False)
    flat = np.ones((h, w, 4), dtype=np.float32)
    flat[:, :, :3] = rgb[::-1].astype(np.float32) / 255.0   # bytes sRGB -> pixels guardados como estão
    img.pixels.foreach_set(flat.ravel())
    img.filepath_raw = os.path.join(CHARS, name + ".png")
    img.file_format = "PNG"
    img.save()
    return img


def tri_fill(buf, p0, p1, p2, col):
    h, w = buf.shape[:2]
    xs = [p0[0], p1[0], p2[0]]
    ys = [p0[1], p1[1], p2[1]]
    x0, x1 = max(int(math.floor(min(xs))), 0), min(int(math.ceil(max(xs))), w - 1)
    y0, y1 = max(int(math.floor(min(ys))), 0), min(int(math.ceil(max(ys))), h - 1)
    if x0 > x1 or y0 > y1:
        return
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    d = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
    if abs(d) < 1e-9:
        return
    a = ((p1[1] - p2[1]) * (gx - p2[0]) + (p2[0] - p1[0]) * (gy - p2[1])) / d
    b = ((p2[1] - p0[1]) * (gx - p2[0]) + (p0[0] - p2[0]) * (gy - p2[1])) / d
    m = (a >= 0) & (b >= 0) & (a + b <= 1)
    buf[y0:y1 + 1, x0:x1 + 1][m] = col


def make_camo(size=256):
    buf = np.zeros((size, size, 3), dtype=np.uint8)
    buf[:] = CAMO_COR[1]
    n = 6
    cell = size / n
    pts = {}
    for j in range(n):
        for i in range(n):
            dx, dy = CAMO_DESLOC[j * n + i]
            pts[(i, j)] = (i * cell + dx, j * cell + dy)
    t = 0
    for j in range(n):
        for i in range(n):
            # cantos da célula (com dobra tileável: pontos além da borda ganham +size)
            def P(ii, jj):
                x, y = pts[(ii % n, jj % n)]
                return (x + (size if ii >= n else 0), y + (size if jj >= n else 0))
            c00, c10, c01, c11 = P(i, j), P(i + 1, j), P(i, j + 1), P(i + 1, j + 1)
            tris = [(c00, c10, c11), (c00, c11, c01)] if CAMO_DIAG[j * n + i] == "1" else [(c00, c10, c01), (c10, c11, c01)]
            for tr in tris:
                col = CAMO_COR[int(CAMO_TRI[t % len(CAMO_TRI)])]
                t += 1
                for ox in (-size, 0, size):
                    for oy in (-size, 0, size):
                        tri_fill(buf, (tr[0][0] + ox, tr[0][1] + oy), (tr[1][0] + ox, tr[1][1] + oy), (tr[2][0] + ox, tr[2][1] + oy), col)
    return save_png("soldado_camo", size, size, buf)


def make_paleta():
    buf = np.zeros((32, 64, 3), dtype=np.uint8)
    for k, c in enumerate(PALETA):
        cx, cy = (k % 8) * 8, (k // 8) * 8
        buf[cy:cy + 8, cx:cx + 8] = c
    return save_png("soldado_paleta", 64, 32, buf)


# ------------------------------------------------------------------ malha
class Malha:
    def __init__(self):
        self.bm = bmesh.new()
        self.vw = []        # pesos por vértice (mesma ordem de criação)
        self.fi = []        # (material 0 camo / 1 paleta, cor, deslocamento uv) por face
        self.ossos = set()
        self.uvscale = 0.7   # metros de malha por repetição da camuflagem

    def vert(self, p, w):
        self.vw.append(w)
        self.ossos.update(w)
        return self.bm.verts.new(V(p))

    def face(self, vs, mat, cor, off=0.0):
        self.bm.faces.new(vs)
        self.fi.append((mat, C[cor] if isinstance(cor, str) else cor, off))

    # anel de N pontos num plano definido por u,v (vetores unitários ortogonais)
    def anel(self, c, u, v, ru, rv, w, n=8, rot=0.0):
        c, u, v = V(c), V(u), V(v)
        return [self.vert(c + u * (ru * math.cos(rot + 2 * math.pi * k / n)) + v * (rv * math.sin(rot + 2 * math.pi * k / n)), w) for k in range(n)]

    def ponte(self, a, b, mat, cor, off=0.0):
        n = len(a)
        for k in range(n):
            self.face([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]], mat, cor, off)

    def tampa(self, a, mat, cor, off=0.0):
        self.face(list(a), mat, cor, off)

    def tubo(self, aneis, mat, cor, off=0.0, tampas=(True, True)):
        """aneis: lista de listas de vértices (já criados)."""
        for a, b in zip(aneis, aneis[1:]):
            self.ponte(a, b, mat, cor, off)
        if tampas[0]:
            self.tampa(list(reversed(aneis[0])), mat, cor, off)
        if tampas[1]:
            self.tampa(aneis[-1], mat, cor, off)

    def tubo_z(self, secoes, w_por_secao, mat, cor, off=0.0, n=8, rot=math.pi / 8, tampas=(True, True)):
        """Tubo vertical: secoes = [(z, cx, cy, rx, ry)]; eixo X à direita, -Y à frente."""
        an = [self.anel((cx, cy, z), (1, 0, 0), (0, -1, 0), rx, ry, w, n, rot) for (z, cx, cy, rx, ry), w in zip(secoes, w_por_secao)]
        self.tubo(an, mat, cor, off, tampas)

    def bloco(self, c, tam, w, mat, cor, off=0.0, topo=(1.0, 1.0), rot=None, cores=None):
        """Bloco (hexaedro) centrado em c, tam = (x,y,z); topo = escala x/y da face de cima (cunha/afunilado); rot = Matrix 3x3."""
        hx, hy, hz = tam[0] / 2, tam[1] / 2, tam[2] / 2
        pts = []
        for zz, (sx, sy) in ((-1, (1.0, 1.0)), (1, topo)):
            for (xx, yy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                p = V((xx * hx * sx, yy * hy * sy, zz * hz))
                if rot is not None:
                    p = rot @ p
                pts.append(self.vert(V(c) + p, w))
        b, t = pts[:4], pts[4:]
        self.face([b[3], b[2], b[1], b[0]], mat, cor, off)
        self.face(t, mat, cor, off)
        for k in range(4):
            self.face([b[k], b[(k + 1) % 4], t[(k + 1) % 4], t[k]], mat, cor, off)
        return pts

    def fim(self, nome):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.faces.ensure_lookup_table()
        # UV: camuflagem = projeção em caixa (0,55 m por repetição); paleta = centro da célula da cor
        uv = bm.loops.layers.uv.new("UVMap")
        for f, (mat, cor, off) in zip(bm.faces, self.fi):
            f.material_index = mat
            nrm = f.normal
            ax = max(range(3), key=lambda i: abs(nrm[i]))
            for lp in f.loops:
                p = lp.vert.co
                if mat == 0:
                    a, b = [(1, 2), (0, 2), (0, 1)][ax]
                    lp[uv].uv = ((p[a] + off) / self.uvscale, (p[b] + off * 0.7) / self.uvscale)
                else:
                    lp[uv].uv = (((cor % 8) * 8 + 4) / 64.0, 1.0 - ((cor // 8) * 8 + 4) / 32.0)
        me = bpy.data.meshes.new(nome)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        return me


def peso(*pares):
    t = sum(w for _, w in pares)
    return {b: w / t for b, w in pares}


def fn_ossos(arm):
    bones = arm.data.bones

    def H(n):
        return V(bones[n].head_local)

    def T(n):
        b = bones[n]
        if b.children:
            return V(b.children[0].head_local)
        return V(b.head_local) + (V(b.head_local) - V(b.parent.head_local)).normalized() * 0.035
    return H, T


def braco(m, H, T, L, s, wm=1.0, cor_mao="pele", cor_dedos="pele_s", cotoveleira=True, manga=True, mao=True, antebraco=False):
    """Manga camuflada (ombro->punho) + mão (palma, dedos de 2 falanges com pesos nos ossos, polegar). wm alarga a mão."""
    CAMO, PAL = 0, 1
    psh, pel, pwr = H(L + "Arm"), H(L + "ForeArm"), H(L + "Hand")
    d1 = (pel - psh).normalized()
    d2 = (pwr - pel).normalized()
    hint = V((0, -1, 0))

    def frame(d):
        u = d.cross(hint).normalized()
        return u, d.cross(u).normalized()

    u1, v1 = frame(d1)
    u2, v2 = frame(d2)
    wA, wF = {L + "Arm": 1.0}, {L + "ForeArm": 1.0}
    an = [
        m.anel(psh - d1 * 0.02 + V((0, 0, 0.01)), u1, v1, 0.072, 0.074, wA, 8, 0.0),
        m.anel(psh + (pel - psh) * 0.5, u1, v1, 0.066, 0.068, wA, 8, 0.0),
        m.anel(pel, (u1 + u2).normalized(), (v1 + v2).normalized(), 0.061, 0.063, peso((L + "Arm", 1), (L + "ForeArm", 1)), 8, 0.0),
        m.anel(pel + (pwr - pel) * 0.55, u2, v2, 0.055, 0.057, wF, 8, 0.0),
        m.anel(pwr + d2 * 0.012, u2, v2, 0.050, 0.052, wF, 8, 0.0),
    ]
    if antebraco:   # 1ª pessoa: só o antebraço (do cotovelo ao punho), como as mangas curtas do pacote original
        an = [m.anel(pel + (pwr - pel) * 0.42, u2, v2, 0.050, 0.052, wF, 8, 0.0), m.anel(pwr + d2 * 0.012, u2, v2, 0.048, 0.050, wF, 8, 0.0)]
        cotoveleira = False
    if manga:
        m.tubo(an, CAMO, 0, off=0.21 * s)
    if manga and cotoveleira:
        m.bloco(pel + V((0.0, 0.058, 0.0)), (0.05, 0.03, 0.07), peso((L + "Arm", 1), (L + "ForeArm", 1)), CAMO, 0, off=0.4)
    if not mao:
        return
    # mão: palma, dedos (2 falanges, pesos nos ossos dos dedos), polegar
    m1, m2, m2t = H(L + "HandMiddle1"), H(L + "HandMiddle2"), T(L + "HandMiddle2")
    df = (m1 - pwr).normalized()
    pu = V((0, 1, 0))
    pu = (pu - df * pu.dot(df)).normalized()
    pv = df.cross(pu).normalized()
    wP = {L + "Hand": 1.0}
    ap = [m.anel(pwr, pu, pv, 0.040 * wm, 0.020 * wm, wP, 4, math.pi / 4), m.anel(pwr + (m1 - pwr) * 0.55, pu, pv, 0.046 * wm, 0.025 * wm, wP, 4, math.pi / 4),
          m.anel(m1, pu, pv, 0.046 * wm, 0.022 * wm, wP, 4, math.pi / 4)]
    m.tubo(ap, PAL, cor_mao)
    df2 = (m2 - m1).normalized()
    pu2 = (pu - df2 * pu.dot(df2)).normalized()
    pv2 = df2.cross(pu2).normalized()
    wf1 = {L + "HandMiddle1": 1.0}
    wf2 = {L + "HandMiddle2": 1.0}
    af = [m.anel(m1, pu2, pv2, 0.047 * wm, 0.021 * wm, wf1, 4, math.pi / 4), m.anel(m2, pu2, pv2, 0.044 * wm, 0.019 * wm, peso((L + "HandMiddle1", 1), (L + "HandMiddle2", 1)), 4, math.pi / 4),
          m.anel(m2t + df2 * 0.012, pu2, pv2, 0.037 * wm, 0.015 * wm, wf2, 4, math.pi / 4)]
    m.tubo(af, PAL, cor_dedos)
    t1, t2, t2t = H(L + "HandThumb1"), H(L + "HandThumb2"), T(L + "HandThumb2")
    dt = (t2 - t1).normalized()
    tu = (V((1, 0, 0)) - dt * dt.x).normalized()
    tv = dt.cross(tu).normalized()
    at = [m.anel(t1, tu, tv, 0.020 * wm, 0.019 * wm, {L + "HandThumb1": 1.0}, 4, math.pi / 4),
          m.anel(t2, tu, tv, 0.019 * wm, 0.018 * wm, peso((L + "HandThumb1", 1), (L + "HandThumb2", 1)), 4, math.pi / 4),
          m.anel(t2t, tu, tv, 0.014 * wm, 0.013 * wm, {L + "HandThumb2": 1.0}, 4, math.pi / 4)]
    m.tubo(at, PAL, cor_mao)


def monta_soldado(arm):
    bones = arm.data.bones

    def H(n):
        return V(bones[n].head_local)

    def T(n):
        b = bones[n]
        if b.children:
            return V(b.children[0].head_local)
        return V(b.head_local) + (V(b.head_local) - V(b.parent.head_local)).normalized() * 0.035

    m = Malha()
    CAMO, PAL = 0, 1

    # ---------------- pernas (calça camuflada) + botas
    for s, L in ((1, "Left"), (-1, "Right")):
        x0 = H(L + "UpLeg").x
        w_up, w_lg, w_ft = {L + "UpLeg": 1.0}, {L + "Leg": 1.0}, {L + "Foot": 1.0}
        secs = [
            (0.905, x0, 0.030, 0.108, 0.118), (0.79, x0, 0.030, 0.104, 0.112), (0.64, x0, 0.026, 0.098, 0.104),
            (0.47, x0, 0.012, 0.088, 0.092), (0.30, x0, 0.012, 0.082, 0.088), (0.16, x0, 0.030, 0.078, 0.086),
        ]
        ws = [w_up, w_up, w_up, peso((L + "UpLeg", 1), (L + "Leg", 1)), w_lg, peso((L + "Leg", 1), (L + "Foot", 1))]
        m.tubo_z(secs, ws, CAMO, 0, off=0.13 * s, n=8, rot=math.pi / 8, tampas=(False, True))
        # bolso cargo na coxa (lado de fora) e joelheira
        m.bloco((x0 + s * 0.112, 0.022, 0.66), (0.04, 0.115, 0.13), w_up, CAMO, 0, off=0.3 * s)
        m.bloco((x0, -0.078, 0.475), (0.09, 0.03, 0.085), peso((L + "UpLeg", 1), (L + "Leg", 1)), PAL, "bolso")
        # bota: cano, peito do pé, bico e sola
        toe = H(L + "ToeBase")
        m.tubo_z([(0.185, x0, 0.030, 0.088, 0.096), (0.11, x0, 0.030, 0.086, 0.094)], [peso((L + "Leg", 1), (L + "Foot", 1)), w_ft], PAL, "bota", n=8, rot=math.pi / 8, tampas=(False, False))
        m.bloco((x0, 0.012, 0.05), (0.118, 0.265, 0.09), w_ft, PAL, "bota", topo=(0.9, 0.95))                    # corpo da bota
        m.bloco((x0, 0.012, 0.0115), (0.128, 0.28, 0.023), w_ft, PAL, "sola")                                     # sola
        m.bloco((x0, -0.140, 0.034), (0.100, 0.075, 0.060), {L + "ToeBase": 1.0}, PAL, "bota", topo=(0.8, 0.7))   # bico
        m.bloco((x0, -0.140, 0.008), (0.112, 0.095, 0.018), {L + "ToeBase": 1.0}, PAL, "sola")

    # ---------------- tronco (jaqueta camuflada)
    wH, wS, wS1, wN = {"Hips": 1.0}, {"Spine": 1.0}, {"Spine1": 1.0}, {"Neck": 1.0}
    tor = [
        (0.83, 0.0, 0.03, 0.150, 0.105), (0.91, 0.0, 0.03, 0.190, 0.125), (1.02, 0.0, 0.02, 0.178, 0.122), (1.12, 0.0, 0.02, 0.165, 0.118),
        (1.22, 0.0, 0.022, 0.182, 0.122), (1.32, 0.0, 0.024, 0.200, 0.128), (1.40, 0.0, 0.02, 0.205, 0.112), (1.435, 0.0, 0.02, 0.085, 0.085),
    ]
    tw = [wH, wH, peso(("Hips", 1), ("Spine", 1)), wS, peso(("Spine", 1), ("Spine1", 1)), wS1, wS1, peso(("Spine1", 1), ("Neck", 1))]
    m.tubo_z(tor, tw, CAMO, 0, off=0.05, n=8, rot=math.pi / 8)

    for s_, L_ in ((1, "Left"), (-1, "Right")):
        braco(m, H, T, L_, s_)

    # ---------------- cabeça (pele), olhos, nariz, orelhas
    wHd = {"Head": 1.0}
    wNH = peso(("Neck", 1), ("Head", 1))
    cab = [
        (1.415, 0.0, 0.024, 0.052, 0.054), (1.50, 0.0, 0.018, 0.050, 0.056), (1.515, 0.0, -0.008, 0.060, 0.072), (1.555, 0.0, -0.006, 0.080, 0.090),
        (1.605, 0.0, 0.000, 0.090, 0.100), (1.655, 0.0, 0.004, 0.090, 0.100), (1.705, 0.0, 0.006, 0.070, 0.082),
    ]
    cw = [wN, wNH, wHd, wHd, wHd, wHd, wHd]
    m.tubo_z(cab, cw, PAL, "pele", n=8, rot=math.pi / 8)
    m.bloco((0.0, -0.102, 1.585), (0.030, 0.045, 0.048), wHd, PAL, "pele_s", topo=(0.6, 0.5))                                     # nariz
    for s in (1, -1):
        m.bloco((0.036 * s, -0.096, 1.608), (0.024, 0.014, 0.016), wHd, PAL, "olho")                                              # olhos
        m.bloco((0.038 * s, -0.099, 1.622), (0.034, 0.014, 0.010), wHd, PAL, "cabelo")                                            # sobrancelhas
        m.bloco((0.092 * s, 0.012, 1.595), (0.014, 0.042, 0.052), wHd, PAL, "pele_s")                                             # orelhas
        m.bloco((0.088 * s, 0.040, 1.625), (0.022, 0.05, 0.05), wHd, PAL, "cabelo")                                               # costeleta

    # ---------------- capacete verde-azulado (casca baixa, aba, tira)
    cap = [
        (1.642, 0.0, 0.010, 0.112, 0.124), (1.685, 0.0, 0.010, 0.118, 0.131), (1.728, 0.0, 0.010, 0.102, 0.115), (1.758, 0.0, 0.008, 0.062, 0.072), (1.772, 0.0, 0.008, 0.028, 0.034),
    ]
    m.tubo_z(cap, [wHd] * 5, PAL, "capacete", n=8, rot=math.pi / 8)
    m.bloco((0.0, 0.014, 1.638), (0.232, 0.246, 0.020), wHd, PAL, "cap_s", topo=(0.98, 0.98))                                     # aba
    m.bloco((0.0, -0.133, 1.682), (0.07, 0.022, 0.022), wHd, PAL, "cap_s")                                                       # faixa frontal
    for s in (1, -1):
        m.bloco((0.092 * s, -0.05, 1.575), (0.012, 0.012, 0.06), wHd, PAL, "preto")                                              # tira do queixo

    # ---------------- lenço vermelho (gola alta cobrindo nariz/boca, ponta caída no peito)
    len_ = [(1.385, 0.0, 0.022, 0.108, 0.108), (1.46, 0.0, 0.015, 0.092, 0.098), (1.52, 0.0, -0.006, 0.088, 0.105), (1.575, 0.0, -0.008, 0.091, 0.110)]
    m.tubo_z(len_, [peso(("Neck", 1), ("Spine1", 1)), wN, wNH, wHd], PAL, "lenco", n=8, rot=math.pi / 8, tampas=(False, False))
    m.bloco((0.0, -0.110, 1.325), (0.17, 0.05, 0.16), peso(("Spine1", 1), ("Neck", 1)), PAL, "lenco_s", topo=(1.4, 1.0))         # ponta em V
    m.bloco((0.085, -0.108, 1.28), (0.05, 0.05, 0.12), wS1, PAL, "lenco")
    m.bloco((-0.12, -0.03, 1.39), (0.07, 0.17, 0.05), wS1, PAL, "lenco_s")                                                       # ponta no ombro

    # ---------------- colete tático: casco, ombreiras, bolsos frontais, rádio, pouch, cinto
    m.tubo_z([(1.14, 0.0, 0.022, 0.176, 0.128), (1.24, 0.0, 0.024, 0.194, 0.136), (1.35, 0.0, 0.026, 0.208, 0.138), (1.385, 0.0, 0.02, 0.200, 0.120)],
             [wS, peso(("Spine", 1), ("Spine1", 1)), wS1, wS1], PAL, "colete", n=8, rot=math.pi / 8, tampas=(False, False))
    for s in (1, -1):
        m.bloco((0.085 * s, -0.012, 1.405), (0.075, 0.175, 0.03), wS1, PAL, "colete")                                            # ombreira
        m.bloco((0.070 * s, -0.142, 1.302), (0.092, 0.050, 0.095), wS1, PAL, "bolso", topo=(0.97, 0.9))                          # bolso superior
    for xx in (-0.118, 0.0, 0.118):
        m.bloco((xx, -0.148, 1.190), (0.104, 0.055, 0.105), peso(("Spine", 1), ("Spine1", 1)), PAL, "bolso", topo=(0.97, 0.9))     # bolsos do meio
    m.bloco((0.0, -0.142, 1.302), (0.05, 0.03, 0.095), wS1, PAL, "cinza")                                                        # zíper/painel central
    m.bloco((0.128, -0.134, 1.346), (0.048, 0.036, 0.115), wS1, PAL, "grafite")                                                  # rádio de ombro (esquerda)
    m.bloco((0.141, -0.120, 1.475), (0.008, 0.008, 0.120), wS1, PAL, "preto")                                                    # antena
    m.bloco((0.128, -0.152, 1.362), (0.022, 0.012, 0.022), wS1, PAL, "cap_s")                                                    # botão do rádio
    # cinto e pouch
    m.tubo_z([(0.935, 0.0, 0.03, 0.198, 0.132), (0.975, 0.0, 0.03, 0.198, 0.132)], [wH, wH], PAL, "cinto", n=8, rot=math.pi / 8)
    m.bloco((-0.105, -0.150, 0.925), (0.135, 0.070, 0.095), wH, PAL, "grafite", topo=(0.95, 0.85))                                # pouch de cintura
    m.bloco((-0.105, -0.186, 0.935), (0.12, 0.012, 0.07), wH, PAL, "preto")
    m.bloco((0.125, -0.140, 0.935), (0.06, 0.05, 0.085), wH, PAL, "bolso")                                                       # carregador no cinto
    m.bloco((0.205, 0.0, 0.905), (0.05, 0.11, 0.09), wH, PAL, "cinto")

    # ---------------- mochila tática (corpo, aba, bolsos laterais, bolsos traseiros, correias, cinturão, saco de dormir)
    my = 0.225
    m.bloco((0.0, my, 1.225), (0.300, 0.150, 0.420), wS1, PAL, "mochila", topo=(0.94, 0.95))
    m.bloco((0.0, my + 0.002, 1.455), (0.285, 0.165, 0.085), wS1, PAL, "mochila", topo=(0.88, 0.9))                                # aba de cima
    m.bloco((0.0, my + 0.088, 1.42), (0.22, 0.03, 0.05), wS1, PAL, "alca")                                                       # fivela da aba
    m.bloco((0.0, my + 0.085, 1.22), (0.21, 0.06, 0.25), wS1, PAL, "mochila", topo=(0.95, 0.9))                                   # bolso traseiro
    for s in (1, -1):
        m.bloco((0.172 * s, my, 1.18), (0.045, 0.12, 0.17), wS1, PAL, "bolso")                                                   # bolsos laterais
        m.bloco((0.085 * s, my + 0.117, 1.23), (0.028, 0.02, 0.36), wS1, PAL, "alca")                                            # correias verticais
        m.bloco((0.075 * s, 0.07, 1.285), (0.04, 0.22, 0.03), wS1, PAL, "alca")                                        # alça sobre o ombro (liga peito)
    for zz in (1.30, 1.18, 1.06):
        m.bloco((0.0, my + 0.128, zz), (0.27, 0.014, 0.022), wS1, PAL, "alca")                                                   # correias horizontais
    m.bloco((0.0, my, 0.995), (0.30, 0.16, 0.05), wH, PAL, "preto")                                                              # cinturão traseiro
    rolo = [m.anel((x, my + 0.015, 1.005), (0, 1, 0), (0, 0, 1), 0.052, 0.052, wS1, 8, 0.0) for x in (-0.160, 0.160)]
    m.tubo(rolo, PAL, "areia")                                                                                                  # saco de dormir na base

    # cabeça maior (proporção estilizada da folha): x/y +12 % nos vértices só da cabeça acima do queixo
    for v, w in zip(m.bm.verts, m.vw):
        if w.get("Head", 0) == 1.0 and v.co.z > 1.50:
            v.co.x *= 1.12
            v.co.y = (v.co.y - 0.0) * 1.12
    return m


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    for o in list(bpy.context.scene.objects):
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    camo_img, pal_img = make_camo(), make_paleta()
    m = monta_soldado(arm)
    me = m.fim("Soldado")
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    # materiais: camuflagem (repete) e paleta (sem filtro)
    for nome, img, interp in (("Camuflagem", camo_img, "Linear"), ("Paleta", pal_img, "Closest")):
        mt = bpy.data.materials.new(nome)
        mt.use_nodes = True
        bs = next(n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bs.inputs["Roughness"].default_value = 0.95
        tx = mt.node_tree.nodes.new("ShaderNodeTexImage")
        tx.image = img
        tx.interpolation = interp
        mt.node_tree.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
        me.materials.append(mt)
    ob = bpy.data.objects.new("Soldado", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = arm
    for b in sorted(m.ossos):
        ob.vertex_groups.new(name=b)
    for i, w in enumerate(m.vw):
        for b, val in w.items():
            ob.vertex_groups[b].add([i], val, "REPLACE")
    md = ob.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    # todas as ações viram faixas NLA para sair como clipes do glb (mesmos nomes do counter.glb)
    ad = arm.animation_data_create()
    ad.action = None
    for a in list(bpy.data.actions):
        tr = ad.nla_tracks.new()
        tr.name = a.name
        st = tr.strips.new(a.name, int(round(a.frame_range[0])), a)
        st.name = a.name
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_apply=False, export_skins=True, export_image_format="AUTO")
    shutil.copyfile(os.path.join(CHARS, "counter_weapon_offsets.json"), os.path.join(CHARS, "soldado_weapon_offsets.json"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "raw", "soldado.blend"))
    print("SOLDADO tris=%d verts=%d faces=%d ossos=%d" % (tris, len(me.vertices), len(me.polygons), len(m.ossos)))


if __name__ == "__main__":
    main()
