# Auditoria técnica de refinamento — ciclo 01

**Projeto:** Ilha Brava / Battle Royale, Godot 4.7.1 Compatibility  
**Escopo:** inspeção estática somente leitura de câmera 1ª/3ª pessoa, tecla C, salto do avião e queda, ADS iron/ACOG, inventário/atalho rápido, menu, áudio e testes existentes. Nenhum código, asset, configuração ou teste foi executado ou alterado durante a auditoria.  
**Data:** 2026-09-28

## Método e critérios de aceite

Apliquei o fluxo GameDev OS de refine loop e quality gate sem geração de assets: converti as imagens fornecidas em critérios verificáveis, comparei os critérios com os fluxos e pontos de entrada reais no código, e separei defeitos observáveis de riscos que ainda pedem teste. O Quality Gate do Scenario avalia imagens, não estados de gameplay; portanto, esta auditoria usa um gate técnico manual para o jogo e reserva a comparação visual direta para capturas por estado. Em ciclos posteriores, mudar uma variável por rodada, comparar com a referência aprovada e interromper/registrar falha em vez de declarar aprovação só por haver arquivos ou recursos.

As imagens fornecidas são requisitos visuais: DeadPoly orienta a leitura low-poly em terceira pessoa, personagem e barra rápida; DayZ orienta menu com personagem/cenário e painéis de inventário/saque/equipamento; as capturas AK iron-sight e Mosin orientam alinhamento de mãos/arma, linha de mira e optic funcional. São referências de comportamento e composição, sem exigir cópia literal de logos, marcas ou conteúdo proprietário. Não proponho substituir modelos por geração procedural: os riscos abaixo pedem integração, ajustes de apresentação e testes dos modelos existentes/autoriais.

**Gate sugerido:** (1) não há transição de modo que perca câmera, arma ou controle; (2) mira física da arma e retículo coincidem no centro da tela; (3) HUD e inventário mantêm estado entre abrir/fechar/trocar; (4) salto começa em terceira pessoa e pouso retorna de forma definida; (5) áudio essencial toca uma vez, no bus e posição corretos; (6) menu e inventário cabem em 1280×720 e 1024×768; (7) nenhum erro Godot e meta de 60 FPS na GT 730 a 1024×768. Para a comparação visual, capturar o mesmo enquadramento, resolução, arma, estado de ADS e escala da UI que a referência-alvo.

## Diagnóstico por sistema

### 1. Câmera 1ª/3ª pessoa e tecla C — bloqueador funcional

- **game/core/player_controller.gd:3,27-51** cria uma única Camera3D como câmera atual e o inicializador chama body_model.set_first_person(true). O controlador e seu comentário descrevem somente câmera em primeira pessoa.
- **game/core/player_controller.gd:74-123** trata mouse, teclas de slots, drop, inspect e pickup; não há ramo para C ou ação equivalente. **game/autoload/settings.gd:40-49** também não declara binding de alternância de perspectiva.
- **game/core/player_controller.gd:187-224** posiciona a câmera na altura dos olhos e atualiza base/orientação como câmera FPS; o caminho vivo não calcula ombro, distância de seguimento, colisão da câmera contra parede, nem retorno de câmera.
- **game/core/player_controller.gd:275-299** usa câmera de morte/espectador e alterna visibilidade do corpo; isso não implementa terceira pessoa jogável. **game/core/body_model.gd:145-154** aplica sombras-only à geometria do corpo/arma próprios na primeira pessoa, mas não é um modo de câmera selecionável.
- Efeito no requisito: a referência DeadPoly de sobrevivente visível e hotbar não pode ser atendida no modo atual; também não se pode começar o salto do avião em terceira pessoa como pedido. Risco de implementar apenas uma câmera deslocada: clipping na parede, arma/corpo sobrepostos e yaw/pitch inconsistentes.

**Gate:** C alterna FP↔TP durante partida e queda; estado preservado após abrir inventário, ADS, pousar e reaparecer/espectar; TP não atravessa paredes nem esconde/intersecta o personagem/arma; o modelo de corpo e viewmodel não aparecem simultaneamente.

### 2. Avião, saída e queda livre — lógica presente, apresentação e transições não fechadas

