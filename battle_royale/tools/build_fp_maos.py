# Mãos + antebraços de 1ª pessoa, rígidos e presos à arma (docs/ref/ak47_fps.jpg: mãos cor de pele facetadas,
# manga verde; docs/ref/mosin_lowpoly.png: manga verde camuflada, luva preta).
# Cada arma recebe um .glb "maos_<arma>.glb" no ESPAÇO LOCAL do nó "Arma" do *_fp.glb (Godot: +Y cima, -Z frente).
# Nada de ombro/braço: o antebraço sai da tela por baixo, então nunca cruza a linha de mira no ADS.
# Uso: blender -b --factory-startup -P tools/build_fp_maos.py [-- --preview]
import bpy, bmesh, math, os, sys
from mathutils import Vector as V, Matrix

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(RAIZ, "game", "assets", "models", "weapons")
COR = {
    "pele": (0.80, 0.60, 0.44), "pele_sombra": (0.70, 0.50, 0.36),
    "manga": (0.33, 0.37, 0.22), "manga_b": (0.42, 0.40, 0.26), "manga_c": (0.26, 0.29, 0.18),
    "punho": (0.22, 0.24, 0.15), "luva": (0.10, 0.10, 0.10), "luva_b": (0.16, 0.16, 0.15),
}


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(n):
    m = bpy.data.materials.get(n)
    if m:
        return m
    m = bpy.data.materials.new(n)
    m.use_nodes = True
    bs = next(x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*[lin(c) for c in COR[n]], 1)
    bs.inputs["Roughness"].default_value = 0.85
    return m


def G(p):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return V((p[0], -p[2], p[1]))


