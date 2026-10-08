# Coberturas de campo aberto, modeladas à mão (geometria explícita) -> game/assets/models/cobertura/<tipo>.glb
# Tipos do design (ilha_layout.json: cobertura_campo_aberto). Uso: blender -b --factory-startup -P tools/build_coberturas.py
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "cobertura")
os.makedirs(OUT, exist_ok=True)
V = Vector
COR = {
    "granito": (0.52, 0.49, 0.44), "granito_escuro": (0.37, 0.35, 0.32), "liquen": (0.45, 0.47, 0.30),
    "cupim": (0.62, 0.42, 0.27), "cupim_escuro": (0.48, 0.32, 0.20), "concreto": (0.66, 0.64, 0.60), "reboco_mureta": (0.81, 0.776, 0.706), "concreto_sujo": (0.52, 0.50, 0.46),
    "pedra_seca": (0.50, 0.46, 0.40), "madeira": (0.40, 0.30, 0.20), "madeira_clara": (0.58, 0.47, 0.33), "cerne": (0.66, 0.52, 0.36),
    "saco": (0.64, 0.57, 0.42), "saco_escuro": (0.52, 0.46, 0.33), "feno": (0.78, 0.66, 0.36), "feno_escuro": (0.62, 0.52, 0.28),
    "tambor_azul": (0.16, 0.28, 0.48), "tambor_verm": (0.55, 0.16, 0.12), "ferrugem": (0.45, 0.25, 0.14), "pneu": (0.10, 0.10, 0.10),
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
    bs.inputs["Roughness"].default_value = 0.9
    return m


class Mod:
    def __init__(self, nome):
        self.nome, self.bm, self.mats = nome, bmesh.new(), []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _add(self, tmp, M, m):
        mi = self._mi(m)
        mp = {v: self.bm.verts.new(M @ v.co) for v in tmp.verts}
        for f in tmp.faces:
            self.bm.faces.new([mp[v] for v in f.verts]).material_index = mi
        tmp.free()

    def caixa(self, c, s, m, rz=0.0, rx=0.0, ry=0.0, chanfro=0.0):
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        if chanfro > 0:
            bmesh.ops.bevel(t, geom=list(t.edges), offset=chanfro, segments=1, affect="EDGES")
        M = Matrix.Translation(c) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Diagonal((*s, 1))
        self._add(t, M, m)

    def blob(self, c, s, m, rz=0.0, amassa=None, sub=1):
        t = bmesh.new()
        bmesh.ops.create_icosphere(t, subdivisions=sub, radius=1.0)
        if amassa:
            t.verts.ensure_lookup_table()
            for i, f in amassa.items():
                t.verts[i].co *= f
        self._add(t, Matrix.Translation(c) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Diagonal((*s, 1)), m)

    def cil(self, c, r, h, m, lados=8, eixo="Z", rz=0.0, r2=None):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False, segments=lados, radius1=r, radius2=r if r2 is None else r2, depth=h)
        R = Matrix.Identity(4)
        if eixo == "X":
            R = Matrix.Rotation(math.pi / 2, 4, "Y")
        elif eixo == "Y":
            R = Matrix.Rotation(math.pi / 2, 4, "X")
        self._add(t, Matrix.Translation(c) @ Matrix.Rotation(rz, 4, "Z") @ R, m)

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


def novo(nome):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return Mod(nome)


