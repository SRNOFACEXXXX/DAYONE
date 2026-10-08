extends SceneTree
func _initialize():
 call_deferred('probe')
func probe():
 var scene=load('res://assets/models/zombies/polyart_pack/zombie_ani_player.fbx') as PackedScene
 var root=scene.instantiate()
 var player=root.find_child('AnimationPlayer',true,false)
 print('ROOT ',root.name,' children ',root.get_child_count(),' animation ',player.get_animation_list())
 for n in root.get_children():
  print('NODE ',n.name,' type ',n.get_class(),' position ',n.position,' children ',n.get_child_count())
 var stack=[root]
 while not stack.is_empty():
  var n=stack.pop_back()
  if n is Skeleton3D:
   print('SKEL ',n.name,' path ',root.get_path_to(n),' bones ',n.get_bone_count(),' global ',n.global_position)
  for c in n.get_children(): stack.append(c)
 var a=player.get_animation('Take 001')
 for i in a.get_track_count(): print('TRACK ',a.track_get_path(i))
 root.free()
 quit()
