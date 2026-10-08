extends Node3D
## Three authored, open-sided roadside refuges. Shared simple meshes, faithful
## box collision, clear doorway and ground access; no generated world at runtime.

const SITES := [
	{"id": "pomar", "pos": Vector2(-231, -340), "yaw": 15.0, "title": "POMAR DO TAUÁ", "next": "FAZENDA  •  130 m  →", "tier": "baixo"},
	{"id": "vale", "pos": Vector2(-34, -176), "yaw": 0.0, "title": "REFÚGIO DO VALE", "next": "REPRESA  •  120 m  ↖", "tier": "medio"},
	{"id": "vigia", "pos": Vector2(200, 268), "yaw": 0.0, "title": "POSTO DA MATA", "next": "QUARTEL  •  120 m  →", "tier": "alto"},
]
var terrain: IlhaTerrain
var shelters: Array[Node3D] = []
var _materials: Dictionary = {}

func build(t: IlhaTerrain) -> void:
	terrain = t
	for site in SITES:
		var root := StaticBody3D.new()
		root.name = "Refugio_" + String(site.id)
		var p: Vector2 = site.pos
		root.position = Vector3(p.x, t.height_world(p.x, -p.y), -p.y)
		root.rotation.y = deg_to_rad(float(site.yaw))
		root.add_to_group("gpt_refugio")
		add_child(root)
		shelters.append(root)
		# Raised deck is only 14 cm. Four large entrances, no walls or convex hull over the shelter.
		_box(root, Vector3(7.2, .14, 5.8), Vector3(0,.07,0), "687063", true)
		for x in [-3.25,3.25]:
			for z in [-2.55,2.55]:
				_box(root, Vector3(.19,2.85,.19), Vector3(x,1.56,z), "68513B", true)
		_box(root, Vector3(7.7,.16,6.3), Vector3(0,3.03,0), "52666A", true)
		# Corrugated roof ribs and a warm fascia make each refuge readable against the grove.
		for x in [-3.4,-2.55,-1.7,-.85,0,.85,1.7,2.55,3.4]:
			_box(root, Vector3(.08,.08,6.3), Vector3(x,3.15,0), "6B8080", false)
		_box(root, Vector3(7.5,.27,.14), Vector3(0,2.88,3.07), "AE8250", false)
		_box(root, Vector3(2.4,.16,.62), Vector3(-1.7,.61,-1.75), "9A7550", true)
		for x in [-2.6,-.8]:
			_box(root, Vector3(.16,.48,.52), Vector3(x,.38,-1.75), "5A4B3B", true)
		# Back panel covers only one bay; doorway remains 6 m wide.
		_box(root, Vector3(2.8,1.25,.12), Vector3(1.55,1.12,-2.5), "7B6E51", true)
		_box(root, Vector3(.55,.6,.15), Vector3(2.2,1.38,-2.37), "DAE0D0", false)
		_box(root, Vector3(.3,.08,.02), Vector3(2.2,1.38,-2.28), "B95640", false)
		_box(root, Vector3(.08,.3,.02), Vector3(2.2,1.38,-2.27), "B95640", false)
		_label(root, String(site.title), Vector3(0,2.88,3.16), 31, .009)
		# A flat authorial pad blends into the terrain (prepared by rebuild_gpt.py).
		var sign := StaticBody3D.new()
		sign.name = "Placa"
		sign.position = Vector3(-4.9,0,3.0)
		root.add_child(sign)
		_box(sign, Vector3(.16,2.5,.16),Vector3(0,1.25,0),"68513B",true)
		_box(sign, Vector3(3.7,.67,.13),Vector3(0,2.03,0),"345052",false)
		_label(sign, String(site.next), Vector3(0,2.03,.09), 28,.0065)
		root.set_meta("loot_tier", site.tier)
		root.set_meta("loot_local", Vector3(1.3,.16,-1.25))
	print("GPT_REFUGIOS count=", shelters.size())

func _material(hex: String) -> StandardMaterial3D:
	if not _materials.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = .95
		_materials[hex] = m
	return _materials[hex]

func _box(root: Node3D, size: Vector3, pos: Vector3, color: String, collide: bool) -> void:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = _material(color)
	m.position = pos
	m.visibility_range_end = 260.0
	root.add_child(m)
	if collide:
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		c.shape = shape
		c.position = pos
		root.add_child(c)
	else:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _label(root: Node3D, text: String, pos: Vector3, font: int, pixel: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font
	l.pixel_size = pixel
	l.position = pos
	l.modulate = Color("F2E7C9")
	l.outline_size = 0
	l.no_depth_test = false
	l.visibility_range_end = 90.0
	root.add_child(l)
