# Estande de tiro — critérios de aceite (movimentação, tiro e mira)

Cena: `game/maps/estande/` (EstandeMatch). Jogável pelo menu ("Estande de tiro") e testável sem a ilha:
`--path game res://tests/estande_gate.tscn -- --out=raw/estande_XX [--only=ak47]`.
Referências: `docs/ref/ak47_fps.jpg` (AK em mira aberta), `docs/ref/mosin_lowpoly.png` (Mosin no quadril).

Um item só é "aprovado" com o número medido **e** a captura olhada ao lado da referência.

## Mira (por arma: ak47, m4, mosin, glock, usp)
| # | Critério | Medida | Limite |
|---|---|---|---|
| M1 | Alça e massa no centro da tela com mira ativa | projeção das duas marcas de mira (espaço da arma → tela, com o FOV do viewmodel) | ≤ 2 px na horizontal, ≤ 3 px na vertical (topo da massa) em 1024×768 |
| M2 | Uma única mira em ADS | nenhum retículo/crosshair de tela desenhado com alça aberta | 0 elementos de tela |
| M3 | Tiro sai onde a massa aponta | média dos impactos de 5 tiros a 25 m, parado, em ADS | ≤ 6 cm do ponto visado |
| M4 | Enquadramento da mira como a referência | alça ocupa a parte baixa-central; arma não cobre mais que 45% da tela | captura lado a lado |
| M5 | Mira estável | sem bob/sway parado em ADS | deslocamento das marcas ≤ 1 px entre quadros parados |

## Quadril e corpo
| # | Critério | Medida | Limite |
|---|---|---|---|
| Q1 | Arma no quadril à direita e baixa, mãos inteiras | cano no quadrante inferior direito; nenhuma mão cortada pela borda | captura |
| Q2 | Sem corpo/braço do personagem de 3ª pessoa na câmera FP | geometria do BodyModel do jogador local em SHADOWS_ONLY | 100% das malhas |
| Q3 | Sem ombro/braço gigante do viewmodel | nenhum vértice dos braços a < 12 cm da câmera | captura |

## Movimentação (percurso do estande)
| # | Critério | Limite |
|---|---|---|
| V1 | Passa por porta de 1,0 × 2,1 m andando reto | atravessa sem travar |
| V2 | Pula mureta de 1,0 m e muro de 1,5 m (mantle) | chega do outro lado em ≤ 2 s |
| V3 | Sobe escada de degraus de 0,18 m e rampa de 25° | chega na plataforma de 1,8 m |
| V4 | Não atravessa parede nem para no ar (sem parede invisível) | colisão = caixa visível |

## Desempenho
- ≥ 60 FPS no estande a 1024×768 na GT 730 (Compatibility).
