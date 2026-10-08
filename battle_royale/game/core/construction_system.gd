class_name ConstructionSystem
extends Node
## Wheel menu, resource-backed modular placement and translucent world blueprint.

const PIECES := [
	{"id":"foundation", "name":"Fundação quadrada", "icon":"◇", "size":Vector3(4.0, .24, 4.0), "grid":4.0, "center":.12, "cost":{"wood":50,"stone":10}, "profile":"slab"},
	{"id":"floor", "name":"Piso de madeira", "icon":"▱", "size":Vector3(4.0, .16, 4.0), "grid":4.0, "center":.08, "cost":{"wood":35,"stone":0}, "profile":"slab"},
	{"id":"wall", "name":"Parede de madeira", "icon":"▤", "size":Vector3(4.0, 3.0, .18), "grid":4.0, "center":1.5, "cost":{"wood":40,"stone":5}, "profile":"wall"},
	{"id":"window", "name":"Parede com janela", "icon":"▣", "size":Vector3(4.0, 3.0, .18), "grid":4.0, "center":1.5, "cost":{"wood":45,"stone":5}, "profile":"window"},
	{"id":"door", "name":"Batente de porta", "icon":"▧", "size":Vector3(4.0, 3.0, .18), "grid":4.0, "center":1.5, "cost":{"wood":35,"stone":5}, "profile":"door"},
	{"id":"roof", "name":"Telhado modular", "icon":"⌂", "size":Vector3(4.0, .18, 4.0), "grid":4.0, "center":.09, "cost":{"wood":45,"stone":8}, "profile":"slab"},
	{"id":"stairs", "name":"Escada de madeira", "icon":"▰", "size":Vector3(2.0, 1.5, 2.0), "grid":2.0, "center":.75, "cost":{"wood":30,"stone":0}, "profile":"stairs"},
	{"id":"pillar", "name":"Pilar de madeira", "icon":"┃", "size":Vector3(.38, 3.0, .38), "grid":2.0, "center":1.5, "cost":{"wood":18,"stone":0}, "profile":"pillar"},
	{"id":"chest", "name":"Baú de base", "icon":"▭", "size":Vector3(.9, .58, .55), "grid":.5, "center":.29, "cost":{"wood":25,"stone":0}, "profile":"chest"},
]

const WOOD_MAT := Color("#9a6336")
const STONE_MAT := Color("#92999a")
const BLUEPRINT_COLOR := Color(0.12, 0.67, 1.0, 0.48)
const INVALID_COLOR := Color(1.0, 0.22, 0.15, 0.55)
const MAX_REACH := 14.0
const GRID_MAJOR := 4.0
const FREE_BUILD_MODE := true
var match_ref
var wheel_ui: RadialWheel
var world_root: Node3D
var preview_root: Node3D
var current_piece := -1
var selected_piece := 0
var yaw_step := 0
var wheel_open := false
var construction_mode := false
var align_to_piece := true
var candidate_transform := Transform3D.IDENTITY
var candidate_valid := false
var candidate_status := "MIRE EM UMA SUPERFÍCIE"
var notice := ""
var notice_time := 0.0


class ConstructionDoor extends Node3D:
	var system: ConstructionSystem
	var hinge: Node3D
	var opened := false
	var busy := false
	var panel_collision: CollisionShape3D

	func toggle() -> void:
		if busy or hinge == null:
			return
		busy = true
		opened = not opened
		var target := PI * .5 if opened else 0.0
		var tween := create_tween()
		if opened and panel_collision:
			panel_collision.disabled = true
		tween.tween_property(hinge, "rotation:y", target, .38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func():
			busy = false
			if panel_collision:
				panel_collision.disabled = opened
		)
		if system and system.match_ref and system.match_ref.has_method("play_sfx"):
			system.match_ref.play_sfx("door_open" if opened else "door_close", global_position)


