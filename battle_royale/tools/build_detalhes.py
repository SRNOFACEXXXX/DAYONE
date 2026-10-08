# Detalhes de chão dos POIs, modelados à mão (geometria explícita) -> game/assets/models/detalhes/<tipo>.glb
# Uso: blender -b --factory-startup -P tools/build_detalhes.py
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "detalhes")
os.makedirs(OUT, exist_ok=True)
V = Vector
COR = {
    "madeira": (0.40, 0.30, 0.20), "madeira_clara": (0.60, 0.47, 0.32), "concreto": (0.64, 0.63, 0.60), "ferro": (0.22, 0.22, 0.22),
    "ferro_claro": (0.55, 0.57, 0.58), "tijolo": (0.66, 0.36, 0.22), "reboco": (0.86, 0.84, 0.78), "reboco_ocre": (0.80, 0.62, 0.38),
    "placa_verde": (0.10, 0.42, 0.22), "placa_branca": (0.92, 0.92, 0.88), "placa_azul": (0.12, 0.30, 0.62), "vermelho": (0.72, 0.16, 0.12),
    "amarelo": (0.92, 0.72, 0.16), "azul": (0.18, 0.40, 0.66), "laranja": (0.90, 0.45, 0.12), "verde": (0.22, 0.52, 0.28),
    "roupa_1": (0.85, 0.30, 0.30), "roupa_2": (0.30, 0.50, 0.85), "roupa_3": (0.95, 0.90, 0.75), "roupa_4": (0.95, 0.75, 0.20),
    "lona": (0.20, 0.42, 0.70), "lona_listra": (0.90, 0.88, 0.80), "pneu": (0.10, 0.10, 0.10), "vidro": (0.55, 0.62, 0.66),
    "plastico_verde": (0.306, 0.42, 0.27), "plastico_verm": (0.75, 0.18, 0.14),
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
    m.use_backface_culling = not n.startswith(("roupa", "lona"))
    return m


class Mod:
    def __init__(self, nome):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.nome, self.bm, self.mats = nome, bmesh.new(), []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _add(self, t, M, m):
        mi = self._mi(m)
        mp = {v: self.bm.verts.new(M @ v.co) for v in t.verts}
        for f in t.faces:
            self.bm.faces.new([mp[v] for v in f.verts]).material_index = mi
        t.free()

    def cx(self, x0, y0, z0, x1, y1, z1, m):
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        M = Matrix.Translation(V(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))) @ Matrix.Diagonal((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0), 1))
        self._add(t, M, m)

    def cil(self, c, r, h, m, lados=6, r2=None, rot=None):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False, segments=lados, radius1=r, radius2=r if r2 is None else r2, depth=h)
        R = rot if rot is not None else Matrix.Identity(4)
        self._add(t, Matrix.Translation(c) @ R, m)

    def quad(self, pts, m):
        vs = [self.bm.verts.new(V(p)) for p in pts]
        self.bm.faces.new(vs).material_index = self._mi(m)

    def fim(self):
        me = bpy.data.meshes.new(self.nome)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(mat(m))
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(self.nome, me)
        bpy.context.scene.collection.objects.link(ob)
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, self.nome + ".glb"), use_selection=True, export_format="GLB", export_yup=True, export_apply=True)
        print("DET", self.nome, len(me.polygons))


RX = Matrix.Rotation(math.pi / 2, 4, "X")
RY = Matrix.Rotation(math.pi / 2, 4, "Y")

# postes (o jogo estica os fios entre os pontos de amarração na cruzeta: x = ±0.7, z = topo - 0.3)
m = Mod("poste_madeira"); m.cil(V((0, 0, 4.0)), 0.13, 8.0, "madeira", r2=0.1); m.cx(-0.8, -0.06, 7.55, 0.8, 0.06, 7.7, "madeira")
for x in (-0.7, 0.0, 0.7):
    m.cil(V((x, 0, 7.78)), 0.04, 0.12, "vidro")
m.fim()
m = Mod("poste_concreto"); m.cx(-0.12, -0.12, 0, 0.12, 0.12, 9.0, "concreto"); m.cx(-0.9, -0.07, 8.5, 0.9, 0.07, 8.65, "concreto")
for x in (-0.8, 0.0, 0.8):
    m.cil(V((x, 0, 8.73)), 0.04, 0.12, "vidro")
