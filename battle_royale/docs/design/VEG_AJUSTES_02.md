# VEG_AJUSTES_02: mata sem fileira (CRITICA_MAPA_03, ajuste 5)

Data: 26/09/2026. Arquivo alterado: `vegetacao.json`, somente `x`, `y`, `z` e `escala` das instâncias listadas abaixo.
Os demais campos continuam iguais: `fonte`, `tipos`, `folgas`, contagens, `canaviais` e o total de 8.517 instâncias.

## Diagnóstico
As matas saem dos carimbos D1, D2, M1, CL e FC, cada um com cerca de 3×3 árvores, aplicados numa grade de 28 m (ou 36 m no
coqueiral) e girados só em múltiplos de 90°. Por isso a mata inteira forma uma **malha de ~9,5 m alinhada aos eixos X e Y**,
com jitter de apenas ±1,5 m. De longe isso lê como fileira. No Coqueiral da Orla o efeito é pior: são duas linhas retas de
coqueiros em y = −440 e y = −456, com 250 m de comprimento.

## Critério (tabelas autorais, sem sorteio nem ruído)
O script só aplica as tabelas abaixo. Não há `random` nem ruído.
1. **Vaga do carimbo**: cada vaga do carimbo recebe um deslocamento escrito à mão, em coordenadas locais e girado junto com a
   âncora. Os valores foram escolhidos para desfazer a malha 3×3 alternando o lado de cada vaga.
   - D1: (−2,0 1,5) (1,5 −1,0) (2,5 1,0) (−1,0 −2,5) (1,0 1,5) (−2,5 0,5) (1,5 2,0) (−1,5 −1,5) (−2,0 −1,0)
   - D2: (1,5 2,0) (−2,0 1,0) (−1,0 −2,5) (2,5 −1,0) (1,0 2,5) (−1,5 −1,5) (2,0 −0,5) (1,5 −2,0) (−2,5 1,0)
   - M1: (−1,5 2,0) (2,0 1,5) (−2,5 −1,0) (1,0 −2,5) (−1,0 −1,5)
   - CL: (1,0 2,0) (−1,5 −1,0) (2,0 −1,5) (−1,0 2,5)
   - FC (coqueiros): (−1,0 −2,5) (1,5 2,0) (0,0 −3,0) (−1,5 1,0) (2,0 2,5)
2. **Âncora**: o carimbo inteiro desloca por um ciclo fixo de 7 vetores, na ordem das âncoras da mancha:
   (1,5 −1,0) (−1,0 −1,5) (0,0 1,5) (−1,5 0,5) (1,0 1,0) (−0,5 −1,0) (1,5 0,5). Assim, células vizinhas deixam de coincidir.
   A soma dos dois deslocamentos é limitada a **1–3 m**.
3. **Clareiras** escolhidas à mão, dadas como centro (x, y) e raio. As árvores dentro do raio vão **3 m para fora, radialmente**.
   - Serra: (−100, 165) r10, (0, 185) r10, (−150, 140) r9
   - Serra Leste: (190, 135) r10
   - Morro do Sul: (120, −120) r10, (180, −95) r10, (90, −150) r9
   - Encosta Norte: (−60, 265) r10, (−115, 240) r9
   - Esporão Norte: (70, 322) r9
   - Contraforte Leste: (360, 130) r10
   - Flanco Sul: (−80, 90) r9
   - Represa Norte: (−60, 45) r8

   Ao todo, 32 árvores abrem 13 clareiras.
4. **Folgas**: valem as regras de `vegetacao.json`. A árvore fica a ≥ 3 m de via, ≥ 4 m de prédio, ≥ 1,5 m do leito do rio,
   ≥ 2 m da represa, ≥ 3 m de outra árvore e ≥ 1,2 m de planta menor. Também ficou longe de pátio, mar, cobertura, prop e cerca.
   Quando o vetor da tabela violava alguma folga, a árvore tentou a mesma tabela nesta ordem fixa: ×0,6, espelhado e girado ±90°.
   Nenhuma árvore ficou sem posição válida. `z` foi reamostrado (bilinear) no `height.bin`.
5. **Escala 0,8 / 1,0 / 1,25**: miolo grande e borda pequena. O critério é o número de árvores vizinhas a 15 m:
   - árvores de mata: ≤ 4 vizinhas → 0,8 (borda); 5–6 → 1,0; ≥ 7 → 1,25 (miolo);
   - coqueiros: ≤ 1 → 0,8; 2 → 1,0; ≥ 3 → 1,25.
6. **Fica de fora de propósito**:
   - o Quebra-vento de Eucalipto (54 árvores), porque é fileira real de propósito;
   - árvores isoladas de pasto (AI), capoeira (CP) e quintais (QT), porque não formam linha.

## Resultado
| Medida | Antes | Depois |
|---|---|---|
| Árvores reposicionadas (deslocamento 1,0–3,0 m, média 2,4 m) | — | **1.125** de 1.254 |
| Escala alterada | — | **1.005** (as 1.125 tratadas ficaram em 0,8: 417 · 1,0: 322 · 1,25: 386, ≈ 1/3 cada) |
| Árvores em "fileira de eixo" (≥ 5 colineares a ±1,2 m em 40 m, direção 0°/90°) | **197** | **85** |
| Mesma medida nas direções de controle 30°/120° e 60°/150° (nível de acaso) | 33 / 81 | 62 / 87 |

Depois do ajuste, a direção dos eixos ficou no nível das direções de controle, ou seja, a mata perdeu a direção preferencial.
Por mancha:
| Mancha | Árvores |
|---|---|
| Morro do Sul | 230 |
| Serra | 192 |
| Encosta Norte | 152 |
| Serra Leste | 105 |
| Contraforte Leste | 76 |
| Esporão Norte | 65 |
| Coqueiral da Orla | 63 |
| Bordas de Mata | 55 |
| Ciliar | 54 |
| Flanco Sul | 48 |
| Coqueiros das Praias | 38 |
| Represa Norte | 20 |
| Cabeceira | 18 |
| Sul | 9 |

**Pendente (não pedido nesta rodada):** os 2–3 arbustos de 1,2 m na borda da mata, parte do ajuste 5 da crítica, e os pares a
≤ 2,5 m. Os pares entram em conflito com a folga `entre_arvores_m` = 3,0 m e precisam de decisão do diretor.
Obs.: `tools/vegetacao_src.py` não foi alterado. Se ele for rodado de novo, estes ajustes se perdem, a menos que as tabelas acima
sejam levadas para os carimbos.
