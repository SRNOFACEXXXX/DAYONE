# Importa os assets de cenário do usuário (Assets/) para o jogo, um .glb por objeto, origem no centro da base (piso),
# escala real, materiais simples (paleta/cor chapada; texturas ≤ 512 px). Malhas UCX_* dos pacotes viram colisão
# convexa ("-convcolonly" -> o importador do Godot cria a colisão fiel, sem parede invisível).
# Saída: game/assets/models/cenario/<categoria>/<nome>.glb + folha de conferência Assets/_vistas/cenario_<categoria>.png
# Uso: blender -b --factory-startup -P tools/importar_cenario.py [-- categoria]
import bpy, os, sys, math, glob
from mathutils import Vector as V, Matrix

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
A = os.path.join(RAIZ, "Assets")
E = os.path.join(A, "_ext")
OUT = os.path.join(RAIZ, "game", "assets", "models", "cenario")
NAT = os.path.join(E, "lowpoly_nature", "Models")
PAL_NAT = os.path.join(E, "lowpoly_nature", "Textures", "Base Palette.png")
ROCKS = os.path.join(E, "_modelo_pedras_free_pack_rocks_stylized", "source", "Free Pack - Rocks Stylized.fbx")
ROCKS_TEX = os.path.join(E, "_modelo_pedras_free_pack_rocks_stylized", "textures", "Rocks_Stylized_Color.png")
CARS = os.path.join(E, "_modelo_carros_freeamericansedanshm")
RUA = os.path.join(E, "_modelo_props_de_cidade_e_rua_ambiente_fbx_1_", "FBX")
CRATE = os.path.join(A, "caixa de armamentos", "free_pack_weapon_crate.fbx")


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat_cor(nome, rgb):
    m = bpy.data.materials.get("cor_" + nome) or bpy.data.materials.new("cor_" + nome)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*[lin(c) for c in rgb], 1)
    bs.inputs["Roughness"].default_value = 0.85
    bs.inputs["Metallic"].default_value = 0.0
    return m


def mat_tex(nome, caminho):
    m = bpy.data.materials.get("tex_" + nome)
    if m:
        return m
    m = bpy.data.materials.new("tex_" + nome)
    m.use_nodes = True
    nt = m.node_tree
    bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(caminho)
    if max(img.size) > 512:
        img.scale(512, 512)
    t.image = img
    t.interpolation = "Closest"
    nt.links.new(t.outputs["Color"], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = 0.85
    bs.inputs["Metallic"].default_value = 0.0
    return m


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def importar(fbx):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    return [o for o in bpy.data.objects if o not in antes]


def exportar(objs, pasta, nome, escala=1.0, cor=None, material=None, cores_mat=None, deitar=False):
    """Junta os objetos numa raiz com a base no piso, aplica material e exporta. deitar: gira +90° em X (modelo em pé)."""
    vis = [o for o in objs if o.type == "MESH" and not o.name.startswith("UCX_")]
    col = [o for o in objs if o.type == "MESH" and o.name.startswith("UCX_")]
    if not vis:
        return
    for o in vis:
        if material:
            o.data.materials.clear()
            o.data.materials.append(material)
        elif cores_mat is not None:
            for i, m in enumerate(o.data.materials):
                chave = next((k for k in cores_mat if m and k.lower() in m.name.lower()), None)
                o.data.materials[i] = mat_cor(chave or nome, cores_mat.get(chave, cor or (0.6, 0.6, 0.6)))
            if not o.data.materials:
                o.data.materials.append(mat_cor(nome, cor or (0.6, 0.6, 0.6)))
        elif cor:
            o.data.materials.clear()
            o.data.materials.append(mat_cor(nome, cor))
    if deitar:
        R = Matrix.Rotation(math.radians(90), 4, "X")
        for o in [x for x in vis + col if x.parent is None or x.parent not in vis + col]:
            o.matrix_world = R @ o.matrix_world
        bpy.context.view_layer.update()
    lo = V((1e9,) * 3); hi = V((-1e9,) * 3)
    for o in vis:
        for c in o.bound_box:
            w = o.matrix_world @ V(c); lo = V(map(min, lo, w)); hi = V(map(max, hi, w))
    # origem no PÉ do objeto: centro dos vértices dos primeiros 40 cm (tronco da árvore), não da caixa da copa —
    # a colisão de tronco (cilindro na origem) fica dentro do tronco mesmo em árvore torta
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    pe = [o.matrix_world @ v.co for o in vis for v in o.data.vertices if (o.matrix_world @ v.co).z < lo.z + 0.4]
    if pe and pasta == "natureza":
        cx = sum(p.x for p in pe) / len(pe); cy = sum(p.y for p in pe) / len(pe)
    raiz = bpy.data.objects.new(nome, None)
    bpy.context.scene.collection.objects.link(raiz)
    M = Matrix.Scale(escala, 4) @ Matrix.Translation(V((-cx, -cy, -lo.z)))
    for o in vis + col:
        mw = o.matrix_world.copy()
        o.parent = raiz
        o.matrix_world = M @ mw
    # grava a transformação final na própria malha (quem usa só a malha — MultiMesh da vegetação — recebe a escala real)
    bpy.context.view_layer.update()
    for o in vis + col:
        mw = o.matrix_world.copy()
        o.data = o.data.copy()
        o.data.transform(mw)
        o.matrix_world = Matrix.Identity(4)
    for o in col:
        o.name = o.name.replace("UCX_", "col_") + "-convcolonly"
        o.data.materials.clear()
    for o in bpy.data.objects:
        o.select_set(False)
    raiz.select_set(True)
    for o in vis + col:
        o.select_set(True)
    os.makedirs(os.path.join(OUT, pasta), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, pasta, nome + ".glb"), use_selection=True, export_format="GLB", export_yup=True)
    d = (hi - lo) * escala
    print("CENARIO %s/%s faces=%d dim=(%.2f %.2f %.2f) col=%d" % (pasta, nome, sum(len(o.data.polygons) for o in vis), d.x, d.y, d.z, len(col)))


