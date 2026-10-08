# Props de sobrevivência modelados à mão (low poly facetado): caixa militar (corpo + tampa com dobradiça), colete de placas, granada.
# -> game/assets/models/props/caixa_corpo.glb, caixa_tampa.glb, colete_placas.glb, granada.glb
# Uso: blender -b --factory-startup -P tools/build_suprimentos.py
# Eixos Blender: X = comprimento, Y = profundidade (frente = -Y), Z = altura. Exporta Y-up.
import bpy, bmesh, math, os
from mathutils import Vector as V, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "props")
COR = {
    "oliva": (0.27, 0.31, 0.18), "oliva_escuro": (0.17, 0.20, 0.12), "metal": (0.42, 0.43, 0.42), "metal_escuro": (0.14, 0.15, 0.15),
    "estencil": (0.85, 0.72, 0.18), "madeira": (0.45, 0.30, 0.16), "lona": (0.23, 0.26, 0.17), "placa": (0.36, 0.40, 0.44),
    "velcro": (0.12, 0.13, 0.11), "granada": (0.22, 0.27, 0.15), "pino": (0.72, 0.62, 0.20),
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
    bs.inputs["Roughness"].default_value = 0.8
    return m


class Mod:
    def __init__(self, nome):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.nome, self.bm, self.mats = nome, bmesh.new(), []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def cx(self, x0, y0, z0, x1, y1, z1, m, rx=0.0, rz=0.0, pivo=None):
        """Caixa alinhada aos eixos entre dois cantos; rx/rz giram em torno do centro (ou do pivo)."""
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        c = V(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        M = Matrix.Translation(c) @ Matrix.Diagonal((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0), 1))
        if rx or rz:
            p = V(pivo) if pivo else c
            R = Matrix.Translation(p) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Translation(-p)
            M = R @ M
        mi = self._mi(m)
        mp = {v: self.bm.verts.new(M @ v.co) for v in t.verts}
        for f in t.faces:
            self.bm.faces.new([mp[v] for v in f.verts]).material_index = mi
        t.free()

    def prisma(self, pts, z0, z1, m):
        """Polígono em XY extrudado de z0 a z1."""
        mi = self._mi(m)
        vb = [self.bm.verts.new(V((p[0], p[1], z0))) for p in pts]
        vt = [self.bm.verts.new(V((p[0], p[1], z1))) for p in pts]
        self.bm.faces.new(list(reversed(vb))).material_index = mi
        self.bm.faces.new(vt).material_index = mi
        n = len(pts)
        for i in range(n):
            self.bm.faces.new((vb[i], vb[(i + 1) % n], vt[(i + 1) % n], vt[i])).material_index = mi

    def esfera(self, cx, cy, cz, r, m, sx=1.0, sy=1.0, sz=1.0):
        mi = self._mi(m)
        t = bmesh.new()
        bmesh.ops.create_icosphere(t, subdivisions=1, radius=r)
        mp = {v: self.bm.verts.new((cx + v.co.x * sx, cy + v.co.y * sy, cz + v.co.z * sz)) for v in t.verts}
        for f in t.faces:
            self.bm.faces.new([mp[v] for v in f.verts]).material_index = mi
        t.free()

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
        print("SUPRIMENTO", self.nome, len(me.polygons))


# ---- caixa militar de munição/armas: 0,9 x 0,5 x 0,5 m; corpo 0,36 + tampa 0,14 (origem do corpo: centro da base)
L, P = 0.9, 0.5
m = Mod("caixa_corpo")
m.cx(-L / 2, -P / 2, 0.0, L / 2, P / 2, 0.36, "oliva")
m.cx(-L / 2 - 0.015, -P / 2 - 0.015, 0.0, -L / 2 + 0.05, P / 2 + 0.015, 0.36, "oliva_escuro")     # cantoneiras
m.cx(L / 2 - 0.05, -P / 2 - 0.015, 0.0, L / 2 + 0.015, P / 2 + 0.015, 0.36, "oliva_escuro")
m.cx(-L / 2, -P / 2 - 0.012, 0.05, L / 2, -P / 2 + 0.01, 0.09, "oliva_escuro")                     # nervuras horizontais
m.cx(-L / 2, -P / 2 - 0.012, 0.25, L / 2, -P / 2 + 0.01, 0.29, "oliva_escuro")
m.cx(-0.25, -P / 2 - 0.02, 0.12, 0.25, -P / 2 + 0.01, 0.23, "estencil")                            # faixa de estêncil
for x in (-0.3, 0.3):                                                                               # fechos de metal na frente
    m.cx(x - 0.04, -P / 2 - 0.035, 0.30, x + 0.04, -P / 2 + 0.01, 0.40, "metal")
for y in (-0.12, 0.12):                                                                             # alças laterais
    m.cx(-L / 2 - 0.05, y - 0.05, 0.16, -L / 2, y + 0.05, 0.24, "metal_escuro")
    m.cx(L / 2, y - 0.05, 0.16, L / 2 + 0.05, y + 0.05, 0.24, "metal_escuro")
m.cx(-0.3, -0.18, 0.0, 0.3, 0.18, 0.365, "madeira")                                                # forro de madeira aparente por dentro
m.fim()

# tampa: origem na dobradiça (aresta de trás, em cima do corpo); ocupa Y de -P..0, Z de 0..0,14
m = Mod("caixa_tampa")
m.cx(-L / 2, -P, 0.0, L / 2, 0.0, 0.11, "oliva")
m.cx(-L / 2 - 0.015, -P - 0.015, 0.0, -L / 2 + 0.05, 0.015, 0.11, "oliva_escuro")
m.cx(L / 2 - 0.05, -P - 0.015, 0.0, L / 2 + 0.015, 0.015, 0.11, "oliva_escuro")
m.cx(-L / 2 + 0.06, -P + 0.06, 0.11, L / 2 - 0.06, -0.06, 0.135, "oliva_escuro")                   # painel elevado
m.cx(-0.2, -P / 2 - 0.06, 0.135, 0.2, -P / 2 + 0.06, 0.15, "metal_escuro")                          # alça de cima
for x in (-0.3, 0.3):
    m.cx(x - 0.04, -P - 0.03, 0.0, x + 0.04, -P + 0.01, 0.11, "metal")
for x in (-0.3, 0.3):                                                                               # dobradiças
    m.cx(x - 0.05, -0.02, 0.0, x + 0.05, 0.03, 0.09, "metal_escuro")
m.fim()

# ---- colete de placas, deitado no chão (0,46 x 0,12 x 0,54): frente + costas ligadas por ombros e faixas laterais
m = Mod("colete_placas")
m.cx(-0.22, -0.06, 0.05, 0.22, -0.02, 0.5, "lona")                      # frente
m.cx(-0.22, 0.02, 0.05, 0.22, 0.06, 0.5, "lona")                        # costas
m.cx(-0.17, -0.075, 0.14, 0.17, -0.06, 0.45, "placa")                   # placa frontal à mostra
m.cx(-0.17, 0.06, 0.14, 0.17, 0.075, 0.45, "placa")                     # placa traseira
for x in (-0.15, 0.15):                                                 # ombros
    m.cx(x - 0.05, -0.06, 0.5, x + 0.05, 0.06, 0.56, "lona")
m.cx(-0.22, -0.065, 0.05, 0.22, 0.065, 0.11, "velcro")                  # cinta da cintura
for x in (-0.12, -0.04, 0.04, 0.12):                                    # bolsos de carregador
    m.cx(x - 0.03, -0.085, 0.06, x + 0.03, -0.06, 0.15, "oliva_escuro")
m.cx(-0.24, -0.05, 0.12, -0.22, 0.05, 0.4, "velcro")                    # laterais
m.cx(0.22, -0.05, 0.12, 0.24, 0.05, 0.4, "velcro")
m.fim()

# ---- granada de fragmentação
m = Mod("granada")
m.esfera(0, 0, 0.06, 0.042, "granada", 1.0, 1.0, 1.25)
m.cx(-0.018, -0.018, 0.115, 0.018, 0.018, 0.14, "metal")                # tampa do detonador
m.cx(-0.004, -0.03, 0.135, 0.004, 0.03, 0.146, "pino")                  # anel do pino
m.cx(0.02, -0.008, 0.06, 0.03, 0.008, 0.145, "metal_escuro")            # alavanca (colher)
m.fim()