- **game/core/br_match.gd:559-579** atualiza voo, prende soldados ao transform do avião e salta por Espaço/força no limite terrestre. As posições dos corpos usam s.global_position, mas o controlador mantém a câmera FPS na cabeça (**player_controller.gd:187-199**), então falta a perspectiva externa exigida durante a saída/queda.
- **game/core/br_match.gd:586-594** muda estado e posição ao saltar, torna o Soldier visível e mostra instrução. Não há ali acionamento de animação de saída, pose de queda, velame visível ou VFX de fluxo de ar.
- **game/core/br_match.gd:597-635** abre paraquedas automaticamente a 110 m, aplica velocidade vertical/horizontal e varre colisões para pouso. O estado “para” é apenas um estado lógico de locomoção nessa função; não se vê integração de modelo de paraquedas nesse trecho. O próprio plano ainda marca **docs/NOITE_PLANO.md:53** paraquedas visível e som de vento como pendentes.
- Somente land é tocado na transição de abertura (**br_match.gd:603-607**), apesar de ser o som de pouso; semanticamente isso dá feedback sonoro errado. **br_smoke.gd:21-38** fotografa avião/queda/paraquedas/pouso, mas força salto, pitch e movimento diretamente no objeto, sem simular input nem conferir modo da câmera/animação/som.
- **br_stability.gd:46-62,89-103** cobre limites de deslocamento, atravessamento de piso, parede e bounds com fixtures artificiais; não cobre o caminho integrado no mapa e as transições de câmera/visibilidade.

**Gate:** partida real → aguardar janela de salto → pressionar Espaço → câmera externa contínua e corpo animado saindo da rampa → queda com vento/pose e controle → abertura/velame → pouso no terreno/telhado → controle a pé e troca C. Cobrir também salto forçado na borda terrestre, sem atravessar ilha/mar, sem teleportes ou estado de input preso.

### 3. Iron sights, ACOG e Mosin — suporte parcial; alinhamento visual é risco principal

- **game/core/player_controller.gd:114-120** troca entre iron e ACOG através da ação inspect somente quando alt_fire já está pressionado e a arma tem ACOG. Com controles atuais, alt_fire é botão direito e inspect é F (**settings.gd:43-48**): ACOG exige manter botão direito e pressionar F. Isso não é indicado no menu/HUD e conflita com F para inspecionar como gesto normal.
- **game/core/player_controller.gd:169-184** reduz FOV e chama viewmodel/overlay; existe transição temporal. Porém o FOV muda independentemente da prova de que o eixo óptico/modelo está alinhado ao centro da câmera. A variável transition calculada na linha 176 não é usada para a interpolação (linha 182 usa dt * 12), tornando o parâmetro por arma ineficaz.
- **game/core/viewmodel.gd:150-163** escolhe o modelo FP se disponível, mas para C4 volta ao modelo world sem braços; as linhas **338-352** usam offsets fixos diferentes para Mosin e AK/M4. São pontos sensíveis: sem calibração por sockets/pose verificada, mão cortada, arma inclinada e linha de mira deslocada podem persistir mesmo com zoom correto, que são justamente problemas apontados nas referências.
- **game/core/viewmodel.gd:338-352** alterna visibilidade de Optic no Mosin e desloca holder, enquanto **game/core/ads_indicator.gd:21-47** desenha uma máscara e retículo ACOG em overlay 2D. Não há evidência de retículo renderizado pela lente com parallax, eye relief, campo de visão limitado pelo vidro ou calibração óptica; a imagem de lente pode ser somente efeito de tela. Risco de a mira parecer funcional, mas tiros/crosshair/câmera não partirem da linha de visada visual.
- **game/core/weapon_def.gd:47-52** fornece apenas valores FOV e transição, sem dados de posição/rotação de alinhamento para cada arma/mira. **game/tests/mosin_smoke.gd:22-40** verifica números, nós Optic/ferrolho e presença dos scripts, não estado real de ADS nem captura alinhada.

