# Converte a mobília dos pacotes do usuário em modelos do jogo (um .glb por móvel):
#   Assets/_ext/_MODELO_DE_CASAS_COM_INTERIORES_objects_interiorvillage_alpha_gltf/scene.gltf (Sketchfab "interior village")
#   Assets/_ext/_interiores_de_casas_fbx/FBX/*.fbx (armários/pia/mesas/cadeira/lixeira, texturas PBR em _interiores_de_casas_textures_1_)
# Saída: game/assets/models/moveis/<nome>.glb + moveis.json (dimensões, para o tools/interior.py escalar cada peça).
# Quadro de cada móvel = o de tools/interior.py: origem no centro da pegada, no piso; COSTAS para +Y do Blender (-Z do Godot),
# FRENTE para -Y do Blender (+Z do Godot). Escala real (metros). Materiais simples: só albedo (<= 512 px), sem normal/metallic.
# Uso: blender -b --factory-startup -P tools/importar_moveis.py [-- --folha pasta]   (--folha: renderiza a folha de miniaturas)
import bpy, bmesh, os, sys, math, json
from mathutils import Vector as V, Matrix

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
EXT = os.path.join(RAIZ, "Assets", "_ext")
GLTF = os.path.join(EXT, "_MODELO_DE_CASAS_COM_INTERIORES_objects_interiorvillage_alpha_gltf", "scene.gltf")
FBX = os.path.join(EXT, "_interiores_de_casas_fbx", "FBX")
TEX = os.path.join(EXT, "_interiores_de_casas_textures_1_", "Textures")
OUT = os.path.join(RAIZ, "game", "assets", "models", "moveis")
os.makedirs(OUT, exist_ok=True)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FOLHA = os.path.abspath(ARGS[ARGS.index("--folha") + 1]) if "--folha" in ARGS else None
MAX_TEX = 512

# nome -> (objetos do gltf [principal + gavetas/portas], altura real desejada (0 = manter), giro em graus no eixo Z para a frente ir a -Y)
G = {
    "sofa_a": (["Armchair_06"], 0, 0), "sofa_b": (["Armchair_07"], 0, 0), "sofa_c": (["Armchair_08"], 0, 0), "sofa_d": (["Armchair_04"], 0, 0),
    "poltrona_a": (["Armchair"], 0, 0), "poltrona_b": (["Armchair_01"], 0, 0), "poltrona_c": (["Armchair_02"], 0, 0), "poltrona_d": (["Armchair_05"], 0, 0),
    "cama_a": (["bed"], 0, 0), "cama_b": (["bed_01"], 0, 0), "cama_c": (["bed_03"], 0, 0), "cama_d": (["bed_04"], 0, 0),
    "guarda_roupa_a": (["Wardrobe"], 0, 0), "guarda_roupa_b": (["Wardrobe_01"], 0, 0),
    "comoda_a": (["Chest_drawers_01.003", "Chest_drawers_01.005", "Chest_drawers_01.006", "Chest_drawers_01.007"], 0, 0),
    "comoda_b": (["Chest_drawers_02", "Chest_drawers_02.002", "Chest_drawers_02.003", "Chest_drawers_02.004"], 0, 0),
    "comoda_c": (["Chest_drawers_03.001", "Chest_drawers_03.003", "Chest_drawers_03.004", "Chest_drawers_03.005"], 0, 0),
    "comoda_d": (["Chest_drawers_04.001", "Chest_drawers_04.003", "Chest_drawers_04.004", "Chest_drawers_04.005", "Chest_drawers_04.006", "Chest_drawers_04.007"], 0, 0),
    "comoda_e": (["Chest_drawers_05.001", "Chest_drawers_05.003", "Chest_drawers_05.004", "Chest_drawers_05.005", "Chest_drawers_05.006", "Chest_drawers_05.007", "Chest_drawers_05.008"], 0, 0),
    "comoda_f": (["Chest_drawers_06", "Chest_drawers_06.002", "Chest_drawers_06.003", "Chest_drawers_06.004", "Chest_drawers_06.005", "Chest_drawers_06.006"], 0, 0),
    "estante_a": (["Bookcase_01"], 0, 0), "estante_b": (["Bookcase_02"], 0, 0), "estante_c": (["Fitment"], 0, 0), "estante_d": (["Fitment_02"], 0, 0),
    "estante_baixa": (["Bookcase"], 0, 0),
    "fogao_a": (["Stove"], 0, 0),
    "geladeira_a": (["Refrigerator.001", "Refrigerator_Door.001", "Refrigerator_Door_01.001"], 1.75, 0),
    "mesa_c": (["Table"], 0, 0), "mesa_d": (["Table_01"], 0, 0), "mesa_e": (["Table_02"], 0, 0),
    "cadeira_b": (["Chair_04"], 0, 0), "cadeira_c": (["Chair_05"], 0, 0),
    "abajur": (["Lamp_01"], 0, 0), "radio": (["Radio_01"], 0, 0),
    # adereços de mesa/parede/teto (alturas reais; conferir na folha --folha e ajustar com --giros)
    "despertador": (["Alarm_clock"], 0.10, 0), "livros": (["Books_001"], 0.22, 0), "garrafa": (["Bottle"], 0.30, 0),
    "lata": (["Can"], 0.12, 0), "bolo": (["Cake_02"], 0.14, 0), "tigela": (["Cereal_bowl"], 0.07, 0),
    "luminaria": (["Desk_lamp"], 0.45, 0), "vaso_flor": (["Flower_Table_01"], 0.40, 0), "leite": (["Milk"], 0.24, 0),
    "quadro_a": (["Painting"], 0.62, 0), "quadro_b": (["Painting_03"], 0.58, 0), "quadro_c": (["Painting_05"], 0.58, 0),
    "telefone": (["Phone"], 0.12, 0), "prato_comida": (["Plate_food"], 0.07, 0), "prato": (["Plate"], 0.02, 0),
    "escorredor": (["Plate_rack"], 0.28, 0), "radio_b": (["Radio_03"], 0.25, 0), "saco_lixo": (["Garbage_bags"], 0.6, 0),
    "ventilador_teto": (["Ceiling_Fan_02", "Ceiling_Fan_Blades_02"], 0, 0), "lixeira_b": (["Trash_can_01"], 0.45, 0),
}
# nome -> (fbx, albedo relativo a TEX, altura real (0 = manter), giro Z)
F = {
    "pia_a": ("cabinetsink.fbx", "BaseCabinet/DoorSink/cabinetsink_albedo.jpg", 0, 0),
    "armario_baixo_a": ("cabinetdrawers.fbx", "BaseCabinet/Drawers/cabinetdrawers_albedo.jpg", 0, 0),
    "armario_baixo_b": ("cabinetdoordrawer.fbx", "BaseCabinet/DoorDrawer/cabinetdoordrawer_albedo.jpg", 0, 0),
    "armario_alto_a": ("wallcabinet.fbx", "WallCabinet/wallcabinet_albedo.jpg", 0, 0),
    "cadeira_a": ("chair.fbx", "Chair/chair_albedo.jpg", 0, 0),
    "mesa_a": ("table_small.fbx", "Tables/table_small_albedo.jpg", 0, 0),
    "mesa_b": ("table_large.fbx", "Tables/table_large_albedo.jpg", 0, 0),
    "lixeira_a": ("trash_can.fbx", "TrashCan/trashcan_albedo.jpg", 0, 0),
    "cristaleira_a": ("glasscabinet.fbx", "GlassCabinet/glasscabinet_albedo.jpg", 0, 0),
}
if "--giros" in ARGS:            # ajustes de orientação conferidos na folha (nome=graus,...)
    for par in ARGS[ARGS.index("--giros") + 1].split(","):
        n, g = par.split("=")
        if n in G:
            G[n] = (G[n][0], G[n][1], float(g))
        else:
            F[n] = (*F[n][:3], float(g))

