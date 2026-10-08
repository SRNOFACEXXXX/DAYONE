extends SceneTree
func _init() -> void:
	var ik = ClassDB.instantiate("TwoBoneIK3D")
	ik.setting_count = 1
	for p in ik.get_property_list():
		if String(p.name).begins_with("settings/") or p.name in ["influence", "active"]:
			print("  P ", p.name, " type=", p.type)
	for m in ClassDB.class_get_method_list("TwoBoneIK3D", true):
		print("  M ", m.name)
	quit()