**Gate:** para AK/M4/Mosin, capturar sem ADS, iron segurada, ACOG montada e ADS, em 1ª e 3ª pessoa; exigir sights co-planares ao centro da câmera, mãos inteiras, retículo no alvo, tiro no ponto sob repouso, transição de FOV coerente e retorno limpo ao soltar RMB/trocar arma/recarregar/abrir UI. Confirmar que ACOG só ativa com attachment e que controles aparecem no jogo.

### 4. Inventário, loot e atalho rápido — núcleo existe, UX DayZ incompleta e fluxo armado não foi integrado

- **game/core/br_inventory.gd:11-24** define AK/M4/Mosin, calibres, mochila e ACOG. **:46-58** define capacidade por linhas/peso; **:124-162,190-226** adiciona, empilha, transfere, equipa mochila e acopla ACOG. É base de dados/grade, não por si só garantia de sincronização com o WeaponState em cada evento.
- **game/core/br_match.gd:57-76,90-105** inicia bolsa com pistola/munição, liga sinais de carregador/recarga e cria UI; popula caches carregados do JSON. **:111-158** sincroniza reserva, magazine e troca arma quando equipamento vem da UI. Precisam testes end-to-end em ambas as direções: disparo/reload no mundo ↔ item da grade, descarte/troca ↔ slot e cache, remoção de attachment ↔ estado visual/ADS.
- **game/core/br_match.gd:182-198** abre UI com I e fecha por closed; E usa take_all para recolher o cache inteiro, sem seleção de item nem teste do caso parcial/grade cheia no fluxo de partida. **:178-179** recalcula hint apenas se chamado; não há evidência nesta área de que o container de saque aberto se rebinde continuamente para o cache mais próximo quando o jogador se desloca.
- **game/ui/br_inventory_ui.gd:137-185** monta dois painéis de grade (“Seu equipamento” e “Saque próximo”), peso/mochila e instrução arrastar/clicar. Comparada à imagem DayZ 0.58, faltam no layout observado painel de proximidade (Vicinity), preview/equipamento de personagem em 3D e separação visual de mãos/slots equipados. Não há rotação de personagem nem equipamento vestível mostrado nesta construção.
- **game/ui/br_inventory_ui.gd:193-228,233-286** faz bind, abrir/fechar, Escape, atualização, equipar/clicar/drag-drop. A verificação de UI existente só abre e fecha sem eventos de mouse/teclado nem teste de resolução responsiva; risco de grid exceder área em 1024×768 ou drag/drop falhar em itens de tamanho >1.
- **game/ui/hud.gd:487-510** exibe lista de slots apenas por 1,5 s após a troca de arma. Isso não equivale à hotbar persistente/legível da referência DeadPoly e não representa stack/consumível/atalho de 1–8. **player_controller.gd:97-110** mapeia 1–5 a slots clássicos; não há bindings por item da grade/quick slot de sobrevivência.
- **game/tests/br_inventory_check.gd:7-36** cobre regras unitárias (stack, peso, mochila, ammo, reload abstrato, ACOG e snapshot/restore); **:37-58** apenas instancia e abre/fecha UI. O teste usa reload_weapon na API de inventário, não recarga pela arma/controlador e visualização FP/TP.
- **game/tests/br_smoke.gd:50-60** chama teleport do jogador até o pickup, espera 60 frames e imprime tamanho de inventário. Isso não simula apertar E/I nem exige assert no resultado; pode passar mesmo sem pickup/inventário realmente integrado.

**Gate:** coletar item individual e lote; pilhas parciais; mochila e capacidade; peso cheio; arrastar itens 1×1 e 3×2; equipar AK/Mosin, disparar/recarregar, soltar arma, recuperar do chão; acoplar/retirar ACOG; fechar/reabrir inventário e confirmar UID/munição/célula; quick slots do início ao fim. UI testada a 1280×720 e 1024×768, incluindo escala/DPI, foco do mouse e Escape.

### 5. Menu — cena abre, mas referência DayZ não está representada

- **game/ui/main_menu.gd:4-18** constrói um fundo ColorRect sólido e escurecimento, sem cena de personagem, mapa, rotação, animação ou iluminação de apresentação. **:20-78** monta card central com título e botões Jogar/Explorar/Sair. A referência DayZ é menu sobre cenário com personagem equipado e painel lateral com estatísticas/ações; o menu atual é funcional, mas é outro layout/experiência.
- **game/tests/menu_capture.gd:4-12** espera dois frames, salva screenshot e termina. Ele prova que houve imagem, não valida botões, troca de cena, resolução curta/ultrawide, foco, áudio, loading, retorno ao menu ou abertura de configurações. O menu atual nem expõe Configurações no código deste arquivo.

