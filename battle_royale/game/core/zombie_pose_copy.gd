extends SkeletonModifier3D
## Applies source animation deltas in actor-world space to an independent Polyart rig.
## Keeping rigs separate avoids inheriting the source GLTF's scale and axis conversion.
## Desempenho: pares de ossos, pesos e poses de descanso ficam em cache (eram recalculados a cada quadro com
## find_bone por osso). A conta é a mesma: motion_world = F·(Rp·Rr⁻¹)·F⁻¹ e desired = T⁻¹·slerp(motion)·T·Tr,
## com F/T = base global (ortonormal) do esqueleto fonte/alvo; como slerp a partir da identidade comuta com a
## conjugação, desired = K·slerp(Rp·Rr⁻¹, w)·K⁻¹·Tr_local, K = T⁻¹·F.

const OSSOS := [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand",
	&"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand",
	&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
	&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes"]

var source_skeleton: Skeleton3D
var _alvo_idx: PackedInt32Array = []
var _fonte_idx: PackedInt32Array = []
var _peso: PackedFloat32Array = []
var _fonte_rest_inv: Array[Quaternion] = []
var _alvo_rest: Array[Quaternion] = []
var _cache_ok := false


func _montar_cache(target: Skeleton3D) -> void:
	var pares: Array = []
	for bone_name in OSSOS:
		var ti := target.find_bone(bone_name)
		var si := source_skeleton.find_bone(bone_name)
		if ti >= 0 and si >= 0:
			pares.append([ti, si, bone_name])
	pares.sort_custom(func(a, b): return a[0] < b[0])   # pais antes dos filhos (global pose)
	for p in pares:
		_alvo_idx.append(p[0])
		_fonte_idx.append(p[1])
		_peso.append(_motion_weight(p[2]))
		_fonte_rest_inv.append(source_skeleton.get_bone_global_rest(p[1]).basis.orthonormalized().get_rotation_quaternion().inverse())
		_alvo_rest.append(target.get_bone_global_rest(p[0]).basis.orthonormalized().get_rotation_quaternion())
	_cache_ok = true


func _process_modification() -> void:
	var target := get_skeleton()
	if source_skeleton == null or target == null:
		return
	if not _cache_ok:
		_montar_cache(target)
	var source_frame := source_skeleton.global_basis.orthonormalized().get_rotation_quaternion()
	var target_frame := target.global_basis.orthonormalized().get_rotation_quaternion()
	var k := target_frame.inverse() * source_frame
	var k_inv := k.inverse()
	for i in _alvo_idx.size():
		var ti := _alvo_idx[i]
		var source_pose := source_skeleton.get_bone_global_pose(_fonte_idx[i])
		var motion := source_pose.basis.orthonormalized().get_rotation_quaternion() * _fonte_rest_inv[i]
		# Retargeting different proportions at full source amplitude makes the Polyart
		# gait look like the elbows and knees snap to the ends of their ranges. Keep
		# the authored timing, but soften those angular excursions for this rig.
		motion = Quaternion.IDENTITY.slerp(motion, _peso[i])
		var target_pose := target.get_bone_global_pose(ti)
		target_pose.basis = Basis(k * motion * k_inv * _alvo_rest[i])
		target.set_bone_global_pose(ti, target_pose)


func _motion_weight(bone_name: StringName) -> float:
	if bone_name in [&"LeftUpperLeg", &"RightUpperLeg", &"LeftLowerLeg", &"RightLowerLeg"]:
		return 0.78
	if bone_name in [&"LeftUpperArm", &"RightUpperArm", &"LeftLowerArm", &"RightLowerArm"]:
		return 0.72
	if bone_name in [&"LeftFoot", &"RightFoot", &"LeftToes", &"RightToes"]:
		return 0.82
	return 0.82
