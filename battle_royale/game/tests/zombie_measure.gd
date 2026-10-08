extends Node3D
## Mede altura do zumbi vs Soldier e velocidade de passada (pé de apoio) de walk/run.
var _z: ZombieEnemy
var _sk: Skeleton3D
var _last := []
func _sample() -> void:
	var lf := _sk.find_bone("LeftFoot"); var rf := _sk.find_bone("RightFoot")
	var inv := _z.global_transform.affine_inverse()
	_last = [inv * (_sk.global_transform * _sk.get_bone_global_pose(lf).origin), inv * (_sk.global_transform * _sk.get_bone_global_pose(rf).origin)]

func _ready() -> void:
	_z = ZombieEnemy.new()
	_z.set("_variant_index", 0)
	_z.set("_demo_locked", true)
	add_child(_z)
	await get_tree().process_frame
	await get_tree().process_frame
	var ap := _z.get("_animation_player") as AnimationPlayer
	(_z.get("_animation_tree") as AnimationTree).active = false
	_sk = _z.get("_target_skeleton") as Skeleton3D
	_sk.skeleton_updated.connect(_sample)
	var cap := (_z.get_node("BodyCollider") as CollisionShape3D).shape as CapsuleShape3D
	print("MEASURE soldier_capsule_h=", Soldier.STAND_HEIGHT, " zombie_capsule_h=", cap.height, " zombie_mesh_h=", _z.get("_fitted_visual_height"))
	for clip in [&"walk", &"run"]:
		var anim := ap.get_animation(clip)
		var n := 48
		var dt := anim.length / n
		var pos := []
		for i in n + 1:
			ap.play(clip); ap.seek(dt * i, true); ap.pause()
			await get_tree().process_frame
			await get_tree().process_frame
			pos.append(_last.duplicate())
		var tot := 0.0; var cnt := 0; var ymin := 9.0; var ymax := -9.0; var zr := 0.0
		for i in n:
			for k in 2:
				var p0: Vector3 = pos[i][k]; var p1: Vector3 = pos[i + 1][k]; var q0: Vector3 = pos[i][1 - k]
				ymin = minf(ymin, p0.y); ymax = maxf(ymax, p0.y)
				if p0.y <= q0.y:   # pé de apoio = o mais baixo
					tot += absf((p1.z - p0.z) / dt); cnt += 1
		print("MEASURE clip=", clip, " length=", anim.length, " stance_foot_speed=", tot / maxf(cnt, 1), " foot_y=[", ymin, ",", ymax, "] samples=", cnt)
	# fase 2: árvore ativa (como no jogo), estado forçado a walk/run; pé de apoio vs velocidade real
	(_z.get("_animation_tree") as AnimationTree).active = true
	ap.pause()
	for st in [&"walk", &"run"]:
		_z.set_demo_state(st)
		(_z.get("_animation_tree") as AnimationTree).active = true
		for i in 20: await get_tree().process_frame
		var spd: float = _z.get("_demo_locomotion_speed")
		var hist: Array = []
		var last: Array = []
		var tot2 := 0.0; var cnt2 := 0
		var t := 0.0
		while t < 3.0:
			await get_tree().process_frame
			var d := get_process_delta_time(); t += d
			var cur := _last.duplicate()
			hist.append([t, cur])
			while hist.size() > 1 and t - float(hist[0][0]) > 0.3: hist.pop_front()
			if t > 0.4 and t - float(hist[0][0]) > 0.28:
				var a: Array = hist[0][1]
				var dtw := t - float(hist[0][0])
				for k in 2:
					var ymean := ((cur[k] as Vector3).y + (a[k] as Vector3).y) * 0.5
					var ymean_o := ((cur[1 - k] as Vector3).y + (a[1 - k] as Vector3).y) * 0.5
					if ymean < ymean_o:
						tot2 += absf(((cur[k] as Vector3).z - (a[k] as Vector3).z) / dtw); cnt2 += 1
			last = cur
		print("MEASURE2 state=", st, " ground_speed=", spd, " time_scale=", (_z.get("_animation_tree") as AnimationTree).get("parameters/TimeScale/scale"), " stance_foot_speed=", tot2 / maxf(cnt2, 1))
	get_tree().quit()
