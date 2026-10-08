extends Node
## Laboratório de pose de quadril: no estande, aplica várias poses candidatas (alça em ponto da câmera + pitch/yaw/roll)
## direto no Holder e salva uma captura por pose. Uso: -- --arma=ak47 --out=raw/pose_lab
const POSES := [
	["a", Vector3(0.06, -0.06, -0.18), Vector3(0, 10, -8)],
	["b", Vector3(0.05, -0.05, -0.16), Vector3(0, 14, -12)],
	["c", Vector3(0.07, -0.07, -0.20), Vector3(0, 8, -6)],
	["d", Vector3(0.05, -0.065, -0.15), Vector3(-2, 16, -14)],
	["e", Vector3(0.08, -0.05, -0.20), Vector3(0, 6, -10)],
	["f", Vector3(0.045, -0.055, -0.14), Vector3(-3, 20, -18)],
]
var m: EstandeMatch


func _ready() -> void:
	Game.test_mode = true
	var out: String = Game.test_args.get("out", "user://pose_lab")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	m = load("res://core/estande_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var arma := StringName(Game.test_args.get("arma", "ak47"))
	m.equipar(arma)
	var pc := m.local_player.controller as PlayerController
	pc._prefer_third_person = false
	pc._set_third_person(false)
	await get_tree().create_timer(1.5).timeout
	var vm: ViewModel = pc.viewmodel
	for p in POSES:
		var alvo: Vector3 = p[1]
		var r: Vector3 = p[2]
		var b := Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z)))
		# holder tal que a alça (no espaço do holder em identidade) vá para 'alvo' e gire em volta dela
		var rel := ViewModel._rel(vm._mira_no, vm.holder)
		var alca_h: Vector3 = rel * vm._alca
		vm._hip = Transform3D(b, alvo - b * alca_h)
		vm._hip_pivo = alvo
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [arma, p[0]]))
	get_tree().quit()
