# Vista lateral ortográfica de uma arma do jogo (.glb) com grade de 1/5 cm e marcadores (espaço Godot: x direita, y cima, -z frente).
# Uso: blender -b --factory-startup -P tools/vista_arma.py -- arma.glb saida.png "nome:x,y,z;nome2:x,y,z"
import bpy, sys, os, math
from mathutils import Vector as V

a = sys.argv[sys.argv.index("--") + 1:]
glb, out = a[0], a[1]
marcas = []
if len(a) > 2 and a[2]:
    for m in a[2].split(";"):
        n, p = m.split(":")
        marcas.append((n, [float(x) for x in p.split(",")]))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
lo = V((1e9,) * 3); hi = V((-1e9,) * 3)
for o in obs:
    for c in o.bound_box:
        w = o.matrix_world @ V(c)
        lo = V(map(min, lo, w)); hi = V(map(max, hi, w))


def G2B(p):   # Godot -> Blender
    return V((p[0], -p[2], p[1]))


def mat(nome, cor):
    m = bpy.data.materials.new(nome)
    m.diffuse_color = (*cor, 1)
    return m


# grade no plano x = 0.2 (atrás da arma, vista de +X): linhas a cada 1 cm (finas) e 5 cm (grossas)
cinza = mat("g", (0.55, 0.55, 0.6)); forte = mat("f", (0.25, 0.25, 0.3))
z0, z1 = math.floor(-hi.y * 100) - 2, math.ceil(-lo.y * 100) + 2     # z Godot = -y Blender
y0, y1 = math.floor(lo.z * 100) - 2, math.ceil(hi.z * 100) + 2
xg = -0.3
for zc in range(z0, z1 + 1):
    grosso = zc % 5 == 0
    bpy.ops.mesh.primitive_cube_add(size=1, location=G2B((xg, (y0 + y1) / 200, zc / 100)))
    o = bpy.context.object; o.scale = (0.0005, 0.0006 if not grosso else 0.0015, (y1 - y0) / 100)
    o.data.materials.append(forte if grosso else cinza)
for yc in range(y0, y1 + 1):
    grosso = yc % 5 == 0
    bpy.ops.mesh.primitive_cube_add(size=1, location=G2B((xg, yc / 100, (z0 + z1) / 200)))
    o = bpy.context.object; o.scale = (0.0005, (z1 - z0) / 100, 0.0006 if not grosso else 0.0015)
    o.data.materials.append(forte if grosso else cinza)
cores = [(1, 0, 0), (0, 0.8, 0), (0, 0.3, 1), (1, 0.6, 0), (0.8, 0, 0.8)]
for i, (n, p) in enumerate(marcas):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.006, location=G2B(p) + V((0.3, 0, 0)))
    bpy.context.object.data.materials.append(mat(n, cores[i % len(cores)]))
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); bpy.context.scene.collection.objects.link(cam)
cam.data.type = "ORTHO"
span = max(hi.y - lo.y, hi.z - lo.z) * 1.08
cam.data.ortho_scale = span
c = (lo + hi) / 2
cam.location = V((3.0, c.y, c.z)); cam.rotation_euler = (math.radians(90), 0, math.radians(90))
bpy.context.scene.camera = cam
r = bpy.context.scene.render; r.engine = "BLENDER_WORKBENCH"
r.resolution_x = 1600; r.resolution_y = int(1600 * (hi.z - lo.z + 0.06) / (hi.y - lo.y + 0.06)) + 40
bpy.context.scene.display.shading.color_type = "TEXTURE"
bpy.context.scene.display.shading.light = "FLAT"
w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.color = (0.9, 0.9, 0.92)
r.filepath = out
bpy.ops.render.render(write_still=True)
print("VISTA", out, "z(cm) %d..%d  y(cm) %d..%d" % (z0, z1, y0, y1))
