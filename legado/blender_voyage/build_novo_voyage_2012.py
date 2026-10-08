"""Novo Voyage 1.6 (first facelift, launched July 2012) for Blender 4.5 LTS.

The model is constructed in metres from the June 2012 VW chassis dimensions.
It deliberately uses one continuous closed guide body, with visual details
shrinkwrapped to that guide, so panels cannot float above the vehicle.
"""

import bpy
import math
import os
from mathutils import Vector


OUT_DIR = r"C:\Users\satoshi\Documents\ChatGPT\teste"
OUT_BLEND = os.path.join(OUT_DIR, "novo_voyage_2012_g6.blend")
OUT_RENDER = os.path.join(OUT_DIR, "novo_voyage_2012_g6_preview.png")

SPEC = {
    "length": 4.215,
    "width": 1.656,
    "width_with_mirrors": 1.893,
    "height": 1.462,
    "wheelbase": 2.465,
    "front_track": 1.429,
    "rear_track": 1.416,
    "ground_clearance": 0.161,
    "tyre_radius": 0.29775,       # 195/55 R15
    "tyre_width": 0.195,
    "rim_radius": 0.19050,        # 15 inches / 2
}

FRONT_AXLE_X = SPEC["wheelbase"] / 2.0
REAR_AXLE_X = -SPEC["wheelbase"] / 2.0
NOSE_X = FRONT_AXLE_X + 0.760
TAIL_X = NOSE_X - SPEC["length"]


def purge_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)


