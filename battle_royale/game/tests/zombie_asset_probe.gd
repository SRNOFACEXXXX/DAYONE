extends SceneTree

const SOURCES := [
	"res://assets/models/zombies/polyart_pack/zombie_ani_player.fbx",
	"res://assets/models/zombies/szombie_variant_1/SZombie_Variant_1/SK_SZombie_Variant_1.fbx",
	"res://assets/models/zombies/szombie_variant_1/scene.gltf",
	"res://assets/animations/zombie_mixamo_source/Zombie Idle.fbx",
	"res://assets/animations/zombie_mixamo_source/Zombie Walk.fbx",
	"res://assets/animations/zombie_mixamo_source/Zombie Running.fbx",
	"res://assets/animations/zombie_mixamo_source/Zombie Scream.fbx",
	"res://assets/animations/zombie_mixamo_source/Zombie Attack.fbx",
	"res://assets/animations/zombie_mixamo_source/Zombie Death.fbx",
	"res://assets/animations/scary_zombie_pack/zombie idle.fbx",
	"res://assets/animations/scary_zombie_pack/zombie walk.fbx",
	"res://assets/animations/scary_zombie_pack/zombie run.fbx",
	"res://assets/animations/scary_zombie_pack/zombie scream.fbx",
	"res://assets/animations/scary_zombie_pack/zombie attack.fbx",
	"res://assets/animations/scary_zombie_pack/zombie death.fbx",
	"res://assets/animations/scary_zombie_pack/zombie neck bite.fbx",
	"res://assets/animations/scary_zombie_pack/zombie crawl.fbx",
	"res://assets/animations/scary_zombie_pack/zombie biting.fbx",
	"res://assets/animations/scary_zombie_pack/zombie biting (2).fbx",
	"res://assets/animations/scary_zombie_pack/zombie dying.fbx",
	"res://assets/animations/scary_zombie_pack/running crawl.fbx",
]

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	for path in SOURCES:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Could not load packed scene: " + path)
			continue
		var root := packed.instantiate()
		print("ZOMBIE_PROBE source=", path, " root=", root.name)
		print("  ROOT transform=", root.transform)
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is Skeleton3D:
				var skeleton := node as Skeleton3D
				var names: PackedStringArray = []
				for bone_index in skeleton.get_bone_count():
					names.append(skeleton.get_bone_name(bone_index))
				print("  SKELETON path=", root.get_path_to(skeleton), " count=", names.size(), " bones=", ",".join(names))
			if node is AnimationPlayer:
				var player := node as AnimationPlayer
				print("  ANIMATIONS path=", root.get_path_to(player), " clips=", ",".join(PackedStringArray(player.get_animation_list())))
				for clip_name in player.get_animation_list():
					var clip := player.get_animation(clip_name)
					print("    CLIP name=", clip_name, " duration=", clip.length, " tracks=", clip.get_track_count())
					for track_index in mini(clip.get_track_count(), 8):
						print("      TRACK type=", clip.track_get_type(track_index), " path=", clip.track_get_path(track_index))
			if node is MeshInstance3D:
				var mesh_node := node as MeshInstance3D
				if mesh_node.mesh != null:
					print("  MESH path=", root.get_path_to(mesh_node), " aabb=", mesh_node.mesh.get_aabb(), " material=", mesh_node.get_active_material(0))
			for child in node.get_children():
				stack.append(child)
		root.free()
	quit()


