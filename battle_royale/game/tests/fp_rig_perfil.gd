extends SceneTree
## Perfil da arma do pack no espaço do osso Main (cm): eixos, extensões, perfil de altura por fatia ao longo do cano.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var osso: String = args[1] if args.size() > 1 else "Main"
	var malha: String = args[2] if args.size() > 2 else "Main"
	var cena: Node3D = load(path).instantiate()
	root.add_child(cena)
	await process_frame
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = null
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		if String(m.name) == malha:
			mi = m
	var skin := mi.skin
	var bi := -1
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == osso or skin.get_bind_name(i) == osso + "_j" or (bi < 0 and skin.get_bind_name(i).begins_with(osso)):
			bi = i
	var bind := skin.get_bind_pose(bi)
	var pts: Array[Vector3] = []
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			pts.append(bind * v)
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	print("BIND ", skin.get_bind_name(bi), " n=", pts.size(), " lo=", lo, " hi=", hi)
	# eixo longo = maior extensão
	var ext := hi - lo
	var ax := 0 if ext.x >= ext.y and ext.x >= ext.z else (1 if ext.y >= ext.z else 2)
	var outros := [0, 1, 2]
	outros.erase(ax)
	print("EIXO_LONGO ", ax, " ext=", ext)
	for o in outros:
		var linha := "PERFIL eixo%d max/min por fatia de 2cm ao longo do eixo%d:\n" % [o, ax]
		var f := lo[ax]
		while f < hi[ax]:
			var mx := -1e9
			var mn := 1e9
			for p in pts:
				if p[ax] >= f and p[ax] < f + 2.0:
					mx = maxf(mx, p[o])
					mn = minf(mn, p[o])
			linha += "  %6.1f: %6.2f .. %6.2f\n" % [f, mn, mx]
			f += 2.0
		print(linha)
	quit()
