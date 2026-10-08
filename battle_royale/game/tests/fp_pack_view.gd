extends Node3D
## Vê um pack FPS (braços+arma+animações) pela câmera do próprio pack (osso FPS_Camera* ou câmera do glb), sem o jogo.
## -- --pack=res://assets/models/fp/g17_pack.fbx --tag=g17
const OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/fp_packs"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var path: String = Game.test_args.get("pack", "res://assets/models/fp/g17_pack.fbx")
	var tag: String = Game.test_args.get("tag", "x")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.66)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sol)
	var cena: Node3D = load(path).instantiate()
	add_child(cena)
	var sk := cena.find_children("*", "Skeleton3D", true, false)
	var ap := cena.find_children("*", "AnimationPlayer", true, false)
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.01
	add_child(cam)
	var skel: Skeleton3D = sk[0] if sk.size() > 0 else null
	var cb := -1
	if skel:
		for i in skel.get_bone_count():
			if "camera" in skel.get_bone_name(i).to_lower():
				cb = i
	print("PACK ", path, " anims=", (ap[0] as AnimationPlayer).get_animation_list() if ap.size() > 0 else [], " cam_bone=", skel.get_bone_name(cb) if cb >= 0 else "-")
	var player: AnimationPlayer = ap[0] if ap.size() > 0 else null
	for anim in (player.get_animation_list() if player else []):
		var a := player.get_animation(anim)
		for k in 4:
			var t := a.length * (k + 0.5) / 4.0
			player.play(anim)
			player.seek(t, true)
			await get_tree().process_frame
			if Game.test_args.has("fixo"):
				var aabb := AABB()
				var first := true
				for mi in cena.find_children("*", "MeshInstance3D", true, false):
					var b2: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
					aabb = b2 if first else aabb.merge(b2)
					first = false
				var ctr := aabb.get_center()
				cam.global_position = ctr + Vector3(1, 0.6, 1).normalized() * aabb.size.length() * 1.1
				cam.look_at(ctr)
			elif cb >= 0:
				var g := skel.global_transform * skel.get_bone_global_pose(cb)
				cam.global_transform = Transform3D(g.basis.orthonormalized(), g.origin) * Transform3D(Basis.from_euler(Vector3(float(Game.test_args.get("rx", "0")), float(Game.test_args.get("ry", "0")), 0) * PI / 180.0), Vector3.ZERO)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUT.path_join("%s_%s_%d.png" % [tag, String(anim).replace("|", "_").replace("/", "_"), k]))
	get_tree().quit()
