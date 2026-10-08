extends Node
## QA independente: mede por quadro a folga optica->superficie da arma (superficie POSADA pelo esqueleto), o atraso do
## BoneAttachment e a distancia em px na tela (com o FOV do shader do viewmodel) em idle, ADS, rajada, recarga, andando,
## troca de arma, retirar/recolocar mira, trocar holo<->ACOG, soltar/pegar.
## Uso: Godot --path game res://tests/qa_holo_anim.tscn -- --armas=m4,m249 [--mira=reddot] [--out=raw/qa_holo]

var OUT := "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/raw/qa_holo"
var _rel := {}
var _vm: ViewModel
var _no: Node3D
var _low := PackedVector3Array()    # pontos baixos da optica (espaco local da optica)
var _ent: Array = []                # triangulos candidatos sob a pegada
var _fx := Vector4()                # x0 x1 z0 z1 no espaco do no da arma
var _k := 1.0
var _sk: Skeleton3D


func _ready() -> void:
	get_tree().create_timer(190.0).timeout.connect(func() -> void: get_tree().quit(2))
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	Game.test_args["chao"] = "1"
	if Game.test_args.has("out"):
		OUT = "C:/Users/satoshi/Documents/ChatGPT/teste/battle_royale/" + String(Game.test_args["out"])
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
	s0.yaw = deg_to_rad(40.0)
	pc._prefer_third_person = false
	pc._set_third_person(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.br_bag.add_item("backpack_large")
	var mira := String(Game.test_args.get("mira", "reddot"))
	for arma in String(Game.test_args.get("armas", "m4")).split(","):
		await _arma(m, pc, arma, mira)
	var f := FileAccess.open(OUT.path_join("qa_anim_%s.json" % String(Game.test_args.get("armas", "m4")).replace(",", "_")), FileAccess.WRITE)
	f.store_string(JSON.stringify(_rel, " "))
	print("QA_DONE")
	get_tree().quit(0)


func _limpar(bag: BRInventory) -> void:
	for it in bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "reddot", "acog", "glock"]:
			bag.remove_item(int(it.uid))


func _arma(m: BRMatch, pc: PlayerController, arma: String, mira: String) -> void:
	var bag: BRInventory = m.br_bag
	_limpar(bag)
	var cal := {"m4": "ammo_556", "m249": "ammo_556", "m107": "ammo_127", "ak47": "ammo_762", "uzi": "ammo_9mm"}
	bag.add_item(String(cal.get(arma, "ammo_556")), 120)
	bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": 30})
	var uid := _uid(bag, arma)
	m._equip_br_weapon(uid)
	await _frames(90)
	bag.add_item(mira)
	var okm: Variant = bag.attach_mira(_uid(bag, mira), uid)
	await _frames(40)
	_vm = pc.viewmodel
	print("QA_ATTACH ", arma, " ", mira, " ", okm, " uid_mira=", _uid(bag, mira))
	var R := {}
	_rel[arma + "_" + mira] = R
	if not _prep():
		R["erro"] = "sem mira"
		return
	R["idle"] = await _cena(pc, "idle", 90)
	await _cap(arma + "_idle")
	Input.action_press("alt_fire")
	R["ads"] = await _cena(pc, "ads", 70)
	await _cap(arma + "_ads")
	Input.action_release("alt_fire")
	await _frames(40)
	if String(Game.test_args.get("rapido", "0")) == "1":
		print("QA ", arma, " ", JSON.stringify(R))
		return
	var ws: WeaponState = m.local_player.current()
	ws.mag = 30 if arma != "m107" else 10
	var mag0 := ws.mag
	Input.action_press("fire")
	R["tiro"] = await _cena(pc, "tiro", 60)
	Input.action_release("fire")
	R["tiro"]["disparos"] = mag0 - ws.mag
	await _frames(40)
	ws.mag = 3
	Input.action_press("reload")
	await _frames(2)
	Input.action_release("reload")
	R["recarga"] = await _cena(pc, "recarga", 200)
	await _frames(30)
	Input.action_press("move_forward")
	R["andando"] = await _cena(pc, "andando", 150)
	Input.action_release("move_forward")
	await _frames(30)
	Input.action_press("move_forward")
	Input.action_press("alt_fire")
	R["andando_ads"] = await _cena(pc, "andando_ads", 100)
	Input.action_release("move_forward")
	Input.action_release("alt_fire")
	await _frames(30)
	bag.add_item("glock", 1, Vector2i(-1, -1), {"mag": 15})
	m._equip_br_weapon(_uid(bag, "glock"))
	await _frames(60)
	m._equip_br_weapon(uid)
	await _frames(60)
	R["apos_troca"] = _estado(m, pc)
	if _prep():
		R["apos_troca"]["medida"] = await _cena(pc, "troca", 60)
		await _cap(arma + "_aposTroca")
	bag.retirar_mira(uid)
	await _frames(30)
	R["sem_mira"] = {"acog_node_nulo": pc.viewmodel._acog_node == null}
	bag.attach_mira(_uid(bag, mira), uid)
	await _frames(40)
	R["recolocada"] = _estado(m, pc)
	if _prep():
		R["recolocada"]["medida"] = await _cena(pc, "recolocada", 40)
	if arma in ["m4", "ak47", "m107"]:
		bag.retirar_mira(uid)
		await _frames(10)
		bag.add_item("acog")
		bag.attach_mira(_uid(bag, "acog"), uid)
		await _frames(40)
		R["acog"] = _estado(m, pc)
		if _prep():
			R["acog"]["medida"] = await _cena(pc, "acog", 40)
			await _cap(arma + "_acog_quadril")
		bag.retirar_mira(uid)
		await _frames(10)
		bag.attach_mira(_uid(bag, mira), uid)
		await _frames(40)
		R["volta_holo"] = _estado(m, pc)
		if _prep():
			R["volta_holo"]["medida"] = await _cena(pc, "volta", 40)
	m._dropar_item(uid)
	await _frames(20)
	R["drop_tem_mira_visual"] = false
	for d in m.br_loot_root.get_children():
		if d is BRDrop:
			var tem := false
			for mi in d.find_children("*", "MeshInstance3D", true, false):
				var nm := String(mi.name).to_lower()
				if "reddot" in nm or "holo" in nm or "acog" in nm or "optic" in nm:
					tem = true
			R["drop_tem_mira_visual"] = R["drop_tem_mira_visual"] or tem
			R["drop_conteudo"] = str(d.contents.items)
	print("QA ", arma, " ", JSON.stringify(R))


