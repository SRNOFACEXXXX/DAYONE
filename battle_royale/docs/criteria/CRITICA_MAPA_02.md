# Crítica do mapa nº 02 — Ilha do Tauá (agente Critério)

Data: 26/09/2026 · Evidência: `raw/tour21/*.png` (18 vistas, 1024×768), build com os itens 1–22 do NOITE_PLANO feitos.
Base de comparação: `docs/criteria/CRITICA_MAPA_01.md` (tour16). Para apontar os números, conferi `game/shaders/terreno.gdshader`,
`game/shaders/nuvem.gdshader`, `game/maps/ilha/ilha.gd` e `game/maps/ilha/vegetation.gd`, sem editar nada.
Restrições respeitadas nas correções: tudo autoral e à mão (nada procedural), sem bake de luz pesado, 60 FPS na GT 730
(o tour atual mede 60–135 FPS, então **não há folga**: cada item abaixo tem custo zero ou negativo).

## Veredito em uma frase
O mapa **saiu do protótipo e virou um lugar**. Os POIs têm marco, narrativa e props, o rio deixou de ser concreto e a ilha
tem mata vista do avião. O que ainda o separa do AAA estilizado são quatro "vazamentos técnicos": triângulos do terreno
pintados com duas cores, sombras que ainda ficam pretas ou em serrote, nuvens próximas que parecem papelão e uma aérea
leitosa. Além disso, a terra laranja chapada domina várias vistas.

## O que melhorou desde a 01
| Aspecto | 01 | 02 | O que mudou (evidência) |
|---|---|---|---|
| Terreno | 4 | 6 | As facetas agora têm cor chapada e a massinha sumiu em `ilha_usina`, `ilha_quartel` e `ilha_praia`. **Ainda** há triângulos com duas cores em `ilha_pico_vista`, `ilha_farol` e no talude de `ilha_vila`. |
| Paleta | 5 | 6 | A grama em 3 tons funciona (`ilha_cobertura_campo2`, `ilha_pico_vista`), o céu tem horizonte pêssego e as fachadas seguem a paleta de casario. A imagem ficou acinzentada, com zênite `≈#7A92AC` sem cor, e a terra laranja cobre 40–60% da tela em `ilha_morro`, `ilha_represa_barragem` e `ilha_farol`. |
| Luz / atmosfera | 5 | 6 | Sol baixo quente com sombras longas e legíveis (`ilha_rio`, `ilha_quartel`). A sombra ainda fica quase preta na parede da `ilha_fazenda` (`≈#36302A`) e sai em serrote no `ilha_quartel_poi`. |
| Vegetação | 5 | 7 | Da aérea a ilha deixou de estar careca: as copas LOD funcionam. O coqueiral da `ilha_praia` tem nível de produto. O canavial agora existe (`ilha_canavial`). Os troncos da mata **continuam claros e em fileira** (`ilha_represa_barragem`, `ilha_cobertura_campo`), então a encosta ainda lê como eucaliptal. |
| Arquitetura | 5 | 7 | Barra suja, rodapé, beiral, janelas com vidro na usina e fim do azul-bebê. O Morro com casas de tijolo, a fiação e a caixa d'água tem a melhor narrativa do mapa. As janelas do quartel continuam buracos marrons chapados. |
| Detalhe de chão | 4 | 6 | Fenos, tambores, bicicletas, cupinzeiro, capim alto, cercas, mesas e quiosques. Ainda há campos vazios de 40–60 m (`ilha_vila_casas`, `ilha_cobertura_campo`). |
| Água | 4 | 6 | Rio verde-escuro com reflexo coerente (de 2 para 6), represa bonita. O mar sob o sol baixo vira uma chapa cinza-leitosa (`ilha_pico_vista`, `ilha_aerea`). |
| Céu | 5 | 5 | O horizonte pêssego ficou ótimo à distância (`ilha_aerea`, `ilha_pico_vista`). As **nuvens próximas** (`ilha_vila`, `ilha_quartel`, `ilha_quartel_poi`, `ilha_pista`) são placas bege chapadas, cortadas como papelão. O gradiente não aparece. |
| Silhueta / marcos | 6 | 8 | Farol listrado, chaminé da usina, caixa d'água e torre de vigia do quartel, antena do pico, biruta da pista. Funciona. |
| Leitura de gameplay | 5 | 6 | Estradas e marcos se leem, e há coberturas perto dos POIs. Os campos ainda têm coberturas isoladas (um matacão sozinho), e o mirante do pico não aparece na vista do pico. |

