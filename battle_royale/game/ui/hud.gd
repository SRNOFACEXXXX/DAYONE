extends CanvasLayer
## HUD da partida conforme docs/design/HUD_SPEC.md (base lógica 1280 x 720).

class Quickbar extends Control:
	var soldier: Soldier
	var match_ref: Match
	var font: Font = ThemeDB.fallback_font

	func _init() -> void:
		font = UIStyle.font(600, "num")
		ItemIcons.request()

	## 5 slots de acesso rápido (teclas 1–5): itens arrastados no inventário; o da arma na mão fica em destaque.
	func _draw() -> void:
		if soldier == null:
			return
		var br := match_ref as BRMatch
		if br == null or br.br_bag == null:
			return
		const SLOTS := 5
		var gap := 6.0
		var side := minf(58.0, (size.x - gap * (SLOTS - 1)) / float(SLOTS))
		var x0 := (size.x - (side * SLOTS + gap * (SLOTS - 1))) * 0.5
		var y0 := size.y - side
		for i in SLOTS:
			var rect := Rect2(x0 + i * (side + gap), y0, side, side)
			var it: Dictionary = br.br_bag.quick_item(i)
			var ativo := false
			var qty := ""
			if not it.is_empty():
				var def := BRInventory.definition(String(it.id))
				if String(def.get("kind", "")) == "weapon":
					qty = str(int(it.mag))
					for cand: WeaponState in soldier.inventory.values():
						if cand.br_uid == int(it.uid):
							ativo = soldier.active_slot == cand.def.slot
							break
				elif int(it.qty) > 1:
					qty = str(int(it.qty))
			YUI.draw_slot(self, font, rect, str(i + 1), "" if it.is_empty() else String(it.id), qty, ativo, it.is_empty())

## Fôlego de corrida: fio fino no centro-baixo, logo acima da barra de acesso rápido. Só aparece quando falta fôlego
## (ou quando está cansado); some devagar ao encher. Cansado: vermelho pulsando. Desligado em Ajustes, some.
class FolegoBar extends Control:
	var soldier: Soldier
	var _vis := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func _process(dt: float) -> void:
		var mostrar := soldier != null and soldier.alive and Settings.stamina_ativa and (soldier.stamina < 0.999 or soldier.stamina_cansado())
		_vis = move_toward(_vis, 1.0 if mostrar else 0.0, dt * 3.0)
		modulate.a = _vis
		if _vis > 0.0:
			queue_redraw()

	func _draw() -> void:
		if soldier == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		var f := clampf(soldier.stamina, 0.0, 1.0)
		var cansado := soldier.stamina_cansado()
		draw_rect(r, Color(0, 0, 0, 0.5), true)
		var cor := UIStyle.DANGER if cansado else UIStyle.ACCENT
		if cansado:
			cor = cor.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)))
		draw_rect(Rect2(0, 0, r.size.x * f, r.size.y), cor, true)
		# marca de 20%: abaixo dela, quem ficou sem fôlego ainda não volta a correr
		draw_rect(Rect2(r.size.x * Soldier.STAMINA_RETORNO, 0, 1, r.size.y), Color(1, 1, 1, 0.35), true)


## Painel do carro (só ao dirigir): km/h, marcha, RPM, vida e combustível (só se usar_combustivel). Discreto.
class VeiculoHud extends Control:
	var carro: DrivableVehicle
	var _vis := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func _process(dt: float) -> void:
		var mostrar := carro != null and is_instance_valid(carro) and carro.driver != null
		_vis = move_toward(_vis, 1.0 if mostrar else 0.0, dt * 4.0)
		modulate.a = _vis
		if _vis > 0.0:
			queue_redraw()

	func _draw() -> void:
		if carro == null or not is_instance_valid(carro):
			return
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UIStyle.BG, true)
		draw_rect(r, UIStyle.PANEL_LINE, false, 1.0)
		var num := UIStyle.font(600, "num")
		var txt := UIStyle.font(400, "text")
		draw_string(num, Vector2(14, 42), str(carro.speed_kmh()), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UIStyle.TEXT)
		draw_string(txt, Vector2(14, 56), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.TEXT_DIM)
		draw_string(num, Vector2(size.x - 90, 42), "M%d" % carro.marcha_atual(), HORIZONTAL_ALIGNMENT_RIGHT, 76, 22, UIStyle.TEXT)
		var rot: float = carro.rpm_frac()
		_barra(66, "RPM", rot, UIStyle.DANGER if rot > 0.85 else UIStyle.ACCENT)
		_barra(82, "VIDA", carro.vida_frac(), UIStyle.DANGER.lerp(UIStyle.GOOD, carro.vida_frac()))
		if carro.usar_combustivel:
			_barra(98, "COMB", carro.combustivel_frac(), UIStyle.MONEY)

	func _barra(y: float, rotulo: String, frac: float, cor: Color) -> void:
		var txt := UIStyle.font(400, "text")
		draw_string(txt, Vector2(14, y + 6), rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.TEXT_DIM)
		var x0 := 60.0
		var w := size.x - x0 - 14.0
		draw_rect(Rect2(x0, y, w, 6), UIStyle.PANEL_LINE, true)
		draw_rect(Rect2(x0, y, w * clampf(frac, 0.0, 1.0), 6), cor, true)


