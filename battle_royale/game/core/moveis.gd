class_name Moveis
## Mobília dos interiores. tools/interior.py / tools/mobiliar_casa.py gravam a colocação de cada móvel por modelo de prédio em
## maps/ilha/moveis.json:
##   {"<modelo do prédio>": [{"m": "cama_a", "pos": [x, y, z], "rot_y": graus, "esc": [sx, sy, sz]}, ...]}  (coordenadas locais do prédio)
## O nome "m" continua sendo o do móvel ANTIGO (caixa de referência: AABB antiga x esc, frente = +Z local). DEPARA troca cada um
## pelo modelo do pack "props interiores" (Cute Furniture, tools/importar_props_interiores.py -> assets/models/atualizacao/interiores),
## encaixado DENTRO da caixa antiga (encostado no fundo, no piso): a colisão nunca cresce, então portas/cômodos continuam livres
## (tests/casa_alcance.tscn). Um "m" que já é nome do pack (ex.: "Kitchen_D_09") usa "tam" [x,y,z] como caixa (ou o tamanho nativo).
## Material: UM StandardMaterial3D compartilhado com Textures_4.png (filtro nearest) para todos os móveis do pack.
## instalar() cria, dentro do StaticBody do prédio, um MeshInstance3D por peça (malha compartilhada, sem sombra, some a 35 m),
## uma caixa de colisão por móvel e, nos móveis com saque (LOOTAVEIS), um BRMovel.

const JSON_PATH := "res://maps/ilha/moveis.json"
const DIR := "res://assets/models/moveis/"
const DIR_NOVO := "res://assets/models/atualizacao/interiores/"
const ATLAS := "res://assets/models/atualizacao/interiores/Textures_4.png"
const DIST_VISIVEL := 35.0
const SEM_COLISAO := ["abajur", "radio", "radio_b", "despertador", "livros", "garrafa", "lata", "bolo", "tigela", "luminaria", "vaso_flor", "leite", "quadro_a", "quadro_b", "quadro_c", "telefone", "prato_comida", "prato", "escorredor", "ventilador_teto", "lixeira_b", "saco_lixo",
	"Light_05", "Picture_08", "Picture_17", "Picture_21", "Plants_05", "Book_03", "Book_08", "Mixer_08", "Computer_01", "Cutting_board_02", "Microwave_01", "Toothbrush_01", "Toothpaste_01", "Paper_01", "Paper_02", "Toy_02", "Toy_03", "GameConsole_01", "Utensils_01"]
