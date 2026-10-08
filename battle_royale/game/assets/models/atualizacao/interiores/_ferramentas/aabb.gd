extends SceneTree
## Ferramenta: AABB (quadro local do móvel) dos móveis antigos e dos novos, e das peças da cozinha da casa_demo.
## godot --headless --path game -s res://assets/models/atualizacao/interiores/_ferramentas/aabb.gd
func _aabb(p: String) -> Array:
	var sc: Node3D = (load(p) as PackedScene).instantiate()
	var tot := AABB()
	var first := true
	var partes := {}
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != sc:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
		partes[String(mi.name)] = [bb.position.x, bb.position.y, bb.position.z, bb.size.x, bb.size.y, bb.size.z]
		tot = bb if first else tot.merge(bb)
		first = false
	sc.free()
	return [[tot.position.x, tot.position.y, tot.position.z, tot.size.x, tot.size.y, tot.size.z], partes]
func _init() -> void:
	var r := {"antigos": {}, "novos": {}, "casa": {}}
	for f in DirAccess.get_files_at("res://assets/models/moveis/"):
		if f.ends_with(".glb"):
			r.antigos[f.get_basename()] = _aabb("res://assets/models/moveis/" + f)[0]
	for f in DirAccess.get_files_at("res://assets/models/atualizacao/interiores/"):
		if f.ends_with(".glb"):
			r.novos[f.get_basename()] = _aabb("res://assets/models/atualizacao/interiores/" + f)[0]
	r.casa = _aabb("res://assets/models/cenario/casas/casa_demo.glb")[1]
	var fa := FileAccess.open("res://assets/models/atualizacao/interiores/_ferramentas/aabb.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(r, " "))
	fa.close()
	print("AABB_OK")
	quit()
