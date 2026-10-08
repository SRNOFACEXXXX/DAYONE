class_name EscadaVertical
extends Area3D
## Escada vertical de 90° (escada de mão / marinheiro): torres de vigia, caixa d'água, mirante, guarita...
## Os modelos (tools/*.py, Kit.escada_mao) trazem dois Empties: ESCADA_<id>_base (onde o jogador fica no pé da
## escada), ESCADA_<id>_topo (onde ele desembarca, sobre a plataforma) e ESCADA_<id>_face (ponto sobre os degraus: o corpo olha para ele). Este Area3D "Escada" é criado por
## EscadaVertical.instalar() em cada prédio/marco; o Soldier detecta a área (escadas_perto), o PlayerController
## mostra "E — subir/descer" e o Soldier faz a subida (gravidade desligada, W/S, câmera em 3ª pessoa).

var base_local := Vector3.ZERO     # no espaço local deste nó (filho do corpo do prédio)
var topo_local := Vector3.ZERO
var face_local := Vector3.ZERO     # ponto sobre os degraus (define para onde o corpo olha enquanto escala)
var tem_face := false


## Varre a cena instanciada de um modelo e cria um Area3D "Escada" para cada par ESCADA_<id>_base/_topo.
static func instalar(corpo: Node3D, cena: Node3D) -> int:
	var bases := {}
	var topos := {}
	var faces := {}
	for n in cena.find_children("ESCADA_*", "Node3D", true, false):
		var nome := String(n.name)
		var id := nome.get_slice("_", 1)
		var p: Vector3 = corpo.global_transform.affine_inverse() * (n as Node3D).global_position
		if nome.ends_with("_base"):
			bases[id] = p
		elif nome.ends_with("_topo"):
			topos[id] = p
		elif nome.ends_with("_face"):
			faces[id] = p
	var criadas := 0
	for id in bases:
		if not topos.has(id):
			continue
		var e := EscadaVertical.new()
		e.name = "Escada" if criadas == 0 else "Escada%d" % (criadas + 1)
		e.base_local = bases[id]
		e.topo_local = topos[id]
		if faces.has(id):
			e.face_local = faces[id]
			e.tem_face = true
		e.collision_layer = Soldier.LAYER_TRIGGER
		e.collision_mask = Soldier.LAYER_SOLDIER
		e.monitoring = true
		e.monitorable = false
		corpo.add_child(e)
		# caixa de interação no pé (subir) e outra na plataforma (descer)
		e._forma(e.base_local + Vector3(0, 1.0, 0), Vector3(1.6, 2.4, 1.6))
		e._forma(e.topo_local + Vector3(0, 0.9, 0), Vector3(1.8, 2.0, 1.8))
		e.body_entered.connect(e._entrou)
		e.body_exited.connect(e._saiu)
		e.add_to_group("escadas_verticais")
		criadas += 1
	return criadas


func _forma(centro: Vector3, tam: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	cs.position = centro
	add_child(cs)


func _entrou(b: Node3D) -> void:
	if b is Soldier and not (b as Soldier).escadas_perto.has(self):
		(b as Soldier).escadas_perto.append(self)


func _saiu(b: Node3D) -> void:
	if b is Soldier:
		(b as Soldier).escadas_perto.erase(self)


func base_world() -> Vector3:
	return global_transform * base_local


func topo_world() -> Vector3:
	return global_transform * topo_local


## Direção horizontal para a qual o corpo olha enquanto escala (do pé da escada para a plataforma).
func frente() -> Vector3:
	var d := (global_transform * face_local - base_world()) if tem_face else (topo_world() - base_world())
	d.y = 0.0
	if d.length() < 0.05:
		return -global_transform.basis.z
	return d.normalized()


## Ponto da linha de subida na altura y (vertical sobre o pé da escada).
func linha_world(y: float) -> Vector3:
	var b := base_world()
	return Vector3(b.x, y, b.z)


## Rótulo do prompt conforme o corpo está embaixo ("subir") ou na plataforma ("descer").
func rotulo_para(s: Soldier) -> String:
	var meio := (base_world().y + topo_world().y) * 0.5
	return "E — descer" if s.global_position.y > meio else "E — subir"
