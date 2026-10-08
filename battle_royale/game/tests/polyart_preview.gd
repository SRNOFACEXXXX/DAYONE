extends Node3D
const SOURCE='res://assets/models/zombies/polyart_pack/zombie_ani_player.fbx'
var ap: AnimationPlayer
var frame=0
func _ready():
 var root=(load(SOURCE) as PackedScene).instantiate(); add_child(root)
 ap=root.find_child('AnimationPlayer',true,false); ap.play('Take 001')
 var env=WorldEnvironment.new(); var e=Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color('89abc1'); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color.WHITE; e.ambient_light_energy=1; env.environment=e; add_child(env)
 var floor=MeshInstance3D.new(); var mesh=PlaneMesh.new(); mesh.size=Vector2(20,20); floor.mesh=mesh; floor.position.y=-0.05; var m=StandardMaterial3D.new(); m.albedo_color=Color('68775b'); floor.material_override=m; add_child(floor)
 var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-25,0); add_child(light)
 var cam=Camera3D.new(); cam.position=Vector3(6,4,8); cam.fov=48; add_child(cam); cam.look_at(Vector3(0,1,0)); cam.current=true
 await get_tree().process_frame
 for i in 5:
  await get_tree().create_timer(0.5).timeout
  await RenderingServer.frame_post_draw
  var image=get_viewport().get_texture().get_image(); image.save_png(ProjectSettings.globalize_path('res://../raw/polyart_preview_%02d.png'%i))
 print('POLYART_PREVIEW frames=5')
 get_tree().quit()
