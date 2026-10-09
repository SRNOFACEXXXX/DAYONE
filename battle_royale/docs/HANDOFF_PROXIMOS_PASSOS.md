# Handoff — a jornada do herói e o caminho das pedras (o que fazer daqui para frente)

## Onde estamos
Temos um jogo de sobrevivência jogável: **zumbis** (IA, sentidos, LOD, variantes, mortes variadas), **armas** realistas (AK, M4, Mosin, M107, M249, Uzi, pistolas; ADS, miras holográfica/ACOG/luneta, balística, coice, som em camadas), **dano** por zona (cabeça ≈50%, corpo ≈20%), **itens/inventário** (grade estilo DayZ, mochila, baús, proximidade), **construção** de base (`ConstructionSystem`), **carros** dirigíveis, **clima/dia-noite**, **água**, **portas/escadas**, **criador de personagem**, trailer de 2 min e cutscene de abertura.
Falta o **loop de sobrevivência de verdade**: coletar recursos, craftar, caçar, evoluir a base. É a missão das próximas IAs.

## Estado em 2026-10-09 (o que ENTROU nesta volta, verificado no Godot — detalhes em `ATUALIZACAO_DAYONE.md`)
- **Sobrevivência:** fome/sede/temperatura (`core/sobrevivencia.gd`), comida e bebida consumíveis, HUD fina.
- **Madeira e construção:** machado na mão derruba árvore (6 golpes, tomba, 5 toras no chão → inventário de proximidade → mochila); construção custa **toras** (5 = fundação, 3 = parede) (`core/arvore_corte.gd`, `core/construction_system.gd`).
- **Fogueira:** kit/gravetos + fósforos, queima por tempo, cozinha carne, aquece (`core/fogueira.gd`).
- **Animais:** cervo, galinha, cachorro, lobo à noite (`core/animal.gd`, `animal_director.gd`); tiro, esfola com faca → carne, pele, gordura, osso. Modelos gerados por script: `tools/blender/animar_animais.py`.
- **Zumbis:** 20 por cidade perto do jogador (`ZombieDirector`); morte com pedaços/membros (`fx/pedacos.gd`, `core/zumbi_desmembrar.gd`); sons refeitos (`tools/gen_zumbi_audio.py`), grilos "de sino" desligados.
- **Carro:** marchas/RPM, dano por batida, HUD, combustível com galão (F perto do carro). **Objetivo final:** consertar o barco MARÉ MANSA (praia sul) com galão x2, bateria, kit x2, corda x2, tora x4 → tela de fuga (`core/barco_fuga.gd`).
- **Itens por dados:** `game/data/itens/*.json` (28 modelos em `assets/models/itens/`, gerados por `tools/blender/gerar_itens.py`).
- **PENDENTE:** colisão da cerca de arame (não colide nem na versão estável); raízes/galhos baixos de árvores atravessáveis; pesca; roupas/isolamento; salvar progresso (fogueira, fome); medir FPS na GT 730 (aqui o render é por CPU).

## Missão (em ordem de prioridade) — cada item: implementar → teste no jogo real → captura → medir FPS → registrar
> Sem HUD feio e sem animação feia. Animações: Mixamo (`Assets/animações`) via retarget (`cinematic/mx_retarget.gd`, `core/zombie_pose_copy.gd`) ou clipes do pack. UI: reutilize `ui/ui_style.gd`, `ui/yui.gd` e o padrão do inventário BR.

### 1. Ferramentas e coleta (base de tudo)
- **Machado**, **picareta**, (depois pá, martelo, faca de caça) como itens do `BRInventory` (`core/br_inventory.gd`, `docs`/`core/BR_INVENTORY_API.md`), com modelo no viewmodel/rig (mesmo padrão das armas: `weapon_def.gd`, `weapon_model.gd`, `viewmodel.gd`).
- **Madeira**: derrubar árvores com machado (HP da árvore, golpes com animação melee, som de lenha, árvore **tomba** e vira tronco/toras coletáveis, toco permanece; respawn lento). As árvores hoje são MultiMesh em `maps/ilha/vegetation.gd`: criar camada de "árvores interativas" por proximidade (instanciar nó colidível só perto do jogador; trocar a instância do MultiMesh por tronco caído).
- **Mineração**: picareta em pedras/veios (`modelo pedras` em Assets; `maps/ilha/detalhes.gd`): pedra, minério (ferro/carvão), com partículas e som. Pontos autorais (JSON), não procedurais.
- Itens novos: tora, tábua, pedra, ferro, carvão, corda/fibra, tecido, pele, carne crua/cozida, ossos, gordura, isca.

