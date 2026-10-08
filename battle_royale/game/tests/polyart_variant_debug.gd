extends SceneTree
func _initialize(): call_deferred('p')
func p():
 var root=(load('res://assets/models/zombies/polyart_pack/variants/zombie_00.tscn') as PackedScene).instantiate(); get_root().add_child(root)
 var skel=root.find_child('Skeleton3D',true,false) as Skeleton3D
 print('skel basis=',skel.global_transform.basis,' bones=',skel.get_bone_count())
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color('89abc1');e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_energy=1;env.environment=e;get_root().add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);get_root().add_child(light)
 var cam=Camera3D.new();cam.position=Vector3(0,1.3,3.2);cam.fov=48;get_root().add_child(cam);cam.look_at(Vector3(0,0.9,0));cam.current=true
 await process_frame;await RenderingServer.frame_post_draw;get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path('res://../raw/polyart_variant_unplayed.png'))
 quit()
