# Renderiza a casa do pacote de interiores (House_Demo*) e a cena inteira, de cima e em 3/4, para entender a peça.
import bpy, math, sys
from mathutils import Vector as V
GLTF = r"C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/Assets/_ext/_MODELO_DE_CASAS_COM_INTERIORES_objects_interiorvillage_alpha_gltf/scene.gltf"
OUT = r"C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/Assets/_vistas/"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLTF)
def ancestrais(o):
    while o:
        yield o
        o = o.parent
casa = [o for o in bpy.data.objects if o.type == "MESH" and any(p.name.startswith("House_Demo") for p in ancestrais(o))]
outros = [o for o in bpy.data.objects if o.type == "MESH" and o not in casa]
def caixa(obs):
    lo = V((1e9,) * 3); hi = V((-1e9,) * 3)
    for o in obs:
        for c in o.bound_box:
            w = o.matrix_world @ V(c); lo = V(map(min, lo, w)); hi = V(map(max, hi, w))
    return lo, hi
lo, hi = caixa(casa)
print("CASA pecas=%d dim=%s lo=%s hi=%s faces=%d" % (len(casa), tuple(round(x, 2) for x in hi - lo), tuple(round(x, 2) for x in lo), tuple(round(x, 2) for x in hi), sum(len(o.data.polygons) for o in casa)))
for o in sorted(casa, key=lambda o: o.name)[:60]:
    l2, h2 = caixa([o])
    print("  P %-40s dim=%s" % (o.name[:40], tuple(round(x, 2) for x in h2 - l2)))
lo2, hi2 = caixa(outros)
print("MOVEIS dentro da caixa da casa:", sum(1 for o in outros if all(lo[i] - 0.5 <= (o.matrix_world.translation[i]) <= hi[i] + 0.5 for i in range(3))), "de", len(outros))
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam
r = bpy.context.scene.render; r.engine = "BLENDER_WORKBENCH"; r.resolution_x = 1400; r.resolution_y = 1000
bpy.context.scene.display.shading.color_type = "TEXTURE"; bpy.context.scene.display.shading.light = "STUDIO"
c = (lo + hi) / 2; s = max(hi - lo)
for nome, loc, rot in (("casa_34", c + V((s * 0.9, -s * 0.9, s * 0.7)), (math.radians(60), 0, math.radians(45))),
                       ("casa_topo", c + V((0, 0, s * 2)), (0, 0, 0))):
    cam.location = loc; cam.rotation_euler = rot
    cam.data.type = "ORTHO" if nome == "casa_topo" else "PERSP"; cam.data.ortho_scale = s * 1.1
    r.filepath = OUT + nome + ".png"
    bpy.ops.render.render(write_still=True)
