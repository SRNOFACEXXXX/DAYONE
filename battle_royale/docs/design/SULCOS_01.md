# SULCOS_01 — sulcos de roda nas estradas de terra principais

Origem: CRITICA_MAPA_05, ajuste 3. Os dados estão em `chao_vivo.json` → `sulcos_roda`.

- **26 polilinhas, 5,43 km** de sulco no total (744 pontos). Largura 0,35 m, cor `#7C4C31`.
- Cada sulco fica a ±0,8 m do eixo autoral de `ilha_layout.json` → `estradas` (bitola de 1,6 m). Nos vértices, o deslocamento usa meia-esquadria para acompanhar a curva. Pontos a cada ≤ 8 m, além dos vértices do eixo. Não há ruído nem sorteio.
- Estradas: E1 Costa Sul (Vila/Fazenda), E2 Coqueiros (Fazenda), E3 Pista, E4 Leste (Pista), E5 Pedreira→Quartel, E8 Usina→Morro, E9 Costa Oeste (Vila), E10 Represa. Ficaram de fora E6, E7 e E11 (menos tráfego), V1/V2 (calçamento) e as trilhas.
- Onde o sulco é interrompido:
  - Cruzamentos e entroncamentos: meia largura da via que cruza + 4 m (E1×T4, E3×P1, E9×V1, E10×E11 e todas as pontas das estradas).
  - Ponte da Vila e rio: E1 e E9, junto de (-367,-330).
  - Crista da Barragem: E10, trecho de 70 m.

| Estrada | Polilinhas | m |
|---|---|---|
| E1 | 4 | 510 |
| E2 | 2 | 574 |
| E3 | 4 | 428 |
| E4 | 2 | 813 |
| E5 | 2 | 920 |
| E8 | 2 | 854 |
| E9 | 4 | 614 |
| E10 | 6 | 721 |

Atenção: `chao_vivo.json` é gerado por `tools/chao_vivo_src.py`, e esse gerador ainda não conhece `sulcos_roda`. Se ele rodar de novo, a lista some.
