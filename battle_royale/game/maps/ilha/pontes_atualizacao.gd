extends Node3D
## Pontes sobre o Rio Tauá (decisões autorais em maps/ilha/cenario_atualizacao.json -> "pontes"):
## centro, direção (graus no plano do design, x leste / y norte), comprimento, largura e altura do tabuleiro em cada
## cabeceira (terreno + 5 cm: sem degrau na entrada). Este script só monta: tabuleiro inclinado com colisão de caixa,
## vigas, encontros enterrados nas margens, pilares até o leito e guarda-corpo (Road_Barrier_01 do pack nas de concreto,
## corrimão de madeira com colisão nas passarelas).

var _mat := {}


func _m(nome: String, cor: Color) -> StandardMaterial3D:
	if not _mat.has(nome):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.95
		_mat[nome] = m
	return _mat[nome]


func build(detalhes: Node, pontes: Array) -> int:
	var n := 0
	for p in pontes:
		_ponte(detalhes, p)
		n += 1
	return n


func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, colide: bool, corpo: StaticBody3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.visibility_range_end = 400.0
	pai.add_child(mi)
	if colide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = tam
		cs.shape = bs
		corpo.add_child(cs)
		cs.global_transform = mi.global_transform


func _ponte(detalhes: Node, p: Dictionary) -> void:
	var L := float(p.comprimento_m)
	var w := float(p.largura_m)
	var z0 := float(p.z_cabeceiras[0])
	var z1 := float(p.z_cabeceiras[1])
	var agua := float(p.agua_m)
	var concreto := String(p.tipo) == "concreto"
	var raiz := Node3D.new()
	raiz.name = "Ponte_" + String(p.nome).replace(" ", "_")
	raiz.set_meta("atualizacao", true)
	add_child(raiz)
	raiz.position = Vector3(float(p.centro[0]), (z0 + z1) * 0.5, -float(p.centro[1]))
	raiz.rotation.y = deg_to_rad(float(p.direcao_deg))          # +X local = direção da ponte
	var tab := Node3D.new()                                      # plano do tabuleiro: topo em y=0, sobe de z0 para z1
	tab.rotation.z = atan2(z1 - z0, L)
	raiz.add_child(tab)
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	tab.add_child(corpo)
	var piso := _m("concreto", Color("B9B4A8")) if concreto else _m("tabua", Color("8A6040"))
	var viga := _m("concreto_esc", Color("8E8A80")) if concreto else _m("tora", Color("5E4430"))
	var esp := 0.45 if concreto else 0.3
	var Lr := L / cos(tab.rotation.z)
	# tabuleiro (colisão fiel = a própria laje) e vigas laterais
	_caixa(tab, Vector3(Lr, esp, w), Vector3(0, -esp * 0.5, 0), piso, true, corpo)
	_caixa(tab, Vector3(Lr, 0.5, 0.35), Vector3(0, -esp - 0.25, w * 0.5 - 0.2), viga, false, corpo)
	_caixa(tab, Vector3(Lr, 0.5, 0.35), Vector3(0, -esp - 0.25, -w * 0.5 + 0.2), viga, false, corpo)
	# encontros: blocos sob as cabeceiras, enterrados no barranco
	for s in [-1.0, 1.0]:
		_caixa(tab, Vector3(2.4, 3.0, w + 0.6), Vector3(s * (Lr * 0.5 - 1.2), -esp - 1.5, 0), viga, false, corpo)
	# pilares do leito até a viga (nível da água - 1,6 m de leito)
	for px in p.get("pilares_x", []):
		var topo_y := lerpf(z0, z1, (float(px) + L * 0.5) / L) - esp - 0.5
		var base_y := agua - 2.0
		var h := topo_y - base_y
		if h <= 0.2:
			continue
		var c := Vector3(float(px), (topo_y + base_y) * 0.5 - raiz.position.y, 0)
		if concreto:
			_caixa(raiz, Vector3(1.0, h, w - 1.2), c, viga, true, _corpo_raiz(raiz))
		else:
			for zz in [-w * 0.5 + 0.3, w * 0.5 - 0.3]:
				_caixa(raiz, Vector3(0.3, h, 0.3), c + Vector3(0, 0, zz), viga, true, _corpo_raiz(raiz))
	# guarda-corpo
	if concreto and detalhes.has_method("_cena"):
		var sc: PackedScene = detalhes._cena(String(p.guarda_corpo))
		if sc:
			var k := int(floor(Lr / 2.5))
			var ini := -k * 2.5 * 0.5 + 1.25
			for i in k:
				for s in [-1.0, 1.0]:
					var b: Node3D = sc.instantiate()
					tab.add_child(b)
					b.position = Vector3(ini + i * 2.5, 0.0, s * (w * 0.5 - 0.3))
					for g in b.find_children("*", "GeometryInstance3D", true, false):
						(g as GeometryInstance3D).visibility_range_end = 260.0
						(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var post := _m("tora", Color("5E4430"))
		for s in [-1.0, 1.0]:
			var zz: float = s * (w * 0.5 - 0.06)
			var np := int(ceil(Lr / 2.0))
			for i in np + 1:
				_caixa(tab, Vector3(0.12, 1.05, 0.12), Vector3(-Lr * 0.5 + i * Lr / np, 0.52, zz), post, false, corpo)
			_caixa(tab, Vector3(Lr, 0.08, 0.1), Vector3(0, 1.0, zz), post, false, corpo)
			_caixa(tab, Vector3(Lr, 0.06, 0.08), Vector3(0, 0.55, zz), post, false, corpo)
			# colisão contínua do corrimão (não deixa cair no rio pela lateral)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(Lr, 1.1, 0.12)
			cs.shape = bs
			cs.position = Vector3(0, 0.55, zz)
			corpo.add_child(cs)


func _corpo_raiz(raiz: Node3D) -> StaticBody3D:
	var c := raiz.get_node_or_null("ColisaoPilares") as StaticBody3D
	if c == null:
		c = StaticBody3D.new()
		c.name = "ColisaoPilares"
		raiz.add_child(c)
	return c
