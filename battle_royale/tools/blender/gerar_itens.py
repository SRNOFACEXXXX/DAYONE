"""Itens de sobrevivência low poly (cores chapadas, estilo do DAYONE), gerados por script e exportados em GLB.
Roda com Blender 4.5/5.x (`blender -b --factory-startup -P tools/blender/gerar_itens.py -- <saida>`) ou com o módulo
`bpy` do PyPI (`python tools/blender/gerar_itens.py <saida>`). Saída padrão: game/assets/models/itens/<id>.glb
Escala em metros, pivô no chão/centro, frente = -Y do Blender (vira +Z/-Z conforme o exportador glTF, Y-up)."""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "models", "itens")
os.makedirs(OUT, exist_ok=True)

PAL = {
    "madeira": (0.45, 0.28, 0.14), "madeira_clara": (0.72, 0.55, 0.33), "casca": (0.33, 0.22, 0.13), "miolo": (0.86, 0.72, 0.48),
    "aco": (0.62, 0.64, 0.67), "aco_escuro": (0.25, 0.26, 0.28), "verde_mil": (0.25, 0.32, 0.18), "vermelho": (0.62, 0.12, 0.10),
    "lata": (0.70, 0.71, 0.70), "rotulo": (0.80, 0.55, 0.12), "agua": (0.35, 0.62, 0.85), "plastico": (0.22, 0.45, 0.78),
    "carne": (0.72, 0.22, 0.22), "gordura": (0.92, 0.85, 0.75), "assada": (0.45, 0.24, 0.10), "pele": (0.55, 0.40, 0.26),
    "corda": (0.78, 0.68, 0.45), "pedra": (0.48, 0.48, 0.46), "papel": (0.92, 0.88, 0.78), "fosforo": (0.85, 0.20, 0.12),
    "cinza": (0.18, 0.17, 0.16), "brasa": (0.95, 0.40, 0.08), "pena": (0.92, 0.92, 0.90), "couro": (0.40, 0.25, 0.14),
}
_mats = {}


def mat(nome):
    if nome not in _mats:
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        c = PAL[nome]
        bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85
        if nome in ("aco", "aco_escuro", "lata"):
            bsdf.inputs["Metallic"].default_value = 0.6
            bsdf.inputs["Roughness"].default_value = 0.45
        if nome == "brasa":
            bsdf.inputs["Emission Color"].default_value = (1.0, 0.45, 0.1, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 3.0
        _mats[nome] = m
    return _mats[nome]


def limpar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def _obj(bm, nome, material):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat(material))
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def caixa(tam, pos=(0, 0, 0), rot=(0, 0, 0), material="madeira", nome="caixa"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(tam), verts=bm.verts)
    o = _obj(bm, nome, material)
    o.location = pos
    o.rotation_euler = [math.radians(a) for a in rot]
    return o


def cilindro(raio, alt, pos=(0, 0, 0), rot=(0, 0, 0), material="madeira", lados=8, raio2=None, nome="cil"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=lados, radius1=raio, radius2=raio if raio2 is None else raio2, depth=alt)
    o = _obj(bm, nome, material)
    o.location = pos
    o.rotation_euler = [math.radians(a) for a in rot]
    return o


def esfera(raio, pos=(0, 0, 0), escala=(1, 1, 1), material="pedra", sub=1, nome="esf"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=raio)
    o = _obj(bm, nome, material)
    o.location = pos
    o.scale = escala
    return o


def prisma(pts2d, esp, pos=(0, 0, 0), rot=(0, 0, 0), material="aco", nome="prisma"):
    """Extrusão de um polígono 2D (x, z) com espessura `esp` em Y."""
    bm = bmesh.new()
    vs_a = [bm.verts.new((x, -esp / 2, z)) for x, z in pts2d]
    vs_b = [bm.verts.new((x, esp / 2, z)) for x, z in pts2d]
    bm.faces.new(vs_a[::-1])
    bm.faces.new(vs_b)
    n = len(pts2d)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vs_a[i], vs_a[j], vs_b[j], vs_b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _obj(bm, nome, material)
    o.location = pos
    o.rotation_euler = [math.radians(a) for a in rot]
    return o


def exportar(id_):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = id_
    # pivô: centro em XY, base no chão
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    desl = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    o.data.transform(Matrix.Translation(-desl))
    o.location = (0, 0, 0)
    caminho = os.path.join(OUT, id_ + ".glb")
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="EXPORT")
    print("ITEM", id_, "%.2f x %.2f x %.2f m" % tuple(mx - mn), "tris", sum(len(p.vertices) - 2 for p in o.data.polygons))


ITENS = {}


def item(f):
    ITENS[f.__name__] = f
    return f


