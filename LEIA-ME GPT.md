# Ilha Brava — mapa GPT

Abra **JOGAR GPT.cmd** para o menu e a sobrevivência. Abra **EXPLORAR MAPA GPT.cmd** para visitar só o mapa: WASD/mouse, Shift para correr, Espaço para saltar, F para voo livre. **1, 2 e 3** levam aos três abrigos. Esc libera o cursor.

O projeto Godot está em `battle_royale/game/project.godot`, dentro desta pasta. Requer o Godot 4.7.1 já instalado neste computador; os iniciadores usam o mesmo executável do projeto original. As configurações da versão GPT usam outro diretório de usuário, graças ao nome de aplicação separado.

## Alterações

- 24 grupos de mata escritos à mão e gravados em JSON: 306 novas árvores, 595 arbustos/pedras baixos, com pelo menos 6,1 m entre os novos troncos e a borda das estradas. Mantidos campos e linhas de visão entre os grupos.
- Três abrigos abertos: Pomar do Tauá, Refúgio do Vale e Posto da Mata. Piso, cobertura, banco, sinalização e caixas do sistema de loot existente, de tiers baixo/médio/alto. Entradas sem casco convexo que feche o espaço.
- Trilhas curtas de acesso, dez props de ambiente e três pequenas bases niveladas. O restante do relevo, a costa, as estradas, os prédios e os pontos de loot anteriores foram preservados.
- Paleta de verde mais contida, luz menos alaranjada e bordas de sub-bosque mais suaves. Mantida a linguagem low poly e o renderizador Compatibility.

## Veículos dirigíveis

Os vinte carros que já estavam espalhados pela ilha — sedãs, táxis e viaturas — agora são veículos físicos. Aproxime-se e pressione **E** para entrar. Use **W/S** para acelerar, frear e dar ré; **A/D** esterça as rodas dianteiras; **Espaço** aciona o freio de mão; **E** sai. Se o carro tombar, pare e segure **R** por um segundo para reposicioná-lo no último ponto estável.

Cada carro pesa 1.180 kg e usa quatro suspensões por raycast, com curso, mola, compressão e retorno amortecidos. As quatro rodas giram ao rodar; somente as dianteiras esterçam. A direção perde amplitude gradualmente com velocidade, há frenagem antes de engatar a ré, limite aproximado de 97 km/h, aderência traseira reduzida durante o freio de mão, centro de massa baixo, força aerodinâmica moderada e câmera externa com colisão.

## Comparação

`comparacao/antes` e `comparacao/depois` contêm capturas reais de Godot. Os oito arquivos com o mesmo nome foram capturados com a mesma câmera a 1024×768. `ilha_gpt_pomar_frente.png` é uma vista adicional da versão nova.

Os dados congelados do mapa anterior estão em `comparacao/mapa_original`. O gerador `battle_royale/tools/rebuild_gpt.py` usa esse snapshot e pode reproduzir a composição, sem sorteio e sem acessar o projeto original.

## Verificação

- 1.582 arquivos de assets conferidos por SHA-256, sem divergências ou arquivos ausentes em relação ao original no momento da conferência.
- `gpt_map_check.tscn`: três pisos suportam o jogador; entrada livre para cápsula de 1,8 m; três caixas abrem, têm até dois itens e transferem o conteúdo. Zero falhas.
- `sv_smoke.tscn`: nascimento na vila, abertura/coleta, granada, regeneração após atraso e morte/respawn passaram (`SV OK`).
- Nenhum erro de script nos testes finais e nas capturas. Logs e relatórios em `comparacao`.
- GT 730, Godot 4.7.1 Compatibility, 1024×768, amostras de 3 segundos sem VSync depois do aquecimento: Pomar **38 FPS**, Vale **36 FPS**, Posto da Mata **58 FPS**. São medições locais de três vistas, não garantia de 60 FPS nem benchmark da ilha inteira.

## Isolamento da cópia

O jogo, seus assets, ferramentas, documentos e arquivos auxiliares de `battle_royale` foram copiados. Caches são regenerados dentro desta cópia. A pasta `.tools` da raiz original e os outros protótipos não são necessários para jogar esta versão. Nenhum arquivo original foi editado por esta tarefa; não houve commit, push ou publicação.
