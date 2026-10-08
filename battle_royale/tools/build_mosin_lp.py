"""Mosin-Nagant low poly à mão (docs/ref/mosin_lowpoly.png) + braços/mãos em 1ª pessoa (manga camuflada, luvas pretas).
Base: blender/build_mosin.py (mesmas dimensões e nomes de nós: BoltAssembly, Optic, eixo -Z = cano, +Y = cima), com as cores corrigidas
(o mosin.glb anterior saía com material cinza padrão) e paleta da referência: coronha/guarda-mão laranja, metal azul-acinzentado escuro.
Saídas: game/assets/models/weapons/mosin.glb e game/assets/models/weapons/mosin_bracos.glb (malha rígida no espaço da arma).
Uso: blender -b --factory-startup -P tools/build_mosin_lp.py"""
import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
import sys, os
sys.path.insert(0, str(Path(__file__).resolve().parent))
OUT = ROOT / "game/assets/models/weapons/mosin.glb"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, color, metallic=0.0, roughness=0.72):
    color = tuple(lin(c) for c in color)   # cores escritas em sRGB
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    if p is None:
        p = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        output = m.node_tree.nodes.get("Material Output")
        if output is None:
            output = m.node_tree.nodes.new("ShaderNodeOutputMaterial")
        m.node_tree.links.new(p.outputs["BSDF"], output.inputs["Surface"])
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = roughness
    return m


wood = mat("Walnut wood", (0.74, 0.40, 0.16), 0.0, 0.8)
wood_dark = mat("End grain", (0.56, 0.29, 0.11), 0.0, 0.8)
steel = mat("Blued steel", (0.30, 0.34, 0.38), 0.0, 0.6)
edge = mat("Steel highlights", (0.52, 0.55, 0.56), 0.0, 0.5)
glass = mat("Dark optic glass", (0.10, 0.22, 0.30), 0.0, 0.3)
rubber = mat("Black rubber", (0.12, 0.12, 0.12))


