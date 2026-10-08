# Braços em primeira pessoa (viewmodel) por arma, a partir dos braços do personagem do time.
# Espaço FP no Blender: câmera na origem, olhando +Y, cima +Z, direita +X  (vira -Z no Godot).
# Cada arma: braços (malha do corpo só dos braços + mangas) + arma + animações keyframe:
#   idle, draw, fire, reload, inspect (armas) | idle, draw, slash_a, slash_b, stab (faca) | idle, draw (bomba)
# Uso: blender -b --factory-startup -P build_fp.py -- <weapons_dir>
import bpy, bmesh, sys, os, math, json
from mathutils import Vector, Matrix, Quaternion, Euler

argv = sys.argv[sys.argv.index("--") + 1:]
WDIR = argv[0]
SRC = r"C:\Users\satoshi\Desktop\Assets\apocalypse_free.blend"
FPS = 30

# posição de cada arma no espaço FP (origem da arma = 35% do comprimento a partir da traseira, na linha do cano)
WEAPONS = {
    # nome: (glb, time_das_mangas, pos, rot_extra_graus(z,x), grip_rel, fore_rel, kind)
    "ak47": ("ak47.glb", "terrorist", (0.092, 0.40, -0.122), (-3.0, 1.5), (0.0, -0.07, -0.085), (-0.035, 0.22, -0.045), "rifle"),
    "m4": ("m4.glb", "counter", (0.092, 0.40, -0.125), (-3.0, 1.5), (0.0, -0.07, -0.085), (0.0, 0.24, -0.045), "rifle"),
    "pistol": ("pistol.glb", "terrorist", (0.085, 0.38, -0.105), (-4.0, 2.0), (0.0, -0.085, -0.03), (0.02, -0.075, -0.05), "pistol"),
    "pistol_ct": ("pistol_ct.glb", "counter", (0.085, 0.38, -0.105), (-4.0, 2.0), (0.0, -0.085, -0.03), (0.02, -0.075, -0.05), "pistol"),
    "knife": ("knife.glb", "terrorist", (0.11, 0.28, -0.118), (-10.0, 12.0), (0.0, -0.02, 0.0), None, "knife"),
    "bomb": ("bomb.glb", "terrorist", (0.02, 0.38, -0.165), (0.0, 25.0), (0.11, 0.0, 0.03), (-0.11, 0.0, 0.03), "bomb"),
}
SLEEVES = {"terrorist": (0x3A, 0x2A, 0x22), "counter": (0x2C, 0x30, 0x29)}
FINGER_CURL = float(os.environ.get("FP_CURL", "1.0"))   # eixo Z positivo fecha para dentro (testado: X abre em leque)   # rad
CURL_AXIS = os.environ.get("FP_CURL_AXIS", "Z")
FOREARM_STRETCH = float(os.environ.get("FP_STRETCH", "1.0"))   # 1,25 testado: a mão ainda não envolve o punho (alvo/cotovelo), reverter
ARM_DROP = float(os.environ.get("FP_ARM_DROP", "0.12"))   # baixa os cotovelos para a borda inferior da câmera sem mover a arma
KEEP_BONES = ("Shoulder", "Arm", "ForeArm", "Hand")


def set_action(ob, act):
    ob.animation_data_create()
    ob.animation_data.action = act
    if act is not None and len(getattr(act, "slots", [])):
        try:
            ob.animation_data.action_slot = act.slots[0]
        except Exception:
            pass


