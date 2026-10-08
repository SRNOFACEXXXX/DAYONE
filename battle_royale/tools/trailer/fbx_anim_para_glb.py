"""Blender CLI: converte FBX do Mixamo (com malha e texturas, 140 MB) em GLB leve só com esqueleto+animação.
blender -b --factory-startup -P tools/trailer/fbx_anim_para_glb.py -- entrada.fbx saida.glb
"""
import bpy, sys
args = sys.argv[sys.argv.index("--") + 1:]
ent, sai = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=ent, use_anim=True, ignore_leaf_bones=True)
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
print("ARMATURES", [(a.name, len(a.pose.bones)) for a in arms])
for a in arms:
    ad = a.animation_data
    if ad and ad.action:
        print("ACTION", ad.action.name, tuple(ad.action.frame_range))
bpy.ops.export_scene.gltf(filepath=sai, export_format="GLB", export_animations=True, export_force_sampling=True,
                          export_skins=True, export_image_format="NONE", export_materials="NONE", export_apply=False)
print("OK", sai)
