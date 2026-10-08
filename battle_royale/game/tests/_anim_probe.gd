extends SceneTree
func _init() -> void:
	for w in ["ak47", "m4", "pistol"]:
		var sc: Node = load("res://assets/models/weapons/%s_fp.tscn" % w).instantiate()
		var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for an in ["idle", "fire"]:
			var a := ap.get_animation(an)
			print("== %s %s len=%.2f tracks=%d" % [w, an, a.length, a.get_track_count()])
			for t in a.get_track_count():
				var p := String(a.track_get_path(t))
				if "Arma" in p or a.track_get_type(t) != Animation.TYPE_ROTATION_3D and "Skeleton" not in p:
					var ks := []
					for k in mini(a.track_get_key_count(t), 6):
						ks.append(str(a.track_get_key_value(t, k)))
					print("  ", p, " type=", a.track_get_type(t), " ", ks)
		sc.free()
	quit()
