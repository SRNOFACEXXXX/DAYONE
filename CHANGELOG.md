<!-- // [LOCOMOTION-FIX v9] -->
## v9 — Cenário Kasbah no FPS · 23/09/2026

- Problema: arsenal funcionava em um plano com grade, sem cenário nem bloqueio de paredes.
- Solução: cenário original criado no Blender 4.5.13 LTS, exportado em GLB; pátios A/B, três rotas, passagem coberta, arcos e caixas. Fonte .blend preservada em client/public/assets/maps.
- Integração: 34 colisores estáticos, movimento com deslizamento e prevenção de atravessamento, tiros bloqueados pela geometria e cinco alvos distribuídos nas rotas. Mantidos os assets e animações das armas.
- Antes/depois: 0 → 34 obstáculos físicos; grade → cenário GLB de 858.584 bytes; 37 → 40 testes passando; build aprovado.
- Limite: mapa original de treino, não Dust 2; piso plano, sem salto/bots. Qualidade visual inicial, sem certificação AAA/performance.
<!-- // [LOCOMOTION-FIX v8] -->
# Arsenal FPS — mãos padronizadas e fogo volumétrico

Problema → modelos de braços diferentes entre armas; flash plano branco; M4 ausente.

Diagnóstico → rigs têm poses/unidades e ossos terminais diferentes; o primeiro M4A4 encontrado não disponibilizava download. A nova M4 fornecida pelo usuário usa materiais specular/glossiness legados e clipes com timestamps absolutos.

Solução → manter AK-47/pistola aprovadas e adaptar offline suas mesmas luvas e mangas para os rigs originais da M4, faca e revólver. Sem IK/retarget procedural no loop. Texturas e UVs preservados; animações das armas preservadas byte a byte nos arquivos derivados. Corrigidos ossos terminais sem referência válida; eliminadas superfícies de ombro fora do enquadramento. M4 integrada com textura original e tempos de ações começando em zero. Flash plano substituído por densidade volumétrica 3D, ligada a sockets medidos nas bocas dos canos.

Antes/depois:
- Armas jogáveis: 1 → 5 (AK-47, M4, pistola, revólver, faca).
- Aparência das mãos: 3 conjuntos diferentes → a mesma base de luvas/mangas aprovada nas 5 armas.
- Flash: forma plana → volume 3D, 24 amostras por fragmento, ativo por 75 ms.
- Munição: preservada por arma; cancelar recarga não concede munição.
- Efeitos: 40 marcas de impacto reutilizáveis, traçante, luz quente e indicador de acerto.
- Áudio: passos alternados, corrida, tecido/manuseio, tiro, recarga, saque/corte; arquivos locais com créditos.
- Validação: 37 testes passaram; build de produção passou. Inspeção visual de pegada e recarga em frames de 0/25/50/75/99%, mais faca em ataque. Igualdade binária das animações originais e das texturas das luvas/mangas testada.

Controles: Jogar captura mouse; WASD move; Shift corre; clique atira; R recarrega; segurar Tab abre roda; mouse/scroll seleciona; soltar equipa; 1–5 troca; Esc libera cursor. O menu também permite clicar nas armas.

Limites reais: M4, revólver e faca não têm Walk/Run autorais neste pacote; mantêm sua pose/Idle enquanto o jogador se desloca. Os sons de disparo e recarga são gravações substitutas, detalhadas em client/public/assets/ARSENAL-CREDITS.md. Não foi feita certificação de orçamento de GPU/CPU por DevTools nesta etapa; nenhuma alegação de 0,8 ms. Os testes de locomação anteriores continuam passando.

<!-- // [LOCOMOTION-FIX v4] -->
# Correção dos braços — 22/09/2026

Problema: após a troca por Mixamo, braços atravessavam o tronco. O retarget usava como equivalentes a T-pose do FBX e a pose relaxada/A do soldado; essa diferença não havia sido compensada.

Solução: alinhamento anatômico offline das referências de clavícula, braço, antebraço e mão, em ambos os lados, antes de converter as rotações prontas. Endpoints explícitos evitam confundir ossos auxiliares de twist com cotovelos/punhos. Nenhuma correção procedural, IK, alteração de comprimento ou nova dependência.

Escopo: somente 8 trilhas de rotação dos braços em Walk, Run e passos laterais. Todas as outras trilhas, incluindo pernas, quadril, tronco e clipes antigos, permanecem idênticas; teste automatizado compara os valores completos com o backup anterior.

Validação:
- 21/21 testes passaram.
- 600 amostras em cada um dos quatro clipes; antebraços fora de um envelope de regressão de 20 cm ao redor do eixo quadril–pescoço.
- Menor distância antebraço/eixo: Walk 20,73 cm; Run 23,33 cm; lateral esquerda 24,00 cm; lateral direita 24,09 cm. É um teste do esqueleto, não uma certificação de colisão da malha/colete.
- Antes, os punhos atravessavam o plano central: Walk até -22,55 cm (L) e -16,90 cm (R), em coordenada lateral orientada para fora. Agora: mínimos +18,24/+27,49 cm no Walk; +5,39/+9,15 cm no Run (mãos à frente do peito durante a corrida).
- Walk e Run revisados visualmente de frente e perfil, incluindo as duas metades da passada.
- Pernas: métricas preservadas, zero aproximações abaixo de 8 cm em 600 amostras por clipe.
- Laboratório ganhou Frente/Perfil/Costas e seletor de fase para reproduzir poses. Na inspeção pausada, métricas ficam suspensas para não exibir valores de outra pose como se fossem atuais.

