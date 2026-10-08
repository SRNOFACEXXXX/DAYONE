# CRÍTICA UPGRADE 02 — arte e jogabilidade (agente Crítico)

Data: 2026-10-01 · Capturas 1024×768 (coordenadas em px da captura). Só avaliação, nenhum código/asset alterado.
Referências: `docs/ref/ak47_fps.jpg`, `mosin_lowpoly.png`, `personagem.jpg`, `menu_inventario.jpg`.
Capturas julgadas: `game/raw/estande_fim/` (AK, AK+ACOG, M4, Mosin, Glock, USP, Uzi, M249, M107), `estande_novas/folha.png`, `casa_demo11/` (e `casa_demo10/sala.png`), `tour_z/`, `raw/design_06/` (cen2_*), `poses_wf/`, `h10/`.
Nota: não existe `game/raw/design_05|06`; as pastas estão em `raw/design_05|06` (fora de `game/`). Não existe `ilha_cen2_vila*` em design_06, só acampamento, carro, cruz e praça.

## Quadro de notas (vs. CRÍTICA 01)

| # | Eixo | 01 | **02** |
|---|------|----|--------|
| 1 | Mira de ferro / ACOG | 2 | **3** |
| 2 | Quadril / mãos / recarga | 1 | **3** |
| 3 | Tiro / flash / coice | 2 | **3** |
| 4 | Personagem 3ª pessoa | 5 | **5** |
| 5 | Mapa / vila / casas por fora | 5 | **7** |
| 6 | Interiores | 3 | **6** |
| 7 | Menu / inventário | 7 | **7** |
| — | **NOTA GERAL** | 3,5 | **4,8** |

Resumo: o mundo (casas, capim, ilha) deu um salto real. A primeira pessoa, que o jogador vê 100% do tempo, melhorou pouco e ainda é o gargalo. A nota geral sobe 1,3 ponto quase só por mapa e interiores. O critério de aceite da crítica 01 (nota ≥ 6 nos eixos 1–3) NÃO foi cumprido.

## O que melhorou desde a crítica 01

- Capim alto 3D denso em campo aberto (`tour_z/ilha_fazenda.png`, `design_06/ilha_cen2_cruz_chao.png`, `ilha_cen2_acampamento.png`). Era o problema nº 1 do mapa e está resolvido.
- Casa por fora (`casa_demo11/fora_frente.png`): tábuas, telhado de duas águas, janelas com veneziana azul-marinho, varanda, palmeiras e acácia. Está muito perto da casa da referência.
- Interiores (`casa_demo11/cozinha.png`, `quarto_ne.png`, `sala.png`): piso de madeira, rodapé, geladeira, bancada, mesa com toalha e cadeiras, cama, abajur, quadro, janela mostrando a paisagem. Era vazio e foto-realista; agora é habitado.
- Mão da Glock no quadril (`glock_1_quadril.png`, `casa_demo11/*`): mãos agora são blocos de pele e luva verde camuflada na mira (`glock_3_tiro_q1.png`). A Mosin tem lente escura e madeira laranja.
- Mão e arma na recarga da AK (`ak47_4_recarga.png`): a arma agora se inclina (pose diferente do quadril).
- Mosin/AK: a luneta tem retículo e vinheta (continua plana, ver abaixo).

## 1. Mira de ferro / ACOG — 3/10

Referência: AK centralizada e baixa, poste da massa isolado no centro com o alvo visível acima, duas mãos de pele nos lados do guarda-mão.

