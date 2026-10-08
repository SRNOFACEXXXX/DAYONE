# Inspeciona FBX/GLB/BLEND: objetos, dimensões, materiais e texturas. Uso: blender -b -P inspect_fbx.py -- arq1 arq2 ...
import bpy, sys, os
args = sys.argv[sys.argv.index("--") + 1:]
for a in args:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = a.lower().rsplit(".", 1)[-1]
    if ext == "fbx":
        bpy.ops.import_scene.fbx(filepath=a)
    elif ext in ("glb", "gltf"):
        bpy.ops.import_scene.gltf(filepath=a)
    elif ext == "blend":
        bpy.ops.wm.open_mainfile(filepath=a)
    print("#####", os.path.basename(a))
    for o in bpy.data.objects:
        if o.type == "MESH":
            mats = [m.name for m in o.data.materials if m]
            texs = []
            for m in o.data.materials:
                if m and m.use_nodes:
                    texs += [n.image.name for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
            print("  MESH %-28s dim=(%.3f %.3f %.3f) loc=(%.2f %.2f %.2f) rot=(%.0f %.0f %.0f) faces=%d mats=%s tex=%s parent=%s" % (
                o.name, *o.dimensions, *o.location, *[x * 57.3 for x in o.rotation_euler], len(o.data.polygons), mats, texs, o.parent.name if o.parent else ""))
        elif o.type in ("ARMATURE", "EMPTY"):
            print("  %s %s children=%d" % (o.type, o.name, len(o.children)))
