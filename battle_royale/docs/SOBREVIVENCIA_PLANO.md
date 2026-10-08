# Plano — Ilha Brava vira jogo de sobrevivência (DayZ/Rust), 2026-09-30

Referências visuais (prioridade máxima): `docs/ref/` — personagem.jpg, menu_inventario.jpg, ak47_fps.jpg, mosin_lowpoly.png.
Mesmo mapa (Ilha do Tauá). Meta: 60 FPS em 1024x768 (GT 730, Compatibility). Nada procedural; dados autorais.

## Trilhas
- [x] **A. Modo sobrevivência** (br_match.gd, hud.gd): remover zona/gás, minimapa, placar, cronômetro, killfeed, contagem de vivos, avião/paraquedas; jogador nasce perto de uma cidade (Vila), equipado só com o básico. Morte → respawn na cidade.
- [x] **B. Vida e colete**: regen lenta só após 2 min sem combate; colete de placas (3 placas, pegar dá 2, indicador, B repõe com efeito azul, 3 barras); asset low poly do colete no chão.
- [x] **C. Construções** (feito 2026-09-30, ver "Trilhas C/E" abaixo): colisão fiel ao modelo 3D (sem parede invisível), portas passáveis, cercas/muros escaláveis, telhados sem loot; casas com sala, cozinha e quarto mobiliados.
- [~] **D. Loot em caixas**: caixa militar com animação de abrir (explosão neon), arma dentro; granada (tecla G) dentro, máx. 2 itens randomizados; caixas DENTRO de galpões militares, celeiros, casas, containers, perto de veículos.
- [x] **E. Escadas** (feito 2026-09-30, ver "Trilhas C/E" abaixo): subir andando; escada vertical 90° com interação + câmera 3ª pessoa + animação.
- [~] **F. Personagem** (3ª pessoa FEITA; FP passou para a sessão principal): modelo igual ao personagem.jpg (capacete verde, lenço vermelho, camuflagem geométrica, colete, rádio, mochila); mãos e braços FP conforme ak47_fps.jpg.
- [~] **G. Armas e animações** (Mosin 3ª pessoa + modelo corrigido FEITOS; FP/ADS na sessão principal): AK-47 e Mosin (segurar, correr, atirar, recarregar, ADS sem 2 miras); animações Mixamo quando o usuário liberar o download.
- [x] **H. Menu**: igual a menu_inventario.jpg (cabeçalho amarelo, painéis escuros, personagem 3D ao centro, hotbar 1–7, status).
  - Feito (2026-09-30): `ui/main_menu.gd` (diorama 3D vivo em SubViewport: venda_bar_a verde, galpao_a, cerca, árvores, capim, soldado idle; painéis JOGAR / EQUIPAMENTO com AK-47 renderizada, hotbar 1–7, estamina e status); `ui/br_inventory_ui.gd` (PROXIMIDADE | soldado 3D + "mão | EQUIPADO" | EQUIPAMENTO F1–F4 + COLETE DE CAMPO/MOCHILA; itens vest/grenade/plate com ícone em código); Quickbar de `ui/hud.gd` com 7 slots (1–4 armas/F1–F4, 5 granada, 6 placas, 7 colete; ativo em amarelo).
  - Novos: `ui/yui.gd` (cores/slots/vidro translúcido com blur), `ui/ypanel.gd` (painel com cabeçalho amarelo), `ui/menu_stage.gd` (cena 3D; **modelo do soldado em `MenuStage.SOLDIER_PATHS`**, troque só ali), `ui/item_icons.gd` (ícones em código + miniaturas das armas renderizadas uma vez; Mosin usa silhueta em código porque o .glb não gera miniatura legível).
  - Teste: `tests/menu_capture.tscn -- --out=pasta [--w=1280 --h=720] [--inv=1] [--qb=1] [--icons=1]` (capturas + FPS). Medido: menu 60–100 FPS, inventário 54–88 FPS (oscila com outros processos Godot rodando; o diorama de fundo do teste também é renderizado).
  - Pendências: cabeçalho da mochila usa ícone fixo; slots F1–F4 só mostram armas atribuídas; vest no inventário só informa (vestir continua no fluxo de recolher do br_match).