def exportar(nome):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + ".glb"), use_selection=True, export_format="GLB", export_yup=True, export_apply=True)
    print("COB", nome, sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH"))


# matacão de granito (~2,6 m): três blocos arredondados apoiados, líquen no topo
m = novo("matacao")
m.blob(V((0, 0, 1.1)), (1.9, 1.5, 1.3), "granito", 0.3, {0: 0.85, 2: 1.1, 5: 0.9, 8: 1.12, 10: 0.88}, sub=1)
m.blob(V((1.3, 0.6, 0.6)), (1.0, 0.9, 0.75), "granito_escuro", 1.1, {1: 0.9, 6: 1.1})
m.blob(V((-1.2, -0.5, 0.5)), (0.9, 0.8, 0.6), "granito", 2.0, {3: 1.15, 9: 0.85})
m.blob(V((0.1, 0.05, 2.02)), (0.95, 0.75, 0.3), "liquen", 0.5)   # embutido no topo (antes flutuava)
m.fim(); exportar("matacao")

# cupinzeiro (1,2 m): monte cônico de terra com lóbulos
m = novo("cupinzeiro")
m.cil(V((0, 0, 0.45)), 0.75, 0.9, "cupim", lados=9, r2=0.35)
m.blob(V((0.05, 0.02, 1.0)), (0.36, 0.34, 0.35), "cupim", 0.4)
m.blob(V((0.35, 0.2, 0.55)), (0.38, 0.32, 0.45), "cupim_escuro", 1.0)
m.blob(V((-0.3, -0.25, 0.45)), (0.35, 0.33, 0.38), "cupim_escuro", 2.1)
m.fim(); exportar("cupinzeiro")

# mureta de concreto (4 m x 1,1 m)
m = novo("mureta_concreto")
m.caixa(V((0, 0, 0.55)), (4.0, 0.22, 1.1), "reboco_mureta", chanfro=0.02)   # #CFC6B4 (crítica 05)
m.caixa(V((0, 0, 0.06)), (4.1, 0.4, 0.12), "concreto_sujo")
for x in (-1.4, 0.3, 1.6):                                   # quebras e manchas na borda
    m.caixa(V((x, 0.0, 1.08)), (0.35, 0.24, 0.12), "concreto_sujo", ry=0.2)
m.fim(); exportar("mureta_concreto")

# muro de pedra seca (10 m x 1 m): pedras empilhadas à mão em duas fiadas
m = novo("muro_pedra_seca_10m")
x = -4.8
larguras = [0.9, 0.7, 1.1, 0.8, 0.95, 0.75, 1.0, 0.85, 0.7, 1.05, 0.8]
for i, w in enumerate(larguras):
    m.blob(V((x + w / 2, (i % 3 - 1) * 0.06, 0.28)), (w * 0.55, 0.45, 0.3), "pedra_seca" if i % 2 else "granito_escuro", i * 0.7)
    x += w * 0.92
x = -4.4
for i, w in enumerate([0.8, 1.0, 0.7, 0.9, 1.1, 0.75, 0.85, 0.9, 0.95]):
    m.blob(V((x + w / 2, 0.02 * (i % 2), 0.72)), (w * 0.52, 0.38, 0.24), "granito" if i % 2 else "pedra_seca", 0.4 + i)
    x += w * 0.95
m.fim(); exportar("muro_pedra_seca_10m")

# tronco caído (6 m, 0,8 m de diâmetro) com toco de galho
m = novo("tronco_caido")
m.cil(V((0, 0, 0.4)), 0.42, 6.0, "madeira", lados=8, eixo="X", r2=0.34)
m.cil(V((3.02, 0, 0.4)), 0.36, 0.05, "cerne", lados=8, eixo="X")
m.cil(V((-3.02, 0, 0.4)), 0.42, 0.05, "cerne", lados=8, eixo="X")
m.cil(V((0.8, 0.45, 0.7)), 0.1, 1.1, "madeira_clara", lados=5, eixo="Y", r2=0.05)
m.fim(); exportar("tronco_caido")

# sacos de areia (barricada em U, 1,1 m)
m = novo("sacos_areia")
for fiada, z in enumerate((0.13, 0.38, 0.63, 0.88)):
    off = 0.0 if fiada % 2 == 0 else 0.3
    for i in range(6):
        x = -1.5 + off + i * 0.6
        if x > 1.6:
            continue
        m.blob(V((x, 0, z)), (0.31, 0.2, 0.13), "saco" if (i + fiada) % 2 else "saco_escuro", 0.05 * (i - 2))
    for y in (0.45, 0.9):
        m.blob(V((-1.75, y, z)), (0.2, 0.31, 0.13), "saco_escuro", 0.0)
        m.blob(V((1.75, y, z)), (0.2, 0.31, 0.13), "saco", 0.0)
m.fim(); exportar("sacos_areia")

# fardos de feno x3 (redondos, 1,4 m)
m = novo("fardo_feno_x3")
for c, rz in ((V((0, 0, 0.7)), 0.0), (V((1.5, 0.3, 0.7)), 0.3), (V((0.75, 0.15, 1.9)), 0.15)):
    m.cil(c, 0.72, 1.3, "feno", lados=10, eixo="Y", rz=rz)
    m.cil(c, 0.55, 1.32, "feno_escuro", lados=10, eixo="Y", rz=rz)
m.fim(); exportar("fardo_feno_x3")

# tambores x4 (200 L)
m = novo("tambor_x4")
for c, cor in ((V((0, 0, 0.45)), "tambor_azul"), (V((0.62, 0.05, 0.45)), "tambor_verm"), (V((0.3, 0.55, 0.45)), "tambor_azul")):
    m.cil(c, 0.29, 0.9, cor, lados=10)
    m.cil(c + V((0, 0, 0.2)), 0.3, 0.04, "ferrugem", lados=10)
m.cil(V((-0.7, 0.3, 0.29)), 0.29, 0.9, "ferrugem", lados=10, eixo="X", rz=0.4)     # um caído
m.fim(); exportar("tambor_x4")

# pilha de pneus (4 pneus + 1 encostado)
m = novo("pilha_pneus")
for i, z in enumerate((0.12, 0.36, 0.60, 0.84)):
    m.cil(V((0.02 * i, 0, z)), 0.42, 0.24, "pneu", lados=10)
m.cil(V((0.75, 0.2, 0.42)), 0.42, 0.24, "pneu", lados=10, eixo="Y", rz=0.6)
m.fim(); exportar("pilha_pneus")

# cocho de gado (madeira, 3 m)
m = novo("cocho")
m.caixa(V((0, 0, 0.35)), (3.0, 0.08, 0.5), "madeira", chanfro=0.01)
m.caixa(V((0, 0.55, 0.35)), (3.0, 0.08, 0.5), "madeira")
m.caixa(V((0, 0.275, 0.12)), (3.0, 0.6, 0.06), "madeira_clara")
for x in (-1.45, 1.45):
    m.caixa(V((x, 0.275, 0.35)), (0.08, 0.63, 0.5), "madeira")
    for y in (0.0, 0.55):
        m.caixa(V((x, y, 0.1)), (0.12, 0.12, 0.2), "madeira")
m.fim(); exportar("cocho")
print("COB_DONE")
