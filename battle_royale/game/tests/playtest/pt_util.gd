extends RefCounted
## Utilidades compartilhadas pelas etapas do playtester.


static func v3(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]


## Equipa a arma pela mochila do jogo (mesmo caminho do inventário): remove armas longas, adiciona a pedida + munição.
static func equipa(c, arma: String) -> bool:
	var m: BRMatch = c.m
	var bag: BRInventory = m.br_bag
	for it in bag.items.duplicate():
		if String(it.id) in ["m4", "m249", "m107", "ak47", "uzi", "reddot", "acog", "mosin", "glock", "usp"]:
			bag.remove_item(int(it.uid))
	var def: WeaponDef = WeaponDB.get_def(StringName(arma))
	if def == null:
		return false
	bag.add_item(arma, 1, Vector2i(-1, -1), {"mag": def.mag_size})
	var cal := String(BRInventory.definition(arma).get("caliber", ""))
	if cal != "":
		bag.add_item(BRInventory.ammo_id_for_caliber(cal), 60)
	var uid := -1
	for it in bag.items:
		if String(it.id) == arma:
			uid = int(it.uid)
	if uid < 0:
		return false
	m._equip_br_weapon(uid)
	return true


## Menor distância 2D de p a uma polilinha (lista de [x, y_norte, ...]); converte y_norte -> z = -y.
static func dist_polilinha(p: Vector3, pts: Array) -> float:
	var best := INF
	var q := Vector2(p.x, p.z)
	for i in range(pts.size() - 1):
		var a := Vector2(float(pts[i][0]), -float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), -float(pts[i + 1][1]))
		var cp := Geometry2D.get_closest_point_to_segment(q, a, b)
		best = minf(best, q.distance_to(cp))
	return best


static func ponto_polilinha(p: Vector3, pts: Array) -> Vector3:
	var best := INF
	var res := Vector3.INF
	var q := Vector2(p.x, p.z)
	for i in range(pts.size() - 1):
		var a := Vector2(float(pts[i][0]), -float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), -float(pts[i + 1][1]))
		var cp := Geometry2D.get_closest_point_to_segment(q, a, b)
		var d := q.distance_to(cp)
		if d < best:
			best = d
			res = Vector3(cp.x, 0.0, cp.y)
	return res


## Raio horizontal a `h` m do chão; devolve a distância livre (alcance se não bater).
static func livre(c, de: Vector3, dir: Vector3, alcance: float, h := 1.4) -> float:
	var space = c.ilha.get_world_3d().direct_space_state
	var o := de + Vector3.UP * h
	var q := PhysicsRayQueryParameters3D.create(o, o + dir.normalized() * alcance, 1)
	var hit: Dictionary = space.intersect_ray(q)
	return o.distance_to(hit.position) if not hit.is_empty() else alcance


static func melhor_direcao(c, de: Vector3, alcance := 90.0) -> Dictionary:
	var best := {"dir": Vector3.FORWARD, "livre": -1.0}
	for i in 16:
		var a := TAU * float(i) / 16.0
		var d := Vector3(sin(a), 0.0, cos(a))
		var l := livre(c, de, d, alcance)
		# declive suave ao longo do trecho
		var h0: float = c.terr.height_world(de.x, de.z)
		var h1: float = c.terr.height_world(de.x + d.x * 40.0, de.z + d.z * 40.0)
		var pen := absf(h1 - h0) * 1.5
		if l - pen > float(best.livre):
			best = {"dir": d, "livre": l - pen}
	return best


static func yaw_de(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## Chão firme perto de `centro`: física ~ terreno (não é telhado/prop), plano e com `livre_min` m de visada numa direção.
static func ponto_plano(c, centro: Vector3, livre_min := 62.0) -> Dictionary:
	for r in [0.0, 10.0, 20.0, 35.0, 50.0, 70.0, 100.0, 140.0]:
		for k in (1 if r == 0.0 else 12):
			var a := TAU * float(k) / 12.0
			var x: float = centro.x + cos(a) * r
			var z: float = centro.z + sin(a) * r
			var ht: float = c.terr.height_world(x, z)
			if ht < 1.5:
				continue
			var hf: float = c.chao_em(x, z, ht + 40.0)
			if absf(hf - ht) > 0.3:
				continue
			if absf(c.terr.height_world(x + 2.0, z) - ht) > 0.5 or absf(c.terr.height_world(x, z + 2.0) - ht) > 0.5:
				continue
			var p := Vector3(x, hf, z)
			var bd: Dictionary = melhor_direcao(c, p, livre_min + 8.0)
			if float(bd.livre) >= livre_min:
				return {"pos": p, "dir": bd.dir, "livre": bd.livre, "raio_busca": r}
	return {}