var match_ref: Match
var root: Control
var crosshair: Crosshair
# vitais
var lbl_health: Label
var lbl_armor: Label
var bar_health: ColorRect
var bar_health_ghost: ColorRect
var bar_armor: ColorRect
var icon_cross: UIStyle.Icon
var icon_shield: UIStyle.Icon
var status_box: HBoxContainer
# munição
var lbl_weapon: Label
var lbl_mag: Label
var lbl_reserve: Label
var reload_line: ColorRect
var lbl_reload_hint: Label
var weapon_list: VBoxContainer
var _weapon_list_t := 0.0
var quickbar: Quickbar
var folego: FolegoBar
var veiculo_hud: VeiculoHud
# dinheiro
var lbl_money: Label
var lbl_money_delta: Label
var buy_hint: HBoxContainer
var _money_prev := -1
# topo
var lbl_score_t: Label
var lbl_score_ct: Label
var lbl_timer: Label
var lbl_round: Label
var alive_t: HBoxContainer
var alive_ct: HBoxContainer
var timer_icon: UIStyle.Icon
var _timer_pulse := 0.0
# feed, avisos, banners
var feed_box: VBoxContainer
var announce: Label
var _announce_t := 0.0
var banner: PanelContainer
var banner_stripe: ColorRect
var banner_title: Label
var banner_reason: Label
var banner_mvp: Label
var _banner_t := 0.0
var progress_panel: VBoxContainer
var progress_label: Label
var progress_fill: ColorRect
var spectate_bar: PanelContainer
var spectate_label: Label
var fps_label: Label
var vignette: Control
var dmg_arrows: Control
var radar: Radar
var rp: PanelContainer
var top_box: VBoxContainer
var plates_bar: Control
var vit: Control
var vital_bar: VitalBar
var lbl_callout: Label
var _callout_prev := ""
var buy_menu: Control
var scoreboard: Control
var pause_menu: Control
var match_end: Control
var _hit_dirs: Array = []
var _pulse := 0.0
var _vignette_hurt := 0.0
var _health_prev := 100
var _shake_t := 0.0


func setup(m: Match) -> void:
	match_ref = m
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	m.killfeed.connect(_on_killfeed)
	m.round_ended.connect(_on_round_ended)
	m.bomb_event.connect(_on_bomb_event)
	m.hud_message.connect(show_message)
	m.phase_changed.connect(_on_phase)
	m.damage_dealt.connect(_on_damage_dealt)
	if m.local_player:
		var lp := m.local_player
		lp.damaged.connect(_on_local_damaged)
		lp.plant_progress.connect(func(p: float) -> void: _set_progress(p, "PLANTANDO A BOMBA — 3,2 s", UIStyle.BOMB))
		lp.defuse_progress.connect(func(p: float) -> void:
			_set_progress(p, "DESARMANDO (KIT) — 5,0 s" if lp.has_defuser else "DESARMANDO — 10,0 s", UIStyle.CT_COLOR))
		lp.weapon_switched.connect(func(_d: WeaponDef) -> void: _weapon_list_t = 1.5)


