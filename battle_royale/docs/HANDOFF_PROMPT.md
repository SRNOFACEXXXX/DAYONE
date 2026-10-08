Você vai continuar o desenvolvimento de um jogo Battle Royale em primeira pessoa chamado "Ilha Brava" (mapa: Ilha do Tauá), feito em Godot 4.7.1 (renderer Compatibility) no Windows 10. Responda sempre em português do Brasil.

## Regras do dono do projeto (obrigatórias)
- NUNCA faça perguntas ao usuário: decida com bom senso e siga trabalhando.
- Nada procedural/aleatório no conteúdo do mapa: posições, alturas e objetos são autorais (dados em JSON escritos à mão). Script só aplica decisões já tomadas.
- PC fraco: i7-3770 + GeForce GT 730. Meta: 60 FPS em 1024x768. Sempre medir FPS depois de mudanças.
- Iluminação simples em tempo real (sem bake de luz pesado).
- Sempre manter uma versão jogável com menu. Quando o usuário pedir "execute o jogo", abra o jogo você mesmo (não mande ele clicar).
- Estilo: low poly estilizado, fim de tarde, litoral brasileiro; qualidade "AAA estilizado" (referência Fortnite/Apex low poly).

## Caminhos
- Projeto: C:\Users\satoshi\Documents\ChatGPT\teste\battle_royale (jogo Godot em \game, ferramentas em \tools, documentação em \docs)
- Plano de trabalho com histórico (itens 1–46): docs\NOITE_PLANO.md  ← leia primeiro
- Críticas de arte: docs\criteria\CRITICA_MAPA_01..05.md
- Dados autorais do Design: docs\design\ (ilha_layout.json, vegetacao.json, detalhes.json, gameplay_01.json, chao_vivo.json) — cópias usadas pelo jogo ficam em game\maps\ilha\
  ATENÇÃO: não rode tools\vegetacao_src.py, gameplay_src.py nem chao_vivo_src.py: eles sobrescrevem os JSON editados à mão.
- Godot (console): C:\Users\satoshi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe
- Blender 4.5 (modelos low poly por script): C:\Users\satoshi\Documents\ChatGPT\teste\.tools\blender45\blender-4.5.13-windows-x64\blender.exe  (uso: blender -b --factory-startup -P tools\script.py)
- Abrir o jogo: battle_royale\JOGAR.cmd
- Projeto anterior (base do combate): C:\Users\satoshi\Documents\ChatGPT\teste\linha_de_fogo (FPS estilo CS)

## Como o mapa é feito
1. docs\design\ilha_layout.json (pontos de altura, costa, estradas, rio, represa, POIs, zona, rotas do avião) →
2. tools\bake_ilha.py (usa tools\ilha_terreno.py, spline sobre 180 pontos de altura) gera em game\maps\ilha: height.bin (601x601 float32, 2 m, linha 0 = norte), splat.png, mata.png (R mata, G canavial, B capim seco), agua.png, trilhas.png (R trilhas, G sulcos de roda), meta.json. Rodar: cd tools && python bake_ilha.py; depois importar no Godot (--headless --path game --import).
3. game\maps\ilha\ilha.gd monta tudo: terrain.gd (chunks com LOD + HeightMapShape3D), vegetation.gd (MultiMesh), detalhes.gd, prédios (assets\models\predios, gerados por tools\build_predios.py + predios_lote2..4.py), coberturas, marcos, nuvens, água (shaders\agua.gdshader), céu (ceu.gdshader), terreno (terreno.gdshader).
Coordenadas: design x = leste, y = norte; Godot X = x, Z = -y.

