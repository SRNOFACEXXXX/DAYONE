# Munição do pacote do usuário (Assets/modelo das munições): um punhado de 8 cartuchos deitados sobre uma bandeja de papelão para cada
# calibre do jogo. Cada cartucho é decimado (~150 faces), escalado ao tamanho real e colorido (latão + ponta de projétil).
# Saída: game/assets/models/props/municao_9mm.glb, municao_762.glb, municao_556.glb (origem no centro da bandeja, base em y = 0).
# Uso: blender -b --factory-startup -P tools/importar_municao.py
import bpy, os, math
from mathutils import Vector as V, Matrix, Euler
RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BLEND = os.path.join(RAIZ, "Assets", "_ext", "_modelo_das_muni_es_que_deve_usar_nar_armas_ammo", "Ammo.blend")
OUT = os.path.join(RAIZ, "game", "assets", "models", "props")
CAL = {"9mm": ("9MM_Bullet", 0.029), "762": ("308_WIM_Bullet", 0.056), "556": ("243_WIM_Bullet", 0.057)}


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(nome, rgb):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*[lin(c) for c in rgb], 1)
    bs.inputs["Roughness"].default_value = 0.6
    bs.inputs["Metallic"].default_value = 0.0
    return m


for cal, (nome, comp) in CAL.items():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    src = bpy.data.objects[nome]
    for o in list(bpy.data.objects):
        if o != src:
            bpy.data.objects.remove(o)
    bpy.context.view_layer.objects.active = src
    mod = src.modifiers.new("d", "DECIMATE"); mod.ratio = 0.12
    bpy.ops.object.modifier_apply(modifier="d")
    src.parent = None
    lo = V((1e9,) * 3); hi = V((-1e9,) * 3)
    for v in src.data.vertices:
        lo = V(map(min, lo, v.co)); hi = V(map(max, hi, v.co))
    d = hi - lo
    eixo = max(range(3), key=lambda i: d[i])
    esc = comp / d[eixo]
    src.data.transform(Matrix.Translation(-(lo + hi) / 2))
    src.data.transform(Matrix.Scale(esc, 4))
    if eixo == 2:   # cartucho em pé (+Z): deita ao longo de +Y
        src.data.transform(Matrix.Rotation(math.radians(-90), 4, "X"))
    elif eixo == 0:
        src.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
    src.data.materials.clear()
    src.data.materials.append(mat("latao", (0.78, 0.60, 0.22)))
    for p in src.data.polygons:
        p.use_smooth = False
    # raio do cartucho para empilhar
    raio = max(abs(v.co.x) for v in src.data.vertices)
    objs = []
    n = 0
    for fila in range(2):
        for k in range(4):
            o = src if n == 0 else src.copy()
            if n:
                o.data = src.data
                bpy.context.scene.collection.objects.link(o)
            o.location = V(((k - 1.5) * raio * 2.3, 0, raio + fila * raio * 2.0 + 0.004))
            o.rotation_euler = Euler((0, 0, 0))
            objs.append(o)
            n += 1
    larg = 4 * raio * 2.3 + 0.012
    prof = comp + 0.012
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.002))
    t = bpy.context.object
    t.scale = (larg, prof, 0.004)
    t.data.materials.append(mat("papelao", (0.46, 0.34, 0.20)))
    objs.append(t)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    nm = "municao_" + cal
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nm + ".glb"), use_selection=True, export_format="GLB", export_yup=True)
    print("MUNICAO", nm, "faces/cartucho=%d" % len(src.data.polygons), "raio=%.4f" % raio)