func _place(c: Control, preset: int, l: float, t: float, r: float, b: float) -> void:
	root.add_child(c)
	c.set_anchors_and_offsets_preset(preset)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _build() -> void:
	vignette = Control.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.draw.connect(_draw_vignette)
	_place(vignette, Control.PRESET_FULL_RECT, 0, 0, 0, 0)
	crosshair = Crosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(crosshair, Control.PRESET_FULL_RECT, 0, 0, 0, 0)
	dmg_arrows = Control.new()
	dmg_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg_arrows.draw.connect(_draw_damage_arcs)
	_place(dmg_arrows, Control.PRESET_FULL_RECT, 0, 0, 0, 0)

	# ---- radar + área + dinheiro (topo-esquerda)
	rp = PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.BG, 6))
	_place(rp, Control.PRESET_TOP_LEFT, 14, 14, 214, 214)
	radar = Radar.new()
	radar.custom_minimum_size = Vector2(186, 186)
	rp.add_child(radar)
	radar.setup(match_ref)
	lbl_callout = UIStyle.label("", 15, UIStyle.TEXT, 400, "text")
	_place(lbl_callout, Control.PRESET_TOP_LEFT, 16, 218, 300, 240)
	lbl_money = UIStyle.label("$ 800", 26, UIStyle.MONEY, 600, "num")
	_place(lbl_money, Control.PRESET_TOP_LEFT, 16, 240, 200, 272)
	lbl_money_delta = UIStyle.label("", 20, UIStyle.GOOD, 600, "num")
	_place(lbl_money_delta, Control.PRESET_TOP_LEFT, 130, 244, 300, 270)
	buy_hint = HBoxContainer.new()
	buy_hint.add_theme_constant_override("separation", 6)
	buy_hint.add_child(UIStyle.Icon.new("cart", UIStyle.TEXT_DIM, 18))
	buy_hint.add_child(UIStyle.label("B — comprar", 14, UIStyle.TEXT_DIM, 400, "text"))
	_place(buy_hint, Control.PRESET_TOP_LEFT, 16, 274, 220, 296)

	# ---- vitais (base-esquerda)
	status_box = HBoxContainer.new()
	status_box.add_theme_constant_override("separation", 8)
	_place(status_box, Control.PRESET_BOTTOM_LEFT, 22, -108, 260, -84)
	vit = UIStyle.panel()
	_place(vit, Control.PRESET_BOTTOM_LEFT, 16, -78, 430, -16)
	var vh := HBoxContainer.new()
	vh.add_theme_constant_override("separation", 10)
	vh.alignment = BoxContainer.ALIGNMENT_BEGIN
	vit.add_child(vh)
	icon_cross = UIStyle.Icon.new("cross", UIStyle.TEXT, 22)
	vh.add_child(icon_cross)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	vh.add_child(hv)
	lbl_health = UIStyle.label("100", 40, UIStyle.TEXT, 600, "num")
	lbl_health.custom_minimum_size.x = 74
	hv.add_child(lbl_health)
	var hb_bg := ColorRect.new(); hb_bg.color = Color(1, 1, 1, 0.12); hb_bg.custom_minimum_size = Vector2(110, 5)
	hv.add_child(hb_bg)
	bar_health_ghost = ColorRect.new(); bar_health_ghost.color = UIStyle.DANGER; bar_health_ghost.size = Vector2(110, 5); hb_bg.add_child(bar_health_ghost)
	bar_health = ColorRect.new(); bar_health.color = UIStyle.TEXT; bar_health.size = Vector2(110, 5); hb_bg.add_child(bar_health)
	var sp := Control.new(); sp.custom_minimum_size.x = 12; vh.add_child(sp)
	icon_shield = UIStyle.Icon.new("shield", UIStyle.ARMOR, 22)
	vh.add_child(icon_shield)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 0)
	vh.add_child(av)
	lbl_armor = UIStyle.label("0", 28, UIStyle.TEXT, 600, "num")
	lbl_armor.custom_minimum_size.x = 60
	av.add_child(lbl_armor)
	var ab_bg := ColorRect.new(); ab_bg.color = Color(1, 1, 1, 0.12); ab_bg.custom_minimum_size = Vector2(110, 5)
	av.add_child(ab_bg)
	bar_armor = ColorRect.new(); bar_armor.color = UIStyle.ARMOR; bar_armor.size = Vector2(0, 5); ab_bg.add_child(bar_armor)

	# ---- munição (base-direita)
	var ap := UIStyle.panel()
	_place(ap, Control.PRESET_BOTTOM_RIGHT, -300, -92, -16, -16)
	var avb := VBoxContainer.new()
	avb.add_theme_constant_override("separation", 0)
	ap.add_child(avb)
	lbl_weapon = UIStyle.label("", 14, UIStyle.TEXT_DIM, 400, "text")
	lbl_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	avb.add_child(lbl_weapon)
	var ah := HBoxContainer.new()
	ah.alignment = BoxContainer.ALIGNMENT_END
	ah.add_theme_constant_override("separation", 6)
	avb.add_child(ah)
	lbl_mag = UIStyle.label("30", 44, UIStyle.TEXT, 600, "num")
	ah.add_child(lbl_mag)
	lbl_reserve = UIStyle.label("/ 90", 22, UIStyle.TEXT_DIM, 600, "num")
	lbl_reserve.size_flags_vertical = Control.SIZE_SHRINK_END
	ah.add_child(lbl_reserve)
	reload_line = ColorRect.new(); reload_line.color = UIStyle.TEXT; reload_line.custom_minimum_size = Vector2(0, 2)
	avb.add_child(reload_line)
	lbl_reload_hint = UIStyle.label("R — RECARREGAR", 16, UIStyle.DANGER, 700, "title")
	lbl_reload_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(lbl_reload_hint, Control.PRESET_BOTTOM_RIGHT, -300, -120, -20, -96)
	weapon_list = VBoxContainer.new()
	weapon_list.alignment = BoxContainer.ALIGNMENT_END
	weapon_list.add_theme_constant_override("separation", 4)
	_place(weapon_list, Control.PRESET_CENTER_RIGHT, -250, -40, -16, 150)   # acima do viewmodel (não cobre a arma)
	quickbar = Quickbar.new()
	quickbar.name = "Quickbar"
	quickbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(quickbar, Control.PRESET_CENTER_BOTTOM, -220, -84, 220, -16)
	folego = FolegoBar.new()
	folego.name = "Folego"
	_place(folego, Control.PRESET_CENTER_BOTTOM, -110, -92, 110, -88)
	veiculo_hud = VeiculoHud.new()
	veiculo_hud.name = "VeiculoHud"
	_place(veiculo_hud, Control.PRESET_BOTTOM_RIGHT, -262, -236, -22, -124)   # acima da caixa de munição, longe da quickbar

	# ---- topo-centro: vivos + placar + cronômetro + rodada
	var top := VBoxContainer.new()
	top_box = top
	top.add_theme_constant_override("separation", 2)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(top, Control.PRESET_CENTER_TOP, -240, 10, 240, 90)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)
	alive_t = HBoxContainer.new(); alive_t.alignment = BoxContainer.ALIGNMENT_END; alive_t.custom_minimum_size.x = 84
	alive_t.add_theme_constant_override("separation", 3)
	row.add_child(alive_t)
	var tp := UIStyle.panel(UIStyle.BG, 4)
	tp.custom_minimum_size = Vector2(250, 50)
	row.add_child(tp)
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 14)
	tp.add_child(trow)
	var tl := UIStyle.label("TR", 13, UIStyle.T_COLOR, 400, "text"); tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tl)
	lbl_score_t = UIStyle.label("0", 26, UIStyle.T_COLOR, 600, "num")
	trow.add_child(lbl_score_t)
	var tbox := Control.new(); tbox.custom_minimum_size = Vector2(72, 36)
	trow.add_child(tbox)
	lbl_timer = UIStyle.label("1:55", 30, UIStyle.TEXT, 600, "num")
	lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_timer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_timer.pivot_offset = Vector2(36, 18)
	tbox.add_child(lbl_timer)
	timer_icon = UIStyle.Icon.new("c4", UIStyle.BOMB, 30)
	timer_icon.set_anchors_preset(Control.PRESET_CENTER)
	timer_icon.position = Vector2(21, 3)
	timer_icon.visible = false
	tbox.add_child(timer_icon)
	lbl_score_ct = UIStyle.label("0", 26, UIStyle.CT_COLOR, 600, "num")
	trow.add_child(lbl_score_ct)
	var cl := UIStyle.label("CT", 13, UIStyle.CT_COLOR, 400, "text"); cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(cl)
	alive_ct = HBoxContainer.new(); alive_ct.custom_minimum_size.x = 84
	alive_ct.add_theme_constant_override("separation", 3)
	row.add_child(alive_ct)
	lbl_round = UIStyle.label("RODADA 1", 13, UIStyle.TEXT_DIM, 400, "text")
	lbl_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(lbl_round)

	# ---- killfeed (topo-direita)
	feed_box = VBoxContainer.new()
	feed_box.add_theme_constant_override("separation", 4)
	_place(feed_box, Control.PRESET_TOP_RIGHT, -560, 12, -14, 200)

	# ---- avisos centrais e banner
	announce = UIStyle.label("", 22, UIStyle.TEXT, 700, "title")
	announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(announce, Control.PRESET_CENTER_TOP, -400, 190, 400, 222)
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.047, 0.055, 0.063, 0.86), 4))
	_place(banner, Control.PRESET_CENTER_TOP, -280, 96, 280, 196)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 2)
	banner.add_child(bv)
	banner_stripe = ColorRect.new(); banner_stripe.custom_minimum_size = Vector2(0, 4)
	bv.add_child(banner_stripe)
	banner_title = UIStyle.label("", 34, UIStyle.TEXT, 700, "title")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(banner_title)
	banner_reason = UIStyle.label("", 16, UIStyle.TEXT, 400, "text")
	banner_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(banner_reason)
	banner_mvp = UIStyle.label("", 14, UIStyle.TEXT_DIM, 400, "text")
	banner_mvp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(banner_mvp)
	banner.visible = false

	# ---- barra de plantar/desarmar
	progress_panel = VBoxContainer.new()
	progress_panel.add_theme_constant_override("separation", 4)
	_place(progress_panel, Control.PRESET_CENTER, -180, 60, 180, 100)
	progress_label = UIStyle.label("", 16, UIStyle.TEXT, 700, "title")
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_panel.add_child(progress_label)
	var pbg := ColorRect.new(); pbg.color = Color(0.063, 0.071, 0.078, 0.7); pbg.custom_minimum_size = Vector2(360, 10)
	progress_panel.add_child(pbg)
	progress_fill = ColorRect.new(); progress_fill.color = UIStyle.BOMB; progress_fill.size = Vector2(0, 10); pbg.add_child(progress_fill)
	var mark := ColorRect.new(); mark.color = Color(1, 1, 1, 0.35); mark.position = Vector2(179, 0); mark.size = Vector2(2, 10); pbg.add_child(mark)
	progress_panel.visible = false

	# ---- espectador e fps
	spectate_bar = UIStyle.panel(UIStyle.BG_SOLID, 4)
	_place(spectate_bar, Control.PRESET_CENTER_BOTTOM, -260, -150, 260, -110)
	spectate_label = UIStyle.label("", 18, UIStyle.TEXT, 700, "title")
	spectate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spectate_bar.add_child(spectate_label)
	spectate_bar.visible = false
	fps_label = UIStyle.label("", 14, UIStyle.GOOD, 600, "num")
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(fps_label, Control.PRESET_TOP_RIGHT, -140, 206, -14, 226)

	buy_menu = BuyMenu.new()
	root.add_child(buy_menu)
	buy_menu.setup(match_ref, self)
	scoreboard = Scoreboard.new()
	root.add_child(scoreboard)
	scoreboard.setup(match_ref)
	pause_menu = PauseMenu.new()
	root.add_child(pause_menu)
	pause_menu.setup(match_ref, self)