**Gate:** captura de menu no perfil visual escolhido, personagem e ambiente autorais estáveis; verificar Jogar→loading→partida, Explorar→mapa, retorno, Configurações e Sair, tab/enter/mouse, 1280×720 e 1024×768. Checar silêncio/volume coerente e nenhum menu modal bloqueado após retorno.

### 6. Áudio — biblioteca e pool funcionam como infraestrutura; feedback da queda ausente

- **game/autoload/audio.gd:21-41** cria buses e pools 3D/2D e varre arquivos. **:58-100** cataloga e carrega lazy streams; **:103-147** toca SFX e voice; **:150-…** tem music/ambient em loop. Isto não prova que cada evento do BR usa o som esperado.
- Uso de Audio.ambient/music encontrado em **game/core/match.gd:69,267-342**; no BR, mapa ilha cai no ramo diferente de poeira e recebe amb_village, mesmo em cena rural/avião. Não encontrei chamada Audio.music no início de BR nem som de vento/avião/paraquedas. Arquivos existentes filtrados em game/assets/audio incluem amb_desert.ogg e amb_village.ogg, mas não wind/fall/parachute/aircraft.
- **game/core/br_match.gd:603-607** toca land na abertura de paraquedas; a queda usa som de pouso como efeito. **game/core/soldier.gd:330-339** também toca land em aterrissagem real, logo o mesmo evento/asset é usado em dois momentos incompatíveis.
- Não há teste dedicado de áudio, verificação de id presente, número de toques, bus, atenuação, prioridade ou mix em cena cheia. A API _stream retorna null silenciosamente para ID desconhecido (**audio.gd:89-100**), então uma grafia divergente falha sem evidência visível.

**Gate:** auditoria da matriz de eventos/IDs: menu, clique, engine/avião, vento de queda, abertura de paraquedas, impacto de pouso, passos por superfície, pickup, tiro próprio/distante, hit, UI e zona; validar bus, ganho, distância, repetição/pool, ausência de clipping e comportamento sem arquivo opcional. Log/asserção de IDs críticos ausentes.

## Matriz de testes de integração para o próximo ciclo