# ---------------- ferramentas ----------------
@item
def machado():
    cilindro(0.018, 0.62, (0, 0, 0.31), material="madeira", lados=6)
    prisma([(0.0, 0.0), (0.13, -0.03), (0.15, 0.06), (0.13, 0.13), (0.0, 0.10)], 0.025, (0.012, 0, 0.50), material="aco")
    caixa((0.035, 0.035, 0.06), (0, 0, 0.555), material="aco_escuro")


@item
def picareta():
    cilindro(0.018, 0.68, (0, 0, 0.34), material="madeira", lados=6)
    prisma([(-0.24, -0.02), (-0.05, 0.02), (0.05, 0.02), (0.24, -0.02), (0.05, 0.045), (-0.05, 0.045)], 0.03, (0, 0, 0.62), material="aco_escuro")


@item
def faca():
    caixa((0.025, 0.02, 0.11), (0, 0, 0.055), material="couro")
    caixa((0.05, 0.022, 0.012), (0, 0, 0.115), material="aco_escuro")
    prisma([(-0.012, 0.0), (0.014, 0.0), (0.012, 0.12), (-0.004, 0.17), (-0.012, 0.12)], 0.004, (0, 0, 0.121), material="aco")


@item
def martelo():
    cilindro(0.016, 0.33, (0, 0, 0.165), material="madeira", lados=6)
    caixa((0.12, 0.03, 0.035), (0.01, 0, 0.33), material="aco_escuro")


@item
def serrote():
    caixa((0.035, 0.03, 0.12), (0, 0, 0.06), material="madeira")
    prisma([(0, 0), (0.42, 0.02), (0.42, 0.06), (0, 0.11)], 0.003, (0.02, 0, 0.0), material="aco")


@item
def arco():
    seg = 9
    for i in range(seg):
        a0 = math.radians(-60 + 120 * i / seg)
        a1 = math.radians(-60 + 120 * (i + 1) / seg)
        x0, z0 = 0.55 * math.cos(a0) - 0.55, 0.55 * math.sin(a0)
        x1, z1 = 0.55 * math.cos(a1) - 0.55, 0.55 * math.sin(a1)
        meio = ((x0 + x1) / 2, 0, (z0 + z1) / 2 + 0.5)
        comp = math.hypot(x1 - x0, z1 - z0)
        ang = math.degrees(math.atan2(z1 - z0, x1 - x0))
        caixa((comp + 0.01, 0.022, 0.03), meio, (0, -ang, 0), material="madeira" if 3 <= i <= 5 else "madeira_clara")
    cilindro(0.003, 0.95, (0.55 * math.cos(math.radians(60)) - 0.55, 0, 0.5), material="corda", lados=4)


@item
def flecha():
    cilindro(0.006, 0.7, (0, 0, 0.35), material="madeira_clara", lados=5)
    cilindro(0.016, 0.05, (0, 0, 0.72), material="aco_escuro", lados=4, raio2=0.0)
    for i in range(3):
        a = math.radians(120 * i)
        caixa((0.002, 0.03, 0.08), (0.012 * math.cos(a), 0.012 * math.sin(a), 0.05), (0, 0, math.degrees(a)), material="pena")


@item
def galao():   # jerrycan 20 L
    caixa((0.34, 0.16, 0.46), (0, 0, 0.23), material="verde_mil")
    caixa((0.36, 0.17, 0.02), (0, 0, 0.14), material="verde_mil")
    caixa((0.36, 0.17, 0.02), (0, 0, 0.32), material="verde_mil")
    for dx in (-0.09, 0.0, 0.09):
        caixa((0.03, 0.05, 0.05), (dx, 0, 0.485), material="verde_mil")
    caixa((0.2, 0.05, 0.015), (0, 0, 0.51), material="verde_mil")
    cilindro(0.025, 0.06, (0.12, 0, 0.49), (0, -25, 0), material="aco_escuro", lados=8)


@item
def fogueira():   # pedras em anel + lenha cruzada + brasa
    for i in range(9):
        a = math.tau * i / 9
        esfera(0.09, (0.32 * math.cos(a), 0.32 * math.sin(a), 0.05), (1.2, 1.0, 0.7), material="pedra")
    for i in range(5):
        a = math.tau * i / 5 + 0.3
        cilindro(0.035, 0.42, (0.06 * math.cos(a), 0.06 * math.sin(a), 0.12), (65, 0, math.degrees(a) + 90), material="casca", lados=6)
    esfera(0.12, (0, 0, 0.02), (1.2, 1.2, 0.3), material="cinza")
    esfera(0.08, (0, 0, 0.06), (1.0, 1.0, 0.5), material="brasa")


@item
def kit_fogueira():   # gravetos amarrados (vira fogueira montada)
    for i in range(7):
        a = math.tau * i / 7
        cilindro(0.012, 0.45, (0.03 * math.cos(a), 0.03 * math.sin(a), 0.03), (0, 90, math.degrees(a) * 0.15), material="casca", lados=5)
    cilindro(0.04, 0.02, (0.0, 0.0, 0.03), (0, 90, 0), material="corda", lados=8)


