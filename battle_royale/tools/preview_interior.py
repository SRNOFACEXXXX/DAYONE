# Pré-visualização de interiores: importa um .glb de prédio, corta tudo acima de uma altura (teto/telhado) e renderiza
# uma vista de cima e uma oblíqua (Workbench, cor do material). Só para conferir layout; não altera nenhum asset.
# Uso: blender -b --factory-startup -P tools/preview_interior.py -- <modelo> <z_corte> <pasta_saida> [andar_z_min]
import bpy, bmesh, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
nome, zc, saida = args[0], float(args[1]), args[2]
zmin = float(args[3]) if len(args) > 3 else -10.0
os.makedirs(saida, exist_ok=True)
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "predios", nome + ".glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
bpy.context.view_layer.update()
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    bpy.context.view_layer.objects.active = o
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    me.transform(o.matrix_world)
    o.parent = None
    o.matrix_world = __import__("mathutils").Matrix.Identity(4)
    bm.clear()
    bm.from_mesh(me)
    # glTF importa Y-up -> Blender Z-up já convertido; corta por z global
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, zc), plane_no=(0, 0, 1), clear_outer=True)
    if zmin > -5:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, zmin), plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=8)
    bm.to_mesh(me)
    bm.free()
    for m in me.materials:
        if m:
            m.use_backface_culling = False
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.show_cavity = True
sc.display.shading.cavity_type = "BOTH"
sc.display.shading.show_object_outline = True
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_shadows = False
sc.render.resolution_x, sc.render.resolution_y = 1000, 1000
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.55, 0.65, 0.75)
cam_d = bpy.data.cameras.new("c")
cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
# dimensões
bpy.context.view_layer.update()
xs, ys = [], []
for o in meshes:
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        xs.append(w.x)
        ys.append(w.y)
cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
ext = max(max(xs) - min(xs), max(ys) - min(ys))
cam_d.type = "ORTHO"
cam_d.ortho_scale = ext * 1.05
cam.location = (cx, cy, 60)
cam.rotation_euler = (0, 0, 0)
sc.render.filepath = os.path.join(saida, nome + "_topo.png")
bpy.ops.render.render(write_still=True)
cam_d.ortho_scale = ext * 1.25
cam.location = (cx + ext * 0.0, cy - ext * 1.1, ext * 1.0 + 4)
cam.rotation_euler = (math.radians(52), 0, 0)
sc.render.filepath = os.path.join(saida, nome + "_obliqua.png")
bpy.ops.render.render(write_still=True)
print("PREVIEW", nome)
