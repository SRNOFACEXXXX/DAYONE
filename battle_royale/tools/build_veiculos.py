# Veículos e coberturas grandes de campo aberto, modelados à mão (geometria explícita, low poly)
# -> game/assets/models/cobertura/<tipo>.glb  (tipos do design: cobertura_campo_aberto)
# Uso: blender -b --factory-startup -P tools/build_veiculos.py
import bpy, bmesh, math, os
from mathutils import Vector as V, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "cobertura")
os.makedirs(OUT, exist_ok=True)
COR = {
    "fusca_azul": (0.32, 0.46, 0.58), "ferrugem": (0.46, 0.26, 0.14), "ferrugem_esc": (0.32, 0.18, 0.10), "pneu": (0.09, 0.09, 0.09),
    "vidro": (0.18, 0.22, 0.24), "cromo": (0.62, 0.63, 0.62), "branco_avi": (0.86, 0.85, 0.80), "vermelho": (0.66, 0.16, 0.12),
    "trator_verm": (0.72, 0.18, 0.10), "trator_amar": (0.88, 0.70, 0.16), "cinza": (0.40, 0.40, 0.40), "caminhao_verde": (0.24, 0.40, 0.30),
    "madeira": (0.40, 0.30, 0.20), "madeira_clara": (0.60, 0.47, 0.32), "barco_azul": (0.20, 0.42, 0.62), "barco_branco": (0.88, 0.87, 0.82),
    "cana": (0.55, 0.60, 0.26), "terra": (0.50, 0.36, 0.22), "saco": (0.62, 0.55, 0.40), "concreto": (0.62, 0.61, 0.58),
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
    bs.inputs["Roughness"].default_value = 0.4 if n in ("vidro", "cromo") else 0.85
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

    def cx(self, x0, y0, z0, x1, y1, z1, m, rz=0.0, rx=0.0, ry=0.0):
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        c = V(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        M = Matrix.Translation(c) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Diagonal((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0), 1))
        self._add(t, M, m)

    def roda(self, c, r, larg, m="pneu", eixo="Y"):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False, segments=10, radius1=r, radius2=r, depth=larg)
        R = Matrix.Rotation(math.pi / 2, 4, "X") if eixo == "Y" else Matrix.Rotation(math.pi / 2, 4, "Y")
        self._add(t, Matrix.Translation(V(c)) @ R, m)

    def prisma(self, base, h, m):
        b = [V(p) for p in base]
        t = [p + V(h) for p in b]
        mi = self._mi(m)
        vb = [self.bm.verts.new(p) for p in b]
        vt = [self.bm.verts.new(p) for p in t]
        self.bm.faces.new(list(reversed(vb))).material_index = mi
        self.bm.faces.new(vt).material_index = mi
        for i in range(len(b)):
            self.bm.faces.new((vb[i], vb[(i + 1) % len(b)], vt[(i + 1) % len(b)], vt[i])).material_index = mi

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
        print("VEI", self.nome, len(me.polygons))


# ---------------------------------------------------------------- carcaça de Fusca (4,1 m): sem rodas traseiras, sobre tijolos, desbotado
m = Mod("carcaca_fusca")
perfil = [(-2.05, 0.35), (-2.0, 0.75), (-1.55, 1.05), (-0.9, 1.45), (0.35, 1.48), (1.0, 1.1), (1.9, 0.95), (2.05, 0.6), (2.0, 0.35)]
m.prisma([(x, -0.78, z) for x, z in perfil], (0, 1.56, 0), "fusca_azul")                    # carroceria (perfil extrudado)
m.cx(-0.9, -0.8, 1.05, 0.35, 0.8, 1.4, "vidro")                                               # janelas laterais
m.cx(0.38, -0.62, 1.1, 0.42, 0.62, 1.42, "vidro", ry=-0.6)                                   # para-brisa
for x, y, r in ((1.35, -0.82, 0.34), (1.35, 0.82, 0.34)):
    m.roda((x, y, 0.34), r, 0.2)
for y in (-0.7, 0.7):                                                                         # traseira sobre tijolos
    m.cx(-1.6, y - 0.15, 0.0, -1.2, y + 0.15, 0.35, "vermelho")
for x0, x1 in ((-2.1, -2.0), (2.0, 2.1)):
    m.cx(x0, -0.8, 0.45, x1, 0.8, 0.55, "cromo")                                            # para-choques
m.cx(-1.0, -0.1, 1.45, 0.0, 0.1, 1.5, "ferrugem")                                           # ferrugem no teto
m.fim()

