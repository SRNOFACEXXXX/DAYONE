# Vegetação low poly modelada à mão (geometria explícita, sem aleatoriedade) -> game/assets/models/veg/<tipo>.glb
# Uso: blender -b --factory-startup -P tools/build_vegetacao.py
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "veg")
os.makedirs(OUT, exist_ok=True)

# paleta (sRGB) — tons de mata atlântica e litoral
COR = {
    "tronco": (0.36, 0.26, 0.18), "tronco_base": (0.23, 0.18, 0.13), "tronco_coq": (0.55, 0.47, 0.36), "casca_clara": (0.35, 0.29, 0.22),
    "folha_escura": (0.13, 0.27, 0.10), "folha": (0.20, 0.36, 0.13), "folha_clara": (0.33, 0.47, 0.17),
    "folha_amarela": (0.52, 0.55, 0.20), "coco": (0.40, 0.33, 0.13), "banana": (0.28, 0.48, 0.16),
    "capim": (0.55, 0.55, 0.25), "capim_escuro": (0.38, 0.42, 0.18), "pedra": (0.47, 0.44, 0.40), "pedra_escura": (0.34, 0.32, 0.30),
}


def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(nome):
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    r, g, b = COR[nome]
    bs.inputs["Base Color"].default_value = (srgb2lin(r), srgb2lin(g), srgb2lin(b), 1)
    bs.inputs["Roughness"].default_value = 0.9
    # folhas e capim são lâminas: dupla face (glTF doubleSided)
    m.use_backface_culling = not any(k in nome for k in ("folha", "banana", "capim"))
    return m


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