m.cx(-0.05, 0.1, 7.2, 0.05, 1.3, 7.3, "ferro"); m.cx(-0.15, 1.2, 7.05, 0.15, 1.5, 7.2, "ferro_claro")       # luminária
m.fim()
# cercas e muros (segmento de 3 m ao longo de +X, começando em x = 0)
m = Mod("cerca_arame")
for x in (0.0, 3.0):
    m.cil(V((x, 0, 0.7)), 0.07, 1.4, "madeira", lados=5)
for z in (0.35, 0.65, 0.95, 1.25):
    m.cx(0.0, -0.008, z, 3.0, 0.008, z + 0.016, "ferro")
m.fim()
m = Mod("cerca_madeira")
for x in (0.0, 3.0):
    m.cx(x - 0.06, -0.06, 0, x + 0.06, 0.06, 1.3, "madeira")
for z in (0.35, 0.8, 1.15):
    m.cx(0.0, -0.03, z, 3.0, 0.03, z + 0.14, "madeira_clara")
m.fim()
m = Mod("muro_baixo"); m.cx(0, -0.08, 0, 3.0, 0.08, 1.2, "tijolo"); m.cx(-0.02, -0.12, 1.2, 3.02, 0.12, 1.28, "concreto"); m.fim()
m = Mod("muro_alto"); m.cx(0, -0.1, 0, 3.0, 0.1, 2.2, "reboco_ocre"); m.cx(-0.02, -0.14, 2.2, 3.02, 0.14, 2.3, "concreto")
m.cx(1.35, -0.16, 0, 1.65, 0.16, 2.3, "reboco_ocre"); m.fim()
m = Mod("portao_ferro")
for x in (0.0, 4.0):
    m.cx(x - 0.15, -0.15, 0, x + 0.15, 0.15, 2.4, "concreto")
for i in range(9):                                                   # grade aberta 30° (passagem livre)
    a = math.radians(30)
    xs = 0.15 + i * 0.22
    m.cx(xs * math.cos(a), -xs * math.sin(a) - 0.02, 0.1, xs * math.cos(a) + 0.03, -xs * math.sin(a) + 0.02, 2.1, "ferro")
m.fim()
# placas
m = Mod("placa_rua"); m.cil(V((0, 0, 1.25)), 0.03, 2.5, "ferro_claro"); m.cx(-0.45, -0.02, 2.2, 0.45, 0.02, 2.45, "placa_azul"); m.fim()
m = Mod("placa_estrada")
for x in (-1.2, 1.2):
    m.cil(V((x, 0, 1.3)), 0.06, 2.6, "ferro_claro")
m.cx(-1.5, -0.04, 1.6, 1.5, 0.04, 2.7, "placa_verde"); m.cx(-1.4, -0.05, 1.7, 1.4, -0.045, 2.6, "placa_branca") if False else m.cx(-1.42, -0.05, 1.68, 1.42, -0.04, 1.74, "placa_branca")
m.fim()
# varal com roupas (4 m entre estacas)
m = Mod("varal")
for x in (0.0, 4.0):
    m.cil(V((x, 0, 0.9)), 0.04, 1.8, "madeira", lados=5)
m.cx(0.0, -0.005, 1.74, 4.0, 0.005, 1.75, "ferro")
for x0, w, h, c in ((0.3, 0.6, 0.7, "roupa_1"), (1.1, 0.5, 0.5, "roupa_2"), (1.8, 0.8, 0.9, "roupa_3"), (2.8, 0.5, 0.6, "roupa_4"), (3.4, 0.4, 0.45, "roupa_2")):
    m.quad([(x0, 0, 1.74), (x0 + w, 0, 1.74), (x0 + w, 0, 1.74 - h), (x0, 0, 1.74 - h)], c)