# ---------------------------------------------------------------- natureza (paleta Base Palette)
NATUREZA = {   # arquivo: (nome no jogo, escala) — pinheiro/bétula adultos reduzidos para o porte de uma ilha tropical
    "OakAdultD": ("carvalho", 0.62), "GenericTreeB": ("arvore_b", 1.0), "GenericTreeD": ("arvore_d", 1.0),
    "BirchTreeAdultA": ("betula", 0.55), "BirchTreeYoungCSimple": ("betula_jovem", 1.0),
    "PineVariantAMatureB": ("pinheiro", 0.45), "PineVariantAGrowingB": ("pinheiro_medio", 1.0), "PineVariantAYoungC": ("pinheiro_jovem", 1.0),
    "WillowTreeAdultA": ("salgueiro", 0.8), "WitheredTreeB": ("arvore_seca", 0.8), "SmallWitheredTreeB": ("arvore_seca_p", 1.0),
    "Bush8": ("arbusto_a", 1.0), "BushA": ("arbusto_b", 1.0), "FernBClusterVariantA": ("samambaia_a", 1.0), "FernDClusterVariantB": ("samambaia_b", 1.0),
    "GrassLumpLargeFTall": ("tufo_capim", 1.6), "MixedGrassLumpLargeB": ("tufo_misto", 1.8), "NettleDMixedVariantB": ("urtiga", 1.0),
    "RockBigC": ("rocha_grande", 1.0), "RockNormD": ("rocha_media", 1.0), "RockBlueD": ("rocha_azul", 1.0), "RockSmallA": ("pedrisco_a", 1.0), "RockSmallE": ("pedrisco_b", 1.0),
    "TreeLogOakB": ("tronco_caido", 1.0), "TreeLogPileNormalB": ("pilha_troncos", 1.0), "TreeStumpNormalC": ("toco", 1.0), "TreeStumpShortD": ("toco_baixo", 1.0),
    "TreeRootB": ("raiz", 1.0), "TreeBranchBLeafless": ("galho", 1.0), "FirewoodPileA": ("lenha", 1.0), "CampfireASmall": ("fogueira", 1.0),
    "PlankStackB": ("pilha_tabuas", 1.0), "SWFModA": ("cerca_madeira", 1.0), "SWFModShortA": ("cerca_madeira_curta", 1.0),
    "RuinedWallA": ("muro_ruina", 1.0), "RuinedWallRubbleA": ("entulho", 1.0), "DirtPileG": ("monte_terra", 1.0),
}


