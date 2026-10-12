extends RefCounted
## Coleta comum das auditorias de colisão: malhas visíveis do mundo agrupadas por ASSET FONTE.
const EXCLUIR := ["Soldier", "Zombie", "Animal", "Vehicle", "Terreno", "Agua", "Water", "Ceu", "Sky", "Nuvem", "Capim", "Fx", "Pickups", "Hud", "HUD"]


static func excluido(m: Node, n: Node) -> bool:
	var p: Node = n
	while p and p != m:
		var nm := String(p.name)
		for ex in EXCLUIR:
			if nm.contains(ex):
				return true
		if p is Soldier or p is ZombieEnemy or p is IlhaTerrain:
			return true
		p = p.get_parent()
	return false


static func limpa(s: String) -> String:
	return s.rstrip("0123456789@_ ")


static func chave(m: Node, mesh: Mesh, n: Node) -> String:
	if mesh.resource_path != "" and not mesh.resource_path.contains("::"):
		return mesh.resource_path
	var raiz: Node = n
	while raiz and raiz != m and raiz.scene_file_path == "":
		raiz = raiz.get_parent()
	if raiz and raiz != m and raiz.scene_file_path != "":
		return raiz.scene_file_path + "#" + limpa(String(n.name))
	return "%s/%s(%d)" % [limpa(String(n.get_parent().name)), limpa(String(n.name)), mesh.get_surface_count()]


static func chave_mm(mesh: Mesh, n: Node) -> String:
	if mesh.resource_path != "" and not mesh.resource_path.contains("::"):
		return mesh.resource_path
	var ab := mesh.get_aabb()
	return "%s|%s|aabb=%.1fx%.1fx%.1f" % [limpa(String(n.get_parent().name)), limpa(String(n.name)), ab.size.x, ab.size.y, ab.size.z]


static func coletar(m: Node, n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).is_visible_in_tree():
		if not excluido(m, n):
			var mi := n as MeshInstance3D
			var k := chave(m, mi.mesh, n)
			if not out.has(k):
				out[k] = []
			(out[k] as Array).append([mi.mesh, mi.global_transform, n])
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and (n as MultiMeshInstance3D).is_visible_in_tree():
		if not excluido(m, n):
			var mmi := n as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm.mesh != null:
				var k2 := "MM:" + (String(n.get_meta("prop")) if n.has_meta("prop") else chave_mm(mm.mesh, n))
				if not out.has(k2):
					out[k2] = []
				var cnt := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
				var passo := maxi(1, cnt / 40)
				for i in range(0, cnt, passo):
					(out[k2] as Array).append([mm.mesh, mmi.global_transform * mm.get_instance_transform(i), n])
	for c in n.get_children():
		coletar(m, c, out)