1. **A AK em mira é uma faixa cinza lisa que vai de y 430 a 768 (x 290–660) e cobre o centro** (`estande_fim/ak47_2_mira.png`). O poste da massa está encaixado no meio de um "garfo" branco/azulado (x 462–545, y 378–430) com ruído de especular, e o corpo não tem nenhum detalhe (sem alça, receptor ou tampa legíveis). Ao lado, blocos cor de pele alaranjados (x 375–440 e 550–640) lembram caixas e não mãos. Nada se parece com o tom e a leitura de `ak47_fps.jpg`.
2. **M4 em mira tem o "anel" da alça visível, mas a arma está alta e preta chapada** (`m4_2_mira.png`). O olho da alça (x 462–502, y 378–415) está bom e cria uma leitura de mira, mas a torre preta ocupa x 385–585, y 360–768 e tapa a metade inferior da cena. Os blocos de mão (x 355–660) ficam atrás como caixas.
3. **Lunetas (`mosin_2_mira.png`, `ak47_acog_2_mira.png`) continuam máscara 2D**: círculo de raio ~260, retículo vermelho de 40 px, fundo apagado. Sem corpo de tubo, sem chevron do ACOG. A AK com ACOG usa exatamente a mesma imagem da Mosin (mesmo zoom, mesmo retículo), então não há diferença entre as duas.

## 2. Quadril / mãos / recarga — 3/10

Referência: a arma entra pela direita-inferior em diagonal, manga verde e luva preta, madeira laranja visível.

1. **AK no quadril aponta com a boca para cima e não se lê como AK** (`ak47_1_quadril.png`). A massa, em forma de garfo, aponta para o alto (x 495–540, y 490–590); o guarda-mão laranja e o receptor cinza ficam num feixe diagonal curto (x 480–720, y 560–768); a mão é uma cunha de pele (x 430–560, y 640–768) e a outra, um pedaço preto (x 690–820). A arma ocupa pouco mais de 15% da tela.
2. **M4 no quadril** (`m4_1_quadril.png`): o guarda-mão laranja (x 480–610, y 545–700) lembra madeira da AK e não polímero preto, o cano cinza-claro com ranhuras sai para o canto e a mão é um bloco cor de pele chapado (x 430–495, y 580–640). Boa direção (arma entra pela direita), mas sem acabamento.
3. **Mosin no quadril e na recarga** (`mosin_1_quadril.png`, `mosin_4_recarga.png`): a luneta e o cano grande (x 440–860, y 470–768) enchem a tela com um disco preto sem leitura, o corpo é azul-acinzentado em tons que não são madeira nem aço e a madeira laranja (x 470–540) só aparece como lasca. Na recarga, o rifle cruza a tela e a "mão" é um bloco verde-escuro cortado.
4. **Recarga é só uma rotação do quadril**: na `ak47_4_recarga.png` a AK gira 30° e vira, mas não há carregador saindo nem mão indo buscá-lo. A M4/Mosin/Glock continuam sem animação de carregador (ver `m4_4_recarga.png`, `glock_4_recarga.png`).
5. **Uma caixa marrom enorme e uma parede bege cobrem boa parte do quadro do estande** (todas as capturas de `estande_fim`: polígono marrom em x 0–930, y 540–768 e parede em x 855–1024, y 180–768). Não é arma, mas atrapalha qualquer avaliação visual e parece geometria de depuração do estande.

## 3. Tiro / flash / coice — 3/10

1. **O coice continua quase invisível**: AK q0→q2 (`ak47_3_tiro_q0.png` / `q2.png`): a arma permanece no mesmo lugar, topo em y≈375 nos dois. Isso reprova o critério de "≥ 25 px" da crítica 01. Mosin q1 (`mosin_3_tiro_q1.png`) mostra só um pequeno recuo de retículo, sem solavanco da luneta.
2. **O flash é um traço amarelo lateral** (`ak47_3_tiro_q0.png`): estrela fina em x 510–640, y 330–440, do lado do cano e sem relação clara com a boca. Em q2 já não há flash. Falta um clarão frontal de 4–6 pontas no cano e luz na arma.
3. **Glock com recuo ainda minúsculo e dedos em "escada"** (`glock_3_tiro_q1.png`): o ferrolho (x 487–537, y 380–540) não recua; a mão esquerda tem 4 degraus de pele (x 425–480, y 515–650) e o antebraço camuflado melhorou, mas a escada persiste.

