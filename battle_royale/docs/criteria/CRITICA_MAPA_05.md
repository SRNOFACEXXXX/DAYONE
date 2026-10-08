# Crítica do mapa nº 05: Ilha do Tauá (agente Critério)

Data: 26/09/2026. Evidência: `raw/tour37/*.png` (18 vistas, 1024×768), build com os itens 35–37 do NOITE_PLANO feitos.
Base de comparação: `docs/criteria/CRITICA_MAPA_04.md` (tour34). Para apontar os números, conferi `game/shaders/terreno.gdshader`,
`game/shaders/agua.gdshader` e o `_environment` de `game/maps/ilha/ilha.gd`, sem editar nada.
Restrições: posições autorais (nada procedural), sem bake pesado, 60 FPS na GT 730. O tour mede **60–135 FPS**.
`ilha_represa_barragem` (60), `ilha_cobertura_campo` (61) e `ilha_canavial` (62) **não têm folga**: todo item com custo abaixo traz a compensação junto.
Fatos assumidos: a pista do aeródromo é de terra (não há asfalto); a faixa cinza-esverdeada em `ilha_vila` e `ilha_rio` é o rio.

## Veredito em uma frase
A rodada 35–37 acertou o que a 04 mais cobrava: o **céu ficou azul** (zênite ≈`#4F7BA0`, sem a faixa escura na aérea), as **estradas
ganharam borda curva e dura com acostamento** e o **campo vazio ganhou cobertura autoral**. O mapa agora parece um BR estilizado.
O que ainda derruba a nota:
- o **rio continua lendo como estrada molhada**, porque é translúcido e leitoso, e não por causa da cor;
- a **encosta oposta ao sol** da pista continua quase preta, porque a luz rebatida do item 4 da 04 não foi aplicada no terreno;
- as **nuvens continuam placas extrudadas**;
- os **grandes planos lisos** em primeiro plano (terra no morro, na represa e no farol; areia na praia) não têm detalhe nenhum.

## O que melhorou desde a 04
| Aspecto | 04 | 05 | Evidência |
|---|---|---|---|
| Céu | 5 | 8 | `ilha_morro_casas`, `ilha_cobertura_campo`, `ilha_farol`: o azul satura no zênite e desce para o pêssego no horizonte. Na `ilha_aerea` a faixa escura entre o mar e o céu sumiu. |
| Borda de estrada | 5 | 8 | `ilha_morro`, `ilha_quartel_poi`, `ilha_usina`: a borda é curva e nítida, e o acostamento `#7A573B` dá leitura de estrada. O dente de serra acabou. |
| Cobertura em campo | 4 | 7 | `ilha_cobertura_campo`: 2 matacões, arbusto, touceiras e tronco formam um bom ponto de combate. `ilha_vila_casas`: muretas e fusca entre as casas. |
| Praia | 6 | 6 | A nova câmera mostra os quiosques e as faixas duras de areia molhada. Em compensação, 60% da tela é areia seca lisa, e isso tira os pontos que o quiosque ganhou. |
| Rio | 5 | 5 | A espuma branca sumiu e a margem está lisa, mas o rio segue cinza-leitoso e translúcido (`ilha_vila`, `ilha_rio`, e cinza até na aérea). |
| Sombras escuras | 5 | 6 | O gramado sombreado da `ilha_quartel_poi` subiu, mas ainda chega a ≈`#355A30`. A encosta da `ilha_pista` continua ≈`#3F4A50`. No terreno **não há `EMISSION`**. |
| Nuvens | 5 | 5 | Continuam placas de contorno em escada (`ilha_vila`, `ilha_quartel`, `ilha_praia`, e a placa que corta a encosta na `ilha_represa_barragem`). |

## Notas por vista
Critérios: **C**omposição, **G**ameplay (leitura), **P**aleta, **D**etalhe, **E**stilo (coesão). Geral = média arredondada.