## Como o jogo funciona (código em game\)
- Combate copiado do Linha de Fogo: core\soldier.gd, player_controller.gd, viewmodel.gd, body_model.gd, bot_brain.gd, match.gd; ui\hud.gd, radar.gd; autoloads Settings, Audio, WeaponDB, Game.
- core\br_match.gd (BRMatch extends Match): carrega a ilha, 255 armas nos pontos de saque, avião de salto (rota do layout, 300 m, 45 m/s; ESPAÇO salta só sobre terra; queda livre 50 m/s guiada por WASD; paraquedas a 110 m), zona que fecha (7 fases do layout, parede shaders\zona.gdshader, zona no radar, dano fora), todos-contra-todos (Match.is_ffa/is_ally), LOD dos corpos por distância, HUD adaptado (contador VIVOS, sem dinheiro/placar). Soldier.external_motion = avião/queda movem o corpo por fora.
- core\br_bot_brain.gd (BRBotBrain extends BotBrain): bots saltam perto de um ponto de saque, buscam arma primária, fogem da zona, rodam entre saques. Sem navmesh (condução direta + destravar). Guarda de barranco em _physics_process.
- Testes (rodar com o Godot console: --path game res://tests/X.tscn -- args):
  ilha_tour.tscn (--perf --only=a,b --out=pasta --probe=x;y) capturas + FPS de 18 vistas do mapa;
  br_smoke.tscn (avião→salto→pouso→pega arma), br_zona.tscn (--chao, zona acelerada), br_bots.tscn (--bots=11 --segundos=200, partida com bots), br_perf.tscn (--chao --bots=11, custo por categoria).
  FPS atuais: tour 60–136; partida com 12 jogadores ~52–60 (no chão, bots parados ~82).

## Problemas reportados AGORA pelo usuário (prioridade máxima)
1. "Teleportes" e o personagem "cai para o limbo" durante a partida. Hipóteses a verificar:
   a) fora de ±600 m (borda do heightmap, no mar) não existe colisão → queda infinita. Criar limites invisíveis (StaticBody) na borda do mapa e/ou impedir andar para o mar profundo; se y < -40, reposicionar em terra.
   b) pouso sobre o mar: _descer usa chão = max(piso, 0) → o corpo fica em y=0 acima do fundo e cai depois.
   c) Soldier._try_step (degrau automático do CS) em terreno íngreme pode "pular" o jogador.
   d) ao morrer a câmera vai para o espectador (siga o bot) — pode parecer teleporte; deixar claro na tela (tela de eliminado/colocação).
2. Mapa alto demais ("uma baita montanha"). O usuário quer uma ilha MAIS PLANA: planícies, bosques, fazendas, áreas militares; pode ter morros, mas não tão altos (pico hoje ~178 m; alvo ~40–60 m, maior parte da ilha entre 3 e 20 m).
   Caminho sugerido: em tools\bake_ilha.py, logo após H = T.altura(...) (linha ~30), aplicar uma curva de compressão f(h) (ex.: h' = h se h < 6; senão 6 + (h-6)*0.3) e aplicar a MESMA f às alturas absolutas do layout usadas no bake: z dos pontos do rio (agua.rio.trechos[].pontos[][2]), represa.nivel_agua_m (48) e barragem.altura_crista_m (52) (e altura_face_m proporcional). Conferir ilha.gd (plano da represa usa nivel_agua_m; ponte/barragem), shaders que dependem de altura (terreno.gdshader: alt/170, rocha acima de 30–45 m, grama seca por altura), rota do avião (300 m ok) e câmeras do tour. Rebake, importar, rodar o tour e a partida, medir FPS.
3. Pendência não aplicada (a última edição foi interrompida): em core\br_bot_brain.gd trocar a guarda de barranco para checar 1,5 m (> 2 m de queda) e 3 m (> 3 m) à frente e não entrar no mar (altura à frente < -0,3); em shaders\zona.gdshader fazer a parede ficar fraca de longe (alpha * mix(1, 0.35, smoothstep(80, 500, distância da câmera))).

## Próximos itens do plano depois disso
- 46: paraquedas visível (modelo à mão) e som de vento na queda.
- Tela de fim de partida do BR (colocação #N, abates) no lugar da tela de CS; remover "TR/CT" do painel do cronômetro.
- Mais jogadores (24 no brief) mantendo 60 FPS; navegação melhor dos bots (navmesh por POI).
- Scenario GameDev OS (texturas/skybox): só quando o usuário disser que conectou o conector https://mcp.scenario.com/mcp; sempre dry_run e informar o custo antes (gasta créditos dele). Nunca pedir chaves/senhas.

## Forma de trabalhar
Pegue o próximo item, implemente, rode o teste/tour correspondente, olhe as capturas (raw\<pasta>\*.png), compare, meça FPS, marque no docs\NOITE_PLANO.md e siga. Mostre ao usuário capturas do resultado. Seja direto nas respostas.
