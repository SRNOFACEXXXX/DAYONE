# Crítica do mapa nº 01 — Ilha do Tauá (Equipe de Critérios)

Data: 26/09/2026 · Evidência: `raw/tour16/*.png` (18 vistas, 1024×768, build com os itens 1–12 do NOITE_PLANO feitos).
Não rodamos o Godot de novo: as capturas do tour16 cobrem todas as vistas atuais. Lemos `shaders/terreno.gdshader`,
`shaders/agua.gdshader`, `shaders/ceu.gdshader`, `maps/ilha/ilha.gd`, `maps/ilha/vegetation.gd` e `tests/ilha_tour.gd` para
tirar os números das correções.

## Veredito em uma frase
O mapa **deixou de ser massinha na geometria**: as facetas aparecem. Mas **ainda parece massinha na cor**, porque o splat
é filtrado linearmente e mancha terra/grama/rocha em degradês borrados. O resto da cena, com luz de meio-dia, verde
saturado uniforme, gramados vazios, rio leitoso e nuvens que parecem pedras, ainda está em "protótipo Synty bem montado",
longe do AAA estilizado. Está a umas 10 correções baratas de chegar lá.

## Referências usadas (pesquisa)
- Firewatch, "The Art of Firewatch" (Jane Ng, GDC 2015): céu ocupa metade da tela e dita a paleta; **névoa estilizada com
  rampa de cor por distância**; camadas de cor, formas fortes e detalhe narrativo.
  https://gdcvault.com/play/1022295/The-Art-of · https://www.thumbsticks.com/gdc-2015-the-art-of-firewatch/ ·
  https://ctrl500.com/art/how-firewatch-translated-2d-concept-art-into-a-3d-open-world/
- Sea of Thieves, "Visual Adventures on Sea of Thieves" (GDC 2018) e "The Technical Art of Sea of Thieves" (SIGGRAPH 2018):
  simplificar a forma mas estilizar pesado a luz na água; nuvens art-directed; tudo em movimento.
  https://gdcvault.com/play/1025015/Visual-Adventures-on-Sea-of · https://80.lv/articles/gdc18-visual-adventures-on-sea-of-thieves ·
  https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf
- Fortnite e Sea of Thieves (resumo das palestras): pintura à mão sem ruído, desgaste e sujeira em tudo, nenhum objeto menor
  que uma caixa de correio, grama sem colisão para dar movimento. https://blog.habrador.com/2018/08/stylized-graphics-fortnite-sea-of-thieves.html
- Synty POLYGON: paleta consistente, cor chapada via textura-gradiente, pós-processo e iluminação inclusos nos packs.
  https://syntystore.com/products/polygon-nature-pack · https://sundaysundae.co/how-to-make-low-poly-look-good/
- Apex, Kings Canyon: macro-layout por zonas, cada uma com um marco próprio. https://www.aspaceman.com/apex ·
  https://apexlegends.wiki.gg/wiki/Kings_Canyon
- Free Fire, Bermuda: 800×800 m com marcos nomeados (Clock Tower, Factory, Peak), mistura de mata densa, vilas e campo aberto.
  https://garenafreefire.fandom.com/wiki/Bermuda · https://www.bluestacks.com/blog/game-guides/free-fire-battlegrounds/ff-map-guide-en.html
- Godot no renderer Compatibility (desde a 4.3): tem ajustes de brilho, contraste e saturação e **color correction com
  rampa 1D ou LUT 3D**. O glow é simplificado. https://godotengine.org/article/rendering-priorities-september-2024/ ·
  https://docs.godotengine.org/en/4.4/tutorials/3d/environment_and_post_processing.html

## Notas