def build(name):
    glb, team, pos, rot_extra, grip_rel, fore_rel, kind = WEAPONS[name]
    bpy.ops.wm.open_mainfile(filepath=SRC)
    scn = bpy.context.scene
    scn.render.fps = FPS
    arm = bpy.data.objects["Adult_Woodcutter"]
    arm.data.pose_position = "POSE"
    for o in list(bpy.data.objects):
        if o is arm or (o.parent is arm and o.name in ("Adult_Male_Body", "Outwear_Adult_Male")):
            continue
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    arm.animation_data_create(); arm.animation_data.action = None
    for tr in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(tr)
    # --- só os braços: remove faces cujo osso dominante não é do braço
    for mname in ("Adult_Male_Body", "Outwear_Adult_Male"):
        o = bpy.data.objects[mname]
        me = o.data
        gname = {g.index: g.name for g in o.vertex_groups}
        bm = bmesh.new(); bm.from_mesh(me)
        dl = bm.verts.layers.deform.active
        kill = []
        fallback_side = {}
        for f in bm.faces:
            ws = {}
            for v in f.verts:
                for gi, w in v[dl].items():
                    n = gname.get(gi, "")
                    ws[n] = ws.get(n, 0.0) + w
            dom = max(ws, key=ws.get) if ws else ""
            arm_side = next((side for side in ("Left", "Right") if dom.startswith(side)), "")
            side_groups = [gi for gi, group_name in gname.items() if group_name.startswith(arm_side) and any(k in group_name for k in ("ForeArm", "Hand"))] if arm_side else []
            leaking_boundary = False
            for v in f.verts:
                weights = v[dl]
                total = sum(weights.values())
                arm_weight = sum(weight for gi, weight in weights.items() if gi in side_groups)
                if total > 0.0 and arm_weight / total < 0.2:
                    leaking_boundary = True
                    break
            if not arm_side or not any(dom[len(arm_side):].startswith(k) for k in ("ForeArm", "Hand")) or leaking_boundary:
                kill.append(f)
            else:
                # Preserve which arm owns boundary vertices before trimming non-arm weights.
                for v in f.verts:
                    fallback_side[v] = arm_side
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        # pesos só nos ossos do próprio braço (antebraço/mão/dedos), normalizados e no máx. 4:
        # restos de peso no tronco/ombro esticavam a manga em "espetos" quando o braço se estende
        for v in bm.verts:
            d = v[dl]
            items = [(gi, w) for gi, w in d.items() if any(k in gname.get(gi, "") for k in ("ForeArm", "Hand"))]
            items.sort(key=lambda x: -x[1])
            items = items[:4]
            tot = sum(w for _, w in items)
            for gi in list(d.keys()):
                del d[gi]
            if tot > 0:
                for gi, w in items:
                    d[gi] = w / tot
            else:
                # Faces can straddle the sleeve cut: pruning torso/upper-arm influences
                # left some vertices unweighted, which stretched giant triangles into view.
                side = fallback_side.get(v, "Left" if v.co.x >= 0.0 else "Right")
                fallback = next((gi for gi, group_name in gname.items() if group_name == side + "ForeArm"), None)
                if fallback is not None:
                    d[fallback] = 1.0
        bm.to_mesh(me); bm.free()
    # material: pele original + mangas na cor do time (UV colapsado numa textura 4x4 de 1 cor)
    img = bpy.data.images.new("manga_" + team, 4, 4)
    r, g, b = SLEEVES[team]
    img.pixels = [r / 255, g / 255, b / 255, 1.0] * 16
    img.filepath_raw = os.path.join(WDIR, "manga_%s.png" % team); img.file_format = "PNG"; img.save()
    msl = bpy.data.materials.new("Manga_" + team); msl.use_nodes = True
    bs = next(n for n in msl.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tx = msl.node_tree.nodes.new("ShaderNodeTexImage"); tx.image = img
    msl.node_tree.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
    clean = bpy.data.materials["Color"]
    for mname in ("Adult_Male_Body", "Outwear_Adult_Male"):
        o = bpy.data.objects[mname]
        me = o.data
        gname = {g.index: g.name for g in o.vertex_groups}
        me.materials.clear(); me.materials.append(clean); me.materials.append(msl)
        for p in me.polygons:
            ws = {}
            for vi in p.vertices:
                for ge in me.vertices[vi].groups:
                    ws[gname.get(ge.group, "")] = ws.get(gname.get(ge.group, ""), 0.0) + ge.weight
            dom = max(ws, key=ws.get) if ws else ""
            tot = sum(ws.values()) or 1.0
            hand_share = sum(w for n, w in ws.items() if "Hand" in n) / tot
            if mname == "Outwear_Adult_Male" or hand_share < 0.85:
                p.material_index = 1
                for lay in me.uv_layers:
                    for li in p.loop_indices:
                        lay.data[li].uv = (0.5, 0.5)
            else:
                p.material_index = 0
    # --- coloca os braços no espaço FP: personagem olha -Y -> gira 180° para olhar +Y; ombros atrás/abaixo da câmera
    arm.rotation_euler = (0, 0, math.radians(180))
    # braços do modelo são curtos: na pistola (braços estendidos) o viewmodel usa braços ~20% maiores
    # (só antebraço/mão aparecem, o aumento não se nota) para a mão alcançar o punho
    sc = 1.057   # testado 1,26 na pistola: mão ainda não alcança e a manga corta perto da câmera
    arm.scale = (sc, sc, sc)
    bpy.context.view_layer.update()
    neck = arm.matrix_world @ arm.data.bones["Neck"].head_local
    head = arm.matrix_world @ arm.data.bones["Head"].head_local
    eye = head + Vector((0, 0.09, 0.07))   # olho ~9 cm à frente e 7 cm acima da base da cabeça
    arm.location = arm.location - eye + Vector((0, -0.02, -ARM_DROP))
    bpy.context.view_layer.update()
    # --- arma
    bpy.ops.import_scene.gltf(filepath=os.path.join(WDIR, glb))
    roots = [o for o in scn.objects if o.parent is None and o is not arm and o.type in ("MESH", "EMPTY")]
    weapon = [o for o in roots if o.type == "MESH"][0]
    weapon.name = "Arma"
    weapon.rotation_mode = "XYZ"
    base_M = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(rot_extra[0]), 4, "Z") @ Matrix.Rotation(math.radians(rot_extra[1]), 4, "X")
    weapon.matrix_world = base_M
    mag = next((c for c in weapon.children if c.name.endswith("_mag")), None)
    bpy.context.view_layer.update()
    # --- IK
    P = arm.pose.bones
    for pb in P:
        pb.rotation_mode = "QUATERNION"
    tgts = {}
    for side, pole in (("Right", Vector((0.55, -0.1, -0.6))), ("Left", Vector((-0.45, 0.2, -0.65)))):
        e = bpy.data.objects.new("IK_" + side, None); scn.collection.objects.link(e)
        pe = bpy.data.objects.new("POLE_" + side, None); scn.collection.objects.link(pe); pe.location = pole
        c = P[side + "ForeArm"].constraints.new("IK"); c.target = e; c.chain_count = 3; c.pole_target = pe; c.pole_angle = math.radians(-90)
        tgts[side] = e
    # pistola: a mão direita copia a orientação relativa à arma medida no AK (pegada que funciona)
    rel_path = os.path.normpath(os.path.join(WDIR, "..", "..", "..", "..", "raw", "fp_debug", "hand_rel.json"))
    rot_tgts = {}
    hand_rel = json.load(open(rel_path)) if (kind == "pistol" and os.path.exists(rel_path)) else {}
    for side in hand_rel:
        e2 = bpy.data.objects.new("ROT_" + side, None); scn.collection.objects.link(e2)
        c2 = P[side + "Hand"].constraints.new("COPY_ROTATION"); c2.target = e2
        rot_tgts[side] = (e2, Matrix(hand_rel[side]))
    def wpos(M, rel):
        return M @ Vector(rel)

    # ---------------- timeline de animações: cada clipe = função(t) -> (M_arma, M_mag_rel, alvo_dir, alvo_esq)
    clips = {}
    def rest(t):
        return base_M
    grip_rel_v = Vector(grip_rel)
    fore_rel_v = Vector(fore_rel) if fore_rel else None
    left_idle = Vector((-0.2, 0.18, -0.42))   # mão livre (faca) fora da tela, embaixo à esquerda

    def hands(M, mag_rel=None, left_override=None):
        r = wpos(M, grip_rel_v)
        if left_override is not None:
            l = left_override
        elif fore_rel_v is not None:
            l = wpos(M, fore_rel_v)
        else:
            l = left_idle
        return r, l

    def ease(x):
        x = max(0.0, min(1.0, x)); return x * x * (3 - 2 * x)

    def M_off(dx=0, dy=0, dz=0, rz=0, rx=0, ry=0):
        return Matrix.Translation(Vector((dx, dy, dz))) @ base_M @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(rx), 4, "X") @ Matrix.Rotation(math.radians(ry), 4, "Y")

    # idle: respiração lenta (2 s)
    clips["idle"] = (2.0, lambda t: (M_off(dz=math.sin(t / 2.0 * math.tau) * 0.0025, rx=math.sin(t / 2.0 * math.tau) * 0.4), None, None))
    # draw: sobe de baixo girando (0,6 s)
    clips["draw"] = (0.6, lambda t: (M_off(dz=-0.22 * (1 - ease(t / 0.6)), dy=-0.05 * (1 - ease(t / 0.6)), rx=-45 * (1 - ease(t / 0.6)), ry=20 * (1 - ease(t / 0.6))), None, None))
    if kind in ("rifle", "pistol"):
        k = 1.0 if kind == "rifle" else 1.5
        def fire(t):
            a = math.exp(-t * 28.0) * (1 - math.exp(-t * 90.0)) * 2.2
            return (M_off(dy=-0.035 * a * k, dz=0.006 * a, rx=4.0 * a * k), None, None)
        clips["fire"] = (0.18, fire)
        L = 2.45 if name == "ak47" else (3.05 if name == "m4" else 2.2)
        def reload(t):
            p = t / L
            # arma inclina para a esquerda e desce; mão esquerda tira o carregador, pega outro, encaixa; puxa o ferrolho (fuzil)
            tilt = ease(p / 0.15) * (1 - ease((p - 0.82) / 0.18))
            M = M_off(dz=-0.04 * tilt, dx=-0.02 * tilt, ry=-22 * tilt, rx=6 * tilt)
            mag_rel = Vector((0, 0, 0))
            if 0.15 < p < 0.62:
                q = (p - 0.15) / 0.47
                mag_rel = Vector((0, 0.02 * q, -0.35 * ease(q / 0.35) + 0.35 * ease((q - 0.55) / 0.45)))
            left = None
            if mag and fore_rel_v is not None:
                mw_mag_center = M @ (mag.matrix_local.translation + mag_rel + Vector((0.0, 0.0, -0.06)))
                if 0.12 < p < 0.72:
                    left = mw_mag_center + Vector((-0.02, -0.03, -0.03))
                if 0.3 < p < 0.5:
                    left = Vector((-0.05, 0.2, -0.45))    # mão desce para o colete buscar outro
            return (M, mag_rel, left)
        clips["reload"] = (L, reload)
        def inspect(t):
            p = t / 2.4
            tw = ease(p / 0.25) * (1 - ease((p - 0.7) / 0.3))
            return (M_off(dx=-0.05 * tw, dz=0.02 * tw, ry=65 * tw, rz=18 * tw), None, None)
        clips["inspect"] = (2.4, inspect)
    elif kind == "knife":
        def slash(side):
            def f(t):
                p = t / 0.45
                s = math.sin(min(p, 1.0) * math.pi)
                return (M_off(dx=-0.22 * s * side, dy=0.1 * s, dz=0.06 * s, rz=70 * s * side, ry=-30 * s * side), None, None)
            return f
        clips["slash_a"] = (0.45, slash(1))
        clips["slash_b"] = (0.45, slash(-1))
        def stab(t):
            p = t / 0.9
            s = ease(p / 0.3) * (1 - ease((p - 0.55) / 0.45))
            return (M_off(dx=-0.1 * s, dy=0.25 * s, dz=0.05 * s, rx=-60 * s), None, None)
        clips["stab"] = (0.9, stab)
    # ---------------- bake: poses por quadro (IK -> keyframes) + transformação da arma e do carregador
    arm_acts = {}
    bpy.context.evaluated_depsgraph_get().update()
    if kind == "pistol" and FOREARM_STRETCH != 1.0:
        # braços do personagem são curtos para a pistola estendida: antebraço 25% mais longo (a manga estica),
        # mão sem herdar a escala (fica no tamanho normal) -> a mão alcança o punho com a arma visível
        for side in ("Left", "Right"):
            arm.data.bones[side + "Hand"].inherit_scale = "NONE"
            P[side + "ForeArm"].scale = (1.0, FOREARM_STRETCH, 1.0)
        bpy.context.view_layer.update()
    base_pose = {pb.name: pb.matrix_basis.copy() for pb in P}   # pose de partida do IK (a do 1º clipe, que funciona)
    for cname, (length, fn) in clips.items():
        n = max(2, int(round(length * FPS)) + 1)
        frames = []
        # cada clipe começa do zero: sem ação anterior avaliada e com a pose de descanso (IK determinístico, sem cotovelo virando)
        for ob in (arm, weapon, mag):
            if ob is not None and ob.animation_data:
                ob.animation_data.action = None
        for fi in range(n):
            t = fi / FPS
            for pb in P:
                pb.matrix_basis = base_pose[pb.name]
                # dedos fechados em volta do punho/guarda-mão (antes: "luva" de dedos esticados)
                if kind in ("rifle", "pistol", "knife") and any(("Hand" + f) in pb.name for f in ("Index", "Middle", "Ring", "Pinky")) and pb.name[-1] in "12":
                    ang = FINGER_CURL * (1.0 if pb.name.endswith("1") else 0.85)
                    pb.matrix_basis = base_pose[pb.name] @ Matrix.Rotation(ang, 4, CURL_AXIS)
            M, mag_rel, left = fn(t)
            r, l = hands(M, mag_rel, left)
            tgts["Right"].location = r
            tgts["Left"].location = l
            for side, (e2, R) in rot_tgts.items():
                e2.matrix_world = (M.to_3x3() @ R).to_4x4()
            weapon.matrix_world = M
            if mag is not None:
                mag.matrix_basis = Matrix.Translation(mag_rel if mag_rel is not None else Vector((0, 0, 0))) @ Matrix.Identity(4) if False else mag.matrix_basis
            bpy.context.evaluated_depsgraph_get().update()
            if name == "ak47" and cname == "idle" and fi == 0:
                rel = {}
                for side in ("Right",):
                    hw = (arm.matrix_world @ P[side + "Hand"].matrix).to_3x3().normalized()
                    rel[side] = [list(row) for row in (M.to_3x3().normalized().inverted() @ hw)]
                # Keep diagnostic hand-pose data local to the existing project state;
                # this refinement build must only emit the selected weapon asset.
                if os.environ.get("FP_WRITE_HAND_REL") == "1":
                    os.makedirs(os.path.dirname(rel_path), exist_ok=True)
                    json.dump(rel, open(rel_path, "w"))
            if os.environ.get("FP_DEBUG") and cname == "idle" and fi == 0:
                for side, (e2, R) in rot_tgts.items():
                    hw = (arm.matrix_world @ P[side + "Hand"].matrix).to_3x3().normalized()
                    print("DBG_ROT", side, "hand=", [round(v, 2) for v in hw.to_euler()], "target=", [round(v, 2) for v in e2.matrix_world.to_euler()], "constraints=", [(c.type, c.mute, c.influence) for c in P[side + "Hand"].constraints])
                debug_render(scn, arm, weapon, r, l, name)
            mats = {pb.name: arm.convert_space(pose_bone=pb, matrix=pb.matrix, from_space="POSE", to_space="LOCAL") for pb in P}
            frames.append((fi, mats, M.copy(), mag_rel.copy() if mag_rel is not None else None))
        act = bpy.data.actions.new(cname)
        wact = bpy.data.actions.new(cname + "__arma")
        mact = bpy.data.actions.new(cname + "__mag") if mag is not None else None
        for c in P[ "RightForeArm"].constraints: c.mute = True
        for side in rot_tgts:
            for c in P[side + "Hand"].constraints: c.mute = True
        for c in P[ "LeftForeArm"].constraints: c.mute = True
        set_action(arm, act)
        for fi, mats, M, mag_rel in frames:
            for bn, m in mats.items():
                P[bn].matrix_basis = m
                P[bn].keyframe_insert("rotation_quaternion", frame=fi + 1)
                P[bn].keyframe_insert("location", frame=fi + 1)
        set_action(weapon, wact)
        for fi, mats, M, mag_rel in frames:
            weapon.matrix_world = M
            weapon.keyframe_insert("location", frame=fi + 1)
            weapon.keyframe_insert("rotation_euler", frame=fi + 1)
        if mact is not None:
            mag0 = mag.location.copy()
            set_action(mag, mact)
            for fi, mats, M, mag_rel in frames:
                mag.location = mag0 + (mag_rel if mag_rel is not None else Vector((0, 0, 0)))
                mag.keyframe_insert("location", frame=fi + 1)
            mag.location = mag0
        for c in P["RightForeArm"].constraints: c.mute = False
        for side in rot_tgts:
            for c in P[side + "Hand"].constraints: c.mute = False
        for c in P["LeftForeArm"].constraints: c.mute = False
        arm_acts[cname] = (act, wact, mact)
    for side in rot_tgts:
        for c in list(P[side + "Hand"].constraints):
            P[side + "Hand"].constraints.remove(c)
        bpy.data.objects.remove(rot_tgts[side][0])
    # remove IK e empties
    for side in ("Right", "Left"):
        for c in list(P[side + "ForeArm"].constraints):
            P[side + "ForeArm"].constraints.remove(c)
    for o in list(scn.objects):
        if o.name.startswith("IK_") or o.name.startswith("POLE_"):
            bpy.data.objects.remove(o)
    # NLA por objeto com o MESMO nome de trilha: o exportador glTF junta em uma animação por nome
    for ob, idx in ((arm, 0), (weapon, 1), (mag, 2)):
        if ob is None:
            continue
        ob.animation_data_create()
        for cname, acts in arm_acts.items():
            a = acts[idx]
            if a is None:
                continue
            tr = ob.animation_data.nla_tracks.new(); tr.name = cname
            st = tr.strips.new(cname, 1, a)
            if len(getattr(a, "slots", [])):
                try:
                    st.action_slot = a.slots[0]
                except Exception:
                    pass
        ob.animation_data.action = None
    bpy.ops.object.select_all(action="DESELECT")
    for o in scn.objects:
        if o.type in ("MESH", "ARMATURE", "EMPTY"):
            o.select_set(True)
    out = os.path.join(WDIR, name + "_fp.glb")
    bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_format="GLB", export_yup=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_skins=True,
                              export_def_bones=False, export_extras=True, export_merge_animation="NLA_TRACK")
    print("FP_DONE", name, list(clips.keys()))



