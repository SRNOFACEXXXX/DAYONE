# Trailer DAYONE — como foi feito e como refazer

Roteiro: `ROTEIRO.md`. Vídeo final: `C:\Users\satoshi\Documents\ChatGPT\teste\teste GPT\catcine\DAYONE_trailer.mp4`.

## Pipeline (tudo offline, nenhum custo extra de GPU no jogo)
1. **Imagem do jogo (Godot, Movie Maker)** — `game/cinematic/trailer.tscn` + `trailer.gd` (tomadas em `ato2_shots.gd.txt` e `ato3_shots.gd.txt`, aplicadas por `tools/trailer/aplica_ato2.py` e `aplica_ato3.py`).
   Roda o jogo REAL (ilha, clima, personagem do criador, zumbis com IA, armas, carro, construção, inventário) com câmera de cinema por tomadas.
   - Pré-visualizar uma tomada: `tools/trailer/prev.sh <tomada> <t1,t2,...>` → `raw/trailer/prev_<tomada>.png`.
   - Renderizar: `godot --path game res://cinematic/trailer.tscn --write-movie ../raw/trailer/bruto.avi --fixed-fps 30 --resolution 1280x720 > ../raw/trailer/render.log` (a linha `TRAILER_INICIO frame=N` marca o primeiro quadro do filme; o AVI inclui o áudio do jogo).
2. **Animações do Mixamo do usuário** (`Desktop\Assets\animações`, convertidas por `tools/trailer/fbx_anim_para_glb.py` em GLB leves) levadas ao esqueleto do personagem por `cinematic/mx_retarget.gd` (cópia de movimento em espaço global, como o zumbi): deitado na praia (Prone Turn), caçador (Shooting Arrow), idle.
3. **Música** original sintetizada: `tools/trailer/musica.py` (violão Karplus-Strong, slide, contrabaixo, drone, stomp, taiko, risers, impactos; Lá menor 76 BPM) → `raw/trailer/musica/`.
4. **Narração** `tools/trailer/narracao.py` (edge-tts, vozes neurais gratuitas: narrador `en-US-ChristopherNeural`, rádio `en-US-JennyNeural`) → `raw/trailer/voz/`.
5. **Mixagem** `tools/trailer/mix.py`: vozes com EQ/compressão/reverb/eco, rádio com passa-banda e estática, sidechain da música sob a voz, foley do jogo do AVI, ondas do mar, whooshes/impactos/risers nos cortes, silêncio de 0,65 s antes do ato III e de 0,6 s antes do logo, tinido após o primeiro tiro → `raw/trailer/mix.wav`.
6. **Pós-produção com IA** `tools/trailer/pos.py` (Python 3.11: opencv, onnxruntime, av):
   - *Depth Anything V2 Small* (ONNX, `raw/trailer/modelos/`, Hugging Face `onnx-community/depth-anything-v2-small`) a cada 10 quadros por tomada → desfoque de campo e névoa atmosférica por distância;
   - grading por ato (curva em S, saturação, tons frios/quentes), bloom, vinheta, aberração cromática, grão, gate weave, flashes de corte, fades, faixas 2,39:1, títulos (DAY ONE / DAYONE), H.264 1080p + AAC.
   - Conferir quadros: `py -3.11 tools/trailer/pos.py --teste 8,20,44,...` → `raw/trailer/pos_teste/`. Vídeo: `py -3.11 tools/trailer/pos.py --tudo`.

## Fontes e licenças dos insumos externos
- Modelos 3D, personagens, zumbis, armas, sons do jogo: assets do projeto (ver `docs/ASSET_CREDITS.md`).
- Animações: Mixamo (conta do usuário). Narração: Microsoft Edge TTS (serviço online gratuito). Modelo de profundidade: Depth Anything V2 Small (Apache-2.0).
- Sons de zumbi/motor: OpenGameArt CC0 (ianzazz, Ogrebane, domasx2) — ver `tools/prep_audio_net.py`.
- Música: sintetizada aqui, sem samples.

## Problemas conhecidos / ideias
- A base do time-lapse é a peça de construção do jogo (caixa laranja); poderia ter telhado/detalhes.
- 1 quadro de transição em alguns cortes mostra o mundo novo com a câmera anterior (invisível a 30 fps).
- Voz do narrador pode ser trocada em `narracao.py` e regerada em segundos.