# ---------------------------------------------------------------- teco-teco (Paulistinha) caído de nariz, asa quebrada
m = Mod("carcaca_teco_teco")
m.prisma([(-3.2, -0.45, 0.6), (-3.2, 0.45, 0.6), (-3.2, 0.2, 1.3), (-3.2, -0.2, 1.3)], (0, 0, 0), "branco_avi") if False else None
fus = [(-3.6, 0.9), (-3.4, 1.3), (-1.0, 1.7), (1.4, 1.75), (2.4, 1.5), (2.6, 0.9), (1.0, 0.6), (-1.0, 0.7)]
m.prisma([(x, -0.5, z - 0.25) for x, z in fus], (0, 1.0, 0), "branco_avi")
m.cx(-1.0, -0.5, 1.4, 1.3, 0.5, 1.75, "vidro")
m.cx(-0.4, -5.5, 1.75, 1.0, -0.5, 1.85, "branco_avi")                                        # asa esquerda inteira
m.cx(-0.4, 0.5, 1.75, 1.0, 3.0, 1.85, "branco_avi")                                          # asa direita quebrada
m.cx(-0.2, 2.8, 0.05, 1.2, 5.4, 0.15, "branco_avi", rz=0.3, rx=0.25)                         # pedaço caído no chão
m.cx(-3.7, -0.05, 0.9, -3.3, 0.05, 1.9, "vermelho")                                          # leme
m.cx(-3.7, -1.2, 0.95, -3.1, 1.2, 1.05, "branco_avi")                                        # estabilizador
m.cx(2.55, -0.9, 0.5, 2.65, 0.9, 0.62, "madeira", ry=0.4)                                    # hélice torta
for y in (-0.8, 0.8):
    m.roda((1.4, y, 0.3), 0.3, 0.15)
    m.cx(1.3, y - 0.04, 0.3, 1.5, y + 0.04, 0.9, "cinza")
m.cx(-3.2, -0.08, 0.0, -3.0, 0.08, 0.4, "cinza")                                             # bequilha
m.fim()

# ---------------------------------------------------------------- trator (4,2 m)
m = Mod("trator")
m.cx(-0.2, -0.45, 0.8, 2.0, 0.45, 1.5, "trator_verm")                                        # capô
m.cx(1.95, -0.4, 0.75, 2.1, 0.4, 1.4, "cinza")                                              # grade
m.cx(-1.3, -0.55, 0.9, -0.2, 0.55, 1.3, "trator_verm")                                      # corpo/assento
m.cx(-1.0, -0.2, 1.3, -0.6, 0.2, 1.4, "pneu")
m.cx(0.5, -0.05, 1.5, 0.6, 0.05, 2.3, "cinza")                                              # escapamento
for sx in (-1.25, -0.2):                                                                      # santantônio (ROPS)
    for y in (-0.55, 0.55):
        m.cx(sx - 0.04, y - 0.04, 1.3, sx + 0.04, y + 0.04, 2.6, "cinza")
m.cx(-1.3, -0.6, 2.55, -0.15, 0.6, 2.65, "trator_amar")
for y in (-0.95, 0.95):
    m.roda((-0.9, y, 0.8), 0.8, 0.45)                                                       # rodas traseiras grandes
    m.roda((1.5, y * 0.8, 0.45), 0.45, 0.28)
    m.roda((-0.9, y, 0.8), 0.45, 0.47, "trator_amar")                                      # aro
m.fim()

# ---------------------------------------------------------------- caminhão abandonado (7 m), carroceria de madeira, cabine enferrujada
m = Mod("caminhao_abandonado")
m.cx(2.0, -1.2, 0.8, 3.8, 1.2, 2.6, "caminhao_verde")                                       # cabine
m.cx(3.8, -1.1, 0.8, 4.6, 1.1, 1.8, "caminhao_verde")                                       # capô
m.cx(3.75, -1.0, 1.9, 3.82, 1.0, 2.5, "vidro")
m.cx(2.3, -1.22, 1.8, 3.4, -1.18, 2.4, "vidro")
m.cx(2.0, 0.2, 2.4, 3.8, 1.2, 2.62, "ferrugem")
m.cx(-3.0, -1.25, 1.0, 1.9, 1.25, 1.15, "madeira")                                          # assoalho
for y in (-1.25, 1.25):
    m.cx(-3.0, y - 0.05, 1.15, 1.9, y + 0.05, 2.1, "madeira_clara")                         # guardas laterais
m.cx(-3.05, -1.25, 1.15, -2.95, 1.25, 1.6, "madeira_clara", ry=0.9)                         # tampa traseira aberta
m.cx(-3.0, -1.2, 0.5, 4.6, 1.2, 0.8, "ferrugem_esc")                                        # chassi
for x, y in ((3.5, -1.1), (3.5, 1.1), (-1.8, -1.1), (-1.8, 1.1)):
    m.roda((x, y, 0.5), 0.5, 0.3)