| Aspecto | Nota | Resumo |
|---|---|---|
| Silhueta / composição | 6 | Da aérea é boa (cratera e represa como foco, estradas em anel). No chão, a linha do horizonte é chata, sem camadas e sem marcos. |
| Paleta / cor | 5 | Verde-limão saturado e uniforme domina 50–70% da tela. Falta contraste quente/frio. |
| Iluminação / atmosfera | 5 | Parece meio-dia, não fim de tarde. Sombras quase pretas e neutras. Sombra serrilhada. |
| Terreno ("massinha"?) | 4 | Facetas OK, mas as transições borradas do splat ainda dão cara de massinha. |
| Vegetação | 5 | De perto é boa (coqueiros e copas facetadas). Da aérea a ilha fica careca. Mata em fileira, sem sub-bosque. |
| Arquitetura | 5 | Volumes corretos, mas caixas lisas: sem rodapé, sem moldura de janela, sem desgaste. Faces na sombra ficam quase pretas. |
| Detalhe de chão | 4 | Gramados enormes sem nada no primeiro plano. Os props se perdem. |
| Água | 4 | Represa bonita. Mar sem espuma legível da aérea. **Rio leitoso, parece concreto ou gelo.** |
| Céu | 5 | O gradiente funciona. As nuvens parecem pedras flutuando. Há uma faixa escura no horizonte da aérea. |
| Leitura de gameplay | 5 | Estradas e POIs se leem bem do avião. Campos abertos sem cobertura por 40–80 m. Pontos altos sem recompensa. |
| Desempenho percebido | 8 | 63–155 FPS no tour. Há folga para as correções abaixo. |

---

## Diagnóstico e correção (todos os aspectos abaixo de 8)

### 1. Terreno: 4/10. A "massinha" hoje está na cor, não na forma
**Evidência:** `ilha_pico_vista.png` (faixa laranja borrada sobre facetas oliva, sem borda), `ilha_farol.png` (a trilha
vira uma mancha laranja que escorre pela encosta), `ilha_represa_barragem.png` e `ilha_morro.png` (primeiro plano de terra
com degradê macio até a grama), `ilha_quartel_poi.png` (mancha rosada no meio do gramado).
**Causa:** em `terreno.gdshader`, `splat` usa `filter_linear_mipmap` e os pesos entram direto em `ALBEDO`. Com texel de
cerca de 1–2 m, cada transição vira um degradê de 2–6 m pintado *por pixel* por cima de facetas planas. É a assinatura da
massinha. Além disso `ROUGHNESS = 0.95` com difuso Lambert deixa todas as faces de mesma inclinação com o mesmo valor.
**Correção (custo ≈ zero):**
1. Endurecer os pesos: `w = smoothstep(vec4(0.40), vec4(0.60), w); w /= soma;` (borda de 20% do texel, fica "recortada"
   como decalque Synty). Na estrada: `w.a = step(0.5, w.a)` para a borda sair nítida.
2. Cor **por face**, não por pixel: calcular a paleta com `wpos` quantizado ao centro da face. Opção barata: usar
   `floor(wpos.xz / 4.0) * 4.0 + 2.0` para ler o splat (célula de 4 m = tamanho médio do triângulo). Cada faceta fica com
   uma cor chapada, como nos packs POLYGON.
3. Variação de valor por faceta (geométrica e determinística, não é ruído): `ALBEDO *= 0.94 + 0.12 * dot(fwn, normalize(vec3(0.6, 0.0, 0.8))) * 0.5 + 0.06;`
   Faces viradas para o mar ficam um tom mais claras. Isso dá o "cristalino" do low poly sem depender da luz.
4. Borda de estrada: faixa de 0,6 m de "terra úmida" `#6B4A2E` entre grama e terra (via `smoothstep(0.45, 0.55, w.a)` menos o
   núcleo). Lê como meio-fio natural.

