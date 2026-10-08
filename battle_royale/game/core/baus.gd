class_name Baus
extends RefCounted
## Persistência dos baús de base. A construção do jogador ainda não é salva em disco; este dicionário serializável
## (compatível com JSON/var_to_str) é o ponto de ligação: guarde-o junto das peças e chame restaurar() no carregamento.
##   {"v": 1, "baus": [{"x": f, "y": f, "z": f, "yaw": f, "inv": BRInventory.snapshot()}, ...]}

static func serializar() -> Dictionary:
	var lista: Array = []
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore:
		for n in arvore.get_nodes_in_group("bau"):
			var b := n as StorageChest
			if b == null or not is_instance_valid(b) or b.contents == null:
				continue
			var raiz := b.get_parent() as Node3D
			var xf := raiz.global_transform if raiz else b.global_transform
			lista.append({"x": xf.origin.x, "y": xf.origin.y, "z": xf.origin.z, "yaw": xf.basis.get_euler().y, "inv": b.contents.snapshot()})
	return {"v": 1, "baus": lista}


## Recria os baús (sem custo de material) com o conteúdo salvo. `sistema` é o ConstructionSystem da partida.
static func restaurar(dados: Dictionary, sistema: ConstructionSystem) -> Array:
	var criados: Array = []
	for e in dados.get("baus", []):
		if not e is Dictionary:
			continue
		var xf := Transform3D(Basis(Vector3.UP, float(e.get("yaw", 0.0))), Vector3(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("z", 0.0))))
		var b := sistema.colocar_bau(xf, e.get("inv", {}))
		if b:
			criados.append(b)
	return criados