class Mod:
    def __init__(self, nome):
        self.nome, self.bm, self.mats = nome, bmesh.new(), []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def bloco(self, centro, eixo_x, eixo_y, eixo_z, tam, m, afina=1.0):
        tam = tuple(t * ESC for t in tam)
        """Caixa orientada (eixos em coordenadas Godot, ortonormais), tam = (lx, ly, lz); afina < 1 estreita a face +z."""
        mi = self._mi(m)
        c = V(centro)
        ex, ey, ez = V(eixo_x).normalized(), V(eixo_y).normalized(), V(eixo_z).normalized()
        hx, hy, hz = tam[0] / 2, tam[1] / 2, tam[2] / 2
        vs = []
        for sz in (-1, 1):
            k = afina if sz > 0 else 1.0
            for sy in (-1, 1):
                for sx in (-1, 1):
                    p = c + ex * sx * hx * k + ey * sy * hy * k + ez * sz * hz
                    vs.append(self.bm.verts.new(G(p)))
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for q in f:
            self.bm.faces.new([vs[i] for i in q]).material_index = mi

    def tubo(self, a, b, r0, r1, mats, lados=6, gira=0.0):
        """Prisma facetado de a até b (Godot), raio r0 -> r1; cada face alterna os materiais da lista (camuflagem por face)."""
        a, b = V(a), V(b)
        d = (b - a).normalized()
        ref = V((0, 1, 0)) if abs(d.y) < 0.9 else V((1, 0, 0))
        u = d.cross(ref).normalized()
        w = d.cross(u).normalized()
        anel = []
        for p, r in ((a, r0), (b, r1)):
            anel.append([self.bm.verts.new(G(p + (u * math.cos(gira + i * 2 * math.pi / lados) + w * math.sin(gira + i * 2 * math.pi / lados)) * r)) for i in range(lados)])
        for i in range(lados):
            j = (i + 1) % lados
            self.bm.faces.new((anel[0][i], anel[0][j], anel[1][j], anel[1][i])).material_index = self._mi(mats[i % len(mats)])
        self.bm.faces.new(list(reversed(anel[0]))).material_index = self._mi(mats[0])
        self.bm.faces.new(anel[1]).material_index = self._mi(mats[0])

    def fim(self):
        me = bpy.data.meshes.new(self.nome)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(mat(m))
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(self.nome, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


ESC = 1.0   # 0,8 nas pistolas (cabo curto, mão mais perto do olho no ADS)


def dedo(M, pts, raios, mats, lados=6):
    """Dedo facetado: cadeia de prismas afinando (cada articulação é o ponto seguinte), cores alternando por face."""
    for i in range(len(pts) - 1):
        M.tubo(pts[i], pts[i + 1], raios[i], raios[i + 1], mats, lados, 0.4 * i)


def mao_empunhadura(M, pulso, eixo_cabo, lado, pele, luva=False):
    """Mão fechada num cabo (docs/ref/ak47_fps.jpg: mãos facetadas, dedos longos envolvendo). pulso = centro da mão;
    eixo_cabo = direção do cabo (para baixo/trás); lado = +1 mão direita, -1 esquerda. 4 dedos em 3 falanges por cima do
    cabo (frente) e o polegar subindo pelo outro lado."""
    p = V(pulso)
    ec = V(eixo_cabo).normalized()
    frente = V((0, 0, -1))
    frente = (frente - ec * frente.dot(ec)).normalized()
    lat = ec.cross(frente).normalized()                  # aponta para +x quando o cabo desce
    cp, cs = ("luva", "luva_b") if luva else (pele, "pele_sombra")
    mats = [cp, cs, cp]
    # palma: bloco afunilado no lado da mão
    M.bloco(p + lat * lado * 0.03, lat, frente, ec, (0.028, 0.08, 0.1), cp, 0.82)
    M.bloco(p + lat * lado * 0.03 - ec * 0.055, lat, frente, ec, (0.026, 0.07, 0.03), cs, 0.9)   # base da palma (heel)
    # dedos: saem da borda frontal da palma, cobrem a frente do cabo e voltam pelo outro lado
    for i in range(4):
        y = -0.032 + i * 0.0225
        r = 0.0112 - 0.0007 * abs(i - 1.2)
        a0 = p + lat * lado * 0.03 + frente * 0.012 + ec * y
        a1 = p + lat * lado * 0.02 + frente * 0.043 + ec * y
        a2 = p - lat * lado * 0.004 + frente * 0.05 + ec * (y + 0.004)
        a3 = p - lat * lado * 0.024 + frente * 0.034 + ec * (y + 0.008)
        a4 = p - lat * lado * 0.03 + frente * 0.016 + ec * (y + 0.01)
        dedo(M, [a0, a1, a2, a3, a4], [r, r * 0.95, r * 0.88, r * 0.8, r * 0.7], mats)
    # polegar: do punho pelo lado de trás, subindo ao longo do cabo
    t0 = p + lat * lado * 0.03 - ec * 0.045 - frente * 0.01
    t1 = p - lat * lado * 0.002 - ec * 0.052 - frente * 0.018
    t2 = p - lat * lado * 0.024 - ec * 0.03 - frente * 0.008
    t3 = p - lat * lado * 0.034 - ec * 0.004 + frente * 0.004
    dedo(M, [t0, t1, t2, t3], [0.0145, 0.0125, 0.0108, 0.009], [cp, cs, cp])
    return p + lat * lado * 0.03 + frente * -0.035 + ec * 0.03   # ponto do pulso (onde nasce o antebraço)


def mao_apoio(M, centro, lado, pele, luva=False):
    """Mão de apoio envolvendo o guarda-mão (como em ak47_fps.jpg): palma por baixo, 4 dedos facetados em 3 falanges
    SUBINDO pelo lado oposto e curvando por cima, polegar subindo pelo outro lado — visível no quadril e nas bordas no ADS.
    centro = centro da seção do guarda-mão (não a face de baixo)."""
    c = V(centro)
    x, y, z = V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))
    cp, cs = ("luva", "luva_b") if luva else (pele, "pele_sombra")
    M.bloco(c + V((0, -0.047, 0.0)), x, y, z, (0.08, 0.026, 0.098), cp, 0.88)                  # palma sob o guarda-mão
    M.bloco(c + V((lado * 0.012, -0.05, 0.058)), x, y, z, (0.06, 0.024, 0.03), cs, 0.9)       # base da palma
    for i in range(4):
        zz = -0.04 + i * 0.0245
        r = 0.0115 - 0.0007 * abs(i - 1.2)
        f0 = c + V((-lado * 0.036, -0.045, zz))
        f1 = c + V((-lado * 0.052, -0.022, zz))
        f2 = c + V((-lado * 0.054, 0.012, zz))
        f3 = c + V((-lado * 0.04, 0.042, zz + 0.002))
        f4 = c + V((-lado * 0.018, 0.05, zz + 0.004))
        dedo(M, [f0, f1, f2, f3, f4], [r, r * 0.97, r * 0.9, r * 0.82, r * 0.72], [cp, cs, cp])
    t0 = c + V((lado * 0.034, -0.048, 0.03))
    t1 = c + V((lado * 0.052, -0.03, 0.018))
    t2 = c + V((lado * 0.056, 0.0, 0.0))
    t3 = c + V((lado * 0.044, 0.022, -0.02))
    dedo(M, [t0, t1, t2, t3], [0.0155, 0.0135, 0.0115, 0.0095], [cp, cs, cp])
    return c + V((lado * 0.02, -0.055, 0.045))


def antebraco(M, pulso, direcao, comp, luva=False):
    d = V(direcao).normalized()
    a = V(pulso)
    b = a + d * comp
    pele = ("luva",) if luva else ("pele", "pele_sombra")
    M.tubo(a - d * 0.01, a + d * 0.05, 0.03, 0.034, list(pele), 6)                              # pulso
    M.tubo(a + d * 0.045, a + d * 0.075, 0.041, 0.043, ["punho"], 6)                            # punho da manga
    M.tubo(a + d * 0.07, b, 0.043, 0.056, ["manga", "manga_b", "manga_c", "manga", "manga_c", "manga_b"], 6, 0.3)


