# DAYONE

Jogo de sobrevivência low poly em mundo aberto (ilha litorânea), com zumbis, armas realistas, inventário, construção, carros e clima. Feito em **Godot 4.7.1** (renderer Compatibility), pensado para PCs fracos (i7-3770 + GT 730, meta 60 FPS em 1024×768).

> **Outra IA ou dev continuando o projeto?** Leia primeiro [`AGENTS.md`](AGENTS.md) e depois [`battle_royale/docs/HANDOFF_PROXIMOS_PASSOS.md`](battle_royale/docs/HANDOFF_PROXIMOS_PASSOS.md).

## Rodar
1. Instale o Godot 4.7.1 (`winget install GodotEngine.GodotEngine`) e abra `battle_royale/game/project.godot` (ou use `battle_royale/JOGAR.cmd` no Windows).
2. Ao abrir, toca a **cutscene de abertura** (trailer); qualquer tecla/clique pula para o menu. Os shaders são aquecidos em segundo plano durante o vídeo.

## Estrutura
| Pasta | O que tem |
|---|---|
| `battle_royale/game/` | Projeto Godot (código em `core/`, `ui/`, `maps/`, `autoload/`, `cinematic/`, testes em `tests/`) |
| `battle_royale/docs/` | Documentação, backlog, handoff, lore, estudos e QA |
| `battle_royale/tools/` | Ferramentas Python/Blender (bake do mapa, trailer, áudio, pós-processamento) |
| `battle_royale/Assets/` | Fontes de assets (modelos, animações Mixamo, sons, referências). Índice em `Assets/LEIA-ME.md` |
| `catcine/` | Trailer final em MP4 (Git LFS) |
| `legado/` | Protótipos e arquivos antigos (carro Voyage no Blender, scripts de ponte) |

## Licenças de terceiros
Os assets de terceiros (Fab, Mixamo, OpenGameArt, bibliotecas de som) mantêm as licenças originais; veja `battle_royale/docs/ASSET_CREDITS.md`. Verifique se a redistribuição é permitida antes de tornar o repositório público.
