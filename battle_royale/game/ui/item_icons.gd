class_name ItemIcons
extends RefCounted
## Ícones de itens do inventário/hotbar. Itens simples são desenhados em código (polígonos low poly);
## armas viram miniaturas renderizadas uma vez a partir dos .glb (cache em memória, sem custo por quadro).

const WEAPON_MODELS := {
	"ak47": "res://assets/models/weapons/ak47.glb",
	"m4": "res://assets/models/weapons/m4.glb",
	"glock": "res://assets/models/weapons/pistol.glb",
	"usp": "res://assets/models/weapons/pistol_ct.glb",
	"knife": "res://assets/models/weapons/knife.glb",
	"uzi": "res://assets/models/weapons/wf/uzi.glb",
	"m249": "res://assets/models/weapons/wf/m249.glb",
	"m107": "res://assets/models/weapons/wf/m107.glb",
	"mosin": "res://assets/models/weapons/wf/mosin.glb",
	"acog": "res://assets/models/weapons/wf/acog.glb",
	"reddot": "res://assets/models/weapons/wf/reddot.glb",
	"grenade": "res://assets/models/weapons/wf/rgd5.glb",
}
const DARK_MODELS := ["m4", "glock", "usp"]
const ICON_SIZE := Vector2i(384, 192)

static var textures: Dictionary = {}
static var _renderer: Node
static var _ready_callbacks: Array[Callable] = []


## Inicia (uma vez) a renderização das miniaturas das armas. Seguro em headless (não faz nada).
static func request() -> void:
	if _renderer != null and is_instance_valid(_renderer):
		return
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_renderer = IconRenderer.new()
	_renderer.name = "ItemIconRenderer"
	tree.root.add_child.call_deferred(_renderer)


static func when_ready(cb: Callable) -> void:
	if textures.size() >= WEAPON_MODELS.size():
		cb.call()
	else:
		_ready_callbacks.append(cb)
		request()


static func _notify_ready() -> void:
	var cbs := _ready_callbacks.duplicate()
	_ready_callbacks.clear()
	for cb: Callable in cbs:
		if cb.is_valid():
			cb.call()


static func texture_for(id: String) -> Texture2D:
	return textures.get(id)


class IconRenderer extends Node:
	func _ready() -> void:
		_run()

	func _run() -> void:
		await get_tree().process_frame
		for id: String in ItemIcons.WEAPON_MODELS:
			var path: String = ItemIcons.WEAPON_MODELS[id]
			if not ResourceLoader.exists(path):
				continue
			var tex := await _render(path)
			if tex != null:
				ItemIcons.textures[id] = tex
		ItemIcons._notify_ready()
		queue_free()

	func _render(path: String) -> Texture2D:
		var vp := SubViewport.new()
		vp.size = ItemIcons.ICON_SIZE
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.78, 0.8, 0.85)
		env.ambient_light_energy = 1.3
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 35, 0)
		sun.light_energy = 1.3
		vp.add_child(sun)
		var model: Node3D = (load(path) as PackedScene).instantiate()
		var holder := Node3D.new()
		vp.add_child(holder)
		holder.add_child(model)
		var box := _aabb(model, Transform3D.IDENTITY)
		if box.size.z > box.size.x:
			holder.rotation.y = PI * 0.5
			box = holder.transform * box
		var c := box.get_center()
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var aspect := float(ItemIcons.ICON_SIZE.x) / float(ItemIcons.ICON_SIZE.y)
		cam.size = maxf(box.size.x * 1.08, box.size.y * 1.08 * aspect) / aspect
		cam.near = 0.05
		cam.far = 50.0
		vp.add_child(cam)
		cam.position = c + Vector3(0, 0, 5)
		cam.look_at(c)
		cam.current = true
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		vp.queue_free()
		if img == null or img.is_empty():
			return null
		return ImageTexture.create_from_image(img)

	func _aabb(n: Node, xf: Transform3D) -> AABB:
		var out := AABB()
		var has := false
		if n is MeshInstance3D:
			out = xf * (n as MeshInstance3D).get_aabb()
			has = true
		for ch in n.get_children():
			if ch is Node3D:
				var sub := _aabb(ch, xf * (ch as Node3D).transform)
				if sub.size != Vector3.ZERO or sub.position != Vector3.ZERO:
					out = sub if not has else out.merge(sub)
					has = true
		return out