m.fim()

# ---------------------------------------------------------------- barco de pesca encalhado (8 m), adernado
m = Mod("barco_encalhado")
casco = [(-4.0, 0.0), (-3.2, -1.2), (2.6, -1.3), (4.0, 0.0), (2.6, 1.3), (-3.2, 1.2)]
m.prisma([(x, y, 0.0) for x, y in casco], (0, 0, 0.35), "barco_azul")
m.prisma([(x * 1.02, y * 1.08, 0.35) for x, y in casco], (0, 0, 1.0), "barco_branco")
m.cx(-3.0, -1.0, 1.35, 2.2, 1.0, 1.42, "madeira_clara")                                     # convés
m.cx(-2.6, -0.8, 1.42, -0.8, 0.8, 3.0, "barco_branco")                                      # casaria
m.cx(-2.62, -0.6, 2.2, -2.58, 0.6, 2.8, "vidro")
m.cx(-2.8, -1.0, 3.0, -0.6, 1.0, 3.12, "barco_azul")
m.cx(0.8, -0.08, 1.42, 0.96, 0.08, 5.5, "madeira")                                          # mastro
m.cx(-0.5, -0.05, 4.5, 3.0, 0.05, 4.6, "madeira")
m.fim()

# ---------------------------------------------------------------- carreta de cana (6 m) carregada, engatada a nada
m = Mod("carreta_cana")
m.cx(-3.0, -1.2, 0.9, 3.0, 1.2, 1.05, "madeira")
for x in (-3.0, -1.5, 0.0, 1.5, 3.0):
    for y in (-1.2, 1.2):
        m.cx(x - 0.06, y - 0.06, 1.05, x + 0.06, y + 0.06, 2.8, "madeira")                  # fueiros
for i, z in enumerate((1.3, 1.7, 2.1, 2.5, 2.85)):                                          # feixes de cana
    w = 1.15 - i * 0.08
    m.cx(-3.2, -w, z - 0.25, 3.2, w, z, "cana")
m.cx(3.0, -0.08, 0.8, 4.4, 0.08, 0.95, "ferrugem")                                          # cambão
m.cx(4.2, -0.3, 0.4, 4.35, 0.3, 0.95, "ferrugem")                                           # pé de apoio
for x in (-1.0, 1.0):
    for y in (-1.35, 1.35):
        m.roda((x, y, 0.55), 0.55, 0.3)
m.fim()

# ---------------------------------------------------------------- trincheira (8 m): vala com sacos de areia e tábuas
m = Mod("trincheira")
for y in (-1.3, 1.3):                                                                         # taludes de terra dos dois lados
    m.prisma([(-4.2, y, 0.0), (4.2, y, 0.0), (4.2, y * 1.8, 0.0), (-4.2, y * 1.8, 0.0)], (0, 0, 0.8), "terra")
for x in [-3.9 + i * 0.6 for i in range(14)]:                                                 # linha de sacos no parapeito
    m.cx(x - 0.28, 1.3, 0.8, x + 0.28, 1.75, 1.05, "saco", rz=0.05 * (x % 2))
    m.cx(x - 0.28, -1.75, 0.8, x + 0.28, -1.3, 1.05, "saco", rz=-0.05 * (x % 2))
for x in (-3.0, 0.0, 3.0):                                                                    # escoras de madeira
    m.cx(x - 0.07, -1.3, 0.0, x + 0.07, -1.2, 0.8, "madeira")
    m.cx(x - 0.07, 1.2, 0.0, x + 0.07, 1.3, 0.8, "madeira")
m.cx(-4.0, -1.2, 0.0, 4.0, 1.2, 0.05, "madeira_clara")                                      # estrado
m.fim()

# ---------------------------------------------------------------- base de concreto da biruta (o mastro vem do detalhe "biruta")
m = Mod("biruta_base_concreto")
m.cx(-1.0, -1.0, 0, 1.0, 1.0, 0.4, "concreto")
m.cx(-0.06, -0.06, 0.4, 0.06, 0.06, 6.4, "cromo")
for i, (y0, r0, c) in enumerate(((0.3, 0.45, "vermelho"), (0.9, 0.38, "barco_branco"), (1.5, 0.31, "vermelho"), (2.1, 0.24, "barco_branco"))):
    m.cx(-r0, y0, 6.0 - r0 - i * 0.1, r0, y0 + 0.6, 6.0 + r0 - i * 0.1, c)
m.fim()
print("VEI_DONE")
