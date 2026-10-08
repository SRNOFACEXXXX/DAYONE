# Acertos e erros (aprendizados do projeto — leia antes de repetir qualquer ideia)

## ACERTOS
- **Testar o jogo real com inputs reais** (`Input.action_press`, Soldier, BRMatch) pegou bugs que testes sintéticos não pegavam (troca de armas, spawn, ADS).
- **Aquecimento de shaders em SubViewport escondida** (`autoload/loading.gd`) com orçamento por quadro + pré-montagem da partida → menu liso. A cutscene de abertura aproveita isso.
- **Retarget Mixamo em espaço global** (`cinematic/mx_retarget.gd`): copiar movimento global (`k·motion·k⁻¹·corr·rest`) + correção T→A por osso resolveu corpo voando/braços errados. Não copie rotações locais entre esqueletos com repouso diferente.
- **Direção de carro**: o veículo anda em **+Z**; dirigir de verdade com inputs + waypoints. Forçar `global_rotation` todo quadro colapsa a suspensão e as rodas atravessam o corpo.
- **Mira**: sempre usar o ADS real (`alt_fire` + `Input.mouse_mode = CAPTURED`, esperar `soldier.ready_at`, deixar `_ads_amount` subir). Retículo holográfico é projetado pelo viewmodel (`reticulo_holo`); forçar `_ads_amount=1` descola retículo e arma.
- **Física a 60 Hz em filmagem a 30 fps** = 2 passos por quadro exatos (64 Hz causava tremida).
- **Variar zumbis** (fase/velocidade/escala por instância) acaba com o efeito de "marcha em uníssono".
- **Terreno autoral** (JSON à mão + `bake_ilha.py`) dá controle de qualidade; procedural gerou mapa feio.
- **Pós barata no CPU** (grade, bloom, vinheta, grão, DoF por profundidade IA em baixa frequência) deu look de cinema sem GPU.
- **Docs vivos** (`ATUALIZACAO_DAYONE.md`) como fonte da verdade do loop.

## ERROS (não repetir)
- Dividir em muitos subagentes baratos: processos Godot órfãos, janela cinza no `JOGAR.cmd`, relatórios sem prova.
- Declarar "resolvido" com print sem medir (mira holográfica flutuando 5–10 cm do cano passou assim).
- Rodar testes longos (20 min) atravessando props sem progresso mensurável.
- CPUParticles3D com `position` definido depois de `add_child` → fumaça invisível (pré-simula na origem). Defina antes. Billboard exige `BILLBOARD_ENABLED + billboard_keep_scale`; curva de escala precisa de min/max.
- Esconder **todos** os CanvasLayer escondeu também as miras do jogo (`MosinAimLayer`/`AimLayer`).
- Câmera de cinema entrando em árvore/poste/arbusto; composição sem checagem prévia → usar previews + crítico.
- Cortes de 1 quadro com câmera antiga em mundo novo (acertar a câmera no 1º quadro da tomada).
- Vídeo longo renderizado antes de aprovar tomadas → retrabalho de ~1 h. Aprovar folhas de contato primeiro.
- Rodar o **mapa inteiro** para uma cinemática (vegetação, zumbis ambientes, diretor, loot) deixa a captura pesada. Ideal: cenários isolados leves montados com props (ainda **não feito**; ver abaixo).
- `class_name` novo sem registrar (`--headless --editor --quit`) → erros de parse falsos.
- Heredocs enormes no bash → falha de EOF.
- Godot só toca vídeo **Theora (.ogv)**; MP4/H.264 não toca. Sem ffmpeg no PATH: converter pelo Blender 4.5 (`tools/trailer/blender_para_ogv.py`). PyAV não tem encoder Theora.
- Arquivos > 100 MB não sobem no GitHub sem Git LFS (FBX do Mixamo/pack zumbi, MP4 do trailer, `bruto.avi`).

## EM ABERTO (dívida técnica conhecida)
- Cinemáticas ainda rodam no mapa completo; falta estúdio isolado leve (`EstudioMatch` + cenários com props) — rascunho do plano em `docs/trailer/PRODUCAO.md`.
- Mãos bege em bloco da AK/Uzi, braço estranho da M249 em 1ª pessoa, base do trailer sem telhado/porta, cenas noturnas escuras demais, carro pouco visível no trailer.
- Lista antiga: ver `ATUALIZACAO_DAYONE.md`.