| Vista | C | G | P | D | E | Geral | 04 | Comentário curto |
|---|---|---|---|---|---|---|---|---|
| ilha_aerea | 8 | 8 | 8 | 7 | 8 | **8** | 7 | O céu e o horizonte foram resolvidos e a malha de estradas lê como mapa de BR. Faltam o litoral em degraus e o retângulo verde-escuro de quina reta embaixo à direita. O rio aparece como risco cinza. |
| ilha_vila | 6 | 6 | 6 | 6 | 6 | **6** | 6 | A margem do rio ficou lisa, mas o rio é uma chapa cinza translúcida que lê como pista, e a margem laranja saturada lê como meio-fio. As nuvens de perto ainda são placas. |
| ilha_vila_casas | 6 | 6 | 7 | 6 | 6 | **6** | 5 | Muretas e fusca dão cobertura. As muretas brancas puras (≈`#E0E0E0`) parecem placas de isopor. 50% da tela ainda é gramado liso. |
| ilha_morro | 7 | 6 | 6 | 5 | 6 | **6** | 5 | A borda com acostamento ficou ótima e a sombra do fio no chão é um toque bonito. A estrada ainda é uma chapa `#8F5F40` de 55% da tela, sem sulco nem variação. |
| ilha_morro_casas | 7 | 6 | 7 | 8 | 7 | **7** | 7 | O céu azul salvou o quadro. As manchas de terra bege no morro formam retalhos grandes demais. |
| ilha_represa_barragem | 6 | 6 | 7 | 6 | 7 | **6** | 7 | A represa e a encosta são bonitas, mas o primeiro plano de terra ocupa 45% da tela, liso. A lixeira verde a 30 m ainda chama o olho (verde saturado) e a nuvem-placa atravessa o morro. |
| ilha_quartel | 7 | 6 | 7 | 7 | 7 | **7** | 7 | A trilha tem borda ondulada boa, mas está a 60% de opacidade e o gramado facetado aparece através dela. O gramado ainda tem triângulos escuros de ruído. |
| ilha_quartel_poi | 8 | 8 | 7 | 7 | 8 | **8** | 8 | É o cartão de visita. A encosta sombreada embaixo à direita (≈`#355A30`) ainda pesa. |
| ilha_usina | 7 | 7 | 7 | 7 | 7 | **7** | 7 | Galpão, alojamento e estrada limpa. Sem defeito novo. |
| ilha_farol | 6 | 5 | 6 | 5 | 6 | **6** | 6 | Na encosta íngreme a terra forma um paredão marrom com borda vertical em escada. Com essa inclinação devia ser rocha. |
| ilha_praia | 6 | 6 | 7 | 5 | 6 | **6** | 6 | Os quiosques e a faixa de areia molhada funcionam. 60% da tela é areia seca lisa, e a lixeira no meio é o único objeto. |
| ilha_pista | 6 | 6 | 5 | 6 | 6 | **6** | 6 | A pista de terra lê bem. A encosta oposta ao sol `≈#3F4A50` ainda é um buraco escuro no terço direito. |
| ilha_rio | 8 | 7 | 7 | 8 | 8 | **8** | 8 | As árvores e a luz estão excelentes. O rio é uma lâmina leitosa com reflexo de céu branco, que lê como asfalto molhado. |
| ilha_cobertura_campo | 7 | 7 | 7 | 7 | 7 | **7** | 5 | É o maior salto do tour: o cluster autoral virou um ponto de combate legível. O céu ocupa 50% da tela, mas agora é azul. |
| ilha_cobertura_campo2 | 7 | 7 | 7 | 7 | 7 | **7** | 7 | Continua sendo o padrão. |
| ilha_pico_vista | 6 | 5 | 6 | 5 | 6 | **6** | 6 | A trilha em fita ficou limpa. Metade da tela ainda é encosta amarela lisa. |
| ilha_fazenda | 8 | 7 | 8 | 7 | 8 | **8** | 7 | A sombra da torre em treliça no gramado, com o sol baixo, é a melhor luz do tour. |
| ilha_canavial | 8 | 8 | 7 | 8 | 8 | **8** | 8 | Continua ótima. O horizonte está no topo da tela, então não aparece céu. |

**Nota geral do mapa: 6,9/10** (a 04 tinha 6,6). O céu e as estradas subiram, a cobertura resolveu duas vistas, e rio, sombras e nuvens ficaram parados.
Desempenho percebido: 7/10. Todas as vistas ficam em 60 ou mais, mas represa, campo e canavial não têm margem.

---

## Lista priorizada: 6 ajustes concretos (maior impacto primeiro)

1. **Rio opaco, com cor de água (ganha FPS).**
   *Objeto:* `agua.gdshader` (`canal == 2`) e o material do rio em `ilha.gd:236–240`.
   - O rio lê como asfalto por causa de `ALPHA = mix(0.78, …)`: a terra e a grama do leito aparecem através da água e a névoa por cima deixa tudo leitoso.
     Para o rio, usar **um material opaco separado** (shader copiado sem `ALPHA`, ou `ALPHA` removido quando `canal == 2`). Assim o rio sai do passe transparente.
   - Cor: rasa **`#3E6E66`**, média **`#2A5560`** e funda **`#1C3F4C`**. Hoje `d` só vai até 1,45 m, então a cor média nunca aparece: usar `smoothstep(0.3, 1.2, d)`.
   - Reflexo do céu: `ALBEDO = mix(ALBEDO, vec3(0.31, 0.44, 0.62) /* #4F709E */, f * 0.35);`. É azul, e não branco. Manter `SPECULAR = 0.08`.
   - Margem: a faixa laranja saturada vira barranco úmido **`#6F5A45`** com 1 m de largura (pintura autoral no splat: canal terra com peso 0,35, que cai no acostamento).
   - Custo: **+1 a +2 FPS** em `ilha_vila` e `ilha_rio`, porque some o blending de tela cheia. Esse ganho serve de crédito para os itens 3 e 4.