class RadialWheel extends Control:
	var system: ConstructionSystem
	var palette_font: Font = ThemeDB.fallback_font

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if system == null:
			return
		if not system.wheel_open:
			if system.construction_mode:
				var panel := Rect2(22, 116, 276, 182)
				draw_rect(panel, Color(.025, .04, .055, .84), true)
				draw_rect(panel, Color(.25, .67, .82, .9), false, 1.5)
				draw_rect(Rect2(panel.position, Vector2(4, panel.size.y)), Color("#58c7eb"), true)
				draw_string(palette_font, panel.position + Vector2(18, 24), "MODO CONSTRUÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#73d7f3"))
				var item_name := "Escolha uma peça [B]" if system.current_piece < 0 else String(system.PIECES[system.current_piece].name)
				draw_string(palette_font, panel.position + Vector2(18, 49), item_name, HORIZONTAL_ALIGNMENT_LEFT, 248, 17, Color("#fff2ce"))
				var status_color := Color("#8ee6ff") if system.candidate_valid else Color("#ff8b72")
				draw_string(palette_font, panel.position + Vector2(18, 72), system.candidate_status, HORIZONTAL_ALIGNMENT_LEFT, 260, 12, status_color)
				draw_line(panel.position + Vector2(14, 82), panel.position + Vector2(262, 82), Color(.4, .6, .68, .45), 1.0)
				draw_string(palette_font, panel.position + Vector2(18, 103), "F  Encaixe: %s" % ("LIGADO" if system.align_to_piece else "GRADE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e4edf0"))
				draw_string(palette_font, panel.position + Vector2(18, 123), "Clique colocar   •   Q girar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(.84, .88, .9))
				draw_string(palette_font, panel.position + Vector2(18, 143), "X remover peça mirado", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(.84, .88, .9))
				draw_string(palette_font, panel.position + Vector2(18, 163), "G sair   •   Esc cancelar peça", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(.84, .88, .9))
			else:
				draw_string(palette_font, Vector2(24, 132), "[B] Construção", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, .78))
			if system.notice_time > 0.0:
				draw_string(palette_font, Vector2(size.x * .5, size.y * .64), system.notice, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color("#ffad78"))
			return
		var c := Vector2(size.x * .735, size.y * .49)
		var outer := 184.0
		var inner := 80.0
		var count := system.PIECES.size()
		var sector := TAU / float(count)
		draw_circle(c, outer + 11.0, Color(.015, .025, .035, .44))
		draw_arc(c, outer + 7.0, 0, TAU, 96, Color(.42, .76, .96, .5), 2.0, true)
		draw_circle(c, outer - 1.0, Color(.018, .032, .043, .30))
		for i in count:
			var center_ang := -PI * .5 + float(i) * sector
			var a0 := center_ang - sector * .46
			var a1 := center_ang + sector * .46
			var color := Color(.025, .045, .06, .92)
			if i == system.selected_piece:
				color = Color(.055, .32, .54, .97)
			var points := PackedVector2Array()
			for k in range(13):
				var a := lerpf(a0, a1, float(k) / 12.0)
				points.append(c + Vector2(cos(a), sin(a)) * outer)
			for k in range(12, -1, -1):
				var a := lerpf(a0, a1, float(k) / 12.0)
				points.append(c + Vector2(cos(a), sin(a)) * inner)
			draw_colored_polygon(points, color)
			draw_polyline(points, Color(.55, .82, 1.0, .42), 1.25, true)
			var item: Dictionary = system.PIECES[i]
			var icon_r := lerpf(inner, outer, .60)
			var icon_pos := c + Vector2(cos(center_ang), sin(center_ang)) * icon_r
			_draw_piece_icon(icon_pos, String(item.id), i == system.selected_piece)
		# Center panel follows the illustration: selected item and recipe stay legible over the world.
		draw_circle(c, inner - 5.0, Color(.018, .028, .038, .98))
		draw_arc(c, inner - 5.0, 0, TAU, 64, Color(.42, .70, .88, .75), 2.0, true)
		_draw_center_tools(c + Vector2(0, -35))
		var item: Dictionary = system.PIECES[system.selected_piece]
		draw_string(palette_font, c + Vector2(-110, -9), String(item.name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 220, 18, Color("#fff2ce"))
		draw_string(palette_font, c + Vector2(-110, 19), "MODO DE TESTE", HORIZONTAL_ALIGNMENT_CENTER, 220, 12, Color(.75, .82, .84))
		draw_string(palette_font, c + Vector2(-110, 40), system._cost_text(item), HORIZONTAL_ALIGNMENT_CENTER, 220, 13, Color("#c9e8f5"))
		draw_string(palette_font, Vector2(size.x - 24.0, size.y - 30.0), "↑ ↓ navegar   •   Enter selecionar   •   Esc sair", HORIZONTAL_ALIGNMENT_RIGHT, 620.0, 14, Color(1, 1, 1, .82))

	func _draw_piece_icon(c: Vector2, kind: String, selected: bool) -> void:
		# Crisp, miniature isometric construction pieces (drawn in native UI vectors).
		var bright := Color("#f8e6bd") if selected else Color("#d9e5e8")
		var mid := Color("#b88450") if selected else Color("#91a2a6")
		var dark := Color("#704323") if selected else Color("#53636b")
		var glass := Color("#74c8e8")
		var p := PackedVector2Array([c + Vector2(0,-15), c + Vector2(18,-5), c + Vector2(0,5), c + Vector2(-18,-5)])
		match kind:
			"foundation", "floor":
				draw_colored_polygon(PackedVector2Array([p[3],p[0],p[1],p[2]]), mid)
				draw_colored_polygon(PackedVector2Array([p[3],p[2],p[2]+Vector2(0,15),p[3]+Vector2(0,15)]), dark)
				draw_colored_polygon(PackedVector2Array([p[2],p[1],p[1]+Vector2(0,15),p[2]+Vector2(0,15)]), Color("#95663d") if selected else Color("#718188"))
				if kind == "floor":
					for k in range(1, 4):
						draw_line(p[3].lerp(p[0],float(k)/4.0), p[2].lerp(p[1],float(k)/4.0), dark, 1.0, true)
				else:
					draw_line(p[3],p[1],bright,1.4,true)
					draw_line(p[3],p[0],bright,1.3,true)
			"wall", "window", "door":
				var frame := Rect2(c + Vector2(-12,-16), Vector2(24,31))
				draw_rect(frame, dark, false, 3.0)
				draw_rect(Rect2(frame.position+Vector2(2,2),frame.size-Vector2(4,4)), mid, true)
				if kind == "window":
					draw_rect(Rect2(c+Vector2(-6,-10),Vector2(12,12)),glass,true)
					draw_line(c+Vector2(0,-10),c+Vector2(0,2),bright,1.4,true)
					draw_line(c+Vector2(-6,-4),c+Vector2(6,-4),bright,1.2,true)
				elif kind == "door":
					draw_rect(Rect2(c+Vector2(-5,-12),Vector2(11,25)),dark,true)
					draw_line(c+Vector2(5,-12),c+Vector2(5,13),bright,1.2,true)
					draw_circle(c+Vector2(3,1),1.5,bright)
				else:
					for k in range(1, 4):
						draw_line(c+Vector2(-10,-12+k*6),c+Vector2(10,-12+k*6),bright,1.2,true)
			"roof":
				draw_colored_polygon(PackedVector2Array([c+Vector2(-19,0),c+Vector2(0,-14),c+Vector2(19,0),c+Vector2(0,7)]),mid)
				draw_line(c+Vector2(-19,0),c+Vector2(0,-14),bright,2.0,true)
				draw_line(c+Vector2(0,-14),c+Vector2(19,0),bright,2.0,true)
				for k in range(1, 3):
					draw_line(c+Vector2(-14+k*4,-1),c+Vector2(0,-11+k*2),dark,1.1,true)
			"stairs":
				for k in 4:
					var step_y := 10.0-float(k)*6.0
					draw_line(c+Vector2(-15+float(k)*3,step_y),c+Vector2(13,step_y),bright,3.0,true)
					draw_line(c+Vector2(13,step_y),c+Vector2(13,step_y+5),dark,2.0,true)
			"chest":
				draw_colored_polygon(PackedVector2Array([c+Vector2(-15,-1),c+Vector2(-12,-9),c+Vector2(12,-9),c+Vector2(15,-1)]),bright)
				draw_rect(Rect2(c+Vector2(-15,-1),Vector2(30,14)),mid,true)
				draw_rect(Rect2(c+Vector2(-15,-1),Vector2(30,14)),dark,false,2.0)
				draw_line(c+Vector2(-15,-1),c+Vector2(15,-1),dark,2.0,true)
				draw_line(c+Vector2(-8,-9),c+Vector2(-8,13),dark,2.0,true)
				draw_line(c+Vector2(8,-9),c+Vector2(8,13),dark,2.0,true)
				draw_rect(Rect2(c+Vector2(-3,-4),Vector2(6,6)),Color("e3c35c"),true)
			"pillar":
				draw_colored_polygon(PackedVector2Array([c+Vector2(-8,-15),c+Vector2(4,-15),c+Vector2(9,-11),c+Vector2(-3,-11)]),bright)
				draw_rect(Rect2(c+Vector2(-8,-11),Vector2(12,23)),mid,true)
				draw_colored_polygon(PackedVector2Array([c+Vector2(4,-11),c+Vector2(9,-14),c+Vector2(9,9),c+Vector2(4,12)]),dark)
				draw_line(c+Vector2(-5,-8),c+Vector2(-5,9),bright,1.0,true)

	func _draw_center_tools(c: Vector2) -> void:
		# Crossed hammer and pick silhouette echoes the construction reference.
		var ink := Color("#dce7e8")
		draw_line(c+Vector2(-13,-10),c+Vector2(13,10),ink,4.0,true)
		draw_line(c+Vector2(13,-10),c+Vector2(-12,12),Color("#aebdc1"),4.0,true)
		draw_line(c+Vector2(-16,-11),c+Vector2(-8,-15),ink,3.5,true)
		draw_line(c+Vector2(8,-14),c+Vector2(16,-10),ink,3.5,true)


func setup(m) -> void:
	match_ref = m
	world_root = Node3D.new()
	world_root.name = "ConstrucoesDoJogador"
	m.add_child(world_root)
	preview_root = Node3D.new()
	preview_root.name = "BlueprintPreview"
	preview_root.visible = false
	m.add_child(preview_root)
	wheel_ui = RadialWheel.new()
	wheel_ui.name = "BuildRadialWheel"
	wheel_ui.system = self
	m.hud.add_child(wheel_ui)
	set_process(true)


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and wheel_open:
		var center := wheel_ui.size * Vector2(.735, .49)
		var delta := (event as InputEventMouseMotion).position - center
		if delta.length() > 48.0:
			var angle := atan2(delta.y, delta.x) + PI * .5
			var step := TAU / float(PIECES.size())
			selected_piece = posmod(roundi(angle / step), PIECES.size())
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_G and (construction_mode or wheel_open or current_piece >= 0):
			_leave_build_mode()
			return true
		if key == KEY_B and not wheel_open:
			_open_wheel()
			return true
		if wheel_open:
			if key == KEY_ESCAPE:
				_close_wheel()
				construction_mode = false
				wheel_ui.visible = false
				wheel_ui.queue_redraw()
				return true
			if key in [KEY_LEFT, KEY_A, KEY_Q]:
				selected_piece = posmod(selected_piece - 1, PIECES.size())
				return true
			if key in [KEY_RIGHT, KEY_D, KEY_E]:
				selected_piece = posmod(selected_piece + 1, PIECES.size())
				return true
			if key in [KEY_ENTER, KEY_SPACE]:
				_choose_piece(selected_piece)
				return true
			return true
		if current_piece >= 0:
			if key == KEY_ESCAPE:
				_cancel_build()
				return true
			if key == KEY_Q:
				yaw_step = posmod(yaw_step + 1, 4)
				_update_candidate()
				return true
		if construction_mode and key == KEY_F:
			align_to_piece = not align_to_piece
			if current_piece >= 0:
				_update_candidate()
			wheel_ui.queue_redraw()
			return true
		if construction_mode and key == KEY_X:
			_delete_aimed_piece()
			return true
		if key == KEY_E and _toggle_nearest_door():
			return true
	if event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton).button_index
		if wheel_open:
			if button == MOUSE_BUTTON_LEFT:
				var center := wheel_ui.size * Vector2(.735, .49)
				var delta := (event as InputEventMouseButton).position - center
				if delta.length() > 48.0:
					var angle := atan2(delta.y, delta.x) + PI * .5
					selected_piece = posmod(roundi(angle / (TAU / float(PIECES.size()))), PIECES.size())
				_choose_piece(selected_piece)
				return true
			if button == MOUSE_BUTTON_WHEEL_UP:
				selected_piece = posmod(selected_piece - 1, PIECES.size())
				return true
			if button == MOUSE_BUTTON_WHEEL_DOWN:
				selected_piece = posmod(selected_piece + 1, PIECES.size())
				return true
		if current_piece >= 0 and button == MOUSE_BUTTON_LEFT:
			place_current()
			return true
		if current_piece >= 0 and button == MOUSE_BUTTON_WHEEL_UP:
			yaw_step = posmod(yaw_step + 1, 4)
			_update_candidate()
			return true
		if current_piece >= 0 and button == MOUSE_BUTTON_WHEEL_DOWN:
			yaw_step = posmod(yaw_step - 1, 4)
			_update_candidate()
			return true
	return false


