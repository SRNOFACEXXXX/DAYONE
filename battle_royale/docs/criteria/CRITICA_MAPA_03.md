# Crítica do mapa nº 03: Ilha do Tauá (agente Critério)

Data: 26/09/2026. Evidência: `raw/tour29/*.png` (18 vistas, 1024×768), build com os itens 1–30 do NOITE_PLANO feitos.
Base de comparação: `docs/criteria/CRITICA_MAPA_02.md` (tour21). Para apontar os números, conferi `game/shaders/terreno.gdshader`,
`game/maps/ilha/ilha.gd`, `terrain.gd`, `vegetation.gd` e `detalhes.gd`, sem editar nada.
Restrições respeitadas: posições autorais (nada procedural), sem bake de luz, 60 FPS na GT 730. O tour mede **57–137 FPS**,
então a pior vista já está abaixo da meta. Cada item abaixo tem custo zero ou traz a compensação junto.

## Veredito em uma frase
A rodada 23–30 limpou a **atmosfera**: a aérea deixou de ser leitosa, o mar ficou azul, as árvores do rio ganharam tronco
escuro e as câmeras da fazenda e do pico agora mostram o marco. Os três defeitos que mais separam o mapa de um BR AAA
estilizado **continuam iguais**:
- o terreno ainda pinta um triângulo com duas cores, porque o splat é lido no centro da célula de 4 m e não na face;
- a sombra em serrote do muro do quartel ainda aparece;
- as nuvens ainda parecem recortes de papelão.

Na leitura de jogo, os campos vazios e a mata plantada em fileira também seguem sem correção.

## O que melhorou desde a 02
| Aspecto | 02 | 03 | Evidência |
|---|---|---|---|
| Atmosfera / aérea | 5 | 7 | `ilha_aerea`: o mar está azul-petróleo, o véu sumiu, as estradas e os POIs leem nítidos e o horizonte pêssego ficou limpo. A faixa escura entre o mar e o céu diminuiu, mas ainda aparece (y≈150–180). |
| Tronco / mata | 7 | 7 | Em `ilha_rio`, o tronco escuro com pé `#3B2E22` ficou ótimo: é a melhor vista do tour. As encostas de `ilha_morro`, `ilha_represa_barragem` e `ilha_cobertura_campo` ainda mostram **fileiras** de árvores de copa e altura iguais (o item 28 adiou isso). |
| Terra | 5 | 6 | A estrada passou do laranja para `≈#8F5F40` e não berra mais. Ainda ocupa 45–55% da tela sem nenhuma variação (`ilha_morro`, `ilha_represa_barragem`, `ilha_farol`). |
| Enquadramento do tour | 4 | 7 | `ilha_fazenda` passou de 4 para 7: a torre do cata-vento, a sombra das pernas e a casa grande contra o sol formam um cartão-postal. `ilha_pico_vista` agora mostra a antena e o mirante. |
| Janelas | 5 | 7 | O vidro com reflexo diagonal funciona na usina, nas casas do Morro e na Vila. **Exceção:** os barracões do quartel ainda têm buracos marrons `≈#6B5A48` (`ilha_quartel`). Provavelmente são geometria de código fora dos 59 modelos. |
| Trilhas | 5 | 6 | A borda das trilhas ficou mais dura (`ilha_represa_barragem`, morro ao fundo). No quartel a trilha ainda tem 1 m de degradê. |
| Céu / nuvens | 5 | 5 | O anel de 1.200 m ajudou na aérea. Do chão (`ilha_vila`, `ilha_quartel`, `ilha_quartel_poi`, `ilha_pista`), as nuvens ainda são placas bege de contorno em escada, sem gradiente visível. O zênite aparece como `≈#8098AE` e não como `#4F7DB8`: a névoa está lavando o céu. |
| Sombras | 5 | 5 | O serrote do `ilha_quartel_poi` continua e domina a vista. Na `ilha_praia`, a sombra no gramado continua quase preta (`≈#2C4A2C`), assim como o rodapé da casa (`≈#3A3C3E`). |