func _estado(m: BRMatch, pc: PlayerController) -> Dictionary:
	var vm := pc.viewmodel
	return {"mira_instalada": m.mira_para(m.local_player), "acog_node": vm._acog_node != null, "visivel": vm._acog_node != null and vm._acog_node.is_visible_in_tree(), "arma_vm": String(vm.current_id)}


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


# ---------------------------------------------------------------- medicao
func _prep() -> bool:
	_ent.clear()
	_low.clear()
	if _vm._acog_node == null or _vm._mira_no == null:
		return false
	_no = _vm._mira_no
	_k = 1.0 if _vm._rig_skel != null else 100.0
	_sk = _vm._rig_skel
	var inv := _no.global_transform.affine_inverse()
	var acog := _vm._acog_node
	var all := PackedVector3Array()
	var locs := PackedVector3Array()
	for mi in acog.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.mesh == null or not mm.visible:
			continue
		var xl := acog.global_transform.affine_inverse() * mm.global_transform
		var xf := inv * mm.global_transform
		for si in mm.mesh.get_surface_count():
			var arr := mm.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
			var visto := {}
			for i in ix:
				if not visto.has(i):
					visto[i] = true
					all.append(xf * vs[i])
					locs.append(xl * vs[i])
	var ymin := INF
	for v in all:
		ymin = minf(ymin, v.y)
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	for i in all.size():
		if all[i].y < ymin + 0.6 / _k:
			_low.append(locs[i])
			x0 = minf(x0, all[i].x)
			x1 = maxf(x1, all[i].x)
			z0 = minf(z0, all[i].z)
			z1 = maxf(z1, all[i].z)
	_fx = Vector4(x0, x1, z0, z1)
	var pad := 1.0 / _k
	for g in _vm.scene_root.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or acog.is_ancestor_of(mi) or not ViewModel._visivel_em(mi, _vm.scene_root):
			continue
		var nm := String(mi.name).to_lower()
		if "hand" in nm or "mao" in nm:
			continue
		var skinned := mi.skin != null
		if skinned and String(mi.name) != "Main":
			continue
		if not skinned and not (_no == mi or _no.is_ancestor_of(mi)):
			continue
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
			var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var wt: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var stride := (bn.size() / vs.size()) if (bn.size() > 0 and vs.size() > 0) else 0
			for t in range(0, ix.size() - 2, 3):
				var e := {"mi": mi, "v": [vs[ix[t]], vs[ix[t + 1]], vs[ix[t + 2]]], "b": [], "w": []}
				if skinned and stride > 0:
					for q in 3:
						var vi := ix[t + q]
						e.b.append(bn.slice(vi * stride, vi * stride + stride))
						e.w.append(wt.slice(vi * stride, vi * stride + stride))
				var p := _pos_tri(e, inv)
				var tx0 := minf(p[0].x, minf(p[1].x, p[2].x))
				var tx1 := maxf(p[0].x, maxf(p[1].x, p[2].x))
				var tz0 := minf(p[0].z, minf(p[1].z, p[2].z))
				var tz1 := maxf(p[0].z, maxf(p[1].z, p[2].z))
				if tx1 < x0 - pad or tx0 > x1 + pad or tz1 < z0 - pad or tz0 > z1 + pad:
					continue
				_ent.append(e)
	return not _ent.is_empty()


