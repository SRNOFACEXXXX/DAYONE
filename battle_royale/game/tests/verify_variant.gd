extends SceneTree
func _initialize():call_deferred('p')
func p():
 var r=(load('res://assets/models/zombies/polyart_pack/variants/zombie_00.tscn') as PackedScene).instantiate();var s=r.find_child('Skeleton3D',true,false)
 for i in s.get_bone_count():print(i,' ',s.get_bone_name(i))
 quit()
