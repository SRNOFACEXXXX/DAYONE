# Inventário BR — integração

`BRInventory` é um `RefCounted` sem dependência do `Soldier` ou do mapa. Guarde **a mesma instância** no controlador da partida/jogador; abrir e fechar a UI não recria nem apaga os itens. IDs de munição: `ammo_762`, `ammo_9mm`, `ammo_556`. O calibre das armas é consultado por `BRInventory.definition(weapon_id).caliber` e mapeado por `BRInventory.ammo_id_for_caliber(caliber)`.

```gdscript
var player_inventory := BRInventory.new()
var nearby_loot := BRInventory.make_loot_container() # grade 6 × 8; peso quase ilimitado
nearby_loot.add_item("ak47", 1, Vector2i(-1, -1), {"mag": 5})
nearby_loot.add_item("ammo_762", 45)
nearby_loot.add_item("backpack_medium")
nearby_loot.add_item("acog")

var inventory_ui := preload("res://ui/br_inventory_ui.tscn").instantiate() as BRInventoryUI
hud.add_child(inventory_ui) # adicione à árvore antes de abrir
inventory_ui.open(player_inventory, nearby_loot)
# inventory_ui.close() restaura o modo anterior do mouse.
```

`add_item(id, quantity := 1, at := Vector2i(-1, -1), extra := {}) -> int` retorna o número aceito, limitado por grade, pilha e peso. `extra` aceita `mag` (cartuchos já no carregador) e `acog` para armas; uma arma nova começa descarregada. `get_item(uid)` e `item_at(cell)` retornam cópias dos registros `{uid, id, qty, x, y, mag, acog}`. `move_item(uid, cell) -> bool`, `remove_item(uid, quantity := -1) -> int` e `transfer_to(target, uid, quantity := -1, at := Vector2i(-1, -1)) -> int` alteram o estado e emitem `changed`. Uma transferência parcial retira da origem apenas a quantidade que coube no destino.

`equip_backpack(uid) -> bool` equipa uma mochila do inventário. Ela adiciona linhas à grade e capacidade de peso; só uma mochila pode estar equipada. `rows()`, `capacity_kg()` e `weight_kg()` expõem os limites atuais. As definições de mochila têm `model_path = "res://assets/models/props/tactical_backpack.glb"` para o visual do loot no mundo; o modelo foi copiado para dentro do projeto. A grade da UI usa um cartão leve com o nome e o espaço adicional.

`attach_acog(scope_uid, weapon_uid) -> bool` instala uma mira numa arma carregada pelo inventário. `count_ammo(caliber) -> int` conta cartuchos soltos; `take_ammo(caliber, count) -> int` retira até a quantidade disponível; `reload_weapon(weapon_uid) -> int` transfere cartuchos compatíveis para o carregador, sem gerar reserva; `fire_round(weapon_uid) -> bool` consome um cartucho carregado. AK-47 usa 7,62; M4 usa 5,56; Glock e USP usam 9 mm. A munição carregada também entra no cálculo do peso.

```gdscript
# Conectar ao combate existente sem alterar WeaponDB:
var gun := player_inventory.get_item(weapon_uid)
var definition := BRInventory.definition(String(gun.id))
var weapon_def := WeaponDB.get_def(StringName(gun.id))
var loaded := player_inventory.reload_weapon(weapon_uid)
if player_inventory.fire_round(weapon_uid):
	# Aplicar um disparo de weapon_def no sistema de combate.
	pass
```

O estado do inventário é separado do `WeaponState` atual. A integração do disparo/recarregamento do `Soldier` deve chamar as operações acima para que a contagem na grade seja a fonte de verdade. Para persistir durante respawn ou reconstrução da partida, use `var save := player_inventory.snapshot()` e `player_inventory.restore(save)`.

Teste isolado: `godot --headless --path game res://tests/br_inventory_check.tscn`.

## Curas (`kind: "heal"`)

`bandagem` (comum, +25 HP em 2,5 s) e `kit_medico` (raro, +60 HP em 5 s, estanca o sangramento) estão em `BRInventory.DEFINITIONS` (`heal`, `time`, `stop_bleed`). API do soldado: `Soldier.usar_cura(item_id) -> bool` (false se não há o item, vida cheia sem sangramento, já curando ou id inválido), `usar_cura_auto()` (tecla **H**: kit se sangra, senão bandagem), `cura_cancelar(motivo)`, `cura_ativa()`, `cura_progresso()` (0..1), `iniciar_sangramento()`/`sangrando`. A vida respeita `Soldier.MAX_HEALTH`; o item só é consumido ao terminar. Só atirar (`fired`/`in_fire`) ou trocar de arma interrompem; mover e levar dano não. O item sai de `match_ref.br_bag` (jogador local) ou de `soldier.cura_bag` (bots/testes; sem nenhum dos dois a cura é grátis). Sinais: `cura_started`, `cura_finished(id, healed)`, `cura_cancelled(id, motivo)`. Atalhos 1–5 e duplo clique no inventário também usam a cura.

## Baú de base (`StorageChest`)

Peça `chest` da roda de construção (B). Grade 6 × 8 sem limite de peso. `E` perto do baú abre o inventário com o conteúdo em PROXIMIDADE (painel titulado BAÚ); soltar um item da mochila nessa coluna guarda no baú. API: `depositar(item_id, qtd := 1, extra := {}) -> int`, `retirar(item_id, qtd := 1) -> int`, `retirar_para(bag, item_id, qtd)`, `contar(item_id) -> int`, `itens() -> Array[{id, qty}]`, `abrir_para(soldier) -> bool` (alcance 3,2 m), `derrubar_itens(match)`. Remover o baú com X derruba os itens no chão (a peça não some se a partida não sabe criar drops). Persistência: `Baus.serializar() -> Dictionary` (JSON-safe) e `Baus.restaurar(dados, construction_system)`; `ConstructionSystem.colocar_bau(transform, snapshot)` cria um baú direto. Teste: `res://tests/base_bau_cura.tscn`.