Relatório: arm-audit-v4.json. Backup: raw-assets/animations/tactical-locomotion-before-arm-fix.json.

As pendências anteriores de hip sway, sliding e performance não foram declaradas resolvidas nesta correção dos braços.

---
<!-- // [LOCOMOTION-FIX v3] -->
# Locomoção — substituição por animações prontas Mixamo

Data: 21/09/2026. Esta versão substitui as alegações de certificação AAA do changelog anterior.

## Problema e diagnóstico

O código anterior emitia DIAG_REPORT com frame e valor constantes, chamava rotação de coxa de Two-Bone IK, e marcava foot locking sem fixar posições. O custo do solver não entrava no indicador de CPU. Os testes antigos também comparavam um diagnóstico literal consigo mesmo.

A auditoria separou distância 3D e distância lateral: 3,99 cm era separação lateral no Walk; a distância 3D mínima real era 8,46 cm. O menor valor 3D foi observado na amostra 259/300 por ciclo, com o tornozelo direito em X positivo. As escalas thigh/shin eram unitárias. Isso não comprova encolhimento do esqueleto. Distância entre tornozelos não é teste de interseção das botas ou joelhos.

## Solução entregue

Por instrução posterior do usuário, removidas as correções procedurais. Sem IK, offsets de escala, foot locking artificial ou animações sintetizadas.

Baixados arquivos FBX prontos: Standard Walk, Running, Idle, Left Strafe Walking, Right Strafe Walking e Sneaking Forward. Quatro estão integrados: Walk e Run substituídos; StrafeLeft e StrafeRight acrescentados. Idle e Sneaking Forward ficam disponíveis como fontes, sem substituir os clipes preservados.

Fonte dos downloads: https://github.com/aaronsnoswell/3DCharacter/tree/master/Mixamo
Origem das animações: Mixamo. Não são assets CC0. Proveniência em raw-assets/mixamo/PROVENANCE.json.

O retarget offline converte os keyframes prontos para os 22 ossos do soldado. Mantém comprimentos e remove apenas o deslocamento horizontal da raiz dos clipes para reprodução in-place com movimento do controlador. Não há pós-processamento procedural da pose no navegador. O carregamento continua por GLTFLoader + tactical-locomotion.json.

O laboratório abre caminhando, mostra o nome do FBX, tem piso plano quadriculado, movimento real com velocidade derivada da fonte, câmera que acompanha, pausa, retorno à origem e controles W/Shift/A/D. O mundo do jogo foi preservado; o cenário de testes é separado.

## Métricas reproduzíveis

600 amostras por clipe, cobrindo dois ciclos completos, 300 amostras por ciclo. Relatórios brutos: locomotion-baseline-v2.json e locomotion-mixamo-v3.json.

| Métrica | Walk antigo | Walk Mixamo | Run antigo | Run Mixamo |
|---|---:|---:|---:|---:|
| Separação 3D mínima (cm) | 8,46 | 29,47 | 18,85 | 43,06 |
| Separação lateral mínima (cm) | 3,99 | 25,23 | 4,17 | 22,37 |
| Amostras com distância 3D <8 cm | 0/600 | 0/600 | 0/600 | 0/600 |
| Hip roll pico a pico (graus) | 4,77 | 8,07 | 9,68 | 17,10 |
| Excursão longitudinal média dos pés (m) | 0,632 | 0,794 | 0,990 | 0,889 |

A métrica strideLength é a excursão média dos tornozelos relativa à raiz, não distância entre dois contatos consecutivos do mesmo pé. Essa definição está explícita para não confundir as medidas.

## Validação e limites

- 19/19 testes passaram; build de produção verificado.
- Keyframes novos são diferentes dos anteriores. Idle, Jog, CrouchIdle, CrouchWalk, JumpStart, JumpLoop, JumpLand, Death, Interact e Pickup são idênticos aos anteriores.
- Walk ↔ Run termina em 0,20 s; teste de continuidade rejeita deslocamentos de tornozelo acima de 20 cm entre amostras a 60 Hz. Isso não substitui revisão artística.
- O HUD mede a pose real e emite DIAG_REPORT observado após um ciclo. Não imprime valores de diagnóstico fixos.
- Sem certificação AAA: hip sway dos novos clipes excede 3–6 graus. Foot locking procedural foi removido conforme solicitação. Ausência de foot sliding ainda não certificada.
- CPU do validador aparece em tempo real, sem custo de IK (inexistente). Foram observados máximos de 0,50 ms e um pico de 4,50 ms durante sessões no navegador. O teto rígido de 0,8 ms/frame não está certificado por perfil DevTools; nenhum Worker foi implementado.
- A captura é do estado real; não foi fabricada uma imagem com todos os indicadores verdes.

## Reprodução

Na pasta survival_online:

    node tools/retarget-mixamo.mjs
    npm test
    npm run build
    npm run dev -w @wasteland/client

Abrir http://127.0.0.1:5174/player-lab.html

Os FBX ficam em raw-assets/mixamo. O backup dos clipes anteriores fica em raw-assets/animations/tactical-locomotion-before-mixamo.json. Nenhuma dependência npm adicionada.


