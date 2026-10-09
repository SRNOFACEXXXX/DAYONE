class_name IlhaVegetation
extends Node3D
## Vegetação autoral (docs/design/vegetacao.json -> maps/ilha/vegetacao.json): instâncias em MultiMesh por tipo
## e por bloco de 120 m (mesma grade do terreno), com distância de desenho por tipo. Colisão só nos troncos/pedras.

const BLOCO := 120.0
const BLOCO_TIPO := {"cana": 20.0, "capim_alto": 40.0}
const ALCANCE := {"cana": 48.0, "coqueiro": 480.0, "arvore_mata_a": 520.0, "arvore_mata_b": 560.0, "bananeira": 220.0,
	"arbusto": 160.0, "capim_alto": 80.0, "pedra_pequena": 120.0}
## mata atlântica real: dossel de 20–30 m e copas que se tocam (com 10 m entre troncos a copa precisa ~1,25x)
const ESCALA_TIPO := {"arvore_mata_a": 1.25, "arvore_mata_b": 1.2}
const TRONCO := {"coqueiro": 0.25, "arvore_mata_a": 0.4, "arvore_mata_b": 0.35, "bananeira": 0.18}   # raio do cilindro de colisão

## Variantes de alta qualidade dos pacotes do usuário (assets/models/cenario/natureza, pedras): a posição autoral não muda;
## a instância de índice i usa VARIANTES[tipo][i % n] ("" = modelo original). Escala por variante em VAR_ESCALA.
const VARIANTES := {
	"arvore_mata_a": ["", "cenario/natureza/carvalho", "cenario/natureza/arvore_d"],
	"arvore_mata_b": ["", "cenario/natureza/arvore_b", "cenario/natureza/betula"],
	"arbusto": ["", "cenario/natureza/arbusto_a", "cenario/natureza/arbusto_b", "cenario/natureza/samambaia_a"],
	"pedra_pequena": ["cenario/pedras/pedra_01", "cenario/pedras/pedra_02", "cenario/pedras/pedra_05", "cenario/pedras/pedra_07"],
}
## as árvores do pacote têm 5,5–8,5 m: sobem ao porte do dossel da mata (o tipo original usa ESCALA_TIPO)
const PERTO_VARIANTE := 170.0
## desempenho: tipos de alcance longo divididos em perto (com sombra, bloco 120 m) e longe (sem sombra, bloco 240 m)
const DIVIDE_LONGE := ["arvore_mata_a", "arvore_mata_b", "coqueiro"]
const BLOCO_LONGE := 240.0
const BLOCO_COPA := 480.0
const VAR_ESCALA := {"cenario/natureza/carvalho": 2.1, "cenario/natureza/arvore_d": 2.2, "cenario/natureza/arvore_b": 2.5,
	"cenario/natureza/betula": 1.9, "cenario/natureza/arbusto_a": 1.0, "cenario/natureza/arbusto_b": 1.0,
	"cenario/natureza/samambaia_a": 0.8}

var terrain: IlhaTerrain
static var _raio_cache := {}


## Raio do tronco medido na malha: percentil 95 da distância horizontal ao eixo (origem) dos vértices entre 0,3 e 1,3 m de altura
## (em metros do mundo, com a escala `s` aplicada). -1 se a malha não tem vértices nessa faixa. `xf` leva a malha ao espaço do eixo.
static func raio_tronco(me: Mesh, s: float, xf := Transform3D.IDENTITY) -> float:
	if Game.test_args.has("colisao_antiga"):
		return -1.0   # A/B da auditoria (tests/props_andar.gd)
	var chave := "%d|%.2f|%s" % [me.get_instance_id(), s, xf]
	if _raio_cache.has(chave):
		return _raio_cache[chave]
	var rs: Array[float] = []
	for v in me.get_faces():
		var q: Vector3 = xf * v
		if q.y * s >= 0.3 and q.y * s <= 1.3:
			rs.append(Vector2(q.x, q.z).length() * s)
	var r := -1.0
	if rs.size() >= 6:
		rs.sort()
		r = clampf(rs[int(rs.size() * 0.95)], 0.12, 1.6)
	_raio_cache[chave] = r
	return r
