# Avião de salto da partida (bimotor cargueiro de asa alta, ~16 m), modelado à mão em geometria explícita low poly.
# Frente = +X, asa ao longo de Y, Z para cima (exporta Y-up: no Godot a frente fica em +X local).
# -> game/assets/models/veiculos/aviao_salto.glb
# Uso: blender -b --factory-startup -P tools/build_aviao.py
import bpy, bmesh, math, os
from mathutils import Vector as V, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "veiculos")
os.makedirs(OUT, exist_ok=True)
COR = {
    "branco": (0.86, 0.85, 0.80), "faixa": (0.20, 0.36, 0.56), "cinza": (0.46, 0.47, 0.48), "escuro": (0.16, 0.17, 0.18),
    "vidro": (0.14, 0.20, 0.24), "helice": (0.12, 0.12, 0.12), "ponta": (0.80, 0.62, 0.14), "interior": (0.10, 0.10, 0.11),
    "pneu": (0.08, 0.08, 0.08),
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
    bs.inputs["Roughness"].default_value = 0.35 if n == "vidro" else 0.75
    return m


class Mod:
    def __init__(self, nome):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.nome, self.bm, self.mats = nome, bmesh.new(), []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def cx(self, x0, y0, z0, x1, y1, z1, m, rx=0.0):
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        c = V(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        M = Matrix.Translation(c) @ Matrix.Rotation(rx, 4, "X") @ Matrix.Diagonal((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0), 1))
        mi = self._mi(m)
        mp = {v: self.bm.verts.new(M @ v.co) for v in t.verts}
        for f in t.faces:
            self.bm.faces.new([mp[v] for v in f.verts]).material_index = mi
        t.free()

    def secao(self, x, y_meia, z0, z1, chanfro):
        """Seção octogonal da fuselagem em x (meia largura, piso, teto, chanfro dos cantos)."""
        return [V((x, -y_meia + chanfro, z0)), V((x, y_meia - chanfro, z0)), V((x, y_meia, z0 + chanfro)), V((x, y_meia, z1 - chanfro)),
                V((x, y_meia - chanfro, z1)), V((x, -y_meia + chanfro, z1)), V((x, -y_meia, z1 - chanfro)), V((x, -y_meia, z0 + chanfro))]

    def loft(self, secoes, m):
        """Liga seções de mesmo número de pontos (fuselagem); tampa as pontas."""
        mi = self._mi(m)
        anel = [[self.bm.verts.new(p) for p in s] for s in secoes]
        n = len(secoes[0])
        for a, b in zip(anel, anel[1:]):
            for i in range(n):
                self.bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])).material_index = mi
        self.bm.faces.new(list(reversed(anel[0]))).material_index = mi
        self.bm.faces.new(anel[-1]).material_index = mi

    def placa(self, pts, espessura, m):
        """Superfície fina (asa/empenagem): polígono em XY extrudado em Z."""
        mi = self._mi(m)
        vb = [self.bm.verts.new(V(p)) for p in pts]
        vt = [self.bm.verts.new(V(p) + V((0, 0, espessura))) for p in pts]
        self.bm.faces.new(list(reversed(vb))).material_index = mi
        self.bm.faces.new(vt).material_index = mi
        for i in range(len(pts)):
            self.bm.faces.new((vb[i], vb[(i + 1) % len(pts)], vt[(i + 1) % len(pts)], vt[i])).material_index = mi

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
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, self.nome + ".glb"), use_selection=True, export_format="GLB", export_yup=True)
        print("AVIAO", self.nome, len(me.polygons))


m = Mod("aviao_salto")
# fuselagem: nariz arredondado -> cabine -> corpo -> cauda subindo (rampa de carga aberta embaixo da cauda)
m.loft([
    m.secao(8.2, 0.25, 1.55, 1.95, 0.1),
    m.secao(7.6, 0.75, 1.05, 2.35, 0.3),
    m.secao(6.4, 1.15, 0.75, 2.75, 0.45),
    m.secao(4.8, 1.3, 0.6, 2.95, 0.5),
    m.secao(-2.5, 1.3, 0.6, 2.95, 0.5),
    m.secao(-5.2, 1.0, 1.6, 2.95, 0.4),
    m.secao(-7.6, 0.45, 2.45, 3.0, 0.18),
], "branco")
for y in (-1.31, 1.31):                                          # faixa azul da janela de ponta a ponta
    m.cx(-4.5, y - 0.01, 2.05, 6.0, y + 0.01, 2.3, "faixa")
    for x in (-1.5, 0.0, 1.5, 3.0):                                # vigias
        m.cx(x - 0.25, y - 0.02, 2.0, x + 0.25, y + 0.02, 2.35, "vidro")
m.cx(6.3, -0.95, 2.3, 7.3, 0.95, 2.62, "vidro", rx=0.0)          # para-brisa
m.cx(-5.1, -0.9, 0.9, -2.6, 0.9, 1.02, "interior")                # piso interno visível pela rampa
m.cx(-5.6, -0.85, 0.45, -3.2, 0.85, 0.55, "cinza", rx=0.0)        # rampa baixada
# asa alta (envergadura 19 m) com pontas amarelas
m.placa([(1.9, -9.5, 3.0), (3.4, -9.5, 3.0), (4.0, 0.0, 3.0), (3.4, 9.5, 3.0), (1.9, 9.5, 3.0), (1.3, 0.0, 3.0)], 0.28, "branco")
for s in (-1, 1):
    m.cx(1.9, s * 9.55 - 0.3, 3.0, 3.4, s * 9.55 + 0.3, 3.28, "ponta")
    # nacele do motor + hélice de 3 pás
    m.cx(2.2, s * 3.6 - 0.5, 2.35, 5.4, s * 3.6 + 0.5, 3.1, "cinza")
    m.cx(5.4, s * 3.6 - 0.15, 2.6, 5.6, s * 3.6 + 0.15, 2.85, "escuro")
    m.cx(5.62, s * 3.6 - 0.09, 1.47, 5.66, s * 3.6 + 0.09, 3.97, "helice")     # hélice: 2 pás em cruz (disco borrado no jogo)
    m.cx(5.62, s * 3.6 - 1.25, 2.68, 5.66, s * 3.6 + 1.25, 2.77, "helice")
    m.cx(2.6, s * 3.6 - 0.2, 1.1, 3.4, s * 3.6 + 0.2, 2.35, "cinza")   # perna do trem
    m.cx(2.7, s * 3.6 - 0.25, 0.55, 3.3, s * 3.6 + 0.25, 1.15, "pneu")
m.cx(6.3, -0.15, 0.3, 6.7, 0.15, 0.9, "pneu")                      # bequilha
# empenagem: estabilizador horizontal e deriva
m.placa([(-8.2, -3.6, 2.85), (-7.2, -3.6, 2.85), (-5.8, 0.0, 2.85), (-7.2, 3.6, 2.85), (-8.2, 3.6, 2.85)], 0.18, "branco")
for (x0, z0, x1, z1) in ((-8.3, 2.95, -5.6, 3.6), (-8.2, 3.6, -6.3, 4.5), (-8.3, 4.5, -7.0, 5.4), (-8.4, 5.4, -7.5, 6.1)):
    m.cx(x0, -0.12, z0, x1, 0.12, z1, "branco")
m.cx(-8.45, -0.13, 5.1, -7.4, 0.13, 6.15, "faixa")
m.fim()