## Notas por vista
Critérios: **C**omposição, **G**ameplay (leitura), **P**aleta, **D**etalhe, **E**stilo (coesão). Geral = média arredondada.

| Vista | C | G | P | D | E | Geral | Comentário curto |
|---|---|---|---|---|---|---|---|
| ilha_aerea | 7 | 8 | 4 | 5 | 5 | **6** | Boa leitura de estradas e POIs, e a mata aparece. Imagem leitosa e sem contraste. As manchas de capim seco são octógonos serrilhados, o sub-bosque sai em retângulos em escada (canto inferior direito) e o litoral tem degraus. Ainda há faixa escura entre o mar e o céu (y≈150–185). |
| ilha_vila | 6 | 6 | 5 | 6 | 5 | **6** | Sol e horizonte bonitos, coqueiros e postes dão profundidade. O talude da estrada tem triângulos alternando laranja e verde, e o asfalto tem uma faixa branca leitosa de especular. A nuvem do topo parece placa. |
| ilha_vila_casas | 5 | 4 | 6 | 5 | 6 | **5** | Casas lindas (janelas azuis), mas 55% da tela é gramado liso e vazio. Não há cobertura em 40 m. As nuvens são placas. |
| ilha_morro | 5 | 5 | 4 | 4 | 5 | **5** | A estrada laranja chapada ocupa 45% da tela sem nenhuma variação. Troncos claros em fila na encosta. O poste de concreto em primeiro plano está bom. |
| ilha_morro_casas | 7 | 6 | 6 | 8 | 7 | **7** | A melhor vista narrativa: tijolo, fiação em catenária, caixa d'água e placa. Os taludes bege (rocha) são blocos chapados grandes. |
| ilha_represa_barragem | 6 | 6 | 5 | 6 | 6 | **6** | Água e morro com trilha lindos. Primeiro plano de terra laranja (40%). A borda da represa ainda tem degraus em escada. As árvores parecem eucaliptal. A lixeira verde está grande demais para a escala. |
| ilha_quartel | 6 | 6 | 6 | 6 | 6 | **6** | O barracão agora tem base suja e as sombras longas são boas. As janelas são buracos marrons chapados. A trilha é borrada (3 m de degradê). |
| ilha_quartel_poi | 7 | 7 | 6 | 7 | 4 | **6** | A composição do POI é ótima (torre, barracões, bandeira). A **sombra em serrote** que atravessa a encosta quebra o estilo de cara. |
| ilha_usina | 7 | 6 | 7 | 7 | 7 | **7** | Galpão com vidro, chaminé, fiação, carreta e morro arborizado no fundo. Só a costura de triângulos laranja e verde no chão incomoda. |
| ilha_farol | 7 | 5 | 5 | 4 | 5 | **5** | O marco é forte. A encosta laranja em primeiro plano ocupa 50% da tela, com faces de duas cores, e a rocha à direita parece translúcida. |
| ilha_praia | 7 | 6 | 6 | 7 | 6 | **6** | Coqueiral e quiosques têm nível de produto. A sombra no chão é quase preta (`≈#1F3A22`). O declive tem linhas paralelas regulares que parecem curvas de nível. |
| ilha_pista | 6 | 6 | 6 | 6 | 6 | **6** | O verde-água substituiu o azul-bebê. A barra suja da parede tem borda borrada. A encosta na sombra é azul-escura e boa, mas no limite do escuro. |
| ilha_rio | 8 | 6 | 7 | 7 | 7 | **7** | A melhor vista de luz: sombras longas, rio escuro e reflexo do sol. Os troncos cinza-claros das árvores do meio destoam dos marrons. |
| ilha_cobertura_campo | 4 | 4 | 6 | 3 | 6 | **5** | Um matacão solitário num campo de 80 m. O céu vazio ocupa a metade de cima da tela. |
| ilha_cobertura_campo2 | 7 | 6 | 7 | 7 | 7 | **7** | Capim alto em primeiro plano, cerca, cupinzeiro, fenos e cata-vento. É o modelo a seguir. |
| ilha_pico_vista | 5 | 3 | 5 | 3 | 4 | **4** | É o pior terreno do tour: faixas laranja cruzam os triângulos (duas cores por face). O mar sob o sol vira chapa branca, e o mirante não aparece. |
| ilha_fazenda | 4 | 5 | 4 | 4 | 5 | **4** | A parede na sombra ocupa 50% da tela e é quase preta. A casa grande ao fundo e o horizonte são bons. É um enquadramento ruim da câmera do tour. |
| ilha_canavial | 8 | 7 | 6 | 7 | 7 | **7** | Grande vista do POI da usina com a cana em primeiro plano. Os colmos são escuros e finos demais e parecem varetas. |

