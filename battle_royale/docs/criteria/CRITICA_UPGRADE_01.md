# CRÍTICA UPGRADE 01 — arte e jogabilidade (agente Critério)

Data: 2026-09-30 · Resolução das capturas: 1024×768 (coordenadas em px da captura original).
Referências: `docs/ref/ak47_fps.jpg`, `docs/ref/mosin_lowpoly.png`, `docs/ref/personagem.jpg`, `docs/ref/menu_inventario.jpg`.
Ordem temporal das capturas de estande (mtime): 22 (17:22) → 23 → 28 → 34 → 35 (17:37). Julguei a mais recente de cada arma.

## Quadro de notas

| # | Eixo | Nota |
|---|------|------|
| 1 | Mira de ferro / ACOG vs ak47_fps.jpg | **2/10** |
| 2 | Arma no quadril, mãos e recarga vs mosin_lowpoly.png | **1/10** |
| 3 | Efeito de tiro (flash, coice) q0..q5 | **2/10** |
| 4 | Personagem 3ª pessoa vs personagem.jpg | **5/10** |
| 5 | Mapa / vila / áreas vs ak47_fps.jpg | **5/10** |
| 6 | Interiores | **3/10** |
| 7 | Menu / inventário vs menu_inventario.jpg | **7/10** |
| — | **NOTA GERAL** | **3,5/10** |

A nota geral é puxada para baixo porque a primeira pessoa (eixos 1–3) é o que o jogador vê 100% do tempo, e ela está quebrada. O menu e o personagem estão perto da referência; a arma na mão, não.

---

## 1. Mira de ferro / ACOG — 2/10

Referência: em `ak47_fps.jpg` a AK aparece centralizada e baixa. A massa de alça e receptor fica abaixo de y≈55% da tela, a massa de mira (x≈700, y≈380 de 1361×768) fica isolada no centro e o alvo continua visível logo acima dela. As mãos cor de pele seguram os dois lados do guarda-mão.

Problemas:

1. **A AK-47 em mira tampa o alvo** (`estande_35/ak47_2_mira.png`, `estande_34/ak47_2_mira.png`, `estande_23/ak47_2_mira.png`). Um bloco cinza-escuro sólido em x 453–543, y 385–583 (≈90×200 px) fica bem no centro. É a alça ou a tampa do receptor alta demais e perto demais da câmera. As "orelhas" do túnel da massa (x 442–470 e 535–555, y 375–440) aparecem, mas o poste da massa fica escondido atrás do bloco. Também não há mão nenhuma na imagem, só um bloco marrom em x 585–650, y 580–768.
   **Correção:** em `game/core/viewmodel.gd` (pose ADS da AK, ou a tabela de offset ADS em `weapon_db.gd`), baixar o pivô ADS e afastá-lo, para que a face superior da tampa fique ≥ 25 px abaixo do centro da tela e a largura do receptor ocupe ≤ 18% da largura (≈180 px) na base. Conferir se a alça (`RearSight`) do modelo não está escalada ou duplicada: rodar `tests/_sight_probe.gd` e exigir o alinhamento topo do poste = centro da tela ±3 px. Adicionar as mãos (IK de `arms_ik.gd`) no guarda-mão, como na referência.
   **Prova:** nova `estande_36/ak47_2_mira.png` com o alvo central inteiramente visível, o poste da massa visível dentro do túnel em (512±3, 384±3), pele das mãos em x 330–450 e 570–700 na faixa y 450–650, e nenhum pixel com luminância < 80 dentro do retângulo x 470–554, y 300–380 fora do poste.

2. **A M4 em mira tem um "anel/prato" flutuante e um cilindro fora do eixo** (`estande_35/m4_2_mira.png`). Um anel plano cinza atravessa a tela em x 368–614, y 550–600, e um cilindro preto (supressor ou tubo de luneta?) aparece em x 575–675, y 610–735. A arma está desalinhada: a alça fica em x 465–525, y 370–440, mas o carry-handle e o guarda-mão laranja se desviam para a direita (x 540–600).
   **Correção:** no importador (`tools/importar_armas.py`) ou na cena da M4, remover o nó que gera o anel (provavelmente um cano, lanterna ou trilho girado 90°). Corrigir a rotação local da arma no ADS para yaw 0 e roll 0, e ocultar a luneta/lanterna quando não houver acessório.
   **Prova:** `m4_2_mira.png` sem nenhum objeto que atravesse a tela na horizontal, com a alça e a massa sobrepostas e centradas em x = 512±4.

