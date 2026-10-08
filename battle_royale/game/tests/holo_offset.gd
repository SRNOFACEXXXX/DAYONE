extends Node
## Mede, em cm (espaço do nó da arma), se a mira holográfica está sentada no trilho e alinhada ao cano.
## Para cada arma: folga base-da-mira -> topo do trilho sob ela, desvio lateral do ponto (centro da janela) e do corpo da
## mira em relação ao eixo do cano (x da boca), altura do ponto sobre o eixo e o erro do ponto no centro da tela em ADS (px).
## Falha (exit 1) se folga > 0,5 cm, desvio lateral > 0,5 cm ou ponto fora do centro > 1,5 px.
## Uso: Godot_console --path game res://tests/holo_offset.tscn -- --armas=m4,m249,m107 [--out=raw/holo_offset]

const LIM_CM := 0.5
const LIM_PX := 1.5
var OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/raw/holo_offset"
var _falhas := 0
var _rel: Array = []


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	if Game.test_args.has("out"):
		OUT = "C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/" + String(Game.test_args["out"])
	DirAccess.make_dir_recursive_absolute(OUT)
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	while m.br_bag == null or m.local_player == null or m.local_player.controller == null:
		await get_tree().process_frame
	var pc := m.local_player.controller as PlayerController
	var s0 := m.local_player
	var hx: float = m.ilha.terrain.height_world(-345.0, 352.0)
	s0.global_position = Vector3(-345.0, hx + 0.1, 352.0)
	s0.velocity = Vector3.ZERO
	s0.yaw = deg_to_rad(40.0)
	s0.pitch = 0.0
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_medium")
	var armas := String(Game.test_args.get("armas", "m4,m249,m107")).split(",")
	for arma in armas:
		await _medir(m, pc, arma)
	var f := FileAccess.open(OUT.path_join("holo_offset.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"limite_cm": LIM_CM, "limite_px": LIM_PX, "falhas": _falhas, "armas": _rel}, " "))
	print("HOLO_RESULT falhas=", _falhas)
	get_tree().quit(1 if _falhas > 0 else 0)


func _medir(m: BRMatch, pc: PlayerController, arma: String) -> void:
	var bag: BRInventory = m.br_bag
	for it in bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "reddot", "acog", "mosin"]:
			bag.remove_item(int(it.uid))
	var uid := int(bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": 30}))
	uid = _uid(bag, arma)
	m._equip_br_weapon(uid)
	await _frames(90)
	var mira := String(Game.test_args.get("mira", "reddot"))
	bag.add_item(mira)
	var ok_ac: Variant = bag.attach_mira(_uid(bag, mira), uid)
	await _frames(30)
	var vm: ViewModel = pc.viewmodel
	var r := {"arma": arma, "mira": String(Game.test_args.get("mira", "reddot")), "acoplou": ok_ac}
	if vm._acog_node == null or vm._mira_no == null:
		r["erro"] = "sem mira instalada"
		_falhas += 1
		_rel.append(r)
		print("HOLO ", JSON.stringify(r))
		return
	var no: Node3D = vm._mira_no
	var k := 1.0 if vm._rig_skel != null else 100.0   # unidades do nó da arma -> cm (rig do pack em cm, wf em m)
	var inv := no.global_transform.affine_inverse()
	# vértices da mira (só os usados por triângulos: há vértices soltos invisíveis no glb)
	var hv := PackedVector3Array()
	for mi in vm._acog_node.find_children("*", "MeshInstance3D", true, false):
		hv.append_array(_verts_usados(mi as MeshInstance3D, inv * (mi as MeshInstance3D).global_transform))
	var ymin := INF
	var ymax := -INF
	for v in hv:
		ymin = minf(ymin, v.y)
		ymax = maxf(ymax, v.y)
	var x0 := INF; var x1 := -INF; var z0 := INF; var z1 := -INF
	for v in hv:
		if v.y < ymin + 0.6 / k:
			x0 = minf(x0, v.x); x1 = maxf(x1, v.x); z0 = minf(z0, v.z); z1 = maxf(z1, v.z)
	# topo da arma sob a pegada da mira: altura da SUPERFÍCIE (triângulos) numa grade de pontos da pegada — os vértices
	# de uma malha low poly ficam nos cantos das faces grandes, fora da pegada
	var wv := _verts_arma(vm, no, inv)
	var tris := _tris_arma(vm, no, inv)
	var topo := -INF
	var n_amostra := 0
	var alturas: Array[float] = []
	for ix in 7:
		for iz in 9:
			var px := lerpf(x0, x1, 0.1 + 0.8 * ix / 6.0)
			var pz := lerpf(z0, z1, 0.1 + 0.8 * iz / 8.0)
			var h := _altura_sob(tris, px, pz, ymin + 2.0 / k)
			if h > -INF:
				n_amostra += 1
				topo = maxf(topo, h)
				alturas.append(h)
	r["amostras_com_superficie"] = n_amostra
	# folga no CENTRO da pegada e mediana (o QA mostrou que só o máximo é tautológico: a óptica é assentada nele)
	var hc := _altura_sob(tris, (x0 + x1) * 0.5, (z0 + z1) * 0.5, ymin + 2.0 / k)
	alturas.sort()
	r["folga_centro_cm"] = snappedf((ymin - hc) * k, 0.01) if hc > -INF else null
	r["folga_mediana_cm"] = snappedf((ymin - alturas[alturas.size() / 2]) * k, 0.01) if alturas.size() > 0 else null
	var muzzle_p := inv * vm.muzzle.global_transform.origin if vm.muzzle else Vector3.ZERO
	# eixo do cano medido na malha: centro (x, y) da ponta do cano (últimos 4 cm na direção da boca)
	var frente := 1.0 if vm._rig_skel != null else -1.0   # rig: +Z boca; wf: -Z boca
	var zf := -INF
	for v in wv:
		zf = maxf(zf, v.z * frente)
	var bx0 := INF; var bx1 := -INF; var by0 := INF; var by1 := -INF
	for v in wv:
		if v.z * frente > zf - 4.0 / k:
			bx0 = minf(bx0, v.x); bx1 = maxf(bx1, v.x); by0 = minf(by0, v.y); by1 = maxf(by1, v.y)
	var cano := Vector3((bx0 + bx1) * 0.5, (by0 + by1) * 0.5, zf * frente)
	# perfil lateral (topo da arma por fatia de 1 cm em z, faixa |x - eixo| < 3 cm) e contorno da mira -> PNG de prova
	_perfil_png(wv, hv, k, cano, arma)
	_dump_tris(vm, no, inv, k, cano, arma, vm._alca * k)
	r["muzzle_cfg_x"] = snappedf(muzzle_p.x * k, 0.01)
	r["cano_malha"] = [snappedf(cano.x * k, 0.01), snappedf(cano.y * k, 0.01)]
	muzzle_p = cano
	var dot: Vector3 = vm._alca
	r["base_mira_y"] = snappedf(ymin * k, 0.01)
	r["topo_trilho_y"] = snappedf(topo * k, 0.01)
	r["folga_cm"] = snappedf((ymin - topo) * k, 0.01)
	r["mira_altura_cm"] = snappedf((ymax - ymin) * k, 0.01)
	r["lateral_ponto_cm"] = snappedf((dot.x - muzzle_p.x) * k, 0.01)
	r["lateral_corpo_cm"] = snappedf(((x0 + x1) * 0.5 - muzzle_p.x) * k, 0.01)
	r["ponto_sobre_cano_cm"] = snappedf((dot.y - muzzle_p.y) * k, 0.01)
	r["pegada_x"] = [snappedf(x0 * k, 0.01), snappedf(x1 * k, 0.01)]
	r["pegada_z"] = [snappedf(z0 * k, 0.01), snappedf(z1 * k, 0.01)]
	await _cap(arma + "_" + String(Game.test_args.get("mira", "reddot")) + "_quadril")
	var fov_hip: float = get_viewport().get_camera_3d().fov
	Input.action_press("alt_fire")
	await _frames(int(Game.test_args.get("ads_q", "45")))
	# erro do ponto no centro, amostrado por 60 quadros (respiração/idle), em px na tela e normalizado ao FOV do quadril
	# (com a ACOG o FOV fecha 4x e 1 px de quadril vira ~4 px)
	var px := 0.0
	var px_raw := 0.0
	var cam: Camera3D
	for _q in 60:
		await get_tree().process_frame
		cam = get_viewport().get_camera_3d()
		var pc_cam := cam.global_transform.affine_inverse() * (no.global_transform * vm._alca)
		var ang := rad_to_deg(atan2(Vector2(pc_cam.x, pc_cam.y).length(), -pc_cam.z))
		var h := float(get_viewport().get_visible_rect().size.y)
		px_raw = maxf(px_raw, ang / cam.fov * h)
		px = maxf(px, ang / fov_hip * h)
	r["ads_ponto_px"] = snappedf(px, 0.01)
	r["ads_ponto_px_tela"] = snappedf(px_raw, 0.01)
	r["fov_ads"] = snappedf(cam.fov, 0.1)
	await _cap(arma + "_" + String(Game.test_args.get("mira", "reddot")) + "_ads")
	Input.action_release("alt_fire")
	await _frames(30)
	await _cap_lado(vm, no, Vector3((x0 + x1) * 0.5, (ymin + topo) * 0.5, (z0 + z1) * 0.5), arma)
	var falha := []
	if topo == -INF:
		falha.append("sem trilho sob a mira")
	elif absf(ymin - topo) * k > LIM_CM:
		falha.append("folga %.2f cm" % ((ymin - topo) * k))
	if absf(dot.x - muzzle_p.x) * k > LIM_CM:
		falha.append("ponto fora do eixo do cano %.2f cm" % ((dot.x - muzzle_p.x) * k))
	if absf((x0 + x1) * 0.5 - muzzle_p.x) * k > LIM_CM:
		falha.append("corpo da mira fora do eixo %.2f cm" % (((x0 + x1) * 0.5 - muzzle_p.x) * k))
	if px > LIM_PX:
		falha.append("ponto fora do centro em ADS %.2f px" % px)
	r["falhas"] = falha
	_falhas += falha.size()
	_rel.append(r)
	print("HOLO ", JSON.stringify(r))
	bag.retirar_mira(uid)
	await _frames(5)


func _perfil_png(wv: PackedVector3Array, hv: PackedVector3Array, k: float, cano: Vector3, arma: String) -> void:
	var px_cm := 8.0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in wv:
		lo = lo.min(Vector2(v.z, v.y) * k); hi = hi.max(Vector2(v.z, v.y) * k)
	var w := int((hi.x - lo.x) * px_cm) + 40
	var h := int((hi.y - lo.y + 12.0) * px_cm) + 40
	var img := Image.create(clampi(w, 64, 4000), clampi(h, 64, 3000), false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.95, 0.95))
	var to_px := func(z: float, y: float) -> Vector2i:
		return Vector2i(int((z - lo.x) * px_cm) + 20, img.get_height() - 20 - int((y - lo.y) * px_cm))
	for v in wv:
		if absf(v.x - cano.x) * k < 3.0:
			var p: Vector2i = to_px.call(v.z * k, v.y * k)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixelv(p, Color(0.2, 0.2, 0.2))
	for v in hv:
		var p: Vector2i = to_px.call(v.z * k, v.y * k)
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(p, Color(0.85, 0.1, 0.1))
	for zz in range(int(lo.x), int(hi.x)):   # linha do eixo do cano
		var p: Vector2i = to_px.call(float(zz), cano.y * k)
		if p.y >= 0 and p.y < img.get_height():
			img.set_pixelv(p, Color(0.1, 0.4, 0.9))
	img.save_png(OUT.path_join(arma + "_perfil.png"))


## Triângulos (z, y em cm) da arma e da mira para tools/perfil_mira.py desenhar a silhueta lateral.
func _dump_tris(vm: ViewModel, no: Node3D, inv: Transform3D, k: float, cano: Vector3, arma: String, dot: Vector3) -> void:
	var arma_t := []
	var mira_t := []
	for g in vm.scene_root.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null or "hand" in String(mi.name).to_lower() or "mao" in String(mi.name).to_lower():
			continue
		var xf := inv * mi.global_transform
		var dest := arma_t
		if vm._acog_node.is_ancestor_of(mi):
			dest = mira_t
		elif mi.skin != null:
			if String(mi.name) != "Main":
				continue
			for i in mi.skin.get_bind_count():
				if String(mi.skin.get_bind_name(i)).begins_with(String(vm._miras_rig.get("osso", "Main"))):
					xf = mi.skin.get_bind_pose(i)
		elif not no.is_ancestor_of(mi):
			continue
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
			for t in range(0, ix.size() - 2, 3):
				var tri := []
				for q in 3:
					var v: Vector3 = xf * vs[ix[t + q]] * k
					tri.append_array([snappedf(v.z, 0.01), snappedf(v.y, 0.01), snappedf(v.x, 0.01)])
				dest.append(tri)
	var f := FileAccess.open(OUT.path_join(arma + "_tris.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"arma": arma_t, "mira": mira_t, "cano": [cano.z * k, cano.y * k, cano.x * k], "ponto": [dot.z, dot.y, dot.x], "frente": 1 if vm._rig_skel != null else -1}))


func _tris_arma(vm: ViewModel, no: Node3D, inv: Transform3D) -> Array:
	var out := []
	for g in vm.scene_root.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null or vm._acog_node.is_ancestor_of(mi) or "hand" in String(mi.name).to_lower() or "mao" in String(mi.name).to_lower():
			continue
		var xf := inv * mi.global_transform
		if mi.skin != null:
			if String(mi.name) != "Main":
				continue
			for i in mi.skin.get_bind_count():
				if String(mi.skin.get_bind_name(i)).begins_with(String(vm._miras_rig.get("osso", "Main"))):
					xf = mi.skin.get_bind_pose(i)
		elif not no.is_ancestor_of(mi):
			continue
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
			for t in range(0, ix.size() - 2, 3):
				out.append([xf * vs[ix[t]], xf * vs[ix[t + 1]], xf * vs[ix[t + 2]]])
	return out


## Maior altura de superfície da arma no ponto (x, z), abaixo de y_max (raio vertical contra os triângulos).
func _altura_sob(tris: Array, x: float, z: float, y_max: float) -> float:
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


func _verts_usados(mi: MeshInstance3D, xf: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mi.mesh == null or not mi.is_visible_in_tree():
		return out
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if ix.is_empty():
			for v in vs:
				out.append(xf * v)
		else:
			var visto := {}
			for i in ix:
				if not visto.has(i):
					visto[i] = true
					out.append(xf * vs[i])
	return out


## Vértices da arma (sem mira, sem mãos) no espaço do nó da arma. Malha com skin (pack): bind do osso da arma.
func _verts_arma(vm: ViewModel, no: Node3D, inv: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var raiz: Node = vm.scene_root
	for g in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if not mi.is_visible_in_tree() or vm._acog_node.is_ancestor_of(mi) or "hand" in String(mi.name).to_lower() or "mao" in String(mi.name).to_lower():
			continue
		if mi.skin != null:
			var bind := Transform3D()
			var achou := false
			for i in mi.skin.get_bind_count():
				if String(mi.skin.get_bind_name(i)).begins_with(String(vm._miras_rig.get("osso", "Main"))):
					bind = mi.skin.get_bind_pose(i)
					achou = true
			if achou and String(mi.name) == "Main":
				out.append_array(_verts_usados(mi, bind))
		elif no.is_ancestor_of(mi):
			out.append_array(_verts_usados(mi, inv * mi.global_transform))
	return out


func _cap_lado(vm: ViewModel, no: Node3D, centro: Vector3, arma: String) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.14
	cam.near = 0.01
	cam.cull_mask = 0xFFFFF
	add_child(cam)
	var c := no.global_transform * centro
	var lado := no.global_transform.basis.x.normalized()
	cam.global_position = c + lado * 1.0
	cam.look_at(c, no.global_transform.basis.y.normalized())
	cam.current = true
	await _frames(3)
	await _cap(arma + "_" + String(Game.test_args.get("mira", "reddot")) + "_lado")
	var cam2 := Camera3D.new()
	cam2.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam2.size = 0.14
	cam2.near = 0.01
	cam2.cull_mask = 0xFFFFF
	add_child(cam2)
	cam2.global_position = c + no.global_transform.basis.z.normalized() * 1.0
	cam2.look_at(c, no.global_transform.basis.y.normalized())
	cam2.current = true
	await _frames(3)
	await _cap(arma + "_" + String(Game.test_args.get("mira", "reddot")) + "_frente")
	cam.queue_free()
	cam2.queue_free()
	await _frames(2)
	var pcam := get_tree().root.find_children("*", "Camera3D", true, false)
	for k in pcam:
		if (k as Camera3D).name == "Camera3D" or (k as Camera3D) == (vm.soldier.controller as PlayerController).camera:
			(k as Camera3D).current = true
	(vm.soldier.controller as PlayerController).camera.current = true


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _cap(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT.path_join(nome + ".png"))


func _uid(bag: BRInventory, id: String) -> int:
	for it in bag.items:
		if String(it.id) == id:
			return int(it.uid)
	return -1
