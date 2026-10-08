# Folha de miniaturas de todos os FBX de uma pasta, aplicando uma textura de paleta. Imprime faces e dimensões.
# Uso: blender -b -P tools/folha_fbx_dir.py -- pasta paleta.png saida.png
import bpy, sys, os, math, glob
from mathutils import Vector as V
a = sys.argv[sys.argv.index("--") + 1:]
pasta, pal, out = a
bpy.ops.wm.read_factory_settings(use_empty=True)
img = bpy.data.images.load(pal) if os.path.exists(pal) else None
arqs = sorted(glob.glob(os.path.join(pasta, "**", "*.fbx"), recursive=True) + glob.glob(os.path.join(pasta, "*.glb")))
cols = 8
for i, f in enumerate(arqs):
    antes = set(bpy.data.objects)
    (bpy.ops.import_scene.gltf if f.endswith(".glb") else bpy.ops.import_scene.fbx)(filepath=f)
    novos = [o for o in bpy.data.objects if o not in antes]
    meshes = [o for o in novos if o.type == "MESH"]
    lo = V((1e9,) * 3); hi = V((-1e9,) * 3); faces = 0
    for o in meshes:
        faces += len(o.data.polygons)
        for c in o.bound_box:
            w = o.matrix_world @ V(c); lo = V(map(min, lo, w)); hi = V(map(max, hi, w))
        for m in (o.data.materials if img else []):
            if m and m.use_nodes:
                nt = m.node_tree
                bs = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
                t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; t.interpolation = "Closest"
                if bs: nt.links.new(t.outputs["Color"], bs.inputs["Base Color"])
    d = hi - lo
    print("FBX %-36s faces=%5d dim=(%.2f %.2f %.2f)" % (os.path.basename(f)[:-4], faces, d.x, d.y, d.z))
    s = max(d) or 1
    raiz = bpy.data.objects.new("r%d" % i, None); bpy.context.scene.collection.objects.link(raiz)
    for o in novos:
        if o.parent is None:
            o.parent = raiz
    raiz.scale = (8 / s,) * 3
    raiz.location = V(((i % cols) * 10.0, -(i // cols) * 10.0, 0)) - (lo + hi) / 2 * (8 / s)
rows = (len(arqs) + cols - 1) // cols
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); bpy.context.scene.collection.objects.link(cam)
cam.data.type = "ORTHO"; cam.data.ortho_scale = cols * 10.5
cam.location = V(((cols - 1) * 5.0, -(rows - 1) * 5.0 - 60, 45)); cam.rotation_euler = (math.radians(58), 0, 0)
bpy.context.scene.camera = cam
r = bpy.context.scene.render; r.engine = "BLENDER_WORKBENCH"; r.resolution_x = 1600; r.resolution_y = int(1600 * rows / cols * 1.0) + 100
bpy.context.scene.display.shading.color_type = "TEXTURE"; bpy.context.scene.display.shading.light = "STUDIO"
r.filepath = out
bpy.ops.render.render(write_still=True)
