extends Node
## Cosméticos corporais do jogador local (chapéu, fones, coroa, máscara de mergulho, chuteira, amuleto): itens da mochila com
## kind "cosmetico" e a marca `vestido`. O modelo fica preso ao osso do corpo (posição de mundo recalculada por quadro a
## partir do osso e da direção do soldado, sem depender dos eixos do osso) e some em 1ª pessoa. Alguns têm efeito de jogo:
## chuva (molha menos), folego (mais ar debaixo d'água) e queda (menos dano de queda). Sem class_name (preload em player_controller).
const CFG := {
	"chapeu": {"osso": "Head", "pos": Vector3(0.0, 0.2, 0.0), "rot": Vector3.ZERO, "esc": 1.0},
	"fones": {"osso": "Head", "pos": Vector3(0.0, 0.1, 0.0), "rot": Vector3.ZERO, "esc": 1.35},
	"coroa": {"osso": "Head", "pos": Vector3(0.0, 0.3, 0.0), "rot": Vector3.ZERO, "esc": 1.0},
	"mascara_mergulho": {"osso": "Head", "pos": Vector3(0.0, 0.05, -0.12), "rot": Vector3(0, 180, 0), "esc": 1.2},
	"chuteira": {"osso": ["LeftFoot", "RightFoot"], "pos": Vector3(0.0, -0.07, -0.07), "rot": Vector3(0, 180, 0), "esc": 1.3},
	"amuleto": {"osso": "Spine1", "pos": Vector3(0.0, 0.02, -0.15), "rot": Vector3(0, 180, 0), "esc": 1.0},
}

var pc: PlayerController
var m: Match
var _ativos := {}          # id -> Array[Node3D] (um por osso)
var _t := 0.0


func setup(p: PlayerController, mt: Match) -> void:
	pc = p
	m = mt


func _bag() -> BRInventory:
	return m.get("br_bag") as BRInventory if m != null else null


## Veste/tira o item `uid`. Um só por espaço (cabeca, orelhas, rosto, pes, peito): vestir outro do mesmo espaço tira o anterior.
func alternar(uid: int) -> String:
	var b := _bag()
	if b == null:
		return ""
	var it := b.get_item(uid)
	if it.is_empty():
		return ""
	var def := BRInventory.definition(String(it.id))
	if String(def.get("kind", "")) != "cosmetico":
		return ""
	var vestir := not bool(it.get("vestido", false))
	if vestir:
		var slot := String(def.get("slot", ""))
		for o in b.items:
			if bool(o.get("vestido", false)) and String(BRInventory.definition(String(o.id)).get("slot", "")) == slot:
				o["vestido"] = false
	for o in b.items:
		if int(o.uid) == uid:
			o["vestido"] = vestir
	b.changed.emit()
	_sincronizar()
	return ("%s vestido" if vestir else "%s guardado") % String(def.get("name", it.id))


## Multiplicador do efeito `chave` (produto dos itens vestidos que o têm; `padrao` se nenhum).
func efeito(chave: String, padrao := 1.0) -> float:
	var b := _bag()
	if b == null:
		return padrao
	var r := padrao
	for o in b.items:
		if bool(o.get("vestido", false)):
			var d := BRInventory.definition(String(o.id))
			if d.has(chave):
				r *= float(d[chave])
	return r


func vestidos() -> Array:
	var out: Array = []
	var b := _bag()
	if b != null:
		for o in b.items:
			if bool(o.get("vestido", false)):
				out.append(String(o.id))
	return out


func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = 0.4
		_sincronizar()
	var bm := pc.soldier.body_model as BodyModel if pc != null and pc.soldier != null else null
	if bm == null or bm.skeleton == null:
		return
	var vis := pc.soldier.alive and not bm.first_person
	var basis := Basis(Vector3.UP, pc.soldier.yaw)
	for id in _ativos:
		var cfg: Dictionary = CFG[id]
		var ossos: Array = cfg.osso if cfg.osso is Array else [cfg.osso]
		var nos: Array = _ativos[id]
		for i in nos.size():
			var n := nos[i] as Node3D
			var bi := bm.skeleton.find_bone(String(ossos[i]))
			n.visible = vis and bi >= 0
			if bi < 0:
				continue
			var p := bm.skeleton.global_transform * bm.skeleton.get_bone_global_pose(bi).origin
			var rot: Vector3 = cfg.rot
			var espelho := 1.0 if i == 0 else -1.0
			var off: Vector3 = cfg.pos
			off.x *= espelho
			n.global_transform = Transform3D(basis * Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), p + basis * off)
			n.scale = Vector3(espelho * float(cfg.esc), float(cfg.esc), float(cfg.esc)) if ossos.size() > 1 else Vector3.ONE * float(cfg.esc)


func _sincronizar() -> void:
	var queremos := vestidos()
	for id in _ativos.keys():
		if not queremos.has(id):
			for n in _ativos[id]:
				(n as Node).queue_free()
			_ativos.erase(id)
	for id in queremos:
		if _ativos.has(id) or not CFG.has(id):
			continue
		var path := String(BRInventory.definition(id).get("model_path", ""))
		if not ResourceLoader.exists(path):
			continue
		var cfg: Dictionary = CFG[id]
		var qtd: int = (cfg.osso as Array).size() if cfg.osso is Array else 1
		var lista: Array = []
		for i in qtd:
			var n: Node3D = (load(path) as PackedScene).instantiate()
			n.top_level = true
			for g in n.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pc.soldier.add_child(n)
			lista.append(n)
		_ativos[id] = lista
