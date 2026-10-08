"""Converte os FBX dos packs 'bases militares' e 'propts apocalipticos' (sem personagens rigados) para glb do jogo.

Uso: blender -b --factory-startup -P tools/importar_pack_mundo.py -- <raiz_extraida>
  <raiz_extraida> = pasta com mil/fbx, mil/tex, apo/fbx, apo/tex (zips do pack extraídos em raw/pack_mundo;
  as texturas 'Сamouflage_*.png' com 'С' CIRÍLICO no nome já renomeadas para 'Camouflage_*.png').
Saída: game/assets/models/atualizacao/mundo/<Nome>.glb + tex/*.png (uma cópia de cada atlas) + mundo.json (AABB, vértices, colisão)

- Escala/eixo: o importador FBX do Blender converte cm->m e Y-up->Z-up; o exportador glTF grava Y-up. Todas as malhas
  viram UM objeto (rodas, pás do helicóptero, torre do tanque são estáticas), transformações aplicadas, origem no centro da base.
- Materiais: o glb NÃO embute imagem. Os slots recebem nomes canônicos (mil_paleta, mil_camo1, mil_camo2, apo_paleta,
  apo_painel, apo_mapa, apo_placas, apo_numeros, int_paleta) e o jogo (maps/ilha/detalhes.gd) troca por UM material
  compartilhado por nome, com filtro nearest na paleta. Props apocalípticos cujo FBX não tem imagem ligada ('Color' vazio)
  recebem a paleta Color2.png por esse mesmo nome.
- Colisão: objetos '<Nome>_colN-convcolonly' (o importador do Godot vira StaticBody3D + ConvexPolygonShape3D):
    casco   = casco convexo da peça inteira (caixas, tambores, HESCO, veículos)
    partes  = casco por parte solta (sacos de areia, muro de concreto, torre, tendas): cobertura fiel, vãos abertos
    tronco  = caixa fina no pé (pinheiro)
    nenhuma = capim, cacto, itens pequenos de mão, asfalto rente ao chão
"""
import bpy, bmesh, sys, os, json, shutil, glob
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = argv[0] if argv else os.path.join(RAIZ, "raw", "pack_mundo")
OUT = os.path.join(RAIZ, "game", "assets", "models", "atualizacao", "mundo")
TEX_OUT = os.path.join(OUT, "tex")
os.makedirs(TEX_OUT, exist_ok=True)

MIL = os.path.join(SRC, "mil", "fbx", "Military_Free_fbx", "Separate_Assets_fbx")
APO = os.path.join(SRC, "apo", "fbx", "Apocalypse_Free_fbx")
FONTES = sorted(glob.glob(os.path.join(MIL, "*.fbx"))) + sorted(glob.glob(os.path.join(APO, "Props", "*.fbx"))) \
    + sorted(glob.glob(os.path.join(APO, "Environment", "*.fbx")))   # Characters/ (rigados) ficam de fora
ANI = os.path.join(SRC, "ani", "sep")
# animais do pack "animais asst" como decoração ESTÁTICA (pose de bind, sem esqueleto/animação: custo zero por quadro)
FONTES += [os.path.join(ANI, n + ".fbx") for n in ("Chicken_001", "Dog_001", "Deer_001", "Kitty_001")]
SO = [a for a in argv[1:]]   # opcional: nomes a converter (sem extensão)

MAT_MIL = {"Color": "mil_paleta", "Picture_1": "mil_camo1", "Picture_2": "mil_camo2"}
MAT_APO = {"Color": "apo_paleta", "Car_Headlights": "apo_paleta", "Car_Taillights": "apo_paleta", "Emissive": "apo_paleta",
           "Dashboard": "apo_painel", "Map": "apo_mapa", "RoadSigns": "apo_placas", "LicensePlates": "apo_numeros",
           "Metal": "int_paleta"}   # Road_Barrier_01 aponta para Textures_4.png (atlas dos móveis) no FBX original

COL = {
    "nenhuma": ["Grass_003", "Grass_008", "Cactus_001", "Cactus_002", "First_Aid", "Flashlight", "Walkie_talkie", "Map",
                "Katana", "Pistol1_Base", "Road_01", "Gas_Burner", "Fuel_Canister",
                "Chicken_001", "Dog_001", "Deer_001", "Kitty_001"],
    "partes": ["Barrier_006", "Barrier_007", "Concrete_Fence", "Tower_003", "Tent_002", "Tent_010", "Radiostation_001",
               "Helicopter_001", "Table_002"],
    "tronco": ["Pine_01"],
}
SEM_COL_OBJ = ("Blade",)       # pás do rotor não colidem (disco de 11 m viraria telhado invisível)
MAX_PARTES = 28


def modo_col(nome):
    for k, v in COL.items():
        if nome in v:
            return k
    return "casco"