# ------------------------------------------------------------------ atualização por quadro
func _process(dt: float) -> void:
	var m := match_ref
	var lp := m.local_player
	var view: Soldier = lp
	if lp and lp.controller and lp.controller.has_method("view_target"):
		view = lp.controller.view_target()
	_pulse += dt
	# placar e cronômetro
	lbl_score_t.text = str(m.score[0])
	lbl_score_ct.text = str(m.score[1])
	lbl_round.text = ("COMPRAS" if m.phase == Match.Phase.FREEZE else "RODADA %d" % m.round_number)
	var tl := m.phase_left
	timer_icon.visible = m.phase == Match.Phase.PLANTED
	lbl_timer.visible = not timer_icon.visible
	if m.phase == Match.Phase.PLANTED:
		var beat := lerpf(1.0, 0.25, clampf(1.0 - tl / float(Game.config.bomb_timer), 0.0, 1.0))
		timer_icon.modulate.a = 0.55 + 0.45 * absf(sin(_pulse * PI / beat))
		timer_icon.queue_redraw()
	else:
		lbl_timer.text = UIStyle.time_str(tl) if m.phase != Match.Phase.MATCH_END else "--:--"
		var col := UIStyle.TEXT
		if m.phase == Match.Phase.FREEZE:
			col = UIStyle.TEXT_DIM
		elif m.phase == Match.Phase.LIVE and tl < 10.0:
			col = UIStyle.DANGER
			var fr := fmod(tl, 1.0)
			lbl_timer.scale = Vector2.ONE * (1.0 + 0.1 * maxf(0.0, (fr - 0.8) * 5.0))
		_cor(lbl_timer, col)
	_update_alive(alive_t, m.team_members(0), UIStyle.T_COLOR)
	_update_alive(alive_ct, m.team_members(1), UIStyle.CT_COLOR)
	# vitais e munição de quem está sendo visto
	if view:
		quickbar.soldier = lp
		quickbar.match_ref = m
		var local_controller := lp.controller as PlayerController if lp.controller else null
		quickbar.modulate.a = 0.28 if local_controller and not local_controller._third_person and local_controller._ads_amount > 0.05 else 1.0
		quickbar.queue_redraw()
		folego.soldier = lp
		var low := view.health <= 25
		lbl_health.text = str(view.health)
		_cor(lbl_health, UIStyle.DANGER if low else UIStyle.TEXT)
		bar_health.size.x = 110.0 * view.health / 100.0
		bar_health.color = UIStyle.DANGER if low else UIStyle.TEXT
		bar_health_ghost.size.x = move_toward(bar_health_ghost.size.x, bar_health.size.x, dt * 110.0 / 0.35)
		icon_cross.color = UIStyle.DANGER if low else UIStyle.TEXT
		icon_cross.modulate.a = (0.6 + 0.4 * absf(cos(_pulse * PI / 0.6))) if low else 1.0
		icon_cross.queue_redraw()
		lbl_armor.text = str(view.armor)
		bar_armor.size.x = 110.0 * view.armor / 100.0
		icon_shield.kind = "helmet" if view.has_helmet else "shield"
		icon_shield.queue_redraw()
		if _shake_t > 0.0:
			_shake_t -= dt
			lbl_health.position.x = randf_range(-2, 2)
		else:
			lbl_health.position.x = 0
		var ws := view.current()
		if ws and ws.def.is_gun():
			lbl_mag.text = str(ws.mag)
			lbl_reserve.text = "/ " + str(ws.reserve)
			_cor(lbl_mag, UIStyle.DANGER if ws.mag <= ws.def.mag_size * 0.3 else UIStyle.TEXT)
			var reloading := view.is_reloading()
			lbl_mag.modulate.a = 0.4 if reloading else 1.0
			if reloading:
				var p := 1.0 - (view.reload_end - view.t) / ws.def.reload_time
				reload_line.custom_minimum_size.x = 268.0 * clampf(p, 0.0, 1.0)
			else:
				reload_line.custom_minimum_size.x = 0
			lbl_reload_hint.visible = view == lp and ws.mag == 0 and ws.reserve > 0 and not reloading
			lbl_reload_hint.modulate.a = 0.5 + 0.5 * absf(sin(_pulse * 4.0))
		else:
			lbl_mag.text = ""
			lbl_reserve.text = ""
			reload_line.custom_minimum_size.x = 0
			lbl_reload_hint.visible = false
		if ws and ws.def.slot == WeaponDef.Slot.BOMB:
			lbl_weapon.text = "C4 — segure o clique no bombsite"
		else:
			lbl_weapon.text = ws.def.display_name if ws else ""
		crosshair.spread_deg = view.current_spread()
		crosshair.visible_for = view.alive and ws != null and m.phase != Match.Phase.FREEZE
		crosshair.dot_only = ws != null and not ws.def.is_gun()
		var cam := get_viewport().get_camera_3d()
		if cam:
			crosshair.fov_v = cam.fov
		_update_status(view, m)
		_update_weapon_list(view, dt)
		# área (callout)
		var callout := m.callout_at(view.global_position)
		if callout != _callout_prev:
			_callout_prev = callout
			lbl_callout.text = callout
			lbl_callout.modulate.a = 0.0
			create_tween().tween_property(lbl_callout, "modulate:a", 1.0, 0.15)
	if lp:
		if lp.money != _money_prev:
			if _money_prev >= 0:
				var dm := lp.money - _money_prev
				lbl_money_delta.text = ("+" if dm > 0 else "−") + UIStyle.money(absi(dm)).replace(" ", "")
				_cor(lbl_money_delta, UIStyle.GOOD if dm > 0 else UIStyle.LOSS)
				lbl_money_delta.position.y = 244
				lbl_money_delta.modulate.a = 1.0
				var tw := create_tween().set_parallel()
				tw.tween_property(lbl_money_delta, "position:y", 232.0, 1.5)
				tw.tween_property(lbl_money_delta, "modulate:a", 0.0, 1.5).set_delay(0.3)
			_money_prev = lp.money
		lbl_money.text = UIStyle.money(lp.money)
		buy_hint.visible = m.can_buy(lp) and not buy_menu.visible
		spectate_bar.visible = not lp.alive and view != lp
		if spectate_bar.visible:
			spectate_label.text = "‹  ESPECTANDO: %s  ·  %d HP  ›" % [view.display_name.to_upper(), view.health]
		if lp.planting <= 0.0 and lp.defusing <= 0.0:
			progress_panel.visible = false
		_vignette_hurt = maxf(_vignette_hurt - dt * 1.4, 0.0)
		vignette.queue_redraw()
	for h in _hit_dirs:
		h.t -= dt
	_hit_dirs = _hit_dirs.filter(func(h): return h.t > 0.0)
	dmg_arrows.queue_redraw()
	# avisos e banner
	if _announce_t > 0.0:
		_announce_t -= dt
		announce.modulate.a = clampf(_announce_t / 0.15, 0.0, 1.0)
	else:
		announce.visible = false
	if _banner_t > 0.0:
		_banner_t -= dt
		banner.modulate.a = clampf(_banner_t / 0.4, 0.0, 1.0)
		if _banner_t <= 0.0:
			banner.visible = false
	fps_label.visible = Settings.show_fps
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	# painel do carro: só enquanto o jogador local dirige
	var c_veh: Object = lp.controller if lp else null
	veiculo_hud.carro = c_veh.get("active_vehicle") if c_veh else null
	if m.phase == Match.Phase.MATCH_END and match_end == null:
		match_end = MatchEndScreen.new()
		root.add_child(match_end)
		match_end.setup(m)