### 2. Paleta / cor: 5/10
**Evidência:** `ilha_vila_casas.png` (60% da tela em verde `≈#4B7A22` sem variação), `ilha_cobertura_campo.png`,
`ilha_cobertura_campo2.png`, `ilha_aerea.png` (a ilha inteira em um verde-limão lavado).
**Causa:** `grama_baixa = (0.26, 0.42, 0.16)` e `grama_alta = (0.46, 0.50, 0.22)` são muito próximos e saturados. Não há
um terceiro tom (seco/queimado) nem manchas autorais de variação. Litoral brasileiro no fim de tarde seco tem capim dourado
e verde-oliva, não gramado de golfe.
**Correção:**
- Nova rampa de grama (sRGB): várzea `#5E7D34`, meia-encosta `#7D8A3E`, alto/seco `#A89A55`, encosta íngreme `#5B6B35`,
  sub-bosque `#2F4424`, canavial `#9AA24A`.
- Um canal livre do `mata` (B) pintado à mão pelo Design com **manchas de capim seco** `#B29C5C` (30–60 m, 8–12 manchas por
  quadrante). Continua autoral, sem ruído.
- Terra de estrada `#9A5A34` e terra batida de pátio `#B07A4A` (hoje é um tom só).
- Areia seca `#E6D3A3`, molhada `#A89272`.
- Regra de proporção (Firewatch): no máximo 40% da tela em verde. O resto fica para céu, terra, construção e sombra colorida.

### 3. Iluminação / atmosfera: 5/10
**Evidência:** `ilha_fazenda.png` (parede na sombra `≈#332A20`, quase preta), `ilha_vila_casas.png` e `ilha_morro.png`
(parece meio-dia: céu azul-cobalto, sem calor), `ilha_quartel.png` (sombra em blocos borrados na fachada),
`ilha_quartel_poi.png` (sombra em serrote das copas).
**Causa:** sol a −34° ainda é alto para o que queremos. `ambient_light_energy = 0.55` com cor `(0.55, 0.6, 0.5)`
esverdeada e neutra, então as sombras ficam sem azul. A sombra ortogonal cobre 100 m num mapa de 2048 px (≈5 cm por texel
no melhor caso, pior nas bordas), e não há `shadow_blur`.
**Correção (Environment/luz em `ilha.gd`):**
- Sol: elevação **−22°** (sombras 2,5× o objeto), `light_color #FFC98F`, `light_energy 1.6`.
- Ambiente: cor `#8FA7C9` (céu frio rebatido), `ambient_light_energy 0.85`, `sky_contribution 0.35`. Sombras ficam azul-lavanda,
  não pretas (é o contraste quente/frio de Firewatch).
- `sun.shadow_blur = 1.5`, `directional_shadow_max_distance = 70`, `shadow_normal_bias = 1.5`,
  `directional_shadow_fade_start = 0.7`. Em Project Settings, `directional_shadow/size = 2048` e
  `soft_shadow_filter_quality = 1` (low).
- Pós-processo, que o Compatibility suporta: `adjustment_enabled = true`, `contrast 1.08`, `saturation 0.92`, e
  `adjustment_color_correction` com GradientTexture1D de 3 paradas: sombras `#2B3350` → meios `#8E8A78` → luzes `#FFE7C2`.
  Custo: 1 amostra de textura em tela cheia.
- Névoa em camadas (Firewatch): `fog_light_color #C9B79C` (quente, na direção do sol), `fog_density 0.0011`,
  `fog_sun_scatter 0.25`, `fog_height = 8`, `fog_height_density 0.015`. Os vales ganham véu e os morros se separam em planos.