## Registro (sessão principal)
- A/B feitos: BRMatch agora é sobrevivência (sem avião, zona, placar, cronômetro, radar, killfeed; respawn na Vila em 6 s; bots desligados por padrão, `--bots=N` liga). Soldier: regen +1 HP/1,2 s após 120 s sem combate; colete (`give_vest` = 2 placas), B encaixa placa (1,6 s, +33 de colete, 3 barras azuis no HUD + clarão azul).
- D em andamento: `BRCrate` (tools/build_suprimentos.py: caixa militar corpo+tampa, colete, granada), abre com E (tampa + explosão neon), máx. 2 itens sorteados por nível, tecla G lança granada (`Grenade`). Falta consumir `pontos_loot.json` (trilha C) — sem ele aparecem 4 caixas de teste junto ao spawn. Teste: tests/sv_smoke.tscn (passa).


## Progresso trilhas F/G (soldado 3ª pessoa) — 2026-09-30
- `tools/build_soldado.py` (Blender, à mão, classe `Malha` com bmesh): importa esqueleto + 26 clipes do `counter.glb` (mesmos 44 ossos, compatível com
  BodyModel/ArmsIK/`*_weapon_offsets.json`) e troca a malha (~16 mil tris) por uma de **1.644 tris** (capacete verde-azulado, lenço vermelho, rosto simples,
  jaqueta/calça com camuflagem "mata geométrica", colete com 6 bolsos, rádio com antena, pouch, cinto, mochila com correias e saco de dormir, botas, mãos de 2 falanges).
  Camuflagem = `soldado_camo.png` (256x256 tileável, triângulos de tabela literal no script, sem ruído) + `soldado_paleta.png` (64x32). 2 materiais no total.
  Saídas: `game/assets/models/characters/soldado.glb`, `soldado_camo.png`, `soldado_paleta.png`, `soldado_weapon_offsets.json`.
- `body_model.gd`: `SOLDIER_FOR_ALL := true` (static var) faz jogador e bots usarem o soldado; `false` volta aos modelos por time. `br_match.gd` intocado.
  Pegada 3ª pessoa do Mosin (`GRIPS[&"mosin"]`, `WEAPON_SCALE` 0,75 porque o modelo tem 1,74 m) e marcador `Muzzle` em `mosin.tscn`.
- `tools/build_mosin_lp.py`: o `mosin.glb` antigo saía com cano/ótica na vertical (cilindros girados 90° duas vezes) e materiais cinza padrão; refeito com madeira laranja e
  metal azul-acinzentado como em `mosin_lowpoly.png`.
- Testes novos: `tests/soldado_turntable.tscn` (frontal/lateral/traseira/busto, compara com personagem.jpg), `tests/soldado_poses.tscn` (parado/corrida/agachado/recarga/tiro com AK e Mosin, 3ª pessoa),
  `tests/fp_capture.tscn` e `tests/fp_lab.tscn` (1ª pessoa). Capturas em `raw/soldado`, `raw/soldado_poses`, `raw/fp_soldado`.
- FPS (`br_perf --chao --bots=11`, 1024x768 na GT 730): bots parados 73–85 fps com o soldado vs 80–81 com os modelos antigos; draw calls 903 vs 972. A variação dos bots ativos (42–84) é ruído do comportamento dos bots, não do modelo.
- Pendências: clipes Mixamo continuam sem retarget (não promover antes do portão de qualidade de LOCOMOCAO_REFERENCIAS.md); mãos do soldado com poucas faces (refinar); pose A de repouso larga (só aparece no turntable);
  FP: ver resumo (arms swap em `viewmodel.gd` feito antes da troca de escopo).