def debug_render(scn, arm, weapon, r, l, name):
    """Depuração: esferas nos alvos das mãos + renders lateral/superior/olho (Workbench)."""
    out = os.path.join(os.path.dirname(WDIR), "..", "..", "..", "raw", "fp_debug")
    out = os.path.normpath(out); os.makedirs(out, exist_ok=True)
    mats = []
    for pos, col in ((r, (1, 0, 0, 1)), (l, (0, 0, 1, 1))):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, location=pos)
        sp = bpy.context.active_object
        m = bpy.data.materials.new("dbg"); m.diffuse_color = col; sp.data.materials.append(m); mats.append(sp)
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.color_type = "MATERIAL"
    scn.render.resolution_x, scn.render.resolution_y = 800, 600
    scn.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("dbgcam"); cam = bpy.data.objects.new("dbgcam", cam_data); scn.collection.objects.link(cam)
    scn.camera = cam
    from mathutils import Vector
    tgt = weapon.matrix_world.translation
    for view, loc in (("side", tgt + Vector((0.8, 0.0, 0.0))), ("top", tgt + Vector((0.0, 0.0, 0.8))), ("eye", Vector((0, 0, 0)))):
        cam.location = loc
        d = (tgt - loc) if view != "eye" else Vector((0, 1, 0))
        cam.rotation_euler = d.to_track_quat("-Z", "Y" if view != "top" else "Y").to_euler()
        cam_data.lens = 35 if view != "eye" else 20
        scn.render.filepath = os.path.join(out, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)
    for sp in mats:
        bpy.data.objects.remove(sp)
    bpy.data.objects.remove(cam)
    print("FP_DEBUG_DONE", out)

for n in (sys.argv[sys.argv.index("--") + 2:] or list(WEAPONS.keys())):
    build(n)