## 4. Personagem em 3ª pessoa — 5/10

Boa fidelidade à referência no capacete verde, lenço vinho, mochila e camuflagem geométrica (`poses_wf/folha.png`). Problemas:

1. **A captura `frente` continua inútil**: `poses_wf/ak47_idle_frente.png` é só céu azul-cinza e chão verde-oliva. Não existe frente de soldado.
2. **Todas as poses são o mesmo soldado em perfil, mudando só a arma** (`folha.png`: 6 quadros). A arma continua na altura do queixo, a mão esquerda no mesmo ponto e a única diferença é a corrida (perna aberta). Recarga e agachado não aparecem na folha.
3. **A Mosin tem cano bege/ cinza-claro de comprimento exagerado** (x 330–390 no quadro inferior esquerdo da folha) e lembra uma vareta; luneta com cor correta, cano não.
4. **Faltam rádio de ombro, bolsos de colete e pouch visíveis** como na referência. O pouch existe, mas o rádio com antena está mínimo.

## 5. Mapa / vila / casas por fora — 7/10

Positivo: ilha com estradas radiais, lago, canal, pistas e floresta (`tour_z/ilha_aerea.png`); campo com capim, moinho de vento e casas ao fundo (`ilha_fazenda.png`); poste, cerca de ripas, cruzeiro e árvores (`design_06/ilha_cen2_cruz_chao.png`); bosque denso (`ilha_cen2_acampamento.png`).

1. **A vista aérea não mostra vila** (`ilha_aerea.png`): casas ficam como pontos vermelhos de 10 px e não há agrupamento de quarteirões; a ilha parece um campo com estradas.
2. **A captura `ilha_vila.png` mostra um barranco e um canal**, não uma vila: casas a mais de 100 m, só ~30 px de altura (x 600–700, y 350–390). É a mesma queixa da crítica 01 e não foi resolvida.
3. **Árvores low poly facetadas grandes, como as da referência, quase não existem perto das casas**; as copas da ilha são alongadas e suaves, com menos facetas que `ak47_fps.jpg`.
4. **O estande, onde se testam as armas, está feio demais**: gramado liso, estrada alaranjada sem textura, caixas marrons e parede bege (todas as capturas `estande_fim`). Não passa a impressão do jogo final.

## 6. Interiores — 6/10

Positivo: ver "O que melhorou". As salas têm piso de madeira com variação, rodapé, janelas com vista, móveis coerentes e iluminação razoável (`casa_demo11/cozinha.png` é o melhor quadro do projeto inteiro).

1. **Textura de parede em pixel-art ruidoso** (`sala.png`, `quarto_ne.png`, `casa_demo10/sala.png`): as paredes e o teto usam um mosaico de blocos amarelos e verdes de 6–12 px que estoura em ruído quando chega perto. O teto cinza-azulado é pior. Falta uma cor de parede lisa com um tom de rodapé.
2. **Mistura de estilos persiste na cozinha e na mesa** (`cozinha.png`): a toalha xadrez, o granito da bancada e o piso têm textura fotográfica, e a geladeira, a bancada e a janela são low poly liso. Ficou melhor, mas ainda destoa das paredes e do exterior.
3. **Móveis simples e pouco loot visível** (`quarto_ne.png`): uma cama, uma cômoda e uma pedra marrom estranha (x 400–490, y 425–590) que lembra um saco de areia sem material. Falta tapete, luminária de teto e itens de loot no chão.
4. **Portas escuras e teto sem relevo** (`sala.png`): batentes azul-marinho pesados, quase pretos, parecem buracos.

## 7. Menu / inventário — 7/10

Positivo: o layout segue a referência (título amarelo, painéis, hotbar, EQUIPAMENTO com AK ilustrada grande na tela inicial, `01_menu_1024x768.png`).

