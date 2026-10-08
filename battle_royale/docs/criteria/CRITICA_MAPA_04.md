# Crítica do mapa nº 04: Ilha do Tauá (agente Critério)

Data: 26/09/2026. Evidência: `raw/tour34/*.png` (18 vistas, 1024×768), build com os itens 31–34 do NOITE_PLANO feitos.
Base de comparação: `docs/criteria/CRITICA_MAPA_03.md` (tour29). Para apontar os números, conferi `game/shaders/terreno.gdshader`,
`game/shaders/ceu.gdshader`, `game/shaders/agua.gdshader` e o `_environment` de `game/maps/ilha/ilha.gd`, sem editar nada.
Restrições: posições autorais (nada procedural), sem bake de luz, 60 FPS na GT 730. O tour mede **61–136 FPS** e a aérea
mede 68, então nenhum item abaixo pode custar mais de ~3 FPS na aérea.

## Veredito em uma frase
A rodada 31–34 resolveu os dois defeitos que mais quebravam o estilo: o **serrote do muro do quartel sumiu** e o terreno
passou a ter **uma cor por triângulo**. O mapa agora lê como low poly de verdade. O que falta para parecer um BR AAA
estilizado mudou de lugar:
- a **borda das estradas e trilhas** virou dente de serra, porque cada triângulo escolhe terra ou grama inteiro;
- o **céu** continua cinza-azulado (`≈#8095A8` no zênite) e as **nuvens** ainda são placas de papelão em escada;
- o **rio** ainda lê como estrada molhada (listras brancas e margem laranja serrilhada);
- as sombras da praia e a encosta oposta ao sol da pista ainda ficam quase pretas.

## O que melhorou desde a 03
| Aspecto | 03 | 04 | Evidência |
|---|---|---|---|
| Sombras de muro | 3 | 8 | `ilha_quartel_poi`: sem serrote. A sombra da torre de vigia fica limpa no gramado e o POI inteiro lê. É o maior salto do tour. |
| Terreno por face | 5 | 7 | `ilha_pico_vista`, `ilha_farol`, `ilha_represa_barragem`: acabaram as faces de duas cores. O primeiro plano da represa ganhou leve variação de tom por faceta. Efeito colateral: bordas terra/grama em dente de serra (`ilha_morro`, `ilha_rio`, `ilha_vila`, `ilha_farol`). |
| Janelas do quartel | 4 | 8 | `ilha_quartel`: vidro `#2A3A44` com caixilho verde em todos os vãos. Os buracos marrons sumiram. |
| Canavial | 7 | 8 | `ilha_canavial`: a cana em primeiro plano sobre a usina é a melhor composição de "descida de paraquedas" do tour. |
| Mata | 7 | 7 | As escalas 0,8/1,0/1,25 quebraram a copa única na encosta da represa. Na crista de `ilha_cobertura_campo` a mata ainda lê como fila. |
| Céu / nuvens | 5 | 5 | Sem mudança: zênite lavado e placas de contorno em escada (`ilha_vila`, `ilha_quartel`, `ilha_quartel_poi`, `ilha_pista`). |
| Rio | 5 | 5 | Sem mudança: faixa cinza-esverdeada com traços brancos leitosos e margem clara (`ilha_vila`, `ilha_rio`). |
| Sombras escuras | 5 | 5 | `ilha_praia`: gramado na sombra `≈#2F4A2C` e um polígono `≈#3C3836` no chão ao pé da casa. `ilha_pista`: encosta direita `≈#3F4A50`, que lê como buraco. |

## Notas por vista
Critérios: **C**omposição, **G**ameplay (leitura), **P**aleta, **D**etalhe, **E**stilo (coesão). Geral = média arredondada.

