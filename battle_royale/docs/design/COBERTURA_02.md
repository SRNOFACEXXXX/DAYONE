# COBERTURA_02: nenhum ponto de campo a mais de 25 m de cobertura (CRITICA_MAPA_03, ajuste 4)

Data: 26/09/2026. Arquivo alterado: `gameplay_01.json`. Foram acrescentadas 100 entradas em `coberturas_novas`, todas com
`"lote": 3`, e `contagem_coberturas_por_tipo` foi recontada. A mata usada na análise já é a de `VEG_AJUSTES_02`.

## Método (definição do diretor)
- **Grade** de 5 m sobre [−600, 600]². O ponto conta como jogável quando está em terra (z > 0,3 m, dentro da costa) e fora
  de represa, rio, estrada ou ponte, prédio e canavial. O canavial fica de fora porque oculta, mas não é campo aberto.
  São **32.827 pontos**.
- **Cobertura**: `coberturas_novas` e `cobertura_campo_aberto` (altura ≥ 0,8 m), amostradas ao longo do comprimento de cada tipo.
  Também contam o contorno dos prédios (menos o heliponto) e os troncos de árvore (`arvore_mata_a`, `arvore_mata_b` e `coqueiro`).
  Muros e cercas **não** contam.
- **Praia rasa** é todo ponto com z < 2,5 m a menos de 25 m da linha de costa. Ela entra no % total, mas não recebe cobertura.

## Antes / depois
| Medida | Antes | Depois |
|---|---|---|
| % da área jogável a > 25 m de cobertura | **1,01%** (331 pts ≈ 8.275 m²) | **0,20%** (66 pts) |
| — em área de combate | 0,75% (245 pts, 16 bolsões) | **0,00%** (0 pts) |
| — em praia rasa | 86 pts | 66 pts |
| Distância máxima em área de combate | 38,7 m | **≤ 25 m** |
| Distância máxima geral (praia) | 44,6 m | 39,4 m |

Com a vegetação original (antes do VEG_AJUSTES_02), o "antes" era de 0,97%. Deslocar a mata abriu 11 pontos novos,
e eles foram cobertos aqui.

## Onde estavam os bolsões
Quase todos os bolsões ficavam **junto aos muros do Quartel e da Usina**, dos dois lados. O muro não entra na regra, e o pátio
dentro dele é área de combate. Os outros ficavam no promontório do Farol, no pátio da Pedreira e em 12 células isoladas
de 25–27 m.

## Coberturas acrescentadas (lote 3): 33 grupos, 100 itens (orçamento: +250)
Cada grupo tem de 3 a 4 itens a ≤ 4 m do centroide e ≥ 2,5 m entre si. Todos passaram pela `Folgas.checar` de
`tools/gameplay_src.py`, com via +1,5 m, prédio +1,5 m, porta, cerca ou muro, tronco, poste e cobertura existente a ≥ 3 m,
e nenhum item caiu dentro de canavial.
- **Tema militar** (sacos de areia, tambores, pneus, trincheira) nos grupos dentro e em volta do quartel.
- **Tema de pátio industrial** (carcaça, tambores, pneus, carreta, trator) na usina.
- **Tema de pasto e mata** (matacão, cupinzeiro, tronco caído, fardo, cocho) nos demais.