## móveis com saque: família do modelo do pack (nome sem o número final). Só em ~65% deles (índice no JSON, determinístico),
## a não ser que a entrada traga "loot": true/false.
const LOOTAVEIS := ["Closet", "Kitchen_D", "Nightstand", "Fridge", "Work_Table", "Wash_Basin"]
const PROP_LOOT := 0.65
## prédios de trabalho: mesa vira bancada com computador (com saque) e cadeira vira cadeira de escritório
const ESCRITORIOS := ["escritorio_a", "comando_a", "casa_radio_a", "casa_operador_a", "casa_gerador_a"]
## de-para: antigo -> {n: modelo novo, rep: cópias lado a lado, alt: altura máx. da peça principal, extra: [[modelo, fx, fz]] em cima}
## (fx, fz em fração da caixa: 0 = centro, -0.5 = esquerda/fundo). Antigos sem entrada continuam (fogão, rádio, telefone, ventilador).
const DEPARA := {
	"armario_alto_a": {"n": "Kitchen_D_10"},
	"armario_baixo_a": {"n": "Kitchen_D_09"},
	"armario_baixo_b": {"n": "Kitchen_D_08"},
	"guarda_roupa_a": {"n": "Closet_02"},
	"guarda_roupa_b": {"n": "Closet_02"},
	"comoda_a": {"n": "Kitchen_D_10"},
	"comoda_b": {"n": "Kitchen_D_01"},
	"comoda_c": {"n": "Nightstand_02"},
	"comoda_d": {"n": "Kitchen_D_10"},
	"comoda_e": {"n": "Kitchen_D_01"},
	"comoda_f": {"n": "Nightstand_02"},
	"cristaleira_a": {"n": "Closet_01"},
	"estante_a": {"n": "Closet_01", "rep": 2, "extra": [["Book_08", -0.25, 0.0]]},
	"estante_b": {"n": "Closet_01", "rep": 2, "extra": [["Book_08", -0.25, 0.0]]},
	"estante_c": {"n": "Closet_01", "rep": 2, "extra": [["Book_08", -0.25, 0.0]]},
	"estante_d": {"n": "Closet_01", "rep": 2, "extra": [["Book_08", -0.25, 0.0]]},
	"estante_baixa": {"n": "Kitchen_D_10"},
	"geladeira_a": {"n": "Fridge_01"},
	"pia_a": {"n": "Kitchen_D_09", "alt": 0.9, "extra": [["Mixer_08", 0.0, -0.3], ["Cutting_board_02", 0.3, 0.0]]},
	"mesa_a": {"n": "Kitchen_Table_09"}, "mesa_b": {"n": "Kitchen_Table_09"}, "mesa_c": {"n": "Kitchen_Table_09"},
	"mesa_d": {"n": "Kitchen_Table_09"}, "mesa_e": {"n": "Kitchen_Table_09"},
	"cadeira_a": {"n": "Chair_17"}, "cadeira_b": {"n": "Chair_17"}, "cadeira_c": {"n": "Chair_17"},
	"sofa_a": {"n": "Couch_08"}, "sofa_b": {"n": "Couch_08"}, "sofa_c": {"n": "Couch_08"}, "sofa_d": {"n": "Couch_11"},
	"poltrona_a": {"n": "Armchair_18"}, "poltrona_b": {"n": "Armchair_18"}, "poltrona_c": {"n": "Armchair_18"}, "poltrona_d": {"n": "Armchair_02"},
	"cama_a": {"n": "Bed_07"}, "cama_b": {"n": "Bed_02"}, "cama_c": {"n": "Bed_07"}, "cama_d": {"n": "Bed_07"},
	"abajur": {"n": "Light_05"},
	"quadro_a": {"n": "Picture_08"}, "quadro_b": {"n": "Picture_21"}, "quadro_c": {"n": "Picture_17"},
	"vaso_flor": {"n": "Plants_15"},
	"livros": {"n": "Book_03"},
	"despertador": {"n": "Clock_03"},
}
const K_XZ := 1.3      # deformação máxima entre largura/profundidade (relativa ao menor fator)
const K_Y := 1.7       # idem para a altura

static var _dados: Dictionary = {}
static var _lido := false
static var _malhas: Dictionary = {}          # m -> [Mesh, Transform3D local, AABB]
static var _mat_cor: StandardMaterial3D
static var _mat_vidro: StandardMaterial3D


static func _ler() -> void:
	if _lido:
		return
	_lido = true
	var d = JsonSeguro.ler(JSON_PATH, TYPE_DICTIONARY)
	if d != null:
		_dados = d


static func e_novo(m: String) -> bool:
	return ResourceLoader.exists(DIR_NOVO + m + ".glb")


static func _materiais() -> void:
	if _mat_cor != null:
		return
	_mat_cor = StandardMaterial3D.new()
	_mat_cor.resource_name = "MoveisAtlas"
	_mat_cor.albedo_texture = load(ATLAS)
	_mat_cor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat_cor.roughness = 0.9
	_mat_vidro = StandardMaterial3D.new()
	_mat_vidro.resource_name = "MoveisVidro"
	_mat_vidro.albedo_color = Color(0.72, 0.86, 0.92)
	_mat_vidro.roughness = 0.2
	_mat_vidro.metallic_specular = 0.8


static func _malha(m: String) -> Array:
	if _malhas.has(m):
		return _malhas[m]
	var r: Array = []
	var novo := e_novo(m)
	var p := (DIR_NOVO if novo else DIR) + m + ".glb"
	if ResourceLoader.exists(p):
		var sc: Node3D = (load(p) as PackedScene).instantiate()
		var mis := sc.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var mi := mis[0] as MeshInstance3D
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != sc:          # transformação da malha dentro da cena do glb
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			if novo:
				_materiais()
				for i in mi.mesh.get_surface_count():
					var sm := mi.mesh.surface_get_material(i)
					var vidro := sm != null and String(sm.resource_name).to_lower().contains("glass")
					mi.mesh.surface_set_material(i, _mat_vidro if vidro else _mat_cor)
			else:
				_chapar(mi)
			r = [mi.mesh, xf, xf * mi.mesh.get_aabb()]
		sc.free()
	_malhas[m] = r
	return r


static var _chapadas := {}