## Notas por vista
Critérios: **C**omposição, **G**ameplay (leitura), **P**aleta, **D**etalhe, **E**stilo (coesão). Geral = média arredondada.

| Vista | C | G | P | D | E | Geral | 02 | Comentário curto |
|---|---|---|---|---|---|---|---|---|
| ilha_aerea | 8 | 8 | 7 | 6 | 6 | **7** | 6 | Leitura de BR de verdade: estradas, represa e POIs. O que resta é **escada**: manchas de capim octogonais, sub-bosque em retângulos (canto inferior direito) e litoral em degraus, tudo por causa da célula de 4 m. |
| ilha_vila | 6 | 6 | 6 | 6 | 5 | **6** | 6 | O sol e o coqueiral no horizonte estão bonitos. O talude à esquerda tem triângulos meio verdes e meio terra, e o rio tem listras brancas leitosas de especular e uma margem clara que lê como meio-fio. As nuvens de perto são placas. |
| ilha_vila_casas | 5 | 4 | 6 | 5 | 6 | **5** | 5 | As casas estão ótimas, mas 55% da tela continua gramado liso. O único prop é um carrinho de mão, e não há cobertura em 40 m. |
| ilha_morro | 5 | 5 | 5 | 4 | 5 | **5** | 5 | A estrada ocupa metade da tela num marrom chapado único. A mata aparece em fila na encosta. O poste e o matacão estão bons. |
| ilha_morro_casas | 7 | 6 | 6 | 8 | 7 | **7** | 7 | Tijolo, janelas com reflexo, fiação e caixa d'água. Os taludes de rocha bege continuam como blocos chapados grandes. |
| ilha_represa_barragem | 6 | 6 | 6 | 6 | 6 | **6** | 6 | A água e a trilha no morro estão lindas. A borda terra/grama sai em degraus no primeiro plano, a rocha atrás da água mistura tons dentro da face e a lixeira verde está 1,5× grande demais. |
| ilha_quartel | 6 | 6 | 6 | 5 | 6 | **6** | 6 | O barracão tem boa massa e bom telhado, mas as janelas continuam **buracos marrons**. O gramado do meio da tela tem ruído de facetas em 5 tons. |
| ilha_quartel_poi | 7 | 6 | 6 | 7 | 3 | **5** | 6 | O POI é ótimo (torre, alojamentos, pátio). A **sombra em serrote do muro**, de 25–30 m, atravessa a vista e quebra o estilo de cara. |
| ilha_usina | 7 | 6 | 7 | 7 | 7 | **7** | 7 | Galpão, chaminé, fiação, carreta e morro arborizado. Só a costura terra/grama em triângulos no chão incomoda. |
| ilha_farol | 7 | 5 | 5 | 4 | 5 | **5** | 5 | O marco é forte. A encosta em primeiro plano ocupa 50% da tela com faces de duas cores e uma rocha "translúcida" à direita. |
| ilha_praia | 7 | 6 | 5 | 7 | 6 | **6** | 6 | O coqueiral e os quiosques têm nível de produto. A sombra no gramado e o rodapé ficam quase pretos, e as curvas de nível paralelas no declive continuam. |
| ilha_pista | 6 | 6 | 6 | 6 | 6 | **6** | 6 | A barra suja verde-água ainda tem topo borrado. A encosta na sombra (azul-escura) está boa, mas no limite do escuro. |
| ilha_rio | 8 | 7 | 8 | 8 | 8 | **8** | 7 | É o modelo do jogo: troncos escuros, sombras longas, contraluz e rio escuro com reflexo. |
| ilha_cobertura_campo | 4 | 4 | 6 | 4 | 6 | **5** | 5 | O matacão continua sozinho no meio do campo, a metade de cima da tela é céu vazio e a mata do fundo aparece em fila. |
| ilha_cobertura_campo2 | 7 | 7 | 7 | 7 | 7 | **7** | 7 | Capim alto, cerca, cupinzeiro, fenos e cata-vento. É o padrão a copiar. |
| ilha_pico_vista | 6 | 5 | 5 | 4 | 4 | **5** | 4 | O mirante e a antena aparecem (melhorou). Metade da tela ainda é faixa de terra cortando os triângulos ao meio. |
| ilha_fazenda | 8 | 7 | 7 | 7 | 7 | **7** | 4 | Foi o reenquadramento certo: torre em primeiro plano, sombra das pernas, casa grande e sol baixo. |
| ilha_canavial | 8 | 7 | 7 | 7 | 7 | **7** | 7 | A cana em primeiro plano sobre o POI da usina é uma grande vista. A faixa de sombra do primeiro plano é densa (`≈#3E5A2A`). |

