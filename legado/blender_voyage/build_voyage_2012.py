"""Procedural Volkswagen Voyage-style sedan created for Blender 4.5 LTS.

Run with the installed Blender 4.5 executable:
  blender.exe -b --python build_voyage_2012.py

The scene is intentionally kept editable: major exterior parts, wheels, glass,
lights, trim, and the studio setup are separate named Blender objects.
"""

import bpy
import math
import os
from mathutils import Vector


OUT_DIR = r"C:\Users\satoshi\Documents\ChatGPT\teste"
BLEND_PATH = os.path.join(OUT_DIR, "voyage_2012.blend")
RENDER_PATH = os.path.join(OUT_DIR, "voyage_2012_preview.png")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        # Keep the script idempotent without trying to remove linked/shared data.
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def make_material(name, color, metallic=0.0, roughness=0.45, transmission=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    # Blender 4.5's fresh material node tree is normally pre-populated, but use
    # node type rather than the localized/display name so this remains reliable.
    bsdf = next((node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        output = next((node for node in mat.node_tree.nodes if node.type == "OUTPUT_MATERIAL"), None)
        if output is None:
            output = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.38 if metallic > 0.1 else 0.12
        bsdf.inputs["Coat Roughness"].default_value = 0.13
    if "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.6
    return mat


def set_material(obj, mat):
    if obj.data and hasattr(obj.data, "materials"):
        obj.data.materials.append(mat)


def smooth(obj):
    if obj.data and hasattr(obj.data, "polygons"):
        for poly in obj.data.polygons:
            poly.use_smooth = True


def add_box(name, location, dimensions, material, bevel=0.0, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("Soft panel edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    set_material(obj, material)
    return obj


def add_cylinder(name, location, radius, depth, material, rotation=(0.0, 0.0, 0.0), vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    set_material(obj, material)
    smooth(obj)
    return obj


def add_torus(name, location, major_radius, minor_radius, material, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=40,
        minor_segments=14,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    set_material(obj, material)
    smooth(obj)
    return obj


def add_mesh(name, vertices, faces, material, smooth_faces=True):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    set_material(obj, material)
    if smooth_faces:
        smooth(obj)
    return obj


def add_curve(name, points, material, bevel=0.012, cyclic=False):
    curve = bpy.data.curves.new(name + "_curve", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = bevel
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (*co, 1.0)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    set_material(obj, material)
    return obj


def add_panel(name, points, material):
    # A thin four-sided exterior element (glass, lamps, etc.).
    return add_mesh(name, points, [tuple(range(len(points)))], material, smooth_faces=False)


def add_wedge(name, x_front, x_back, width, z_front, z_back, thickness, material):
    y = width / 2.0
    verts = [
        (x_front, -y, z_front), (x_front, y, z_front),
        (x_back, y, z_back), (x_back, -y, z_back),
        (x_front, -y, z_front - thickness), (x_front, y, z_front - thickness),
        (x_back, y, z_back - thickness), (x_back, -y, z_back - thickness),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
        (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    obj = add_mesh(name, verts, faces, material, smooth_faces=False)
    bevel = obj.modifiers.new("Panel edge radius", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def make_canopy(material):
    """Create the painted greenhouse/roof as a smooth transverse-section loft."""
    sections = [
        # x, half width, side base z, roof crown z
        (1.11, 0.57, 1.01, 1.08),
        (0.76, 0.66, 1.08, 1.38),
        (0.26, 0.71, 1.12, 1.49),
        (-0.42, 0.70, 1.12, 1.50),
        (-0.91, 0.66, 1.07, 1.36),
        (-1.39, 0.56, 0.99, 1.08),
    ]
    # From the left shoulder over the roof to the right shoulder.
    fractions = (-1.0, -0.70, -0.34, 0.0, 0.34, 0.70, 1.0)
    verts = []
    for x, half_width, base_z, crown_z in sections:
        for f in fractions:
            # Side surfaces meet the body at base_z; the crown remains broad and gentle.
            # A broad crown with near-vertical shoulders gives the greenhouse a
            # sedan-like beltline and supplies a flush surface for the panes.
            elevation = (1.0 - abs(f) ** 3.50)
            z = base_z + (crown_z - base_z) * elevation
            verts.append((x, f * half_width, z))
    faces = []
    per_section = len(fractions)
    for i in range(len(sections) - 1):
        for j in range(per_section - 1):
            a = i * per_section + j
            faces.append((a, a + 1, a + per_section + 1, a + per_section))
    # End caps make the component opaque if viewed from below.
    faces.append(tuple(range(per_section - 1, -1, -1)))
    start = (len(sections) - 1) * per_section
    faces.append(tuple(start + j for j in range(per_section)))
    canopy = add_mesh("Roof_and_greenhouse_shell", verts, faces, material, smooth_faces=True)
    bevel = canopy.modifiers.new("Subtle roof edge radius", "BEVEL")
    bevel.width = 0.018
    bevel.segments = 2
    bpy.context.view_layer.objects.active = canopy
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return canopy


def cut_wheel_arch(body, x):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=56,
        radius=0.365,
        depth=2.4,
        location=(x, 0.0, 0.38),
        rotation=(math.pi / 2.0, 0.0, 0.0),
    )
    cutter = bpy.context.object
    mod = body.modifiers.new("Wheel arch cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def create_wheel(x, side, tyres, chrome, dark, brake):
    y = side * 0.865
    z = 0.38
    # The torus is rotated so its axle follows the vehicle Y axis.
    tyre = add_torus(
        "Tyre_%s_%s" % ("Front" if x > 0 else "Rear", "R" if side < 0 else "L"),
        (x, y, z), 0.245, 0.082, tyres, rotation=(math.pi / 2.0, 0.0, 0.0),
    )
    tyre["part"] = "Tyre"
    face_y = y + side * 0.035
    rim = add_cylinder("Alloy_rim", (x, face_y, z), 0.225, 0.105, chrome,
                       rotation=(math.pi / 2.0, 0.0, 0.0), vertices=40)
    disc = add_cylinder("Brake_disc", (x, face_y + side * 0.058, z), 0.173, 0.018, brake,
                        rotation=(math.pi / 2.0, 0.0, 0.0), vertices=40)
    # Five paired spokes make a close visual match to the double-spoke alloy wheels.
    for i in range(5):
        base = i * (2.0 * math.pi / 5.0) + math.radians(18)
        for offset in (-0.105, 0.105):
            angle = base + offset
            radius = 0.118
            spoke = add_box(
                "Split_spoke_%d_%s" % (i, "a" if offset < 0 else "b"),
                (x + math.cos(angle) * radius, face_y + side * 0.076, z + math.sin(angle) * radius),
                (0.168, 0.030, 0.034), chrome, bevel=0.010,
                rotation=(0.0, -angle, 0.0),
            )
            spoke["part"] = "Wheel spoke"
    add_cylinder("VW_wheel_center", (x, face_y + side * 0.099, z), 0.050, 0.018, dark,
                 rotation=(math.pi / 2.0, 0.0, 0.0), vertices=32)
    # A small caliper is a visible clue of an actual wheel rather than a flat disc.
    add_box("Brake_caliper", (x + 0.17, y + side * 0.045, z + 0.05),
            (0.055, 0.050, 0.095), dark, bevel=0.012)


def add_arch_trim(x, side, material):
    points = []
    for step in range(17):
        theta = math.pi * step / 16.0
        points.append((x + 0.365 * math.cos(theta), side * 0.847, 0.38 + 0.365 * math.sin(theta)))
    add_curve("Wheel_arch_trim", points, material, bevel=0.010)


def add_side_glass_and_doors(side, glass, trim, body_mat, chrome):
    # Windows sit just outside the painted greenhouse.  They intentionally remain
    # separate panes, providing a clear B-pillar and four-door sedan read.
    # The panes follow the inward slope of the roof shoulders rather than staying
    # vertical.  This makes them sit flush with the painted canopy in a 3/4 view.
    front_window = [
        (0.96, side * 0.570, 1.055), (0.67, side * 0.485, 1.315),
        (0.24, side * 0.500, 1.385), (-0.08, side * 0.687, 1.114),
    ]
    rear_window = [
        (-0.14, side * 0.688, 1.112), (-0.06, side * 0.500, 1.385),
        (-0.56, side * 0.475, 1.325), (-1.20, side * 0.560, 1.052),
    ]
    add_panel("Front_side_window_%s" % ("R" if side < 0 else "L"), front_window, glass)
    add_panel("Rear_side_window_%s" % ("R" if side < 0 else "L"), rear_window, glass)
    for label, poly in (("front", front_window), ("rear", rear_window)):
        add_curve("%s_window_frame_%s" % (label, "R" if side < 0 else "L"), poly, trim, bevel=0.009, cyclic=True)

    y_panel = side * 0.844
    front_door = [(0.78, y_panel, 0.47), (0.80, y_panel, 0.96), (-0.18, y_panel, 1.00), (-0.30, y_panel, 0.45)]
    rear_door = [(-0.30, y_panel, 0.45), (-0.18, y_panel, 1.00), (-1.22, y_panel, 0.96), (-1.39, y_panel, 0.45)]
    add_curve("Front_door_gap_%s" % ("R" if side < 0 else "L"), front_door, trim, bevel=0.008, cyclic=True)
    add_curve("Rear_door_gap_%s" % ("R" if side < 0 else "L"), rear_door, trim, bevel=0.008, cyclic=True)
    # Main horizontal character line and discrete handles.
    add_curve("Side_character_line_%s" % ("R" if side < 0 else "L"),
              [(1.72, y_panel, 0.74), (0.28, y_panel, 0.79), (-1.70, y_panel, 0.76)],
              body_mat, bevel=0.010)
    for name, handle_x in (("Front", 0.15), ("Rear", -0.92)):
        add_box("%s_door_handle_%s" % (name, "R" if side < 0 else "L"),
                (handle_x, side * 0.865, 0.925), (0.20, 0.035, 0.046), chrome, bevel=0.013)


def add_vw_badge(x, z, chrome, dark, front=True):
    # A small concentric badge with simplified V and W strokes.
    add_torus("VW_badge_ring", (x, 0.0, z), 0.097, 0.013, chrome, rotation=(0.0, math.pi / 2.0, 0.0))
    add_cylinder("VW_badge_backing", (x - (0.004 if front else -0.004), 0.0, z), 0.083, 0.014, dark,
                 rotation=(0.0, math.pi / 2.0, 0.0), vertices=32)
    face_x = x + (0.013 if front else -0.013)
    # Curves lie in the YZ plane; their metallic strokes make the VW motif legible.
    add_curve("VW_V", [(face_x, -0.052, z + 0.038), (face_x, 0.0, z - 0.016), (face_x, 0.052, z + 0.038)], chrome, bevel=0.008)
    add_curve("VW_W", [(face_x, -0.060, z - 0.026), (face_x, -0.030, z - 0.058),
                        (face_x, 0.0, z - 0.026), (face_x, 0.030, z - 0.058), (face_x, 0.060, z - 0.026)], chrome, bevel=0.008)


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def main():
    clear_scene()
    if bpy.app.version < (4, 5, 0):
        raise RuntimeError("This build is intended for Blender 4.5 LTS or newer.")

    # Materials tuned for the silver reference car photographed in a studio.
    paint = make_material("Silver metallic paint", (0.47, 0.50, 0.53), metallic=0.72, roughness=0.22)
    paint_dark = make_material("Shadow silver", (0.22, 0.24, 0.27), metallic=0.52, roughness=0.30)
    black = make_material("Satin black plastic", (0.012, 0.016, 0.021), metallic=0.03, roughness=0.31)
    tyre_mat = make_material("Rubber", (0.008, 0.010, 0.013), metallic=0.0, roughness=0.52)
    glass = make_material("Smoked glass", (0.025, 0.044, 0.060), metallic=0.12, roughness=0.10, transmission=0.10)
    chrome = make_material("Polished alloy", (0.57, 0.62, 0.67), metallic=0.92, roughness=0.17)
    brake = make_material("Brake disc", (0.20, 0.23, 0.26), metallic=0.82, roughness=0.25)
    headlamp = make_material("Headlamp lens", (0.59, 0.72, 0.86), metallic=0.38, roughness=0.10, emission=(0.12, 0.16, 0.20))
    red_lamp = make_material("Rear lamp red", (0.48, 0.008, 0.012), metallic=0.22, roughness=0.16, emission=(0.22, 0.0, 0.0))
    white = make_material("Plate white", (0.92, 0.94, 0.95), metallic=0.0, roughness=0.35)
    ground_mat = make_material("Studio floor", (0.10, 0.115, 0.13), metallic=0.0, roughness=0.42)

    # Lower, gently rounded body.  Exact Boolean arches make the wheels seat in the
    # panels instead of reading as circles pasted over a box.
    body = add_box("Main_body_shell", (0.0, 0.0, 0.66), (4.34, 1.66, 0.63), paint, bevel=0.16)
    for wheel_x in (1.39, -1.39):
        cut_wheel_arch(body, wheel_x)
    body["part"] = "Car body"
    add_box("Front_bumper", (2.08, 0.0, 0.59), (0.30, 1.65, 0.37), paint, bevel=0.105)
    add_box("Rear_bumper", (-2.08, 0.0, 0.60), (0.31, 1.65, 0.34), paint, bevel=0.105)
    add_wedge("Hood_panel", 1.96, 0.32, 1.54, 0.90, 1.015, 0.115, paint)
    add_wedge("Trunk_lid", -1.96, -0.77, 1.55, 0.90, 1.00, 0.105, paint)
    make_canopy(paint)

    # Side styling: greenhouses, panel gaps, handles, skirts, trims, and mirrors.
    for side in (-1, 1):
        add_side_glass_and_doors(side, glass, black, paint_dark, chrome)
        add_box("Side_sill_%s" % ("R" if side < 0 else "L"), (0.0, side * 0.838, 0.395),
                (3.80, 0.045, 0.105), black, bevel=0.018)
        for x in (1.39, -1.39):
            add_arch_trim(x, side, black)
        # Mirror stalk and painted mirror housing at the A-pillar.
        add_box("Mirror_stalk_%s" % ("R" if side < 0 else "L"), (0.78, side * 0.835, 1.12),
                (0.09, 0.08, 0.07), black, bevel=0.012)
        mirror = add_box("Door_mirror_%s" % ("R" if side < 0 else "L"), (0.79, side * 0.925, 1.165),
                         (0.25, 0.15, 0.115), paint, bevel=0.055)
        add_box("Mirror_glass_%s" % ("R" if side < 0 else "L"), (0.82, side * 1.005, 1.168),
                (0.16, 0.012, 0.068), glass, bevel=0.008)

    # Windshield and rear glass span across the greenhouse and make the roofline read
    # as a compact three-box sedan rather than a hatchback.
    windshield = [(1.105, -0.57, 1.045), (1.105, 0.57, 1.045), (0.65, 0.48, 1.315), (0.65, -0.48, 1.315)]
    rear_glass = [(-0.86, -0.48, 1.315), (-0.86, 0.48, 1.315), (-1.38, 0.55, 1.045), (-1.38, -0.55, 1.045)]
    add_panel("Front_windscreen", windshield, glass)
    add_panel("Rear_windscreen", rear_glass, glass)
    add_curve("Windscreen_frame", windshield, black, bevel=0.010, cyclic=True)
    add_curve("Rear_screen_frame", rear_glass, black, bevel=0.010, cyclic=True)
    # Roof seam highlight and short rear-leaning antenna.
    add_curve("Roof_center_seam", [(0.58, 0.0, 1.47), (-0.72, 0.0, 1.48)], paint_dark, bevel=0.006)
    add_curve("Roof_antenna", [(-0.72, 0.0, 1.47), (-0.97, 0.0, 1.74)], black, bevel=0.012)

    # Four wheels and the dark wheel-well backing visible through their arches.
    for x in (1.39, -1.39):
        for side in (-1, 1):
            add_cylinder("Wheel_well", (x, side * 0.818, 0.38), 0.355, 0.020, black,
                         rotation=(math.pi / 2.0, 0.0, 0.0), vertices=48)
            create_wheel(x, side, tyre_mat, chrome, black, brake)

    # Front: horizontally barred upper grille, badge, angular lamps, lower intake,
    # small fog lamps, and a simple white plate.
    add_box("Upper_grille", (2.245, 0.0, 0.905), (0.040, 1.18, 0.255), black, bevel=0.025)
    for z in (0.825, 0.875, 0.925, 0.975):
        add_box("Grille_bar", (2.270, 0.0, z), (0.019, 1.08, 0.014), paint_dark, bevel=0.004)
    add_box("Lower_air_intake", (2.245, 0.0, 0.585), (0.045, 1.34, 0.175), black, bevel=0.035)
    for y in (-0.55, 0.55):
        add_box("Front_fog_light_housing", (2.275, y, 0.625), (0.055, 0.18, 0.095), black, bevel=0.020)
        add_box("Front_fog_lamp", (2.304, y, 0.625), (0.017, 0.11, 0.045), headlamp, bevel=0.010)
    for side in (-1, 1):
        y = side * 0.57
        lamp = add_box("Headlamp_%s" % ("R" if side < 0 else "L"), (2.228, y, 1.02),
                       (0.028, 0.39, 0.155), headlamp, bevel=0.030, rotation=(0.0, 0.0, side * 0.09))
        add_box("Headlamp_inner_%s" % ("R" if side < 0 else "L"), (2.246, y, 1.015),
                (0.007, 0.23, 0.045), chrome, bevel=0.008, rotation=(0.0, 0.0, side * 0.09))
    add_vw_badge(2.285, 0.905, chrome, black, front=True)
    add_box("Front_plate", (2.288, 0.0, 0.655), (0.022, 0.56, 0.125), white, bevel=0.012)

    # Tail: discreet bumper reflectors, trunk badge, plate recess, and wide red lamps.
    for side in (-1, 1):
        y = side * 0.57
        add_box("Tail_lamp_%s" % ("R" if side < 0 else "L"), (-2.215, y, 1.005),
                (0.028, 0.405, 0.145), red_lamp, bevel=0.028, rotation=(0.0, 0.0, -side * 0.08))
        add_box("Tail_lamp_inner_%s" % ("R" if side < 0 else "L"), (-2.234, y, 1.005),
                (0.007, 0.235, 0.032), chrome, bevel=0.006, rotation=(0.0, 0.0, -side * 0.08))
        add_box("Rear_reflector_%s" % ("R" if side < 0 else "L"), (-2.245, side * 0.54, 0.475),
                (0.030, 0.17, 0.035), red_lamp, bevel=0.010)
    add_vw_badge(-2.285, 0.99, chrome, black, front=False)
    add_box("Rear_plate", (-2.288, 0.0, 0.715), (0.022, 0.56, 0.125), white, bevel=0.012)
    add_box("Voyage_badge", (-2.294, 0.47, 0.855), (0.018, 0.13, 0.030), chrome, bevel=0.006)
    # Fuel cap on the driver's rear quarter panel (left in this coordinate convention).
    add_cylinder("Fuel_filler_cap", (-1.20, 0.847, 0.90), 0.105, 0.012, paint_dark,
                 rotation=(math.pi / 2.0, 0.0, 0.0), vertices=36)
    add_torus("Fuel_filler_outline", (-1.20, 0.855, 0.90), 0.105, 0.006, black,
             rotation=(math.pi / 2.0, 0.0, 0.0))

    # Studio presentation setup.
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "Studio_floor"
    set_material(floor, ground_mat)

    world = bpy.context.scene.world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.035, 0.045, 0.060, 1.0)
    bg.inputs["Strength"].default_value = 0.32

    def add_area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, type="AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        data.color = color
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = location
        look_at(light, (0.0, 0.0, 0.80))
        return light

    add_area("Key_softbox", (4.2, -4.5, 6.5), 1100, 4.2, (0.88, 0.93, 1.0))
    add_area("Fill_softbox", (1.0, 5.0, 3.8), 800, 3.4, (0.72, 0.82, 1.0))
    add_area("Rear_rim_light", (-4.5, -2.5, 5.0), 1000, 3.0, (0.95, 0.70, 0.50))
    add_area("Front_fill", (5.0, 1.0, 2.8), 450, 2.0, (1.0, 0.93, 0.85))

    cam_data = bpy.data.cameras.new("Presentation_camera")
    cam_data.lens = 62
    cam_data.sensor_width = 36
    camera = bpy.data.objects.new("Presentation_camera", cam_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (6.85, -8.20, 2.48)
    look_at(camera, (0.0, 0.0, 0.82))
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = RENDER_PATH
    scene.render.film_transparent = False
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    scene.render.image_settings.color_mode = "RGBA"

    # Useful scene metadata for an artist opening the blend file.
    scene["vehicle"] = "Volkswagen Voyage 2012-style sedan"
    scene["source"] = "Modelled from supplied multi-angle reference images"
    scene["blender_target"] = "Blender 4.5 LTS"

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print("VOYAGE_BUILD_COMPLETE")
    print("BLEND_PATH=" + BLEND_PATH)
    print("RENDER_PATH=" + RENDER_PATH)


if __name__ == "__main__":
    main()
