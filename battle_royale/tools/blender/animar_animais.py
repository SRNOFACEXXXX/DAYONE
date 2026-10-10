"""Rig + animações automáticas para os animais estáticos do pack (Deer_001, Dog_001, Chicken_001) e um lobo (Dog_001 maior,
pelagem cinza). Esqueleto simples (corpo, pescoço, cabeça, 2 ossos por perna), pesos por região do corpo (pernas por
quadrante, cabeça na ponta -Y), clipes: parado, andar, correr, comer, morrer. Exporta GLB com skin + animações.
Uso: python tools/blender/animar_animais.py [saida]   (bpy do PyPI)  ou  blender -b --factory-startup -P ... -- [saida]
Saída padrão: game/assets/models/animais/<id>.glb"""
import bpy, math, os, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game")
OUT = args[0] if args else os.path.join(RAIZ, "assets", "models", "animais")
SRC = os.path.join(RAIZ, "assets", "models", "atualizacao", "mundo")
os.makedirs(OUT, exist_ok=True)
FPS = 30

# id: (arquivo, quadrupede, perna_frac (altura do topo da perna / altura do corpo), escala, tinta (multiplica a cor) )
ANIMAIS = {
    "cervo": ("Deer_001", True, 0.52, 1.0, None),
    "cachorro": ("Dog_001", True, 0.42, 1.0, None),
    "lobo": ("Dog_001", True, 0.42, 1.3, (0.55, 0.56, 0.6)),
    "galinha": ("Chicken_001", False, 0.32, 1.0, None),
}


def limpar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for a in list(bpy.data.armatures):
        bpy.data.armatures.remove(a)


def importar(arq):
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, arq + ".glb"))
    malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    me = malhas[0]
    bpy.ops.object.select_all(action="DESELECT")
    me.select_set(True)
    bpy.context.view_layer.objects.active = me
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me.parent = None
    return me