**Nota geral do mapa: 6,1/10.** A 02 tinha 6,0: a atmosfera subiu e o terreno e as sombras ficaram parados.
Desempenho percebido: 7/10 (57–137 FPS, **abaixo de 60 na pior vista**).

---

## Lista priorizada: 6 ajustes concretos (maior impacto primeiro)

1. **Uma cor por triângulo no terreno. É o item 1 da 02, ainda pendente, e é o maior salto de estilo.**
   *Objeto:* `game/shaders/terreno.gdshader`. Hoje o `fragment()` calcula `celula = floor(wpos.xz/4)` (linha 41), e a
   grade de 4 m não coincide com a malha. Isso causa as faces de duas cores em `ilha_pico_vista`, `ilha_farol`,
   `ilha_vila`, `ilha_represa_barragem` e `ilha_usina`, além da escada das manchas vistas da aérea.
   - Declarar `varying flat vec2 v_cel;` e, no `vertex()`, fazer `v_cel = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;`.
     No `fragment()`, trocar `uv_cel` por `(v_cel + vec2(600.0)) / 1200.0` nas leituras de `splat` e `mata`. O GLES3 do
     Compatibility aceita `flat`, e cada face herda a cor do vértice provocador. Fazer o mesmo com `alt_cel`, usando
     `varying flat float`.
   - Trocar `smoothstep(vec4(0.4), vec4(0.6), w) + w*0.08` por **`step(vec4(0.5), w)`** para que o dominante vença 100%.
   - Variação da terra **por face**, sem mudar posição de nada: `t *= 1.0 + 0.05 * (fract(sin(dot(v_cel, vec2(12.9,78.2))) * 43758.5) - 0.5);`.
     Isso gera ±2,5% de tom por faceta e acaba com a chapa marrom única do `ilha_morro`.
   - Custo: ≈0 FPS, porque sai uma amostra de textura linear e entram leituras sem filtro.

2. **Fim do serrote do quartel e das sombras pretas.** *Objeto:* `detalhes.gd` (muros), `ilha.gd` (`_environment` e sol).
   - Nos segmentos `muro*` com altura ≥ 2 m, usar `cast_shadow = SHADOW_CASTING_SETTING_OFF`. A sombra do topo do muro
     sobre faces alternadas é que forma o serrote de 25–30 m. No lugar dela, colocar **1 quad sem sombra de 1,6 m de
     largura** ao pé do muro, do lado oposto ao sol, cor **`#3F5A34`** com alpha 0,45. O quad é autoral, na mesma
     polilinha do muro. Isso **ganha** FPS porque sai um caster longo do mapa de sombra.
   - `sun.shadow_normal_bias` **2.0** e `shadow_bias` **0.04**, para as árvores e os prédios que continuam projetando sombra.
   - `ambient_light_sky_contribution` de 0.5 para **0.3** e `ambient_light_energy` de 1.0 para **1.1**. Meta: o gramado
     na sombra da `ilha_praia` deve ficar ≥ `#3A5A3A` e o rodapé ≥ `#55585E`.

3. **Nuvens com volume e céu saturado.** *Objeto:* modelos/mesh das 24 nuvens em `ilha.gd`, `nuvem.gdshader` e `Environment`.
   - Trocar a placa extrudada, que tem contorno em escada, por **3 a 5 icosferas de 1 subdivisão** achatadas (Y ×0,45)
     e sobrepostas. Cada nuvem fica com 60–140 m de largura e ~200 tris, e as posições são as mesmas do anel autoral.
     A base plana fica em `#A7B3C9` e o topo em `#FFF3E0`, via `smoothstep(0.1, 0.55, h)` na altura local.
   - `env.fog_sky_affect` para **0.2**. Hoje a névoa desbota o zênite `#4F7DB8` até `≈#8098AE`, e a metade de cima
     de `ilha_cobertura_campo` e de `ilha_morro_casas` vira cinza. Com o zênite saturado, o céu vira fundo de BR estilizado.
   - Custo: +5 mil tris no total, sem sombra, o que é desprezível.