| Grupo | Itens | Tipo (x, y) rot |
|---|---|---|
| Q1 pátio leste do quartel | 4 | sacos_areia (401, 308) 0°; sacos_areia (404, 305) 90°; tambor_x4 (398, 303) 20°; pilha_pneus (401, 301) 0° |
| Q2 corredor heliponto/muro leste | 3 | sacos_areia (406, 323.5) 90°; tambor_x4 (406, 327) 90°; pilha_pneus (406.5, 330.5) 0° |
| Q3 fora do muro leste | 3 | matacao (421, 288) 15°; cupinzeiro (424, 284) 0°; tronco_caido (418, 284) 110° |
| Q4 portão sul, lado de fora | 3 | carcaca_fusca (340, 216.5) 170°; sacos_areia (343.5, 217.5) 0°; tambor_x4 (337, 218.5) 30° |
| Q5 pátio sul, junto ao muro | 3 | sacos_areia (322, 228) 0°; tambor_x4 (318, 231) 0°; pilha_pneus (325, 231) 0° |
| Q6 pátio sudoeste (paiol), a oeste da via do portão | 3 | sacos_areia (276, 229) 45°; tambor_x4 (273.5, 231.5) 0°; pilha_pneus (278.5, 226.5) 0° |
| Q7 fora do muro oeste | 3 | matacao (212, 363) 30°; cupinzeiro (216, 361) 0°; tronco_caido (213, 366.5) 60° |
| Q8 fora do muro norte, canto NO | 3 | sacos_areia (231, 385) 0°; sacos_areia (235, 388) 90°; tambor_x4 (228, 389) 0° |
| Q9 fora do muro norte, caixa d'água | 3 | matacao (276, 385) 0°; cupinzeiro (279, 383) 0°; tronco_caido (273.5, 387.5) 20° |
| Q10 fora do muro norte, atrás do comando | 3 | trincheira (321, 383) 0°; sacos_areia (321, 387) 0°; tambor_x4 (325, 386.5) 90° |
| Q11 fora do muro norte, guarita NE | 3 | matacao (368, 384) 0°; pilha_pneus (371, 381) 0°; tronco_caido (365, 381) 170° |
| P1 pátio da pedreira | 3 | matacao (316, 11) 0°; matacao (320, 6) 40°; tambor_x4 (315, 6) 0° |
| F1 mirante oeste do farol, aquém da cerca | 3 | matacao (40, 528) 0°; matacao (43.5, 530) 50°; tronco_caido (37.5, 525.5) 30° |
| F2 mirante norte do farol, aquém da cerca | 3 | matacao (66, 534) 20°; matacao (70, 532.5) 70°; tronco_caido (63, 535.5) 5° |
| U1 pátio norte da usina (chaminé) | 3 | tambor_x4 (-271, 373) 0°; pilha_pneus (-267, 370) 0°; carcaca_fusca (-274, 369) 80° |
| U2 fora do muro oeste (canavial oeste) | 3 | fardo_feno_x3 (-376, 294) 60°; cupinzeiro (-379, 297) 0°; cocho (-373, 297.5) 20° |
| U3 fora do muro sul, oeste | 3 | carreta_cana (-289, 237) 175°; pilha_pneus (-292, 240.5) 0°; tambor_x4 (-285, 240.5) 0° |
| U4 fora do muro sul, leste | 3 | trator (-262, 237) 10°; pilha_pneus (-259, 240.5) 0°; tambor_x4 (-265, 240.5) 0° |
| U5 fora do muro leste, guarita | 3 | fardo_feno_x3 (-188, 255) 100°; cupinzeiro (-186, 251) 0°; tronco_caido (-191, 251) 30° |
| U6 fora do muro leste, tanque | 3 | matacao (-188, 326) 0°; cupinzeiro (-184, 324) 0°; tronco_caido (-191, 323) 30° |
| R1 fora do canto sudoeste do quartel | 3 | sacos_areia (222, 203) 45°; tambor_x4 (225, 201) 0°; pilha_pneus (219.5, 205.5) 0° |
| R2 portão oeste do quartel (posto de controle) | 3 | sacos_areia (232, 318) 90°; tambor_x4 (235, 315) 0°; pilha_pneus (235.5, 321) 0° |
| R3 encosta leste do Pico | 3 | matacao (127, 77) 25°; tronco_caido (130.5, 75) 140°; cupinzeiro (124.5, 80) 0° |
| R4 Esporão Norte, borda da mata | 3 | matacao (122, 328) 0°; cupinzeiro (125.5, 326) 0°; tronco_caido (119.5, 331) 75° |
| R5 Estrada do Farol, curva do T2 | 3 | matacao (80, 422) 10°; cupinzeiro (83, 420) 0°; tronco_caido (77.5, 425) 120° |
| R6 Subida do Pico, baixada leste | 3 | matacao (40, -82) 0°; tronco_caido (43, -80) 30°; cupinzeiro (42, -85.5) 0° |
| R7 entre a Represa e o Morro do Sul | 3 | matacao (28, -158) 60°; cupinzeiro (31, -156) 0°; tronco_caido (25.5, -155) 10° |
| R8 restinga do Coqueiral | 3 | matacao (2, -486) 0°; tronco_caido (5.5, -484.5) 165°; matacao (-1, -483.5) 35° |
| R9 Pasto da Fazenda, sudeste | 3 | fardo_feno_x3 (-78, -378) 20°; cocho (-75, -381) 110°; cupinzeiro (-81, -381) 0° |
| R10 saída norte da Usina | 3 | carcaca_fusca (-236, 373) 100°; tambor_x4 (-239, 376) 0°; pilha_pneus (-238.5, 370) 0° |
| R11 Morro do Cruzeiro, abaixo da crista | 3 | matacao (-282, -42) 0°; tronco_caido (-278.5, -44) 15°; cupinzeiro (-285, -45) 0° |
| R12 canto sudoeste da Usina, além da Estrada E8 | 3 | fardo_feno_x3 (-336, 218) 40°; cupinzeiro (-333, 215.5) 0°; cocho (-339, 215) 40° |
| R13 Estrada da Pedreira ao Quartel, lado do mar | 3 | matacao (434, 101) 0°; tronco_caido (437, 98.5) 80°; cupinzeiro (433, 97.5) 0° |

Itens por tipo: matacao 20 · tronco_caido 16 · cupinzeiro 15 · tambor_x4 14 · sacos_areia 11 · pilha_pneus 11 · fardo_feno_x3 4 ·
carcaca_fusca 3 · cocho 3 · trincheira 1 · carreta_cana 1 · trator 1.
Total de `coberturas_novas`: 443 → **543**.

**FPS:** a crítica pede que, pela compensação do ajuste 4, `tambor_x4`, `pilha_pneus` e demais itens com menos de 1 m saiam sem
sombra e com alcance de 90 m. Isso fica a cargo de quem implementa `detalhes.gd`. Os 100 itens estão bem abaixo do teto de 250.