func _open_wheel() -> void:
	if match_ref.br_ui and match_ref.br_ui.visible:
		return
	wheel_open = true
	construction_mode = true
	wheel_ui.visible = true
	var pc := match_ref.local_player.controller as PlayerController
	if pc:
		pc.ui_blocking = true
	if not Game.test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.warp_mouse(wheel_ui.size * Vector2(.735, .49))
		# Start on the foundation sector that matches the concept-art selection.
	selected_piece = 0
	wheel_ui.queue_redraw()


func _close_wheel() -> void:
	wheel_open = false
	wheel_ui.visible = construction_mode
	var pc := match_ref.local_player.controller as PlayerController
	if pc:
		pc.ui_blocking = bool(match_ref.br_ui and match_ref.br_ui.visible)
	if not Game.test_mode and not (match_ref.br_ui and match_ref.br_ui.visible):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _choose_piece(index: int) -> void:
	construction_mode = true
	current_piece = clampi(index, 0, PIECES.size() - 1)
	yaw_step = 0
	preview_root.visible = true
	_build_preview_mesh()
	_close_wheel()


func _cancel_build() -> void:
	current_piece = -1
	preview_root.visible = false
	candidate_valid = false
	_set_notice("Construção cancelada", 1.5)
	wheel_ui.queue_redraw()