## Desenha o ícone de `id` dentro de `r` (o ícone se ajusta ao menor lado).
static func draw(ci: CanvasItem, id: String, r: Rect2) -> void:
	var tex := texture_for(id)
	if tex != null:
		var inner := r.grow(-3.0)
		var ts := tex.get_size()
		var k := minf(inner.size.x / ts.x, inner.size.y / ts.y)
		var sz := ts * k
		ci.draw_texture_rect(tex, Rect2(inner.get_center() - sz * 0.5, sz), false, Color(2.3, 2.3, 2.3, 1.0) if id in DARK_MODELS else Color(1.45, 1.45, 1.45, 1.0))
		return
	var c := r.get_center()
	var u := minf(r.size.x, r.size.y)
	match id:
		"ammo_762", "ammo_556", "ammo_9mm", "ammo_127":
			_ammo(ci, c, u, id)
		"grenade":
			_grenade(ci, c, u)
		"vest":
			_vest(ci, c, u)
		"plate":
			_plate(ci, c, u)
		"bandagem":
			_bandagem(ci, c, u)
		"kit_medico":
			_kit_medico(ci, c, u)
		"acog":
			_acog(ci, c, u)
		"reddot":
			_reddot(ci, c, u)
		"backpack_small", "backpack_medium", "backpack_large":
			_backpack(ci, c, u, id)
		"knife":
			_knife(ci, c, u)
		"mosin":
			_mosin(ci, r)
		_:
			_generic_gun(ci, c, u, r.size.x)


static func _p(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)


static func _ammo(ci: CanvasItem, c: Vector2, u: float, id: String) -> void:
	var tip := Color("c0703a") if id == "ammo_762" else Color("8fa35f") if id == "ammo_556" else Color("d8c98a")
	var h := u * (0.30 if id == "ammo_9mm" else 0.46)
	var w := u * 0.15
	for i in 3:
		var x := c.x + (i - 1) * u * 0.21
		var y := c.y + (1 - absf(i - 1)) * -u * 0.03
		ci.draw_rect(Rect2(x - w * 0.5, y - h * 0.1, w, h * 0.6), Color("c9a24a"))
		_p(ci, [Vector2(x - w * 0.5, y - h * 0.1), Vector2(x - w * 0.36, y - h * 0.5), Vector2(x + w * 0.36, y - h * 0.5), Vector2(x + w * 0.5, y - h * 0.1)], tip)
		ci.draw_rect(Rect2(x - w * 0.5, y + h * 0.42, w, h * 0.08), Color("8a6c2a"))


static func _grenade(ci: CanvasItem, c: Vector2, u: float) -> void:
	var r := u * 0.26
	var pts: Array = []
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 1.08 + u * 0.05))
	_p(ci, pts, Color("5d6b43"))
	_p(ci, [c + Vector2(-r * 0.9, u * 0.0), c + Vector2(r * 0.9, u * 0.0), c + Vector2(r * 0.8, u * 0.08), c + Vector2(-r * 0.8, u * 0.08)], Color("3f4a2e"))
	ci.draw_rect(Rect2(c.x - u * 0.07, c.y - u * 0.3, u * 0.14, u * 0.11), Color("8c8f86"))
	_p(ci, [c + Vector2(u * 0.05, -u * 0.3), c + Vector2(u * 0.26, -u * 0.25), c + Vector2(u * 0.28, -u * 0.05), c + Vector2(u * 0.22, -u * 0.06), c + Vector2(u * 0.2, -u * 0.22), c + Vector2(u * 0.05, -u * 0.25)], Color("a9aba0"))
	ci.draw_arc(c + Vector2(-u * 0.14, -u * 0.28), u * 0.07, 0, TAU, 12, Color("d9d6c4"), 1.5)


static func _vest(ci: CanvasItem, c: Vector2, u: float) -> void:
	var s := u * 0.5
	_p(ci, [c + Vector2(-s * 0.7, -s), c + Vector2(-s * 0.3, -s), c + Vector2(0, -s * 0.72), c + Vector2(s * 0.3, -s), c + Vector2(s * 0.7, -s),
		c + Vector2(s * 0.85, -s * 0.2), c + Vector2(s * 0.7, s), c + Vector2(-s * 0.7, s), c + Vector2(-s * 0.85, -s * 0.2)], Color("6a7a55"))
	_p(ci, [c + Vector2(-s * 0.5, -s * 0.45), c + Vector2(s * 0.5, -s * 0.45), c + Vector2(s * 0.52, s * 0.65), c + Vector2(-s * 0.52, s * 0.65)], Color("3e4735"))
	_p(ci, [c + Vector2(-s * 0.36, -s * 0.3), c + Vector2(s * 0.36, -s * 0.3), c + Vector2(s * 0.38, s * 0.3), c + Vector2(-s * 0.38, s * 0.3)], Color("566349"))
	ci.draw_line(c + Vector2(-s * 0.5, s * 0.45), c + Vector2(s * 0.5, s * 0.45), Color("a59a70"), 2.0)


