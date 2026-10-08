extends SceneTree
func _initialize(): call_deferred('p')
func p():
 var root=(load('res://assets/models/zombies/polyart_pack/zombie_ani_player.fbx') as PackedScene).instantiate();var rig=root.get_node('rig_CharRoot');var sk=rig.find_child('Skeleton3D',true,false) as Skeleton3D
 for i in sk.get_bone_count(): print('BONE ',i,' ',sk.get_bone_name(i),' par=',sk.get_bone_parent(i))
 for m in sk.find_children('*','MeshInstance3D',true,false):
  if m.skin:
   print('SKIN ',m.name,' binds=',m.skin.get_bind_count())
   for i in mini(10,m.skin.get_bind_count()): print(i,' ',m.skin.get_bind_name(i))
 await process_frame;root.free();quit()