# ---------------- materiais ----------------
@item
def tora():
    cilindro(0.13, 1.0, (0, 0, 0.13), (0, 90, 0), material="casca", lados=8)
    cilindro(0.115, 1.004, (0, 0, 0.13), (0, 90, 0), material="miolo", lados=8)


@item
def tabua():
    caixa((1.0, 0.16, 0.025), (0, 0, 0.0125), material="madeira_clara")


@item
def graveto():
    cilindro(0.012, 0.45, (0, 0, 0.012), (0, 90, 0), material="casca", lados=5)
    cilindro(0.007, 0.12, (0.08, 0.04, 0.012), (0, 90, 35), material="casca", lados=4)


@item
def pregos():   # caixinha de pregos
    caixa((0.10, 0.06, 0.04), (0, 0, 0.02), material="papel")
    caixa((0.101, 0.061, 0.012), (0, 0, 0.034), material="vermelho")


@item
def fosforos():
    caixa((0.055, 0.035, 0.015), (0, 0, 0.0075), material="papel")
    caixa((0.056, 0.036, 0.004), (0, 0, 0.014), material="fosforo")


@item
def corda():
    for i in range(6):
        a = math.tau * i / 6
        cilindro(0.075, 0.012, (0, 0, 0.006 + 0.012 * i), material="corda", lados=10, raio2=0.07)
    cilindro(0.045, 0.08, (0, 0, 0.04), material="couro", lados=8)


@item
def pedra_item():
    esfera(0.08, (0, 0, 0.05), (1.2, 1.0, 0.7), material="pedra")


# ---------------- comida e bebida ----------------
@item
def lata_comida():
    cilindro(0.04, 0.1, (0, 0, 0.05), material="lata", lados=10)
    cilindro(0.0405, 0.06, (0, 0, 0.05), material="rotulo", lados=10)


@item
def garrafa_agua():
    cilindro(0.04, 0.2, (0, 0, 0.1), material="agua", lados=10)
    cilindro(0.04, 0.05, (0, 0, 0.225), material="agua", lados=10, raio2=0.015)
    cilindro(0.016, 0.025, (0, 0, 0.26), material="plastico", lados=8)


@item
def cantil():
    cilindro(0.08, 0.05, (0, 0, 0.08), (90, 0, 0), material="verde_mil", lados=12)
    cilindro(0.015, 0.03, (0, 0, 0.17), material="aco_escuro", lados=8)


@item
def carne_crua():
    esfera(0.08, (0, 0, 0.03), (1.3, 0.9, 0.4), material="carne")
    esfera(0.05, (0.06, 0.02, 0.04), (1.0, 0.8, 0.3), material="gordura")


@item
def carne_cozida():
    esfera(0.08, (0, 0, 0.03), (1.3, 0.9, 0.4), material="assada")


@item
def pele():
    prisma([(-0.35, -0.25), (0.0, -0.32), (0.35, -0.25), (0.42, 0.0), (0.35, 0.25), (0.0, 0.3), (-0.35, 0.25), (-0.45, 0.0)],
           0.01, (0, 0, 0.005), (90, 0, 0), material="pele")


@item
def osso():
    cilindro(0.012, 0.18, (0, 0, 0.012), (0, 90, 0), material="gordura", lados=6)
    for dx in (-0.09, 0.09):
        esfera(0.022, (dx, 0, 0.018), (1, 1.4, 1), material="gordura")


@item
def frutas():   # maçãs/frutas silvestres
    for i, (x, y) in enumerate([(0, 0), (0.06, 0.02), (0.03, 0.06)]):
        esfera(0.035, (x, y, 0.035), material="vermelho")


@item
def bateria_carro():
    caixa((0.25, 0.17, 0.18), (0, 0, 0.09), material="aco_escuro")
    for dx, m in ((-0.08, "vermelho"), (0.08, "aco")):
        cilindro(0.015, 0.025, (dx, 0, 0.19), material=m, lados=8)


@item
def roda_carro():
    cilindro(0.32, 0.2, (0, 0, 0.32), (90, 0, 0), material="aco_escuro", lados=14)
    cilindro(0.18, 0.205, (0, 0, 0.32), (90, 0, 0), material="aco", lados=10)


@item
def kit_reparo():
    caixa((0.30, 0.15, 0.12), (0, 0, 0.06), material="vermelho")
    caixa((0.10, 0.03, 0.02), (0, 0, 0.13), material="aco_escuro")


so = set(args[1:]) if len(args) > 1 else None
for nome, f in ITENS.items():
    if so and nome not in so:
        continue
    limpar()
    f()
    exportar(nome)
print("ITENS_OK", len(ITENS))