### 4. Vegetação: 5/10
**Evidência:** `ilha_aerea.png`, câmera a cerca de 780 m do centro. As 8.517 plantas quase somem: as árvores têm alcance de
520–560 m (`vegetation.gd`, `ALCANCE`), então **o jogador que salta do avião vê uma ilha careca** com retângulos escuros
de "sub-bosque pintado" de borda dura. Em `ilha_represa_barragem.png` e `ilha_cobertura_campo2.png` a mata aparece como
fileiras de pirulitos de tronco claro sobre gramado limpo, com cara de plantação de eucalipto, não de Mata Atlântica.
`ilha_canavial.png` não mostra cana nenhuma: a vista enquadra um muro.
**Correção:**
- **LOD distante barato:** um segundo MultiMesh por bloco, com mesh "copa-bolha" de 8–12 triângulos (octaedro achatado,
  cor `#2F4A26`/`#3E5C2C`), visível de **500 a 1.600 m** (`visibility_range_begin = 500`, `end = 1600`) e sem sombra.
  São 8.517 × 12 ≈ 100 mil triângulos, mas só nos blocos longe; a GT 730 aguenta. Resultado: a ilha vista do avião fica
  coberta de mata, que é a primeira impressão da partida.
- Troncos da mata: de claro/bege para `#5A4632` (tronco) e `#3B2E22` (base). Troncos claros em fila são o que dá cara de
  plantação.
- Três tons de copa, sorteados por **tipo** no Design (dado autoral): `#2E4B27`, `#3F6130`, `#58773A`. Hoje é praticamente
  um só.
- Sub-bosque: 1 arbusto a cada 2 árvores dentro das manchas `mata.r > 0.5`, com alcance de 160 m. Na aérea, trocar o
  retângulo pintado por borda suave de 6 m (o `mata` com `filter_linear` só nessa textura, ou os polígonos do Design com
  cantos chanfrados).
- Capim alto (`capim_alto`, 80 m): dobrar a densidade só num raio de 25 m das coberturas e das bordas de estrada. É o
  "não-colisão que dá movimento" do Fortnite.
- Corrigir a vista `canavial` do tour (posição −240,330 → −195,350 pega o muro). O Design deve mover a câmera para dentro
  do talhão.

### 5. Arquitetura: 5/10
**Evidência:** `ilha_fazenda.png` (parede chapada de 12 m sem nenhum elemento), `ilha_usina.png` (galpão bege, janelas =
buracos escuros), `ilha_quartel.png` (barracão amarelo liso de 50 m), `ilha_pista.png` (parede azul-bebê "estourada").
**Causa:** um material por parede, sem trim, sem gradiente vertical, sem sujeira. Os packs Synty e Fortnite resolvem com
**textura-atlas de gradientes** e desgaste pintado.
**Correção (sem subir polígono):**
- Gradiente vertical no shader dos prédios: `ALBEDO *= mix(0.72, 1.0, smoothstep(0.0, 1.2, altura_local))`. Base suja até
  1,2 m (respingo de terra vermelha `#8A5A3A` a 30%). Isso sozinho ancora as casas no chão.
- Rodapé de 0,4 m em `#7A6F62` e moldura de janela de 0,12 m em branco `#EDE6D8` (4 quads por janela, cerca de 8 tris).
- Beiral: o telhado precisa passar 0,5 m da parede com espessura visível de 0,15 m. Hoje vários parecem papel (`ilha_pista`).
- Paleta das fachadas, de casario litorâneo: cal `#EFE9DC`, ocre `#E0B25A`, rosa-colonial `#D98C7A`, azul-marinho `#3F6E8C`,
  verde-água `#8CC2B0`. Telha `#B5533A` e telha velha `#8C4A36`. **Proibir** o azul-bebê saturado de `ilha_pista.png`
  (`≈#C4F0F5`).
- Janelas: vidro `#2A3A44` com 1 faixa diagonal clara (reflexo pintado) em vez de buraco preto.

### 6. Detalhe de chão: 4/10
**Evidência:** `ilha_vila_casas.png` (primeiro plano vazio, 0 props em 40 m), `ilha_cobertura_campo.png` (um matacão
solitário num campo de 100 m), `ilha_vila.png`, `ilha_fazenda.png`.
**Correção:**
- Regra de densidade (Fortnite, "nada menor que uma caixa de correio", mas com frequência): **1 prop legível a cada
  12–15 m** em área de POI e 1 a cada 30 m em campo. Candidatos já modelados: fenos, tambores, pneus, cocho, mureta.