| ID | Cenário / caminho | Ações observáveis | Critério de aprovação | Evidência / teste atual |
|---|---|---|---|---|
| CAM-01 | Partida no chão, perspectiva | alternar C FP→TP→FP parado e correndo | uma câmera ativa; sem clipping; body/viewmodel consistentes; controle e mira não mudam | não existe teste de C; criar captura FP/TP e caso automatizado |
| CAM-02 | C + ADS | alternar perspectiva com iron, ACOG e Mosin optic | nenhum offset/câmera residual; tiro no centro visual em ambos modos | mosin_smoke só inspecciona recursos/nós |
| AIR-01 | avião → saída por Espaço | saltar na janela autorizada | saída em terceira pessoa, pose/corpo legível, sem snap/teleporte, yaw e input corretos | br_smoke força saltar() diretamente e fotografa; não testa input/câmera |
| AIR-02 | voo/queda → paraquedas → pouso | queda guiada, cruzar 110 m, pousar em terreno, telhado e borda | transições únicas, velame visível, vento separado do pouso, sem atravessar piso e controle retorna | estabilidade cobre colisão em fixtures; smoke cobre pouso; não verifica visual/áudio real |
| ADS-01 | AK iron sights | segurar RMB e mover mouse; disparar no alvo central | alça/massa alinhadas ao eixo, mãos completas, muzzle/recuo e ponto de impacto compatíveis | sem teste visual/integrado; capturar por resolução |
| ADS-02 | ACOG em arma compatível | pegar ACOG, acoplar pelo inventário, ADS e alternar F/RMB | optic ligado somente equipada; máscara/retículo centrados; tiro coincide com retículo | UI/inventário + Mosin smoke isolados, sem fluxo integrado |
| ADS-03 | Mosin | ADS iron/optic, tiro, ciclo do ferrolho, recarga | FOV, olho, lente, retículo, bolt e disparo sequenciados sem cortar arma/mãos | mosin_smoke.gd:22-40 checa definições/nós, não ação |
| INV-01 | cache perto, ação E e UI I | coletar item seletivo, dividir pilha, transferir e fechar | inventários origem/destino exatos; sem duplicação/perda; UI acompanha cache | br_smoke teleporta ao pickup; br_inventory_check API somente |
| INV-02 | arma/mag/munição integrada | equipar AK/Mosin; disparar, recarregar, soltar, recolher | WeaponState, munição por calibre, magazine e células permanecem sincronizados | sinais em br_match.gd:67-76,111-158; sem teste integrado |
| INV-03 | capacidade e hotbar | mochila, excesso de peso/slots, atalho rápido e consumível | limites claros; barra legível persistente; keybind equipa item certo; nenhum loot desaparece | API testa mochila; HUD só mostra lista transitória de 1,5 s |
| INV-04 | resolução/UI/mouse capture | abrir/arrastar em 1280×720 e 1024×768; Escape; retomar mouse | painéis no viewport, célula e tooltip corretos, controle volta ao jogador ao fechar | teste existente só chama open/close |
| MENU-01 | menu → jogar → partida → voltar | mouse e teclado; loading e janela normal | sem tela cinza/softlock; mapa e HUD carregados; mouse/cursor e áudio corretos | menu_capture é apenas screenshot estático |
| AUD-01 | sequência áudio de queda | motor/ambiente → vento → abrir velame → pousar | eventos distintos, sem som de pouso ao abrir; bus/atenuação audíveis e únicos | sem teste; id land está na transição errada |
| AUD-02 | mix em combate/ilha | passos, pickup, tiros perto/longe, hit, UI, ambient | spatialização, distância, variações e ganho corretos sem estourar o pool | nenhuma suíte de áudio identificada |
| PERF-01 | cena integrada sob carga | 24 jogadores, mapa, loot, UI, câmera FP/TP, FX e áudio em 1024×768 | meta brief ≥60 FPS, sem picos de frame/physics e sem crescimento de draw calls | br_perf mede categorias com bots imóveis; não representa combate/queda/duas câmeras |

## Ordem recomendada para o refinamento

1. **Bloqueio P0 — arquitetura de perspectiva:** definir modo e câmera FP/TP, input C e estados de visibilidade/colisão; projetar o avião/queda em TP antes dos ajustes estéticos. Isso fecha um requisito central e evita calibrar ADS para um controlador que depois muda de pose/câmera.
2. **Bloqueio P0 — ADS/alinhamento:** calibrar sockets/transformações nos assets existentes AK, M4, Mosin e optic; verificar raycast de tiro versus linha óptica em capturas e teste automatizado.
3. **P1 — entrada e UI de sobrevivência:** definir quickbar persistente e modelo DayZ 0.58 (vicinity, personagem/equipamento e grade), então ligar input/eventos reais e manter serialização/sincronização como fonte única de estado.
4. **P1 — queda/áudio:** separar som de abertura de paraquedas do pouso, escolher/misturar evento de vento/avião e cobrir transições visuais com estados explícitos.
5. **P1 — menu:** aprovar composição de cenário/character hero e ações/configurações antes de polir tipografia/efeitos; preservar fallback leve para GT 730.
6. **Gate integrado:** rodar a matriz com input simulado e caminho jogável; capturar referências equivalentes, revisar erro/teleporte e medir 60 FPS. Marcar falha por ID e corrigir uma categoria por rodada, preservando os modelos manuais existentes.

## Limites desta auditoria

Esta é uma inspeção estática, não uma declaração de que os riscos reproduzem em execução nem que a build passa/falha. Não rodei Godot, não alterei assets/código e não confirmei output de testes. As referências visuais foram tratadas como critérios do usuário; medições visuais de alinhamento, legibilidade, clipping e FPS ainda precisam das capturas e testes listados acima. Linhas citadas apontam para o estado lido em 2026-09-28; se o projeto mudar, devem ser atualizadas no próximo ciclo.

