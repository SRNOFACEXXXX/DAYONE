extends Node
## Machado, picareta e martelo na mão (primeira pessoa): captura o golpe em quadros-chave (descanso, recuo, impacto, retorno) e
## a terceira pessoa. --out=<pasta>
var _out := ""


func _shot(nome: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(nome + ".png"))


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	_out = Game.test_args.get("out", OS.get_user_data_dir())
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_loot_root == null or m.br_bag == null:
		await get_tree().process_frame
	while Loading.visivel():
		await get_tree().process_frame
	for i in 120:
		await get_tree().physics_frame
	var p: Soldier = m.local_player
	p.godmode = true
	var pc := p.controller as PlayerController
	var fm = pc.get("ferramentas")
	for id in ["machado", "picareta", "martelo"]:
		m.br_bag.add_item(id, 1)
		var uid := -1
		for it in m.br_bag.items:
			if String(it.id) == id:
				uid = int(it.uid)
		if not fm.equipar(uid):
			print("VISTA falhou equipar ", id)
			continue
		fm.set_process(false)   # congela o golpe automático: a pose vem dos quadros-chave
		for k in [0.0, 0.2, 0.34, 0.48, 0.62, 0.85]:
			fm._pose(k)
			await _shot("%s_k%02d" % [id, int(k * 100)])
		fm._pose(0.0)
		fm.set_process(true)
		fm.desequipar()
	print("VISTA_FIM")
	get_tree().quit()