- Decalques de chão (quads com alpha scissor, sem sombra): poça `#5C6B55`, marca de pneu, tampa de bueiro, capim ralo na
  base dos muros. 4–8 por casa, alcance de 60 m.
- Trilha de pé "gasto" (terra `#A0764C` a 40%) ligando portas às estradas, pintada no splat. Isso dá narrativa e rota.

### 7. Água: 4/10 (represa 7, mar 5, rio 2)
**Evidência:** `ilha_rio.png` e `ilha_vila.png`. O rio é uma faixa branco-esverdeada leitosa, opaca, com listras
horizontais regulares. Lê como pista de concreto ou gelo. `ilha_aerea.png`: o mar não tem espuma legível na praia e a
água rasa quase não aparece. `ilha_represa_barragem.png` está bonita (degradê turquesa), mas a borda não tem espuma.
**Causa do rio:** em `agua.gdshader`, `ROUGHNESS 0.06` + `SPECULAR 0.5` + fresnel com o céu claro. Contra o sol baixo (as
duas vistas olham para o sol) a água vira espelho do céu `#B8C4C8`. A "correnteza" `corr` é uma senoide com período fixo
em UV.y, e por isso sai em listras de régua.
**Correção:**
- Rio: `ROUGHNESS 0.35`, `SPECULAR 0.15`, `ALBEDO` com `cor_media #2E4A38` e `cor_funda #1A2E24`, `ALPHA 0.9` fixo.
  Correnteza: 3 senoides com frequências 0.9, 1.7 e 2.3 e amplitude 0.15 **somadas** (quebra a regularidade), cor
  `#6F8A70`, não branca.
- Mar: espuma de beira com largura 1,5× a atual e cor `#F4F1E6`. Faixa de água rasa turquesa `#4FB3B0` até 2 m (hoje
  `(0.30, 0.66, 0.62)` some sob a névoa na aérea). Brilho do sol limitado: `ROUGHNESS` mínimo de 0.12.
- Represa: linha de espuma `d < 0.3 m` na margem, igual ao mar.

### 8. Céu: 5/10
**Evidência:** `ilha_vila_casas.png`, `ilha_quartel.png` e `ilha_quartel_poi.png` (as nuvens parecem rochas brancas
facetadas, com face sombreada cinza-escuro), `ilha_aerea.png` (faixa azul-escura entre o mar e o céu na altura y≈150–185
e as nuvens pequenas demais para a escala), `ilha_usina.png` (nuvem cortada perto da câmera).
**Correção:**
- Nuvens com shader próprio **sem sombreamento Lambert**: `render_mode unshaded`,
  `ALBEDO = mix(#B9C3D6 (base), #FFF8EC (topo), smoothstep(-0.2, 0.6, NORMAL.y))`, e rim quente `#FFD9A8` nas faces
  voltadas ao sol. Escala Y ×0.55 (achatar a base) e escala geral ×2. Distância mínima de 900 m da câmera de jogo.
- 11 nuvens → **24**, em dois bancos: cúmulos baixos a 250 m e cirros alongados (quads de 400×60 m, alpha 0.5) a 600 m.
  É o céu "com metade da tela" de Firewatch.
- Faixa do horizonte: em `ceu.gdshader`, `mar_longe` deve ser igual à cor final da névoa sobre o mar a 6 km
  (≈`#8FA6B8`), e `smoothstep(0.0, -0.02)` vira `smoothstep(0.01, -0.03)`. Hoje há um degrau escuro visível.
- Fim de tarde de verdade: `zenite #3B6FB0`, `meio #8DB3D9`, `horizonte #F2D2A8` (pêssego), halo do sol ×0.5 mais largo.