4. **Nenhum ponto de campo a mais de 25 m de cobertura.** Legibilidade de BR, item 6 da 02, pendente.
   *Objeto:* `gameplay_01.json` e `detalhes.json` (Design, posições à mão).
   - `ilha_vila_casas`: entre as casas, **1 mureta de 0,9 × 4 m ou 1 carro a cada 15 m**, mais 2 clusters no gramado central.
   - `ilha_cobertura_campo`: o matacão solitário vira **cluster de raio 4 m** (matacão de 1,8 m, 2 arbustos, anel de 6
     touceiras de capim alto e 1 tronco caído), igual ao `ilha_cobertura_campo2`. Mais 1 cluster a cada 25 m na trilha
     até a mata.
   - Compensação de FPS, obrigatória porque a pior vista está em 57: touceiras e tambores já nascem com
     `SHADOW_CASTING_SETTING_OFF` e alcance de 90 m (hoje 160 m) para itens com menos de 1 m. O saldo fica ≈0.

5. **Mata sem fileira.** Item 28, adiado. *Objeto:* `vegetacao.json` (Design, à mão).
   - Nas encostas do Morro, da Represa e do fundo de `ilha_cobertura_campo`, deslocar cada árvore em **±3 m** fora do
     alinhamento e juntar 1 em cada 4 em pares a ≤ 2,5 m.
   - Escala **0,8 / 1,0 / 1,25** alternada à mão, com ~1/3 em cada valor. Hoje as copas têm a mesma altura e a encosta
     lê como eucaliptal comercial.
   - Em cada borda de mata, **2 a 3 arbustos** de 1,2 m na frente das árvores, para ter transição e cobertura na entrada.
     Custo ≈0, porque o número de instâncias fica igual e os arbustos entram sem sombra.

6. **Acabamento dos POIs: quartel, pista, rio e praia.** *Objeto:* kit de prédios (`tools/build_predios.py` ou a geometria de
   código do quartel), `agua.gdshader` e terreno da praia.
   - Barracões do quartel: aplicar o mesmo material de janela dos 59 modelos, vidro **`#2A3A44`** com diagonal
     **`#80999F`** e moldura **`#EDE6D8`** de 0,12 m. Hoje ainda são buracos `#6B5A48`, e o POI militar é o mais
     disputado do BR.
   - Barra suja da `ilha_pista`: borda dura em 1,1 m, cor `#9C8468`, sem degradê.
   - Rio da Vila: a margem clara (`≈#C8CCBC`) vira **faixa de 0,6 m `#6F6A4E`** (barranco úmido). O especular rasante
     tem teto: `SPECULAR *= 0.5` quando `dot(VIEW, NORMAL) < 0.2`. As listras brancas somem, e o rio deixa de parecer via.
   - Declive da `ilha_praia`: as "curvas de nível" paralelas vêm de faixas de altura quantizadas. Usar `alt_cel` por
     face (item 1) e passo `/ 4.0` em vez de `/ 6.0`.
   - Lixeira verde da represa: escala **0,65**.

### Custo estimado de desempenho
Itens 1, 3, 5 e 6: ≈0 FPS. Item 2: **ganho** de 1 a 3 FPS (muros fora do mapa de sombra). Item 4: −1 a −2 FPS,
compensados pelo corte de alcance e sombra dos props pequenos. Saldo previsto: pior vista em **≥ 60 FPS**.

### Ordem sugerida
Aplicar 1 e 2 primeiro (shader + 3 linhas de ambiente, 1 noite), recapturar como `tour30` e depois atacar 3 a 6.
Se os itens 1 e 2 entrarem, a nota prevista sobe para cerca de **7,0**: pico, farol, vila e quartel_poi ganham 1 a 2 pontos cada.