| Vista | C | G | P | D | E | Geral | 03 | Comentário curto |
|---|---|---|---|---|---|---|---|---|
| ilha_aerea | 8 | 8 | 7 | 6 | 7 | **7** | 7 | As estradas por pixel ficaram lisas e os POIs leem bem. Ainda aparecem a faixa escura entre o mar e o céu (y≈150–185), o litoral em degraus e um retângulo verde-escuro de quina reta no canto inferior direito. |
| ilha_vila | 6 | 6 | 6 | 6 | 5 | **6** | 6 | O sol, o coqueiral e o casario estão bons. O rio tem listras brancas e a margem vira uma fileira de dentes laranja e verdes. As nuvens de perto são placas. |
| ilha_vila_casas | 5 | 4 | 6 | 5 | 6 | **5** | 5 | Casas ótimas, mas 55% da tela continua gramado liso. Em quadro só aparece um carrinho de mão, e não há cobertura a menos de 25 m. |
| ilha_morro | 5 | 5 | 5 | 4 | 5 | **5** | 5 | A estrada continua uma chapa `#8F5F40` sem variação e agora tem borda em degrau de 4 m. O poste e o matacão estão bons. |
| ilha_morro_casas | 7 | 6 | 6 | 8 | 7 | **7** | 7 | Tijolo, fiação e caixa d'água. 45% da tela é céu lavado. A lixeira verde continua grande. |
| ilha_represa_barragem | 7 | 6 | 7 | 6 | 7 | **7** | 6 | A água, a trilha no morro e a terra em facetas estão bonitas. A lixeira verde continua 1,5× grande demais. |
| ilha_quartel | 7 | 6 | 7 | 7 | 7 | **7** | 6 | As janelas foram resolvidas. A trilha ainda tem 1 m de degradê e o gramado tem ruído de facetas escuras. |
| ilha_quartel_poi | 8 | 7 | 7 | 7 | 8 | **8** | 5 | Sem serrote, o POI militar vira cartão de visita: torre, alojamentos, caixa d'água e sacos de areia. |
| ilha_usina | 7 | 6 | 7 | 7 | 7 | **7** | 7 | Galpão, chaminé e fiação estão bons. A terra ao redor do galpão tem borda em degrau. |
| ilha_farol | 7 | 5 | 6 | 5 | 6 | **6** | 5 | O marco é forte e a encosta ficou com uma cor por face. Em primeiro plano, as faixas terra/grama formam um zigue-zague em diagonal. |
| ilha_praia | 7 | 6 | 5 | 7 | 6 | **6** | 6 | O coqueiral tem nível de produto. A sombra e o polígono do rodapé ficam quase pretos, e as linhas paralelas no declive continuam. |
| ilha_pista | 6 | 6 | 5 | 6 | 6 | **6** | 6 | A barra suja da parede ainda tem topo borrado. A encosta oposta ao sol `≈#3F4A50` domina o terço direito da tela. |
| ilha_rio | 8 | 7 | 8 | 8 | 8 | **8** | 8 | Continua sendo o modelo do jogo. Só a margem do rio, em dentes laranja, e o reflexo leitoso tiram pontos. |
| ilha_cobertura_campo | 4 | 4 | 6 | 4 | 6 | **5** | 5 | Mesmo quadro da 03: matacão sozinho, céu vazio em 50% da tela e mata em fila na crista. |
| ilha_cobertura_campo2 | 7 | 7 | 7 | 7 | 7 | **7** | 7 | Capim alto, cerca, cupinzeiro, fenos e cata-vento. Continua sendo o padrão a copiar. |
| ilha_pico_vista | 6 | 5 | 6 | 5 | 6 | **6** | 5 | Faces limpas e a faixa de trilha em fita. A antena e o mirante leem. Metade da tela ainda é encosta. |
| ilha_fazenda | 8 | 7 | 7 | 7 | 7 | **7** | 7 | Torre em primeiro plano, sombra das pernas, sol baixo. Sem mudança. |
| ilha_canavial | 8 | 8 | 7 | 8 | 8 | **8** | 7 | A cana visível ao redor com a usina ao fundo é uma grande vista. |

**Nota geral do mapa: 6,6/10.** A 03 tinha 6,1: estilo e POI militar subiram, e céu, rio e bordas de estrada ficaram parados.
Desempenho percebido: 8/10 (61–136 FPS, todas as vistas acima de 60).

---