### 9. Silhueta / composição: 6/10
**Evidência:** `ilha_vila_casas.png`, `ilha_cobertura_campo.png`, `ilha_pico_vista.png`. O horizonte é uma linha reta de
mar ou gramado, sem 2º e 3º planos. `ilha_farol.png` é a única vista com marco forte (farol listrado): funciona e deve
virar regra.
**Correção:**
- Um **marco vertical por POI**, visível a 600 m (Kings Canyon e Bermuda): caixa d'água da vila, chaminé da usina com
  fumaça, torre de rádio do pico com luz vermelha piscando, antena e bandeira do quartel, biruta e hangar da pista, silo da
  fazenda. Altura mínima de 18 m, cor contrastante (branco + vermelho `#C8402F`).
- Cristas: pôr 3–5 árvores altas isoladas **na linha de cumeada** do morro e do pico, com silhueta contra o céu (hoje elas
  somem entre as outras).

### 10. Leitura de gameplay: 5/10
**Evidência:** `ilha_vila_casas.png` e `ilha_cobertura_campo.png` (travessias de 50–80 m sem cobertura),
`ilha_pico_vista.png` (o ponto mais alto da ilha é um morro liso, sem nada que justifique subir), `ilha_aerea.png` (as
estradas se leem muito bem, ponto positivo).
**Correção:**
- Regra de cobertura: **nenhum ponto de campo aberto a mais de 25 m de uma cobertura** que proteja um jogador agachado
  (1,0 m) e de 40 m de uma que proteja em pé (1,8 m). Usar os 10 tipos já modelados. Rodar essa checagem como teste no
  layout do Design.
- Pico: ruína ou mirante com mureta e loot de alto nível, com 2 acessos (estrada + trilha íngreme). Risco e recompensa.
- Contraste de loot: os POIs quentes (quartel, usina) com cor de telhado saturada `#C8402F`; as casas isoladas com telha
  desbotada `#9A6A58`. O jogador lê "onde tem loot" do avião, como em Free Fire.

### Desempenho percebido: 8/10 (sem correção obrigatória)
63–155 FPS (NOITE_PLANO, itens 8 e 10). Orçamento para as correções acima: LOD de copas (+100 mil tris ao longe,
≈ −5 FPS), color correction (−1 a −2 FPS), shadow blur (−2 FPS), nuvens unshaded (0). Meta: continuar ≥ 60 FPS na pior vista.
Se apertar, a sombra cai para 60 m antes de mexer na vegetação.

---

## Lista priorizada: 10 melhorias de maior impacto
1. **Terreno sem massinha:** endurecer os pesos do splat (`smoothstep 0.4–0.6`) e colorir por face (splat lido no centro
   da célula de 4 m), mais a variação de valor por orientação da faceta.
2. **Copas LOD 500–1.600 m** (octaedro de 12 tris): a ilha deixa de ficar careca vista do avião.
3. **Luz de fim de tarde real:** sol a −22° `#FFC98F` 1.6, ambiente `#8FA7C9` 0.85, sombras azuladas.
4. **Color correction** (rampa `#2B3350` → `#8E8A78` → `#FFE7C2`), contraste 1.08, saturação 0.92, névoa de altura quente.
5. **Nova paleta de grama** em 3 tons mais manchas autorais de capim seco `#B29C5C`, com no máximo 40% da tela em verde.
6. **Rio:** roughness 0.35, specular 0.15, verde-escuro `#2E4A38`, correnteza com 3 senoides somadas (fim do "concreto").
7. **Nuvens** unshaded com gradiente, achatadas e ×2, 24 unidades em 2 bancos, e o horizonte sem faixa.
8. **Prédios:** sujeira na base até 1,2 m, rodapé, moldura de janela, beiral espesso e paleta de casario (sem azul-bebê).
9. **Marco vertical ≥ 18 m por POI** e regra de cobertura a cada 25 m nos campos abertos.
10. **Chão vivo:** 1 prop a cada 12–15 m nos POIs, decalques, trilhas de pé pintadas, capim alto junto de muros e
    coberturas, troncos da mata escuros e sub-bosque.
