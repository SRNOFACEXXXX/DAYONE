# Converte as armas dos pacotes do usuário (Assets/modelos das armas) para o jogo:
#   Weapons FREE (Separate_assets_fbx): AK (rifle_001), rifle de ferrolho no lugar da Mosin (sniper_rifle_001 + sight_001),
#   revólver (pistol_001), faca, machado; pacote "Meshes" (SK_*): M4, ópticas, granada RGD5, M1911.
# Saída: game/assets/models/weapons/wf/<id>.glb em escala real, cano para -Z do Godot, +Y para cima, origem no centro do
# receptor (x = 0 no eixo do cano). Imprime o perfil superior/inferior (espaço Godot) para marcar alça, massa e pegas.
# Uso: blender -b --factory-startup -P tools/importar_armas.py
import bpy, os, math, json
from mathutils import Vector as V, Matrix

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
EXT = os.path.join(RAIZ, "Assets", "_ext")
WF = os.path.join(EXT, "_ext_modelos_das_armas_source_Separate_assets_fbx", "Separate_assets_fbx")
SK = os.path.join(EXT, "_modelos_das_armas_meshes", "Meshes")
TEX_WF = os.path.join(WF, "Texture_1.png")
TEX_SK = os.path.join(EXT, "_modelos_das_armas_texture", "T_Gun.TGA")
OUT = os.path.join(RAIZ, "game", "assets", "models", "weapons", "wf")
os.makedirs(OUT, exist_ok=True)

# id -> (fbx, textura, comprimento real desejado em m (0 = manter), objetos a descartar)
ARMAS = {
    "ak47": (os.path.join(WF, "rifle_001.fbx"), TEX_WF, 0.88, []),
    "mosin": (os.path.join(WF, "sniper_rifle_001.fbx"), TEX_WF, 1.20, []),
    "revolver": (os.path.join(WF, "pistol_001.fbx"), TEX_WF, 0.28, []),
    "faca": (os.path.join(WF, "knife_001.fbx"), TEX_WF, 0.0, []),
    "machado": (os.path.join(WF, "axe_001.fbx"), TEX_WF, 0.0, []),
    "m4": (os.path.join(SK, "SK_M4_8.fbx"), TEX_SK, 0.0, []),
    "m1911": (os.path.join(SK, "SK_M1911.fbx"), TEX_SK, 0.0, []),
    "acog": (os.path.join(SK, "SK_Optic_07.fbx"), TEX_SK, 0.0, []),
    "luneta": (os.path.join(SK, "SK_Optic_02_Black.fbx"), TEX_SK, 0.0, []),
    "rgd5": (os.path.join(SK, "SK_Grenade_RGD5.fbx"), TEX_SK, 0.0, []),
    "uzi": (os.path.join(SK, "SK_Uzi.fbx"), TEX_SK, 0.47, []),
    "m249": (os.path.join(SK, "SK_M249.fbx"), TEX_SK, 1.04, []),
    "m107": (os.path.join(SK, "SK_M107.fbx"), TEX_SK, 1.45, []),
    "sg_m4": (os.path.join(SK, "SK_SG_M4.fbx"), TEX_SK, 1.0, []),
}
perfis = {}


def carregar(fbx, tex):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    img = bpy.data.images.load(tex)
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        nt = m.node_tree
        bs = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        texs = [n for n in nt.nodes if n.type == "TEX_IMAGE"]
        if not texs and bs:
            t = nt.nodes.new("ShaderNodeTexImage")
            nt.links.new(t.outputs["Color"], bs.inputs["Base Color"])
            texs = [t]
        for t in texs:
            t.image = img
            t.interpolation = "Closest"
        if bs:
            bs.inputs["Roughness"].default_value = 0.7
            bs.inputs["Metallic"].default_value = 0.0
    # remove armaduras/vazios mantendo as malhas
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            for c in o.children:
                mw = c.matrix_world.copy()
                c.parent = None
                c.matrix_world = mw
            bpy.data.objects.remove(o)


def _paleta():
    img = bpy.data.images.load(TEX_WF, check_existing=True)
    w, h = img.size
    px = list(img.pixels)
    return img, w, h, px