**Nota geral do mapa: 6,0/10** (a 01 tinha cerca de 5,0). Desempenho percebido: 7/10 (60–135 FPS, sem folga na pior vista).

---

## Lista priorizada: 8 ajustes concretos (maior impacto primeiro)

1. **Uma cor por triângulo no terreno (fim das faces de duas cores).** *Objeto:* `game/shaders/terreno.gdshader`.
   Hoje o splat é lido no centro da célula de 4 m, que não coincide com os triângulos. Por isso, em `ilha_pico_vista`,
   `ilha_farol` e `ilha_vila`, a borda da célula corta a face ao meio. A correção é declarar `varying flat vec3 v_cel;` e,
   no `vertex()`, gravar a posição de mundo do vértice. O `fragment()` passa a ler `splat`, `mata` e `trilhas` com esse
   UV. Cada triângulo pega a cor do seu vértice provocador, com borda sempre na aresta, como nos packs POLYGON. O custo é
   zero, e a mudança também tira a escada das manchas de capim e do sub-bosque vistos da aérea.
   Junto: `terra_cor` de `#94663D` para **`#8A5E3F`** (estrada) e **`#9C7650`** nos pátios de POI, para tirar o laranja
   berrante que ocupa 40–60% da tela no morro, na represa e no farol.

2. **Sombras sem preto e sem serrote.** *Objeto:* `ilha.gd` (`_environment`) e `terrain.gd`.
   - `ambient_light_energy` de 0.85 para **1.05**, `ambient_light_sky_contribution` de 0.5 para **0.3** e
     `ambient_light_color` para **`#9AB0D0`**. Meta: a parede da fazenda na sombra deve ficar ≥ `#5A5F70` (hoje `#36302A`)
     e o chão sombreado da praia ≥ `#34503A`.
   - Serrote do `ilha_quartel_poi`: nos LOD 1 e 2 do terreno (4 m e 8 m), usar
     `cast_shadow = SHADOW_CASTING_SETTING_OFF`. Só o LOD0 (≤140 m) projeta sombra, `sun.shadow_normal_bias = 2.0`.
     Isso **ganha** FPS.

3. **Aérea sem leite.** *Objeto:* `ilha.gd`.
   - Em `_process`, o piso da névoa em altitude vai de `0.3` para **`0.08`** (`clampf(..., 0.08, 1.0)`).
   - `fog_light_color` de cinza `(0.78, 0.78, 0.78)` para **`#A3B6C6`**: a distância fica azul-mar em vez de leitosa.
   - Faixa do horizonte: em `ceu.gdshader`, igualar a cor do mar distante a `#8FA6B8` e alargar a transição para
     `smoothstep(0.015, -0.035, ...)`.

