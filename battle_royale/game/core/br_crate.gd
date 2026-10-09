class_name BRCrate
extends BRLoot
## Caixa militar de suprimentos. Fechada até o jogador apertar E: a tampa gira, uma explosão neon sai de dentro e os
## itens (no máximo 2, sorteados pelo nível da caixa) aparecem dentro. Só então dá para recolher ([E]) ou abrir o inventário ([I]).

const SORTEIO := {
	"alto": {"armas": [&"ak47", &"mosin", &"m4", &"m249", &"m107", &"uzi"], "extra": ["grenade", "ammo", "acog", "reddot", "backpack_medium", "kit_medico", "bandagem"]},
	"medio": {"armas": [&"ak47", &"m4", &"glock", &"usp", &"mosin", &"uzi"], "extra": ["grenade", "ammo", "reddot", "backpack_small", "bandagem", "bandagem", "comida"]},
	"baixo": {"armas": [&"glock", &"usp"], "extra": ["grenade", "ammo", "ammo", "bandagem", "comida"]},
}
const MUNICAO := {"762": ["ammo_762", 30], "556": ["ammo_556", 30], "9mm": ["ammo_9mm", 36], "127": ["ammo_127", 10]}
# caixa de armamento do pacote do usuário (Assets/caixa de armamentos): corpo e tampa separados
const CORPO := "res://assets/models/cenario/caixas/caixa_3_corpo.glb"
const TAMPA := "res://assets/models/cenario/caixas/caixa_3_tampa.glb"
const CORPO_CENA := preload("res://assets/models/cenario/caixas/caixa_3_corpo.glb")   # caixa: antes load() a cada construção
const TAMPA_CENA := preload("res://assets/models/cenario/caixas/caixa_3_tampa.glb")
const MODELOS_ITEM := {
	"vest": "res://assets/models/props/colete_placas.glb",
	"grenade": "res://assets/models/weapons/wf/rgd5.glb",
	"acog": "res://assets/models/weapons/wf/acog.glb",
	"reddot": "res://assets/models/weapons/wf/reddot.glb",
	"ammo_9mm": "res://assets/models/props/municao_9mm.glb",
	"ammo_762": "res://assets/models/props/municao_762.glb",
	"ammo_556": "res://assets/models/props/municao_556.glb",
	"backpack_small": "res://assets/models/props/tactical_backpack.glb",
	"backpack_medium": "res://assets/models/props/tactical_backpack.glb",
}

var aberta := false
var tier := "medio"
var _tampa: Node3D
var _vis: Node3D
var _luz: OmniLight3D


func setup_crate(id: String, nivel: String) -> void:
	cache_id = id
	tier = nivel if SORTEIO.has(nivel) else "medio"
	contents = BRInventory.make_loot_container(4)
	_sortear()
	contents.changed.connect(_refresh)
	_build_visual()


## Até 2 itens: uma arma (já com o carregador) e/ou um extra. Sorteio em tempo de jogo, tabela por nível.
func _sortear() -> void:
	var tab: Dictionary = SORTEIO[tier]
	var armas: Array = tab.armas
	var arma: StringName = armas[randi() % armas.size()]
	var def := BRInventory.definition(String(arma))
	var tem_arma := randf() < 0.85
	var extras: Array = tab.extra
	var extra: String = extras[randi() % extras.size()]
	if tem_arma:
		contents.add_item(String(arma), 1, Vector2i(-1, -1), {"mag": int(def.mag_size)})
	if extra == "ammo":
		var m: Array = MUNICAO[String(def.caliber)]
		contents.add_item(String(m[0]), int(m[1]))
	elif extra == "grenade":
		contents.add_item("grenade", 1 + randi() % 2)
	elif extra == "comida":   # ração de campo: algo de comer e de beber
		contents.add_item(["lata_comida", "feijao_lata", "barra_cereal"][randi() % 3], 1 + randi() % 2)
		contents.add_item(["garrafa_agua", "cantil"][randi() % 2], 1)
	elif extra == "bandagem":
		contents.add_item("bandagem", 1 + randi() % 3)
	elif extra == "kit_medico":
		if randf() < 0.5:   # kit é raro mesmo na caixa de nível alto
			contents.add_item("kit_medico", 1)
		else:
			contents.add_item("bandagem", 2)
	elif not tem_arma or randf() < 0.6:
		contents.add_item(extra, 1)


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var corpo: Node3D = CORPO_CENA.instantiate()
	_visual.add_child(corpo)
	# dobradiça na aresta de trás (-Z) do topo do corpo; medidas tiradas das próprias malhas
	var cb := _aabb(corpo)
	var tampa: Node3D = TAMPA_CENA.instantiate()
	var tb := _aabb(tampa)
	_tampa = Node3D.new()
	_tampa.position = Vector3(cb.get_center().x, cb.end.y, cb.position.z)
	_visual.add_child(_tampa)
	_tampa.add_child(tampa)
	tampa.position = Vector3(-tb.get_center().x, -tb.position.y, -tb.position.z)
	_vis = Node3D.new()
	_visual.add_child(_vis)
	for g in _visual.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 60.0
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = "CAIXA  [E] abrir"
	tag.font_size = 32
	tag.pixel_size = 0.006
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 1.0
	tag.visibility_range_end = 14.0
	add_child(tag)