func _leave_build_mode() -> void:
	if wheel_open:
		_close_wheel()
	construction_mode = false
	wheel_ui.visible = false
	current_piece = -1
	candidate_valid = false
	preview_root.visible = false
	_set_notice("Modo construção encerrado", 1.2)
	wheel_ui.queue_redraw()


func _process(dt: float) -> void:
	notice_time = maxf(0.0, notice_time - dt)
	if current_piece < 0 or wheel_open or match_ref.local_player == null:
		return
	_update_candidate()


func _build_preview_mesh() -> void:
	for child in preview_root.get_children():
		child.queue_free()
	var piece: Dictionary = PIECES[current_piece]
	_add_piece_visual(preview_root, piece, true)
	var grid := MeshInstance3D.new()
	grid.name = "BlueprintGrid"
	var profile := String(piece.profile)
	if profile in ["wall", "window", "door"]:
		grid.mesh = _grid_mesh(float(piece.size.x), float(piece.size.y))
		grid.rotation.x = PI * .5
		grid.position.y = float(piece.center)
	else:
		grid.mesh = _grid_mesh(float(piece.size.x), float(piece.size.z))
		grid.position.y = float(piece.center) + float(piece.size.y) * .5 + .012
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.albedo_color = Color(.40, .84, 1.0, .88)
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid.material_override = grid_mat
	preview_root.add_child(grid)