## Texturas fotográficas viram paleta low poly: reduzidas a 10x10 px com filtro "nearest" (blocos de cor chapada),
## cores um pouco mais saturadas — o mesmo traço do resto do mapa.
static func _chapar(mi: MeshInstance3D, lado := 10, suave := false) -> void:
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
		if mat == null or mat.albedo_texture == null:
			continue
		if not _chapadas.has(mat):
			var img := mat.albedo_texture.get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			img.resize(lado, lado, Image.INTERPOLATE_BILINEAR)
			for y in lado:
				for x in lado:
					var c := img.get_pixel(x, y)
					c.s = minf(1.0, c.s * 1.15)
					img.set_pixel(x, y, c)
			var m2 := mat.duplicate() as BaseMaterial3D
			m2.albedo_texture = ImageTexture.create_from_image(img)
			m2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if suave else BaseMaterial3D.TEXTURE_FILTER_NEAREST   # casa: transição suave (sem mosaico ruidoso)
			m2.roughness = 1.0
			_chapadas[mat] = m2
		mi.mesh.surface_set_material(i, _chapadas[mat])


## Família do modelo do pack: "Kitchen_D_09" -> "Kitchen_D", "Closet_02" -> "Closet".
static func familia(m: String) -> String:
	var partes := m.rsplit("_", true, 1)
	return partes[0] if partes.size() == 2 and partes[1].is_valid_int() else m


## Escolhe o modelo novo para uma entrada antiga (depende do prédio e do tamanho). Devolve {} = manter o antigo.
static func _regra(m: String, modelo: String, caixa: AABB) -> Dictionary:
	if e_novo(m):
		return {"n": m}
	if not DEPARA.has(m):
		return {}
	var r: Dictionary = DEPARA[m]
	var tipo := m.rsplit("_", true, 1)[0]
	if tipo == "mesa":
		if modelo in ESCRITORIOS:
			return {"n": "Work_Table_06", "extra": [["Computer_01", 0.0, -0.1]], "loot": true}
		if caixa.size.y < 0.55:
			return {"n": "Coffee_Table_03"}
	if tipo == "cadeira" and modelo in ESCRITORIOS:
		return {"n": "Chair_PC_04"}
	return r


## Fatores de escala que encaixam o tamanho `t` (nativo) dentro de `alvo`, deformando no máximo K_XZ / K_Y.
static func _encaixe(t: Vector3, alvo: Vector3) -> Vector3:
	var r := alvo / t.max(Vector3(0.001, 0.001, 0.001))
	var g := minf(r.x, r.z)
	return Vector3(minf(r.x, g * K_XZ), minf(r.y, g * K_Y), minf(r.z, g * K_XZ))


## Quantos móveis o modelo de prédio tem registrados.
static func contar(modelo: String) -> int:
	_ler()
	return (_dados.get(modelo, []) as Array).size()


## Peça visual: malha `dados` com a AABB nativa encaixada na caixa `cx` (quadro local da entrada; fundo = z mín.), piso = y mín.
## Devolve a AABB final ocupada (quadro local da entrada).
static func _peca(raiz: Node3D, base: Transform3D, dados: Array, cx: AABB, alt := 0.0) -> AABB:
	var bb: AABB = dados[2]
	var alvo := cx.size
	if alt > 0.0:
		alvo.y = minf(alvo.y, alt)
	var s := _encaixe(bb.size, alvo)
	var tam := bb.size * s
	var ancora := Vector3(bb.get_center().x, bb.position.y, bb.position.z)
	var destino := Vector3(cx.get_center().x, cx.position.y, cx.position.z)
	var xf := base * Transform3D(Basis.from_scale(s), destino - ancora * s) * (dados[1] as Transform3D)
	if _coletando:
		_coleta.append([dados[0], xf])
		return AABB(Vector3(destino.x - tam.x * 0.5, destino.y, destino.z), tam)
	var mi := MeshInstance3D.new()
	mi.mesh = dados[0]
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DIST_VISIVEL
	mi.visibility_range_end_margin = 3.0
	raiz.add_child(mi)
	return AABB(Vector3(destino.x - tam.x * 0.5, destino.y, destino.z), tam)


## Cria os móveis do modelo de prédio (nome do .glb sem extensão) como filhos de `corpo` (StaticBody3D do prédio).
static var _coletando := false
static var _coleta: Array = []               # [Mesh, Transform3D] das peças do pack enquanto funde
static var _fundidas: Dictionary = {}        # modelo -> ArrayMesh com todas as peças do pack (mesmo layout em todas as casas)


