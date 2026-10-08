extends Node
## Óptica no modelo de mundo: 3ª pessoa do jogador local, bot e arma solta no chão (OpticaAssento).
## Uso: godot --path game res://tests/mira_mundo_check.tscn -- --out=<pasta> --bots=1
## Mede a folga base->superfície (cm, escala da arma) e a presença do nó; escreve o JSON dos casos.

var out := ""
var casos := []
var falhou := false
var cam: Camera3D


func _ready() -> void:
	Game.test_mode = true
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.02
	add_child(cam)
	cam.make_current()
	var s: Soldier = m.local_player
	var bm := s.body_model as BodyModel
	bm.set_first_person(false)
	await _frames(10)
	# --- jogador local: M4 + holográfica e AK + ACOG pelo inventário real
	for par in [["m4", "reddot"], ["ak47", "acog"]]:
		var uid := _dar(m, par[0], par[1])
		m._equip_br_weapon(uid)
		await _frames(30)
		await _caso("3a_pessoa", s, par[0], par[1], "jogador_%s" % par[0])
	# retirada: a óptica some do modelo de 3ª pessoa
	var uid_ak := int(m.local_player.current().br_uid)
	assert(m.br_bag.retirar_mira(uid_ak) == "acog", "retirar_mira devolve a ACOG")
	await _frames(40)
	var wn := bm.weapon_node
	var sumiu := wn.get_node_or_null(OpticaAssento.NOME) == null
	print("MIRA_MUNDO retirada sumiu=", sumiu)
	if not sumiu:
		falhou = true
	# --- bot
	var bot: Soldier = null
	for b: Soldier in m.soldiers:
		if b != s:
			bot = b
			break
	if bot:
		(bot.controller as Node).set_process(false)
		(bot.controller as Node).set_physics_process(false)
		bot.global_position = s.global_position + Vector3(4, 0, 0)
		var bbm := bot.body_model as BodyModel
		bbm.set_first_person(false)
		for par in [["ak47", "acog"], ["m4", "reddot"]]:
			bot.ready_at = 0.0
			bot.active_slot = -1
			bot.give_weapon(StringName(par[0]))
			await _frames(4)
			bbm.set_mira(par[1])
			await _frames(20)
			await _caso("bot", bot, par[0], par[1], "bot_%s" % par[0])
	else:
		print("MIRA_MUNDO sem bot")
	# --- chão
	var base := s.global_position
	for par in [["m4", "reddot"], ["ak47", "acog"]]:
		var d: BRDrop = m.criar_drop(par[0], 1, Vector3(base.x + 10.0, base.y, base.z + 10.0 + (0.0 if par[0] == "m4" else 3.0)), {"mag": 10, par[1]: true})
		await _frames(10)
		var sc := d._visual.get_child(0) as Node3D
		var o := sc.get_node_or_null(OpticaAssento.NOME) as Node3D
		var f := OpticaAssento.folga_cm(sc, o) if o else 99.0
		var p := d.global_position
		cam.global_position = p + Vector3(-0.7, 0.35, 0.6)
		cam.look_at(p + Vector3(-0.05, 0.1, 0.0), Vector3.UP)
		await _frames(6)
		var cap := await _foto("chao_%s" % par[0])
		_registrar("chao", par[0], par[1], o != null and o.is_inside_tree(), f, cap)
	var json := JSON.stringify({"casos": casos, "pendente": []}, "  ")
	var f := FileAccess.open(out.path_join("resultado_mira_mundo.json"), FileAccess.WRITE)
	f.store_string(json)
	f.close()
	print("MIRA_MUNDO_JSON ", json)
	print("MIRA_MUNDO_", "FALHOU" if falhou else "OK")
	get_tree().quit(1 if falhou else 0)


func _dar(m: BRMatch, id: String, mira: String) -> int:
	if not m.br_bag.items.any(func(it) -> bool: return String(it.id).begins_with("backpack")):
		m.br_bag.add_item("backpack_medium")   # a capacidade inicial mudou: sem mochila a arma não cabe
	m.br_bag.add_item(id, 1, Vector2i(-1, -1), {"mag": 10, mira: true})
	var uid := -1
	for it in m.br_bag.items:
		if String(it.id) == id and bool(it.get(mira, false)):
			uid = int(it.uid)
	assert(uid >= 0, "arma com mira na mochila: " + id)
	return uid


func _caso(onde: String, s: Soldier, arma: String, mira: String, nome: String) -> void:
	var bm := s.body_model as BodyModel
	var wn := bm.weapon_node
	var o: Node3D = wn.get_node_or_null(OpticaAssento.NOME) as Node3D if wn else null
	var f := OpticaAssento.folga_cm(wn, o) if o else 99.0
	var p := wn.global_position
	var b := wn.global_transform.basis
	cam.global_position = p + b.x.normalized() * 0.55 + Vector3(0, 0.25, 0)
	cam.look_at(p + Vector3(0, 0.06, 0), Vector3.UP)
	await _frames(6)
	var cap := await _foto(nome)
	_registrar(onde, arma, mira, o != null and o.is_inside_tree() and String(bm.weapon_id) == arma, f, cap)


func _registrar(onde: String, arma: String, mira: String, presente: bool, folga: float, cap: String) -> void:
	var ok := presente and folga <= 0.5
	if not ok:
		falhou = true
	print("MIRA_MUNDO %s %s %s presente=%s folga=%.3f cm %s" % [onde, arma, mira, presente, folga, "ok" if ok else "FALHA"])
	casos.append({"onde": onde, "arma": arma, "mira": mira, "presente": presente, "folga_cm": snappedf(folga, 0.001), "captura": cap})


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		if cam:
			cam.make_current()
			var pc := (get_tree().get_first_node_in_group("__none"))
			for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = false


func _foto(nome: String) -> String:
	await RenderingServer.frame_post_draw
	var p := out.path_join("mira_mundo_%s.png" % nome)
	get_viewport().get_texture().get_image().save_png(p)
	return p
