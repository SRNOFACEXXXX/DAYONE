# Converte um asset (braços FPS + arma + animações, ou só um modelo) para a estética low poly do jogo:
#   1) reduz a malha (Decimate collapse; pesos de osso e UV são interpolados, então a animação continua valendo);
#   2) cor por FACE amostrada da textura base (centro da face) e agrupada em poucas cores (k-means por material),
#      sem texturas: cada grupo vira um material de cor chapada;
#   3) sombreamento flat (facetado).
# Mantém armadura e todas as ações; exporta GLB.
# Uso: blender -b --factory-startup -P tools/lowpolyfy.py -- <entrada.fbx|glb> <saida.glb> [razao=0.35] [cores=6] [--sem-osso]
import bpy, bmesh, sys, os, math, random

args = sys.argv[sys.argv.index("--") + 1:]
ENT, SAI = args[0], args[1]
RAZAO = float(args[2]) if len(args) > 2 else 0.35
CORES = int(args[3]) if len(args) > 3 else 6
IGNORAR = [a.split("=", 1)[1] for a in args if a.startswith("--ignorar=")]   # malhas a apagar (ex.: Icosphere)
def _hex(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


PALETA = {}   # --paleta=Material:#hex,#hex  (cores escolhidas à mão, do escuro ao claro; os grupos da textura são mapeados por luminância)
MANGA = {}    # --manga=Material:#hex  (faces desse material presas ao antebraço/braço viram manga de tecido)
for a in args:
    if a.startswith("--paleta="):
        k, v = a.split("=", 1)[1].split(":")
        PALETA[k] = [_hex(x) for x in v.split(",")]
    if a.startswith("--manga="):
        k, v = a.split("=", 1)[1].split(":")
        MANGA[k] = _hex(v)
SEM_VIDRO = "--sem-vidro" in args   # apaga faces cuja textura é transparente (vidro da mira)
ESCURECER = {}   # material -> fator (ex.: --escurecer=Glove_D:0.8)
for a in args:
    if a.startswith("--escurecer="):
        k, v = a.split("=", 1)[1].split(":")
        ESCURECER[k] = float(v)

bpy.ops.wm.read_factory_settings(use_empty=True)
if ENT.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=ENT, use_anim=True)
else:
    bpy.ops.import_scene.gltf(filepath=ENT)

for o in list(bpy.data.objects):
    if o.type == "MESH" and (o.name.startswith("Icosphere") or any(i in o.name for i in IGNORAR)):
        bpy.data.objects.remove(o)


def osso_pai(o):
    """(armadura, osso) se o objeto (ou um ancestral vazio) estiver preso a um osso."""
    p = o
    while p is not None:
        if p.parent is not None and p.parent_type == "BONE" and p.parent.type == "ARMATURE":
            return p.parent, p.parent_bone
        p = p.parent
    return None, None


# Peças da arma presas a ossos (Sketchfab/glTF) viram malhas com peso 100% no osso: o reexport glTF de objetos filhos de
# osso desloca as peças (cauda do osso) e a arma ia parar longe dos braços.
_arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
for a in _arms:
    a.data.pose_position = "REST"
bpy.context.view_layer.update()
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    arm, osso = osso_pai(o)
    if arm is None or any(m.type == "ARMATURE" for m in o.modifiers):
        continue
    mw = o.matrix_world.copy()
    o.data = o.data.copy()
    o.data.transform(mw)
    o.parent = None
    o.matrix_world = arm.matrix_world.copy()
    o.data.transform(arm.matrix_world.inverted())
    o.parent = arm
    o.parent_type = "OBJECT"
    o.matrix_parent_inverse = arm.matrix_world.inverted()
    vg = o.vertex_groups.new(name=osso)
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    md = o.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    print("SKIN", o.name, "->", osso)
for a in _arms:
    a.data.pose_position = "POSE"
bpy.context.view_layer.update()


def imagem_do_material(m):
    if m is None or not m.use_nodes:
        return None
    bs = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bs is None:
        return None
    lk = bs.inputs["Base Color"].links
    no = lk[0].from_node if lk else None
    while no is not None and no.type != "TEX_IMAGE":
        ent = [i for i in no.inputs if i.links]
        no = ent[0].links[0].from_node if ent else None
    if no is not None and no.image is not None and no.image.size[0] > 0:
        return no.image
    # FBX com textura não encontrada: procura <material>_D.* / <material>.* na pasta do arquivo
    pasta = os.path.dirname(ENT)
    base = m.name.split(".")[0]
    for cand in [base + "_D", base, base.replace("_D", "") + "_D"]:
        for ext in (".png", ".jpg", ".tga"):
            f = os.path.join(pasta, cand + ext)
            if os.path.exists(f):
                return bpy.data.images.load(f, check_existing=True)
    return None


def cor_base(m):
    if m is None or not m.use_nodes:
        return (0.5, 0.5, 0.5)
    bs = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    return tuple(bs.inputs["Base Color"].default_value[:3]) if bs else (0.5, 0.5, 0.5)


cache_px = {}


def pixels(img):
    if img.name not in cache_px:
        cache_px[img.name] = (img.size[0], img.size[1], img.pixels[:])
    return cache_px[img.name]


def amostra(img, u, v):
    w, h, px = pixels(img)
    x = min(w - 1, max(0, int((u % 1.0) * w)))
    y = min(h - 1, max(0, int((v % 1.0) * h)))
    i = (y * w + x) * 4
    return (px[i], px[i + 1], px[i + 2], px[i + 3])


