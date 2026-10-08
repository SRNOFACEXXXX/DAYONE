class_name OpticaAssento
extends RefCounted
## Óptica (ACOG / holográfica) no modelo de MUNDO da arma (wf/*.tscn: metros, -Z = boca, +Y = cima): 3ª pessoa, bots e arma no chão.
## Mesma lógica de ViewModel._assentar_mira: a base da óptica (vértice mais baixo usado por triângulos) sobe/desce até a
## superfície mais alta da arma sob a pegada, e o centro da óptica vai para o eixo do cano. Cache por arma + tipo.

const HOLO_GLB := "res://assets/models/fp/holo_lp.glb"
const ACOG_GLB := "res://assets/models/weapons/wf/acog.glb"
const HOLO_ESC := 0.9          # holo_lp.glb em tamanho real (o rig usa 0,9 x 100 em cm)
const ACOG_ESC := 0.55
const NOME := "OpticaMira"
## [y do trilho, z, x do centro do trilho] no espaço da arma (igual a ViewModel.ACOG_TRILHO)
const TRILHO := {"ak47": [0.176, -0.03, -0.0044], "m4": [0.03, 0.02, -0.004], "m107": [0.05, -0.05, -0.025], "m249": [0.058, 0.05, -0.0097], "uzi": [0.05, -0.02, 0.0]}
const K := 100.0   # unidades por cm inverso: 1 cm = 1/K m
static var _cache := {}


static func tem_trilho(id: StringName) -> bool:
	return TRILHO.has(String(id))


static func tipo_do_item(item: Dictionary) -> String:
	return "acog" if bool(item.get("acog", false)) else ("reddot" if bool(item.get("reddot", false)) else "")


static func remover(arma: Node3D) -> void:
	if arma == null:
		return
	var o := arma.get_node_or_null(NOME)
	if o:
		arma.remove_child(o)
		o.queue_free()


## Sincroniza a óptica da arma com `tipo` ("", "acog", "reddot"). Devolve o nó (ou null).
static func sincronizar(arma: Node3D, id: StringName, tipo: String) -> Node3D:
	var atual := arma.get_node_or_null(NOME) as Node3D if arma else null
	if atual and String(atual.get_meta("tipo", "")) == tipo:
		return atual
	remover(arma)
	if arma == null or tipo == "" or not TRILHO.has(String(id)):
		return null
	return montar(arma, id, tipo)


static func montar(arma: Node3D, id: StringName, tipo: String) -> Node3D:
	var t: Array = TRILHO[String(id)]
	var arq := HOLO_GLB if tipo == "reddot" else ACOG_GLB
	if not ResourceLoader.exists(arq):
		return null
	var o: Node3D = load(arq).instantiate()
	o.name = NOME
	o.set_meta("tipo", tipo)
	if tipo == "reddot":
		o.scale = Vector3.ONE * HOLO_ESC
		o.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		o.position = Vector3(float(t[2]), float(t[0]), float(t[1]))
	else:
		o.scale = Vector3.ONE * ACOG_ESC
		o.rotation = Vector3(0.0, PI, 0.0)
		o.position = Vector3(float(t[2]), float(t[0]) + 0.038 * ACOG_ESC, float(t[1]))
	arma.add_child(o)
	for g in o.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = 2
	var chave := "%s|%s" % [id, tipo]
	var d: Vector3
	if _cache.has(chave):
		d = _cache[chave]
	else:
		d = medir(arma, o)[0]
		_cache[chave] = d
	o.position += d
	return o


static func _rel(n: Node3D, raiz: Node3D) -> Transform3D:
	var x := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != raiz:
		if c is Node3D:
			x = (c as Node3D).transform * x
		c = c.get_parent()
	return x


static func _visivel(n: Node, raiz: Node) -> bool:
	var c := n
	while c != null and c != raiz:
		if c is Node3D and not (c as Node3D).visible:
			return false
		c = c.get_parent()
	return true


static func _tris(m: MeshInstance3D, xf: Transform3D, saida: Array) -> void:
	for si in m.mesh.get_surface_count():
		var arr := m.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
		for t in range(0, ix.size() - 2, 3):
			saida.append([xf * vs[ix[t]], xf * vs[ix[t + 1]], xf * vs[ix[t + 2]]])


## Mede (deslocamento a aplicar à óptica, folga atual em cm). `o` deve estar na posição inicial (antes do deslocamento).
## Folga = base da óptica - superfície da arma sob a pegada (0 = assentada).
static func medir(arma: Node3D, o: Node3D) -> Array:
	var mv := PackedVector3Array()
	for mi in o.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var xf := _rel(o, arma) * _rel(m, o)
		var tr := []
		_tris(m, xf, tr)
		for t in tr:
			for v: Vector3 in t:
				mv.append(v)
	if mv.is_empty():
		return [Vector3.ZERO, 0.0]
	var ymin := INF
	for v in mv:
		ymin = minf(ymin, v.y)
	var x0 := INF; var x1 := -INF; var z0 := INF; var z1 := -INF
	for v in mv:
		if v.y < ymin + 0.6 / K:
			x0 = minf(x0, v.x); x1 = maxf(x1, v.x); z0 = minf(z0, v.z); z1 = maxf(z1, v.z)
	var tris := []
	for g in arma.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or o.is_ancestor_of(mi) or not _visivel(mi, arma):
			continue
		var nm := String(mi.name).to_lower()
		if "hand" in nm or "mao" in nm:
			continue
		_tris(mi, _rel(mi, arma), tris)
	if tris.is_empty():
		return [Vector3.ZERO, 0.0]
	var zf := INF   # boca = -Z
	for t in tris:
		for v: Vector3 in t:
			zf = minf(zf, v.z)
	var bx0 := INF; var bx1 := -INF
	for t in tris:
		for v: Vector3 in t:
			if v.z < zf + 4.0 / K:
				bx0 = minf(bx0, v.x); bx1 = maxf(bx1, v.x)
	var dx := (bx0 + bx1) * 0.5 - (x0 + x1) * 0.5
	var topo := -INF
	for ia in 7:
		for ib in 9:
			var px := lerpf(x0, x1, 0.1 + 0.8 * ia / 6.0) + dx
			var pz := lerpf(z0, z1, 0.1 + 0.8 * ib / 8.0)
			topo = maxf(topo, altura_sob(tris, px, pz, ymin + 3.0 / K))
	var dy := 0.0 if topo == -INF else topo - ymin
	return [Vector3(dx, dy, 0.0), (ymin - topo) * K if topo != -INF else 0.0]


## Folga (cm) entre a base da óptica já assentada e a superfície da arma sob ela; mede de novo, sem cache.
static func folga_cm(arma: Node3D, o: Node3D) -> float:
	var r := medir(arma, o)
	return absf((r[0] as Vector3).y) * K   # deslocamento residual vertical que ainda faltaria para encostar


static func altura_sob(tris: Array, x: float, z: float, y_max: float) -> float:
	var best := -INF
	for t in tris:
		var a: Vector3 = t[0]; var b: Vector3 = t[1]; var c: Vector3 = t[2]
		var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-9:
			continue
		var u := ((b.x - x) * (c.z - z) - (c.x - x) * (b.z - z)) / d
		var v := ((c.x - x) * (a.z - z) - (a.x - x) * (c.z - z)) / d
		var w := 1.0 - u - v
		if u < 0.0 or v < 0.0 or w < 0.0:
			continue
		var y := u * a.y + v * b.y + w * c.y
		if y <= y_max and y > best:
			best = y
	return best