_mats = {}


def img_reduzida(img):
    if img is None:
        return None
    if max(img.size) > MAX_TEX:
        s = MAX_TEX / max(img.size)
        img.scale(max(8, int(img.size[0] * s)), max(8, int(img.size[1] * s)))
    return img


def mat_simples(chave, img, cor=(0.8, 0.8, 0.8, 1)):
    """Material só com albedo (sem normal/metallic/AO), rugoso."""
    if chave in _mats:
        return _mats[chave]
    m = bpy.data.materials.new("mv_" + chave)
    m.use_nodes = True
    nt = m.node_tree
    bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Roughness"].default_value = 0.85
    bs.inputs["Metallic"].default_value = 0.0
    bs.inputs["Base Color"].default_value = cor
    if img is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img_reduzida(img)
        nt.links.new(t.outputs["Color"], bs.inputs["Base Color"])
    _mats[chave] = m
    return m


def albedo_de(m):
    """Imagem ligada à Base Color de um material importado (ou cor base)."""
    if m is None or not m.use_nodes:
        return None, (0.8, 0.8, 0.8, 1)
    bs = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bs is None:
        return None, (0.8, 0.8, 0.8, 1)
    inp = bs.inputs["Base Color"]
    cor = tuple(inp.default_value)
    for l in inp.links:
        n = l.from_node
        while n and n.type != "TEX_IMAGE" and n.inputs:
            ls = [x for i in n.inputs for x in i.links]
            n = ls[0].from_node if ls else None
        if n and n.type == "TEX_IMAGE" and n.image:
            return n.image, cor
    return None, cor


def juntar(obs, nome):
    """Copia as malhas (transformação de mundo aplicada) e junta num único objeto novo."""
    novos = []
    for o in obs:
        me = o.data.copy()
        me.transform(o.matrix_world)
        n = bpy.data.objects.new(nome + "_p", me)
        bpy.context.scene.collection.objects.link(n)
        novos.append(n)
    bpy.ops.object.select_all(action="DESELECT")
    for n in novos:
        n.select_set(True)
    bpy.context.view_layer.objects.active = novos[0]
    if len(novos) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nome
    ob.data.name = nome
    return ob