4. **Nuvens que não parecem papelão.** *Objeto:* `nuvem.gdshader` e posições das 24 nuvens em `ilha.gd`.
   - Distância mínima de **1.200 m** do centro da ilha e altitude entre **380 e 520 m**. As próximas de `ilha_vila`,
     `ilha_quartel` e `ilha_pista` estão a menos de 600 m e enchem o topo da tela como placas.
   - Mais contraste no gradiente: `base` **`#A7B3C9`** e `topo` **`#FFF3E0`**. Trocar `smoothstep(0.0, 0.7, h)` por
     `smoothstep(0.1, 0.55, h)` e `borda_sol` ×0.55 (hoje 0.35).
   - Remover a linha redundante `h = ... VERTEX.z ...` do `vertex()`.
   - Zênite do `ceu.gdshader` mais saturado: **`#4F7DB8`**, porque a metade de cima da tela hoje é cinza-azulada sem vida.

5. **Troncos escuros e mata sem fileira (item pendente da 01).** *Objeto:* modelos `arvore_mata_a` e `arvore_mata_b`
   (Blender, material do tronco) e `vegetacao.json`.
   - Tronco **`#5A4632`** com base **`#3B2E22`** nos 1,5 m inferiores (2 cores de vértice). Hoje ele é cinza-claro
     `≈#A8A49C` (`ilha_rio`, `ilha_represa_barragem`).
   - O Design desloca à mão as árvores das encostas do Morro e da Represa em **±3 m** para quebrar as linhas, e junta 1 em
     cada 4 em pares a ≤2,5 m. O dado continua autoral.

6. **Nada de campo vazio: clusters de cobertura a cada 25 m.** *Objeto:* `gameplay_01.json` e `detalhes.json` (Design).
   Em `ilha_vila_casas`, `ilha_cobertura_campo` e no gramado da `ilha_praia`: trocar o matacão isolado por **grupos de 3 a
   5 itens num raio de 4 m** (matacão + 2 arbustos + anel de capim alto de 6 touceiras). É o padrão que funciona em
   `ilha_cobertura_campo2`. Regra: nenhum ponto de campo a mais de **25 m** de uma cobertura de 1,0 m. Na Vila, pôr
   1 mureta de 0,9 × 4 m ou 1 carro a cada 15 m entre as casas. Custo: o alcance de 160 m já existente.

7. **Asfalto e janelas.** *Objeto:* material da estrada (asfalto) e material de janela do kit de prédios
   (`tools/build_predios.py`).
   - Asfalto: `roughness 0.92`, `specular 0.2`, cor **`#4B4A46`** e faixa central tracejada **`#D9B04A`** de 0,12 × 3 m
     com vão de 3 m (quads sem sombra). Isso acaba com a mancha branca leitosa da `ilha_vila`.
   - Janelas do quartel e da fazenda: vidro **`#2A3A44`** com 1 faixa diagonal **`#6F8796`** (reflexo pintado) e moldura
     **`#EDE6D8`** de 0,12 m, igual à usina. Hoje são buracos marrons `≈#6B5A48`.
   - A borda da barra suja da `ilha_pista` deve ser dura (degrau em 1,1 m, sem degradê).

8. **Trilhas nítidas, mar sob o sol e câmeras do tour.** *Objeto:* `terreno.gdshader`, `agua.gdshader` e `tests/ilha_tour.gd`.
   - `trilhas`: `filter_linear` para **`filter_nearest`** (com o item 1 fica por face). Largura pintada de 1,2–1,5 m e
     cor `#A0764C` a 75% (hoje 60%). Isso fecha o item 25 do plano.
   - Mar: `ROUGHNESS` mínimo **0.18** e especular ×0.6 quando o ângulo é rasante. A chapa branca da `ilha_pico_vista`
     e da aérea vira faixa de brilho.
   - Tour: `ilha_fazenda` recua 6 m da parede e gira 25° para a casa grande. `ilha_pico_vista` enquadra o **mirante**
     (é a recompensa do ponto alto e precisa aparecer). Depois, recapturar como `tour22`.

### Custo estimado de desempenho
Itens 1, 3, 4, 5, 7 e 8: ≈0 FPS. Item 2: **ganho** de 2 a 5 FPS (menos terreno projetando sombra). Item 6: −1 a −2 FPS
(cerca de 150 props, dentro do alcance existente). Saldo previsto: igual ou melhor que os 60 FPS atuais na pior vista.