func _pos_tri(e: Dictionary, inv: Transform3D) -> Array:
	var mi: MeshInstance3D = e.mi
	var out := []
	if mi.skin == null or e.b.is_empty():
		var xf := inv * mi.global_transform
		for q in 3:
			out.append(xf * (e.v[q] as Vector3))
		return out
	var sk := mi.get_node(mi.skeleton) as Skeleton3D
	var g0 := sk.global_transform
	for q in 3:
		var acc := Vector3.ZERO
		var bs: PackedInt32Array = e.b[q]
		var wv: PackedFloat32Array = e.w[q]
		for j in bs.size():
			if wv[j] <= 0.0:
				continue
			var bi := mi.skin.get_bind_bone(bs[j])
			if bi < 0:
				bi = sk.find_bone(mi.skin.get_bind_name(bs[j]))
			acc += wv[j] * ((sk.get_bone_global_pose(bi) * mi.skin.get_bind_pose(bs[j])) * (e.v[q] as Vector3))
		out.append(inv * (g0 * acc))
	return out


func _amostra() -> Dictionary:
	var inv := _no.global_transform.affine_inverse()
	var acog := _vm._acog_node
	var xo := inv * acog.global_transform
	var ymin := INF
	for v in _low:
		ymin = minf(ymin, (xo * v).y)
	var tris := []
	for e in _ent:
		tris.append(_pos_tri(e, inv))
	var topo := -INF
	var soma := 0.0
	var cont := 0
	var pior := 0.0
	var cx := (_fx.x + _fx.y) * 0.5
	var cz := (_fx.z + _fx.w) * 0.5
	for ia in 7:
		for ib in 9:
			var px := lerpf(_fx.x, _fx.y, 0.1 + 0.8 * ia / 6.0)
			var pz := lerpf(_fx.z, _fx.w, 0.1 + 0.8 * ib / 8.0)
			var hh := ViewModel._altura_sob(tris, px, pz, ymin + 3.0 / _k)
			topo = maxf(topo, hh)
			if hh > -INF:
				soma += ymin - hh
				cont += 1
				pior = maxf(pior, ymin - hh)
	var hc := ViewModel._altura_sob(tris, cx, cz, ymin + 3.0 / _k)
	var gap := (ymin - topo) * _k if topo > -INF else 999.0
	var lag := 0.0
	var att := _no as BoneAttachment3D
	if att != null and _sk != null:
		var bi := _sk.find_bone(att.bone_name)
		var esperado := _sk.global_transform * _sk.get_bone_global_pose(bi)
		lag = (esperado.origin - att.global_transform.origin).length() * 100.0
	var cam := get_viewport().get_camera_3d()
	var H := float(get_viewport().get_visible_rect().size.y)
	var Wd := float(get_viewport().get_visible_rect().size.x)
	var pxgap := 999.0
	if hc > -INF:
		var a := _vm_proj(cam, _no.global_transform * Vector3(cx, ymin, cz), H, Wd)
		var b := _vm_proj(cam, _no.global_transform * Vector3(cx, hc, cz), H, Wd)
		pxgap = a.distance_to(b)
	var vis := acog.is_visible_in_tree() and _vm.visible
	return {"gap": gap, "lag": lag, "px": pxgap, "vis": vis, "media": soma / maxf(cont, 1) * _k, "pior": pior * _k, "centro": (ymin - hc) * _k if hc > -INF else 999.0}


func _vm_proj(cam: Camera3D, w: Vector3, H: float, Wd: float) -> Vector2:
	var v := cam.global_transform.affine_inverse() * w
	var f := 1.0 / tan(deg_to_rad(_vm._vm_fov()) * 0.5)
	return Vector2(f / (Wd / H) * v.x / -v.z * Wd * 0.5, f * v.y / -v.z * H * 0.5)


func _cena(pc: PlayerController, nome: String, n: int) -> Dictionary:
	var gmin := INF
	var gmax := -INF
	var lmax := 0.0
	var pmax := 0.0
	var inv_n := 0
	var nan := 0
	var gseq := []
	var mm := 0.0
	var pp := 0.0
	var cc := 0.0
	for i in n:
		await get_tree().process_frame
		if _vm._acog_node == null:
			nan += 1
			continue
		var s := _amostra()
		gmin = minf(gmin, s.gap)
		gmax = maxf(gmax, s.gap)
		lmax = maxf(lmax, s.lag)
		mm = maxf(mm, s.media)
		pp = maxf(pp, s.pior)
		cc = maxf(cc, s.centro)
		pmax = maxf(pmax, s.px)
		if not s.vis:
			inv_n += 1
		if i % 5 == 0:
			gseq.append(snappedf(s.gap, 0.01))
	return {"gap_min_cm": snappedf(gmin, 0.01), "gap_max_cm": snappedf(gmax, 0.01), "lag_max_cm": snappedf(lmax, 0.01),
		"px_gap_max": snappedf(pmax, 0.01), "folga_media_grade_cm": snappedf(mm, 0.01), "folga_pior_celula_cm": snappedf(pp, 0.01), "folga_centro_cm": snappedf(cc, 0.01), "quadros_invisiveis": inv_n, "sem_no": nan, "gap_seq": gseq}
