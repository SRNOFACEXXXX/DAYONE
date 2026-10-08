"""Author-made, low-poly Mosin-Nagant; run with Blender --background --python this file."""
import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/models/weapons/mosin.glb"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def mat(name, color, metallic=0.0, roughness=0.72):
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


wood = mat("Walnut wood", (0.32, 0.16, 0.075))
wood_dark = mat("End grain", (0.20, 0.095, 0.045))
steel = mat("Blued steel", (0.105, 0.13, 0.14), 0.65, 0.42)
edge = mat("Steel highlights", (0.23, 0.25, 0.24), 0.68, 0.36)
glass = mat("Dark optic glass", (0.018, 0.045, 0.064), 0.3, 0.16)
rubber = mat("Black rubber", (0.035, 0.035, 0.034))


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
        o.rotation_euler.x = math.pi / 2  # along rifle barrel, -Z
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