m.fim()
m = Mod("lixeira"); m.cil(V((0, 0, 0.45)), 0.28, 0.9, "plastico_verde", lados=8); m.cil(V((0, 0, 0.93)), 0.3, 0.06, "plastico_verde", lados=8); m.fim()
m = Mod("orelhao"); m.cil(V((0, 0, 1.1)), 0.05, 2.2, "ferro_claro")
m.cil(V((0, -0.35, 2.05)), 0.55, 0.9, "laranja", lados=10, r2=0.4, rot=RX); m.cx(-0.12, -0.35, 1.25, 0.12, -0.25, 1.6, "ferro"); m.fim()
m = Mod("banco_praca")
m.cx(-0.9, -0.2, 0.42, 0.9, 0.2, 0.48, "madeira_clara"); m.cx(-0.9, 0.16, 0.5, 0.9, 0.2, 0.9, "madeira_clara")
for x in (-0.8, 0.8):
    m.cx(x - 0.04, -0.2, 0, x + 0.04, 0.2, 0.42, "ferro")
m.fim()
m = Mod("bicicleta")
for x in (-0.52, 0.52):
    m.cil(V((x, 0, 0.34)), 0.34, 0.04, "pneu", lados=10, rot=RX)
m.cx(-0.52, -0.02, 0.34, 0.3, 0.02, 0.38, "vermelho"); m.cx(-0.1, -0.02, 0.36, -0.06, 0.02, 0.8, "vermelho")
m.cx(0.25, -0.02, 0.38, 0.52, 0.02, 0.42, "vermelho"); m.cx(0.28, -0.02, 0.4, 0.32, 0.02, 0.95, "ferro"); m.cx(0.24, -0.25, 0.93, 0.36, 0.25, 0.97, "ferro")
m.cx(-0.2, -0.08, 0.8, 0.05, 0.08, 0.85, "ferro"); m.fim()
m = Mod("carrinho_mao")
m.cil(V((0.7, 0, 0.2)), 0.2, 0.08, "pneu", lados=8, rot=RX)
m.quad([(-0.4, -0.3, 0.3), (0.5, -0.3, 0.25), (0.5, 0.3, 0.25), (-0.4, 0.3, 0.3)], "ferro_claro")
m.cx(-0.4, -0.32, 0.3, 0.5, -0.3, 0.6, "ferro_claro"); m.cx(-0.4, 0.3, 0.3, 0.5, 0.32, 0.6, "ferro_claro")
for y in (-0.25, 0.25):
    m.cx(-1.1, y - 0.02, 0.45, 0.6, y + 0.02, 0.49, "madeira")
m.fim()
m = Mod("canoa_praia")
m.quad([(-2.8, 0, 0.05), (-1.5, -0.45, 0.05), (1.5, -0.45, 0.05), (2.8, 0, 0.05)], "azul")
m.quad([(-2.8, 0, 0.05), (2.8, 0, 0.05), (1.5, 0.45, 0.05), (-1.5, 0.45, 0.05)], "azul")
for s in (-1, 1):
    m.quad([(-2.8, 0, 0.05), (-1.5, s * 0.45, 0.05), (-1.5, s * 0.5, 0.6), (-3.0, 0, 0.7)], "madeira_clara")
    m.quad([(-1.5, s * 0.45, 0.05), (1.5, s * 0.45, 0.05), (1.5, s * 0.5, 0.6), (-1.5, s * 0.5, 0.6)], "madeira_clara")
    m.quad([(1.5, s * 0.45, 0.05), (2.8, 0, 0.05), (3.0, 0, 0.7), (1.5, s * 0.5, 0.6)], "madeira_clara")
m.cx(-1.4, -0.48, 0.55, 1.4, 0.48, 0.62, "vermelho")
m.cx(-0.1, -0.45, 0.35, 0.1, 0.45, 0.4, "madeira")
m.fim()
m = Mod("caixote_peixe"); m.cx(-0.35, -0.25, 0, 0.35, 0.25, 0.3, "plastico_verm"); m.cx(0.3, -0.2, 0.3, 1.0, 0.3, 0.6, "azul"); m.fim()
m = Mod("tambor"); m.cil(V((0, 0, 0.45)), 0.29, 0.9, "azul", lados=10); m.cil(V((0, 0, 0.62)), 0.3, 0.04, "ferro", lados=10); m.fim()
m = Mod("pilha_tijolo")
for i in range(4):
    m.cx(-0.6 + (i % 2) * 0.05, -0.4, i * 0.25, 0.6 + (i % 2) * 0.05, 0.4, i * 0.25 + 0.24, "tijolo")