class Mod:
    """Acumula geometria (bmesh) com índice de material por face."""

    def __init__(self, nome):
        self.nome = nome
        self.bm = bmesh.new()
        self.mats = []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def poly(self, pts, m):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self._mi(m)
        f.smooth = False
        return f

    def tubo(self, eixo, raios, lados, m, tampa=True):
        """Tronco: anel por ponto do eixo (lista de Vector) com raio próprio."""
        aneis = []
        for i, (p, r) in enumerate(zip(eixo, raios)):
            d = (eixo[min(i + 1, len(eixo) - 1)] - eixo[max(i - 1, 0)]).normalized()
            a = d.orthogonal().normalized()
            b = d.cross(a)
            aneis.append([self.bm.verts.new(p + (a * math.cos(t) + b * math.sin(t)) * r)
                          for t in [k * math.tau / lados for k in range(lados)]])
        mi = self._mi(m)
        for i in range(len(aneis) - 1):
            for k in range(lados):
                f = self.bm.faces.new((aneis[i][k], aneis[i][(k + 1) % lados], aneis[i + 1][(k + 1) % lados], aneis[i + 1][k]))
                f.material_index = mi
        if tampa:
            f = self.bm.faces.new(list(reversed(aneis[0])))
            f.material_index = mi
            f = self.bm.faces.new(aneis[-1])
            f.material_index = mi

    def blob(self, centro, escala, m, rot_z=0.0, amassa=None):
        """Copa: icosfera de 1 subdivisão escalada (low poly facetado). amassa: {índice_vértice: fator} feito à mão."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=1.0)
        if amassa:
            tmp.verts.ensure_lookup_table()
            for i, f in amassa.items():
                tmp.verts[i].co *= f
        M = Matrix.Translation(centro) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Diagonal((*escala, 1.0))
        mi = self._mi(m)
        mapa = {v: self.bm.verts.new(M @ v.co) for v in tmp.verts}
        for f in tmp.faces:
            nf = self.bm.faces.new([mapa[v] for v in f.verts])
            nf.material_index = mi
        tmp.free()

    def fronde(self, base, direcao, comp, larg, queda, m, segs=4):
        """Folha de coqueiro/bananeira: tira que se curva para baixo (queda em m na ponta), afina na ponta."""
        d = Vector(direcao).normalized()
        lado = Vector((0, 0, 1)).cross(d).normalized()
        pts_e, pts_d = [], []
        for i in range(segs + 1):
            t = i / segs
            c = base + d * comp * t + Vector((0, 0, -queda * t * t + 0.35 * comp * t * (1 - t)))
            w = larg * (1 - t * 0.85) * (0.6 + 0.4 * math.sin(math.pi * min(t * 1.4, 1)))
            pts_e.append(c + lado * w + Vector((0, 0, -w * 0.35)))   # folha em "V" (nervura central)
            pts_d.append(c - lado * w + Vector((0, 0, -w * 0.35)))
            if i == 0:
                eixo0 = c
            pts_e[-1], pts_d[-1] = pts_e[-1], pts_d[-1]
        mi = self._mi(m)
        cen = [base + d * comp * (i / segs) + Vector((0, 0, -queda * (i / segs) ** 2 + 0.35 * comp * (i / segs) * (1 - i / segs))) for i in range(segs + 1)]
        ve = [self.bm.verts.new(p) for p in pts_e]
        vd = [self.bm.verts.new(p) for p in pts_d]
        vc = [self.bm.verts.new(p) for p in cen]
        for i in range(segs):
            for a, b in ((ve, vc), (vc, vd)):
                f = self.bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
                f.material_index = mi

    def lamina(self, base, dir_xy, altura, larg, curva, m):
        """Lâmina de capim: triângulo curvo em 2 segmentos."""
        d = Vector((dir_xy[0], dir_xy[1], 0)).normalized()
        lado = Vector((0, 0, 1)).cross(d).normalized()
        p0a = base + lado * larg
        p0b = base - lado * larg
        p1 = base + Vector((0, 0, altura * 0.55)) + d * curva * 0.35
        p1a = p1 + lado * larg * 0.55
        p1b = p1 - lado * larg * 0.55
        p2 = base + Vector((0, 0, altura)) + d * curva
        self.poly([p0a, p0b, p1b, p1a], m)
        self.poly([p1a, p1b, p2], m)

    def fim(self):
        me = bpy.data.meshes.new(self.nome)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(mat(m))
        ob = bpy.data.objects.new(self.nome, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def exportar(nome):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + ".glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_apply=True, export_materials="EXPORT")
    print("VEG", nome, sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH"), "faces")


V = Vector

# ---------------------------------------------------------------- coqueiro (12 m): tronco curvo inclinado para o mar
limpar()
m = Mod("coqueiro")
eixo = [V((0, 0, 0)), V((0.15, 0, 2.5)), V((0.45, 0.05, 5.0)), V((0.9, 0.1, 7.4)), V((1.45, 0.12, 9.6)), V((2.0, 0.1, 11.4))]
m.tubo(eixo, [0.26, 0.22, 0.19, 0.17, 0.16, 0.15], 7, "tronco_coq")
topo = eixo[-1] + V((0, 0, 0.1))
# 9 frondes: ângulos e quedas escolhidos à mão (copa assimétrica, pendendo mais para o lado do mar)
for ang, comp, queda, cor in ((0, 4.6, 2.8, "folha"), (38, 4.2, 2.3, "folha_clara"), (80, 4.8, 3.0, "folha"), (122, 4.0, 2.1, "folha_escura"),
                              (160, 4.5, 2.6, "folha"), (200, 4.3, 2.9, "folha_clara"), (243, 4.7, 2.5, "folha_escura"), (285, 4.1, 2.2, "folha"),
                              (325, 4.4, 2.7, "folha_amarela")):
    a = math.radians(ang)
    m.fronde(topo, (math.cos(a), math.sin(a), 0), comp, 0.55, queda, cor, segs=4)
for dx, dy, dz in ((0.25, 0.1, -0.35), (-0.15, 0.22, -0.4), (0.05, -0.25, -0.38), (-0.2, -0.12, -0.3)):
    m.blob(topo + V((dx, dy, dz)), (0.17, 0.17, 0.19), "coco")
m.fim()
exportar("coqueiro")

# ---------------------------------------------------------------- árvore de mata A (16 m): copa larga em camadas
limpar()
m = Mod("arvore_mata_a")
m.tubo([V((0, 0, 0)), V((0.1, 0, 3)), V((0.05, 0.1, 6.5)), V((-0.1, 0.1, 9))], [0.45, 0.34, 0.28, 0.22], 7, "tronco")
m.tubo([V((0, 0, -0.1)), V((0.03, 0, 1.1))], [0.47, 0.42], 7, "tronco_base")   # pé do tronco sujo/úmido #3B2E22 (crítica 02)
# galhos principais (à mão)
for p, q, r in ((V((0.05, 0.1, 6.5)), V((2.2, 0.8, 10.5)), 0.14), (V((0.0, 0.05, 7.0)), V((-2.0, -1.2, 10.8)), 0.13),
                (V((-0.05, 0.1, 8.0)), V((0.4, -2.3, 11.5)), 0.12)):
    m.tubo([p, (p + q) * 0.5 + V((0, 0, 0.4)), q], [r, r * 0.8, r * 0.6], 5, "tronco")
# copa: 7 blobs posicionados à mão (silhueta larga e irregular)
for c, e, cor, rz in ((V((0, 0, 12.2)), (4.2, 3.8, 2.4), "folha", 0.2), (V((2.6, 1.0, 11.2)), (2.8, 2.4, 1.9), "folha_escura", 0.6),
                      (V((-2.4, -1.3, 11.4)), (2.9, 2.6, 2.0), "folha", 1.1), (V((0.6, -2.5, 12.0)), (2.4, 2.2, 1.8), "folha_clara", 0.4),
                      (V((-1.0, 2.2, 12.8)), (2.3, 2.1, 1.7), "folha_escura", 1.7), (V((0.4, 0.3, 14.0)), (2.6, 2.4, 1.6), "folha_clara", 0.9),
                      (V((3.0, -1.6, 12.6)), (1.7, 1.6, 1.3), "folha", 2.3)):
    m.blob(c, e, cor, rz)
m.fim()
exportar("arvore_mata_a")

# ---------------------------------------------------------------- árvore de mata B (19 m): emergente, copa alta e estreita
limpar()
m = Mod("arvore_mata_b")
m.tubo([V((0, 0, 0)), V((-0.1, 0.05, 5)), V((0.1, 0, 10)), V((0.2, -0.1, 14))], [0.4, 0.3, 0.24, 0.18], 7, "casca_clara")
m.tubo([V((0, 0, -0.1)), V((-0.02, 0.01, 1.0))], [0.42, 0.38], 7, "tronco_base")
for c, e, cor, rz in ((V((0.2, -0.1, 14.8)), (2.6, 2.4, 2.0), "folha", 0.3), (V((1.2, 0.6, 16.4)), (2.0, 1.8, 1.7), "folha_escura", 1.0),
                      (V((-0.9, -0.7, 16.8)), (1.9, 1.8, 1.6), "folha", 1.9), (V((0.3, 0.1, 18.3)), (1.6, 1.5, 1.3), "folha_clara", 0.5),
                      (V((-0.2, 1.3, 13.4)), (1.5, 1.4, 1.2), "folha_escura", 2.6)):
    m.blob(c, e, cor, rz)
m.fim()
exportar("arvore_mata_b")

# ---------------------------------------------------------------- arbusto (2 m)
limpar()
m = Mod("arbusto")
for c, e, cor, rz in ((V((0, 0, 0.9)), (1.2, 1.0, 0.9), "folha", 0.0), (V((0.8, 0.3, 0.7)), (0.8, 0.7, 0.7), "folha_escura", 0.7),
                      (V((-0.6, -0.4, 0.75)), (0.8, 0.8, 0.7), "folha_clara", 1.3), (V((0.1, 0.5, 1.4)), (0.7, 0.6, 0.55), "folha_clara", 2.0)):
    m.blob(c, e, cor, rz)
m.fim()
exportar("arbusto")

# ---------------------------------------------------------------- bananeira (3,5 m)
limpar()
m = Mod("bananeira")
m.tubo([V((0, 0, 0)), V((0.05, 0, 1.4)), V((0.1, 0.05, 2.6))], [0.2, 0.17, 0.14], 7, "banana")
topo = V((0.1, 0.05, 2.6))
for ang, comp, queda, cor in ((10, 2.2, 1.2, "banana"), (70, 2.0, 0.9, "folha_clara"), (135, 2.4, 1.4, "banana"),
                              (195, 1.9, 1.0, "folha"), (250, 2.3, 1.3, "folha_clara"), (310, 2.1, 1.1, "banana")):
    a = math.radians(ang)
    m.fronde(topo, (math.cos(a), math.sin(a), 0), comp, 0.42, queda, cor, segs=3)
m.fim()
exportar("bananeira")

# ---------------------------------------------------------------- touceira de capim alto (1 m)
limpar()
m = Mod("capim_alto")
for ang, alt, curva, cor in ((0, 1.0, 0.35, "capim"), (40, 0.85, 0.3, "capim_escuro"), (85, 1.1, 0.4, "capim"), (130, 0.9, 0.25, "capim_escuro"),
                             (175, 1.05, 0.38, "capim"), (220, 0.8, 0.3, "capim_escuro"), (265, 1.0, 0.36, "capim"), (310, 0.95, 0.3, "capim_escuro")):
    a = math.radians(ang)
    m.lamina(V((math.cos(a) * 0.08, math.sin(a) * 0.08, 0)), (math.cos(a), math.sin(a)), alt, 0.06, curva, cor)
m.fim()
exportar("capim_alto")

# ---------------------------------------------------------------- pedra pequena (0,8 m): icosfera com vértices ajustados à mão
limpar()
m = Mod("pedra_pequena")
m.blob(V((0, 0, 0.25)), (0.7, 0.55, 0.45), "pedra", 0.3, amassa={0: 0.7, 3: 1.15, 5: 0.85, 7: 1.2, 9: 0.8, 11: 0.9})
m.blob(V((0.45, 0.2, 0.15)), (0.35, 0.3, 0.25), "pedra_escura", 1.2, amassa={1: 0.8, 4: 1.1})
m.fim()
exportar("pedra_pequena")
# ---------------------------------------------------------------- touceira de cana (2,6 m): 9 colmos com folhas longas arqueadas
limpar()
m = Mod("cana")
colmos = ((0.0, 0.0, 2.6), (0.2, 0.08, 2.4), (-0.16, 0.13, 2.5), (0.07, -0.19, 2.3), (-0.14, -0.11, 2.55))
for i, (x, y, h) in enumerate(colmos):   # leve: 5 colmos de 3 lados, 1 folha arqueada cada (plantação com 5.560 touceiras)
    m.tubo([V((x, y, 0)), V((x * 1.25, y * 1.25, h))], [0.03, 0.02], 3, "capim_escuro", tampa=False)
    a = math.radians(i * 72 + 20)
    m.fronde(V((x * 1.2, y * 1.2, h * 0.78)), (math.cos(a), math.sin(a), 0), 1.1, 0.06, 0.6, "capim" if i % 2 else "folha_clara", segs=2)
m.fim()
exportar("cana")
print("VEG_DONE")
