import bpy
import sys

paths = sys.argv[sys.argv.index("--") + 1:]
for path in paths:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.armatures, bpy.data.meshes):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    print("RIG", path)
    for arm in arms:
        print(" ARMATURE", arm.name, "bones", len(arm.data.bones))
        print("  ", " | ".join(b.name for b in arm.data.bones))
        if arm.animation_data:
            print(" ACTION", arm.animation_data.action.name if arm.animation_data.action else "-")
    print(" ACTIONS", " | ".join(a.name for a in bpy.data.actions))