def medir(me):
    vs = [v.co.copy() for v in me.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return vs, mn, mx


def criar(id_, arq, quad, perna_frac, escala, tinta):
    limpar()
    me = importar(arq)
    if escala != 1.0:
        me.scale = (escala, escala, escala)
        bpy.ops.object.transform_apply(scale=True)
    if tinta:
        for m in me.data.materials:
            m2 = m.copy()
            bsdf = m2.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                tex = bsdf.inputs["Base Color"].links[0].from_node if bsdf.inputs["Base Color"].links else None
                mix = m2.node_tree.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MULTIPLY"
                mix.inputs["Factor"].default_value = 1.0
                mix.inputs["B"].default_value = (tinta[0], tinta[1], tinta[2], 1.0)
                if tex:
                    m2.node_tree.links.new(tex.outputs["Color"], mix.inputs["A"])
                m2.node_tree.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
            me.data.materials[me.data.materials.find(m.name)] = m2
    vs, mn, mx = medir(me)
    comp = mx.y - mn.y
    # altura do corpo: topo na faixa central (sem cabeça/chifres)
    meio = [v for v in vs if mn.y + comp * 0.35 <= v.y <= mn.y + comp * 0.75]
    corpo_top = max(v.z for v in meio)
    perna_top = corpo_top * perna_frac
    corpo_meio = (perna_top + corpo_top) / 2
    # pernas: vértices abaixo de perna_top; centros por quadrante
    pernas = [v for v in vs if v.z < perna_top * 0.85]
    yc = sum(v.y for v in pernas) / max(len(pernas), 1)
    def centro(fx, fy):
        sel = [v for v in pernas if (v.x >= 0) == (fx > 0) and ((v.y >= yc) == (fy > 0) if quad else True)]
        if not sel:
            return Vector((fx * (mx.x - mn.x) * 0.25, yc, 0))
        return Vector((sum(v.x for v in sel) / len(sel), sum(v.y for v in sel) / len(sel), 0))
    cps = {}
    if quad:
        for nome, fx, fy in [("fe", 1, -1), ("fd", -1, -1), ("te", 1, 1), ("td", -1, 1)]:
            cps[nome] = centro(fx, fy)
    else:
        for nome, fx in [("e", 1), ("d", -1)]:
            cps[nome] = centro(fx, 1)
    y_frente = min(c.y for c in cps.values()) if quad else yc - comp * 0.15
    y_tras = max(c.y for c in cps.values()) if quad else yc + comp * 0.2
    pesc_ini = Vector((0, y_frente - comp * (0.02 if quad else 0.0), corpo_meio + (corpo_top - corpo_meio) * 0.4))
    cab = [v for v in vs if v.y < y_frente - comp * 0.05 and v.z > corpo_meio]
    cab_c = Vector((0, sum(v.y for v in cab) / len(cab), sum(v.z for v in cab) / len(cab))) if cab else pesc_ini + Vector((0, -comp * 0.15, 0.2))

    # ---- esqueleto ----
    arm_d = bpy.data.armatures.new(id_ + "_arm")
    arm = bpy.data.objects.new(id_ + "_rig", arm_d)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_d.edit_bones
    raiz = eb.new("raiz"); raiz.head = (0, yc, 0); raiz.tail = (0, yc, perna_top * 0.5)
    corpo = eb.new("corpo"); corpo.head = (0, y_tras, corpo_meio); corpo.tail = (0, y_frente, corpo_meio); corpo.parent = raiz
    pesc = eb.new("pescoco"); pesc.head = corpo.tail; pesc.tail = pesc_ini.lerp(cab_c, 0.6); pesc.parent = corpo
    cabeca = eb.new("cabeca"); cabeca.head = pesc.tail; cabeca.tail = cab_c + Vector((0, -comp * 0.08, 0.02)); cabeca.parent = pesc
    for nome, c in cps.items():
        cima = eb.new("perna_" + nome); cima.head = (c.x, c.y, perna_top); cima.tail = (c.x, c.y, perna_top * 0.5); cima.parent = corpo
        baixo = eb.new("pe_" + nome); baixo.head = cima.tail; baixo.tail = (c.x, c.y, 0.0); baixo.parent = cima
    bpy.ops.object.mode_set(mode="OBJECT")

    # ---- pesos por região ----
    for g in list(me.vertex_groups):
        me.vertex_groups.remove(g)
    grupos = {b.name: me.vertex_groups.new(name=b.name) for b in arm_d.bones}
    for v in me.data.vertices:
        p = v.co
        if p.z < perna_top * 1.05:
            # perna mais próxima (no plano), com mistura no topo para a coxa não rasgar
            nome = min(cps, key=lambda n: (Vector((p.x, p.y)) - Vector((cps[n].x, cps[n].y))).length)
            d = (Vector((p.x, p.y)) - Vector((cps[nome].x, cps[nome].y))).length
            if d < (mx.x - mn.x) * 0.45:
                if p.z < perna_top * 0.45:
                    grupos["pe_" + nome].add([v.index], 1.0, "REPLACE")
                elif p.z < perna_top * 0.6:
                    grupos["pe_" + nome].add([v.index], 0.5, "REPLACE")
                    grupos["perna_" + nome].add([v.index], 0.5, "REPLACE")
                elif p.z < perna_top * 0.9:
                    grupos["perna_" + nome].add([v.index], 1.0, "REPLACE")
                else:
                    grupos["perna_" + nome].add([v.index], 0.5, "REPLACE")
                    grupos["corpo"].add([v.index], 0.5, "REPLACE")
                continue
        if p.y < y_frente - comp * 0.02 and p.z > corpo_meio:
            t = (y_frente - p.y) / max(y_frente - (cab_c.y - comp * 0.08), 0.01)
            if t > 0.55:
                grupos["cabeca"].add([v.index], 1.0, "REPLACE")
            elif t > 0.3:
                grupos["cabeca"].add([v.index], 0.5, "REPLACE")
                grupos["pescoco"].add([v.index], 0.5, "REPLACE")
            else:
                grupos["pescoco"].add([v.index], 1.0, "REPLACE")
            continue
        grupos["corpo"].add([v.index], 1.0, "REPLACE")
    me.parent = arm
    mod = me.modifiers.new("Armature", "ARMATURE")
    mod.object = arm

    # ---- animações ----
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    ad = arm.animation_data_create()
    pares = {"fe": 0.0, "td": 0.0, "fd": 0.5, "te": 0.5} if quad else {"e": 0.0, "d": 0.5}

    def chave(b, f, rot=None, loc=None):
        if rot is not None:
            b.rotation_euler = [math.radians(a) for a in rot]
            b.keyframe_insert("rotation_euler", frame=f)
        if loc is not None:
            b.location = loc
            b.keyframe_insert("location", frame=f)

    def nova(nome):
        act = bpy.data.actions.new(nome)
        ad.action = act
        for b in pb:
            b.rotation_euler = (0, 0, 0)
            b.location = (0, 0, 0)
        # TODO clipe fixa TODOS os ossos no quadro 1: o AnimationPlayer do Godot não zera trilhas que o clipe novo não
        # tem (a perna ficava presa na pose do clipe anterior); os quadros seguintes sobrescrevem o que o clipe anima.
        for b in pb:
            b.keyframe_insert("rotation_euler", frame=1)
        pb["raiz"].keyframe_insert("location", frame=1)
        return act

    def ciclo(nome, dur, amp_cima, amp_baixo, bob, cab_amp):
        act = nova(nome)
        n = int(dur * FPS)
        for k in range(0, n + 1, 3):
            fase = k / n
            for perna, off in pares.items():
                s = math.sin(math.tau * (fase + off))
                chave(pb["perna_" + perna], k + 1, rot=(amp_cima * s, 0, 0))
                chave(pb["pe_" + perna], k + 1, rot=(amp_baixo * max(0.0, -math.cos(math.tau * (fase + off))), 0, 0))
            chave(pb["raiz"], k + 1, loc=(0, 0, bob * abs(math.sin(math.tau * fase * 2))))
            chave(pb["cabeca"], k + 1, rot=(cab_amp * math.sin(math.tau * fase * 2), 0, 0))
        return act

    acts = [ciclo("andar", 1.0, 22, 30, 0.015, 4), ciclo("correr", 0.5, 38, 50, 0.05, 6)]
    act = nova("parado")
    for k, (r, c) in enumerate([(0, 0), (1.5, 3), (0, 0), (-1.0, -2), (0, 0)]):
        chave(pb["corpo"], k * 15 + 1, rot=(r * 0.3, 0, 0))
        chave(pb["cabeca"], k * 15 + 1, rot=(c, c * 3, 0))
    acts.append(act)
    act = nova("comer")
    for k, a in enumerate([0, 45, 50, 45, 50, 0]):
        chave(pb["pescoco"], k * 12 + 1, rot=(a, 0, 0))
        chave(pb["cabeca"], k * 12 + 1, rot=(a * 0.4, 0, 0))
    acts.append(act)
    act = nova("morrer")
    altura = corpo_meio
    for f, rol, desce, perna in [(1, 0, 0, 0), (10, 30, 0.1, 15), (22, 88, 0.55, 35), (30, 90, 0.6, 40)]:
        chave(pb["raiz"], f, rot=(0, rol, 0), loc=(0, 0, -altura * desce * 0.5))
        for perna_n in pares:
            chave(pb["perna_" + perna_n], f, rot=(perna if perna_n[0] in "ft" and quad else perna, 0, 0))
        chave(pb["pescoco"], f, rot=(-perna * 0.5, 0, 0))
    acts.append(act)
    ad.action = None
    # pose neutra antes de exportar: o exportador grava a pose ATUAL como repouso (o último clipe, "morrer", deitava o bicho)
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
    bpy.context.view_layer.update()
    for a in acts:
        tr = ad.nla_tracks.new()
        tr.name = a.name
        st = tr.strips.new(a.name, 1, a)
        st.name = a.name
        tr.mute = True
    # exportar
    bpy.ops.object.select_all(action="DESELECT")
    me.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    caminho = os.path.join(OUT, id_ + ".glb")
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
                              export_def_bones=False, export_materials="EXPORT")
    print("ANIMAL", id_, "comp=%.2f altura=%.2f perna_top=%.2f pernas=%d clipes=%s" % (comp, mx.z - mn.z, perna_top, len(cps), [a.name for a in acts]))


so = set(args[1:]) if len(args) > 1 else None
for id_, cfg in ANIMAIS.items():
    if so and id_ not in so:
        continue
    criar(id_, *cfg)
print("ANIMAIS_OK")