### 2. Craft
- Tela de craft integrada ao inventário (aba/botão), receitas em **JSON** (`game/data/receitas.json`): entrada → saída, tempo, ferramenta/estação exigida (mão, fogueira, bancada).
- Receitas mínimas: tábuas, pregos, machado/picareta/martelo, lança/arco/flechas, fogueira, tocha, bandagem, **mochila de couro** (pele+corda), colete de couro, roupas, cozinhar carne, destilar/ferver água, munição simples.
- Estações: fogueira (já há `fogueira` no trailer — transformar em objeto de jogo com combustível, cozinhar, calor, luz), bancada (construção), forja (depois).
- Construção: ampliar `ConstructionSystem` com custo em madeira/pedra (hoje construir é de graça), reparo, demolição, tetos/portas/baús/camas (respawn), cercas, torres.

### 3. Animais e caça
- Os animais do mapa (galinha, cão, cervo, gato: `assets/models/atualizacao/mundo/*`, ex. `Deer_001`) estão **estáticos**: dar vida.
  - Animação: clipes do pack ou retarget; se faltar, gerar ciclo simples via Blender (andar/correr/idle/morrer/comer).
  - IA leve: `CharacterBody3D` + estados (pastar, andar, fugir ao ouvir tiro/ver jogador, morrer). Presas fogem, predadores (lobo/cão selvagem) atacam. **LOD/orçamento por quadro** como o `ZombieDirector` (PC fraco!).
  - **Distribuir pelas florestas** usando `mata.png` (R = mata) + pontos autorais; densidade baixa e manadas pequenas; spawn por proximidade do jogador (nada de 500 animais vivos).
- **Caçar** com arco/rifle/faca → cadáver coletável: **carne crua** (cozinhar na fogueira → comida que cura/sacia), **pele** (curtir → couro → **mochila**, bota, colete), osso, gordura.
- Sons de animais (OpenGameArt CC0) e sangue discreto.

### 4. Sobrevivência (mecânicas de sistema)
- Fome, sede, temperatura/molhado (chuva, noite, água), sangramento, fratura, doença/infecção do COROV-27, sono/cansaço, peso/estamina.
- Comida/água/remédios no inventário (já existe `healing` e baú: base_bau_cura). Curas com animação própria.
- Base: durabilidade, raid (zumbis atacam paredes), baú trancável, cama/respawn, fornalha, horta/plantio (colheita), pesca (o herói é pescador!).
- Eventos: queda de suprimentos, horda noturna, tempestade, helicóptero caído (loot militar), radiotransmissor com a voz da rádio do trailer.
- Progressão leve: habilidades por uso (corte, mineração, caça, costura) em vez de XP genérico.

### 5. Lore em jogo (ver `LORE.md`)
- **Aumentar a lore a cada feature**: cada item/NPC/local novo ganha texto. Diários, bilhetes, gravações de rádio, cartazes e documentos achados no loot, ligando a história do COROV-27, da ilha e do herói. Arquivo de textos: `game/data/lore/*.json` (id → título → corpo → onde aparece).
- Crie pontos de interesse narrativos (casa do pescador, posto militar abandonado, laboratório, igreja, farol), com ambientação (props do pack `atualizacao`).

### 6. Qualidade/performance (sempre)
- Meta 60 FPS/1024×768 (GT 730). Medir com `tests/br_perf`, `tests/perf_*`. Nenhuma feature entra se baixar o FPS sem justificativa.
- Pendências antigas (`ATUALIZACAO_DAYONE.md`): travada ao apertar Shift, AK/Uzi com mão bege em blocos e braço da sniper, M107 não cabe na mochila média, capim/postes dominando vistas, som no jogo real, "jogador atravessa props", zumbi rastejando sem cabeça, bot sobrevivente (playtester) que vive vários dias usando só input real.

## Fluxo de trabalho recomendado para cada tarefa
1. **Triagem barata** (ler docs/arquivos-chave, listar o estado) → decidir → só então editar (ver `ECONOMIA_DE_TOKENS.md`).
2. Implementar a menor fatia jogável (ex.: só machado + 1 árvore tombando) e **ver rodando** (captura/preview).
3. Teste automatizado curto em `game/tests/` (usa jogo real, inputs reais). Rodar regressão.
4. Registrar em `docs/ATUALIZACAO_DAYONE.md` (feito/medido/pendente). Commit pequeno e descritivo.
5. Repetir. Nunca deixar o jogo quebrado entre commits.

## Cutscene de abertura (já feita)
`ui/intro.tscn` é a cena principal: toca `assets/video/intro.ogv` (trailer, Theora/Vorbis) e, por baixo, `Loading.iniciar_aquecimento()` compila shaders e carrega recursos da partida; **qualquer tecla/clique/botão pula** para `main_menu.tscn`, que continua o aquecimento. Para trocar o vídeo: gerar OGV (`tools/trailer/blender_para_ogv.py`, Godot só toca Theora) e substituir `assets/video/intro.ogv`.
