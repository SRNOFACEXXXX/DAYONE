# AGENTS.md — leia isto primeiro (instruções para qualquer IA que continue o DAYONE)

Responda sempre em **português do Brasil**. Este arquivo é o ponto de entrada; o resto está em `battle_royale/docs/`.

## O que é o jogo
**DAYONE** — jogo de sobrevivência low poly em mundo aberto (ilha litorânea, estilo DayZ/Rust) com zumbis, armas realistas,
inventário, construção de base, carros e clima/dia-noite. Godot **4.7.1**, renderer **Compatibility**, Windows.
PC-alvo fraco: i7-3770 + GeForce GT 730 → meta 60 FPS em 1024×768. Projeto Godot: `battle_royale/game/`.

## Ordem de leitura
1. `battle_royale/docs/HANDOFF_PROXIMOS_PASSOS.md` — **o que fazer daqui para frente** (roadmap de mecânicas).
2. `battle_royale/docs/LORE.md` — história/universo (**precisa crescer**: faz parte do trabalho).
3. `battle_royale/docs/ACERTOS_E_ERROS.md` — o que funcionou e o que deu errado (não repita).
4. `battle_royale/docs/ECONOMIA_DE_TOKENS.md` — como trabalhar rápido e barato (estudo de dev).
5. `battle_royale/docs/ATUALIZACAO_DAYONE.md` — backlog histórico e "Volta 2026-10-07".
6. `battle_royale/docs/TESTE_VISUAL.md` — **como rodar o jogo de verdade e VER (capturas) antes de dizer "feito"**. Obrigatório.
7. `battle_royale/docs/HANDOFF_PROMPT.md`, `NOITE_PLANO.md`, `SOBREVIVENCIA_PLANO.md` — contexto antigo (BR → sobrevivência).

## Regras do dono (obrigatórias)
- **Nunca faça perguntas** ao dono: decida com bom senso e siga trabalhando.
- **Código "revisado à mão" que quebra o jogo é o erro nº 1 (carro que não virava, barraca de 474 m).** Rode o Godot (há build Linux em `/tmp/godot_dl` quando existir; senão baixe o 4.7.1 de github.com/godotengine/godot-builds) e abra a folha de contato (`tools/visual/ver.sh`).
- **Testar o jogo REAL** (partida `BRMatch` com `Soldier`/inputs reais), olhar capturas PNG e medir. Só diga "resolvido" com medição + captura.
- Rodar o Godot **um processo por vez** (processos órfãos travam tudo e deixam a janela cinza).
- No máximo **1 subagente de apoio**; nunca modelos baratos para tarefas visuais/de física; nada de enxame de agentes.
- Conteúdo do mapa é **autoral** (JSON à mão), não procedural. Luz simples em tempo real, sem bake pesado.
- Visual: low poly estilizado, **sem HUD feio, sem animações feias** (use Mixamo/GLB retargeted; sem mãos procedurais).
- Cada correção ganha um teste em `battle_royale/game/tests/` e uma linha em `docs/ATUALIZACAO_DAYONE.md`.
- Jogador/QA devem conseguir jogar: **mantenha sempre uma build jogável com menu** (`JOGAR.cmd`).

## Comandos
```bash
# Jogo (um processo; abre menu → intro/cutscene → menu)
battle_royale/JOGAR.cmd
# Godot console
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe" --path battle_royale/game res://tests/<teste>.tscn
# Após criar class_name novo, registrar:  Godot --headless --editor --quit --path battle_royale/game
# Blender 4.5 (assets por script):  teste/.tools/blender45/blender-4.5.13-windows-x64/blender.exe -b --factory-startup -P tools/x.py
```
Regressão antes de encerrar uma volta: `troca_armas`, `inventario_real`, `zumbi_dano`, `som_real`, `spawn_costa`.

## Mapa do código (`battle_royale/game/`)
- `autoload/`: `game.gd` (config/modo teste), `loading.gd` (aquecimento de shaders + pré-montagem), `audio.gd`, `settings.gd`, `weapon_db.gd`, `rastreio.gd` (depuração de recursos em memória, **F9** grava relatório).
- `core/`: `soldier.gd`, `player_controller.gd`, `viewmodel.gd`, `body_model.gd`, `zombie.gd` + `zombie_director.gd`, `br_match.gd` (partida), `br_inventory.gd`, `construction_system.gd`, `drivable_vehicle.gd`, `clima.gd`, `casa_pacote.gd`.
- `maps/ilha/`: terreno (`height.bin`), vegetação, detalhes, casas, água (autoral, JSON em `docs/design/`).
- `ui/`: menu, criador de personagem, inventário, HUD, **`intro.tscn` (cena inicial: cutscene → menu)**.
- `cinematic/`: trailer de 2 min (`trailer.gd`), retarget Mixamo (`mx_retarget.gd`); ferramentas em `tools/trailer/`.
- `tests/`: ~200 testes (`*.tscn` + `*.gd`) que jogam o jogo de verdade.