def kmeans(cores, k):
    if len(cores) <= k:
        return list(set(cores)) or [(0.5, 0.5, 0.5)]
    random.seed(1)
    cs = random.sample(cores, k)
    for _ in range(12):
        grupos = [[] for _ in cs]
        for c in cores:
            j = min(range(len(cs)), key=lambda t: sum((c[q] - cs[t][q]) ** 2 for q in range(3)))
            grupos[j].append(c)
        cs = [tuple(sum(c[q] for c in g) / len(g) for q in range(3)) if g else cs[i] for i, g in enumerate(grupos)]
    return cs


novos = {}


def material_chapado(nome, cor):
    chave = (nome, tuple(round(x, 3) for x in cor))
    if chave in novos:
        return novos[chave]
    m = bpy.data.materials.new("lp_%s_%d" % (nome, len(novos)))
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*cor, 1.0)
    bs.inputs["Roughness"].default_value = 0.85
    bs.inputs["Metallic"].default_value = 0.0
    novos[chave] = m
    return m


for ob in [o for o in bpy.data.objects if o.type == "MESH"]:
    me = ob.data
    antes = len(me.polygons)
    # 1) decimação (antes da armadura na pilha; aplicar só ela)
    if RAZAO < 0.999 and antes > 200:
        bpy.context.view_layer.objects.active = ob
        for o2 in bpy.context.selected_objects:
            o2.select_set(False)
        ob.select_set(True)
        mod = ob.modifiers.new("lp_dec", "DECIMATE")
        mod.ratio = RAZAO
        mod.use_collapse_triangulate = False
        while ob.modifiers[0].name != "lp_dec":
            bpy.ops.object.modifier_move_up(modifier="lp_dec")
        bpy.ops.object.modifier_apply(modifier="lp_dec")
    me = ob.data
    uvl = me.uv_layers.active
    # 2) cor por face
    por_mat = {}
    vidro = []
    for p in me.polygons:
        mat = me.materials[p.material_index] if p.material_index < len(me.materials) else None
        img = imagem_do_material(mat)
        if img is not None and uvl is not None and img.size[0] > 0:
            us = [uvl.data[li].uv for li in p.loop_indices]
            u = sum(x.x for x in us) / len(us)
            v = sum(x.y for x in us) / len(us)
            c4 = amostra(img, u, v)
            if SEM_VIDRO and c4[3] < 0.5:
                vidro.append(p.index)
                continue
            c = c4[:3]
            b = cor_base(mat)
            c = (c[0] * b[0], c[1] * b[1], c[2] * b[2])
        else:
            c = cor_base(mat)
        f = ESCURECER.get(mat.name if mat else "", 1.0)
        c = (c[0] * f, c[1] * f, c[2] * f)
        nm = mat.name if mat else "_"
        if nm in MANGA and ob.vertex_groups:
            soma = {}
            for vi in p.vertices:
                for g in me.vertices[vi].groups:
                    soma[g.group] = soma.get(g.group, 0.0) + g.weight
            if soma:
                dom = ob.vertex_groups[max(soma, key=soma.get)].name.lower()
                if "arm" in dom and "hand" not in dom:
                    por_mat.setdefault(nm + "_manga", []).append((p.index, MANGA[nm]))
                    continue
        por_mat.setdefault(nm, []).append((p.index, c))
    nomes = list(por_mat.keys())
    paleta = {}
    lum = lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    for n in nomes:
        if n.endswith("_manga"):
            paleta[n] = [por_mat[n][0][1]]
        elif n in PALETA:
            grupos = sorted(kmeans([c for _, c in por_mat[n]], len(PALETA[n])), key=lum)
            # recolore cada face: grupo mais próximo -> cor da paleta na mesma posição de luminância
            mapa = []
            for pi, c in por_mat[n]:
                j = min(range(len(grupos)), key=lambda t: sum((c[q] - grupos[t][q]) ** 2 for q in range(3)))
                mapa.append((pi, PALETA[n][min(j, len(PALETA[n]) - 1)]))
            por_mat[n] = mapa
            paleta[n] = list(PALETA[n])
        else:
            paleta[n] = kmeans([c for _, c in por_mat[n]], max(2, CORES))
    me.materials.clear()
    idx = {}
    for n in nomes:
        for c in paleta[n]:
            m = material_chapado(n, c)
            if m.name not in idx:
                me.materials.append(m)
                idx[m.name] = len(me.materials) - 1
    for n in nomes:
        for pi, c in por_mat[n]:
            j = min(range(len(paleta[n])), key=lambda t: sum((c[q] - paleta[n][t][q]) ** 2 for q in range(3)))
            me.polygons[pi].material_index = idx[material_chapado(n, paleta[n][j]).name]
    if vidro:
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.faces[i] for i in vidro], context="FACES")
        bm.to_mesh(me)
        bm.free()
        print("VIDRO removido", len(vidro))
    # 3) flat
    for p in me.polygons:
        p.use_smooth = False
    if hasattr(me, "use_auto_smooth"):
        me.use_auto_smooth = False
    print("LP", ob.name, antes, "->", len(me.polygons), "cores", sum(len(v) for v in paleta.values()))

# imagens não são mais usadas
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
bpy.ops.export_scene.gltf(filepath=SAI, export_format="GLB", export_yup=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True)
print("SAIDA", SAI)