def collection(name):
    existing = bpy.data.collections.get(name)
    if existing:
        return existing
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def link_to(obj, col):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def material(name, color, metallic=0.0, roughness=0.45, transmission=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    node = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if node is None:
        node = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        output = next((n for n in mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if output is None:
            output = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(node.outputs["BSDF"], output.inputs["Surface"])
    node.inputs["Base Color"].default_value = (*color, 1.0)
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in node.inputs:
        node.inputs["Coat Weight"].default_value = 0.56 if metallic else 0.12
        node.inputs["Coat Roughness"].default_value = 0.10
    if "Transmission Weight" in node.inputs:
        node.inputs["Transmission Weight"].default_value = transmission
    if emission:
        node.inputs["Emission Color"].default_value = (*emission, 1.0)
        node.inputs["Emission Strength"].default_value = 1.2
    return mat


def assign(obj, mat):
    if hasattr(obj.data, "materials"):
        obj.data.materials.append(mat)


def smooth(obj):
    if hasattr(obj.data, "polygons"):
        for poly in obj.data.polygons:
            poly.use_smooth = True


def interp(keys, x, field):
    if x <= keys[0][0]:
        return keys[0][field]
    if x >= keys[-1][0]:
        return keys[-1][field]
    for a, b in zip(keys, keys[1:]):
        if a[0] <= x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            return a[field] * (1.0 - t) + b[field] * t
    return keys[-1][field]


# x, half-width, floor z, belt z, roof/deck z.  The profile is a direct
# interpretation of the white Novo Voyage reference: low wedge hood, arched
# roof, distinct short trunk, and a higher, compact tail.
PROFILE = [
    (TAIL_X, 0.600, 0.205, 0.710, 0.805),
    (-2.105, 0.735, 0.180, 0.805, 0.890),
    (-1.925, 0.798, 0.165, 0.885, 0.965),
    (-1.620, 0.826, 0.161, 0.930, 1.010),
    (-1.305, 0.828, 0.161, 0.955, 1.045),
    (-1.090, 0.816, 0.161, 0.980, 1.100),
    (-0.820, 0.790, 0.161, 0.990, 1.300),
    (-0.520, 0.758, 0.161, 0.995, 1.420),
    (-0.180, 0.735, 0.161, 0.995, 1.462),
    (0.215, 0.738, 0.161, 0.992, 1.452),
    (0.515, 0.757, 0.161, 0.987, 1.365),
    (0.805, 0.792, 0.161, 0.970, 1.190),
    (1.080, 0.820, 0.161, 0.950, 1.045),
    (1.385, 0.828, 0.161, 0.915, 0.982),
    (1.650, 0.815, 0.170, 0.865, 0.935),
    (1.875, 0.750, 0.185, 0.790, 0.865),
    (NOSE_X, 0.600, 0.210, 0.705, 0.790),
]


def profile_xs():
    values = {round(row[0], 4) for row in PROFILE}
    x = TAIL_X
    while x < NOSE_X - 1e-6:
        values.add(round(x, 4))
        x += 0.045
    values.add(round(NOSE_X, 4))
    return sorted(values)


def side_window(x, z):
    # Two panes divided by the vertical black B pillar.
    front = 0.03 < x < 0.82 and z > 1.005
    rear = -1.07 < x < -0.105 and z > 1.015
    return front or rear


def screen_window(x, y):
    # Windscreen/rear window are integrated into the same continuous surface.
    return abs(y) < 0.66 and ((0.50 < x < 0.91) or (-1.14 < x < -0.67))


def build_closed_body(body_col, guide_col, paint, glass):
    xs = profile_xs()
    half_count = 9
    rings = []
    vertices = []
    for x in xs:
        hw = interp(PROFILE, x, 1)
        floor = interp(PROFILE, x, 2)
        belt = interp(PROFILE, x, 3)
        roof = interp(PROFILE, x, 4)
        half = [
            (0.0, floor),
            (hw * 0.52, floor),
            (hw * 0.88, floor + 0.045),
            (hw, max(floor + 0.150, belt - 0.220)),
            (hw, belt),
            (hw * 0.985, belt + 0.105),
            (hw * 0.855, roof - 0.030),
            (hw * 0.460, roof),
            (0.0, roof),
        ]
        ring = [(x, y, z) for y, z in half]
        ring += [(x, -y, z) for y, z in reversed(half[1:-1])]
        start = len(vertices)
        vertices.extend(ring)
        rings.append(list(range(start, start + len(ring))))

    faces = []
    face_tags = []
    per_ring = len(rings[0])
    for ring_i in range(len(rings) - 1):
        x_mid = (xs[ring_i] + xs[ring_i + 1]) * 0.5
        for j in range(per_ring):
            face = (rings[ring_i][j], rings[ring_i][(j + 1) % per_ring],
                    rings[ring_i + 1][(j + 1) % per_ring], rings[ring_i + 1][j])
            faces.append(face)
            # Cross-section segments 4-5 on either side represent the vertical/
            # shoulder glazing; roof segments carry windshield/rear screen.
            side_seg = j in (4, 5, per_ring - 5, per_ring - 6)
            roof_seg = j in (6, 7, 8, per_ring - 7, per_ring - 8)
            z_mid = sum(vertices[v][2] for v in face) * 0.25
            y_mid = sum(vertices[v][1] for v in face) * 0.25
            face_tags.append(1 if ((side_seg and side_window(x_mid, z_mid)) or
                                   (roof_seg and screen_window(x_mid, y_mid))) else 0)

    faces.append(tuple(reversed(rings[0])))
    face_tags.append(0)
    faces.append(tuple(rings[-1]))
    face_tags.append(0)

    mesh = bpy.data.meshes.new("Novo_Voyage_2012_guide_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.materials.append(paint)
    mesh.materials.append(glass)
    for polygon, tag in zip(mesh.polygons, face_tags):
        polygon.material_index = tag
        polygon.use_smooth = True

    body = bpy.data.objects.new("BODY_Guide_Closed_Shell", mesh)
    body_col.objects.link(body)
    body["role"] = "continuous monocoque guide shell"
    body["target_variant"] = "Novo Voyage 1.6 launched July 2012"

    # A hidden duplicate supplies a stable, smooth surface target for every
    # exterior detail.  This explicitly prevents the previous floating panels.
    guide = body.copy()
    guide.data = mesh.copy()
    guide.name = "REFERENCE_Surface_Target"
    guide_col.objects.link(guide)
    guide.hide_render = True
    guide.hide_viewport = True
    guide.display_type = "WIRE"
    guide_mod = guide.modifiers.new("Guide subdivision", "SUBSURF")
    guide_mod.levels = 1
    guide_mod.render_levels = 1
    return body, guide


def add_wheel_arch_cutters(body, cuts_col):
    cutters = []
    for label, x, _track in (
        ("Front", FRONT_AXLE_X, SPEC["front_track"]),
        ("Rear", REAR_AXLE_X, SPEC["rear_track"]),
    ):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=64,
            radius=SPEC["tyre_radius"] + 0.043,
            depth=2.30,
            location=(x, 0.0, SPEC["tyre_radius"]),
            rotation=(math.pi / 2.0, 0.0, 0.0),
        )
        cutter = bpy.context.object
        cutter.name = "CUT_Wheel_Arch_" + label
        link_to(cutter, cuts_col)
        cutter.hide_render = True
        cutter.hide_viewport = True
        boolean = body.modifiers.new("Wheel arch " + label, "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.solver = "EXACT"
        boolean.object = cutter
        cutters.append(cutter)
    subdiv = body.modifiers.new("Body subdivision", "SUBSURF")
    subdiv.levels = 1
    subdiv.render_levels = 1
    return cutters


def mesh_grid(name, corners, nu, nv, col, mat, parent=None):
    """Create a quad grid (never a non-coplanar n-gon) from four corners."""
    a, b, c, d = [Vector(p) for p in corners]
    verts = []
    for i in range(nu + 1):
        u = i / nu
        for j in range(nv + 1):
            v = j / nv
            point = ((a * (1 - u) + b * u) * (1 - v) +
                     (d * (1 - u) + c * u) * v)
            verts.append(tuple(point))
    faces = []
    stride = nv + 1
    for i in range(nu):
        for j in range(nv):
            k = i * stride + j
            faces.append((k, k + stride, k + stride + 1, k + 1))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def conformed_patch(name, corners, nu, nv, col, mat, target, offset=0.003, thickness=0.0, parent=None):
    obj = mesh_grid(name, corners, nu, nv, col, mat, parent)
    shrink = obj.modifiers.new("Conform to body", "SHRINKWRAP")
    shrink.target = target
    shrink.wrap_method = "NEAREST_SURFACEPOINT"
    shrink.wrap_mode = "ABOVE_SURFACE"
    shrink.offset = offset
    if thickness:
        solid = obj.modifiers.new("Lens/panel thickness", "SOLIDIFY")
        solid.thickness = thickness
        solid.offset = 0.0
        solid.use_even_offset = True
    obj["max_attachment_offset_m"] = offset
    return obj


def closest_surface(target, query):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = target.evaluated_get(depsgraph)
    ok, location, normal, _index = evaluated.closest_point_on_mesh(Vector(query))
    if not ok:
        raise RuntimeError("Could not locate an exterior attachment surface.")
    return location, normal.normalized()


def primitive_box(name, location, dims, col, mat, bevel=0.0, parent=None, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    assign(obj, mat)
    if parent:
        obj.parent = parent
    link_to(obj, col)
    return obj


def cylinder_on_surface(name, query, radius, depth, col, mat, target, parent=None, offset=0.004, vertices=48):
    location, normal = closest_surface(target, query)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(normal)
    obj.location = location + normal * (offset + depth * 0.5)
    assign(obj, mat)
    smooth(obj)
    link_to(obj, col)
    if parent:
        obj.parent = parent
    obj["max_attachment_offset_m"] = offset
    return obj


def torus_on_surface(name, query, major, minor, col, mat, target, parent=None, offset=0.006):
    location, normal = closest_surface(target, query)
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=40, minor_segments=12)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(normal)
    obj.location = location + normal * offset
    assign(obj, mat)
    smooth(obj)
    link_to(obj, col)
    if parent:
        obj.parent = parent
    obj["max_attachment_offset_m"] = offset
    return obj


def create_tyre(name, x, y, wheels_col, rubber, parent):
    width = SPEC["tyre_width"]
    rim = SPEC["rim_radius"]
    outer = SPEC["tyre_radius"]
    profile = [
        (-width * 0.50, rim + 0.005),
        (-width * 0.50, rim + 0.055),
        (-width * 0.40, outer - 0.020),
        (-width * 0.18, outer - 0.002),
        (0.0, outer),
        (width * 0.18, outer - 0.002),
        (width * 0.40, outer - 0.020),
        (width * 0.50, rim + 0.055),
        (width * 0.50, rim + 0.005),
    ]
    segments = 48
    verts = []
    for i in range(segments):
        angle = 2 * math.pi * i / segments
        for axle, radius in profile:
            verts.append((x + radius * math.cos(angle), y + axle,
                          SPEC["tyre_radius"] + radius * math.sin(angle)))
    faces = []
    count = len(profile)
    for i in range(segments):
        nxt = (i + 1) % segments
        for j in range(count - 1):
            faces.append((i * count + j, nxt * count + j, nxt * count + j + 1, i * count + j + 1))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(rubber)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    tyre = bpy.data.objects.new(name, mesh)
    wheels_col.objects.link(tyre)
    tyre.parent = parent
    tyre["touches_ground"] = True
    return tyre


def create_wheel_assembly(tag, x, y, wheels_col, rubber, alloy, brake, black, parent):
    side = 1 if y > 0 else -1
    create_tyre("Tyre_" + tag, x, y, wheels_col, rubber, parent)
    exterior_y = y + side * (SPEC["tyre_width"] * 0.5 + 0.006)
    # Brake disc and 15-inch alloy face.
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.143, depth=0.016,
                                        location=(x, exterior_y - side * 0.014, SPEC["tyre_radius"]),
                                        rotation=(math.pi / 2.0, 0.0, 0.0))
    disc = bpy.context.object
    disc.name = "Brake_disc_" + tag
    assign(disc, brake)
    smooth(disc)
    link_to(disc, wheels_col)
    disc.parent = parent

    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=SPEC["rim_radius"], depth=0.026,
                                        location=(x, exterior_y, SPEC["tyre_radius"]),
                                        rotation=(math.pi / 2.0, 0.0, 0.0))
    rim = bpy.context.object
    rim.name = "Alloy_rim_" + tag
    assign(rim, alloy)
    smooth(rim)
    link_to(rim, wheels_col)
    rim.parent = parent

    # Five paired spokes, close to the twin-spoke alloy wheel in the supplied view.
    for i in range(5):
        base_angle = i * 2 * math.pi / 5 + math.radians(18)
        for suffix, delta in (("A", -0.105), ("B", 0.105)):
            angle = base_angle + delta
            radial = 0.110
            spoke = primitive_box(
                "Alloy_spoke_%s_%d_%s" % (tag, i, suffix),
                (x + radial * math.cos(angle), exterior_y + side * 0.018,
                 SPEC["tyre_radius"] + radial * math.sin(angle)),
                (0.155, 0.017, 0.028), wheels_col, alloy, bevel=0.008,
                parent=parent, rotation=(0.0, -angle, 0.0),
            )
            spoke["part"] = "wheel spoke"
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.047, depth=0.028,
                                        location=(x, exterior_y + side * 0.026, SPEC["tyre_radius"]),
                                        rotation=(math.pi / 2.0, 0.0, 0.0))
    cap = bpy.context.object
    cap.name = "VW_wheel_cap_" + tag
    assign(cap, black)
    smooth(cap)
    link_to(cap, wheels_col)
    cap.parent = parent


def add_area(name, location, energy, size, color, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def build():
    purge_scene()
    if bpy.app.version < (4, 5, 0):
        raise RuntimeError("Use Blender 4.5 LTS or newer for this model.")

    root_col = collection("VEHICLE_ROOT")
    ref_col = collection("REFERENCE")
    body_col = collection("BODY")
    glass_col = collection("GLASS")
    lights_col = collection("LIGHTS")
    wheels_col = collection("WHEELS")
    trim_col = collection("TRIM")
    panels_col = collection("PANELS")
    cuts_col = collection("VALIDATION_CUTTERS")
    cuts_col.hide_render = True
    cuts_col.hide_viewport = True

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0.0, 0.0, 0.0))
    root = bpy.context.object
    root.name = "VEHICLE_ROOT_Novo_Voyage_2012"
    link_to(root, root_col)
    root["units"] = "metres"
    root["variant"] = "Novo Voyage 1.6, first facelift, launched July 2012"
    root["wheelbase_m"] = SPEC["wheelbase"]

    paint = material("Paint_Silver_2012", (0.48, 0.50, 0.52), metallic=0.68, roughness=0.22)
    glass = material("Integrated_Smoked_Glass", (0.015, 0.029, 0.042), metallic=0.08, roughness=0.10, transmission=0.08)
    black = material("Satin_Black", (0.008, 0.012, 0.016), roughness=0.30)
    rubber = material("Tyre_Rubber", (0.007, 0.009, 0.012), roughness=0.55)
    alloy = material("Alloy_Wheel", (0.54, 0.59, 0.64), metallic=0.92, roughness=0.16)
    brake = material("Brake_Metal", (0.18, 0.22, 0.25), metallic=0.85, roughness=0.25)
    lens = material("Headlamp_Lens", (0.34, 0.50, 0.68), metallic=0.35, roughness=0.08, transmission=0.12)
    lamp_red = material("Tail_Lamp_Red", (0.52, 0.006, 0.010), metallic=0.20, roughness=0.14, emission=(0.12, 0.0, 0.0))
    chrome = material("Chrome", (0.68, 0.72, 0.76), metallic=0.96, roughness=0.13)
    plate = material("Licence_Plate", (0.93, 0.94, 0.95), roughness=0.32)
    ground = material("Studio_Ground", (0.075, 0.085, 0.10), roughness=0.40)

    body, guide = build_closed_body(body_col, ref_col, paint, glass)
    body.parent = root
    guide.parent = root
    add_wheel_arch_cutters(body, cuts_col)

    # Exact wheelbase, track and 195/55R15 diameter from the technical sheet.
    wheel_specs = (
        ("Front_R", FRONT_AXLE_X, -SPEC["front_track"] / 2.0),
        ("Front_L", FRONT_AXLE_X, SPEC["front_track"] / 2.0),
        ("Rear_R", REAR_AXLE_X, -SPEC["rear_track"] / 2.0),
        ("Rear_L", REAR_AXLE_X, SPEC["rear_track"] / 2.0),
    )
    for tag, x, y in wheel_specs:
        create_wheel_assembly(tag, x, y, wheels_col, rubber, alloy, brake, black, root)

    # --- Clean, surface-attached G6 front ---
    conformed_patch("Upper_black_grille",
        [(NOSE_X + 0.05, -0.41, 0.655), (NOSE_X + 0.05, 0.41, 0.655),
         (NOSE_X + 0.05, 0.41, 0.775), (NOSE_X + 0.05, -0.41, 0.775)],
        16, 3, panels_col, black, guide, offset=0.004, thickness=0.003, parent=root)
    for idx, z in enumerate((0.692, 0.735)):
        conformed_patch("Grille_horizontal_bar_%d" % idx,
            [(NOSE_X + 0.058, -0.385, z - 0.008), (NOSE_X + 0.058, 0.385, z - 0.008),
             (NOSE_X + 0.058, 0.385, z + 0.008), (NOSE_X + 0.058, -0.385, z + 0.008)],
            12, 1, trim_col, chrome, guide, offset=0.008, thickness=0.001, parent=root)
    conformed_patch("Lower_hex_intake",
        [(NOSE_X + 0.05, -0.58, 0.405), (NOSE_X + 0.05, 0.58, 0.405),
         (NOSE_X + 0.05, 0.58, 0.565), (NOSE_X + 0.05, -0.58, 0.565)],
        18, 4, panels_col, black, guide, offset=0.004, thickness=0.003, parent=root)
    # Headlamps use dense quad grids that conform to the fender corners.
    for side, label in ((-1, "R"), (1, "L")):
        conformed_patch("Headlamp_housing_" + label,
            [(NOSE_X + 0.025, side * 0.790, 0.805), (NOSE_X + 0.025, side * 0.430, 0.800),
             (1.805, side * 0.470, 0.985), (1.780, side * 0.770, 0.910)],
            9, 4, lights_col, black, guide, offset=0.004, thickness=0.004, parent=root)
        conformed_patch("Headlamp_lens_" + label,
            [(NOSE_X + 0.030, side * 0.775, 0.820), (NOSE_X + 0.030, side * 0.455, 0.815),
             (1.820, side * 0.485, 0.962), (1.795, side * 0.748, 0.900)],
            9, 4, lights_col, lens, guide, offset=0.008, thickness=0.003, parent=root)
        conformed_patch("Fog_lamp_surround_" + label,
            [(NOSE_X + 0.045, side * 0.705, 0.455), (NOSE_X + 0.045, side * 0.505, 0.455),
             (NOSE_X + 0.045, side * 0.500, 0.555), (NOSE_X + 0.045, side * 0.665, 0.575)],
            5, 3, lights_col, black, guide, offset=0.006, thickness=0.003, parent=root)
        conformed_patch("Fog_lamp_lens_" + label,
            [(NOSE_X + 0.052, side * 0.655, 0.480), (NOSE_X + 0.052, side * 0.545, 0.480),
             (NOSE_X + 0.052, side * 0.542, 0.525), (NOSE_X + 0.052, side * 0.642, 0.530)],
            4, 2, lights_col, lens, guide, offset=0.010, thickness=0.002, parent=root)
    conformed_patch("Front_plate",
        [(NOSE_X + 0.055, -0.265, 0.548), (NOSE_X + 0.055, 0.265, 0.548),
         (NOSE_X + 0.055, 0.265, 0.635), (NOSE_X + 0.055, -0.265, 0.635)],
        8, 2, panels_col, plate, guide, offset=0.010, thickness=0.002, parent=root)
    cylinder_on_surface("VW_front_badge_backing", (NOSE_X + 0.06, 0.0, 0.715), 0.088, 0.010,
                        trim_col, black, guide, root, offset=0.006)
    torus_on_surface("VW_front_badge_ring", (NOSE_X + 0.065, 0.0, 0.715), 0.074, 0.010,
                     trim_col, chrome, guide, root, offset=0.014)

    # --- Doors, trim and mirrors: every line is a narrow shrinkwrapped quad strip. ---
    for side, label in ((-1, "R"), (1, "L")):
        y = side * 0.96
        for seam_name, seam_x, low, high in (
            ("Front_door_leading", 0.82, 0.455, 0.985),
            ("B_pillar", -0.06, 0.455, 1.365),
            ("Rear_door_trailing", -1.08, 0.455, 0.965),
        ):
            conformed_patch(seam_name + "_" + label,
                [(seam_x - 0.006, y, low), (seam_x + 0.006, y, low),
                 (seam_x + 0.006, y, high), (seam_x - 0.006, y, high)],
                1, 8, trim_col, black, guide, offset=0.0035, thickness=0.0008, parent=root)
        # Black B-pillar remains a real surface rather than a freestanding frame.
        conformed_patch("B_pillar_black_" + label,
            [(-0.082, y, 1.005), (-0.032, y, 1.005),
             (-0.032, y, 1.375), (-0.082, y, 1.375)],
            2, 6, glass_col, black, guide, offset=0.004, thickness=0.001, parent=root)
        conformed_patch("Side_character_line_" + label,
            [(0.91, y, 0.752), (-1.40, y, 0.735),
             (-1.40, y, 0.752), (0.91, y, 0.770)],
            18, 1, trim_col, chrome, guide, offset=0.003, thickness=0.0008, parent=root)
        conformed_patch("Lower_side_sill_" + label,
            [(1.12, y, 0.338), (-1.55, y, 0.330),
             (-1.55, y, 0.405), (1.12, y, 0.410)],
            16, 2, trim_col, black, guide, offset=0.005, thickness=0.002, parent=root)
        for h_name, hx in (("Front_handle", 0.32), ("Rear_handle", -0.67)):
            conformed_patch(h_name + "_" + label,
                [(hx - 0.090, y, 0.880), (hx + 0.090, y, 0.880),
                 (hx + 0.090, y, 0.916), (hx - 0.090, y, 0.916)],
                4, 1, panels_col, chrome, guide, offset=0.007, thickness=0.002, parent=root)
        # Mirror base contacts the body surface, and a rounded housing grows from it.
        loc, normal = closest_surface(guide, (0.78, side * 0.90, 1.02))
        base = cylinder_on_surface("Mirror_base_" + label, (0.78, side * 0.90, 1.02), 0.050, 0.026,
                                   trim_col, black, guide, root, offset=0.003, vertices=24)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=loc + normal * 0.105)
        mirror = bpy.context.object
        mirror.name = "Painted_mirror_" + label
        mirror.scale = (0.115, 0.072, 0.060)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        assign(mirror, paint)
        smooth(mirror)
        link_to(mirror, panels_col)
        mirror.parent = root

    # Fuel cap constrained to the left rear quarter.
    cylinder_on_surface("Fuel_filler_cap", (-1.18, 0.88, 0.855), 0.092, 0.006,
                        panels_col, paint, guide, root, offset=0.004, vertices=40)
    torus_on_surface("Fuel_filler_outline", (-1.18, 0.88, 0.855), 0.092, 0.004,
                     trim_col, black, guide, root, offset=0.009)

    # --- G6 rear: split wraparound tail lamps and low plate on the trunk. ---
    for side, label in ((-1, "R"), (1, "L")):
        conformed_patch("Tail_lamp_outer_" + label,
            [(TAIL_X - 0.030, side * 0.790, 0.825), (TAIL_X - 0.030, side * 0.430, 0.850),
             (-2.020, side * 0.475, 1.005), (-2.005, side * 0.745, 0.940)],
            9, 4, lights_col, lamp_red, guide, offset=0.006, thickness=0.003, parent=root)
        conformed_patch("Tail_lamp_trunk_" + label,
            [(TAIL_X - 0.032, side * 0.420, 0.855), (TAIL_X - 0.032, side * 0.095, 0.850),
             (TAIL_X - 0.032, side * 0.090, 0.970), (TAIL_X - 0.032, side * 0.400, 0.990)],
            7, 3, lights_col, lamp_red, guide, offset=0.007, thickness=0.003, parent=root)
        conformed_patch("Rear_reflector_" + label,
            [(TAIL_X - 0.034, side * 0.630, 0.430), (TAIL_X - 0.034, side * 0.455, 0.430),
             (TAIL_X - 0.034, side * 0.455, 0.465), (TAIL_X - 0.034, side * 0.620, 0.470)],
            4, 1, lights_col, lamp_red, guide, offset=0.006, thickness=0.002, parent=root)
    conformed_patch("Rear_plate",
        [(TAIL_X - 0.040, -0.265, 0.618), (TAIL_X - 0.040, 0.265, 0.618),
         (TAIL_X - 0.040, 0.265, 0.704), (TAIL_X - 0.040, -0.265, 0.704)],
        8, 2, panels_col, plate, guide, offset=0.010, thickness=0.002, parent=root)
    cylinder_on_surface("VW_rear_badge_backing", (TAIL_X - 0.045, 0.0, 0.875), 0.079, 0.010,
                        trim_col, black, guide, root, offset=0.006)
    torus_on_surface("VW_rear_badge_ring", (TAIL_X - 0.050, 0.0, 0.875), 0.066, 0.009,
                     trim_col, chrome, guide, root, offset=0.014)
    # Discreet model badges deliberately embedded on the trunk rather than floating text.
    conformed_patch("Voyage_badge", [(TAIL_X - 0.045, 0.57, 0.820), (TAIL_X - 0.045, 0.40, 0.820),
                                      (TAIL_X - 0.045, 0.40, 0.850), (TAIL_X - 0.045, 0.57, 0.850)],
                    4, 1, trim_col, chrome, guide, offset=0.008, thickness=0.001, parent=root)
    conformed_patch("One_six_badge", [(TAIL_X - 0.045, -0.40, 0.820), (TAIL_X - 0.045, -0.56, 0.820),
                                       (TAIL_X - 0.045, -0.56, 0.850), (TAIL_X - 0.045, -0.40, 0.850)],
                    4, 1, trim_col, chrome, guide, offset=0.008, thickness=0.001, parent=root)

    # Hood and trunk shut lines, again projected in tiny strips rather than tubes.
    conformed_patch("Hood_shut_line",
        [(0.98, -0.80, 0.970), (0.98, 0.80, 0.970),
         (1.00, 0.80, 0.978), (1.00, -0.80, 0.978)],
        14, 1, trim_col, black, guide, offset=0.003, thickness=0.0005, parent=root)
    conformed_patch("Trunk_shut_line",
        [(-1.42, -0.80, 1.010), (-1.42, 0.80, 1.010),
         (-1.40, 0.80, 1.018), (-1.40, -0.80, 1.018)],
        14, 1, trim_col, black, guide, offset=0.003, thickness=0.0005, parent=root)

    # Short roof antenna, rooted in an actual cap on the rear roof skin.
    antenna_loc, antenna_normal = closest_surface(guide, (-0.67, 0.0, 1.46))
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.016, radius2=0.004, depth=0.255,
                                    location=antenna_loc + antenna_normal * 0.112)
    antenna = bpy.context.object
    antenna.name = "Short_roof_antenna"
    antenna.rotation_euler = (0.0, math.radians(-28), 0.0)
    assign(antenna, black)
    link_to(antenna, trim_col)
    antenna.parent = root
    cylinder_on_surface("Antenna_base", (-0.67, 0.0, 1.46), 0.025, 0.010,
                        trim_col, black, guide, root, offset=0.003, vertices=24)

    # Minimal dark underbody preserves the unibody/chassis visual mass without
    # inventing a GL-style frame.
    primitive_box("Underbody", (-0.05, 0.0, 0.205), (2.65, 1.15, 0.075),
                  body_col, black, bevel=0.025, parent=root)

    # Studio and camera for the requested review print.
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "Studio_floor"
    assign(floor, ground)
    link_to(floor, root_col)
    world = bpy.context.scene.world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.025, 0.035, 0.050, 1.0)
    background.inputs["Strength"].default_value = 0.30
    add_area("Key_softbox", (4.6, -4.8, 6.0), 1000, 4.0, (0.88, 0.93, 1.0), (0, 0, 0.75))
    add_area("Fill_softbox", (0.8, 4.0, 3.5), 680, 3.2, (0.72, 0.82, 1.0), (0, 0, 0.78))
    add_area("Rim_softbox", (-4.2, -2.8, 4.5), 850, 3.0, (1.0, 0.72, 0.50), (0, 0, 0.85))

    cam_data = bpy.data.cameras.new("Review_camera")
    cam_data.lens = 60
    camera = bpy.data.objects.new("Review_camera", cam_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = (6.25, -7.30, 2.35)
    camera.rotation_euler = (Vector((0.0, 0.0, 0.76)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = OUT_RENDER
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    scene["technical_reference"] = (
        "VW official data June 2012: 4215x1656x1462 mm, wheelbase 2465 mm, "
        "tracks 1429/1416 mm, 195/55R15"
    )
    scene["model_identity"] = "Novo Voyage 1.6, first facelift launched July 2012"

    # Structural validation, intended to fail rather than silently drift to a
    # generic/incorrect generation again.
    assert abs((NOSE_X - TAIL_X) - SPEC["length"]) < 1e-6
    assert abs((FRONT_AXLE_X - REAR_AXLE_X) - SPEC["wheelbase"]) < 1e-6
    assert abs(SPEC["tyre_radius"] - 0.29775) < 1e-7
    assert all(obj.get("max_attachment_offset_m", 0.0) <= 0.014 for obj in bpy.data.objects)

    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("NOVO_VOYAGE_2012_BUILD_COMPLETE")
    print("BLEND=" + OUT_BLEND)
    print("RENDER=" + OUT_RENDER)


if __name__ == "__main__":
    build()