## Junta as peças coletadas numa malha (uma superfície por material: atlas + vidro).
static func _fundir_coleta() -> ArrayMesh:
	var por_mat := {}
	for c in _coleta:
		var me: Mesh = c[0]
		for i in me.get_surface_count():
			var mat := me.surface_get_material(i)
			if not por_mat.has(mat):
				var st0 := SurfaceTool.new()
				st0.begin(Mesh.PRIMITIVE_TRIANGLES)
				por_mat[mat] = st0
			(por_mat[mat] as SurfaceTool).append_from(me, i, c[1])
	var am := ArrayMesh.new()
	for mat in por_mat:
		var st: SurfaceTool = por_mat[mat]
		st.set_material(mat)
		st.commit(am)
	return am


## fundir = true: as peças do pack viram UMA malha compartilhada por todos os prédios do mesmo modelo (1 draw call por casa);
## colisão e saque continuam por móvel.
static func instalar(corpo: StaticBody3D, modelo: String, com_sombra := true, fundir := false) -> int:
	_ler()
	_coletando = fundir
	_coleta = []
	if not corpo.has_meta("modelo"):
		corpo.set_meta("modelo", modelo)
	var lista: Array = _dados.get(modelo, [])
	if lista.is_empty():
		return 0
	var raiz := corpo.get_node_or_null("Moveis") as Node3D
	if raiz == null:
		raiz = Node3D.new()
		raiz.name = "Moveis"
		corpo.add_child(raiz)
	var n := 0
	for it in lista:
		var m := String(it.m)
		var p: Array = it.pos
		var base := Transform3D(Basis(Vector3.UP, deg_to_rad(float(it.rot_y))), Vector3(float(p[0]), float(p[1]), float(p[2])))
		var esc := Vector3.ONE
		if it.has("esc"):
			var e: Array = it.esc
			esc = Vector3(float(e[0]), float(e[1]), float(e[2]))
		# caixa de referência (quadro local da entrada, sem giro)
		var caixa: AABB
		if e_novo(m):
			var dn := _malha(m)
			if dn.is_empty():
				continue
			var bbn: AABB = dn[2]
			var t := bbn.size * esc
			if it.has("tam"):
				var ta: Array = it.tam
				t = Vector3(float(ta[0]), float(ta[1]), float(ta[2]))
			caixa = AABB(Vector3(-t.x * 0.5, 0.0, -t.z * 0.5), t)
		else:
			var da := _malha_aabb_antiga(m)
			if da == AABB():
				continue
			caixa = AABB(da.position * esc, da.size * esc)
		var regra := _regra(m, modelo, caixa)
		var ocupada: AABB
		var nome_tipo := m
		if regra.is_empty():
			# antigo sem equivalente no pack (fogão, rádio, telefone, ventilador): como antes
			var dados := _malha(m)
			if dados.is_empty():
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = dados[0]
			mi.transform = base * Transform3D(Basis.from_scale(esc), Vector3.ZERO) * (dados[1] as Transform3D)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = DIST_VISIVEL
			mi.visibility_range_end_margin = 3.0
			raiz.add_child(mi)
			ocupada = caixa
		else:
			nome_tipo = String(regra.n)
			var dados := _malha(nome_tipo)
			if dados.is_empty():
				continue
			var rep := int(regra.get("rep", 1))
			var larg := caixa.size.x / rep
			for k in rep:
				var sub := AABB(Vector3(caixa.position.x + larg * k, caixa.position.y, caixa.position.z), Vector3(larg, caixa.size.y, caixa.size.z))
				var oc := _peca(raiz, base, dados, sub, float(regra.get("alt", 0.0)))
				ocupada = oc if k == 0 else ocupada.merge(oc)
			for ex in regra.get("extra", []):
				var de := _malha(String(ex[0]))
				if de.is_empty():
					continue
				var bbe: AABB = de[2]
				var topo := Vector3(ocupada.get_center().x + float(ex[1]) * ocupada.size.x, ocupada.end.y,
						ocupada.get_center().z + float(ex[2]) * ocupada.size.z)
				var te := bbe.size.min(Vector3(ocupada.size.x * 0.8, 1.0, ocupada.size.z * 0.8))
				var ce := AABB(Vector3(topo.x - te.x * 0.5, topo.y, topo.z - te.z * 0.5), te)
				_peca(raiz, base, de, ce)
		var fam := familia(nome_tipo)
		var com_loot := fam in LOOTAVEIS and ((n * 7 + 3) % 20) < int(PROP_LOOT * 20.0)
		if regra.has("loot"):
			com_loot = bool(regra.loot)
		if it.has("loot"):
			com_loot = bool(it.loot) and fam in LOOTAVEIS
		if com_loot:
			var ml := BRMovel.new()
			ml.name = "Loot_%s_%d" % [nome_tipo, n]
			ml.transform = base
			corpo.add_child(ml)
			ml.setup_movel(nome_tipo)
			ml.position += base.basis * ocupada.get_center()   # centro do móvel (alvo da mira)
			ml.set_meta("altura", ocupada.size.y)
		var tem_col: bool = not m in SEM_COLISAO and not nome_tipo in SEM_COLISAO and bool(it.get("col", true))
		if tem_col and base.origin.y + ocupada.position.y < 0.4:
			var lst: Array = corpo.get_meta("sombras", [])
			lst.append([base, ocupada])
			corpo.set_meta("sombras", lst)
		if tem_col:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = ocupada.size.max(Vector3(0.02, 0.02, 0.02))
			cs.shape = bs
			cs.transform = base.translated_local(ocupada.get_center())
			corpo.add_child(cs)
		n += 1
	if fundir:
		_coletando = false
		if not _fundidas.has(modelo) and not _coleta.is_empty():
			_fundidas[modelo] = _fundir_coleta()
		_coleta = []
		if _fundidas.has(modelo):
			var mf := MeshInstance3D.new()
			mf.name = "Pack_" + modelo
			mf.mesh = _fundidas[modelo]
			mf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mf.visibility_range_end = DIST_VISIVEL
			mf.visibility_range_end_margin = 3.0
			raiz.add_child(mf)
	if com_sombra:
		sombras(corpo)
	return n


