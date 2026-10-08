# Miniatura lateral (câmera em -Y olhando +Y, Z para cima) de cada FBX. Uso: blender -b -P thumb_fbx.py -- saida_dir textura_fallback arq...
import bpy, sys, os, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
out, tex, arqs = a[0], a[1], a[2:]
os.makedirs(out, exist_ok=True)
for f in arqs:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=f)
    img = bpy.data.images.load(tex) if os.path.exists(tex) else None
    for m in bpy.data.materials:
        if m.use_nodes and img:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and (n.image is None or not n.image.has_data):
                    n.image = img
    obs = [o for o in bpy.data.objects if o.type == "MESH"]
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in obs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    ctr = (lo + hi) / 2; size = max(hi - lo)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = size * 1.1
    cam.location = ctr + Vector((0, -3 * size, 0)); cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), 0, math.radians(20))
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.color = (0.6, 0.65, 0.7)
    r = bpy.context.scene.render; r.engine = "BLENDER_WORKBENCH"; r.resolution_x = 640; r.resolution_y = 320
    bpy.context.scene.display.shading.color_type = "TEXTURE"; bpy.context.scene.display.shading.light = "STUDIO"
    r.filepath = os.path.join(out, os.path.basename(f).rsplit(".", 1)[0] + ".png")
    bpy.ops.render.render(write_still=True)
    print("THUMB", r.filepath, "lo", tuple(round(x, 3) for x in lo), "hi", tuple(round(x, 3) for x in hi))
