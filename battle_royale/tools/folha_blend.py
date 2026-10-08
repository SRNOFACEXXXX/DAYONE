# Folha de miniaturas de todos os objetos MESH de um .blend/.fbx (grade, vista 3/4) + contagem de faces/materiais.
# Uso: blender -b -P tools/folha_blend.py -- arquivo saida.png
import bpy, sys, os, math
from mathutils import Vector as V
a = sys.argv[sys.argv.index("--") + 1:]
src, out = a[0], a[1]
if src.lower().endswith(".blend"):
    bpy.ops.wm.open_mainfile(filepath=src)
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
cols = 5
x = 0.0
for i, o in enumerate(obs):
    tex = set()
    for m in o.data.materials:
        if m and m.use_nodes:
            tex |= {n.image.name for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}
    print("OBJ %-18s faces=%6d mats=%d tex=%s dim=(%.1f %.1f %.1f)" % (o.name, len(o.data.polygons), len(o.data.materials), sorted(tex), *o.dimensions))
    o.parent = None
    o.rotation_euler = (0, 0, 0)
    s = max(o.dimensions)
    o.location = V(((i % cols) * 12.0, -(i // cols) * 12.0, 0))
    o.scale = o.scale * (10.0 / s if s > 0 else 1)
for o in list(bpy.data.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
rows = (len(obs) + cols - 1) // cols
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); bpy.context.scene.collection.objects.link(cam)
cam.data.type = "ORTHO"; cam.data.ortho_scale = max(cols, rows) * 12.5
cam.location = V(((cols - 1) * 6.0 - 20, -(rows - 1) * 6.0 - 20, 40)); cam.rotation_euler = (math.radians(55), 0, math.radians(-45))
bpy.context.scene.camera = cam
r = bpy.context.scene.render; r.engine = "BLENDER_WORKBENCH"; r.resolution_x = 1400; r.resolution_y = 1000
bpy.context.scene.display.shading.color_type = "TEXTURE"; bpy.context.scene.display.shading.light = "STUDIO"
r.filepath = out
bpy.ops.render.render(write_still=True)
