# Armas em 1ª pessoa — o que deu certo e o que deu errado (foco desde 2026-10-01)

## O que FALHOU (não repetir)
- Mãos/antebraços gerados por blocos em Blender (tools/build_fp_maos.py): ficaram "mãos gigantes de caixa"; nenhuma versão passou.
- Recarga procedural (carregador descendo por código + mão interpolada à mão; depois movimento extraído de outro pack aplicado
  em outro modelo): nunca encaixou, mão não pegava o carregador, arma girava para fora da tela.
- ACOG/holográfica montadas com medidas chutadas no modelo velho: ponto vermelho fora do centro, moldura enorme.
- Iron sights calculados por "vértice mais alto": anel/poste errado, mira torta no quadril.
- Escurecer/clarear materiais por shader para disfarçar o modelo (AK "estourada" branca).
- Sons sintetizados (camadas boom/cauda): soavam artificiais.

## O que FUNCIONA (base nova)
- Packs FPS reais com braços+arma+animações no MESMO esqueleto (BarcodeGames, Fab, grátis):
  - M4: Downloads/m4_pack/M4 Animations/M4.fbx (Idle, Fire, Reload, Reload_Empty, Draw, Holster)
  - G17: Downloads/glock17.fbx (mesmas animações)
- tools/lowpolyfy.py: converte o pack para a estética low poly do jogo (decimate, cor chapada por face via k-means da textura,
  flat), transforma peças presas a osso em malha com peso 100% no osso (sem isso o reexport glTF desloca a arma),
  `--sem-vidro` apaga faces transparentes (janela da mira), `--escurecer=Material:f`.
- core/viewmodel.gd `_load_rig`: o osso FPS_Camera do pack vai para o olho (Holder) + "rig_off"; "Arma" = BoneAttachment3D
  no osso Main_j (espaço em cm: +Z boca, +Y cima); animações renomeadas idle/fire/reload/reload_empty/draw.
  Configuração em assets/models/weapons/miras.json (chave "rig").
- Medidas reais tiradas do perfil da malha (tests/fp_rig_perfil.gd) — nada chutado.
- Mira holográfica: Fab "Holographic Sight" (Karnaval) → fp/holo_lp.glb; eixo do modelo +X, base y -0,0388 m,
  janela y 0,0511 m. Captura raw/ads_review/m4_holo.png ficou igual à referência (docs/ref/mira_holografica_REF.md).
- Sons: gravações do usuário (Glock/M4/M249) + Free Firearm Sound Library CC0 (AK, Mosin, 1911...) via tools/audio_usuario.py.

## Ferramentas de verificação
- tests/fp_pack_view.tscn (vê o pack pela câmera dele), tests/m4_ads.tscn -- --arma=X (quadril/iron/acog/holo),
  tests/recarga_capture.tscn, tests/ver_modelo.tscn (4 vistas de um glb), tests/estande_gate.tscn.

## Estado em 2026-10-01 (noite)
- M4: rig M4 low poly (animações reais Idle/Fire/Reload/Draw), holográfica igual à referência, ACOG 4x, iron alinhada (gate M1 ≤1,5 px).
- Glock/USP: rig G17 low poly (slide anima no tiro, recarga real com troca de carregador).
- M249 e M107: modelo próprio montado no rig da M4 (mão no cabo; carregador do modelo segue os ossos Mag1/Mag2 na recarga),
  escala 0,85/0,72 para caber na tela. Mão esquerda fica escondida atrás da M249 em parte da recarga.
- Mosin: no rig da M4 com luneta; FALTA ferrolho entre tiros (sem pack grátis de bolt-action; plano: TwoBoneIK3D da mão direita
  até o ferrolho) e recarga por clip (a do pack é de carregador).
- Áudio: tools/audio_nivelar.py — rajadas clipavam (soma de fatias até 1,9 de pico); agora pico ≤0,85 e loudness de ataque igualada
  (saturação suave nas gravações de campo muito "pontudas"). Prévia: raw/audio_preview/armas_v2.wav.
- Pendentes: Mosin ferrolho/clip; AK (rig M4 + modelo AK); mãos com manga verde (pack tem antebraço nu); Chrome desconectou
  (para baixar mais packs da Fab).

## 2026-10-01 (madrugada) — revisão após prints do usuário (mão branca enorme, holo gigante, arma pálida)
- Causa: lowpolyfy agrupava cores por k-means da textura e a luz do jogo estourava os tons médios → arma bege/branca, luva branca,
  antebraço nu. Agora: `--paleta=Material:#hex,...` (cores escolhidas à mão, mapeadas por luminância) e `--manga=Hand_D:#hex`
  (faces do antebraço/braço viram manga verde, por peso de osso). M4/G17 regenerados: arma cinza-chumbo, luva preta, manga oliva.
- Holográfica reduzida para o tamanho real do EXPS3 (escala não uniforme 0,68/0,6/0,85) e a alça/massa da M4 do pack é
  removida quando há óptica (`ferro_caixas`, triângulos cortados no espaço do osso Main).
- Referência estudada: github.com/Jeh3no/Godot-Simple-FPS-Weapon-System-Asset (MIT; raw/ref_repos): sway/tilt/bob por lerp com
  retorno exato a zero, recoil num nó próprio da câmera, animação de recarga em AnimationPlayer — mesma arquitetura que usamos.
