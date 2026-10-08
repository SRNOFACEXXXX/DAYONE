extends SceneTree
const SOURCE='res://assets/models/zombies/polyart_pack/zombie_ani_player.fbx'
const OUTPUT='res://assets/models/zombies/polyart_pack/variants/'
const HUMANOID_NAMES={
 'bip Pelvis':'Hips','bip Spine':'Spine','bip Spine1':'Chest','bip Spine2':'UpperChest','bip Neck':'Neck','bip Head':'Head',
 'bip L Clavicle':'LeftShoulder','bip L UpperArm':'LeftUpperArm','bip L Forearm':'LeftLowerArm','bip L Hand':'LeftHand',
 'bip R Clavicle':'RightShoulder','bip R UpperArm':'RightUpperArm','bip R Forearm':'RightLowerArm','bip R Hand':'RightHand',
 'bip L Thigh':'LeftUpperLeg','bip L Calf':'LeftLowerLeg','bip L Foot':'LeftFoot','bip L Toe0':'LeftToes',
 'bip R Thigh':'RightUpperLeg','bip R Calf':'RightLowerLeg','bip R Foot':'RightFoot','bip R Toe0':'RightToes'
}
func _initialize(): call_deferred('build')
func _set_owners(node:Node,root:Node):
 for child in node.get_children(): child.owner=root; _set_owners(child,root)
func build():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var source=(load(SOURCE) as PackedScene).instantiate()
 var base_rig=source.get_node('rig_CharRoot')
 var base_skeleton=base_rig.find_child('Skeleton3D',true,false) as Skeleton3D
 var target_names=[]
 for index in base_skeleton.get_bone_count():
  var base_name=String(base_skeleton.get_bone_name(index))
  target_names.append(String(HUMANOID_NAMES.get(base_name, 'PolyRoot' if index==0 else base_name.trim_prefix('bip '))))
 for i in 10:
  var rig_name='rig_CharRoot' + (('%03d'%i) if i>0 else '')
  var rig=source.get_node_or_null(NodePath(rig_name)) as Node3D
  if rig==null: push_error('missing rig '+rig_name); continue
  var variant=Node3D.new(); variant.name='PolyartZombie%02d'%i
  var rig_copy=rig.duplicate(8) as Node3D; rig_copy.name=rig_name
  # Preserve the FBX import's Z-up to Godot Y-up basis; drop only lineup offset.
  var model_basis=rig.transform.basis
  rig_copy.transform=Transform3D(model_basis,Vector3.ZERO)
  variant.add_child(rig_copy)
  var skeleton=rig_copy.find_child('Skeleton3D',true,false) as Skeleton3D
  var old_names=[]
  for bone_index in skeleton.get_bone_count(): old_names.append(String(skeleton.get_bone_name(bone_index)))
  for mesh_node in skeleton.find_children('*','MeshInstance3D',true,false):
   if mesh_node.skin==null: continue
   var skin=mesh_node.skin.duplicate(true) as Skin
   for bind_index in skin.get_bind_count():
    var old_bind=String(skin.get_bind_name(bind_index))
    var bone_index=skeleton.find_bone(old_bind)
    if bone_index<0:
     for candidate_index in old_names.size():
      var candidate=old_names[candidate_index]
      if old_bind.begins_with(candidate):
       var suffix=old_bind.trim_prefix(candidate)
       if suffix.is_empty() or suffix.is_valid_int(): bone_index=candidate_index; break
    if bone_index>=0 and bone_index<target_names.size(): skin.set_bind_name(bind_index,StringName(target_names[bone_index]))
   mesh_node.skin=skin
  for bone_index in skeleton.get_bone_count(): skeleton.set_bone_name(bone_index,StringName(target_names[bone_index]))
  for attachment in skeleton.find_children('*','BoneAttachment3D',true,false):
   var bone_index=old_names.find(String(attachment.bone_name))
   if bone_index>=0: attachment.bone_name=StringName(target_names[bone_index])
  _set_owners(variant,variant)
  var packed=PackedScene.new();var err=packed.pack(variant)
  if err==OK:
   var path=OUTPUT.path_join('zombie_%02d.tscn'%i);var save_err=ResourceSaver.save(packed,path)
   print('POLYART_VARIANT ',path,' bones=',skeleton.get_bone_count(),' Hips=',skeleton.find_bone('Hips'),' Spine=',skeleton.find_bone('Spine'),' LeftLeg=',skeleton.find_bone('LeftUpperLeg'),' save=',save_err)
  else: push_error('pack failed '+str(err))
  variant.free()
 source.free();quit()