## Trilhas C/E (construções e escadas) — 2026-09-30
**Colisão fiel (C1).** `ilha.gd::_collision_for` e `detalhes.gd` deixaram de usar casco convexo: coberturas, cercas, muros, portões, postes e props usam `trimesh`
(`backface_collision = true`); só as 3 placas de identificação (10 mil triângulos) seguem convexas. Prédios já eram trimesh (o bloqueio das portas vinha da malha, ver C2).
`Soldier` ganhou **escalar (mantle)**: pular encostado em muro/cerca/caixa de 0,5 a 1,65 m (medido do chão, não do ar) sobe e passa por cima, em cima se o topo for largo
(`_tentar_mantle`: varredura da cápsula acha cerca de ripas/arame, pouso em cima ou do outro lado, sem pisar em vão fechado). `muro_alto` (2,3 m) continua intransponível.
`_try_step` corrigido: avanço mínimo de 14 cm por tique (parado ao pé de uma escada a velocidade nunca passava de ~0,5 m/s e a cápsula não subia) e sobe o vão livre disponível
(teto baixo junto à escada não impede degrau de 20 cm).
**Portas e interiores (C2/C3).** `tools/build_predios.py` (+ `predios_lote2..4.py`, novo `tools/interior.py`): todas as portas com vão >= 1,1 x 2,15 m abertos na malha E na colisão
(achados: a "barra pintada" cobria o vão das casas caiçara/colono/vila e a capela tinha uma "rosácea" que tampava o portal). Folha de porta aberta rente à parede externa.
Toda casa tem SALA, COZINHA e QUARTO mobiliados (sofá, TV, estante, fogão, geladeira, pia, armário, mesa/cadeiras, cama, guarda-roupa...; móveis low poly em `interior.py`,
reutilizando os materiais existentes: nenhum draw call a mais) com divisórias e portas de 1,1 m: casa_laje, casa_caicara, casa_colono, vila_operaria (4 unidades), sobrado (2 andares),
casarao (2 andares, 8 cômodos), casa_faroleiro/piloto/operador, casa_gerador/radio, restaurante, escritório, comando. Galpões/paióis/hangar/garagem/tulha/armazém/moenda/casa de força:
prateleiras, paletes, caixotes, tambores, bancadas; alojamento (beliches), refeitório (mesas e cozinha), container-escritório, venda/bar, rancho.
**Escadas (E).** Degraus <= 0,3 m e largura livre >= 1,1 m em todos os lances (casa_laje ganhou escada externa de 1,2 m fora do beiral da laje; bloco de 2 andares ganhou
patamar de 0,8 m no pé e vão do piso aberto; posto salva-vidas com pé-direito de 2,1 m). Escadas de mão 90° interativas em: guarita, caixa d'água, tanque, farol, antena (3 lances),
antena celular, torre de vigia de madeira, mirante, britador, torre de controle, torre da igreja. Modelos trazem Empties `ESCADA_<id>_base/_topo/_face`;
`core/escada_vertical.gd` cria o `Area3D "Escada"` (base/topo) em `ilha.gd` (prédios e marcos); `Soldier.iniciar_escada/soltar_escada/_subir_escada` (gravidade desligada, W/S,
Espaço ou E solta, entra/sai com deslizamento); `PlayerController` mostra "E — subir/descer", força câmera em 3ª pessoa enquanto escala; `BodyModel._sync_climb`
(pose de "salto" + balanço procedural no ritmo da subida; não há clipe próprio de escalada).
**Pontos de saque.** `docs/design/pontos_loot.json` (cópia em `game/maps/ilha/pontos_loot.json`), gerado por `tools/gerar_pontos_loot.py` a partir dos pontos posicionados à mão
em cada modelo (`tools/_loot/*.json`): 78 prédios, ~260 pontos, tier alto no Quartel/paióis/hangar/garagem/comando; `externos_veiculos` lista pontos junto a caminhão/trator/carcaças.
**Testes.** `tests/ce_construcoes.tscn -- --modo=portas|loot|escadas|mantle|lances [--modelos=a,b]` (terreno plano, Soldier real; `loot` faz BFS de cápsula da porta até cada ponto),
`tests/ce_mundo.tscn -- --modo=portas|fotos|mantle` (no mapa real, com terreno). `tools/preview_interior.py` renderiza corte de planta de um .glb.