def natureza():
    for f in sorted(glob.glob(os.path.join(NAT, "**", "*.fbx"), recursive=True)):
        base = os.path.basename(f)[:-4]
        if base not in NATUREZA:
            continue
        nome, esc = NATUREZA[base]
        limpar()
        exportar(importar(f), "natureza", nome, esc, material=mat_tex("paleta_natureza", PAL_NAT))


def pedras():
    limpar()
    objs = importar(ROCKS)
    mat = mat_tex("pedras", ROCKS_TEX)
    for o in [o for o in objs if o.type == "MESH" and not o.name.startswith("UCX_")]:
        nome = o.name.lower().replace("sm_rocks_", "pedra_")
        for x in bpy.data.objects:
            x.select_set(False)
        exportar([o], "pedras", nome, 1.0, material=mat)


def carros():
    tex = os.path.join(CARS, "Texture")
    for arq, nome, t in (("Car_stylized", "carro_sedan", "Car_color.png"), ("Police_stylized", "carro_policia", "Car_Police.png"),
                         ("Taxi_stylized", "carro_taxi", "Car_Taxi.png")):
        limpar()
        objs = importar(os.path.join(CARS, "Assets", arq + ".fbx"))
        for o in objs:
            if o.type == "MESH":
                for i, m in enumerate(o.data.materials):
                    n = (m.name.lower() if m else "")
                    if "glass" in n or "vidro" in n:
                        o.data.materials[i] = mat_tex("vidro", os.path.join(tex, "Glass.png"))
                    elif "detail" in n or "wheel" in n or "tire" in n:
                        o.data.materials[i] = mat_tex("detalhes", os.path.join(tex, "Car_details.png"))
                    elif "number" in n or "plate" in n:
                        o.data.materials[i] = mat_tex("placa", os.path.join(tex, "Car_Number.png"))
                    else:
                        o.data.materials[i] = mat_tex(nome, os.path.join(tex, t))
        exportar(objs, "carros", nome, 1.0, deitar=True)


# cor por NOME DO OBJETO (os materiais do pacote vieram sem textura)
RUA_CORES = {"Bank": (0.52, 0.36, 0.22), "Bin": (0.27, 0.36, 0.27), "Mailbox": (0.2, 0.32, 0.58), "Hydrant": (0.78, 0.2, 0.12),
             "Cone": (0.92, 0.45, 0.12), "Barrier": (0.9, 0.55, 0.15), "Box": (0.63, 0.49, 0.32), "Envelope": (0.86, 0.82, 0.72),
             "NewsPaper": (0.8, 0.78, 0.72), "Manhole": (0.3, 0.3, 0.31), "Trash": (0.25, 0.32, 0.26)}


def rua():
    for f in sorted(glob.glob(os.path.join(RUA, "*.fbx")) + glob.glob(os.path.join(RUA, "*.FBX"))):
        base = os.path.basename(f).rsplit(".", 1)[0]
        nome = base.lower().replace("sm_", "rua_")
        cor = next((v for k, v in RUA_CORES.items() if k.lower() in base.lower()), (0.5, 0.5, 0.5))
        limpar()
        exportar(importar(f), "rua", nome, 1.0, cor=cor)


def caixas():
    """5 caixas de armamento: corpo (_B) e tampa (_L) separados; a tampa sai com origem na dobradiça (aresta de trás em cima)."""
    limpar()
    objs = importar(CRATE)
    madeira = mat_cor("caixa_oliva", (0.30, 0.34, 0.20))
    for i in range(1, 6):
        corpo = bpy.data.objects.get("SM_WeaponCrate_0%d_B" % i)
        tampa = bpy.data.objects.get("SM_WeaponCrate_0%d_L" % i)
        if not corpo or not tampa:
            continue
        for o in (corpo, tampa):
            mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
            o.data.materials.clear(); o.data.materials.append(madeira)
        print("CAIXA %d corpo dim=%s tampa dim=%s" % (i, tuple(round(x, 3) for x in corpo.dimensions), tuple(round(x, 3) for x in tampa.dimensions)))
        for o in bpy.data.objects:
            o.select_set(False)
        exportar([corpo], "caixas", "caixa_%d_corpo" % i, 1.0)
        exportar([tampa], "caixas", "caixa_%d_tampa" % i, 1.0)


CATS = {"natureza": natureza, "pedras": pedras, "carros": carros, "rua": rua, "caixas": caixas}
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(CATS)
for c in args:
    CATS[c]()
