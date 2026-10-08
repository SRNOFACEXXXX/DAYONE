# Nuvens cúmulo low poly modeladas à mão (3 formas) -> game/assets/models/ceu/nuvem_<a|b|c>.glb
# Blocos de icosfera achatados posicionados à mão; base plana e sombreada (cor mais fria embaixo).
import bpy, bmesh, os
from mathutils import Vector as V, Matrix
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "ceu")
os.makedirs(OUT, exist_ok=True)


def material(nome, cor, emissao):
    m = bpy.data.materials.new(nome); m.use_nodes = True
    bs = next(x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*cor, 1); bs.inputs["Roughness"].default_value = 1.0
    bs.inputs["Emission Color"].default_value = (*cor, 1); bs.inputs["Emission Strength"].default_value = emissao
    return m


FORMAS = {
    "a": [((0, 0, 0), (38, 30, 16)), ((30, 6, -3), (26, 22, 12)), ((-28, -4, -2), (24, 20, 11)), ((6, 4, 12), (22, 18, 12)), ((-8, -10, 8), (18, 15, 10))],
    "b": [((0, 0, 0), (50, 26, 13)), ((42, 4, -2), (28, 20, 10)), ((-40, -6, -1), (30, 18, 10)), ((14, 2, 10), (20, 16, 10)), ((-18, 0, 9), (22, 14, 9)), ((60, -8, -4), (16, 12, 7))],
    "c": [((0, 0, 0), (26, 24, 18)), ((18, 8, 6), (18, 16, 13)), ((-16, -6, 4), (18, 16, 12)), ((2, 2, 20), (14, 12, 10))],
}
for nome, blocos in FORMAS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    for (x, y, z), (sx, sy, sz) in blocos:
        t = bmesh.new(); bmesh.ops.create_icosphere(t, subdivisions=1, radius=1.0)
        M = Matrix.Translation(V((x, y, z))) @ Matrix.Diagonal((sx, sy, sz, 1))
        mp = {v: bm.verts.new(M @ v.co) for v in t.verts}
        for f in t.faces:
            nf = bm.faces.new([mp[v] for v in f.verts])
            c = sum((M @ v.co for v in f.verts), V()) / 3
            nf.material_index = 1 if c.z < -2 else 0          # base achatada mais fria/sombreada
        t.free()
    for v in bm.verts:                                        # corta a base: nuvem cúmulo tem fundo plano
        if v.co.z < -6:
            v.co.z = -6 + (v.co.z + 6) * 0.15
    me = bpy.data.meshes.new("nuvem_" + nome); bm.to_mesh(me); bm.free()
    me.materials.append(material("nuvem_topo", (0.98, 0.95, 0.90), 0.35))
    me.materials.append(material("nuvem_base", (0.70, 0.74, 0.82), 0.2))
    ob = bpy.data.objects.new("nuvem_" + nome, me); bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "nuvem_%s.glb" % nome), use_selection=True, export_format="GLB", export_yup=True)
    print("NUVEM", nome, len(me.polygons))
