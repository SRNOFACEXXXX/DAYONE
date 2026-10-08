extends SceneTree
func _initialize(): call_deferred('probe')
func probe():
 for path in ['res://assets/models/zombies/scary_zombie_pack/Ch35_nonPBR.fbx','res://assets/animations/scary_zombie_pack/zombie idle.fbx']:
  var packed=load(path) as PackedScene
  print('PACKED ',path,' loaded=',packed!=null)
  if packed==null: continue
  var root=packed.instantiate(); print('ROOT ',root.name,' children=',root.get_child_count())
  var stack=[root]
  while not stack.is_empty():
   var n=stack.pop_back()
   if n is Skeleton3D:
    var s=n as Skeleton3D;var bones=[]
    for i in s.get_bone_count(): bones.append(str(s.get_bone_name(i)) + ':' + str(s.get_bone_global_rest(i).origin))
    print('SKELETON path=',root.get_path_to(s),' count=',s.get_bone_count(),' global=',s.global_transform,' bones=',','.join(bones.slice(0,12)))
   if n is AnimationPlayer:
    var ap=n as AnimationPlayer; print('AP path=',root.get_path_to(ap),' root_node=',ap.root_node,' clips=',ap.get_animation_list())
    for clip in ap.get_animation_list():
     var a=ap.get_animation(clip);print('CLIP ',clip,' len=',a.length,' tracks=',a.get_track_count())
     for i in mini(8,a.get_track_count()): print('TRACK ',a.track_get_path(i))
   for c in n.get_children(): stack.append(c)
  root.free()
 quit()

