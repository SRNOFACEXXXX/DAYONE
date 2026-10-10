extends Node
## Converte as FBX do pacote Lowpoly Objects (assets/_src_props, importadas pelo Godot) em GLB normalizados para o jogo:
## maior dimensão = tamanho real em metros, centro no XZ e base em Y=0, atlas embutido. Saída: assets/models/itens/props/<id>.glb
## Rodar:  Godot --path game res://tools/gd/converter_props.tscn   (depois apagar assets/_src_props)
const ALVO := {
	"baby_rake": 0.55, "backpack": 0.5, "bitcoin": 0.08, "bomb": 0.28, "bottle": 0.26, "bowl": 0.16, "crown": 0.2, "dice_blue": 0.04,
	"diver_mask": 0.22, "dynamite": 0.24, "frying_pan": 0.42, "hat": 0.30, "headphones": 0.2, "hex_wrench_set": 0.13, "idol": 0.22,
	"piggy_bank": 0.16, "pot": 0.25, "smartphone": 0.15, "smiley": 0.1, "soccer_boot": 0.28, "steering_wheel": 0.38, "tape": 0.1,
	"telescopic_ladder": 0.85, "tower_ruler": 0.3, "water_mine": 0.35, "watering_can": 0.36, "wheel": 0.62,
}
const SAIDA := "res://assets/models/itens/props/"


func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is MeshInstance3D:
		var b: AABB = xf * (n as MeshInstance3D).get_aabb()
		acc[0] = b if acc[1] == false else (acc[0] as AABB).merge(b)
		acc[1] = true
	for c in n.get_children():
		if c is Node3D:
			_aabb(c, xf * (c as Node3D).transform, acc)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	for f in DirAccess.get_files_at("res://assets/_src_props"):
		var nome := f.trim_suffix(".import")
		if not nome.ends_with(".fbx"):
			continue
		var id := nome.get_basename()
		if not ALVO.has(id) or FileAccess.file_exists(SAIDA + id + ".glb"):
			continue
		var cena := load("res://assets/_src_props/" + nome) as PackedScene
		if cena == null:
			print("PROPS falhou carregar ", nome)
			continue
		var src: Node3D = cena.instantiate()
		var acc: Array = [AABB(), false]
		_aabb(src, Transform3D.IDENTITY, acc)
		var ab: AABB = acc[0]
		var maior := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		var k: float = float(ALVO[id]) / maxf(maior, 0.0001)
		var raiz := Node3D.new()
		raiz.name = id
		raiz.add_child(src)
		src.scale = Vector3.ONE * k
		src.position = Vector3(-(ab.position.x + ab.size.x * 0.5) * k, -ab.position.y * k, -(ab.position.z + ab.size.z * 0.5) * k)
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		var e := doc.append_from_scene(raiz, st)
		var e2 := doc.write_to_filesystem(st, ProjectSettings.globalize_path(SAIDA + id + ".glb")) if e == OK else e
		print("PROPS %s dim=%s k=%.4f -> %s (%d)" % [id, ab.size, k, "ok" if e2 == OK else "erro", e2])
		raiz.free()
	print("PROPS_FIM")
	get_tree().quit()
