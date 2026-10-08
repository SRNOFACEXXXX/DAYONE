import bpy
s=bpy.context.scene
s.render.engine='BLENDER_EEVEE_NEXT'
s.render.resolution_percentage=65
s.render.filepath=r'C:\Users\satoshi\Documents\ChatGPT\teste\voyage_rebuild_review_v2.png'
bpy.ops.render.render('INVOKE_DEFAULT',write_still=True)
result={'render_started':True,'path':s.render.filepath}