m.cx(-0.65, -0.45, -0.05, 0.65, 0.45, 0.0, "madeira"); m.fim()
m = Mod("lona_barraca")
for x, y in ((-1.5, -1.5), (1.5, -1.5), (-1.5, 1.5), (1.5, 1.5)):
    m.cx(x - 0.04, y - 0.04, 0, x + 0.04, y + 0.04, 2.3, "ferro_claro")
for i in range(6):
    x0 = -1.6 + i * 0.533
    m.quad([(x0, -1.6, 2.3), (x0 + 0.533, -1.6, 2.3), (x0 + 0.533, 1.6, 2.5), (x0, 1.6, 2.5)], "lona" if i % 2 else "lona_listra")
m.cx(-1.3, -1.3, 0.75, 1.3, -0.5, 0.8, "madeira_clara")
for x in (-1.2, 1.2):
    m.cx(x - 0.03, -1.3, 0, x + 0.03, -1.25, 0.75, "ferro")
m.fim()
m = Mod("mesa_bar_cadeiras")
m.cil(V((0, 0, 0.72)), 0.45, 0.04, "amarelo", lados=10); m.cil(V((0, 0, 0.36)), 0.04, 0.72, "amarelo")
for a in (0, 90, 180, 270):
    r = math.radians(a)
    cx0, cy0 = 0.75 * math.cos(r), 0.75 * math.sin(r)
    m.cx(cx0 - 0.2, cy0 - 0.2, 0.42, cx0 + 0.2, cy0 + 0.2, 0.46, "amarelo")
    for dx in (-0.17, 0.17):
        for dy in (-0.17, 0.17):
            m.cx(cx0 + dx - 0.02, cy0 + dy - 0.02, 0, cx0 + dx + 0.02, cy0 + dy + 0.02, 0.42, "amarelo")
    ox, oy = 0.95 * math.cos(r), 0.95 * math.sin(r)
    m.cx(ox - 0.2 * abs(math.sin(r)) - 0.02, oy - 0.2 * abs(math.cos(r)) - 0.02, 0.46, ox + 0.2 * abs(math.sin(r)) + 0.02, oy + 0.2 * abs(math.cos(r)) + 0.02, 0.85, "amarelo")
m.fim()
m = Mod("barril"); m.cil(V((0, 0, 0.45)), 0.3, 0.9, "madeira", lados=8, r2=0.3); m.cil(V((0, 0, 0.45)), 0.33, 0.5, "madeira_clara", lados=8); m.fim()
m = Mod("holofote")
for a in (0, 120, 240):
    r = math.radians(a)
    m.cx(0.4 * math.cos(r) - 0.03, 0.4 * math.sin(r) - 0.03, 0, 0.4 * math.cos(r) + 0.03, 0.4 * math.sin(r) + 0.03, 3.0, "ferro")
m.cx(-0.45, -0.45, 3.0, 0.45, 0.45, 3.08, "ferro")
m.cil(V((0, 0, 3.35)), 0.3, 0.5, "ferro", lados=8, rot=RX); m.cil(V((0, -0.27, 3.35)), 0.26, 0.04, "vidro", lados=8, rot=RX)
m.fim()
# biruta da pista: mastro de 6 m + cone de tecido em faixas laranja/branco apontando o vento (sul -> norte)
m = Mod("biruta")
m.cx(-0.6, -0.6, 0, 0.6, 0.6, 0.3, "concreto")
m.cil(V((0, 0, 3.15)), 0.06, 6.0, "ferro_claro")
for i, (y0, r0, r1, c) in enumerate(((0.1, 0.45, 0.4, "laranja"), (0.7, 0.4, 0.34, "roupa_3"), (1.3, 0.34, 0.28, "laranja"), (1.9, 0.28, 0.22, "roupa_3"), (2.5, 0.22, 0.17, "laranja"))):
    m.cil(V((0, y0 + 0.3, 5.9 - i * 0.12)), r0, 0.6, c, lados=8, r2=r1, rot=RX @ Matrix.Rotation(math.pi, 4, "X"))
m.fim()
print("DET_DONE")
