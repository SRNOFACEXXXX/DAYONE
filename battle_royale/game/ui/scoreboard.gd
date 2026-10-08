class_name Scoreboard
extends Control
## Placar (Tab) conforme HUD_SPEC 4.14: 960 × 600, CT em cima, TR embaixo; dinheiro só do seu time,
## sua linha destacada, mortos esmaecidos com caveira, portador da bomba com C4 (só para TR).

const COLS := [["JOGADOR", 330], ["DINHEIRO", 110], ["ABATES", 80], ["ASSIST.", 80], ["MORTES", 80], ["PONTOS", 80], ["LATÊNCIA", 90], ["", 60]]
const DEAD := Color("7D7466")

var match_ref: Match
var box: VBoxContainer
var head_score: Label
var head_round: Label
var head_map: Label
var _acc := 0.0


func setup(m: Match) -> void:
	match_ref = m
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	var sb := UIStyle.panel_style(Color(0.047, 0.055, 0.063, 0.88), 8, 1)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -480
	p.offset_right = 480
	p.offset_top = -250
	p.offset_bottom = 250
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head_map = UIStyle.label("", 22, UIStyle.TEXT, 700, "title")
	head_map.custom_minimum_size.x = 300
	head.add_child(head_map)
	head_score = UIStyle.label("", 30, UIStyle.TEXT, 600, "num")
	head_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(head_score)
	head_round = UIStyle.label("", 16, UIStyle.TEXT_DIM, 600, "num")
	head_round.custom_minimum_size.x = 300
	head_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(head_round)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	v.add_child(box)


func _process(dt: float) -> void:
	if not visible:
		return
	_acc -= dt
	if _acc > 0.0 and box.get_child_count() > 0:
		return
	_acc = 0.25
	_rebuild()


func _rebuild() -> void:
	for c in box.get_children():
		c.queue_free()
	var map_node := match_ref.map as Node
	head_map.text = (str(map_node.get("map_title")) if map_node and map_node.get("map_title") else "PARTIDA").to_upper()
	head_score.text = "CT  %d  ×  %d  TR" % [match_ref.score[1], match_ref.score[0]]
	head_round.text = "RODADA %d · primeiro a %d" % [match_ref.round_number, int(Game.config.rounds_to_win)]
	var lp := match_ref.local_player
	for tm in [1, 0]:
		var sp := Control.new()
		sp.custom_minimum_size.y = 8
		box.add_child(sp)
		var title := HBoxContainer.new()
		var tl := UIStyle.label(Game.TEAM_NAMES[tm].to_upper(), 18, UIStyle.team_color(tm), 700, "title")
		tl.custom_minimum_size.x = COLS[0][1]
		title.add_child(tl)
		for i in range(1, COLS.size()):
			var hl := UIStyle.label(COLS[i][0], 12, UIStyle.TEXT_DIM, 600, "title")
			hl.custom_minimum_size.x = COLS[i][1]
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hl.size_flags_vertical = Control.SIZE_SHRINK_END
			title.add_child(hl)
		box.add_child(title)
		var bar := ColorRect.new()
		bar.color = Color(UIStyle.team_color(tm), 0.55)
		bar.custom_minimum_size.y = 2
		box.add_child(bar)
		var members := match_ref.team_members(tm)
		members.sort_custom(func(a, b): return _points(a) > _points(b))
		for s in members:
			box.add_child(_row(s, lp))


func _points(s: Soldier) -> int:
	return s.kills * 2 + s.assists


func _row(s: Soldier, lp: Soldier) -> Control:
	var pc := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UIStyle.ACCENT, 0.15) if s == lp else Color(1, 1, 1, 0.025)
	bg.content_margin_top = 3
	bg.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", bg)
	pc.custom_minimum_size.y = 30
	var h := HBoxContainer.new()
	pc.add_child(h)
	var col := UIStyle.TEXT if s.alive else DEAD
	var name_box := HBoxContainer.new()
	name_box.custom_minimum_size.x = COLS[0][1]
	name_box.add_theme_constant_override("separation", 6)
	h.add_child(name_box)
	var strip := ColorRect.new()
	strip.color = UIStyle.team_color(s.team) if s.alive else Color(DEAD, 0.6)
	strip.custom_minimum_size = Vector2(3, 22)
	name_box.add_child(strip)
	if not s.alive:
		name_box.add_child(UIStyle.Icon.new("skull", DEAD, 18))
	name_box.add_child(UIStyle.label(s.display_name, 17, col, 600, "title"))
	if s.is_carrying_bomb and lp and lp.team == 0 and s.team == 0:
		name_box.add_child(UIStyle.Icon.new("c4", UIStyle.BOMB, 20))
	if s.has_defuser and lp and lp.team == 1 and s.team == 1:
		name_box.add_child(UIStyle.Icon.new("kit", UIStyle.CT_COLOR, 18))
	var money := UIStyle.money(s.money) if (lp == null or s.team == lp.team) else ""
	var vals := [money, str(s.kills), str(s.assists), str(s.deaths), str(_points(s)), "BOT" if s.is_bot else "0"]
	for i in vals.size():
		var l := UIStyle.label(vals[i], 17, UIStyle.MONEY if i == 0 else col, 600, "num")
		l.custom_minimum_size.x = COLS[i + 1][1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(l)
	var stars := HBoxContainer.new()
	stars.custom_minimum_size.x = COLS[7][1]
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	if s.mvps > 0:
		stars.add_child(UIStyle.Icon.new("star", UIStyle.ACCENT, 16))
		stars.add_child(UIStyle.label(str(s.mvps), 15, UIStyle.ACCENT, 600, "num"))
	h.add_child(stars)
	return pc
