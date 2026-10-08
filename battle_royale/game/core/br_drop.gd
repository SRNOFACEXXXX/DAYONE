class_name BRDrop
extends BRLoot
## Item solto no chão (dropado pelo inventário ou spawnado pelo painel de administrador). Contém UM item (ou pilha).
## Aparece em PROXIMIDADE no inventário e some quando esvazia. O modelo vem do próprio item (arma/munição/mochila/granada).

const MODELOS := {
	"grenade": "res://assets/models/weapons/wf/rgd5.glb",
	"acog": "res://assets/models/weapons/wf/acog.glb",
	"reddot": "res://assets/models/weapons/wf/reddot.glb",
	"ammo_9mm": "res://assets/models/props/municao_9mm.glb",
	"ammo_762": "res://assets/models/props/municao_762.glb",
	"ammo_556": "res://assets/models/props/municao_556.glb",
	"backpack_small": "res://assets/models/props/tactical_backpack.glb",
	"backpack_medium": "res://assets/models/props/tactical_backpack.glb",
	"backpack_large": "res://assets/models/props/tactical_backpack.glb",
}
var nome := ""


## Cria o item no chão em `pos` (mundo). extra = {"mag": n, "acog": bool} para armas.
static func criar(pai: Node, id: String, qtd: int, pos: Vector3, extra := {}) -> BRDrop:
	var d := BRDrop.new()
	pai.add_child(d)
	d.global_position = pos
	d.contents = BRInventory.make_loot_container(4)
	d.contents.add_item(id, qtd, Vector2i(-1, -1), extra)
	d.cache_id = "drop_" + id
	d.nome = String(BRInventory.definition(id).get("name", id))
	d.contents.changed.connect(d._refresh)
	d._build_visual()
	return d


func _build_visual() -> void:
	var id := String(contents.items[0].id) if not contents.items.is_empty() else ""
	var def := BRInventory.definition(id)
	var kind := String(def.get("kind", ""))
	var path := String(MODELOS.get(id, ""))
	if path.is_empty() and kind == "weapon":
		var wd := WeaponDB.get_def(StringName(id))
		if wd:
			path = wd.model_path
	_visual = Node3D.new()
	add_child(_visual)
	if not path.is_empty() and ResourceLoader.exists(path):
		var sc: Node3D = load(path).instantiate()
		if kind == "ammo":
			sc.scale = Vector3.ONE * 3.0
		elif kind == "backpack":
			sc.scale = Vector3.ONE * 0.5
		elif kind == "weapon":
			sc.rotation.z = deg_to_rad(90.0) if false else 0.0
			sc.rotation_degrees = Vector3(0, 0, 0)
		_visual.add_child(sc)
		if kind == "weapon":
			OpticaAssento.sincronizar(sc, StringName(id), OpticaAssento.tipo_do_item(contents.items[0]))
	elif kind == "heal":
		_visual.add_child(modelo_cura(id))
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 0.12, 0.18)
		mi.mesh = bm
		_visual.add_child(mi)
	# armas ficam deitadas no chão (cano para o lado)
	if kind == "weapon":
		_visual.rotation_degrees = Vector3(0, 0, 90)
		_visual.position.y = 0.08
	else:
		_visual.position.y = 0.04
	for g in _visual.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(g as GeometryInstance3D).visibility_range_end = 70.0
	var tag := Label3D.new()
	tag.text = nome
	tag.font_size = 24
	tag.pixel_size = 0.0028
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 0.55
	tag.visibility_range_end = 6.0
	add_child(tag)


## Modelo lowpoly das curas (sem .glb): bandagem = rolo branco com faixa vermelha; kit = maleta branca com cruz vermelha.
static func modelo_cura(id: String) -> Node3D:
	var raiz := Node3D.new()
	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color("ecebe6")
	branco.roughness = 0.9
	var vermelho := StandardMaterial3D.new()
	vermelho.albedo_color = Color("d9372b")
	vermelho.roughness = 0.8
	if id == "kit_medico":
		var corpo := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.13, 0.2)
		corpo.mesh = bm
		corpo.material_override = branco
		corpo.position.y = 0.065
		raiz.add_child(corpo)
		for dim in [Vector3(0.14, 0.01, 0.04), Vector3(0.04, 0.01, 0.14)]:
			var cruz := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = dim
			cruz.mesh = cm
			cruz.material_override = vermelho
			cruz.position.y = 0.135
			raiz.add_child(cruz)
	else:
		var rolo := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.06
		cm2.bottom_radius = 0.06
		cm2.height = 0.05
		cm2.radial_segments = 10
		rolo.mesh = cm2
		rolo.material_override = branco
		rolo.position.y = 0.025
		raiz.add_child(rolo)
		var faixa := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.0615
		fm.bottom_radius = 0.0615
		fm.height = 0.014
		fm.radial_segments = 10
		faixa.mesh = fm
		faixa.material_override = vermelho
		faixa.position.y = 0.025
		raiz.add_child(faixa)
	return raiz


func _refresh() -> void:
	super._refresh()
	if contents.items.is_empty() or _visual == null or _visual.get_child_count() == 0:
		return
	var it: Dictionary = contents.items[0]
	var sc := _visual.get_child(0) as Node3D
	if String(BRInventory.definition(String(it.id)).get("kind", "")) == "weapon" and sc:
		OpticaAssento.sincronizar(sc, StringName(String(it.id)), OpticaAssento.tipo_do_item(it))