func _update_alive(box: HBoxContainer, members: Array[Soldier], col: Color) -> void:
	var n := members.size()
	while box.get_child_count() < n:
		var r := Panel.new()
		r.custom_minimum_size = Vector2(12, 18)
		box.add_child(r)
	for i in box.get_child_count():
		var r: Panel = box.get_child(i)
		r.visible = i < n
		if i < n:
			var alive := members[i].alive
			var chave := [alive, col]
			if r.get_meta("_estado", []) == chave:
				continue   # só refaz o estilo quando muda (criar StyleBox por quadro custava caro com 12+ soldados)
			r.set_meta("_estado", chave)
			var sb := StyleBoxFlat.new()
			sb.bg_color = col if alive else Color(0, 0, 0, 0.25)
			sb.set_border_width_all(1)
			sb.border_color = col if alive else Color(col, 0.6)
			sb.set_corner_radius_all(2)
			r.add_theme_stylebox_override("panel", sb)


func _update_status(s: Soldier, m: Match) -> void:
	var want: Array[String] = []
	if s.is_carrying_bomb:
		want.append("c4")
	if s.has_defuser:
		want.append("kit")
	if s.has_helmet:
		want.append("helmet")
	var cur: Array[String] = []
	for c in status_box.get_children():
		cur.append(c.kind)
	if cur != want:
		for c in status_box.get_children():
			c.queue_free()
		for k in want:
			status_box.add_child(UIStyle.Icon.new(k, UIStyle.BOMB if k == "c4" else UIStyle.TEXT, 22))
	for c in status_box.get_children():
		if c.kind == "c4":
			var in_site := m.site_at(s.global_position) != ""
			c.modulate.a = (0.4 + 0.6 * absf(sin(_pulse * TAU))) if in_site else (0.6 + 0.4 * absf(sin(_pulse * 1.5)))


