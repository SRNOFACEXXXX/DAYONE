"""Pia do banheiro (Wash_Basin_07, pack de interiores): os UVs da louça caíam na região VERMELHA do atlas Textures_4.png
(pia vermelha = 'textura bugada' do relato do dono). Remapeia as faces avermelhadas para a cor branca da louça do vaso
(Toilet_03, mesmo atlas) e regrava o GLB no mesmo formato do importador (material único 'Color', sem imagem embutida).
Uso: python tools/blender/corrigir_pia.py   (bpy do PyPI)"""
import bpy, os
from mathutils import Vector
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "models", "atualizacao", "interiores")
img = bpy.data.images.load(os.path.join(D, "Textures_4.png"))
W, H = img.size
px = list(img.pixels)


def cor(uv):
    x = min(max(int(uv.x % 1.0 * W), 0), W - 1)
    y = min(max(int(uv.y % 1.0 * H), 0), H - 1)
    i = (y * W + x) * 4
    return px[i], px[i + 1], px[i + 2]


def limpar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


# 1) UV da louça branca do vaso: o mais claro e menos saturado
limpar()
bpy.ops.import_scene.gltf(filepath=os.path.join(D, "Toilet_03.glb"))
vaso = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
melhor, uv_branco = -1.0, None
for l in vaso.data.uv_layers.active.data:
    r, g, b = cor(l.uv)
    claro = (r + g + b) / 3 - (max(r, g, b) - min(r, g, b))
    if claro > melhor:
        melhor, uv_branco = claro, l.uv.copy()
print("UV_BRANCO", tuple(uv_branco), "cor", cor(uv_branco))

# 2) pia: faces avermelhadas -> UV branco
limpar()
bpy.ops.import_scene.gltf(filepath=os.path.join(D, "Wash_Basin_07.glb"))
pia = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
uvs = pia.data.uv_layers.active.data
trocadas = 0
for p in pia.data.polygons:
    rs = [cor(uvs[li].uv) for li in p.loop_indices]
    r = sum(c[0] for c in rs) / len(rs); g = sum(c[1] for c in rs) / len(rs); b = sum(c[2] for c in rs) / len(rs)
    if r > 0.35 and r > g * 1.6 and r > b * 1.6:   # vermelho
        for li in p.loop_indices:
            uvs[li].uv = uv_branco
        trocadas += 1
print("FACES_TROCADAS", trocadas, "de", len(pia.data.polygons))
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(D, "Wash_Basin_07.glb"), export_format="GLB", use_selection=True,
                          export_yup=True, export_materials="EXPORT", export_image_format="NONE")
print("PIA_OK")
