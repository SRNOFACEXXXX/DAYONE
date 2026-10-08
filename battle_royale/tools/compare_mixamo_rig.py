"""Diagnóstico no destrutivo de compatibilidade entre o rig do jogo e um FBX Mixamo."""
import bpy
import math
import sys
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
if len(args) < 2:
    raise SystemExit("uso: blender -b --python compare_mixamo_rig.py -- personagem.glb animacao.fbx")

for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=args[0])
target = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
bpy.ops.import_scene.fbx(filepath=args[1], automatic_bone_orientation=False)
source = [o for o in bpy.context.scene.objects if o.type == "ARMATURE" and o != target][-1]
print("RIG TARGET", target.name, len(target.data.bones))
print("RIG MIXAMO", source.name, len(source.data.bones))
print("ACTIONS", [(a.name, round(a.frame_range[0]), round(a.frame_range[1])) for a in bpy.data.actions])
matched = 0
for tb in target.data.bones:
    sb = source.data.bones.get("mixamorig:" + tb.name)
    if not sb:
        continue
    matched += 1
    tm = tb.matrix_local if not tb.parent else tb.parent.matrix_local.inverted() @ tb.matrix_local
    sm = sb.matrix_local if not sb.parent else sb.parent.matrix_local.inverted() @ sb.matrix_local
    tq, sq = tm.to_quaternion(), sm.to_quaternion()
    dot = abs(tq.dot(sq))
    print("MATCH", tb.name, "len", round(tb.length, 3), round(sb.length, 3), "rest_delta_deg", round(math.degrees(2 * math.acos(min(dot, 1.0))), 1))
print("MATCHED", matched)