3. **As lunetas (Mosin / AK ACOG) são uma máscara 2D circular com retículo minúsculo** (`estande_28/mosin_2_mira.png`, `estande_22/ak47_acog_2_mira.png`). O círculo tem raio ≈256 px, o fundo é escurecido sem mostrar o corpo da luneta e o retículo é uma cruz vermelha de ~12 px, quase invisível sobre o alvo branco. O ACOG não tem chevron, e a Mosin não tem a caixa da luneta na tela (na referência o tubo e o anel da luneta são objetos 3D).
   **Correção:** em `game/core/ads_indicator.gd` / `ui/crosshair.gd`, trocar a máscara plana por uma sobreposição com anel do tubo (borda preta de 30–40 px e vinheta), um retículo com traço de ≥2 px e comprimento ≥ 60 px para a Mosin, e um chevron âmbar de ~24 px para o ACOG. Mostrar o corpo 3D da luneta nos 0,12 s de transição.
   **Prova:** `mosin_2_mira.png` e `ak47_acog_2_mira.png` com o retículo legível sobre o alvo branco (contraste ≥ 4:1), e um quadro intermediário de transição (`_2b_entrando.png`) com a luneta 3D.

## 2. Arma no quadril, mãos e recarga — 1/10

Referência: em `mosin_lowpoly.png` o rifle entra pela direita-inferior em diagonal, com a coronha no ombro fora da tela e o cano apontando para o centro-alto. A mão com luva preta segura o guarda-mão, a manga verde low poly fica visível, a coronha é de madeira laranja e a arma ocupa ~35% da tela.

Problemas:

1. **Mosin no quadril está virada para a câmera e com materiais quebrados** (`estande_28/mosin_1_quadril.png`). A ocular da luneta aponta para o jogador (x 495–660, y 450–540), um disco ciano saturado (#00FFFF aprox.) ocupa x 630–800, y 670–768 (lente sem material) e o corpo é branco/preto chapado. Não há madeira, luva nem manga. A recarga (`mosin_4_recarga.png`) repete o mesmo bloco.
   **Correção:** em `tools/build_mosin_lp.py` / `tools/pose_quadril.py`, girar a arma 180° em yaw, aplicar os materiais madeira (#B5652A), aço (#3A3D40) e vidro escuro (lente #1B2A33, sem emissivo) e reposicionar para o cano apontar a (≈560, 330). Ligar a malha de braço e mão (`build_fp_bracos.py`/`build_fp_maos.py`) com manga verde e luva preta.
   **Prova:** `mosin_1_quadril.png` sem nenhum pixel ciano (R<60, G>200, B>200 = 0 px), com a madeira laranja visível ≥ 8% da tela e a luva mais a manga verde no quadrante inferior esquerdo, como em `mosin_lowpoly.png`.

2. **AK-47 e M4 no quadril aparecem "de ponta-cabeça/de lado" e sem mãos** (`estande_35/ak47_1_quadril.png`, `ak47_5_andando.png`, `m4_1_quadril.png`). Na AK, o guarda-mão laranja sobe na vertical (x 570–700, y 540–768), a massa em forquilha fica no topo (x 560–600, y 470–540) e o receptor aparece por trás (x 640–815, y 590–768). Nenhuma mão cor de pele aparece. Na M4, a arma sai da tela pela direita em x 680–760, e a "mão" é um bloco bege quadrado em x 510–620, y 580–700.
   **Correção:** em `game/core/viewmodel.gd` (transform do quadril por arma) ou `weapon_db.gd`, corrigir a pose do quadril para cano apontando a (≈540, 360), com rotação pitch ≈ -5°, yaw ≈ 8° e roll 0, e a arma inteira dentro da tela. Religar as mãos low poly (pele #E8B48A) no guarda-mão e no punho via `arms_ik.gd`.
   **Prova:** `ak47_1_quadril.png` com o cano horizontal-diagonal, as duas mãos cor de pele visíveis e a arma sem sair pela borda direita (bounding box x ≤ 1000).

3. **A recarga não comunica nada** (`estande_35/ak47_4_recarga.png`, `m4_4_recarga.png`, `estande_34/glock_4_recarga.png`). A pose é idêntica à do quadril, e só o contador vira "0" vermelho. Não há carregador saindo, mão indo ao carregador nem inclinação da arma. Na Glock, os dedos continuam em "escada" (ver eixo 3).
   **Correção:** em `viewmodel.gd`, criar a animação "reload" em 3 fases: inclinar a arma (roll +25°, desce 6 cm), soltar o carregador (nó `Mag` desanexado com queda) e a mão esquerda trazer o carregador novo. Capturar em t = 0,3/0,8/1,4 s.
   **Prova:** três quadros `ak47_4_recarga_a/b/c.png` com a arma visivelmente inclinada e o carregador fora do receptor em pelo menos um deles.

## 3. Efeito de tiro (flash e coice) nos quadros q0..q5 — 2/10

Medição: centroide dos pixels escuros da arma (luminância < 80, janela x 300–724, y 300–690).
- AK (estande_35): q0 (510,507) → q1 (507,501) → q5 (506,500). Deslocamento máximo de 7 px, e o topo fica fixo em y=372.
- M4 (estande_35): o centroide varia ≤ 5 px e o topo fica fixo em y=372.
- Glock (estande_34): de q0 para q1 desce 15 px (489→504) e depois para. O ferrolho não recua.

Problemas:

1. **O coice é imperceptível** (≤ 1% da altura da tela). Na AK e na M4, q1..q5 são praticamente o mesmo quadro. `viewmodel.gd` linha 443–444 soma `_kick_vel += 5.0` e `_kick_rot ≤ 3.0°`, e o clamp `_kick` em ±0,6 (linha 707) achata o recuo.
   **Correção:** para rifles, recuo de 4–6 cm para trás mais 3–4° de pitch no pico (q1–q2) e retorno até q5. Subir o clamp para ±1,5 e o `view_kick` (weapon_def.gd:36) da AK para 0,8.
   **Prova:** em q1/q2 o topo da arma sobe ≥ 25 px e o centroide sobe ≥ 15 px em relação a q0, voltando a ±5 px em q5, medido com o mesmo script de centroide.

2. **O flash dura um quadro e sai fora do cano.** Só aparece em q0 (AK: estrela amarela em x≈540–620, y≈390–450, à direita da massa; M4: x≈470–560, y≈340–450). Nenhum brilho aparece em q1, embora o código prometa `_flash_quadros = 2` (viewmodel.gd:486). Na mira, o flash fica deslocado à direita do eixo do cano.
   **Correção:** garantir 2 quadros de flash (a captura de q1 deve cair dentro de `_flash_t`, ou aumentar `_flash_t` para 0,05 s × 2 quadros com base no delta de captura). Ancorar o flash ao nó `Muzzle` corrigido depois do conserto da pose ADS (eixo 1). Acrescentar um sprite frontal (estrela de 4–6 pontas vista de frente) mais um clarão da `OmniLight3D` visível na arma.
   **Prova:** q0 e q1 com pixels amarelos (R>230, G>200, B<120) ≥ 400 px cada, com centro do flash a ≤ 20 px da ponta do cano.

3. **A pistola tem dedos em "escada" e o ferrolho não recua** (`estande_34/glock_3_tiro_q0..q5.png`, `glock_2_mira.png`). A mão esquerda é formada por 5 lâminas horizontais empilhadas (x 415–490, y 500–660) que parecem uma escada. Não há luva nem polegar reconhecível, e o ferrolho (x 487–537, y 390–660) não muda entre q0 e q1. Ponto positivo: a cápsula ejetada aparece em q0 (x≈900, y≈350).
   **Correção:** em `tools/build_fp_maos.py`, fundir os dedos da mão de apoio num bloco único facetado (como as mãos de `ak47_fps.jpg`). Em `viewmodel.gd`, animar o nó `Slide` com -2,5 cm em z por 0,04 s no disparo.
   **Prova:** em `glock_3_tiro_q1.png` o ferrolho recuado ≥ 12 px em relação a q0, e a mão esquerda formando uma silhueta contínua (sem faixas de fundo entre os dedos).

## 4. Personagem em 3ª pessoa — 5/10

Positivo: o capacete verde, o lenço vermelho, a mochila, o camuflado geométrico e as botas marrons batem com `personagem.jpg` (`poses_wf/folha.png`).

Problemas:

1. **As capturas "frente" não são de frente, e 3 estão vazias.** `ak47_idle_frente.png`, `ak47_run_frente.png` e `mosin_run_frente.png` só mostram céu e chão (87, 80 e 69 cores distintas, contra ~1000 nas válidas). As demais "frente" mostram o mesmo perfil ¾ das "lado". Em `ak47_crouch_frente.png` / `mosin_crouch_frente.png` o boneco sai cortado pela borda direita (x > 900).
   **Correção:** em `game/tests/soldado_poses.gd`, posicionar a câmera "frente" em azimute 0° diante do peito (olhando −Z do soldado) e enquadrar pelo AABB do modelo em cada pose (incluindo agachado). Falhar o teste se a imagem tiver < 300 cores.
   **Prova:** 12 capturas "frente" mostrando rosto e lenço de frente, soldado inteiro dentro de x 100–924.

2. **As poses idle/aim/fire/reload são idênticas** (`ak47_idle_lado`, `ak47_aim_lado`, `ak47_fire_lado`, `ak47_reload_lado`: mesma silhueta, arma na mesma altura y≈130/390 na folha). Não há recarga (mão no carregador) nem diferença entre ocioso (arma baixa) e mira (coronha no ombro, cabeça inclinada).
   **Correção:** em `game/core/body_model.gd` / `arms_ik.gd`, criar alvos de IK distintos: idle com a arma baixa (cano a −30°), aim com a coronha no ombro e a bochecha na coronha, e reload com a mão esquerda no carregador e a arma inclinada 30°.
   **Prova:** `folha.png` nova em que as 4 poses tenham ângulo do cano diferente em ≥ 15° entre idle e aim, e a mão esquerda longe do guarda-mão em reload.

3. **A arma segura alto demais e é pequena para o corpo.** A coronha fica na altura do queixo/lenço, e não no ombro. A AK mede ≈0,55 da largura do torso vista de lado (≈0,6 m equivalentes para 1,8 m de altura). A Mosin tem um cano cinza-claro longo e fino que parece uma vareta (em `mosin_*_lado` o cano se estende ~1,3× o comprimento da coronha e tem a cor do céu). Faltam o rádio de ombro com antena visível e o pouch de cintura da referência (o pouch aparece pequeno em x≈250, y≈205 na folha).
   **Correção:** em `tools/build_soldado.py`, baixar o socket da arma 8–10 cm e escalar a AK para 0,88 m. Na Mosin, trocar a cor do cano para aço escuro (#3A3D40) e encurtar para comprimento total 1,23 m. Aumentar o rádio no ombro esquerdo com antena de 25 cm.
   **Prova:** `ak47_aim_lado.png` com a coronha abaixo da linha do queixo e a AK com comprimento ≥ 45% da altura do soldado, e `mosin_aim_lado.png` com o cano escuro.

## 5. Mapa, vila e áreas — 5/10

Positivo: os pacotes design_02/03 têm vila com casas coloridas (`ilha_cen_vila_rua.png`: casa azul-petróleo em x 740–1024, y 260–470 lembra a casa verde da referência), igreja, galpões, cercas de madeira (`ilha_cen_fazenda_piquete.png`), postes com fios, carros e usina. A paleta low poly é coerente.

Problemas:

1. **Não há capim alto nem vegetação rasteira.** A referência tem capim denso em toda a metade inferior (y > 420 de 768). Nas capturas o chão é um verde chapado liso. Em `ilha_cen_fazenda_piquete.png` ~60% da imagem (y 330–768) é verde uniforme, e em `ilha_cen_quartel_patio.png` ~55%. Só há tufos isolados (`ilha_cen_usina.png` x 720–1024, y 680–768; `tour_pacote3/ilha_fazenda.png` 1 tufo em x 0–70).
   **Correção:** em `game/maps/ilha/vegetation.gd` (+ `tools/build_vegetacao.py`), adicionar um MultiMesh de capim (tufos de 3–5 lâminas, altura 0,5–0,9 m, 2 tons de verde oliva) com densidade ≥ 6 tufos/m² até 35 m da câmera, excluindo estrada, piso e água.
   **Prova:** `ilha_cen_fazenda_piquete.png` e `ilha_cen_vila_rua.png` refeitos com ≥ 40% da faixa y 500–768 coberta por lâminas de capim, e o FPS do HUD ≥ 60 em `perf_mapa.gd`.

2. **A captura "vila" não mostra a vila, e o enquadramento do tour é fraco** (`tour_pacote3/ilha_vila.png`). O barranco ocupa x 0–600, y 320–768 e as casas ficam a >150 m (x 650–1000, y 360–390, só ~30 px de altura). As árvores são poucas e pequenas perto das casas (a referência tem árvore facetada grande colada à casa).
   **Correção:** em `game/tests/ilha_tour.gd`, mover a câmera "vila" para a rua principal, a 1,7 m de altura, olhando para as casas a 20–40 m. Em `ilha_layout_src.py`/`vegetation.gd`, colocar 1–2 árvores de copa facetada (6–9 m) por lote de casa.
   **Prova:** `ilha_vila.png` com ≥ 2 casas ocupando ≥ 25% da largura, pelo menos uma árvore grande e cerca de ripas no plano médio, como em `ak47_fps.jpg`.

3. **As áreas abertas são grandes e vazias, e as cercas não fecham lotes.** Em `ilha_cen_fazenda_colonos.png`, `ilha_cen_quartel_patio.png` e `tour_pacote3/ilha_fazenda.png` há gramados de 100+ m sem cobertura. A cerca de ripas da referência (brancas/cinza fechando o quintal) aparece só como trechos soltos. Em `ilha_cen_vila_rua.png` a bicicleta (x 290–400, y 500–560) mostra só duas rodas e o quadro está quase invisível.
   **Correção:** em `tools/detalhes_src.py`/`build_detalhes.py`, cercar cada lote de casa com cerca de ripas (perímetro fechado com portão) e espalhar cobertura (fardos, tambores, lenha, carroças) a cada 15–25 m nas áreas abertas. Corrigir o material do quadro da bicicleta.
   **Prova:** capturas `ilha_cen_*` sem nenhum trecho > 40 m de gramado sem objeto de cobertura no terço inferior, e casas da vila com cerca contínua visível.

## 6. Interiores — 3/10

Fonte: `raw/interiores_02/folha.jpg` (10 quadros em grade 4×3).

1. **Mistura de estilos: texturas fotográficas em mundo low poly.** O fogão com textura foto (quadro 2, x 600–900, y 40–260 da folha), o lençol amassado realista (quadros 5–6), o sofá floral foto e a mesinha de estampa preto/branco (quadros 8–10) destoam das paredes chapadas e do resto do jogo.
   **Correção:** em `tools/importar_moveis.py`/`game/core/moveis.gd`, substituir os albedos fotográficos por cor sólida/paleta (reduzir a textura a 1–3 cores médias ou usar vertex color) e ativar flat shading.
   **Prova:** folha nova em que nenhum móvel tenha variação de alta frequência (desvio padrão de luminância < 12 dentro do móvel).

2. **As câmeras atravessam ou colam nos móveis e o enquadramento é inútil.** No quadro 2 o fogão enche o quadro de cima, nos quadros 5–6 a cama ocupa 80% e no quadro 1 a parede cinza ocupa 1/4 à esquerda. Não dá para avaliar o cômodo.
   **Correção:** em `game/tests/interior_capture.gd`, posicionar a câmera no vão da porta, a 1,6 m de altura, com FOV 75° e olhando para o centro do cômodo, validando que não há colisão a < 0,5 m.
   **Prova:** folha nova em que cada quadro mostre ≥ 2 paredes e o piso inteiro do cômodo.

3. **Os cômodos estão vazios e as portas/janelas são buracos escuros.** Cada cômodo tem 1–3 móveis. As portas são retângulos azul-marinho chapados (quadro 7 x 1320–1390; quadro 8 x 1700–1800; quadros 9–10 x 260–380 e 710–840), sem folha de porta nem batente com luz. A sala e o quarto não têm tapete, quadro, luminária de teto ou loot visível. O galpão (quadro 4) é o melhor, com prateleiras e paletes.
   **Correção:** em `tools/interior.py`, adicionar folha de porta (aberta 70°) com batente e colocar 5–8 props por cômodo (mesa, cadeiras, armário, tapete, TV/rádio, loot no chão). Em `ilha.gd`, garantir a luz ambiente interna (fill > 0,25) para que os vãos não fiquem pretos.
   **Prova:** folha com ≥ 5 objetos por cômodo e portas com folha visível.

## 7. Menu e inventário — 7/10

Positivo: a estrutura segue a referência de perto (painéis com cabeçalho amarelo, PROXIMIDADE à esquerda, EQUIPAMENTO e COLETE/MOCHILA à direita, "mão | EQUIPADO" central, hotbar e ícones de status). O personagem de fundo e a vila combinam.

1. **O fundo não é escurecido nem desfocado, e o painel central cobre o personagem.** Na referência o cenário aparece escurecido e desfocado. Em `03_inventario_1024x768.png`, o fundo (casa em x 0–380, y 240–460, galpão em x 590–740) tem o mesmo contraste dos painéis. O painel "mão | EQUIPADO" (x 376–648, y 538–712) cobre as pernas, e o boneco fica cortado pela moldura.
   **Correção:** em `game/ui/br_inventory_ui.gd`/`menu_stage.gd`, aplicar ao 3D um blur/escurecimento (vinheta, exposição −35%) enquanto o inventário estiver aberto. Reduzir o painel central a 230 px de altura e ancorá-lo em y ≥ 560, ou mover o boneco 40 px para cima.
   **Prova:** novo `03_inventario_1024x768.png` com a luminância média do fundo (fora dos painéis) ≤ 70% da atual e os joelhos do boneco visíveis.

2. **O personagem do menu é blocado demais em relação à referência.** O lenço vermelho é um bloco retangular reto (x 475–545, y 200–330 em `01_menu`) e os ombros formam "asas" quadradas (x 390–440 e 555–600, y 290–420 no inventário). As mãos são palitos separados (x 400–420, y 440–500), enquanto a referência tem lenço dobrado envolvendo o pescoço e mãos fechadas.
   **Correção:** em `tools/build_soldado.py`, modelar o lenço como cone/anel facetado com dobra frontal, arredondar o deltoide com um loop extra e fundir os dedos em uma mão fechada.
   **Prova:** `01_menu_1024x768.png` com a silhueta do lenço triangular/curva (sem cantos retos de 90°) e as mãos como bloco único.

3. **Slots de equipamento vazios e ícones de proximidade em grade crua.** O painel EQUIPAMENTO do inventário mostra F1–F4 vazios (x 767–977, y 58–104) com texto de ajuda longo. Na referência ele exibe ferramentas (machado, pá) em ilustrações grandes. PROXIMIDADE é uma grade de células vazias (x 95–235, y 150–215); na referência há uma amostra do chão com os itens. Os rótulos "ACOG"/"RESERV" (x 425–500, y 697–705) têm ~7 px e são ilegíveis a 1024×768.
   **Correção:** em `br_inventory_ui.gd`/`item_icons.gd`, ocultar as células vazias de PROXIMIDADE (mostrar só os itens sobre um fundo de chão texturizado), preencher EQUIPAMENTO com as armas atribuídas (miniatura grande) ou recolher o painel, e usar fonte mínima de 11 px.
   **Prova:** `03_inventario_1024x768.png` sem células vazias em PROXIMIDADE e rótulos com altura de caixa ≥ 11 px.

---

## Lista priorizada de correções (ordem de execução)

1. **[P0] Pose do viewmodel no quadril (AK/M4/Mosin) e mãos** (eixo 2.1, 2.2): arma virada, sem mãos, Mosin com lente ciano. Isso bloqueia toda a primeira pessoa. `viewmodel.gd`, `weapon_db.gd`, `build_mosin_lp.py`, `pose_quadril.py`, `arms_ik.gd`.
2. **[P0] Pose ADS da AK/M4** (1.1, 1.2): bloco que tampa o alvo, anel flutuante na M4. `viewmodel.gd` e a cena da M4. Validar com `_sight_probe.gd`.
3. **[P1] Coice visível e flash de 2 quadros** (3.1, 3.2): recuo ≥ 25 px em q1–q2, flash em q0 e q1 ancorado no cano. `viewmodel.gd:443-486, 707`.
4. **[P1] Animação de recarga real** (2.3) e ferrolho da pistola (3.3).
5. **[P1] Capim denso e vila enquadrada** (5.1, 5.2): `vegetation.gd`, `ilha_tour.gd`.
6. **[P2] Captura de poses 3ª pessoa** (4.1) e poses distintas idle/aim/reload (4.2). Depois, a altura e escala da arma (4.3).
7. **[P2] Interiores**: tirar as texturas foto, refazer as câmeras de captura e mobiliar (6.1–6.3).
8. **[P2] Cercas fechando lotes e cobertura nas áreas abertas** (5.3).
9. **[P3] Inventário**: blur no fundo, painel central, slots e fontes (7.1, 7.3). Lenço, ombros e mãos do boneco (7.2).
10. **[P3] Lunetas**: retículo legível, chevron do ACOG e transição 3D (1.3).

Critério de aceite do próximo ciclo: estande_36 com as provas dos itens 1–4 e nota ≥ 6 nos eixos 1–3.
