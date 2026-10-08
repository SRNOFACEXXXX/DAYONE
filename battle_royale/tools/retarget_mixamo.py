"""Recalibra ações Mixamo para o rig low-poly do jogo e exporta um GLB candidato.

Uso:
  blender -b --factory-startup -P tools/retarget_mixamo.py -- alvo.glb saida.glb nome=arquivo.fbx [...]

Só transfere mudanças de orientação por osso para quadril/pernas/pés; mantém a escala,
proporção, materiais, roupa, mãos e poses de arma do personagem original.
"""
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_target(path):
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    return arm


def descendants(root):
    out = [root]
    for child in root.children:
        out.extend(descendants(child))
    return out


def set_action(owner, action):
    ad = owner.animation_data_create()
    ad.action = action
    slots = getattr(action, "slots", None)
    if slots and len(slots):
        slot = next((x for x in slots if getattr(x, "target_id_type", "") == "OBJECT"), slots[0])
        ad.action_slot = slot
    for track in ad.nla_tracks:
        track.mute = True


def retarget_action(target, source, requested_name, export_name):
    action = source.animation_data.action if source.animation_data else None
    if action is None:
        raise RuntimeError("FBX sem ação ativa: " + requested_name)
    source_slot = getattr(source.animation_data, "action_slot", None)
    if source_slot and hasattr(source.animation_data, "action_slot"):
        source.animation_data.action_slot = source_slot
    start, end = map(int, (math.floor(action.frame_range[0]), math.ceil(action.frame_range[1])))
    sc = bpy.context.scene
    sc.render.fps = 30
    sc.frame_start, sc.frame_end = start, end
    target.pose.bones[0].rotation_mode = "QUATERNION"

    # Nome de osso base do esqueleto do jogo -> osso correspondente de Mixamo.
    names = ("Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
             "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase")
    pairs = []
    for name in names:
        tb = target.data.bones.get(name)
        sb = source.data.bones.get("mixamorig:" + name)
        if tb and sb:
            pb = target.pose.bones[name]
            pb.rotation_mode = "QUATERNION"
            pairs.append((tb, pb, sb))
    if len(pairs) < 8:
        raise RuntimeError("Mapeamento incompleto: %d ossos" % len(pairs))

    dst_action = bpy.data.actions.new(export_name)
    set_action(target, dst_action)
    target_world_rot = target.matrix_world.to_3x3().normalized()
    target_world_rot_inv = target_world_rot.inverted()
    source_world_rot = source.matrix_world.to_3x3().normalized()
    original_frame = sc.frame_current

    for frame in range(start, end + 1):
        sc.frame_set(frame)
        bpy.context.view_layer.update()
        source_pose = {sb.name: source.pose.bones[sb.name].matrix.copy() for _tb, _pb, sb in pairs}
        target_pose_by_name = {}
        for tb, pb, sb in pairs:
            sm = source_pose[sb.name]
            sr = sb.matrix_local
            # Rotação relativa à pose de repouso calculada no espaço de mundo, depois
            # convertida para a base do rig do projeto, cujas bone rolls são diferentes.
            delta_world = source_world_rot @ sm.to_3x3().normalized() @ (source_world_rot @ sr.to_3x3().normalized()).inverted()
            rest_world = target.matrix_world.to_3x3() @ tb.matrix_local.to_3x3()
            desired = target_world_rot_inv @ delta_world @ rest_world
            q = desired.to_quaternion().normalized()

            if tb.parent:
                rest_local = tb.parent.matrix_local.inverted() @ tb.matrix_local
                parent_pose = target_pose_by_name.get(tb.parent.name)
                if parent_pose is None:
                    parent_pose = target.pose.bones[tb.parent.name].matrix.copy()
                head = parent_pose @ rest_local.translation
            else:
                head = tb.matrix_local.translation.copy()
            pose_matrix = Matrix.LocRotScale(head, q, Vector((1.0, 1.0, 1.0)))
            pb.matrix = pose_matrix
            target_pose_by_name[tb.name] = pb.matrix.copy()
            pb.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=tb.name)

    sc.frame_set(original_frame)
    bpy.context.view_layer.update()
    print("RETARGET", requested_name, "->", export_name, "frames", start, end, "bones", len(pairs))


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    if len(args) < 3:
        raise SystemExit("uso: alvo.glb saida.glb nome=arquivo.fbx [...]")
    target_path, out_path = args[:2]
    clips = [a.split("=", 1) for a in args[2:]]
    clear_scene()
    target = import_target(target_path)
    original_actions = list(bpy.data.actions)
    # O personagem original mantém todos os seus clipes; suas faixas importadas não
    # devem sobrepor as novas curvas durante o bake.
    ad = target.animation_data_create()
    for tr in ad.nla_tracks:
        tr.mute = True
    ad.action = None
    for export_name, fbx in clips:
        clear_sources = [o for o in bpy.context.scene.objects if o.type == "ARMATURE" and o != target]
        for obj in clear_sources:
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.ops.import_scene.fbx(filepath=os.path.abspath(fbx), automatic_bone_orientation=False)
        source = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE" and o != target)
        src_actions = [a for a in bpy.data.actions if a not in original_actions]
        if source.animation_data is None or source.animation_data.action is None:
            raise RuntimeError("FBX importado sem action: " + fbx)
        source.animation_data.action_slot = source.animation_data.action_slot if source.animation_data.action_slot else source.animation_data.action.slots[0]
        retarget_action(target, source, os.path.basename(fbx), export_name)
        bpy.data.objects.remove(source, do_unlink=True)
        # Remove só a ação temporária do FBX; a ação retarget já está separada.
        for a in src_actions:
            if a.users == 0:
                bpy.data.actions.remove(a)

    # GLB com Actions exporta separadamente os clipes originais e os quatro candidatos.
    wanted = descendants(target)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in wanted:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = target
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(out_path), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_frame_range=True, export_apply=True)
    print("EXPORTED", os.path.abspath(out_path))


if __name__ == "__main__":
    main()
