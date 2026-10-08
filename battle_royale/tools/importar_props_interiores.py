"""Converte os FBX do pack 'props interiores' (Cute Furniture Free) para glb do jogo.

Uso: blender -b --factory-startup -P tools/importar_props_interiores.py -- <pasta_fbx_separados> <Textures_4.png>
Saída: game/assets/models/atualizacao/interiores/<Nome>.glb  (+ Textures_4.png copiado uma vez, + interiores.json com AABB)

- Escala/eixo: o importador FBX do Blender converte para metros e Z-up; o exportador glTF grava Y-up (+Y up, frente -Z do Blender -> +Z).
- Todas as malhas do arquivo viram UM objeto, transformações aplicadas, origem no centro da base (x/z centrados, y=0 no chão).
- Material: o glb NÃO embute imagem (export_image_format NONE); o jogo (core/moveis.gd) troca por UM material compartilhado com
  Textures_4.png e filtro nearest — textura não é duplicada em 47 arquivos. Superfícies 'Glass' viram material de vidro único.
"""
import bpy, sys, os, json, shutil, glob
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = argv[0] if argv else ""
TEX = argv[1] if len(argv) > 1 else ""
OUT = os.path.join(RAIZ, "game", "assets", "models", "atualizacao", "interiores")
os.makedirs(OUT, exist_ok=True)
if TEX and os.path.exists(TEX):
    shutil.copyfile(TEX, os.path.join(OUT, "Textures_4.png"))

info = {}
for f in sorted(glob.glob(os.path.join(SRC, "*.fbx"))):
    nome = os.path.splitext(os.path.basename(f))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=f, use_custom_normals=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("SEM MALHA", nome); continue
    # aplica transformações (inclui escala 0.01 de cm e rotação -90 X do FBX) e junta
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        if o.parent:
            mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o, do_unlink=True)
    ob.name = nome
    ob.data.name = nome
    # materiais: só 'Color' (atlas) e 'Glass'; imagens removidas
    for i, ms in enumerate(ob.material_slots):
        mn = (ms.material.name if ms.material else "Color")
        alvo = "Glass" if "glass" in mn.lower() else "Color"
        m = bpy.data.materials.get(alvo) or bpy.data.materials.new(alvo)
        ms.material = m
    # origem no centro da base
    vs = [v.co for v in ob.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    off = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for v in ob.data.vertices:
        v.co -= off
    dim = mx - mn
    # glTF: x, z(up)->y, -y -> z
    info[nome] = {"tam": [round(dim.x, 4), round(dim.z, 4), round(dim.y, 4)], "verts": len(ob.data.vertices),
                  "mats": [ms.material.name for ms in ob.material_slots]}
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + ".glb"), export_format="GLB", use_selection=False,
                              export_image_format="NONE", export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_animations=False, export_skins=False)
    print("OK", nome, info[nome])

with open(os.path.join(OUT, "interiores.json"), "w", encoding="utf-8") as fh:
    json.dump(info, fh, indent=1)
print("CONVERTIDOS", len(info))
