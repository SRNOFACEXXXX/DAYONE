"""Modelos pequenos de sinalização dos POIs, geometria fixa e legível no chão."""
import bpy
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "detalhes")
os.makedirs(OUT, exist_ok=True)

def material(name, color, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Roughness"].default_value = 0.88
    p.inputs["Metallic"].default_value = metallic
    return m

def cube(name, loc, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new("quina gasta", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        o.modifiers.new("normais", "WEIGHTED_NORMAL")
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier="normais")
    return o

def sign_text(body, size, x, z, mat, name):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.offset = 0.012
    curve.extrude = 0.008
    curve.bevel_depth = 0.002
    curve.bevel_resolution = 0
    ob = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(ob)
    ob.location = (x, -0.112, z)
    ob.rotation_euler[0] = math.radians(90.0)  # face para -Y, a frente das placas
    ob.data.materials.append(mat)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob.select_set(False)
    return ob

def make_sign(kind, title, subtitle):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = {
        "military": material("Pintura verde quartel", (0.12, 0.24, 0.18)),
        "farm": material("Madeira envelhecida fazenda", (0.30, 0.19, 0.10)),
        "runway": material("Oliva placa aerodromo", (0.25, 0.31, 0.22)),
        "cream": material("Letra marfim", (0.91, 0.84, 0.65)),
        "yellow": material("Tinta amarela", (0.88, 0.58, 0.13)),
        "wood": material("Eucalipto gasto", (0.36, 0.25, 0.15)),
        "iron": material("Ferro escuro fosco", (0.12, 0.14, 0.13), 0.35),
    }
    width = 3.7 if kind != "farm" else 4.2
    board_mat = palette[kind]
    objs = []
    for x in (-width * 0.39, width * 0.39):
        objs.append(cube("poste", (x, 0.02, 1.42), (0.16, 0.18, 2.84), palette["wood"], 0.025))
        objs.append(cube("sapata", (x, 0.02, 0.1), (0.28, 0.3, 0.2), palette["iron"], 0.025))
    objs.append(cube("quadro", (0, 0, 2.2), (width, 0.18, 1.28), palette["wood"], 0.055))
    objs.append(cube("painel", (0, -0.103, 2.2), (width - 0.14, 0.035, 1.14), board_mat, 0.025))
    # Friso superior e divisor dão leitura à distância sem encher o painel de ornamento.
    objs.append(cube("friso", (0, -0.128, 2.685), (width - 0.28, 0.025, 0.055), palette["yellow"], 0.006))
    objs.append(cube("divisor", (0, -0.129, 2.16), (width - 0.42, 0.02, 0.025), palette["yellow"], 0.003))
    # Placa central simples, sem símbolos ou brasões inventados.
    font_title = sign_text(title, 0.43 if len(title) < 12 else 0.30, 0, 2.31, palette["cream"], "titulo")
    font_sub = sign_text(subtitle, 0.205 if len(subtitle) < 24 else 0.155, 0, 1.91, palette["yellow"], "linha auxiliar")
    bpy.context.view_layer.update()
    # Centraliza cada linha pelo próprio limite tipográfico.
    for ob in (font_title, font_sub):
        ob.location.x -= ob.dimensions.x * 0.5
        objs.append(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = "placa_identificacao_" + kind
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, joined.name + ".glb"), export_format="GLB", export_yup=True, export_apply=True, use_selection=True)
    print("POI_SIGN", joined.name, "faces", len(joined.data.polygons))

make_sign("military", "7º BIL", "INFANTARIA LEVE")
make_sign("farm", "FAZENDA BOA ESPERANÇA", "CAFÉ  /  GADO")
make_sign("runway", "PISTA DO TAUÁ", "AERÓDROMO DE TERRA")