## Lista priorizada: 6 ajustes concretos (maior impacto primeiro)

1. **Estradas e trilhas com borda curva e dura, e acostamento.** Corrige o efeito colateral do item 31.
   *Objeto:* `game/shaders/terreno.gdshader`. Hoje o peso da terra (`w.a`) vem de `uv_cel`, que usa `fpos` flat dentro de 140 m.
   Por isso cada triângulo de 4 m vira terra ou grama inteiro e a borda sai em degrau (`ilha_morro`, `ilha_rio`, `ilha_vila`, `ilha_farol`, `ilha_usina`).
   - Manter grama, rocha e areia **por face**, como está. Só a terra passa a ser lida **por pixel** com limiar duro:
     `float tp = clamp(1.0 - dot(texture(splat, (wpos.xz + vec2(600.0)) / 1200.0).rgb, vec3(1.0)), 0.0, 1.0);`
     e depois `cor = mix(cor_sem_terra, t, step(0.5, tp));`. O filtro bilinear com `step` desenha uma curva lisa de borda dura, e não degrau.
   - Acostamento de ~0,8 m: `float ac = step(0.32, tp) - step(0.5, tp);` e `cor = mix(cor, vec3(0.478, 0.341, 0.231) /* #7A573B */, ac);`.
     A estrada passa a ler como estrada a 200 m, o que ajuda na rotação de BR.
   - Variação da terra por face, pendente desde a 03: `t *= 1.0 + 0.05 * (fract(sin(dot(fpos.xz, vec2(12.9, 78.2))) * 43758.5) - 0.5);`.
     Isso acaba com a chapa `#8F5F40` única do `ilha_morro`.
   - Custo: +1 leitura de textura por pixel só dentro de 140 m. Na aérea é **0 FPS**, porque ela já lê por pixel. No chão, < 1 FPS.

2. **Céu saturado, faixa do horizonte e nuvens com volume.** É o item 3 da 03, pendente.
   *Objeto:* `ceu.gdshader`, `ilha.gd` (`_environment`), e o mesh e o `nuvem.gdshader` das 24 nuvens.
   - O zênite chega em `≈#8095A8`, e não em `#4F7DB8`, porque somam névoa cinza, AgX e rampa. Mudar `env.fog_sky_affect` de 0.25 para **0.08**,
     `zenite` para **`#3F6FB0`** e `meio` para **`#6F9CCB`**. O céu vira fundo de BR estilizado, e 45–50% da tela de `ilha_morro_casas` e de `ilha_cobertura_campo` deixa de ser cinza.
   - Faixa escura da aérea (y≈150–185): casar `env.fog_light_color` com `mar_longe` (**`#A1B0BD`**). Hoje está em `#C7C7C7` neutro. A névoa sobre o mar
     distante deixa de formar degrau com o céu abaixo do horizonte.
   - Nuvens: trocar a placa extrudada por **3 a 5 icosferas de 1 subdivisão** achatadas (Y ×0,45) e sobrepostas, com ~200 tris cada,
     nas **mesmas posições autorais**. Base em `#A7B3C9` e topo em `#FFF3E0`, via `smoothstep(0.1, 0.55, h_local)`. Sem sombra.
   - Custo: +5 mil tris em 24 instâncias, ≈0,5 FPS na aérea.

3. **Rio com cara de água, e não de asfalto molhado.** É o item 6 da 03, pendente.
   *Objeto:* `agua.gdshader` (`canal == 2`) e a margem do rio no splat.
   - As listras brancas de `ilha_vila` e `ilha_rio` são a espuma da correnteza. No canal 2, multiplicar `espuma *= 0.25` e usar a espuma do rio
     em **`#9FA89A`** no lugar de `cor_espuma`.
   - Cor do rio: rasa **`#4F6E5C`** e funda **`#22404A`**, com `SPECULAR = 0.08` (hoje 0.15). No `fragment()`, limitar o especular rasante:
     `SPECULAR *= mix(0.4, 1.0, smoothstep(0.1, 0.35, dot(NORMAL, VIEW)));`.
   - Margem: com o item 1, o dente laranja vira curva. Na borda do rio, pintar no splat uma faixa de **1 m de barranco úmido `#6F6A4E`**
     (canal terra com peso ~0,4, que cai no acostamento do item 1). É pintura autoral no splat, e não geração.
   - Custo: 0 FPS.

