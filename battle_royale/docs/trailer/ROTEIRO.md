# DAYONE — Trailer de 2 minutos: "O PRIMEIRO DIA"

**Logline:** No dia 1 do patógeno COROV-27, que contaminou 90% da população mundial, um pescador acorda numa praia depois de cair do próprio barco. Ao chegar ao continente encontra o fim do mundo — e precisa coletar, construir, caçar e matar mortos-vivos para ver o dia 2.

**Tom:** suspense, atmosfera pesada, western sombrio (Americana noir). Poucas palavras, silêncio como arma. Narrador em inglês, voz grave e cansada. Rádio de emergência em fragmentos (voz processada).

**Formato:** 1920x1080 (renderizado em 1280x720 no jogo e reescalonado), 30 fps, 2,39:1 (faixas de cinema), 120 s. Pós-processamento todo OFFLINE (zero custo de GPU no jogo).

## Enredo em quatro atos

### ATO I — O MAR (0:00 – 0:30)
Escuro. Ondas, vento, estática de rádio. A voz de uma locutora entrecortada: a contenção falhou.
- **0:00–0:06** Preto. Rádio: "…all stations… the containment lines have failed… repeat, the containment…". Cartão pequeno: *DAY ONE*.
- **0:06–0:14** Madrugada na praia, névoa, o barco de pesca encalhado, espuma. Câmera baixa, avanço lento. Narrador: *"They say the sea always gives back what it takes."*
- **0:14–0:22** POV: ele abre os olhos (borrão que foca), areia, céu, respiração. Levanta-se. Rádio de novo: *"COROV-27 is now confirmed on every continent. Ninety percent of the global population… stay indoors. Do not—"* (corta).
- **0:22–0:30** Costas dele subindo a duna; a câmera sobe (grua) e revela a cidade ao fundo com colunas de fumaça. Narrador: *"I wish it hadn't."*

### ATO II — O MUNDO DEPOIS (0:30 – 1:00)
- **0:30–0:40** Montagem rápida (1–2 s cada): carros abandonados na estrada, caminhão tombado, barricadas, manchas de sangue, luz piscando, silhuetas de zumbis na névoa. Narrador: *"COROV-27. Ninety percent of the world… gone. Or worse."* Riser de tensão.
- **0:40–0:52** Entardecer. Ele caminha pela estrada de terra rumo à ponte da Vila; ao fundo, um zumbi parado no meio da rua (lente longa). Close dos olhos. Ele se agacha. O coração bate.
- **0:52–1:00** Ele entra numa casa; a porta se fecha; pela janela o zumbi passa arrastando-se. Narrador: *"Out here… silence is the only weapon."* Corte seco para preto + 0,5 s de silêncio.

### ATO III — SOBREVIVER (1:00 – 1:40)
Muda a música: o violão fica seco e rítmico (boom-chick), entram percussão e baixo.
- **1:00–1:08** Dentro da casa: revirando gavetas, atadura, munição, mochila. Narrador: *"Scavenge."*
- **1:08–1:18** Base: fundação, paredes, telhado e baú aparecem em sequência (time-lapse); o céu faz dia → noite → dia. Narrador: *"Build."*
- **1:18–1:24** Campo ao pôr do sol: ele arma um arco rústico e mira num cervo. Narrador: *"Hunt."*
- **1:24–1:40** Noite: tiros, fogos do cano, zumbis em enxame, headshots, sangue; carro atravessando a rua com a horda atrás. Narrador (1:30): *"And when the dead come knocking…"* (1:36) *"…answer."*

### ATO IV — O PRIMEIRO DIA (1:40 – 2:00)
- **1:40–1:50** Amanhecer. Ele sentado no telhado da base olhando a cidade em ruínas; fumaça, silêncio. Narrador: *"Day one… is only the beginning."*
- **1:50–2:00** Preto. Impacto. Logo **DAYONE** em dourado, subtítulo **SURVIVE THE FIRST DAY**, "COROV-27 · COMING SOON". Último acorde do violão que se desfaz.

## Texto da narração (inglês, voz masculina grave)
| Tempo | Linha |
|---|---|
| 0:08 | They say the sea always gives back what it takes. |
| 0:25 | I wish it hadn't. |
| 0:34 | COROV-27. Ninety percent of the world… gone. Or worse. |
| 0:55 | Out here… silence is the only weapon. |
| 1:01 | Scavenge. |
| 1:09 | Build. |
| 1:18 | Hunt. |
| 1:30 | And when the dead come knocking… |
| 1:36 | …answer. |
| 1:42 | Day one… is only the beginning. |

Rádio (voz feminina filtrada, banda 400–3400 Hz, estática): 0:02 e 0:16 (ver acima).

## Direção de som (sonorização)
- **Música original sintetizada** (Americana sombria, Lá menor): violão dedilhado (Karplus-Strong), slide/steel guitar com vibrato e reverb longo, contrabaixo, drone grave; ato III com ritmo "boom-chick" mais rápido, bumbo de pé (stomp) e caixa de vassourinha; final solo.
- **Camadas de trailer:** risers (ruído filtrado subindo), impactos graves (braam) nos cortes principais, whooshes, batimento cardíaco (ato II), zumbido de ouvido após o primeiro susto, silêncio de 0,5 s antes do ato III e antes do logo, *sidechain* (a música abaixa sob a narração).
- **Foley do próprio jogo** (gravado junto do vídeo pelo Godot): passos, porta, grunhidos de zumbi, tiros, motor do carro, vento/ondas/grilos (grilos bem baixos).
- **Voz:** narrador via `edge-tts` (neural, gratuito), compressão leve, reverb curto e cauda de delay; locutora do rádio com passa-banda, distorção e estática.

## Direção de imagem e pós-processamento (offline, gratuito, leve)
- **Câmera:** lente longa para revelações, close extremo para medo, plano baixo para ameaça, grua para escala; leve tremor de mão; 2,39:1.
- **Profundidade com IA:** estimador de profundidade *Depth Anything V2 Small* (ONNX, CPU) → **desfoque de campo (DoF)** real, névoa atmosférica por distância e brilho de contraluz — o que o renderizador Compatibility do jogo não faz.
- **Movimento:** *motion blur* por fluxo óptico (OpenCV) em vez de renderizar 2x os quadros.
- **Cor:** curva em S, tons frios nas sombras e quentes nas luzes (teal & orange sutil), dessaturação por ato (vermelho só no sangue), bloom por limiar, vinheta, grão de filme (variável por quadro), aberração cromática leve nas bordas, queima de filme nos cortes de ação.
- **Pode ser feito sem GPU:** tudo roda em CPU depois da renderização (o jogo só renderiza 1280x720 uma vez).