func _update_candidate() -> void:
	var player: Soldier = match_ref.local_player
	var pc := player.controller as PlayerController
	var camera := pc.camera if pc else null
	if camera == null:
		candidate_valid = false
		candidate_status = "CÂMERA INDISPONÍVEL"
		return
	var origin := camera.global_position
	var target := origin - camera.global_basis.z * MAX_REACH
	var query := PhysicsRayQueryParameters3D.create(origin, target, Soldier.LAYER_WORLD, [player.get_rid()])
	query.collide_with_areas = false
	var hit: Dictionary = match_ref.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		candidate_valid = false
		candidate_status = "NENHUMA SUPERFÍCIE NO RAIO"
		preview_root.visible = false
		if wheel_ui:
			wheel_ui.queue_redraw()
		return
	var piece: Dictionary = PIECES[current_piece]
	var grid := float(piece.grid)
	var p: Vector3 = hit.position
	var hit_root := _find_construction_root(hit.get("collider") as Node)
	if String(piece.id) == "stairs":
		var stair_root := hit_root
		if stair_root and String(stair_root.get_meta("construction_id")) == "stairs":
			var local_hit: Vector3 = stair_root.to_local(hit.position)
			if local_hit.z < -.25 and local_hit.y > .35:
				var old_basis: Basis = stair_root.global_basis
				p = stair_root.global_position + old_basis * Vector3(0, float(piece.size.y), -float(piece.size.z))
				yaw_step = posmod(roundi(stair_root.rotation.y / (PI * .5)), 4)
				candidate_transform = Transform3D(old_basis, p)
				preview_root.global_transform = candidate_transform
				preview_root.visible = true
				candidate_valid = _has_cost(piece) and float(hit.normal.dot(Vector3.UP)) >= .78 and origin.distance_to(hit.position) <= MAX_REACH and not _overlaps_constructed(p, piece)
				candidate_status = "PRONTO PARA COLOCAR" if candidate_valid else "ESCADA SEM ESPAÇO LIVRE"
				_set_preview_tint(candidate_valid)
				return
	var piece_snapped := false
	if align_to_piece and hit_root:
		var snap := _snap_to_aimed_piece(hit_root, hit.position, hit.normal, piece, p)
		piece_snapped = bool(snap.get("valid", false))
		if piece_snapped:
			p = snap.position
			yaw_step = int(snap.yaw_step)
	if not piece_snapped and String(piece.id) == "roof" and float(hit.normal.dot(Vector3.UP)) < -.78:
		# Roof placed from below: its upper face touches the underside being targeted.
		p.y = hit.position.y - float(piece.size.y)
	if not piece_snapped and String(piece.profile) in ["wall", "window", "door"]:
		# Parede: centro do comprimento alinhado à célula e centro da espessura na borda.
		var edge_offset := grid * .5
		if yaw_step % 2 == 0:
			p.x = roundf(p.x / grid) * grid
			p.z = roundf((p.z - edge_offset) / grid) * grid + edge_offset
		else:
			p.x = roundf((p.x - edge_offset) / grid) * grid + edge_offset
			p.z = roundf(p.z / grid) * grid
	elif not piece_snapped:
		p.x = roundf(p.x / grid) * grid
		p.z = roundf(p.z / grid) * grid
	# Keep the exact hit height: rounding Y made foundations float or sink on uneven ground.
	candidate_transform = Transform3D(Basis(Vector3.UP, float(yaw_step) * PI * .5), p)
	preview_root.global_transform = candidate_transform
	preview_root.visible = true
	var available := _has_cost(piece)
	var surface_ok := float(hit.normal.dot(Vector3.UP)) >= .78 or piece_snapped
	if String(piece.id) == "roof":
		surface_ok = absf(float(hit.normal.dot(Vector3.UP))) >= .78
	if String(piece.id) == "chest" and hit_root and (hit_root.has_meta("bau") or String(hit_root.get_meta("construction_id", "")) in ["pillar", "stairs"]):
		surface_ok = false   # sem baú em cima de baú (nem empilhado em pilar/escada)
	var in_range := origin.distance_to(hit.position) <= MAX_REACH
	var clear := not _overlaps_constructed(p, piece)
	candidate_valid = available and surface_ok and in_range and clear
	if candidate_valid:
		candidate_status = "PRONTO PARA COLOCAR"
	elif not available:
		candidate_status = "FALTAM MATERIAIS"
	elif not surface_ok:
		candidate_status = "MIRE NA FACE DE ENCAIXE"
	elif not in_range:
		candidate_status = "PEÇA FORA DO ALCANCE"
	else:
		candidate_status = "ESPAÇO OCUPADO"
	_set_preview_tint(candidate_valid)
	if wheel_ui:
		wheel_ui.queue_redraw()


func _find_construction_root(node: Node) -> Node3D:
	while node:
		if node is Node3D and node.is_in_group("player_constructed"):
			return node as Node3D
		if node == world_root:
			break
		node = node.get_parent()
	return null