4. **Nenhuma sombra preta.** Termina o item 2 da 03.
   *Objeto:* `ilha.gd` (sol), `terreno.gdshader` e o material do rodapé e da calçada da casa da praia.
   - `sun.shadow_opacity = 0.8` (Light3D no Godot 4). A sombra deixa de ser vácuo. Meta: gramado na sombra da `ilha_praia` ≥ **`#3F5E3A`**.
   - Encosta oposta ao sol (`ilha_pista`, `≈#3F4A50`): no terreno, simular a luz rebatida com `EMISSION = cor * 0.07;`.
     Meta: ≥ **`#56604F`**. Custo: 1 multiplicação.
   - O polígono `≈#3C3836` ao pé da casa da `ilha_praia` é cimento na sombra. Material: albedo **`#8A8580`**, roughness 0.9.
   - Custo: 0 FPS.

5. **As vistas de cobertura ainda mostram o campo vazio.** Legibilidade de BR.
   O item 34 diz 0% da área a mais de 25 m de cobertura, mas `ilha_vila_casas` e `ilha_cobertura_campo` mostram **o mesmo quadro da 03**.
   *Objeto:* `detalhes.json` / `gameplay_01.json` (Design, à mão).
   - Conferir se as câmeras do tour estão no 0,75% antigo. Se estiverem, o jogador também vê isso ao aterrissar ali.
   - `ilha_cobertura_campo`: o matacão vira **cluster de raio 4 m**, igual ao `ilha_cobertura_campo2`: matacão de 1,8 m, 2 arbustos de 1,2 m,
     anel de 6 touceiras e 1 tronco caído de 4 m.
   - `ilha_vila_casas`: no gramado central, **2 muretas de 0,9 × 4 m** a 12–18 m da câmera e **1 carro** a ~20 m, entre a casa da esquerda e a do centro.
   - Compensação obrigatória na aérea: coberturas com menos de 1,2 m de altura passam de **alcance 320 m para 200 m**, sem sombra.
     O saldo na aérea fica ≈0 ou positivo, porque os mais de 100 props pequenos saem do quadro aéreo.

6. **Acabamento pendente (todos com custo 0).**
   - Lixeira verde da represa e do Morro: escala **0,65**.
   - Barra suja da parede verde-água da `ilha_pista`: borda dura a **1,1 m**, cor `#9C8468`, sem degradê.
   - Trilha do `ilha_quartel`: a trilha também passa pelo `step` do item 1, sem o degradê de 1 m.
   - Linhas paralelas no declive da `ilha_praia`: se vierem de `alt_cel` (6 níveis por `fpos.y`), reduzir para **4 níveis** (`* 4.0) / 4.0`).
     Se vierem da textura `trilhas`, apagar as linhas nesse trecho da pintura.
   - Mata em fila na crista de `ilha_cobertura_campo`: aplicar ali o mesmo tratamento do VEG_AJUSTES_02, com deslocamento de ±3 m e pares a ≤ 2,5 m.
   - Retângulo verde-escuro de quina reta no canto inferior direito da aérea: arredondar os cantos na pintura da `mata` (raio ≥ 12 m).

### Custo estimado de desempenho (aérea, hoje 68 FPS)
Item 1: 0. Item 2: −0,5. Itens 3, 4 e 6: 0. Item 5: entre −0,5 e +1, com o corte de alcance. **Saldo: −1 a +0,5 FPS**, dentro do teto de 3 FPS.

### Ordem sugerida
Aplicar 1 e 2 primeiro (1 noite: shader do terreno e céu), recapturar como `tour35` e depois atacar 3 a 6.
Com 1 a 4 aplicados, a nota prevista sobe para cerca de **7,2**: morro, farol, vila, pista e praia ganham 1 ponto cada.