## Mobília do pacote do usuário nos interiores — 2026-09-30
- `tools/importar_moveis.py` (Blender -b; `-- --folha raw/moveis` gera `moveis_frente.png`/`moveis_topo.png`): 43 móveis → `game/assets/models/moveis/<nome>.glb`
  + `moveis.json` (dimensões). Fontes: `interiorvillage_alpha_gltf/scene.gltf` (sofás, poltronas, camas, guarda-roupas, cômodas com gavetas juntadas,
  estantes, fogão, geladeira normalizada a 1,75 m, mesas, cadeiras, abajur, rádio) e `_interiores_de_casas_fbx` (pia, armários baixos/de parede,
  cadeira, mesas, lixeira, cristaleira; albedo reduzido a 512 px). Origem no centro da pegada no piso, costas +Y Blender (−Z Godot), frente −Y Blender
  (+Z Godot) = mesmo quadro de `interior.py`; escala real; material só albedo (rugoso, sem normal/metallic). Orientação/escala conferidas na folha.
- `tools/interior.py`: `Comodo._por` não desenha mais as peças com equivalente (`MOVEIS`: sofa, poltrona, cama, guarda_roupa, criado (+abajur), fogao,
  geladeira, pia (pia + módulos de armário), armario_baixo/armario_alto (módulos de 0,8 m), estante, aparador/tv_rack → cômoda, mesa, mesa_centro,
  mesa_bar, mesa_longa, cadeira); registra modelo/posição/giro/escala (pegada w×d pedida, distorção ≤ 35 %, alturas-alvo) em
  `game/maps/ilha/moveis.json` (chave = modelo do prédio). Escolha do modelo = menor distorção, alternando por prédio (fixo, nada sorteado).
  Sem equivalente continuam desenhadas: tapete, beliche, estante_carga, caixotes, pallet, tambores, bancada, mesa_escritorio, arquivo, balcão, banco, vaso/lavatório.
  `MOVEIS_A_MAO=1` no ambiente volta ao desenho antigo. Layout, portas e `tools/_loot/*.json` idênticos aos de antes (diff conferido).
- `game/core/moveis.gd` (`Moveis.instalar(corpo, modelo)`), chamado em `ilha.gd::_modelo_predio` e em `tests/ce_construcoes.gd`: MeshInstance3D com malha
  compartilhada, sem sombra, `visibility_range_end` 35 m; colisão = BoxShape da AABB escalada de cada móvel (abajur/rádio sem colisão). 415 móveis em 23 modelos.
- Teste novo `tests/interior_capture.tscn -- --out=pasta [--perf]` (sala/cozinha/quarto de 3 casas perto da Vila + 1 galpão; câmera recua antes de parede):
  capturas em `raw/interiores_02`. Interiores 106–139 fps (draws 224–1113).
- Validação: estande_mov 7/7 (falhas=0); sv_smoke OK (1 falha intermitente anterior: a caixa sorteou um colete e o teste espera exatamente 2 placas);
  ce_construcoes `loot` 0 falhas (com as caixas dos móveis); `portas` 1 falha em rancho_pesca_a #2 (modelo idêntico ao anterior e sem móveis: pré-existente).
  FPS ilha_tour --perf: vila 72, vila_casas 91, quartel_poi 78, morro_casas 59, aérea 59 (com outros 2 Godot rodando).
- Pendências: galpões seguem com prateleiras/caixotes desenhados (pacote não tem equivalente); sofás quase sempre `sofa_a` (é o de menor distorção
  para 1,9 x 0,9 m); lixeira/rádio/cristaleira importados mas lixeira sem lugar no layout; menu (menu_stage) mostra prédios sem os móveis.