## Árvores cortáveis (arvore_mata_a/b, coqueiro): {pos, tipo, mesh, escala, xf, raio, refs:[[chave,indice]], col, viva}.
## `derrubar(i)` esconde a instância dos MultiMesh (transform zerado) e remove a colisão; só quem corta mexe nisto (nada por quadro).
var arvores: Array = []
var _mm_chave := {}            # chave do grupo -> MultiMesh
var _mm_copa := {}             # chave da copa -> MultiMesh
var auditoria: Array = []     # tests/props_andar.gd (--audit_props): pontos sólidos de cada instância não-rasteira
var _col_pedra := {}          # tipo -> ConvexPolygonShape3D (casco da malha)
const SEM_COLISAO_VEG := ["cana", "capim_alto", "arbusto"]   # rasteiros: atravessáveis por design


func build_async(t: IlhaTerrain, path := "res://maps/ilha/vegetacao.json") -> int:
	terrain = t
	if not FileAccess.file_exists(path):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var lista: Array = data if data is Array else data.get("instancias", [])
	var meshes := {}
	var grupos := {}          # "tipo|bx|bz|base[|perto|longe]" -> Array[Transform3D]
	var copas := {}           # "base|cx|cz" -> Array[Transform3D] (impostor de copa, células de BLOCO_COPA)
	var corpo := StaticBody3D.new()
	corpo.name = "VegetacaoColisao"
	add_child(corpo)
	var casas: Array = []
	for c in get_tree().get_nodes_in_group("casa_pacote"):
		casas.append([Vector2((c as Node3D).global_position.x, (c as Node3D).global_position.z), (c as Node3D).rotation.y])
	# casas extras (casas_pacote.json) só nascem depois, no Detalhes: usa a mesma pose já ajustada (casas_ajuste.json)
	if FileAccess.file_exists("res://maps/ilha/casas_pacote.json"):
		var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/ilha/casas_pacote.json"))
		var aj: Dictionary = CasaPacote.ajustes()
		var k := 0
		for c in ex.get("casas", []):
			var a: Dictionary = aj.get("extra_%d" % k, {})
			var yw := deg_to_rad(float(a.yaw_deg)) if a.has("yaw_deg") else deg_to_rad(float(c.get("rot_deg", 0.0)))
			casas.append([Vector2(float(c.x) + float(a.get("dx", 0.0)), -float(c.y) - float(a.get("dy", 0.0))), yw])
			k += 1
	for index in lista.size():
		var it: Dictionary = lista[index]
		var dentro := false
		var xi := float(it.x)
		var zi := -float(it.y)
		for site in preload("res://maps/ilha/refugios_gpt.gd").SITES:
			if absf(xi - site.pos.x) < 8.0 and absf(zi + site.pos.y) < 7.0:
				dentro = true
		for c in casas:
			var dd: Vector2 = Vector2(xi, zi) - (c[0] as Vector2)
			var yw: float = c[1]
			# espaço local da casa (+Z = frente): inverso da rotação Y do corpo
			var lx := dd.x * cos(yw) - dd.y * sin(yw)
			var lz := dd.x * sin(yw) + dd.y * cos(yw)
			if absf(lx) < 8.0 and lz > -8.4 and lz < 9.4:
				dentro = true
				break
		if dentro:
			continue
		var tipo_base: String = it.tipo
		var tipo := tipo_base
		var vs: Array = VARIANTES.get(tipo_base, [])
		if not vs.is_empty() and String(vs[index % vs.size()]) != "":
			tipo = String(vs[index % vs.size()])
		if not meshes.has(tipo):
			meshes[tipo] = _mesh_of(tipo)
		if meshes[tipo] == null:
			tipo = tipo_base
			if not meshes.has(tipo):
				meshes[tipo] = _mesh_of(tipo)
			if meshes[tipo] == null:
				continue
		var x := float(it.x)
		var z := -float(it.y)
		var y := terrain.height_world(x, z)
		var s := float(it.get("escala", 1.0)) * (float(VAR_ESCALA.get(tipo, 1.0)) if tipo != tipo_base else float(ESCALA_TIPO.get(tipo, 1.0)))
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(it.get("rot_deg", 0.0)))).scaled(Vector3(s, s, s)), Vector3(x, y - 0.05, z))
		var bl: float = BLOCO_TIPO.get(tipo_base, BLOCO)   # capim/cana: blocos menores para o corte por distância ser justo
		var sb := float(it.get("escala", 1.0)) * float(ESCALA_TIPO.get(tipo_base, 1.0))
		var xb := Transform3D(Basis(Vector3.UP, deg_to_rad(float(it.get("rot_deg", 0.0)))).scaled(Vector3(sb, sb, sb)), Vector3(x, y - 0.05, z))
		var arv := {}
		if DIVIDE_LONGE.has(tipo_base):
			arv = {"pos": Vector3(x, y, z), "tipo": tipo_base, "mesh": meshes[tipo], "escala": s, "xf": xf, "raio": 0.3, "refs": [], "col": null, "viva": true}
			arvores.append(arv)
			# perto (até PERTO_VARIANTE): modelo do pacote ou original, com sombra, bloco de 120 m
			var kp := "%s|%d|%d|%s|perto" % [tipo, int(floor(x / bl)), int(floor(z / bl)), tipo_base]
			if not grupos.has(kp):
				grupos[kp] = []
			grupos[kp].append(xf)
			arv.refs.append([kp, grupos[kp].size() - 1])
			# longe (PERTO_VARIANTE..ALCANCE): modelo original leve, sem sombra, bloco de 240 m (1/4 dos draws)
			var kl := "%s|%d|%d|%s|longe" % [tipo_base, int(floor(x / BLOCO_LONGE)), int(floor(z / BLOCO_LONGE)), tipo_base]
			if not grupos.has(kl):
				grupos[kl] = []
			grupos[kl].append(xb)
			arv.refs.append([kl, grupos[kl].size() - 1])
			if not meshes.has(tipo_base):
				meshes[tipo_base] = _mesh_of(tipo_base)
			if tipo_base.begins_with("arvore"):
				var kc := "%s|%d|%d" % [tipo_base, int(floor(x / BLOCO_COPA)), int(floor(z / BLOCO_COPA))]
				if not copas.has(kc):
					copas[kc] = []
				copas[kc].append(xb)
				arv.refs.append(["copa|" + kc, copas[kc].size() - 1])
		else:
			var key := "%s|%d|%d|%s" % [tipo, int(floor(x / bl)), int(floor(z / bl)), tipo_base]
			if not grupos.has(key):
				grupos[key] = []
			grupos[key].append(xf)
			if tipo != tipo_base and float(ALCANCE.get(tipo_base, 300.0)) > PERTO_VARIANTE:
				# LOD: a variante do pacote (500–900 faces) só até PERTO_VARIANTE; além disso, o modelo original leve no mesmo lugar
				var kl2 := "%s|%d|%d|%s|longe" % [tipo_base, int(floor(x / BLOCO_LONGE)), int(floor(z / BLOCO_LONGE)), tipo_base]
				if not grupos.has(kl2):
					grupos[kl2] = []
				grupos[kl2].append(xb)
				if not meshes.has(tipo_base):
					meshes[tipo_base] = _mesh_of(tipo_base)
		if Game.test_args.has("audit_props") and not tipo_base in SEM_COLISAO_VEG:
			var me: Mesh = meshes[tipo]
			var f := me.get_faces()
			var passo := maxi(3, int(f.size() / 3.0 / 400.0) * 3)
			var pts := PackedVector3Array()
			var i := 0
			while i + 2 < f.size():
				pts.append(xf * f[i])
				pts.append(xf * ((f[i] + f[i + 1] + f[i + 2]) / 3.0))
				i += passo
			auditoria.append({"tipo": tipo_base + ("" if tipo == tipo_base else "|" + tipo), "pos": xf.origin, "pts": pts,
				"basis": Basis(Vector3.UP, deg_to_rad(float(it.get("rot_deg", 0.0))))})
		if tipo_base == "pedra_pequena" and not Game.test_args.has("colisao_antiga"):
			# pedras do pacote: casco convexo da malha (antes só o docstring dizia "colisão nos troncos/pedras": não havia)
			if not _col_pedra.has(tipo):
				_col_pedra[tipo] = (meshes[tipo] as Mesh).create_convex_shape(true, true)
			var cp := CollisionShape3D.new()
			cp.shape = _col_pedra[tipo]
			cp.transform = xf
			corpo.add_child(cp)
		if TRONCO.has(tipo_base):
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = TRONCO[tipo_base] * (s if tipo == tipo_base else s * 0.55)
			var rm := raio_tronco(meshes[tipo], s)
			if rm > 0.0:
				cyl.radius = maxf(cyl.radius, rm)   # nunca menor que o tronco visível (o jogador entrava no tronco)
			cyl.height = 6.0 * s
			cs.shape = cyl
			cs.position = Vector3(x, y + 3.0 * s, z)
			corpo.add_child(cs)
			if not arv.is_empty():
				arv.col = cs
				arv.raio = cyl.radius
		if index > 0 and Loading.ceder():
			Loading.set_progress("Distribuindo vegetação e colisões...", 25.0 + 20.0 * float(index) / maxf(1.0, float(lista.size())))
			await get_tree().process_frame
	for key in grupos:
		var partes: PackedStringArray = String(key).split("|")
		var tipo: String = partes[0]
		var base: String = partes[3]
		var faixa: String = partes[4] if partes.size() > 4 else ""
		var variante := tipo != base
		var xfs: Array = grupos[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[tipo]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		_mm_chave[key] = mm
		var alcance: float = ALCANCE.get(base, 300.0)
		mmi.visibility_range_end_margin = 20.0
		if faixa == "longe":
			mmi.visibility_range_begin = PERTO_VARIANTE
			mmi.visibility_range_begin_margin = 20.0
			mmi.visibility_range_end = alcance
		elif faixa == "perto":
			mmi.visibility_range_end = minf(PERTO_VARIANTE, alcance)
		else:
			mmi.visibility_range_end = minf(PERTO_VARIANTE, alcance) if variante else alcance
		# sombra só das árvores/coqueiros de perto (o sol só projeta até 70 m); longe, arbustos, capim e pedras: sem sombra
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if faixa == "perto" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		if Loading.ceder():
			await get_tree().process_frame
	for kc in copas:
		_copas_longe(copas[kc], String(kc).split("|")[0], "copa|" + String(kc))
	return lista.size()


## Junta as superfícies do modelo glb num único ArrayMesh (materiais preservados).
func _mesh_of(tipo: String) -> Mesh:
	var p := ("res://assets/models/%s.glb" % tipo) if "/" in tipo else ("res://assets/models/veg/%s.glb" % tipo)
	if not ResourceLoader.exists(p):
		return null
	var sc: Node = load(p).instantiate()
	var mi := sc.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (mi[0] as MeshInstance3D).mesh if mi.size() > 0 else null
	sc.free()
	return _juntar_cores(m)


## Desempenho: os modelos originais (veg/*.glb) têm 3–6 superfícies só com cor chapada (sem textura) = 3–6 draws por
## bloco. Viram no máximo 2 superfícies (por modo de cull) com a cor do material gravada na cor do vértice.
static var _mats_vc: Dictionary = {}


static func _juntar_cores(m: Mesh) -> Mesh:
	if m == null or m.get_surface_count() < 2:
		return m
	var por_cull := {}
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i) as BaseMaterial3D
		if mat == null or mat.albedo_texture != null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.emission_enabled:
			return m
		var cm: int = mat.cull_mode
		if not por_cull.has(cm):
			por_cull[cm] = []
		por_cull[cm].append(i)
	var im := ImporterMesh.new()   # gera LODs automáticos como no import do glb (sem isso a malha fundida perdia o LOD)
	for cull in por_cull:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rough := 1.0
		for i in por_cull[cull]:
			var mat := m.surface_get_material(i) as BaseMaterial3D
			rough = mat.roughness
			var a := m.surface_get_arrays(i)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns = a[Mesh.ARRAY_NORMAL]
			var cs = a[Mesh.ARRAY_COLOR]
			var idx = a[Mesh.ARRAY_INDEX]
			var lista: PackedInt32Array = idx if idx != null else PackedInt32Array(range(vs.size()))
			for k in lista:
				var c: Color = mat.albedo_color
				if cs != null and (cs as PackedColorArray).size() > k and mat.vertex_color_use_as_albedo:
					c *= (cs as PackedColorArray)[k]
				st.set_color(c)
				if ns != null and (ns as PackedVector3Array).size() > k:
					st.set_normal((ns as PackedVector3Array)[k])
				st.add_vertex(vs[k])
		st.index()
		var chave := "%d|%.2f" % [cull, rough]
		if not _mats_vc.has(chave):
			var mv := StandardMaterial3D.new()
			mv.vertex_color_use_as_albedo = true
			mv.vertex_color_is_srgb = true
			mv.cull_mode = cull
			mv.roughness = rough
			_mats_vc[chave] = mv
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, _mats_vc[chave])
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## Impostor de copa (crítica 01, item 14): icosaedro achatado verde-escuro, 20 triângulos, de ~500 m a 1.600 m.
## Sem isso a ilha fica "careca" vista do avião (as árvores reais somem entre 520 e 560 m).
static var _copa_mesh: Mesh
static var _copa_mat: StandardMaterial3D