static func _aabb(n: Node3D) -> AABB:
	var r := AABB()
	var primeiro := true
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		var b := mi.transform * mi.get_aabb()
		r = b if primeiro else r.merge(b)
		primeiro = false
	return r


## Abre a caixa: tampa gira, explosão neon, itens aparecem dentro.
func abrir() -> void:
	if aberta:
		return
	aberta = true
	var tag := get_node_or_null("Tag") as Label3D
	if tag:
		tag.text = "SAQUE  [E]"
	var tw := create_tween()
	tw.tween_property(_tampa, "rotation:x", deg_to_rad(-115.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_explosao_neon()
	get_tree().create_timer(0.35).timeout.connect(_mostrar_itens)
	Audio.play_at("buy", global_position, {"volume_db": -2.0, "max_distance": 25.0})


func _explosao_neon() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 40
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 65.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	p.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(0.3, 0.95, 1.0)
	p.material_override = mt
	p.position.y = 0.4
	add_child(p)
	# a luz só existe durante a explosão (centenas de caixas com OmniLight parada custavam vários ms na GT 730)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(0.25, 0.85, 1.0)
	_luz.omni_range = 4.0
	_luz.position.y = 0.6
	_luz.light_energy = 6.0
	add_child(_luz)
	var tw := create_tween()
	tw.tween_property(_luz, "light_energy", 0.0, 0.8)
	tw.tween_callback(_luz.queue_free)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Os itens não ficam mais visíveis dentro da caixa (atravessavam as paredes dela): o conteúdo aparece no inventário (PROXIMIDADE).
func _mostrar_itens() -> void:
	for c in _vis.get_children():
		c.queue_free()


func _modelo_item(id: String) -> Node3D:
	var def := BRInventory.definition(id)
	var kind := String(def.get("kind", ""))
	var raiz := Node3D.new()
	var path := String(MODELOS_ITEM.get(id, ""))
	if path.is_empty() and kind == "weapon" and WeaponDB.get_def(StringName(id)):
		path = WeaponDB.get_def(StringName(id)).model_path
	if not path.is_empty() and ResourceLoader.exists(path):
		var sc: Node3D = load(path).instantiate()
		if kind == "backpack":
			sc.scale = Vector3.ONE * 0.4
		elif kind == "ammo":
			sc.scale = Vector3.ONE * 3.0     # bandeja de cartuchos reais (7 cm) ampliada para ler dentro da caixa
		raiz.add_child(sc)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.1, 0.12)
		mi.mesh = bm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.72, 0.6, 0.2) if kind == "ammo" else Color(0.4, 0.45, 0.5)
		mi.material_override = mt
		raiz.add_child(mi)
	for g in raiz.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(g as GeometryInstance3D).visibility_range_end = 40.0
	return raiz


func _refresh() -> void:
	if aberta and is_inside_tree():
		_mostrar_itens()
		if contents.items.is_empty():
			var tag := get_node_or_null("Tag") as Label3D
			if tag:
				tag.text = "vazia"