2. **Luz rebatida no terreno e rocha nas encostas íngremes.** Termina o item 4 da 04.
   *Objeto:* `terreno.gdshader`.
   - Luz rebatida (não foi aplicada: não existe `EMISSION` no shader): no fim do `fragment()`, `EMISSION = cor * 0.07 * (1.0 - clamp(orient, 0.0, 1.0));`.
     Metas: encosta da `ilha_pista` ≥ **`#56604F`** e sombra da `ilha_quartel_poi` ≥ **`#3F5E3A`**.
   - Terra só em rampa transitável: calcular `inclina` antes de `e_terra` e usar `e_terra = step(0.5, terra_px) * (1.0 - step(0.55, inclina));`.
     Acima de ~50° a face cai para rocha (`w.b`). Isso acaba com o paredão marrom da `ilha_farol`.
   - Custo: 2 multiplicações e 1 `step`, **0 FPS**.

3. **Primeiro plano de terra e de areia com detalhe pintado.** Tira 45–60% da tela do "liso".
   *Objeto:* textura `trilhas` / splat (pintura à mão) e `terreno.gdshader`.
   - Terra por face, pendente desde a 03: `t *= 1.0 + 0.06 * (fract(sin(dot(fpos.xz, vec2(12.9, 78.2))) * 43758.5) - 0.5);`.
   - Sulcos de roda pintados à mão nas estradas principais (Morro, represa, pista): **2 sulcos de 0,35 m a 1,6 m um do outro**, cor **`#7C4C31`**,
     com leitura por pixel e limiar duro, como a terra.
   - Areia: um canal `trilhas.g` pintado com **manchas de areia fofa `#D8C398`** (raio 2–4 m) e **rastros de pneu/pé** perto dos quiosques. Mesma leitura por pixel com `step`.
   - Custo: +1 leitura de textura por pixel só onde já se lê o splat por pixel, **< 0,5 FPS**. Na represa (60 FPS) compensa com o item 6 (lixeira e props sem sombra).

4. **Nuvens com volume, com o mesmo orçamento de triângulos.** É o item 2 da 04, pendente.
   *Objeto:* `assets/models/ceu/nuvem_a/b/c.glb` (Blender, à mão) e `nuvem.gdshader`.
   - Trocar a placa extrudada por **3 a 4 icosferas de 1 subdivisão** achatadas (Y ×0,45) e sobrepostas, **nas mesmas posições autorais**.
   - Base **`#AEB8CA`**, topo **`#FFF1DC`** via `smoothstep(0.1, 0.55, h_local)`. `unshaded`, sem sombra, `cast_shadow = OFF`.
   - Orçamento: **no máximo o total de triângulos atual das 3 malhas** (conferir no Blender). Se passar, cortar para **18 nuvens**, tirando as 6 que ficam atrás da ilha na aérea.
   - Custo: **0 FPS** com o orçamento igual. `ilha_canavial` não vê céu, e na represa e no campo o custo fica neutro.

5. **Muretas, lixeira e trilha: acabamento de material (custo 0).**
   - Muretas da `ilha_vila_casas`: reboco **`#CFC6B4`**, com rodapé **`#8E857A`** de 0,15 m e topo em pingadeira de 0,05 m mais claro (`#DDD5C4`). Isso acaba com o aspecto de isopor.
   - Lixeira verde (represa e Morro): albedo **`#4E6B45`** (hoje é verde saturado) e roughness 0,9. Continua legível a 30 m sem virar alvo visual.
   - Trilha do quartel: `cor = mix(cor, trilha_cor, tr * 0.6)` passa para **`tr * 0.9`**. A 60% o facetado da grama aparece através da trilha.
   - Ruído de facetas escuras no gramado (`ilha_quartel`, `ilha_usina`): reduzir o tom por orientação de `0.06` para **`0.04`** só em grama (`* (1.0 - w.g * 0.33)`).

6. **Compensação obrigatória para as 3 vistas sem folga (represa, campo, canavial).**
   Mesmo com os itens 1–5 perto de zero, é preciso abrir ~3 FPS de margem nessas vistas:
   - Props com menos de 0,6 m (lixeiras, touceiras, baldes, caixas pequenas) **sem sombra** (`cast_shadow = OFF`). A sombra desses objetos a 30 m não se lê em 1024×768.
   - Sombra direcional: `directional_shadow_max_distance` de 1 a 2 cascatas com **máximo de 120 m**. As sombras de árvore na encosta da represa acima de 120 m viram tom da `mata`.
   - Canavial: a cana dentro do quadro com `visibility_range_end` em **90 m** (fade `self` de 10 m). Acima disso quem aparece é a mancha `canavial` do splat, que já tem a mesma cor.
   - Ganho esperado: **+3 a +5 FPS** na represa, no campo e no canavial, sem perda visível.

### Custo estimado de desempenho
Item 1: +1 a +2 (vila e rio). Itens 2, 4 e 5: 0. Item 3: −0,5. Item 6: +3 a +5 nas vistas críticas.
**Saldo: positivo em todas as vistas.** A represa deve sair de 60 para ≈63–64 FPS.

### Ordem sugerida
Primeiro 6 e 1, que liberam FPS. Depois 2 e 5 (custo zero, 1 noite). Recapturar como `tour40` e só então atacar 3 e 4.
Com 1, 2 e 5 aplicados, a previsão é **≈7,3**: vila, rio, pista, farol e vila_casas ganham 1 ponto cada.
