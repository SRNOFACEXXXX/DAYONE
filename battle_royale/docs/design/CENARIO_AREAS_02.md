# Cenário por área 02 — quintais, alamedas e sítios

Dados: `docs/design/cenario_areas_02.json` (cópia idêntica em `game/maps/ilha/cenario_areas_02.json`, lida por `maps/ilha/detalhes.gd`).
O passe 01 (`cenario_areas.json`, 238 peças) não foi tocado. **997 peças novas em 14 áreas**, 173 árvores, 436 cercas de ripas, 4 carros.

Como foi feito (nada sorteia):
- Fonte autoral: `tools/cenario_02_src.py` (ajudantes) + `tools/cen02_*.py` (uma decisão por linha: tipo, ponto, ângulo). Rodar: `python tools/cenario_02_gerar.py`.
- Os ajudantes só expandem decisões geométricas: "cerca de A até B com vão de portão aqui" vira peças contíguas de 4,5 m e 2,2 m (escala uniforme entre 0,85 e 1,2); "alameda de A até B, a 5,5 m do eixo, a cada 16 m" vira uma fileira de árvores; o que é relativo a uma casa usa o referencial dela.
- Conferência: `python tools/checa_cenario.py` (só valida; não gera nem move nada). Estado final: **0 erros, 28 avisos** (todos de proximidade com peças antigas, ver "Pendências").
- Mudança do coordenador (casa_demo): todas as casas residenciais foram tratadas como retângulo 14 x 14 m (vila_operaria 26 x 14, casarao 28 x 15), com a porta virada para o centro do POI, e as 9 casas extras de `casas_pacote.json` entram como obstáculos. Cercas ficam a 4 m da parede nos quintais da Vila e da Fazenda (lote de 22 x 22 m) e a 1,7 m nos lotes apertados do Cruzeiro; o validador reprova cerca a menos de 1,5 m da casa.

## Áreas

| Área | Peças | Intenção |
|---|---|---|
| Vila: quintais | 315 | Cada casa tem lote cercado de ripas (frente, direita e esquerda; os fundos ficam abertos para o terreiro), com **vão de portão de 3 m no eixo da porta**. Cada quintal conta um ofício: pescador (canoa virada, caixotes de peixe), lavadeira (varal, lenha), obra (tijolo, tábua, entulho), horta (arbustos em fileira, banco), oficina (tambores), sobrado de jardim (arbustos, bétula, banco). O Bar do Tião tem pátio com mesas e arvore_d; os dois ranchos de pesca têm canoa de reserva. Onde a V1 passa rente (lote 01) e onde há barranco de 40 graus (lote 13) a cerca abre um vão. |
| Cruzeiro: lotes da ladeira | 176 | As casas, coladas e viradas para o cruzeiro, não comportam lote de 22 m: cada uma tem **quintal da frente** com cerca (frente com portão de 2,6 m e retorno de 4,5 m nos lados) e um canto de vida (lenha e toco, obra da próxima laje, canteiro, tambores de óleo, entulho e barril). Pontos em que a cerca bateria na V2 ou na casa vizinha foram abertos à mão. |
| Fazenda: casarão, colonos e capela | 119 | Casarão (2 casas lado a lado): jardim da frente cercado com **dois portões alinhados às duas portas**, sebe de arbustos, 2 carvalhos de sombra e bancos. Três colonos com lote de 22 m e kits de roça. Capela com adro de cerca baixa (portão de 3,6 m), 2 bancos, lixeira, carvalho. Tulha com toras, tábuas e barris; paiol com tambores e tijolo. |
| Alamedas das estradas | 134 | Fileiras de carvalho, arvore_d, bétula, arvore_b e pinheiro_medio em quincôncio ao lado de E1 a E9, nos trechos de campo aberto (a 5,5 m do eixo; 5,0 m nas de 6 m), como na referência `mosin_lowpoly.png`. Pulam a casa do pacote em E1 e o paiol da Fazenda. |
| Usina Santa Cruz | 35 | Varal, bicicleta e lixeira na fachada da vila operária, barris de melaço e toras de cana na moenda, tijolos da chaminé que caiu, tambores junto ao tanque, mesa e bancos do escritório, barreiras e cones no acostamento do posto de guarda. |
| Quartel do 7º BIL | 30 | Mesas do rancho ao ar livre e caixas de ração no refeitório, bancos e arbustos no comando, 4 tambores alinhados no paiol, tambores na garagem, cones nos 4 cantos do heliponto, árvores de sombra. |
| Pedreira São Jorge | 19 | Pilha de brita e pedras sob o britador, tambores e tijolo no galpão, canto de lanche nos contêineres, barreira e cones no paiol de explosivos, cones na borda norte da cava, 2 matacões. |
| Pista do Tauá | 17 | 4 tambores de combustível alinhados no hangar, caixa, lenha e bicicleta na casa do piloto, tambores no tanque e **6 balizas na borda sul da pista**. |
| Farol da Ponta Norte | 13 | Varal, lenha, bicicleta e barril na casa do faroleiro, tambores no gerador, 2 bancos para olhar o mar e arbustos ao vento. |
| Represa do Tauá | 8 | Mínimo de propósito (a barragem é a vista mais pesada): tambores e caixa na subestação, barris na casa de força, banco e arbusto na casa do operador. |
| Praia dos Quiosques | 31 | Caixotes de peixe, lixeira e barril por quiosque (as mesas do pacote antigo já estão nas portas), 3 mesas novas no restaurante, bancos e lixeira na orla, 2 canoas na linha da maré, canoa e barril no posto salva-vidas. |
| Campo aberto: sítios e vestígios | 82 | Sítios com cena legível, escolhidos nos vazios (sem mata, estrada ou prédio a menos de 14 m): acampamento abandonado com fogueira, toras e lona; pasto com carvalho de sombra; curral de pedra em ruína (3 muros_ruina); capoeira queimada (5 árvores secas); bosquete de sombra; barraca de pescador na costa oeste; bosque de pinheiros jovens; pedras do planalto; naufrágio no litoral sudeste; obra abandonada; 10 árvores e 4 pedras isoladas como cobertura natural. |
| Carros abandonados nas estradas | 4 | Sedã na E8, táxi na E5, viatura na E9 e sedã na E4, no acostamento, paralelos ao eixo, a mais de 60 m de qualquer outro carro e fora da faixa. |
| Margens do rio e praça do Cruzeiro | 14 | Samambaias, arbustos e pedras na margem do Rio Tauá no trecho aberto (fora do leito) e canteiro de 6 arbustos com 2 pedras de sentar em volta do cruzeiro. |

