extends Node3D
## OBJETIVO FINAL: consertar o barco do Pescador (o MARÉ MANSA, encalhado na praia sul) e sair da ilha.
## E perto do barco entrega as peças que estiverem na mochila; quando todas chegam, tela de fuga com os dias
## sobrevividos e volta ao menu. Peças: galão (combustível), bateria, kit de reparo (casco/motor), corda, toras (remendo).
## Lore: data/lore/barco.json. Sem class_name (preload em maps/ilha/ilha.gd).

const PECAS := {"galao": 2, "bateria_carro": 1, "kit_reparo": 2, "corda": 2, "tora": 4}
const ALCANCE := 5.0
var entregues := {}
var _rotulo: Label3D
var _fugiu := false


func _ready() -> void:
	add_to_group("barco_fuga")
	for k in PECAS:
		entregues[k] = 0
	_rotulo = Label3D.new()
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.font_size = 30
	_rotulo.pixel_size = 0.0035
	_rotulo.outline_size = 10
	_rotulo.modulate = Color(1, 0.93, 0.75)
	_rotulo.position = Vector3(0, 3.2, 0)
	_rotulo.visible = false
	add_child(_rotulo)


func faltando() -> Dictionary:
	var f := {}
	for k in PECAS:
		if int(entregues[k]) < int(PECAS[k]):
			f[k] = int(PECAS[k]) - int(entregues[k])
	return f


func _texto() -> String:
	var linhas: PackedStringArray = ["MARÉ MANSA — consertar para fugir"]
	for k in PECAS:
		var nome := String(BRInventory.definition(k).get("name", k))
		linhas.append("%s  %d/%d" % [nome, int(entregues[k]), int(PECAS[k])])
	linhas.append("[E] entregar peças da mochila")
	return "\n".join(linhas)


func _process(_dt: float) -> void:
	if _fugiu:
		return
	var m = Game.current_match
	if m == null or not is_instance_valid(m) or not "local_player" in m or not is_instance_valid(m.local_player):
		return
	var p: Soldier = m.local_player
	var perto := p.alive and p.global_position.distance_to(global_position) < ALCANCE
	_rotulo.visible = perto
	if not perto:
		return
	_rotulo.text = _texto()
	if Input.is_action_just_pressed("use") and m.br_bag:
		entregar(m.br_bag)


## Tira da mochila o que falta (até o necessário). Devolve quantas unidades entraram.
func entregar(bag: BRInventory) -> int:
	var n := 0
	for k in faltando():
		var precisa: int = faltando().get(k, 0)
		for it in bag.items.duplicate(true):
			if precisa <= 0:
				break
			if String(it.id) != String(k):
				continue
			var tira := mini(precisa, int(it.qty))
			bag.remove_item(int(it.uid), tira)
			entregues[k] = int(entregues[k]) + tira
			precisa -= tira
			n += tira
	if n > 0 and Audio.has_sound("loot_open"):
		Audio.play("loot_open", {"volume_db": -4.0})
	if faltando().is_empty():
		fugir()
	return n


func fugir() -> void:
	if _fugiu:
		return
	_fugiu = true
	var dias := int(Clima.dia) if "dia" in Clima else 1
	var tela := CanvasLayer.new()
	tela.layer = 50
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.05, 0.0)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela.add_child(fundo)
	var txt := Label.new()
	txt.set_anchors_preset(Control.PRESET_FULL_RECT)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.add_theme_font_size_override("font_size", 30)
	txt.modulate.a = 0.0
	txt.text = "O MARÉ MANSA ganhou o mar.\n\nVocê sobreviveu %d dia%s na Ilha do Tauá.\n\nNo rádio, as coordenadas do navio-hospital se repetem.\n\"Day one... is only the beginning.\"" % [dias, "" if dias == 1 else "s"]
	tela.add_child(txt)
	get_tree().root.add_child(tela)
	var tw := tela.create_tween()
	tw.tween_property(fundo, "color:a", 0.92, 2.0)
	tw.tween_property(txt, "modulate:a", 1.0, 1.5)
	tw.tween_interval(7.0)
	tw.tween_callback(func():
		tela.queue_free()
		if not Game.test_mode:
			Game.back_to_menu())
	print("FUGA dias=%d" % dias)