# ---- texturas: uma cópia de cada atlas; camuflagem 2048² reduzida a 512² (ruído, GT 730)
def copiar_tex():
    pares = [(os.path.join(SRC, "mil", "tex", "textures", "Textures1.png"), "Textures1.png", 0),
             (os.path.join(SRC, "mil", "tex", "textures", "Camouflage_1.png"), "Camouflage_1.png", 512),
             (os.path.join(SRC, "mil", "tex", "textures", "Camouflage_2.png"), "Camouflage_2.png", 512)]
    pares.append((os.path.join(SRC, "ani", "sep", "Texture_1.png"), "Animais.png", 0))
    for n in ["Color2", "Dashboard", "Map", "RoadSigns", "Car_Numbers"]:
        pares.append((os.path.join(SRC, "apo", "tex", "textures", n + ".png"), n + ".png", 512 if n in ("Map",) else 0))
    for src, dst, lado in pares:
        if not os.path.exists(src):
            print("FALTA TEXTURA", src); continue
        if lado:
            img = bpy.data.images.load(src)
            if img.size[0] > lado:
                img.scale(lado, lado)
            img.filepath_raw = os.path.join(TEX_OUT, dst)
            img.file_format = "PNG"
            img.save()
        else:
            shutil.copyfile(src, os.path.join(TEX_OUT, dst))


def casco(pts, nome):
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    if len(bm.verts) < 4:
        bm.free(); return None
    ret = bmesh.ops.convex_hull(bm, input=list(bm.verts))
    lixo = [g for g in ret.get("geom_interior", []) + ret.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)]
    if lixo:
        bmesh.ops.delete(bm, geom=list(set(lixo)), context="VERTS")
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    if len(me.polygons) < 4:
        return None
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def partes_soltas(ob):
    """Listas de pontos (mundo) por componente conexo da malha."""
    me = ob.data
    pai = list(range(len(me.vertices)))

    def raiz(i):
        while pai[i] != i:
            pai[i] = pai[pai[i]]
            i = pai[i]
        return i
    for e in me.edges:
        a, b = raiz(e.vertices[0]), raiz(e.vertices[1])
        if a != b:
            pai[a] = b
    grupos = {}
    mw = ob.matrix_world
    for v in me.vertices:
        grupos.setdefault(raiz(v.index), []).append(mw @ v.co)
    return list(grupos.values())


def agrupar(partes):
    partes = [p for p in partes if max((max(c[i] for c in p) - min(c[i] for c in p)) for i in range(3)) >= 0.15]
    cel = 0.6
    while len(partes) > MAX_PARTES:
        cel *= 1.4
        g = {}
        for p in partes:
            c = sum(p, Vector()) / len(p)
            g.setdefault((int(c.x // cel), int(c.y // cel), int(c.z // cel)), []).extend(p)
        partes = list(g.values())
    return partes


copiar_tex()
info = {}
for f in FONTES:
    nome = os.path.splitext(os.path.basename(f))[0]
    if SO and nome not in SO:
        continue
    animal = os.sep + "ani" + os.sep in f
    apo = os.sep + "Apocalypse_Free_fbx" + os.sep in f
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=f, use_custom_normals=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("SEM MALHA", nome); continue
    for o in meshes:
        for md in list(o.modifiers):
            if md.type == "ARMATURE":
                o.modifiers.remove(md)   # fica na pose de bind
        o.shape_key_clear() if o.data.shape_keys else None
    for o in meshes:
        if o.parent:
            mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    # base/centro do visual (todas as malhas)
    vs = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    off = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    dim = mx - mn
    # ---- colisão (antes de juntar, para saber de que objeto vem cada parte)
    modo = modo_col(nome)
    cols = []
    if modo == "casco":
        c = casco([v - off for v in vs], nome + "_col0-convcolonly")
        if c: cols.append(c)
    elif modo == "partes":
        ps = []
        for o in meshes:
            if any(s in o.name for s in SEM_COL_OBJ):
                continue
            ps += partes_soltas(o)
        for i, p in enumerate(agrupar(ps)):
            c = casco([v - off for v in p], "%s_col%d-convcolonly" % (nome, i))
            if c: cols.append(c)
    elif modo == "tronco":
        r = 0.22
        pts = [Vector((x, y, z)) for x in (-r, r) for y in (-r, r) for z in (0.0, min(4.0, dim.z * 0.6))]
        c = casco(pts, nome + "_col0-convcolonly")
        if c: cols.append(c)
    # ---- visual: junta e renomeia materiais
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nome
    ob.data.name = nome
    tab = MAT_APO if apo else MAT_MIL
    usados = []
    for ms in ob.material_slots:
        mn_ = ms.material.name.split(".")[0] if ms.material else "Color"
        alvo = "ani_paleta" if animal else tab.get(mn_, "apo_paleta" if apo else "mil_paleta")
        if mn_ not in tab and not animal:
            print("MATERIAL DESCONHECIDO", nome, mn_, "->", alvo)
        m = bpy.data.materials.get(alvo) or bpy.data.materials.new(alvo)
        m.use_nodes = False
        ms.material = m
        usados.append(alvo)
    for v in ob.data.vertices:
        v.co -= off
    bpy.ops.object.select_all(action="DESELECT")
    info[nome] = {"tam": [round(dim.x, 3), round(dim.z, 3), round(dim.y, 3)], "verts": len(ob.data.vertices),
                  "mats": sorted(set(usados)), "colisao": modo, "n_col": len(cols)}
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + ".glb"), export_format="GLB", use_selection=False,
                              export_image_format="NONE", export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_animations=False, export_skins=False)
    print("OK", nome, info[nome])

if SO and os.path.exists(os.path.join(OUT, "mundo.json")):
    velho = json.load(open(os.path.join(OUT, "mundo.json"), encoding="utf-8"))
    velho.update(info)
    info = velho
with open(os.path.join(OUT, "mundo.json"), "w", encoding="utf-8") as fh:
    json.dump(info, fh, indent=1, ensure_ascii=False)
print("CONVERTIDOS", len(info))
