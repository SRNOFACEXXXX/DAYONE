# Teste visual e medido (para agentes e IAs) — leia antes de dizer "feito"

Lição desta volta: 5 agentes escreveram código "revisado à mão" que passou nos testes e **quebrou o jogo** (carro que não vira,
barraca de 474 m, sons ruins). Teste que não mede o que o jogador sente não vale. Regras:

1. **Rode o jogo real** (partida `BRMatch`, `Soldier`, inputs reais) — não só funções puras.
2. **Meça o efeito, não a intenção.** Ex.: carro → `tests/carro_curva.tscn` mede quantos graus a carroceria GIROU (não só o
   ângulo das rodas). Colisão → `tests/atravessa_real.tscn` faz o soldado ANDAR contra o objeto e mede se passou.
3. **Compare com a versão estável.** Antes de mudar sistema existente, rode o mesmo teste na base
   (`git worktree add /tmp/base <commit>`; copie o teste para lá) e registre os dois números.
4. **Olhe a imagem.** Use o harness visual abaixo e abra a folha de contato. Procure: objetos gigantes/flutuando,
   HUD sobreposta, texturas erradas, coisas atravessando.

## Harness (Linux/container)
```bash
battle_royale/tools/visual/ver.sh tests/<cena>.tscn <nome> [-- args]
# -> /tmp/visual/<nome>/folha.jpg (grade de todas as capturas com nome), log.txt, PNGs
```
Godot: `/tmp/godot_dl/bin/Godot_v4.7.1-stable_linux.x86_64` (baixe o build Linux 4.7.1 de github.com/godotengine/godot-builds).
Primeira vez num clone: `Godot --headless --editor --quit --path battle_royale/game` (importa e registra os class_name).
Sempre **um Godot por vez** (`flock /tmp/godot_dl/lock ...`). Render aqui é por CPU: **FPS daqui não vale** (só compare
draw calls / primitivas, ou meça no PC alvo GT 730).

## Cenas de teste com captura (passe `-- --out=<pasta>`)
| cena | o que mostra |
|---|---|
| `tests/cenario_vistas.tscn` | uma foto por área autoral de `cenario_pontos.json` (`--only=<nome>`) |
| `tests/hud_visual.tscn` | HUD parado, correndo (fôlego) e dirigindo (painel do carro) |
| `tests/carro_dirigindo.tscn` | carro em estrada aberta: acelera, curva, freio de mão, freia (fotos a cada 1 s) |
| `tests/carro_curva.tscn` | sem foto; imprime `CURVA ... giro_graus=` (esq./dir. a 15 e 35 km/h) |
| `tests/atravessa_real.tscn` | sem foto; soldado anda contra ~100 objetos e imprime `ATRAVESSOU` |
| `tests/zumbis_cidade.tscn` | conta zumbis vivos em cada cidade visitada (meta >= 20) |

Para criar uma nova: copie `tests/hud_visual.gd` (carrega a partida, usa Input real e `_shot(nome)`).
