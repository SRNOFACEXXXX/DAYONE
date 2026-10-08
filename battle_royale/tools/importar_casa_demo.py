# Casa completa do pacote de interiores (House_Demo*: paredes de madeira, telhado de ardósia, janelas com venezianas, porta,
# piso, cozinha e móveis embutidos) -> game/assets/models/cenario/casas/casa_demo.glb. Origem no centro da pegada, no piso;
# frente (porta) para -Z do Godot. Cada peça mantém o seu material do pacote (texturas ≤ 512 px).
# A colisão é fiel (trimesh por peça no jogo: paredes/piso/telhado sólidos, portas e janelas abertas do modelo).
# Uso: blender -b --factory-startup -P tools/importar_casa_demo.py
import bpy, os, math
from mathutils import Vector as V, Matrix
RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GLTF = os.path.join(RAIZ, "Assets", "_ext", "_MODELO_DE_CASAS_COM_INTERIORES_objects_interiorvillage_alpha_gltf", "scene.gltf")
OUT = os.path.join(RAIZ, "game", "assets", "models", "cenario", "casas")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLTF)


def anc(o):
    while o:
        yield o
        o = o.parent


casa = [o for o in bpy.data.objects if o.type == "MESH" and any(p.name.startswith("House_Demo") for p in anc(o))]
resto = [o for o in bpy.data.objects if o not in casa]
for o in resto:
    bpy.data.objects.remove(o)
lo = V((1e9,) * 3); hi = V((-1e9,) * 3)
for o in casa:
    for c in o.bound_box:
        w = o.matrix_world @ V(c); lo = V(map(min, lo, w)); hi = V(map(max, hi, w))
print("CASA bbox", tuple(round(x, 2) for x in lo), tuple(round(x, 2) for x in hi))
# piso da casa = face de cima da laje de concreto: usa o mínimo z do conjunto + 0,0; centraliza em XY
ctr = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z + 0.40))   # piso do modelo (0,48 m) fica a 8 cm do chão
raiz = bpy.data.objects.new("casa_demo", None)
bpy.context.scene.collection.objects.link(raiz)
for o in casa:
    mw = o.matrix_world.copy()
    o.parent = raiz
    o.matrix_world = Matrix.Translation(-ctr) @ mw
bpy.context.view_layer.update()
for o in casa:
    for m in o.data.materials:
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and max(n.image.size) > 512:
                    n.image.scale(512, 512)
                if n.type == "BSDF_PRINCIPLED":
                    n.inputs["Metallic"].default_value = 0.0
                    n.inputs["Roughness"].default_value = 0.9
# aplica as transformações nas malhas (cada peça independente, sem hierarquia de empties do gltf)
for o in casa:
    mw = o.matrix_world.copy()
    o.parent = None
    o.data = o.data.copy()
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)
for o in list(bpy.data.objects):
    if o.type == "EMPTY":
        bpy.data.objects.remove(o)
# porta da frente (House_Demo_039_Door_0): sai num .glb próprio com a ORIGEM NA DOBRADIÇA (aresta esquerda vista de fora, no piso),
# para o jogo animar a abertura; a casa exportada fica sem folha de porta (vão livre na colisão e na malha)
porta = next((o for o in casa if "039_Door" in o.name), None)
if porta:
    pl = V((1e9,) * 3); ph = V((-1e9,) * 3)
    for vv in porta.data.vertices:
        w = porta.matrix_world @ vv.co; pl = V(map(min, pl, w)); ph = V(map(max, ph, w))
    print("PORTA objeto", porta.name, "mw", [round(x, 2) for x in porta.matrix_world.translation], "verts", len(porta.data.vertices))
    pivo = V((pl.x, (pl.y + ph.y) / 2, pl.z))
    print("PORTA bbox", tuple(round(x, 2) for x in pl), tuple(round(x, 2) for x in ph), "pivô", tuple(round(x, 2) for x in pivo))
    porta.data.transform(Matrix.Translation(-pivo))
    porta.location = V((0, 0, 0))
    bpy.ops.object.select_all(action="DESELECT")
    porta.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "casa_demo_porta.glb"), use_selection=True, export_format="GLB", export_yup=True)
    open(os.path.join(OUT, "porta_pivo.txt"), "w").write("%.4f %.4f %.4f %.4f %.4f %.4f" % (pivo.x, pivo.y, pivo.z, ph.x - pl.x, ph.y - pl.y, ph.z - pl.z))
    bpy.data.objects.remove(porta)
    casa.remove(porta)
# a laje de concreto (House_Demo_040_Concrete_0) é o piso: sobe a casa para que o topo do piso fique em y = 0.17 -> origem no piso
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "casa_demo.glb"), use_selection=True, export_format="GLB", export_yup=True)
print("CASA exportada pecas=%d" % len(casa))