1. **O fundo continua sem desfoque/escurecimento** (`03_inventario_1024x768.png`): a casa e o galpão têm o mesmo contraste dos painéis, enquanto na referência eles ficam escurecidos e borrados. O painel "mão | EQUIPADO" ainda corta as pernas (y 540–712).
2. **O personagem é blocado** (lenço retangular reto em x 475–545, y 195–270, mãos em palito, ombros quadrados), enquanto a referência tem o lenço curvo envolvendo o pescoço e rosto humano. Sem rádio, sem antena.
3. **Slots F1–F4 vazios e PROXIMIDADE com grade cheia de células vazias** (x 95–235, y 80–215); rótulos "ACOG/RESERV" (x 425–500, y 697–705) com ~7 px. Na referência há ferramentas ilustradas e uma amostra do chão.

## Os 8 problemas mais importantes (ordem de prioridade)

1. **AK-47 não se lê na mira nem no quadril.** A faixa cinza lisa (mira, x 290–660) e o feixe com a massa para cima (quadril) não têm receptor, tampa, alça ou coronha reconhecíveis.
   Correção: em `game/core/viewmodel.gd` / `weapon_db.gd`, abaixar o pivô ADS da AK em ~6 cm e recuá-lo ~4 cm para a tampa do receptor ficar abaixo de y=470 e a alça visível; usar o modelo da AK com cores distintas (madeira #B5652A no guarda-mão e coronha, aço #3A3D40 no receptor, tampa #2B2E31) e normais suavizadas. Mover o quadril para cano apontando a (≈540, 360), arma diagonal até a borda inferior direita, ocupando ≥ 30% da largura.
   Prova: nova `estande_*/ak47_2_mira.png` com poste da massa em (512±3, 384±3), a AK visível só abaixo de y=470 e alvo inteiro visível; `ak47_1_quadril.png` com cano horizontal-diagonal e 2 mãos legíveis.

2. **Mãos são caixas de pele sem dedos nem manga.** Nas capturas de AK, M4 e Mosin, a mão esquerda é um bloco chapado cortado pela borda, e a Glock mostra a escada.
   Correção: em `tools/build_fp_maos.py`, modelar a mão como um poliedro único (palma + 4 dedos fundidos em uma cunha + polegar separado) com luva preta nos rifles e manga camuflada; em `arms_ik.gd`, prender a esquerda ao guarda-mão e a direita ao punho por socket por arma.
   Prova: `ak47_1_quadril.png`, `m4_1_quadril.png`, `mosin_1_quadril.png` e `glock_3_tiro_q1.png` com mão como silhueta contínua (sem faixas de fundo entre dedos), como em `mosin_lowpoly.png`.

3. **Coice e flash quase não existem.** AK q0 vs q2 com o mesmo topo da arma (y≈375), flash lateral só em q0.
   Correção: em `viewmodel.gd`, recuo de 4–6 cm em z e 3–4° de pitch no pico (q1) com retorno em q5, subindo o clamp do `_kick` para ±1,5; criar sprite de flash com estrela de 4 pontas, 20 cm, ancorado no nó `Muzzle`, 2 quadros, mais um OmniLight curto. Glock: nó `Slide` recua 2,5 cm em 0,04 s.
   Prova: `ak47_3_tiro_q1.png` com o topo da arma ≥ 25 px acima do de q0, e q0/q1 com ≥ 400 px amarelos (R>230, G>200, B<120) a ≤ 20 px do cano; `glock_3_tiro_q1.png` com ferrolho recuado ≥ 12 px.

4. **Recarga não tem carregador nem mão que o troque.** A AK só inclina; a Glock/M4 repetem o quadril.
   Correção: animação em 3 fases em `viewmodel.gd` (inclina +25° e desce 6 cm; nó `Mag` desanexa e cai; a mão esquerda traz o novo e o encaixa, `Slide`/ferrolho volta no fim); capturar em t = 0,3, 0,8, 1,4 s.
   Prova: `ak47_4_recarga_a/b/c.png` e `glock_4_recarga_a/b/c.png` com o carregador fora do receptor em ao menos um dos quadros.

5. **Lunetas são máscara plana, e o ACOG é igual à Mosin.**
   Correção: em `game/core/ads_indicator.gd` / `ui/crosshair.gd`, anel de tubo (borda de 30–40 px com vinheta), retículo de 2 px e ≥ 60 px na Mosin (mil-dot), chevron âmbar de 24 px e retículo de ponto no ACOG, zoom diferente (ACOG 4x, Mosin 6x) e transição de 0,12 s com a luneta 3D.
   Prova: `mosin_2_mira.png` e `ak47_acog_2_mira.png` visivelmente diferentes, retículo com contraste ≥ 4:1 sobre o alvo branco, e `ak47_acog_2b_entrando.png` com o tubo 3D.

6. **Captura de 3ª pessoa continua quebrada e as poses são iguais.** `poses_wf/ak47_idle_frente.png` é só céu/chão; idle, aim e fire repetem a mesma pose.
   Correção: em `game/tests/soldado_poses.gd`, posicionar a câmera "frente" a azimute 0° e enquadrar pelo AABB do modelo (incluindo agachado), reprovando o teste com < 300 cores; em `body_model.gd`/`arms_ik.gd`, alvos de IK distintos (idle: arma baixa −30°; aim: coronha no ombro e bochecha na coronha; reload: mão esquerda no carregador). Baixar o socket da arma 8–10 cm e escurecer/encurtar o cano da Mosin.
   Prova: nova `folha.png` com frente, perfil e traseira de uma mesma pose + as 4 poses com ângulo de cano ≥ 15° de diferença entre idle e aim.

7. **Paredes e teto dos interiores têm mosaico ruidoso; ainda há móveis com textura foto.**
   Correção: em `tools/interior.py`/materiais de parede, trocar o mosaico por cor sólida de paleta (creme #E6D7A8 e verde-oliva #8A8A55) com rodapé e friso; teto branco-gelo liso; reduzir os albedos fotográficos (toalha, granito) a 2–3 cores e flat shading; escurecer menos os batentes (#3A4A5C) com folha de porta visível; substituir o "saco" marrom do `quarto_ne.png` por uma caixa ou baú e acrescentar tapete e 1 item de loot.
   Prova: `casa_demo*/sala.png`, `quarto_ne.png` e `cozinha.png` refeitos sem padrão de pixel > 4 px nas paredes (desvio padrão de luminância < 12 numa área de parede) e com ≥ 5 objetos por cômodo.

8. **A vila não é legível no mapa nem no tour, e o estande é geometria de depuração.** `ilha_aerea.png` não mostra quarteirões, `ilha_vila.png` mostra barranco, e o estande tem caixa marrom e parede bege tampando 30% da tela.
   Correção: em `game/tests/ilha_tour.gd`, câmera "vila" na rua principal a 1,7 m olhando casas a 20–40 m; em `vegetation.gd`/layout, 1–2 árvores facetadas de 6–9 m por lote e cerca de ripas fechando os quintais; aérea mais baixa (45°, 250 m) sobre a vila. No estande, remover o bloco marrom e a parede bege e usar chão com textura, tendo a pista como em `ak47_fps.jpg`.
   Prova: `ilha_vila.png` com ≥ 2 casas ocupando ≥ 25% da largura e uma árvore grande no plano médio; `ilha_aerea_vila.png` com ≥ 6 casas legíveis; `estande_*/ak47_1_quadril.png` sem o polígono marrom em x 0–930, y 540–768.

## Resultado vs. crítica anterior

- Nota geral 3,5 → **4,8** (+1,3).
- Eixos que subiram: interiores (+3), mapa (+2), mira (+1), quadril (+2), tiro (+1).
- Eixos iguais: personagem (5), menu (7).
- Meta do ciclo (≥ 6 em mira, quadril e tiro): **não atingida**. O próximo ciclo deve gastar quase todo o esforço nos itens 1–5 acima, e não em mapa/interiores.