## Bandagem: rolo de gaze branco com faixa vermelha e ponta solta.
static func _bandagem(ci: CanvasItem, c: Vector2, u: float) -> void:
	var r := u * 0.3
	var pts: Array = []
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.78))
	_p(ci, pts, Color("e9e6dc"))
	var in_pts: Array = []
	for i in 12:
		var a := TAU * i / 12.0
		in_pts.append(c + Vector2(cos(a) * r * 0.42, sin(a) * r * 0.32))
	_p(ci, in_pts, Color("a7a395"))
	ci.draw_arc(c, r * 0.74, 0.0, TAU, 16, Color("c9c5b6"), 1.2)
	_p(ci, [c + Vector2(-r, -r * 0.1), c + Vector2(r, -r * 0.1), c + Vector2(r * 0.96, r * 0.22), c + Vector2(-r * 0.96, r * 0.22)], Color("d24a3a"))
	_p(ci, [c + Vector2(r * 0.6, r * 0.55), c + Vector2(r * 1.15, r * 0.95), c + Vector2(r * 0.8, r * 1.05), c + Vector2(r * 0.4, r * 0.7)], Color("e9e6dc"))


## Kit médico: maleta branca com cruz vermelha e alça.
static func _kit_medico(ci: CanvasItem, c: Vector2, u: float) -> void:
	var w := u * 0.7
	var h := u * 0.5
	ci.draw_rect(Rect2(c.x - w * 0.22, c.y - h * 0.72, w * 0.44, h * 0.2), Color("4a4f55"))
	ci.draw_rect(Rect2(c.x - w * 0.14, c.y - h * 0.62, w * 0.28, h * 0.1), Color("171a1d"))
	_p(ci, [c + Vector2(-w * 0.5, -h * 0.5), c + Vector2(w * 0.5, -h * 0.5), c + Vector2(w * 0.5, h * 0.5), c + Vector2(-w * 0.5, h * 0.5)], Color("ecebe6"))
	ci.draw_rect(Rect2(c.x - w * 0.5, c.y + h * 0.3, w, h * 0.2), Color("c8c6bd"))
	ci.draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), Color("8c8a82"), false, 1.5)
	var k := h * 0.16
	ci.draw_rect(Rect2(c.x - k * 0.6, c.y - k * 2.2, k * 1.2, k * 4.4), Color("d9372b"))
	ci.draw_rect(Rect2(c.x - k * 2.2, c.y - k * 0.6, k * 4.4, k * 1.2), Color("d9372b"))
	ci.draw_rect(Rect2(c.x - w * 0.42, c.y - h * 0.08, w * 0.06, h * 0.16), Color("8c8a82"))
	ci.draw_rect(Rect2(c.x + w * 0.36, c.y - h * 0.08, w * 0.06, h * 0.16), Color("8c8a82"))


static func _plate(ci: CanvasItem, c: Vector2, u: float) -> void:
	var s := u * 0.34
	_p(ci, [c + Vector2(-s, -s * 1.1), c + Vector2(s, -s * 1.1), c + Vector2(s, s * 0.6), c + Vector2(0, s * 1.2), c + Vector2(-s, s * 0.6)], Color("7b8aa0"))
	_p(ci, [c + Vector2(-s * 0.7, -s * 0.8), c + Vector2(s * 0.7, -s * 0.8), c + Vector2(s * 0.7, s * 0.45), c + Vector2(0, s * 0.9), c + Vector2(-s * 0.7, s * 0.45)], Color("9db0c8"))


static func _acog(ci: CanvasItem, c: Vector2, u: float) -> void:
	_p(ci, [c + Vector2(-u * 0.36, -u * 0.12), c + Vector2(u * 0.3, -u * 0.16), c + Vector2(u * 0.3, u * 0.12), c + Vector2(-u * 0.36, u * 0.1)], Color("4a5056"))
	ci.draw_rect(Rect2(c.x - u * 0.22, c.y + u * 0.1, u * 0.34, u * 0.1), Color("2c3034"))
	ci.draw_circle(c + Vector2(u * 0.3, -u * 0.02), u * 0.15, Color("7cc0ee"))
	ci.draw_circle(c + Vector2(u * 0.3, -u * 0.02), u * 0.06, Color("d8f0ff"))
	ci.draw_rect(Rect2(c.x - u * 0.4, c.y - u * 0.15, u * 0.06, u * 0.27), Color("2c3034"))


