class_name BRMovel
extends BRLoot
## Móvel com saque (armário, guarda-roupa, cômoda, estante, geladeira, criado-mudo, bancada — modelos do pack props interiores): fica dentro das casas (criado em Moveis.instalar).
## O jogador segura E por 1 s (barra circular); ao completar, o conteúdo é sorteado AGORA (sistema aleatório) e vai para a mochila.
## O que não couber fica dentro (abra [I]). Cada móvel só abre uma vez por partida.

const TEMPO_ABRIR := 1.0
const NOMES := {"armario_alto": "Armário", "armario_baixo": "Armário", "guarda_roupa": "Guarda-roupa", "comoda": "Cômoda",
	"cristaleira": "Cristaleira", "estante": "Estante", "geladeira": "Geladeira",
	# pack "props interiores" (core/moveis.gd DEPARA): tipo = nome do modelo; família = sem o número final
	"Closet_01": "Estante", "Closet_02": "Guarda-roupa", "Kitchen_D_01": "Balcão", "Kitchen_D": "Armário",
	"Nightstand": "Criado-mudo", "Fridge": "Geladeira", "Work_Table": "Bancada", "Wash_Basin": "Armarinho do banheiro"}
## Tabela por tipo de móvel: [peso_vazio, peso_municao, peso_pistola, peso_granada, peso_colete, peso_rifle, peso_mochila, peso_cura]
const TABELA := {
	"armario_alto": [34, 30, 14, 8, 0, 4, 4, 8],
	"armario_baixo": [34, 30, 14, 8, 0, 4, 4, 8],
	"guarda_roupa": [30, 18, 10, 6, 0, 6, 14, 8],
	"comoda": [36, 28, 14, 8, 0, 3, 6, 8],
	"cristaleira": [46, 18, 10, 4, 0, 2, 2, 6],
	"estante": [40, 22, 12, 6, 0, 3, 6, 6],
	"Closet_01": [40, 22, 12, 6, 0, 3, 6, 6],
	"Closet_02": [30, 18, 10, 6, 0, 6, 14, 8],
	"Kitchen_D_01": [46, 18, 10, 4, 0, 2, 2, 8],
	"Kitchen_D": [34, 30, 14, 8, 0, 4, 4, 8],
	"Nightstand": [38, 30, 22, 6, 0, 0, 4, 16],
	"Fridge": [55, 25, 6, 10, 0, 0, 4, 6],
	"Work_Table": [30, 32, 16, 8, 4, 6, 4, 8],
	"Wash_Basin": [60, 30, 10, 0, 0, 0, 0, 20],
}
## Peso extra do saque de comida/bebida por móvel (9ª coluna da tabela): cozinha e geladeira têm muito mais.
const PESO_COMIDA := {"Fridge": 70, "geladeira": 70, "Kitchen_D_01": 55, "Kitchen_D": 50, "armario_alto": 30, "armario_baixo": 30,
	"cristaleira": 30, "Work_Table": 12, "Nightstand": 14, "comoda": 8, "estante": 6, "Closet_01": 6, "guarda_roupa": 4, "Closet_02": 4, "Wash_Basin": 4}
## [id, peso] do que sai quando o móvel dá comida; geladeira/cozinha favorecem refeição e bebida.
const COMIDAS := [["lata_comida", 16], ["feijao_lata", 12], ["sardinha", 12], ["frutas", 12], ["barra_cereal", 10], ["chocolate", 6],
	["garrafa_agua", 16], ["refrigerante", 10], ["carne_crua", 3], ["carne_cozida", 3], ["cantil", 3]]
const PISTOLAS := [&"glock", &"usp"]
const RIFLES := [&"ak47", &"m4", &"mosin", &"uzi", &"m249", &"m107"]
const MOCHILAS := ["backpack_small", "backpack_small", "backpack_medium"]

var tipo := ""
var aberto := false
var nome_exibido := "Armário"


func setup_movel(t: String) -> void:
	tipo = t
	nome_exibido = String(NOMES.get(t, NOMES.get(Moveis.familia(t), "Móvel")))
	contents = BRInventory.make_loot_container(4)
	contents.changed.connect(_refresh)
	add_to_group("loot")


## Sorteio do conteúdo (chamado ao abrir). Máximo 2 itens.
func sortear() -> void:
	var w: Array = (TABELA.get(tipo, TABELA.get(Moveis.familia(tipo), TABELA["armario_baixo"])) as Array).duplicate()
	w.append(int(PESO_COMIDA.get(tipo, PESO_COMIDA.get(Moveis.familia(tipo), 8))))   # índice 8 = comida/bebida
	var total := 0
	for x in w:
		total += int(x)
	var r := randi() % total
	var k := 0
	for i in w.size():
		r -= int(w[i])
		if r < 0:
			k = i
			break
	match k:
		1:
			var cal: Array = [["ammo_9mm", 24 + randi() % 28], ["ammo_762", 20 + randi() % 21], ["ammo_556", 20 + randi() % 21], ["ammo_127", 5 + randi() % 6]]
			var c: Array = cal[randi() % cal.size()]
			contents.add_item(String(c[0]), int(c[1]))
		2:
			var id: StringName = PISTOLAS[randi() % PISTOLAS.size()]
			var d := BRInventory.definition(String(id))
			contents.add_item(String(id), 1, Vector2i(-1, -1), {"mag": int(d.mag_size)})
			contents.add_item("ammo_9mm", 12 + randi() % 17)
		3:
			contents.add_item("grenade", 1)
		4:
			contents.add_item("vest", 1)
		5:
			var id2: StringName = RIFLES[randi() % RIFLES.size()]
			var d2 := BRInventory.definition(String(id2))
			contents.add_item(String(id2), 1, Vector2i(-1, -1), {"mag": int(d2.mag_size)})
		6:
			contents.add_item(MOCHILAS[randi() % MOCHILAS.size()], 1)
		7:
			if randf() < 0.15:   # kit médico é raro; o comum é bandagem
				contents.add_item("kit_medico", 1)
			else:
				contents.add_item("bandagem", 1 + randi() % 3)
		8:
			var tot := 0
			for c in COMIDAS:
				tot += int(c[1])
			var r2 := randi() % tot
			for c in COMIDAS:
				r2 -= int(c[1])
				if r2 < 0:
					contents.add_item(String(c[0]), 1 + (randi() % 2 if c[0] in ["lata_comida", "feijao_lata", "sardinha", "barra_cereal", "frutas"] else 0))
					break


## Abre: sorteia, tenta passar tudo para a mochila e devolve a lista de nomes achados (vazia = móvel vazio).
func abrir_para(bag: BRInventory) -> Array:
	aberto = true
	sortear()
	var achados: Array = []
	for it in contents.items:
		achados.append(String(BRInventory.definition(String(it.id)).get("name", it.id)) + (" x%d" % int(it.qty) if int(it.qty) > 1 else ""))
	take_all(bag)
	_balanco()
	return achados


## Abre sem passar nada para a mochila (o inventário mostra o conteúdo em PROXIMIDADE).
func abrir_sem_pegar() -> void:
	aberto = true
	sortear()
	_balanco()


func _balanco() -> void:
	var mi := get_parent().get_node_or_null("Moveis") as Node3D
	if mi == null:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 1.03, 1.0), 0.08)
	tw.tween_property(self, "scale", Vector3.ONE, 0.12)


func _refresh() -> void:
	pass   # móvel não some quando esvazia (o jogador vê "vazio")


func _build_visual() -> void:
	pass   # o móvel já é o visual