- Pendentes: Mosin (sem ferrolho), AK (sistema antigo), mão esquerda da M249/M107 não encaixa no guarda-mão (IK TwoBoneIK3D
  disponível no Godot 4.7: LeftArm→LeftForeArm→LeftHand), Chrome desconectado (sem busca na Fab).

## 2026-10-02 — volta de crítica (docs/criteria/CRITICA_ARMAS_01.md, 4/10)
- Holográfica: medida a janela pela vista frontal (pixels→m): base visível em y=0, janela centro y=0,0509, 3,7x2,8 cm
  (a AABB do glb vai a -0,039 por vértices soltos — era isso que fazia a mira flutuar). Escala real 0,9. ADS agora igual à
  referência (janela limpa, carcaça embaixo). M249 com riser 2,2 cm; M107 sem as miras de ferro atrás.
- M4: alça/massa do pack removidas com óptica (ferro_caixas inclui a base da massa).
- Recarga: o enquadramento do animador deixava mãos/carregador abaixo da tela; durante "reload" o rig mistura para
  rig_reload [0,03, 0,09, -0,24] (M4/M249/M107) e [0,02, 0,05, -0,08] (Glock) → mão com o carregador aparece.
- Capturas agora em campo aberto (m4_ads/recarga_capture teleportam para -345, 352; yaw 40) — sem o parapeito.

## 2026-10-02 (tarde) — holográfica "flutuando" RESOLVIDA com medição
- Causa: posição da óptica vinha de constantes por arma (trilho/riser chutados): M249 com riser solto (+2,15 cm), Uzi +0,69 cm,
  AK afundada −0,55 cm, M107 1,8 cm fora do eixo do cano (trilho do modelo é descentrado), M249 0,82 cm fora.
- Correção: core/viewmodel.gd `_assentar_mira` / `_medir_assento` — mede a malha ao instalar a óptica (holo e ACOG, rig e wf):
  base = vértice mais baixo USADO por triângulos; desce/sobe até a superfície mais alta da arma sob a pegada (raio vertical
  contra os triângulos, grade 7x9); centro x vai para o eixo do cano (centro da ponta, últimos 4 cm). Cache por arma+óptica.
- Gate: tests/holo_offset.tscn -- --armas=m4,m249,m107,ak47,uzi [--mira=acog] → raw/holo_offset/holo_offset.json, capturas
  quadril/ADS/lado/frente e silhueta medida (python tools/perfil_mira.py <arma>). Limites: folga ≤0,5 cm, lateral ≤0,5 cm,
  ponto no centro ≤1,5 px (máx. de 60 quadros, normalizado ao FOV do quadril). Resultado: 0 falhas (holo e ACOG).
- Atenção: medir "topo" por VÉRTICES dentro da pegada engana em low poly (faces grandes); usar a superfície.
- Triagens do bloco: raw/triagem/{movimentacao_corrigido,pesquisa_packs,recarga_coice_quadril,qa_holo}.json

## Som "de simulador" (v3: peso + propagação)
- Gerador: `python tools/audio_peso.py` -> `game/assets/audio/weapons/t2/<arma>_t2_{perto,fatia,mec,cauda,longe,longe_fatia}_N.wav`
  (fonte: Free Firearm Sound Library, originais em `Assets/sons_novos/` com LICENCA.txt). Perto = gravação "near" + reforço grave
  + estalo + thump sintetizado (36–80 Hz), compressão, saturação suave e limitador (pico <= 0,95). Fatias de rajada = 2,4 períodos
  com fade cruzado. Cauda = IR de campo aberto sintética (RT60 1,3–2,6 s). Longe = gravação "mid distance" filtrada + reverb.
- Runtime: `game/core/tiro_som.gd` (todas as 8 armas). `TiroSom.plano(arma, d, local, rajada, com_cauda)` dá as camadas.
  Tiro alheio: atraso d/343 s, ganho -12·log10(d/8) dB, troca perto->longe entre 40 e 250 m, barramentos Tiros (<150 m),
  TiroMedio (LPF 2,8 kHz, <450 m), TiroLonge (LPF 1 kHz); audível até 1000 m. Pitch ±3%. Bus Tiros tem compressor leve.
- Barulho para IA: `Audio.barulho(pos: Vector3, raio: float, fonte: Node)` (signal), emitido a cada tiro com o raio do perfil
  (pistola 400–450 m, fuzil 850–950 m, Mosin 1000 m, M107 1200 m). Uso: `Audio.barulho.connect(func(p, r, f): if Audio.ouve(minha_pos, p, r): ...)`.
  Outros sistemas podem emitir com `Audio.emitir_barulho(pos, raio, fonte)`.
- Peso: o tiro local chama `soldier.controller.shake(tremor)` (0,14 Glock … 0,9 M107), decai em ~0,2 s.
- Teste: `res://tests/audio_armas.tscn` mixa offline os planos -> `raw/audio_preview/<arma>_{perto,100m,500m}.wav`,
  `ak47/m4_rajada_1s(_100m).wav` e `medidas.json` (pico, pico antes do limitador, loudness de ataque 50 ms, cauda).
