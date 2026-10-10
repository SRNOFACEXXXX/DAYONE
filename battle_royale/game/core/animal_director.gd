extends Node3D
## Animais por perto do jogador (GT 730: poucos e só perto). Nasce fora da vista, a 70–170 m; some além de 260 m.
## Bioma simples: perto das vilas (centros do ZombieDirector) galinhas e cachorros; no mato cervos (manada 1–3);
## à noite (Clima) uma matilha de 2 lobos. Carcaça: E perto com FACA no inventário esfola -> itens no chão.
## Sem class_name (preload em maps/ilha/ilha.gd).

const ANIMAL := preload("res://core/animal.gd")
const MAX_VIVOS := 9
const NASCE_MIN := 70.0
const NASCE_MAX := 170.0
const SOME := 260.0
const DORME := 110.0

var terrain: Node
var cidades: Array[Vector3] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _dica: Label3D


func setup(terreno: Node, centros: Array[Vector3]) -> void:
	terrain = terreno
	cidades = centros
	_rng.randomize()


func _jogador() -> Soldier:
	var m = Game.current_match
	if m and is_instance_valid(m) and "local_player" in m and is_instance_valid(m.local_player):
		return m.local_player
	return null


func _noite() -> bool:
	return Clima.e_noite()   # autoload


func _perto_de_vila(p: Vector3) -> bool:
	for c in cidades:
		if Vector2(c.x - p.x, c.z - p.z).length() < 90.0:
			return true
	return false


func _process(dt: float) -> void:
	var p := _jogador()
	if p == null or terrain == null:
		return
	_esfolar_input(p)
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	var vivos := 0
	var lobos := 0
	for a in get_children():
		if not a is CharacterBody3D:
			continue
		var d: float = (a as Node3D).global_position.distance_to(p.global_position)
		if d > SOME:
			a.queue_free()
			continue
		var acordado: bool = d < DORME
		a.set_physics_process(acordado)
		(a as Node3D).visible = d < 140.0
		if a.state != ANIMAL.DEAD:
			vivos += 1
			if a.especie == "lobo":
				lobos += 1
	if vivos >= MAX_VIVOS:
		return
	# escolhe um ponto e o tipo pelo lugar
	var cam := get_viewport().get_camera_3d()
	for tentativa in 6:
		var ang := _rng.randf_range(-PI, PI)
		var dist := _rng.randf_range(NASCE_MIN, NASCE_MAX)
		var pos := p.global_position + Vector3(cos(ang), 0, sin(ang)) * dist
		var h := float(terrain.height_world(pos.x, pos.z))
		if h < 1.2:
			continue   # mar/água
		pos.y = h + 0.2
		if cam and cam.is_position_in_frustum(pos + Vector3.UP) and dist < 120.0:
			continue
		var especie := "cervo"
		var qtd := _rng.randi_range(1, 3)
		if _perto_de_vila(pos):
			especie = "galinha" if _rng.randf() < 0.75 else "cachorro"
			qtd = 3 if especie == "galinha" else 1
		elif _noite() and lobos < 2 and _rng.randf() < 0.5:
			especie = "lobo"
			qtd = 2
		for k in qtd:
			var a := ANIMAL.new()
			a.configurar(especie, terrain)
			a.name = "%s_%d" % [especie, Time.get_ticks_msec() % 100000 + k]
			add_child(a)
			a.global_position = pos + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
			a.rotation.y = _rng.randf_range(-PI, PI)
		return


func _esfolar_input(p: Soldier) -> void:
	var alvo: Node3D = null
	for a in get_tree().get_nodes_in_group("carcaca"):
		if (a as Node3D).global_position.distance_to(p.global_position) < 2.2:
			alvo = a
			break
	if _dica == null:
		_dica = Label3D.new()
		_dica.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_dica.font_size = 26
		_dica.pixel_size = 0.0028
		_dica.outline_size = 8
		add_child(_dica)
	var m = Game.current_match
	var bag: BRInventory = m.br_bag if m and "br_bag" in m else null
	var tem_faca := (bag != null and _conta(bag, "faca") > 0) or p.inventory.has(WeaponDef.Slot.KNIFE)   # faca do inventário ou a faca de combate
	_dica.visible = alvo != null
	if alvo == null:
		return
	_dica.global_position = alvo.global_position + Vector3.UP * 0.9
	_dica.text = "[E] Esfolar" if tem_faca else "Precisa de uma FACA para esfolar"
	if Input.is_action_just_pressed("use") and tem_faca:
		var r: Dictionary = alvo.esfolar(true)
		var i := 0
		for id in r:
			if m.has_method("criar_drop"):
				var ang := TAU * i / maxf(r.size(), 1)
				m.criar_drop(String(id), int(r[id]), alvo.global_position + Vector3(cos(ang), 0, sin(ang)) * 0.7)
			i += 1
		if Audio.has_sound("loot_open"):
			Audio.play("loot_open", {"volume_db": -6.0})


static func _conta(bag: BRInventory, id: String) -> int:
	var n := 0
	for it in bag.items:
		if String(it.id) == id:
			n += int(it.qty)
	return n
