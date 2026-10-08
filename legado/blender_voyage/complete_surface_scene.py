from pathlib import Path
source=Path(r'C:\Users\satoshi\Documents\ChatGPT\teste\voyage_surface_rebuild.py').read_text(encoding='utf-8')
prefix=source[:source.index('scene=bpy.data.scenes.new')]
helpers=source[source.index('def mat('):source.index('paint=mat(')]
tail=source[source.index('wheel_spec='):]
import bpy, math, importlib.util
from mathutils import Vector
OUT=Path(r'C:\Users\satoshi\Documents\ChatGPT\teste')
scene=bpy.context.scene
root=scene.objects.get('VOYAGE | exterior assembly')
cols={c.name:c for c in scene.collection.children}
exec(helpers)
def grid(name,fn,nu,nv,m,col='Studio',solid=0):
    vs=[fn(i/nu,j/nv) for i in range(nu+1) for j in range(nv+1)]
    fs=[(i*(nv+1)+j,(i+1)*(nv+1)+j,(i+1)*(nv+1)+j+1,i*(nv+1)+j+1) for i in range(nu) for j in range(nv)]
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);cols[col].objects.link(o);me.materials.append(m)
exec(tail)
