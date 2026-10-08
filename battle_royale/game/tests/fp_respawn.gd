extends Node
## Arma na mão (1ª pessoa) antes e depois de renascer. Capturas raw/spawn/fp_antes.png / fp_depois.png
func _ready() -> void:
	get_tree().create_timer(100.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["spawn_costa"] = "1"
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	var s: Soldier = m.local_player
	var pc := s.controller as PlayerController
	var out := ProjectSettings.globalize_path("res://").path_join("../raw/spawn")
	DirAccess.make_dir_recursive_absolute(out)
	for i in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("fp_antes.png"))
	print("antes: camera_current=", pc.camera.current, " fov=", pc.camera.fov, " vm_enabled=", pc.viewmodel.viewmodel_enabled, " frozen=", s.frozen)
	for k in 3:
		m.respawn(s)
		for i in 150:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("fp_depois%d.png" % k))
		var vm := pc.viewmodel
		print("respawn %d: arma=%s vm=%s modelo=%s anim=%s" % [k, s.current_def().id if s.current_def() else "-", vm.current_id, vm.scene_root != null, vm.anim.current_animation if vm.anim else "-"])
	get_tree().quit()
