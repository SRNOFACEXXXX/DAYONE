# Cenário por área 01 — peças dos pacotes do usuário

Dados: `docs/design/cenario_areas.json` (cópia idêntica em `game/maps/ilha/cenario_areas.json`, lida por `maps/ilha/detalhes.gd`).
Tudo foi posicionado à mão: cada coordenada está escrita no JSON, sem sorteio. **238 peças em 12 áreas**, com **17 carros** no total.

Convenções usadas:
- rot_deg segue o `ilha_layout` (anti-horário). A porta dos prédios fica na face -Y local, ou seja, voltada para `rot_deg - 90`.
- Carros têm o comprimento no Z local. Para alinhar com uma rua na direção φ, usei `rot = φ + 90`. A captura `cen_vila_rua` confirma o alinhamento.
- Carro estacionado fica a 5,2–5,5 m do eixo de uma estrada de 7 m, ou seja, no acostamento.

## Áreas

| Área | Peças | Intenção (resumo) |
|---|---|---|
| Vila | 34 | 4 carros na beira da E1, da V1 e da E9, e um táxi na Pousada. Praça da capela com 2 bancos, lixeira e carvalho. Correio na Pousada, hidrante na ponte, jornal e caixas na porta do Bar do Tião, um bueiro na V1. Lenha nos quintais de 6 casas, tábuas nos ranchos, fogueira de pescador com tocos, salgueiros na margem do rio. |
| Cruzeiro | 14 | Carros só no pé do morro (a escadaria não sobe carro). 2 bancos voltados para a cruz, caixas de papelão no Bar da Laje, entulho de obra e tábuas nos fundos, lenha. |
| Usina | 18 | Muro do engenho antigo em ruína (em L) ao lado da moenda, entulho da destilaria, tábuas no armazém, pilhas de toras junto à chaminé, sedã abandonado torto no pátio, caixas no escritório, lenha na vila operária. |
| Farol | 12 | Matacões e pedras grandes na borda do costão, árvore seca, carro do faroleiro no fim da estrada, lenha e tábuas. |
| Quartel | 26 | Chicane de 8 barreiras e 4 cones na E5, no portão sul (bloqueio intencional). Viatura largada torta no acostamento e outra na garagem. Barreiras e cones no portão oeste e na porta do paiol, caixas no refeitório e na garagem. |
| Pedreira | 22 | Blocos de granito (rocha_grande em escala 1,3–1,9) e pedras grandes no fundo da cava, pedriscos, montes de terra na saída da correia, entulho atrás da oficina, tábuas nos contêineres, sedã do encarregado, barreira no paiol de explosivos. |
| Pista | 17 | Cabeceira oeste interditada com 6 barreiras em escala 1,25 e cones. Cones no eixo da pista a cada 30 m, fora da carcaça do teco-teco. Táxi na casa do piloto, sedã no depósito, tábuas e caixas no hangar. |
| Represa | 10 | Área mínima de propósito, porque a vista da barragem é a mais pesada. Barreiras leves na cabeceira da crista, pedras e galho no remanso abaixo da barragem, tronco na margem norte, sedã e lenha do caseiro fora do alcance da vista da barragem. |
| Fazenda | 41 | Piquete de cerca de ripas encostado no curral: 31 × 30 m, 21 peças, porteira aberta a norte. Pilha de toras na tulha, lenha no casarão e nas 3 casas de colono. Fogueira com tocos-banco no terreiro, tocos e árvore seca no pasto, carvalhos de sombra, carro velho perto do paiol. |
| Praia | 16 | Troncos, galhos e raiz trazidos pelo mar na linha da maré, fogueira de pescador, pedras nas pontas, 2 carros na estrada em frente ao restaurante, banco da orla. |
| Matas e trilhas | 26 | Troncos caídos, tocos, samambaias, raiz e rocha com urtiga na beira das trilhas T1 a T5 (sempre a mais de 2,5 m do eixo), pedras nas margens do Vau (fora d'água) e 3 árvores secas isoladas em campos. |
| Campo aberto | 2 | Matacão grande e tronco caído no único vazio de campo acima de 32 m sem cobertura, em (-180, 210). O resto do mapa já estava coberto pelas 590 coberturas do gameplay_01. |

## Conferência

Rodei um validador de apoio que não gera conteúdo, só confere. Ele verifica, em cada peça, a distância às vias pela largura, a planta e a porta dos 100 prédios, o mar e a represa (`agua.png`), o leito do rio, os props existentes, as coberturas e as árvores do `vegetacao.json`, além da rampa sob os carros.

Sobraram só avisos intencionais:
- carros no acostamento;
- jornal na porta da venda;
- quinas da cerca do piquete;
- capim e urtiga no pé do muro em ruína.

Colisão: com `--probe`, um raio sobre o sedã da Usina acerta `DetalhesColisao` em (-264, 299). O carro recebe casco convexo, e as peças `rua_*` usam a própria colisão UCX.

Vistas novas no tour: `cen_vila_rua`, `cen_vila_praca`, `cen_vila_bar`, `cen_morro_pe`, `cen_morro_cruzeiro`, `cen_usina`, `cen_farol`, `cen_quartel_portao`, `cen_quartel_patio`, `cen_pedreira`, `cen_pista_cabeceira`, `cen_pista_hangar`, `cen_fazenda_piquete`, `cen_fazenda_colonos`, `cen_praia`, `cen_praia_carros`, `cen_trilha`, `cen_vau`. Há também 2 vistas de sonda de colisão: `cen_colisao_viatura` e `cen_colisao_sedan_usina`.

Observação sobre `--probe`: o viewport base é 1280×720 com stretch `canvas_items`. Por isso a coordenada da sonda não é o pixel da captura de 1024×768; o sedã fica em `--probe=700;600`.

## FPS (`--perf`, 1024×768, sem vsync, `raw/design_02`)

| Vista | ms | FPS |
|---|---|---|
| cen_vila_rua | 12,4 | 80 |
| cen_vila_praca | 12,7 | 79 |
| cen_vila_bar | 6,8 | 148 |
| cen_morro_pe | 14,1 | 71 |
| cen_morro_cruzeiro | 13,1 | 76 |
| cen_usina | 7,5 | 134 |
| cen_farol | 6,5 | 153 |
| cen_quartel_portao | 14,9 | 67 |
| cen_quartel_patio | 7,8 | 128 |
| cen_pedreira | 15,7 | 64 |
| cen_pista_cabeceira | 8,4 | 119 |
| cen_pista_hangar | 11,3 | 88 |
| cen_fazenda_piquete | 10,0 | 100 |
| cen_fazenda_colonos | 7,6 | 132 |
| cen_praia | 6,1 | 163 |
| cen_praia_carros | 12,6 | 80 |
| cen_trilha | 8,5 | 118 |
| cen_vau | 11,6 | 86 |
| represa_barragem | 13,5 | 74 |
| morro_casas | 11,9 | 84 |
| vila / usina / fazenda / quartel_poi | 8,0 / 9,7 / 9,1 / 8,6 | 124 / 103 / 110 / 116 |

Comparação com e sem `cenario_areas.json`, nas mesmas vistas e condições: o custo foi de +0,0 a +0,4 ms e +20 a +50 draws por vista. Exemplos:
- `cen_pedreira`: 15,7 → 15,7 ms;
- `cen_vila_praca`: 12,3 → 12,7 ms;
- `cen_quartel_portao`: 14,7 → 14,9 ms.

Nenhuma vista decorada ficou abaixo de 60 FPS.

Atenção: havia outros processos do Godot rodando na máquina (outros trabalhos em paralelo). Nas primeiras vistas de cada execução a medição oscilou muito, com `morro_casas` entre 29 e 84 FPS e `represa_barragem` entre 35 e 74 FPS, com e sem as peças novas. Convém repetir a medição com a máquina livre.

## Pendências

- `rua_newspaper` (9,8 mil faces) e `rua_envelope_*` (9 a 18 mil faces) são caros para o tamanho. Usei 1 jornal e nenhum envelope. Vale reduzir as malhas.
- Os carros ficam apoiados na altura do centro, sem inclinar com o terreno. Escolhi pontos com rampa menor que 0,7 m no comprimento, mas em encosta o carro pode flutuar alguns centímetros.
- A pista de terra desenhada no terreno é mais larga que os 7 m do layout em algumas curvas (portão sul do Quartel). Por isso afastei a viatura para cerca de 7 m do eixo. Convém conferir outras curvas no playtest.
- As caixas de armas do pacote (`cenario/caixas/caixa_N_corpo/tampa`) não entraram, porque ficam para o saque. A `caixa_2_tampa` tem escala errada no glb (±29 m).
- A foto `docs/ref/ak47_fps.jpg` pede capim alto e cercas de ripas mais presentes nos quintais da Vila. Isso pode entrar no próximo passe com `tufo_capim` e `cerca_madeira_curta`, medindo FPS em `cen_vila_rua` e `cen_vila_praca`.