def _cor_em(pal, u, v):
    img, w, h, px = pal
    x = min(w - 1, max(0, int(u % 1.0 * w))); y = min(h - 1, max(0, int(v % 1.0 * h)))
    i = (y * w + x) * 4
    return px[i], px[i + 1], px[i + 2]


def _uv_da_cor(pal, alvo):
    """UV do texel da paleta mais próximo da cor alvo (linear 0..1) — procura na grade de cores sólidas."""
    img, w, h, px = pal
    melhor, uv = 9.0, (0.5, 0.5)
    for y in range(8, h, 16):
        for x in range(8, w, 16):
            i = (y * w + x) * 4
            d = sum((px[i + k] - alvo[k]) ** 2 for k in range(3))
            if d < melhor:
                melhor, uv = d, ((x + 0.5) / w, (y + 0.5) / h)
    return uv


def recolorir_mosin(obs):
    """Rifle de ferrolho do pacote -> visual de Mosin (docs/ref/mosin_lowpoly.png). Troca de cor por UV (mesma paleta):
    cores medidas nas faces do modelo (sRGB 0-255) -> cor alvo."""
    pal = _paleta()
    TROCA = {(77, 86, 90): (196, 98, 52),      # coronha ardósia -> madeira laranja
             (111, 87, 79): (196, 98, 52),     # envoltório de couro -> madeira
             (217, 243, 245): (96, 110, 124),  # cano/ferragens claras -> metal cinza-azulado
             (219, 219, 219): (70, 76, 82),    # anéis da luneta -> metal escuro
             (0, 188, 212): (30, 36, 40)}      # lente ciano -> vidro escuro
    alvo_uv = {k: _uv_da_cor(pal, tuple(c / 255 for c in v)) for k, v in TROCA.items()}
    n = 0
    for o in obs:
        uvl = o.data.uv_layers.active
        if uvl is None:
            continue
        for poly in o.data.polygons:
            us = [uvl.data[li].uv for li in poly.loop_indices]
            cu = sum(u.x for u in us) / len(us); cv = sum(u.y for u in us) / len(us)
            c = tuple(int(x * 255) for x in _cor_em(pal, cu, cv))
            k = next((k for k in TROCA if max(abs(c[i] - k[i]) for i in range(3)) <= 6), None)
            if k:
                for li in poly.loop_indices:
                    uvl.data[li].uv = alvo_uv[k]
                n += 1
    print("RECOLOR mosin faces=%d" % n)


def limpar_m249(obs):
    """M249: a alça tem dois anéis em fila; fica só o da frente (o de trás, mais perto do olho, tampava a visada).
    Remove as faces do anel traseiro (z Godot 0,240..0,262 acima de y 0,052) em todos os objetos."""
    import bmesh
    for o in obs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        mw = o.matrix_world
        apagar = []
        for f in bm.faces:
            ok = True
            for v in f.verts:
                w = mw @ v.co
                gz = -w.y
                if not (0.240 <= gz <= 0.275 and w.z >= 0.046):
                    ok = False
                    break
            if ok:
                apagar.append(f)
        if apagar:
            bmesh.ops.delete(bm, geom=apagar, context="FACES")
            print("M249 anel removido faces=%d em %s" % (len(apagar), o.name))
        bm.to_mesh(o.data)
        bm.free()