func _copas_longe(xfs: Array, tipo: String, chave := "") -> void:
	if _copa_mesh == null:
		var sm := SphereMesh.new()
		sm.radial_segments = 6
		sm.rings = 3
		sm.radius = 1.0
		sm.height = 2.0
		_copa_mesh = sm
		_copa_mat = StandardMaterial3D.new()
		_copa_mat.albedo_color = Color("3F5E2C")
		_copa_mat.roughness = 1.0
	var alto := 15.0 if tipo == "arvore_mata_b" else 12.5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _copa_mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		var t: Transform3D = xfs[i]
		var s := t.basis.get_scale().x
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(4.6, 2.6, 4.6) * s), t.origin + Vector3.UP * alto * s))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if chave != "":
		_mm_chave[chave] = mm
	mmi.material_override = _copa_mat
	mmi.visibility_range_begin = float(ALCANCE.get(tipo, 500.0)) - 20.0
	mmi.visibility_range_end = 1600.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Índice da árvore viva mais próxima de `p` (plano XZ) dentro de `raio` m, ou -1. Só é chamado ao golpear (varredura linear, ~1,5 mil árvores).
func arvore_mais_proxima(p: Vector3, raio: float) -> int:
	var melhor := -1
	var dmin := raio * raio
	for i in arvores.size():
		var a: Dictionary = arvores[i]
		if not a.viva:
			continue
		var d: Vector3 = (a.pos as Vector3) - p
		var d2 := d.x * d.x + d.z * d.z
		if d2 < dmin:
			dmin = d2
			melhor = i
	return melhor