# Pontos de pega por arma (espaço do nó "Arma", Godot, metros), medidos no perfil da malha (tests/_sight_probe.gd):
# AK: cabo z 0,02..0,06 descendo até y -0,16; guarda-mão z -0,38..-0,26. M4: cabo z 0..0,06 (y -0,18); guarda-mão z -0,34..-0,18.
ARMAS = {
    "ak47": {"cabo": (0.0, -0.075, 0.045), "eixo_cabo": (0.0, -1.0, 0.35), "apoio": (0.0, -0.02, -0.31), "luva": False},
    "m4": {"cabo": (0.0, -0.085, 0.035), "eixo_cabo": (0.0, -1.0, 0.3), "apoio": (0.0, -0.03, -0.26), "luva": False},
    "pistol": {"cabo": (0.0, -0.055, 0.035), "eixo_cabo": (0.0, -1.0, 0.25), "apoio": None, "luva": False},
    "pistol_ct": {"cabo": (0.0, -0.055, 0.035), "eixo_cabo": (0.0, -1.0, 0.25), "apoio": None, "luva": False},
}


# Armas novas (game/assets/models/weapons/wf/*.glb, medidas nas vistas com grade de tools/vista_arma.py):
ARMAS_WF = {
    "ak47": {"cabo": (0.0, 0.05, 0.15), "eixo_cabo": (0.0, -1.0, 0.15), "apoio": (0.0, 0.118, -0.19), "luva": False},
    "m4": {"cabo": (0.0, -0.092, 0.144), "eixo_cabo": (0.0, -1.0, 0.6), "apoio": (0.0, 0.0, -0.15), "luva": False},
    "mosin": {"cabo": (0.0, 0.013, 0.228), "eixo_cabo": (0.0, -1.0, 0.45), "apoio": (0.0, 0.07, -0.08), "luva": True},
    "m1911": {"cabo": (0.0, -0.07, 0.076), "eixo_cabo": (0.0, -1.0, 0.34), "apoio": None, "luva": False},
    "revolver": {"cabo": (0.0, 0.0, 0.121), "eixo_cabo": (0.0, -1.0, 0.26), "apoio": None, "luva": False},
}


try:   # armas extras (tools/armas_novas.json)
    import json as _j
    for _k, _c in _j.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "armas_novas.json"), encoding="utf-8")).items():
        if not _k.startswith("_"):
            ARMAS_WF[_c["modelo"]] = {"cabo": tuple(_c["cabo"]), "eixo_cabo": tuple(_c["eixo_cabo"]), "apoio": tuple(_c["apoio"]), "luva": False}
except Exception as _e:
    print("armas_novas.json:", _e)


def centrar(ob, ponto):
    """Move a origem do objeto para `ponto` (Godot) mantendo a geometria no lugar: o nó gira/anda em volta da mão."""
    loc = G(ponto)
    for v in ob.data.vertices:
        v.co -= loc
    ob.location = loc


def gerar(nome, cfg):
    global ESC
    ESC = 0.52 if cfg["apoio"] is None else 1.0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if cfg["apoio"]:
        # duas peças: MaoD (empunhadura + antebraço) e MaoE (apoio + antebraço); MaoE tem a origem na mão para animar a recarga
        MD = Mod("MaoD")
        pulso_d = mao_empunhadura(MD, cfg["cabo"], cfg["eixo_cabo"], 1, "pele", cfg["luva"])
        antebraco(MD, pulso_d, (0.3, -0.8, 0.8), 0.36, cfg["luva"])
        ME = Mod("MaoE")
        pulso_e = mao_apoio(ME, cfg["apoio"], -1, "pele", cfg["luva"])
        antebraco(ME, pulso_e, (-0.3, -1.0, 0.55), 0.36, cfg["luva"])   # desce quase reto: não varre a tela no ADS
        od, oe = MD.fim(), ME.fim()
        centrar(oe, cfg["apoio"])
        objs = [od, oe]
    else:
        M = Mod("MaosFP")
        pulso_d = mao_empunhadura(M, cfg["cabo"], cfg["eixo_cabo"], 1, "pele", cfg["luva"])
        antebraco(M, pulso_d, (0.3, -0.8, 0.8), 0.36, cfg["luva"])
        # pistola: mão esquerda por baixo/à esquerda da direita (pega a duas mãos)
        c = V(cfg["cabo"]) + V((-0.035, -0.02, 0.005))
        mao_empunhadura(M, c, cfg["eixo_cabo"], -1, "pele", cfg["luva"])
        antebraco(M, c + V((-0.03, -0.03, 0.035)), (-0.4, -0.55, 1.0), 0.42, cfg["luva"])
        objs = [M.fim()]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "maos_%s.glb" % nome), use_selection=True, export_format="GLB", export_yup=True)
    print("MAOS", nome, sum(len(o.data.polygons) for o in objs))


for n, c in ARMAS.items():
    gerar(n, c)
for n, c in ARMAS_WF.items():
    gerar("wf_" + n, c)