static func _reddot(ci: CanvasItem, c: Vector2, u: float) -> void:
	ci.draw_rect(Rect2(c.x - u * 0.34, c.y + u * 0.1, u * 0.6, u * 0.12), Color("2a2d31"))                       # base/trilho
	_p(ci, [c + Vector2(-u * 0.34, u * 0.1), c + Vector2(-u * 0.3, -u * 0.04), c + Vector2(u * 0.12, -u * 0.04), c + Vector2(u * 0.26, u * 0.1)], Color("3d4249"))   # corpo
	ci.draw_rect(Rect2(c.x + u * 0.12, c.y - u * 0.3, u * 0.12, u * 0.4), Color("3d4249"))                         # moldura da janela
	ci.draw_rect(Rect2(c.x + u * 0.16, c.y - u * 0.26, u * 0.04, u * 0.32), Color(0.5, 0.75, 0.9, 0.5))           # vidro
	ci.draw_circle(c + Vector2(u * 0.18, -u * 0.1), u * 0.035, Color("ff3b2e"))


static func _backpack(ci: CanvasItem, c: Vector2, u: float, id: String) -> void:
	var s := u * 0.42
	var col := Color("56694a") if id == "backpack_small" else Color("4d6a52") if id == "backpack_medium" else Color("445c4a")
	_p(ci, [c + Vector2(-s * 0.8, -s * 0.6), c + Vector2(-s * 0.4, -s), c + Vector2(s * 0.4, -s), c + Vector2(s * 0.8, -s * 0.6), c + Vector2(s * 0.9, s), c + Vector2(-s * 0.9, s)], col)
	_p(ci, [c + Vector2(-s * 0.8, -s * 0.6), c + Vector2(s * 0.8, -s * 0.6), c + Vector2(s * 0.7, -s * 0.1), c + Vector2(-s * 0.7, -s * 0.1)], col.darkened(0.25))
	ci.draw_rect(Rect2(c.x - s * 0.5, c.y + s * 0.15, s, s * 0.6), col.darkened(0.35))
	ci.draw_line(c + Vector2(-s * 0.5, -s * 0.1), c + Vector2(-s * 0.5, s), Color("b3a672"), 1.5)
	ci.draw_line(c + Vector2(s * 0.5, -s * 0.1), c + Vector2(s * 0.5, s), Color("b3a672"), 1.5)


static func _knife(ci: CanvasItem, c: Vector2, u: float) -> void:
	_p(ci, [c + Vector2(-u * 0.05, -u * 0.05), c + Vector2(u * 0.4, -u * 0.02), c + Vector2(u * 0.05, u * 0.06)], Color("c4c8cc"))
	ci.draw_rect(Rect2(c.x - u * 0.4, c.y - u * 0.06, u * 0.36, u * 0.1), Color("6b4a2c"))


static func _generic_gun(ci: CanvasItem, c: Vector2, u: float, w: float) -> void:
	var l := minf(w * 0.8, u * 1.6) * 0.5
	ci.draw_rect(Rect2(c.x - l, c.y - u * 0.06, l * 2.0, u * 0.12), Color("3a3d40"))
	ci.draw_rect(Rect2(c.x - l, c.y - u * 0.09, l * 0.5, u * 0.2), Color("7a5a36"))


## Mosin-Nagant: silhueta em código (o .glb não gera miniatura legível).
static func _mosin(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var l := minf(r.size.x * 0.46, r.size.y * 2.4)
	var h := l * 0.07
	ci.draw_rect(Rect2(c.x - l, c.y - h * 0.4, l * 2.0, h), Color("8d9198"))
	_p(ci, [Vector2(c.x - l, c.y - h * 0.6), Vector2(c.x - l * 0.1, c.y - h * 0.6), Vector2(c.x + l * 0.15, c.y + h * 1.6), Vector2(c.x - l * 0.95, c.y + h * 1.8)], Color("9a6a3a"))
	ci.draw_rect(Rect2(c.x - l * 0.1, c.y - h * 0.9, l * 0.3, h * 1.3), Color("555a60"))
	ci.draw_line(Vector2(c.x + l * 0.2, c.y - h * 0.2), Vector2(c.x + l * 0.95, c.y - h * 0.2), Color("c0c4ca"), 1.5)
	ci.draw_rect(Rect2(c.x - l * 0.95, c.y + h * 1.7, l * 0.08, h * 0.6), Color("3a2a1a"))
