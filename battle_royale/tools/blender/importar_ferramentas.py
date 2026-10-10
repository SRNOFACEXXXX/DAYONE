"""Importa os modelos de ferramentas/armas fornecidos pelo dono (machado hatchet_low_poly.glb, SM_BasicPickaxe.fbx + texturas,
RPG weapons FBX) e gera os GLBs leves do jogo em game/assets/models/itens/ (um material com a textura base reduzida).
Convenção dos itens do DAYONE: comprimento no eixo Z do Blender (vira +Y no Godot), base em Z=0, cabeça/lâmina para +Z,
fio da lâmina para +X. Roda com o `bpy` do PyPI:  python tools/blender/importar_ferramentas.py <pasta_fontes> <pasta_saida>
<pasta_fontes> tem: hatchet_low_poly.glb, pick/SM_BasicPickaxe.fbx + T_BasicPickaxe_BaseColor.tga, rpg/Bows/Bow_01.fbx,
rpg/Accessories/Arrow_01.fbx, rpg/Hammers/Hammer_01.fbx, rpg/Spears/Spear_01.fbx, rpg/RPG_Weapons_Texture_01.png"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

FONTES, SAIDA = sys.argv[1], sys.argv[2]
TMP = os.path.join(SAIDA, "_tmp")
os.makedirs(TMP, exist_ok=True)


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def meshes_utiles(manter_lod0=True):
    ms = [o for o in bpy.data.objects if o.type == "MESH"]
    # LODs (Nome_LOD1, _LOD2): fica só o mais detalhado
    ms = [o for o in ms if "_LOD1" not in o.name and "_LOD2" not in o.name and "_LOD3" not in o.name]
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o not in ms:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    return ms


def juntar(ms):
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(ms) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def eixos(o):
    vs = [v.co.copy() for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return vs, mn, mx


def orientar(o, comprimento, cabeca_pesada=True, largura_em_x=True):
    """Eixo mais longo -> +Z; a ponta com mais vértices (cabeça) para cima; segunda maior dimensão -> X; base em Z=0 e centrado."""
    vs, mn, mx = eixos(o)
    dim = mx - mn
    ordem = sorted(range(3), key=lambda i: -dim[i])
    longo, medio = ordem[0], ordem[1]
    # matriz que leva o eixo `longo` a Z e `medio` a X
    base = [Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))]
    zc = base[longo]
    xc = base[medio]
    yc = zc.cross(xc)
    if yc.length < 0.5:
        yc = Vector((0, 1, 0))
    rot = Matrix((xc, yc, zc))   # linhas = novos eixos em termos dos antigos
    o.data.transform(rot.to_4x4())
    o.data.update()
    vs, mn, mx = eixos(o)
    meio = (mn.z + mx.z) / 2
    if cabeca_pesada:
        acima = sum(1 for v in vs if v.z > meio)
        if acima < len(vs) - acima:
            o.data.transform(Matrix.Rotation(math.pi, 4, "X"))   # vira: cabeça para +Z
            o.data.update()
            vs, mn, mx = eixos(o)
    k = comprimento / (mx.z - mn.z)
    o.data.transform(Matrix.Scale(k, 4))
    o.data.update()
    vs, mn, mx = eixos(o)
    o.data.transform(Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))))
    o.data.update()
    return o


def lado_do_fio(o):
    """Cabo no eixo (x=0) e fio da lâmina para +X: x=0 na média dos vértices do cabo (30% de baixo); se a cabeça se estende mais
    para -X do que para +X, gira 180° em Z."""
    vs, mn, mx = eixos(o)
    cabo = [v.x for v in vs if v.z < mx.z * 0.3]
    hx = sum(cabo) / max(len(cabo), 1)
    o.data.transform(Matrix.Translation(Vector((-hx, 0, 0))))
    o.data.update()
    vs, mn, mx = eixos(o)
    topo = [v for v in vs if v.z > mx.z * 0.7]
    ext_mais = max((v.x for v in topo), default=0.0)
    ext_menos = -min((v.x for v in topo), default=0.0)
    if ext_menos > ext_mais:
        o.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
        o.data.update()
    print("FIO", o.name, "mais=%.3f menos=%.3f" % (ext_mais, ext_menos))


def textura(caminho_origem, nome, lado=512):
    img = bpy.data.images.load(caminho_origem)
    img.scale(lado, lado)
    png = os.path.join(TMP, nome + ".png")
    img.filepath_raw = png
    img.file_format = "PNG"
    img.save()
    return bpy.data.images.load(png)


def material(o, img, rugosidade=0.8, metal=0.0):
    for i in range(len(o.data.materials)):
        o.data.materials.pop()
    m = bpy.data.materials.new("mat_" + o.name)
    m.use_nodes = True
    n = m.node_tree.nodes
    b = n.get("Principled BSDF")
    t = n.new("ShaderNodeTexImage")
    t.image = img
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rugosidade
    b.inputs["Metallic"].default_value = metal
    o.data.materials.append(m)


def exportar(o, id_):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    o.name = id_
    for p in o.data.polygons:
        p.use_smooth = False
    caminho = os.path.join(SAIDA, id_ + ".glb")
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    vs, mn, mx = eixos(o)
    print("ITEM", id_, "%.2f x %.2f x %.2f m" % tuple(mx - mn), "tris", sum(len(p.vertices) - 2 for p in o.data.polygons), "KB", os.path.getsize(caminho) // 1024)


def importar(caminho):
    limpar()
    if caminho.endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=caminho)
    else:
        bpy.ops.import_scene.fbx(filepath=caminho)
    return juntar(meshes_utiles())


# ---- machado: hatchet do dono (textura base reduzida) ----
o = importar(os.path.join(FONTES, "hatchet_low_poly.glb"))
base = None
for m in bpy.data.materials:
    if m.use_nodes:
        b = m.node_tree.nodes.get("Principled BSDF")
        if b and b.inputs["Base Color"].links:
            base = b.inputs["Base Color"].links[0].from_node.image
if base is not None:
    base.filepath_raw = os.path.join(TMP, "hatchet_base_orig.png")
    base.file_format = "PNG"
    base.save()
img = textura(os.path.join(TMP, "hatchet_base_orig.png"), "machado_base", 512) if base is not None else None
orientar(o, 0.62)
lado_do_fio(o)
if img is not None:
    material(o, img, 0.7, 0.2)
exportar(o, "machado")

# ---- picareta: SM_BasicPickaxe (LOD0) + BaseColor ----
o = importar(os.path.join(FONTES, "pick", "SM_BasicPickaxe.fbx"))
orientar(o, 0.85, cabeca_pesada=True)
lado_do_fio(o)
material(o, textura(os.path.join(FONTES, "pick", "T_BasicPickaxe_BaseColor.tga"), "picareta_base", 512), 0.6, 0.35)
exportar(o, "picareta")

# ---- pack RPG: arco, flecha, martelo, lança (atlas de cores único) ----
ATLAS = os.path.join(FONTES, "rpg", "RPG_Weapons_Texture_01.png")
for id_, rel, comp, pesada in (("arco", "Bows/Bow_01.fbx", 1.0, False), ("flecha", "Accessories/Arrow_01.fbx", 0.7, True),
                               ("martelo", "Hammers/Hammer_01.fbx", 0.55, True), ("lanca", "Spears/Spear_01.fbx", 1.6, True)):
    o = importar(os.path.join(FONTES, "rpg", rel))
    orientar(o, comp, cabeca_pesada=pesada)
    material(o, textura(ATLAS, "rpg_atlas", 512), 0.75, 0.1)   # limpar() apaga as imagens: recarrega a cada peça
    exportar(o, id_)

import shutil
shutil.rmtree(TMP, ignore_errors=True)
