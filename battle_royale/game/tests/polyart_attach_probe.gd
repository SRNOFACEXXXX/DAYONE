extends SceneTree
func _initialize(): call_deferred('p')
func p():
 var x=(load('res://assets/models/zombies/polyart_pack/zombie_ani_player.fbx') as PackedScene).instantiate()
 for i in range(10):
  var n='rig_CharRoot'+(('%03d'%i) if i>0 else '')
  var rig=x.get_node(n)
  for b in rig.find_children('*','BoneAttachment3D',true,false): print(n,' ATT ',b.name,' bone=',b.bone_name,' idx=',b.bone_idx)
 quit()