func _snap_to_aimed_piece(target_root: Node3D, hit_position: Vector3, hit_normal: Vector3, piece: Dictionary, initial_position: Vector3) -> Dictionary:
	var target_id := String(target_root.get_meta("construction_id", ""))
	var target_size: Vector3 = target_root.get_meta("build_size", Vector3.ZERO)
	var target_pos := target_root.global_position
	var target_basis := target_root.global_basis
	var target_yaw := posmod(roundi(target_root.rotation.y / (PI * .5)), 4)
	var local_hit: Vector3 = target_root.to_local(hit_position)
	var local_normal: Vector3 = target_basis.inverse() * hit_normal.normalized()
	var selected_id := String(piece.id)
	var selected_profile := String(piece.profile)
	var selected_size: Vector3 = piece.size
	var p := initial_position
	var snapped_yaw := yaw_step
	var target_is_wall := target_id in ["wall", "window", "door"]
	var target_is_slab := target_id in ["foundation", "floor", "roof"]
	var selected_is_wall := selected_profile in ["wall", "window", "door"]
	var selected_is_slab := selected_id in ["foundation", "floor", "roof"]

	if selected_is_wall and target_is_wall:
		if local_normal.y > .7:
			p = target_pos + Vector3(0, target_size.y, 0)
			snapped_yaw = target_yaw
			return {"valid": true, "position": p, "yaw_step": snapped_yaw}
		# Aim anywhere on a wall and attach the next 4 m module to its nearest end.
		var end_sign := -1.0 if local_hit.x < 0.0 else 1.0
		p = target_pos + target_basis * Vector3(end_sign * target_size.x, 0, 0)
		snapped_yaw = target_yaw
		return {"valid": true, "position": p, "yaw_step": snapped_yaw}

	if selected_is_wall and target_is_slab:
		var top_y := target_pos.y + target_size.y
		if local_normal.y > .7:
			p.y = top_y
			var grid := float(piece.grid)
			if yaw_step % 2 == 0:
				p.x = roundf(p.x / grid) * grid
				p.z = roundf((p.z - grid * .5) / grid) * grid + grid * .5
			else:
				p.x = roundf((p.x - grid * .5) / grid) * grid + grid * .5
				p.z = roundf(p.z / grid) * grid
			return {"valid": true, "position": p, "yaw_step": yaw_step}
		if absf(local_normal.x) > .7:
			snapped_yaw = posmod(target_yaw + 1, 4)
			p = target_pos + target_basis * Vector3(signf(local_normal.x) * (target_size.x * .5 + selected_size.z * .5), target_size.y, 0)
			return {"valid": true, "position": p, "yaw_step": snapped_yaw}
		if absf(local_normal.z) > .7:
			snapped_yaw = target_yaw
			p = target_pos + target_basis * Vector3(0, target_size.y, signf(local_normal.z) * (target_size.z * .5 + selected_size.z * .5))
			return {"valid": true, "position": p, "yaw_step": snapped_yaw}

	if selected_is_slab and target_is_slab:
		snapped_yaw = target_yaw
		if local_normal.y > .7:
			p = Vector3(target_pos.x, target_pos.y + target_size.y, target_pos.z)
			return {"valid": true, "position": p, "yaw_step": snapped_yaw}
		if local_normal.y < -.7:
			p = Vector3(target_pos.x, target_pos.y - selected_size.y, target_pos.z)
			return {"valid": true, "position": p, "yaw_step": snapped_yaw}
		if absf(local_normal.x) > .7:
			p = target_pos + target_basis * Vector3(signf(local_normal.x) * (target_size.x + selected_size.x) * .5, 0, 0)
			return {"valid": true, "position": p, "yaw_step": snapped_yaw}
		if absf(local_normal.z) > .7:
			p = target_pos + target_basis * Vector3(0, 0, signf(local_normal.z) * (target_size.z + selected_size.z) * .5)
			return {"valid": true, "position": p, "yaw_step": snapped_yaw}
	return {"valid": false}


func _delete_aimed_piece() -> void:
	var player: Soldier = match_ref.local_player
	var pc := player.controller as PlayerController
	var camera := pc.camera if pc else null
	if camera == null:
		return
	var origin := camera.global_position
	var target := origin - camera.global_basis.z * MAX_REACH
	var query := PhysicsRayQueryParameters3D.create(origin, target, Soldier.LAYER_WORLD, [player.get_rid()])
	query.collide_with_areas = false
	var hit: Dictionary = match_ref.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_set_notice("Mire em uma peça construída para removê-la", 1.4)
		return
	var root := _find_construction_root(hit.get("collider") as Node)
	if root == null:
		_set_notice("Essa peça não é sua construção", 1.4)
		return
	var removed_name := String(root.get_meta("construction_id", "peça"))
	if root.has_meta("bau_node"):
		var bau := root.get_meta("bau_node") as StorageChest
		if bau and not bau.vazio() and not bau.derrubar_itens(match_ref):
			_set_notice("Esvazie o baú antes de removê-lo", 1.8)
			return
	root.queue_free()
	candidate_valid = false
	_set_notice("Peça removida: %s" % removed_name, 1.4)


func _set_preview_tint(is_valid: bool) -> void:
	var tint := BLUEPRINT_COLOR if is_valid else INVALID_COLOR
	for visual in preview_root.find_children("*", "MeshInstance3D", true, false):
		if String(visual.name) == "BlueprintGrid":
			continue
		var material := (visual as MeshInstance3D).material_override as StandardMaterial3D
		if material:
			material.albedo_color = tint
	if wheel_ui:
		wheel_ui.queue_redraw()


func place_current() -> bool:
	if current_piece < 0 or not candidate_valid:
		_set_notice("Posição inválida ou recursos insuficientes", 1.6)
		return false
	var piece: Dictionary = PIECES[current_piece]
	if not _has_cost(piece):
		_set_notice("Faltam materiais para esta peça", 1.6)
		return false
	_consume_cost(piece)
	var root := Node3D.new()
	root.name = "Construcao_" + String(piece.id)
	root.global_transform = candidate_transform
	root.set_meta("build_size", Vector3(piece.size.x, piece.size.y, piece.size.z))
	root.set_meta("build_center", float(piece.center))
	root.set_meta("construction_id", String(piece.id))
	root.set_meta("build_profile", String(piece.profile))
	root.add_to_group("player_constructed")
	world_root.add_child(root)
	_add_piece_visual(root, piece, false)
	_add_piece_collision(root, piece)
	if String(piece.id) == "chest":
		_add_chest(root)
	_set_notice("%s construída" % String(piece.name), 1.5)
	return true


