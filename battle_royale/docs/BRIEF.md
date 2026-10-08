# BRIEF — Battle Royale (projeto novo, do zero)

Projeto irmão de **Linha de Fogo** (FPS tático, `..\linha_de_fogo`), de onde herdamos o aprendizado: movimento estilo Source,
personagens com IK de pegada (ArmsIK), sangue/gore, HUD. **Começamos do zero**: nada é copiado sem revisão.

## Regras permanentes (do usuário)
- Nunca fazer perguntas ao usuário; decidir e seguir.
- Manter sempre uma build jogável com menu; executar o jogo quando o usuário pedir.
- **Nada procedural**: terreno, vilas e props são autorais (modelados/posicionados à mão no Blender, com dados explícitos). Sem ruído aleatório, sem scatter automático.
- Trabalhar com referências reais (fotos em `reference/`, com fonte).
- Máquina fraca: i7-3770 (4 threads), **GT 730** (só renderer *Compatibility*/OpenGL 3.3), 16 GB, tela 1600×900. Meta: 60 FPS a 1024×768.

## Motor e ferramentas
- **Godot 4.7.1** (Compatibility, Jolt, 64 ticks) — mesmo executável do Linha de Fogo:
  `C:\Users\satoshi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`
- **Blender 4.5**: `C:\Users\satoshi\Documents\ChatGPT\teste\.tools\blender45\blender-4.5.13-windows-x64\blender.exe`
- **Scenario (GameDev OS)**: skills em `.claude/skills/scenario-*`, MCP `https://mcp.scenario.com/mcp` (OAuth na conta do usuário, gasta créditos).
  Uso previsto: texturas PBR tileáveis (`scenario-textures`), skybox 360° (`scenario-skyboxes`), concept art (`scenario-image`),
  props 3D sob demanda (`scenario-3d`, `scenario-meshy`). **Não** usar mundos em Gaussian splat (a GT 730 não renderiza).
  Sempre `dry_run` para preço antes de gerar; cada asset gerado é revisado pela Direção de Arte antes de entrar no jogo.
- Assets low poly do usuário: `C:\Users\satoshi\Desktop\Assets` (casas, militar, armas, apocalipse, vila low poly, kit modular).

## O jogo
- Battle royale em 1ª pessoa, ilha fictícia no litoral brasileiro. Partida de **24 jogadores** (humano + bots), solo.
- Salto de avião → saque no chão → zona que fecha em fases → último vivo vence. Partida ~12–15 min.
- Mapa de **1,2 km × 1,2 km** (tamanho que a GT 730 aguenta com LOD/impostores), com 8–10 pontos de interesse (POIs).

## Pastas
- `game/` projeto Godot · `blender/` .blend fonte · `docs/design/` Equipe de Design · `docs/criteria/` Critérios · `docs/qa/` Testes
- `reference/` fotos de referência (+ `SOURCES.md`) · `tools/` scripts de pipeline · `raw/` capturas e intermediários
- `.claude/skills/` skills da Scenario · `_ref_scenario_skills/` clone de referência do repositório