def iron_m107(raiz):
    """M107 não tem mira de ferro: cria alça (duas hastes com vão central) e massa (poste) sobre o trilho, que fica 2,5 cm à
    esquerda do eixo do modelo (x = -0,025). Visada horizontal: vão e ponta do poste em y = ymax + 0,017. UV = texel escuro da paleta."""
    import bmesh
    pal = _paleta()
    uv = _uv_da_cor(pal, (0.22, 0.22, 0.24))
    x, y0 = -0.025, 0.049
    me = bpy.data.meshes.new("iron_m107")
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")

    def caixa_(x0, x1, ya, yb, z0, z1):
        v = [bm.verts.new((px, -pz, py)) for (px, py, pz) in
             [(x0, ya, z0), (x1, ya, z0), (x1, yb, z0), (x0, yb, z0), (x0, ya, z1), (x1, ya, z1), (x1, yb, z1), (x0, yb, z1)]]
        for q in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2)]:
            f = bm.faces.new([v[i] for i in q])
            for l in f.loops:
                l[uvl].uv = uv

    # alça: base + duas hastes (vão central de 8 mm, fundo a 8 mm do trilho) em z = 0,235
    caixa_(x - 0.011, x + 0.011, y0, y0 + 0.008, 0.228, 0.242)
    caixa_(x - 0.0095, x - 0.0040, y0, y0 + 0.027, 0.228, 0.242)
    caixa_(x + 0.0040, x + 0.0095, y0, y0 + 0.027, 0.228, 0.242)
    # massa: base + poste, ponta em y0 + 0,017, em z = -0,43 (ponta do trilho)
    caixa_(x - 0.007, x + 0.007, y0, y0 + 0.006, -0.44, -0.42)
    caixa_(x - 0.0013, x + 0.0013, y0, y0 + 0.017, -0.434, -0.426)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("iron_m107", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("iron")
    mat.use_nodes = True
    nt = mat.node_tree
    bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = pal[0]; t.interpolation = "Closest"
    nt.links.new(t.outputs["Color"], bs.inputs["Base Color"])
    me.materials.append(mat)
    ob.parent = raiz
    return ob


def caixa(obs):
    lo = V((1e9,) * 3); hi = V((-1e9,) * 3)
    for o in obs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = V(map(min, lo, w)); hi = V(map(max, hi, w))
    return lo, hi


def converter(aid, fbx, tex, comp, fora):
    carregar(fbx, tex)
    obs = [o for o in bpy.data.objects if o.type == "MESH" and o.name not in fora]
    if aid == "mosin":
        recolorir_mosin(obs)
    tops = [o for o in obs if o.parent is None or o.parent not in obs]
    lo, hi = caixa(obs)
    esc = comp / (hi.x - lo.x) if comp > 0 else 1.0
    cx = (lo.x + hi.x) / 2
    # raiz: cano (+X) -> +Y do Blender (= -Z do Godot); centro no meio do comprimento, eixo do cano em y = 0
    raiz = bpy.data.objects.new(aid, None)
    bpy.context.scene.collection.objects.link(raiz)
    R = Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Scale(esc, 4) @ Matrix.Translation(V((-cx, -(lo.y + hi.y) / 2, 0)))
    for o in tops:
        mw = o.matrix_world.copy()
        o.parent = raiz
        o.matrix_world = R @ mw
    bpy.context.view_layer.update()
    if aid == "m249":
        limpar_m249(obs)
    if aid == "m107":
        obs.append(iron_m107(raiz))
    # perfil no espaço Godot (x, y, z) = (bx, bz, -by), fatias de 1 cm em z
    prof = {}
    for o in obs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            gx, gy, gz = w.x, w.z, -w.y
            k = int(math.floor(gz * 100))
            p = prof.setdefault(k, [9.0, -9.0, 0.0])
            p[0] = min(p[0], gy); p[1] = max(p[1], gy); p[2] = max(p[2], abs(gx))
    perfis[aid] = {"escala": esc, "partes": [o.name for o in obs], "perfil_cm": {k: [round(a * 100, 1), round(b * 100, 1), round(c * 100, 1)] for k, (a, b, c) in sorted(prof.items())}}
    for o in bpy.data.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, aid + ".glb"), use_selection=True, export_format="GLB", export_yup=True,
                              export_image_format="AUTO")
    print("ARMA", aid, "escala=%.3f" % esc, "partes=", [o.name for o in obs])


for aid, (fbx, tex, comp, fora) in ARMAS.items():
    if os.path.exists(fbx):
        converter(aid, fbx, tex, comp, fora)
    else:
        print("FALTA", aid, fbx)
with open(os.path.join(OUT, "perfis.json"), "w", encoding="utf-8") as f:
    json.dump(perfis, f, indent=1)
