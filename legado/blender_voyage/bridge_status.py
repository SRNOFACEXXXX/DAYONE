import bpy
result={'rendering':bpy.app.is_job_running('RENDER'),'scene':bpy.context.scene.name,'objects':len(bpy.context.scene.objects),'file':bpy.data.filepath}