def cube(name, loc, scale, material, bevel=0.0, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new("Soft machined edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.data.set_sharp_from_angle()
    o.data.materials.append(material)
    if parent:
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    return o


def rod(name, loc, radius, depth, material, verts=10, parent=None, axis="Z"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    if axis == "Z":
        pass  # o cilindro já nasce com eixo Z = eixo do cano (o glb anterior girava 90° aqui e deixava cano/ótica na vertical)
    elif axis == "X":
        o.rotation_euler.y = math.pi / 2
    o.data.materials.append(material)
    if parent:
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    return o


# -Z is muzzle direction, +Y is up; a compact single material palette.
cube("Buttstock", (0, -0.075, 0.22), (0.105, 0.18, 0.55), wood, .018)
cube("Buttplate", (0, -0.07, 0.505), (0.112, 0.19, 0.025), steel, .004)
cube("Wrist", (0, -0.105, -0.10), (.08, .11, .28), wood, .012)
cube("Forestock", (0, -0.068, -0.62), (.09, .13, .75), wood, .012)
cube("Upper handguard", (0, .018, -.65), (.085, .047, .57), wood_dark, .009)
rod("Long barrel", (0, .034, -.77), .018, .88, steel, 10)
rod("Muzzle crown", (0, .034, -1.211), .022, .035, edge, 10)
cube("Receiver", (0, .033, -.31), (.09, .085, .24), steel, .007)
cube("Magazine floor", (0, -.105, -.32), (.072, .085, .17), steel, .005)
cube("Trigger guard", (0, -.16, -.19), (.07, .018, .13), steel, .004)
cube("Trigger", (0, -.135, -.23), (.012, .07, .014), edge, .002)
for z in (-.52, -.83):
    cube("Barrel band", (0, -.012, z), (.099, .105, .032), steel, .006)

# Bolt assembly is kept as a named glTF node for procedural cycling in Godot.
bolt = bpy.data.objects.new("BoltAssembly", None)
bpy.context.collection.objects.link(bolt)
bolt.location = (0, .075, -.28)
rod("Bolt body", (0, .075, -.28), .023, .22, edge, 8, bolt)
rod("Bolt handle", (.075, .069, -.20), .011, .15, edge, 8, bolt, "X")
rod("Bolt knob", (.15, .069, -.20), .027, .035, steel, 8, bolt, "X")

# Open notch and protected front post remain visible when the optic is hidden.
cube("Rear sight base", (0, .095, -.46), (.07, .025, .07), steel, .004)
for x in (-.024, .024):
    cube("Rear sight ear", (x, .12, -.46), (.012, .038, .025), edge, .002)
cube("Front sight base", (0, .075, -1.13), (.055, .03, .035), steel, .003)
cube("Front sight post", (0, .12, -1.13), (.007, .07, .013), edge, .001)
for x in (-.028, .028):
    cube("Front sight guard", (x, .11, -1.13), (.008, .065, .012), steel, .001)

optic = bpy.data.objects.new("Optic", None)
bpy.context.collection.objects.link(optic)
optic.location = (0, .16, -.37)
rod("ACOG housing", (0, .16, -.37), .047, .19, steel, 12, optic)
rod("ACOG eyepiece", (0, .16, -.255), .037, .015, rubber, 12, optic)
rod("ACOG front glass", (0, .16, -.47), .033, .006, glass, 12, optic)
cube("Optic mount", (0, .105, -.37), (.05, .07, .085), steel, .004, optic)

# Blender uses Z-up while the authored dimensions above use Godot's Y-up.
# Rotating the common root makes glTF's axis conversion preserve the intended
# +Y sight height and -Z muzzle direction in Godot.
axis_root = bpy.data.objects.new("MosinAxisRoot", None)
bpy.context.collection.objects.link(axis_root)
for obj in list(bpy.context.scene.objects):
    if obj != axis_root and obj.parent is None:
        obj.parent = axis_root
axis_root.rotation_euler.x = math.pi / 2

OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "blender/mosin_source.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_apply=True,
                          export_yup=True, export_materials="EXPORT", export_animations=False)
print("MOSIN_EXPORT", OUT)

# ------------------------------------------------------------------ braços em 1ª pessoa (espaço da arma; o viewmodel já posiciona a arma)
import build_soldado as S
from mathutils import Vector as V

bpy.ops.wm.read_factory_settings(use_empty=True)
camo_img, pal_img = S.make_camo(), S.make_paleta()
m = S.Malha()
PAL = 1


def manga(p0, p1, r0, r1, off):
    d = (p1 - p0).normalized()
    u = d.cross(V((0, 1, 0))).normalized()
    v = d.cross(u).normalized()
    an = [m.anel(p0, u, v, r0, r0, {}, 8, 0.0), m.anel(p0 + (p1 - p0) * 0.5, u, v, (r0 + r1) / 2, (r0 + r1) / 2, {}, 8, 0.0), m.anel(p1, u, v, r1, r1, {}, 8, 0.0)]
    m.tubo(an, 0, 0, off=off, tampas=(True, False))


def luva(c, cor, flip=1.0):
    """Mão fechada no guarda-mão/punho: palma (bloco), quatro dedos enrolados (bloco em 2 partes) e polegar."""
    cx, cy, cz = c
    k = 1.18   # mão um pouco maior que a real: legível em 1ª pessoa (estilo da referência)
    m.bloco((cx, cy, cz), (0.092 * k, 0.060 * k, 0.105 * k), {}, PAL, cor, topo=(0.95, 0.9))                       # palma
    m.bloco((cx + 0.05 * flip * k, cy - 0.035 * k, cz), (0.050 * k, 0.030 * k, 0.095 * k), {}, PAL, cor, topo=(1.0, 0.9))  # dedos por baixo
    m.bloco((cx + 0.085 * flip * k, cy - 0.012 * k, cz), (0.030 * k, 0.070 * k, 0.090 * k), {}, PAL, cor)                  # dedos subindo do outro lado
    m.bloco((cx - 0.03 * flip * k, cy + 0.045 * k, cz - 0.03), (0.032 * k, 0.030 * k, 0.085 * k), {}, PAL, cor, topo=(0.8, 0.8))   # polegar


# mão de apoio (esquerda): luva preta no guarda-mão; manga camuflada vindo de baixo/esquerda
L_W = V((-0.10, -0.150, -0.62))
manga(V((-0.62, -0.42, 0.30)), L_W, 0.058, 0.046, 0.0)
luva((-0.095, -0.125, -0.70), "preto", 1.0)
# mão do gatilho (direita): punho da coronha, luva preta; manga vindo de baixo/direita
R_W = V((0.062, -0.165, -0.02))
manga(V((0.40, -0.30, 0.42)), R_W, 0.052, 0.043, 0.3)
luva((0.058, -0.145, -0.085), "preto", -1.0)
m.uvscale = 0.16
me = m.fim("MosinBracos")
for nome, img, interp in (("Manga_soldado", camo_img, "Linear"), ("Luva_paleta", pal_img, "Closest")):
    mt = bpy.data.materials.new(nome)
    mt.use_nodes = True
    bs = next(n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Roughness"].default_value = 0.95
    tx = mt.node_tree.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = interp
    mt.node_tree.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
    me.materials.append(mt)
ob = bpy.data.objects.new("MosinBracos", me)
root = bpy.data.objects.new("MosinBracosRoot", None)
bpy.context.scene.collection.objects.link(root)
bpy.context.scene.collection.objects.link(ob)
ob.parent = root
root.rotation_euler.x = math.pi / 2          # mesma convenção de eixos do mosin.glb (Y-up do jogo dentro do Z-up do Blender)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(OUT.parent / "mosin_bracos.glb"), export_format="GLB", export_yup=True, export_animations=False)
print("MOSIN_BRACOS tris", sum(len(p.vertices) - 2 for p in me.polygons))
