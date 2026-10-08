"""Temporary 4.5-LTS render harness for the verified continuous blueprint body.

This does not touch the user's existing model directory.  It reads only its
curve data/build recipe, constructs a fresh scene, then saves the result in the
active workspace for visual comparison.
"""

import bpy
import os
from mathutils import Vector


OUT_DIR = r"C:\Users\satoshi\Documents\ChatGPT\teste"
SOURCE = r"C:\Users\satoshi\Documents\voyage\scripts\build_body_v3.py"
OUT_BLEND = os.path.join(OUT_DIR, "voyage_2012_blueprint_prototype.blend")
OUT_PNG = os.path.join(OUT_DIR, "voyage_2012_blueprint_prototype.png")


def ensure_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


# Fresh empty scene and the collection contract expected by the reusable core.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for col_name in ("Carroceria", "Iluminacao", "Rodas", "Interior"):
    ensure_collection(col_name)

# The original script was written against a pre-created studio scene.  Its
# material helper assumes Blender auto-adds a Principled node; make that one
# compatibility adjustment in memory for Blender 4.5's blank startup scene.
source = open(SOURCE, "r", encoding="utf-8").read()
old = """    p = principled(m)\n    p.inputs[\"Base Color\"].default_value = base"""
new = """    p = principled(m)\n    if p is None:\n        p = m.node_tree.nodes.new(\"ShaderNodeBsdfPrincipled\")\n        out = next((n for n in m.node_tree.nodes if n.type == \"OUTPUT_MATERIAL\"), None)\n        if out is None:\n            out = m.node_tree.nodes.new(\"ShaderNodeOutputMaterial\")\n        m.node_tree.links.new(p.outputs[\"BSDF\"], out.inputs[\"Surface\"])\n    p.inputs[\"Base Color\"].default_value = base"""
if old not in source:
    raise RuntimeError("Could not safely apply the Blender 4.5 material compatibility shim.")
source = source.replace(old, new, 1)
exec(compile(source, SOURCE, "exec"), {"__name__": "__blueprint_core__"})

# Use the supplied-photo silver and a fast presentational render for reviewing
# topology and silhouette.  The final build will keep this body foundation but
# replace details only after the reference identity is locked down.
paint = bpy.data.materials.get("MAT_Pintura_Branca")
if paint:
    bsdf = next((n for n in paint.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.42, 0.45, 0.48, 1.0)
        bsdf.inputs["Metallic"].default_value = 0.65
        bsdf.inputs["Roughness"].default_value = 0.24

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 960
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT_PNG
scene.render.film_transparent = False


def area(name, loc, energy, size, color):
    light_data = bpy.data.lights.new(name, "AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size
    light_data.color = color
    light = bpy.data.objects.new(name, light_data)
    bpy.context.scene.collection.objects.link(light)
    light.location = loc
    look_at(light, (0.0, 0.0, 0.78))


area("Review_Key", (4.2, -4.5, 6.3), 1200, 4.0, (0.86, 0.92, 1.0))
area("Review_Fill", (1.0, 4.0, 4.0), 700, 3.0, (0.75, 0.83, 1.0))
area("Review_Rim", (-4.0, -2.0, 4.5), 850, 2.5, (1.0, 0.72, 0.52))

cam_data = bpy.data.cameras.new("Review_camera")
cam_data.lens = 58
camera = bpy.data.objects.new("Review_camera", cam_data)
bpy.context.scene.collection.objects.link(camera)
camera.location = (6.45, -7.45, 2.55)
look_at(camera, (0.0, 0.0, 0.75))
scene.camera = camera

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("BLUEPRINT_PROTOTYPE_COMPLETE")