def normalizar(ob, alt, giro):
    me = ob.data
    me.transform(Matrix.Rotation(math.radians(giro), 4, "Z"))
    xs = [v.co for v in me.vertices]
    lo = V((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
    hi = V((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
    me.transform(Matrix.Translation(V(((lo.x + hi.x) / -2, (lo.y + hi.y) / -2, -lo.z))))
    if alt > 0:
        me.transform(Matrix.Scale(alt / (hi.z - lo.z), 4))
    # limpeza leve: remove vértices soltos/duplicados, normais para fora
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    # só um mapa UV (o exportador leva todos)
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    xs = [v.co for v in me.vertices]
    return [round(max(p.x for p in xs) - min(p.x for p in xs), 3), round(max(p.y for p in xs) - min(p.y for p in xs), 3), round(max(p.z for p in xs), 3)]


def exportar(ob, nome):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + ".glb"), use_selection=True, export_format="GLB", export_yup=True,
                              export_apply=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
                              export_image_format="AUTO", export_attributes=False)


manifesto = {}
prontos = []
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLTF)
fonte = list(bpy.data.objects)
por_nome = {o.name: o for o in fonte}
for nome, (nomes, alt, giro) in G.items():
    obs = []
    for n in nomes:
        o = por_nome[n]
        obs += [d for d in [o] + list(o.children_recursive) if d.type == "MESH"]
    ob = juntar(obs, nome)
    for i, slot in enumerate(ob.material_slots):
        img, cor = albedo_de(slot.material)
        slot.material = mat_simples(img.name if img else "%s_%d" % (nome, i), img, cor)
    dim = normalizar(ob, alt, giro)
    exportar(ob, nome)
    manifesto[nome] = {"dim": dim, "faces": len(ob.data.polygons), "mats": len(ob.material_slots)}
    prontos.append(ob)
    print("MOVEL", nome, dim, len(ob.data.polygons), "faces")
for o in fonte:                       # descarta a cena de origem
    bpy.data.objects.remove(o)

for nome, (arq, alb, alt, giro) in F.items():
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(FBX, arq))
    novos = [o for o in bpy.data.objects if o not in antes]
    obs = [o for o in novos if o.type == "MESH"]
    ob = juntar(obs, nome)
    for o in novos:
        bpy.data.objects.remove(o)
    img = bpy.data.images.load(os.path.join(TEX, alb))
    m = mat_simples(nome, img)
    ob.data.materials.clear()
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.material_index = 0
    dim = normalizar(ob, alt, giro)
    exportar(ob, nome)
    manifesto[nome] = {"dim": dim, "faces": len(ob.data.polygons), "mats": 1}
    prontos.append(ob)
    print("MOVEL", nome, dim, len(ob.data.polygons), "faces")

with open(os.path.join(OUT, "moveis.json"), "w", encoding="utf8") as f:
    json.dump(manifesto, f, indent=1, ensure_ascii=False)
print("MOVEIS_OK", len(manifesto))

# ---------------------------------------------------------------- folha de miniaturas (vista de frente-esquerda, 3/4 de cima)
if FOLHA:
    os.makedirs(FOLHA, exist_ok=True)
    col = 8
    passo = 3.2
    for i, ob in enumerate(prontos):
        ob.location = V(((i % col) * passo, -(i // col) * passo * 1.1, 0))
        # boneco de referência 1,8 m atrás/à direita
        p = bpy.data.objects.new("ref%d" % i, bpy.data.meshes.new("ref"))
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(0.12, 0.12, 1.8), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(1.35, 0.9, 0.9), verts=bm.verts)
        bm.to_mesh(p.data)
        bm.free()
        p.location = ob.location
        bpy.context.scene.collection.objects.link(p)
        t = bpy.data.objects.new("t%d" % i, bpy.data.curves.new("t%d" % i, "FONT"))
        t.data.body = ob.name
        t.data.size = 0.32
        t.location = ob.location + V((-1.4, -1.5, 0))
        bpy.context.scene.collection.objects.link(t)
    # seta de frente (-Y) no chão de cada célula
    linhas = (len(prontos) + col - 1) // col
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = col * passo + 1
    cx = (col - 1) * passo / 2
    cy = -(linhas - 1) * passo * 1.1 / 2
    ang = math.radians(35)
    cam.location = V((cx - 14, cy - 30, 22))
    cam.rotation_euler = (math.radians(60), 0, math.radians(-25))
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.color = (0.55, 0.6, 0.65)
    r = sc.render
    r.engine = "BLENDER_WORKBENCH"
    r.resolution_x = 1800
    r.resolution_y = 1100
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.light = "STUDIO"
    r.filepath = os.path.join(FOLHA, "moveis_frente.png")
    bpy.ops.render.render(write_still=True)
    # vista de cima (confere pegada e costas: frente para baixo da imagem)
    cam.location = V((cx, cy, 40))
    cam.rotation_euler = (0, 0, 0)
    r.filepath = os.path.join(FOLHA, "moveis_topo.png")
    bpy.ops.render.render(write_still=True)
    print("FOLHA", FOLHA)
