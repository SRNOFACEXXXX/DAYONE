# Braços/mãos em 1ª pessoa do soldado (docs/ref/ak47_fps.jpg): mangas camufladas + mãos cor de pele facetadas (poucas faces),
# skinnados no MESMO esqueleto dos *_fp.glb (Adult_Woodcutter, 44 ossos). O viewmodel.gd troca as malhas antigas por esta em tempo de execução,
# então as animações draw/fire/idle/reload/inspect da AK/M4/pistola/faca continuam valendo.
# -> game/assets/models/weapons/fp_bracos.glb
# Uso: blender -b --factory-startup -P tools/build_fp_bracos.py
import bpy, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_soldado as S

OUT = os.path.join(S.ROOT, "game", "assets", "models", "weapons", "fp_bracos.glb")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=S.SRC)
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    for o in list(bpy.context.scene.objects):
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    camo_img = bpy.data.images.get("soldado_camo") or S.make_camo()
    pal_img = bpy.data.images.get("soldado_paleta") or S.make_paleta()
    H, T = S.fn_ossos(arm)
    m = S.Malha()
    for s, L in ((1, "Left"), (-1, "Right")):
        S.braco(m, H, T, L, s, wm=1.2, cor_mao="pele", cor_dedos="pele_s", antebraco=True)
    m.uvscale = 0.14   # câmera a poucos cm da manga: triângulos da camuflagem menores
    me = m.fim("BracosFP")
    for nome, img, interp in (("Manga_soldado", camo_img, "Linear"), ("Pele_paleta", pal_img, "Closest")):
        mt = bpy.data.materials.new(nome)
        mt.use_nodes = True
        bs = next(n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bs.inputs["Roughness"].default_value = 0.95
        tx = mt.node_tree.nodes.new("ShaderNodeTexImage")
        tx.image = img
        tx.interpolation = interp
        mt.node_tree.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
        me.materials.append(mt)
    ob = bpy.data.objects.new("BracosFP", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = arm
    for b in sorted(m.ossos):
        ob.vertex_groups.new(name=b)
    for i, w in enumerate(m.vw):
        for b, val in w.items():
            ob.vertex_groups[b].add([i], val, "REPLACE")
    md = ob.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False, export_skins=True)
    print("FP_BRACOS tris=%d" % sum(len(p.vertices) - 2 for p in me.polygons))


main()
