import bpy,bmesh,math
scene=bpy.context.scene
# Wait for rendering before applying a structural correction.
if bpy.app.is_job_running('RENDER'):
    raise RuntimeError('Render still running; retry this correction after completion')
for o in scene.objects:
    if o.type!='MESH':continue
    if o.name.startswith('Side glazing'):
        for v in o.data.vertices:v.co.y-=math.copysign(.0025,v.co.y)
    if o.name.startswith(('Windscreen','Rear windscreen')):
        for v in o.data.vertices:v.co.z-=.0015
    if o.name.startswith(('Left body sheet','Right body sheet','Hood and forward fenders','Trunk lid and rear quarters')):
        for v in o.data.vertices:
            x,y,z=v.co
            if x< -1.85:
                t=max(0,min(1,(-1.85-x)/.2));v.co.x+=.095*(abs(y)/.715)**3*t*t
            if x>1.965:
                t=max(0,min(1,(x-1.965)/.2));v.co.x-=.095*(abs(y)/.738)**3*t*t
    # Make winding consistent per disconnected mesh sheet.
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
for m in bpy.data.materials:
    if m.name.startswith('W3'):
        p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if p:m.diffuse_color=p.inputs['Base Color'].default_value
scene.render.resolution_percentage=80
scene.cycles.samples=48
bpy.ops.wm.save_as_mainfile(filepath=r'C:\Users\satoshi\Documents\ChatGPT\teste\voyage_rebuild_v3.blend')
result={'corrected':True,'objects':len(scene.objects)}
