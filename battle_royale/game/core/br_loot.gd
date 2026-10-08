class_name BRLoot
extends Node3D

const MOCHILA_CENA := preload("res://assets/models/props/tactical_backpack.glb")   # mochila no chão: antes load() a cada item
## Contentor físico de saque. Os itens são definidos em br_loot.json, sem sorteio.

var contents: BRInventory
var cache_id := ""
var _visual: Node3D
var aberto_sempre := true   # drops e saques soltos já vêm abertos (caixas/móveis sobrescrevem)


func _ready() -> void:
	add_to_group("loot")


func setup(id: String, entries: Array) -> void:
	cache_id = id
	contents = BRInventory.make_loot_container(4)
	for entry in entries:
		contents.add_item(String(entry[0]), int(entry[1]))
	contents.changed.connect(_refresh)
	_build_visual()


func _build_visual() -> void:
	var has_bag := false
	for item in contents.items:
		if String(BRInventory.definition(String(item.id)).get("kind", "")) == "backpack":
			has_bag = true
			break
	if has_bag and ResourceLoader.exists("res://assets/models/props/tactical_backpack.glb"):
		_visual = MOCHILA_CENA.instantiate()
	else:
		var crate := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.65, 0.35, 0.4)
		crate.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("746B4E")
		mat.roughness = 0.96
		crate.material_override = mat
		crate.position.y = 0.18
		_visual = crate
	add_child(_visual)
	for g in _visual.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(g as GeometryInstance3D).visibility_range_end = 42.0
	var tag := Label3D.new()
	tag.text = "MOCHILA  [E]" if has_bag else "SAQUE  [E]"
	tag.font_size = 32
	tag.pixel_size = 0.006
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = false
	tag.position.y = 0.9
	tag.visibility_range_end = 18.0
	add_child(tag)


func _refresh() -> void:
	if contents.items.is_empty() and is_inside_tree():
		queue_free()


func take_all(target: BRInventory) -> int:
	var taken := 0
	for item in contents.items.duplicate(true):
		taken += contents.transfer_to(target, int(item.uid))
	return taken
