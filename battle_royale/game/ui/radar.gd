class_name Radar
extends Control
## Rotating minimap: map overview image + teammates, spotted enemies, bomb.

var match_ref: Match
var tex: Texture2D
var world_rect := Rect2(-60, -60, 120, 120)   # x/z do mundo cobertos pela imagem
var zoom := 0.55                               # fração do mapa visível


func setup(m: Match) -> void:
	match_ref = m
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map := m.map
	if map and map.has_meta("radar_texture"):
		var p: String = map.get_meta("radar_texture")
		if ResourceLoader.exists(p):
			tex = load(p)
	if map and map.has_meta("radar_rect"):
		world_rect = map.get_meta("radar_rect")


func _process(_dt: float) -> void:
	queue_redraw()


func _w2r(p: Vector3, center: Vector3, yaw: float, scale: float) -> Vector2:
	var d := Vector2(p.x - center.x, p.z - center.z)
	d = d.rotated(yaw)
	return size * 0.5 + d * scale


func _draw() -> void:
	var lp := match_ref.local_player
	var view: Soldier = lp
	if lp and lp.controller and lp.controller.has_method("view_target"):
		view = lp.controller.view_target()
	var rad := size.x * 0.5
	draw_circle(size * 0.5, rad, Color(0.04, 0.035, 0.03, 0.72))
	if view == null:
		return
	var center := view.global_position
	var yaw := view.yaw
	var scale := size.x / (world_rect.size.x * zoom)
	if tex:
		var xf := Transform2D()
		var tl := _w2r(Vector3(world_rect.position.x, 0, world_rect.position.y), center, yaw, scale)
		xf = Transform2D(yaw, Vector2(scale, scale) * world_rect.size / Vector2(tex.get_size()), 0.0, tl)
		draw_set_transform_matrix(xf)
		draw_texture(tex, Vector2.ZERO, Color(1, 1, 1, 0.9))
		draw_set_transform_matrix(Transform2D())
	if match_ref.has_method("zona_radar"):
		# BR: zona atual (azul) e próxima (branca)
		var z: Array = match_ref.zona_radar()
		var ca := _w2r(Vector3(z[0].x, 0, z[0].y), center, yaw, scale)
		draw_arc(ca, maxf(float(z[1]) * scale, 1.0), 0.0, TAU, 96, Color(0.3, 0.65, 1.0, 0.95), 2.0)
		var cp := _w2r(Vector3(z[2].x, 0, z[2].y), center, yaw, scale)
		draw_arc(cp, maxf(float(z[3]) * scale, 1.0), 0.0, TAU, 96, Color(1, 1, 1, 0.9), 1.5)
	var team := view.team
	for s in match_ref.soldiers:
		if not s.alive:
			if s.team == team and s.deaths > 0 and not match_ref.is_ffa():
				var pd := _w2r(s.global_position, center, yaw, scale)
				if pd.distance_to(size * 0.5) < rad - 4:
					draw_line(pd - Vector2(4, 4), pd + Vector2(4, 4), Color(0.9, 0.2, 0.2, 0.8), 2)
					draw_line(pd - Vector2(-4, 4), pd + Vector2(-4, 4), Color(0.9, 0.2, 0.2, 0.8), 2)
			continue
		var visible_enemy := false
		if not match_ref.is_ally(s, view):
			# inimigo aparece se algum aliado o vê (aproximação: está na memória de um bot aliado ou atirou há pouco)
			visible_enemy = (match_ref.clock - s.last_shot) < 1.0 and s.t > 0.0
			for mate in ([] if match_ref.is_ffa() else match_ref.team_members(team, true)):
				if mate.is_bot and mate.controller.target == s:
					visible_enemy = true
					break
			if not visible_enemy:
				continue
		var p := _w2r(s.global_position, center, yaw, scale)
		if p.distance_to(size * 0.5) > rad - 5:
			p = size * 0.5 + (p - size * 0.5).normalized() * (rad - 5)
		var col := UIStyle.team_color(s.team)
		if s == view:
			var tri := PackedVector2Array([p + Vector2(0, -8), p + Vector2(5.5, 6), p + Vector2(-5.5, 6)])
			draw_colored_polygon(tri, Color.WHITE)
		else:
			draw_circle(p, 5.5, Color(0, 0, 0, 0.6))
			draw_circle(p, 4.2, col if s.team == team else UIStyle.DANGER)
			if s.is_carrying_bomb and s.team == team:
				draw_circle(p, 2.0, UIStyle.DANGER)
	var bomb := match_ref.planted_bomb()
	var bpos: Variant = null
	if bomb:
		bpos = bomb.global_position
	elif team == 0 and match_ref.dropped_bomb():
		bpos = match_ref.dropped_bomb().global_position
	if bpos != null:
		var bp := _w2r(bpos, center, yaw, scale)
		if bp.distance_to(size * 0.5) > rad - 6:
			bp = size * 0.5 + (bp - size * 0.5).normalized() * (rad - 6)
		var blink := fmod(match_ref.clock, 0.8) < 0.5 or bomb == null
		if blink:
			draw_rect(Rect2(bp - Vector2(5, 4), Vector2(10, 8)), UIStyle.DANGER)
	draw_arc(size * 0.5, rad - 1, 0, TAU, 64, Color(1, 1, 1, 0.18), 2.0)
	var callout := match_ref.callout_at(view.global_position)
	if callout != "":
		var f := UIStyle.font(600)
		var w := f.get_string_size(callout, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
		draw_string(f, Vector2(size.x * 0.5 - w * 0.5, size.y - 10), callout, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.TEXT)