func _update_weapon_list(s: Soldier, dt: float) -> void:
	_weapon_list_t -= dt
	weapon_list.visible = _weapon_list_t > 0.0
	weapon_list.modulate.a = clampf(_weapon_list_t / 0.3, 0.0, 1.0)
	if not weapon_list.visible:
		return
	var keys := s.inventory.keys()
	keys.sort()
	if weapon_list.get_child_count() != keys.size():
		for c in weapon_list.get_children():
			c.queue_free()
		for k in keys:
			var p := PanelContainer.new()
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			p.add_child(h)
			h.add_child(UIStyle.label(str(5 if k == 4 else k), 16, UIStyle.TEXT_DIM, 600, "num"))
			h.add_child(UIStyle.label("", 16, UIStyle.TEXT, 400, "text"))
			weapon_list.add_child(p)
	for i in mini(keys.size(), weapon_list.get_child_count()):
		var p: PanelContainer = weapon_list.get_child(i)
		var active: bool = keys[i] == s.active_slot
		p.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(UIStyle.ACCENT, 0.25) if active else UIStyle.BG, 3, 0))
		var lbl: Label = p.get_child(0).get_child(1)
		lbl.text = s.inventory[keys[i]].def.display_name


func _set_progress(p: float, text: String, col: Color) -> void:
	progress_panel.visible = p > 0.0 and p < 1.0
	progress_label.text = text
	progress_fill.color = col
	progress_fill.size.x = 360.0 * clampf(p, 0.0, 1.0)