## Tira a árvore `i` do mundo estático: zera a instância em cada MultiMesh (perto/longe/copa) e apaga o cilindro de colisão.
## Devolve o registro (pos, mesh, escala, xf, raio) para quem for animar a queda. {} se já derrubada.
func derrubar(i: int) -> Dictionary:
	if i < 0 or i >= arvores.size() or not arvores[i].viva:
		return {}
	var a: Dictionary = arvores[i]
	a.viva = false
	var zero := Transform3D(Basis.from_scale(Vector3.ZERO), a.pos)
	var orig: Array = []
	for r in a.refs:
		var mm: MultiMesh = _mm_chave.get(r[0])
		if mm != null and int(r[1]) < mm.instance_count:
			orig.append(mm.get_instance_transform(int(r[1])))
			mm.set_instance_transform(int(r[1]), zero)
		else:
			orig.append(zero)
	a["orig"] = orig
	if a.col != null and is_instance_valid(a.col):
		(a.col as Node).queue_free()
	a.col = null
	return a


## Respawn (ou desfazer): devolve a árvore `i` ao mundo. Colisão recriada com o mesmo raio.
func restaurar(i: int) -> void:
	if i < 0 or i >= arvores.size() or arvores[i].viva:
		return
	var a: Dictionary = arvores[i]
	a.viva = true
	var orig: Array = a.get("orig", [])
	for k in a.refs.size():
		var r: Array = a.refs[k]
		var mm: MultiMesh = _mm_chave.get(r[0])
		if mm != null and int(r[1]) < mm.instance_count and k < orig.size():
			mm.set_instance_transform(int(r[1]), orig[k])
	var corpo := get_node_or_null("VegetacaoColisao") as StaticBody3D
	if corpo != null:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = a.raio
		cyl.height = 6.0 * float(a.escala)
		cs.shape = cyl
		cs.position = (a.pos as Vector3) + Vector3(0, 3.0 * float(a.escala), 0)
		corpo.add_child(cs)
		a.col = cs
