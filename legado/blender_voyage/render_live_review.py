import bpy
bpy.context.scene.render.engine='CYCLES'
bpy.context.scene.cycles.samples=32
bpy.context.scene.render.resolution_percentage=70
bpy.ops.render.render('INVOKE_DEFAULT',write_still=True)
result={'render_started':True,'path':bpy.context.scene.render.filepath}