func show_message(text: String, seconds := 2.0) -> void:
	announce.text = text.to_upper()
	announce.visible = true
	announce.modulate.a = 0.0
	_announce_t = seconds
	create_tween().tween_property(announce, "modulate:a", 1.0, 0.15)


# ------------------------------------------------------------------ eventos
func _on_phase(phase: int) -> void:
	if phase == Match.Phase.FREEZE:
		banner.visible = false
		_banner_t = 0.0
	elif phase == Match.Phase.LIVE and match_ref.buy_left <= 0.0:
		pass


func _on_round_ended(winner: int, reason: String) -> void:
	banner_title.text = "TERRORISTAS VENCEM" if winner == 0 else "CONTRA-TERRORISTAS VENCEM"
	banner_title.add_theme_color_override("font_color", UIStyle.team_color(winner))
	banner_stripe.color = UIStyle.team_color(winner)
	banner_reason.text = reason
	var mvp: Soldier = null
	for s in match_ref.team_members(winner):
		if mvp == null or s.round_kills > mvp.round_kills:
			mvp = s
	banner_mvp.text = ("★  Destaque da rodada: %s — %d abate%s" % [mvp.display_name, mvp.round_kills, "" if mvp.round_kills == 1 else "s"]) if mvp else ""
	banner.visible = true
	banner.modulate.a = 0.0
	banner.position.y -= 18
	var tw := create_tween().set_parallel()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(banner, "position:y", banner.position.y + 18, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_banner_t = 4.9


func _on_bomb_event(kind: String) -> void:
	var lp := match_ref.local_player
	match kind:
		"planted": show_message("A bomba foi plantada", 2.0)
		"defused": show_message("A bomba foi desarmada", 2.0)
		"dropped":
			if lp and lp.team == 0:
				show_message("A bomba caiu", 2.0)
		"picked":
			if lp and lp.is_carrying_bomb:
				show_message("Você pegou a bomba", 2.0)


func _on_killfeed(e: Dictionary) -> void:
	var lp := match_ref.local_player
	var mine: bool = lp != null and e.killer == lp.display_name
	var died: bool = lp != null and e.victim == lp.display_name
	var border := UIStyle.ACCENT if mine else (UIStyle.DANGER if died else UIStyle.PANEL_LINE)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.063, 0.071, 0.078, 0.65), 3, 2 if (mine or died) else 1, border))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_END
	p.add_child(h)
	if e.killer != "":
		h.add_child(UIStyle.label(e.killer, 15, UIStyle.team_color(e.killer_team), 600, "text"))
		if e.assist != "":
			h.add_child(UIStyle.label("+ " + e.assist, 13, UIStyle.TEXT_DIM, 400, "text"))
	h.add_child(UIStyle.label(e.weapon, 14, UIStyle.TEXT, 600, "num"))
	if e.wallbang:
		h.add_child(UIStyle.Icon.new("wallbang", UIStyle.TEXT, 16))
	if e.headshot:
		h.add_child(UIStyle.Icon.new("headshot", UIStyle.TEXT, 16))
	h.add_child(UIStyle.label(e.victim, 15, UIStyle.team_color(e.victim_team), 600, "text"))
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 28)
	wrap.add_child(p)
	feed_box.add_child(wrap)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var w := p.size.x
	p.position = Vector2(feed_box.size.x, 0)
	create_tween().tween_property(p, "position:x", feed_box.size.x - w, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	tw.tween_interval(5.5)
	tw.tween_property(wrap, "modulate:a", 0.0, 0.3)
	tw.tween_callback(wrap.queue_free)
	while feed_box.get_child_count() > 5:
		var old := feed_box.get_child(0)
		feed_box.remove_child(old)
		old.queue_free()


func _on_local_damaged(amount: int, attacker: Soldier, _from_dir: Vector3) -> void:
	_vignette_hurt = clampf(0.1 + amount / 150.0, 0.0, 0.45)
	_shake_t = 0.15
	if attacker:
		_hit_dirs.append({"pos": attacker.global_position, "t": 1.2})
		if _hit_dirs.size() > 4:
			_hit_dirs.pop_front()
	Audio.play("hurt", {"volume_db": -6.0})


func _on_damage_dealt(attacker: Soldier, victim: Soldier, _amount: int, group: String) -> void:
	if attacker == match_ref.local_player and victim != attacker:
		Audio.play("hitmark_head" if group == "head" else "hitmark", {"volume_db": -10.0 if group != "head" else -4.0, "pitch_var": 0.0})


func _draw_damage_arcs() -> void:
	var lp := match_ref.local_player
	if lp == null or not lp.alive:
		return
	var c := dmg_arrows.size * 0.5
	for h in _hit_dirs:
		var to: Vector3 = h.pos - lp.global_position
		var ang := atan2(to.x, -to.z) + lp.yaw
		var a := clampf(h.t / 1.2, 0.0, 1.0)
		var center := -ang - PI / 2
		dmg_arrows.draw_arc(c, 110.0, center - deg_to_rad(25), center + deg_to_rad(25), 16, Color(UIStyle.HURT, 0.85 * a), 6.0)


func _draw_vignette() -> void:
	var lp := match_ref.local_player
	var s := vignette.size
	var alpha := _vignette_hurt
	if lp and lp.alive and lp.health <= 25:
		alpha = maxf(alpha, 0.12 + 0.08 * absf(sin(_pulse * PI / 0.6)))
	if alpha <= 0.01:
		return
	var w := s.x * 0.18
	var col := Color(0.8, 0.05, 0.03, alpha)
	var clear := Color(0.8, 0.05, 0.03, 0.0)
	vignette.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, s.y), Vector2(0, s.y)]), PackedColorArray([col, clear, clear, col]))
	vignette.draw_polygon(PackedVector2Array([Vector2(s.x - w, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y)]), PackedColorArray([clear, col, col, clear]))
	vignette.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, w * 0.6), Vector2(0, w * 0.6)]), PackedColorArray([col, col, clear, clear]))
	vignette.draw_polygon(PackedVector2Array([Vector2(0, s.y - w * 0.6), Vector2(s.x, s.y - w * 0.6), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([clear, clear, col, col]))


func _unhandled_input(event: InputEvent) -> void:
	var lp := match_ref.local_player
	if event.is_action_pressed("pause"):
		if buy_menu.visible:
			buy_menu.close()
		else:
			pause_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("buy_menu") and lp and not pause_menu.visible and not match_ref.is_survival():
		if buy_menu.visible:
			buy_menu.close()
		elif match_ref.can_buy(lp):
			buy_menu.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scoreboard") and not match_ref.is_survival():
		scoreboard.visible = true
	elif event.is_action_released("scoreboard"):
		scoreboard.visible = false


func set_ui_blocking(on: bool) -> void:
	var lp := match_ref.local_player
	if lp and lp.controller:
		lp.controller.ui_blocking = on
	if not Game.test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED



## Troca a cor da fonte só quando muda: add_theme_color_override a cada quadro refaz tema/layout do Label (~ms com vários).
func _cor(c: Control, cor: Color) -> void:
	if c.get_meta("_cor", Color(-1, -1, -1)) != cor:
		c.set_meta("_cor", cor)
		c.add_theme_color_override("font_color", cor)


## Sobrevivência: tira radar, placar, cronômetro, killfeed, dinheiro, compras, armadura/colete e lista de armas; entra a barra de saúde nova.
func modo_sobrevivencia() -> void:
	for c in [rp, top_box, feed_box, lbl_money, lbl_money_delta, buy_hint, lbl_callout, alive_t, alive_ct, lbl_round, lbl_timer, lbl_score_t, lbl_score_ct, weapon_list, vit, status_box]:
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	if match_ref.local_player and vital_bar == null:
		vital_bar = VitalBar.new()
		vital_bar.vincular(match_ref.local_player)
		_place(vital_bar, Control.PRESET_BOTTOM_LEFT, 16, -80, 330, -16)


func _on_plate_started(seconds: float) -> void:
	show_message("Encaixando placa...", seconds)
	_flash_azul(0.35, seconds * 0.9)


func _on_plate_applied() -> void:
	_flash_azul(0.55, 0.6)
	Audio.ui("buy")


## Clarão azul nas bordas da tela (efeito da placa).
func _flash_azul(alpha: float, seconds: float) -> void:
	var f := ColorRect.new()
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.color = Color(0.2, 0.55, 1.0, 0.0)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", alpha * 0.8, seconds * 0.4)
	tw.tween_property(f, "color:a", 0.0, seconds * 0.6)
	tw.tween_callback(f.queue_free)


## Colete de placas: 3 barras azuis (uma por placa encaixada, a atual enche durante a aplicação) e as placas na mochila.
class PlatesBar extends Control:
	var s: Soldier

	func setup(soldier: Soldier) -> void:
		s = soldier
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if s == null:
			return
		var cheias := float(s.armor) / float(Soldier.PLATE_ARMOR)
		var aplicando := 1.0 - s.plate_left / Soldier.PLATE_TIME if s.plate_left > 0.0 else 0.0
		for i in 3:
			var r := Rect2(i * 37.0, 4.0, 33.0, 13.0)
			draw_rect(r, Color(1, 1, 1, 0.12))
			var f := clampf(cheias - i, 0.0, 1.0)
			if s.plate_left > 0.0 and i == int(floor(cheias + 0.001)):
				f = maxf(f, aplicando)
				draw_rect(r.grow(2.0), Color(0.3, 0.65, 1.0, 0.25 + 0.2 * sin(Time.get_ticks_msec() * 0.02)))
			draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Color(0.27, 0.6, 1.0))
		# placas carregadas (quadradinhos abaixo)
		for i in 3:
			var c := Color(0.75, 0.8, 0.85) if i < s.plates else Color(1, 1, 1, 0.1)
			draw_rect(Rect2(i * 37.0 + 8.0, 24.0, 17.0, 11.0), c)
		if s.has_vest and s.plates > 0 and s.armor < Soldier.PLATE_ARMOR * 3:
			draw_string(ThemeDB.fallback_font, Vector2(114.0, 34.0), "[B]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
