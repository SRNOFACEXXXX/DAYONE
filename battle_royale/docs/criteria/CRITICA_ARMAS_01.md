# Crítica armas 1ª pessoa — rodada 01 (2026-10-02)

Base: capturas 1280x720 em raw/ads_review e raw/recarga vs ref ak47_fps.jpg, mosin_lowpoly.png, mira_holografica_REF.md.
Cores medidas por amostragem de pixel.

## Por arma
**M4 quadril** — ocupa x 640–1010, y 365–720 (~29% L x 50% A); centro ≈ (820,560), 180 px à direita do centro. Ref AK: centro x≈51% da tela, arma alinhada ao eixo, mãos dos dois lados. Mão esquerda #3c3c3c (luva preta indistinguível do metal); mão direita invisível. Corpo #554941–#726c66 (marrom-acinzentado sujo) vs ref #5d6766 cinza-azulado chapado. Massa de polígonos pequenos/ruído no guarda-mão.
**M4 iron** — massa de mira traseira cobre x 575–730, y 345–580; dioptra ~40 px, poste e alça desalinhados ~8 px; o carregador/punho cobre ~25% inferior. Mãos quase invisíveis.
**M4 holo** — moldura 160x130 px (x 560–720, y 315–445). A metade inferior da janela (y 360–425) está tapada por bloco escuro #111d2c: só ~40% da janela mostra cenário. Ref exige janela 100% transparente. Retículo vermelho centrado em (640,360) — OK. Moldura #2c3d4e azul-marinho, sem facetas claras.
**M4 holo quadril** — mira traseira de ferro visível atrás da holo (proibido pela ref).
**M4 ACOG** — vinheta circular 490 px, fundo #1a1e22 a ~85% opaco: 70% da tela perdida; sem corpo da luneta, sem arma. Retículo cruz ok.
**Glock** — quadril: 140x300 px, centro (795,570), sem mão de apoio; iron: alça bem alinhada, mãos #4a4641 marrom-cinza sem dedos legíveis.
**Recarga Glock** — arma gigante (~35% L x 75% A), bege #ac997e (não preta), mão branca/cinza #86888c deformada; carregador flutuando sem mão.
**Recarga M4** — rotação ~35°, arma cobre ~45% da tela; mão esquerda branca fantasma (#3f4e57 e dedos brancos) desconectada.
**M249** — quadril ok de escala (~22% L), mas holo + alça de ferro juntas; no ADS a caixa da holo (y 395–470) tapa 45% da janela; sem mãos visíveis.
**M107** — ADS: trilho ocupa canto inferior esquerdo 0–600 px (~30% da tela) — enquadramento quebrado; mão #695b54 sem luva consistente.
**Mosin** — ref: arma diagonal, madeira laranja #b0662a, mãos verdes de manga. Atual: luneta encara a câmera (tubo preto 100 px no centro), madeira #3d2a22, mão bege #ae9e89 + braço branco.

## O que mais incomoda
Janelas de mira obstruídas, mãos que não parecem mãos (cores aleatórias: preto, bege, branco, cinza), e armas deslocadas à direita sem a segunda mão visível. Parapeito cinza desfocado (#626567) cobre 35% inferior da tela em todas as capturas.

## 8 correções (alvo verificável)
1. Holo: janela livre ≥95% da área interna; nenhum pixel de mira de ferro/bloco < y_retículo+40 px.
2. Mãos: uma paleta única — luva #3a3f2e ou pele #dbbea0 (ref), contraste ΔL ≥25 vs arma; 2 mãos visíveis no quadril (≥3% da tela cada).
3. Quadril: centro da arma em x 700–760 (55–59%), y 540–600; arma ocupa 25–30% L.
4. Materiais flat: corpo M4 #5d6766±10, ≤3 tons por peça, sem ruído de microfaces.
5. ACOG: vinheta opacidade ≤60%, círculo ≥560 px, corpo da luneta visível nas bordas.
6. Recarga: arma rotação ≤25°, cobre ≤35% da tela; mão nunca branca; carregador sempre preso a uma mão.
7. Mosin: ângulo diagonal 30–40° como ref, madeira #b0662a±15, luneta não frontal (tubo ≤4% da tela).
8. M107/M249 ADS: arma ≤20% da tela fora da mira; cenário de teste sem parapeito (capturar em campo aberto).

**Nota geral: 4/10.**