static var _mat_sombra: StandardMaterial3D


## "AO" falso: uma mancha escura (gradiente radial, mistura multiplicativa) sob cada móvel de chão registrado por instalar(),
## todas numa só malha por prédio (1 draw call).
static func sombras(corpo: Node3D) -> void:
	var lst: Array = corpo.get_meta("sombras", [])
	corpo.remove_meta("sombras")
	if lst.is_empty():
		return
	if _mat_sombra == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.42, 0.38, 0.36))
		g.set_color(1, Color(1, 1, 1))
		g.add_point(0.55, Color(0.62, 0.58, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_SQUARE
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_mat_sombra = StandardMaterial3D.new()
		_mat_sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_sombra.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		_mat_sombra.albedo_texture = gt
		_mat_sombra.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_sombra.disable_fog = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in lst:
		var b: Transform3D = e[0]
		var a: AABB = e[1]
		var x0 := a.position.x - 0.14
		var x1 := a.end.x + 0.14
		var z0 := a.position.z - 0.14
		var z1 := a.end.z + 0.14
		var y := a.position.y + 0.012
		var q := [b * Vector3(x0, y, z0), b * Vector3(x1, y, z0), b * Vector3(x1, y, z1), b * Vector3(x0, y, z1)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(q[k])
	var mi := MeshInstance3D.new()
	mi.name = "SombrasMoveis"
	mi.mesh = st.commit()
	mi.material_override = _mat_sombra
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DIST_VISIVEL
	corpo.add_child(mi)


static var _aabb_antigas: Dictionary = {}
static var _aabb_lidas := false


## AABB (quadro local) dos móveis antigos: lida da tabela gerada (sem carregar os glb antigos com textura fotográfica);
## se faltar, carrega o glb antigo.
static func _malha_aabb_antiga(m: String) -> AABB:
	if not _aabb_lidas:
		_aabb_lidas = true
		var arq := DIR_NOVO + "aabb_antigos.json"
		var d = JsonSeguro.ler(arq, TYPE_DICTIONARY)
		if d != null:
			for k in d:
				var a = d[k]
				if a is Array and a.size() >= 6:
					_aabb_antigas[k] = AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]))
	if _aabb_antigas.has(m):
		return _aabb_antigas[m]
	var dados := _malha(m)
	if dados.is_empty():
		return AABB()
	_aabb_antigas[m] = dados[2]
	return dados[2]