## Baú de base: nó StorageChest dentro da peça (o raio de interação acha o baú a partir da colisão da peça).
func _add_chest(root: Node3D, snap := {}) -> StorageChest:
	var chest := StorageChest.new()
	chest.name = "Bau"
	chest.position = Vector3.ZERO
	root.add_child(chest)
	chest.setup_bau(snap)
	root.set_meta("bau_node", chest)
	root.set_meta("bau", true)
	return chest


## Coloca um baú direto em `xf` (sem raycast nem custo): usado por Baus.restaurar() e por bots. snap = conteúdo salvo.
func colocar_bau(xf: Transform3D, snap := {}) -> StorageChest:
	var piece: Dictionary = {}
	for def in PIECES:
		if String(def.id) == "chest":
			piece = def
	if piece.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Construcao_chest"
	world_root.add_child(root)
	root.global_transform = xf
	root.set_meta("build_size", Vector3(piece.size.x, piece.size.y, piece.size.z))
	root.set_meta("build_center", float(piece.center))
	root.set_meta("construction_id", "chest")
	root.set_meta("build_profile", "chest")
	root.add_to_group("player_constructed")
	_add_piece_collision(root, piece)
	return _add_chest(root, snap)


func _add_piece_visual(parent: Node3D, piece: Dictionary, blueprint: bool) -> void:
	var size: Vector3 = piece.size
	var profile := String(piece.profile)
	if profile == "chest" and not blueprint:
		return   # o baú tem visual próprio (StorageChest), criado em _add_chest
	var boxes: Array[Dictionary] = _profile_boxes(profile, size, float(piece.center))
	for part in boxes:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part.size
		mi.mesh = box
		mi.position = part.position
		mi.material_override = _blueprint_material() if blueprint else _build_material(String(piece.id))
		parent.add_child(mi)
	if profile == "door" and not blueprint:
		_add_operable_door(parent, size)