## FPS (`--perf`, 1024x768, sem vsync, `raw/design_05`)

Mínimo de todas as 68 vistas do tour (novas e antigas): **60 fps**. As duas vistas em 60 (`cen2_cruz_aereo` e `cen2_acampamento`) têm o mesmo custo sem o arquivo novo (16,3 e 16,6 ms medidos com `cenario_areas_02.json` removido): o limite vem da cena base (vegetação e muitas casas na aérea). O arquivo novo custa de +0 a +0,5 ms e +30 a +150 draws.

| Vista | ms | FPS | Vista | ms | FPS |
|---|---|---|---|---|---|
| cen2_vila_aereo | 11,7 | 86 | cen2_usina_operaria | 7,9 | 127 |
| cen2_vila_aereo_leste | 13,2 | 76 | cen2_quartel_rancho | 9,5 | 105 |
| cen2_vila_quintais | 8,6 | 116 | cen2_pedreira_cava | 10,6 | 94 |
| cen2_vila_ruas | 14,2 | 71 | cen2_pista_hangar | 13,4 | 74 |
| cen2_vila_ranchos | 14,5 | 69 | cen2_farol | 7,2 | 138 |
| cen2_cruz_aereo | 16,7 | 60 | cen2_praia | 8,0 | 125 |
| cen2_cruz_chao | 13,1 | 76 | cen2_acampamento | 16,7 | 60 |
| cen2_praca_cruzeiro | 12,4 | 80 | cen2_ruina_curral | 9,1 | 109 |
| cen2_fazenda_casarao | 14,2 | 70 | cen2_capoeira | 9,2 | 108 |
| cen2_fazenda_colonos | 11,0 | 91 | cen2_naufragio | 7,5 | 133 |
| cen2_alameda_e2 | 8,4 | 119 | cen2_bosque_pinheiros | 7,9 | 126 |
| cen2_alameda_e4 | 8,6 | 116 | cen2_carro_e8 / e5 (`design_06`) | 11,5 / 13,3 | 87 / 75 |
| cen2_alameda_e7 | 11,6 | 86 | | | |

Vistas antigas no mesmo run, com as 997 peças carregadas: mais baixas `cobertura_campo` 62, `cen_pedreira` 62, `cen_vila_praca` 63, `cen_morro_pe` 64, `cen_quartel_portao` 64; demais entre 68 e 156.

## Pendências

- **Cercas antigas de fundos** (`detalhes.json`, `cercas`) ainda estão posicionadas para a casa antiga (6 x 8) e agora cortam as casas de 14 x 14 (aparecem como ripas escuras dentro dos quintais). Precisam ser regeradas por quem mudou as casas; o validador as lista como "cerca_antiga".
- Os props antigos de cada casa (varal, lixeira, bicicleta, tambor, tijolo do `detalhes.json`) também seguem a posição da casa antiga. Evitei sobreposição só com o que está fora do retângulo novo; revisar quando o `detalhes.json` for refeito.
- No Cruzeiro as casas de 14 m ficam a 6 m uma da outra (algumas se tocam, ex. 01/07, 11/16): por isso só há cerca na frente e retornos. Se o coordenador reabrir o layout, vale espaçar as casas e então fechar os lotes.
- O capim alto cobre props baixos (fogueira, canoa, caixote): nos sítios do campo entraram lona e árvores secas para ficarem legíveis de longe.
- Os 28 avisos restantes são de proximidade (0,4 a 3 m) entre peças novas e peças antigas ou cobertura do gameplay (cerca de quintal a 2 m de sedã do passe 01, poste de fiação perto de árvore da alameda); sem erro de sobreposição.
- Colisão: cercas de pacote recebem casco convexo em `detalhes.gd`, ou seja, ficam maciças (1,8 m); bots sem navmesh podem encostar nos quintais, os vãos de portão têm 3 m (2,6 m no Cruzeiro).
- Os carros do passe 02 ficam apoiados na altura do centro, sem inclinar (mesma observação do passe 01).
