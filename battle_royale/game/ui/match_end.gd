class_name MatchEndScreen
extends Control
## Final result: winner, score, best players, replay/menu buttons.

var match_ref: Match


func setup(m: Match) -> void:
	match_ref = m
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.offset_left = -360
	v.offset_right = 360
	v.offset_top = -260
	v.offset_bottom = 260
	var lp := m.local_player
	var won := lp != null and lp.team == m.match_winner
	var t1 := UIStyle.label("VITÓRIA" if won else ("DERROTA" if lp else "FIM DE PARTIDA"), 64, UIStyle.GOOD if won else UIStyle.DANGER, 800)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var t2 := UIStyle.label("%s venceram  ·  %d × %d" % [Game.TEAM_NAMES[m.match_winner], m.score[m.match_winner], m.score[1 - m.match_winner]], 24, UIStyle.team_color(m.match_winner), 700)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	var best: Soldier = null
	for s in m.soldiers:
		if best == null or s.kills > best.kills:
			best = s
	if best:
		var t3 := UIStyle.label("Melhor jogador: %s — %d abates, %d MVPs" % [best.display_name, best.kills, best.mvps], 20, UIStyle.TEXT, 500)
		t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t3)
	if lp:
		var t4 := UIStyle.label("Você: %d abates · %d assistências · %d mortes · %d MVPs" % [lp.kills, lp.assists, lp.deaths, lp.mvps], 18, UIStyle.TEXT_DIM, 500)
		t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t4)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var again := UIStyle.button("Jogar de novo", 22, true)
	again.pressed.connect(Game.start_match)
	h.add_child(again)
	var menu := UIStyle.button("Menu principal", 22)
	menu.pressed.connect(Game.back_to_menu)
	h.add_child(menu)
	if not Game.test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if lp and lp.controller:
		lp.controller.ui_blocking = true