func _profile_boxes(profile: String, size: Vector3, center_y: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match profile:
		"slab", "wall", "pillar", "chest":
			out.append({"size": size, "position": Vector3(0, center_y, 0)})
		"window":
			var opening_w := 1.5
			var opening_bottom := .9
			var opening_h := 1.1
			var side_w := (size.x - opening_w) * .5
			out.append({"size": Vector3(side_w, size.y, size.z), "position": Vector3(-size.x * .5 + side_w * .5, center_y, 0)})
			out.append({"size": Vector3(side_w, size.y, size.z), "position": Vector3(size.x * .5 - side_w * .5, center_y, 0)})
			out.append({"size": Vector3(opening_w, opening_bottom, size.z), "position": Vector3(0, opening_bottom * .5, 0)})
			out.append({"size": Vector3(opening_w, size.y - opening_bottom - opening_h, size.z), "position": Vector3(0, opening_bottom + opening_h + (size.y - opening_bottom - opening_h) * .5, 0)})
			out.append({"size": Vector3(opening_w, .08, size.z), "position": Vector3(0, opening_bottom, 0)})
		"door":
			var opening_w := 1.3
			var opening_h := 2.2
			var side_w := (size.x - opening_w) * .5
			out.append({"size": Vector3(side_w, size.y, size.z), "position": Vector3(-size.x * .5 + side_w * .5, center_y, 0)})
			out.append({"size": Vector3(side_w, size.y, size.z), "position": Vector3(size.x * .5 - side_w * .5, center_y, 0)})
			out.append({"size": Vector3(opening_w, size.y - opening_h, size.z), "position": Vector3(0, opening_h + (size.y - opening_h) * .5, 0)})
		"stairs":
			var steps := 8
			for i in steps:
				var h := size.y * float(i + 1) / float(steps)
				var z := size.z * .5 - size.z * (float(i) + .5) / float(steps)
				out.append({"size": Vector3(size.x, h, size.z / float(steps)), "position": Vector3(0, h * .5, z)})
	return out


func _add_operable_door(parent: Node3D, size: Vector3) -> void:
	var door := ConstructionDoor.new()
	door.name = "OperableDoor"
	door.system = self
	door.hinge = door
	door.position = Vector3(-.65, .04, size.z * .5 + .06)
	parent.add_child(door)
	var leaf_size := Vector3(1.22, 2.12, .08)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = leaf_size
	mesh.mesh = box
	mesh.position = Vector3(leaf_size.x * .5, leaf_size.y * .5, 0)
	mesh.material_override = _build_material("door")
	door.add_child(mesh)
	var body := AnimatableBody3D.new()
	body.name = "DoorLeafBody"
	body.sync_to_physics = true
	body.collision_layer = Soldier.LAYER_WORLD
	body.collision_mask = Soldier.LAYER_SOLDIER
	door.add_child(body)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = leaf_size
	shape.shape = box_shape
	shape.position = Vector3(leaf_size.x * .5, leaf_size.y * .5, 0)
	body.add_child(shape)
	door.panel_collision = shape
	door.add_to_group("construction_doors")


func _toggle_nearest_door() -> bool:
	if match_ref == null or match_ref.local_player == null:
		return false
	var player: Node3D = match_ref.local_player
	var closest: ConstructionDoor
	var closest_dist := 2.8
	for node in get_tree().get_nodes_in_group("construction_doors"):
		if not is_instance_valid(node):
			continue
		var door := node as ConstructionDoor
		var distance := player.global_position.distance_to(door.global_position)
		if distance < closest_dist:
			closest = door
			closest_dist = distance
	if closest:
		closest.toggle()
		return true
	return false


func _add_piece_collision(parent: Node3D, piece: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "BuildCollision"
	body.collision_layer = Soldier.LAYER_WORLD
	body.collision_mask = Soldier.LAYER_SOLDIER
	parent.add_child(body)
	var profile := String(piece.profile)
	for part in _profile_boxes(profile, piece.size, float(piece.center)):
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = part.size
		cs.shape = shape
		cs.position = part.position
		body.add_child(cs)


func _grid_mesh(width: float, depth: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var half_w := width * .5
	var half_d := depth * .5
	var step := .5
	var count_x := int(round(width / step))
	var count_z := int(round(depth / step))
	for i in count_x + 1:
		var x := -half_w + float(i) * step
		verts.append(Vector3(x, 0, -half_d)); verts.append(Vector3(x, 0, half_d))
	for i in count_z + 1:
		var z := -half_d + float(i) * step
		verts.append(Vector3(-half_w, 0, z)); verts.append(Vector3(half_w, 0, z))
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _blueprint_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = BLUEPRINT_COLOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_material(piece_id: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = .85
	mat.albedo_color = STONE_MAT if piece_id == "foundation" else WOOD_MAT
	return mat


func _has_cost(piece: Dictionary) -> bool:
	if FREE_BUILD_MODE:
		return true
	if match_ref.br_bag == null:
		return false
	for id in piece.cost:
		if _material_count(String(id)) < int(piece.cost[id]):
			return false
	return true


func _consume_cost(piece: Dictionary) -> void:
	if FREE_BUILD_MODE:
		return
	for id in piece.cost:
		var remaining := int(piece.cost[id])
		if remaining <= 0:
			continue
		for item in match_ref.br_bag.items.duplicate(true):
			if String(item.id) != String(id):
				continue
			var take := mini(remaining, int(item.qty))
			match_ref.br_bag.remove_item(int(item.uid), take)
			remaining -= take
			if remaining <= 0:
				break


func _material_count(id: String) -> int:
	var total := 0
	if match_ref.br_bag:
		for item in match_ref.br_bag.items:
			if String(item.id) == id:
				total += int(item.qty)
	return total


func _cost_text(piece: Dictionary) -> String:
	if FREE_BUILD_MODE:
		return "GRÁTIS"
	var cost: Dictionary = piece.cost
	return "MADEIRA %d   •   PEDRA %d" % [int(cost.get("wood", 0)), int(cost.get("stone", 0))]


func _stock_text() -> String:
	return "Madeira %d   •   Pedra %d" % [_material_count("wood"), _material_count("stone")]


func _overlaps_constructed(pos: Vector3, piece: Dictionary) -> bool:
	var candidate_basis := Basis(Vector3.UP, float(yaw_step) * PI * .5)
	var candidate_boxes := _profile_boxes(String(piece.profile), piece.size, float(piece.center))
	for node in get_tree().get_nodes_in_group("player_constructed"):
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var other := node as Node3D
		var other_size: Vector3 = other.get_meta("build_size", Vector3.ZERO)
		if other_size == Vector3.ZERO:
			continue
		var other_id := String(other.get_meta("construction_id", ""))
		var other_profile := String(other.get_meta("build_profile", ""))
		if other_profile.is_empty():
			for definition in PIECES:
				if String(definition.id) == other_id:
					other_profile = String(definition.profile)
					break
		if other_profile.is_empty():
			other_profile = "slab"
		var other_boxes := _profile_boxes(other_profile, other_size, float(other.get_meta("build_center", other_size.y * .5)))
		var other_yaw := posmod(roundi(other.rotation.y / (PI * .5)), 4)
		var other_basis := Basis(Vector3.UP, float(other_yaw) * PI * .5)
		for candidate_box in candidate_boxes:
			var candidate_center: Vector3 = pos + candidate_basis * candidate_box.position
			var candidate_size: Vector3 = _box_size_at_yaw(candidate_box.size, yaw_step)
			for other_box in other_boxes:
				var other_center: Vector3 = other.global_position + other_basis * other_box.position
				var other_world_size: Vector3 = _box_size_at_yaw(other_box.size, other_yaw)
				var overlap_x := (candidate_size.x + other_world_size.x) * .5 - absf(candidate_center.x - other_center.x)
				var overlap_y := (candidate_size.y + other_world_size.y) * .5 - absf(candidate_center.y - other_center.y)
				var overlap_z := (candidate_size.z + other_world_size.z) * .5 - absf(candidate_center.z - other_center.z)
				# Ignore only the tiny shared seam at perpendicular wall corners and
				# slab-to-wall joints; real volumetric overlap still blocks placement.
				if overlap_x > .12 and overlap_y > .025 and overlap_z > .12:
					return true
	return false


func _box_size_at_yaw(local_size: Vector3, quarter_turns: int) -> Vector3:
	if posmod(quarter_turns, 2) == 1:
		return Vector3(local_size.z, local_size.y, local_size.x)
	return local_size


func _set_notice(text: String, seconds: float) -> void:
	notice = text
	notice_time = seconds
	if wheel_ui:
		wheel_ui.queue_redraw()
