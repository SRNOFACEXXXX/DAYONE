"""Render side and rear validation views from the current Nouveau Voyage blend."""

import bpy
import os
from mathutils import Vector

OUT_DIR = r"C:\Users\satoshi\Documents\ChatGPT\teste"
camera = bpy.data.objects.get("Review_camera")
if camera is None:
    raise RuntimeError("Review camera missing from loaded blend")

def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 960
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"

camera.location = (0.20, -8.20, 1.72)
camera.data.lens = 58
look_at(camera, (-0.12, 0.0, 0.73))
scene.render.filepath = os.path.join(OUT_DIR, "novo_voyage_2012_g6_side.png")
bpy.ops.render.render(write_still=True)

camera.location = (-6.35, 6.95, 2.35)
camera.data.lens = 60
look_at(camera, (-0.40, 0.0, 0.76))
scene.render.filepath = os.path.join(OUT_DIR, "novo_voyage_2012_g6_rear.png")
bpy.ops.render.render(write_still=True)
print("REVIEW_VIEWS_COMPLETE")
