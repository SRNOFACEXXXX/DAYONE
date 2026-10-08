#!/usr/bin/env bash
# Teste VISUAL para agentes (Linux/container): roda uma cena de teste do jogo real com tela virtual, junta as capturas numa
# folha de contato e salva o log. Um Godot por vez (flock), como manda o AGENTS.md.
#   tools/visual/ver.sh <cena_de_teste> [nome_da_saida] [-- args do teste]
#   ex.: tools/visual/ver.sh tests/hud_visual.tscn hud
#        tools/visual/ver.sh tests/cenario_vistas.tscn cenario -- --only=09_fazenda
# Saída: /tmp/visual/<nome>/  (PNGs, folha.jpg, log.txt). Depois o agente ABRE folha.jpg (ferramenta Read) e olha.
set -u
CENA="$1"; NOME="${2:-$(basename "$CENA" .tscn)}"; shift; [ $# -gt 0 ] && shift
[ "${1:-}" = "--" ] && shift
GODOT="${GODOT:-/tmp/godot_dl/bin/Godot_v4.7.1-stable_linux.x86_64}"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="/tmp/visual/$NOME"
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$RAIZ/game"
flock /tmp/godot_dl/lock timeout "${TEMPO:-1500}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" ${DEBUG_COL:+--debug-collisions} --path . "res://${CENA#res://}" -- --out="$OUT" "$@" > "$OUT/log.txt" 2>&1
echo "saida=$?" >> "$OUT/log.txt"
python3 "$RAIZ/tools/visual/folha.py" "$OUT" || true
grep -E "SCRIPT ERROR|Parse Error|FAIL|FALHA|_OK|RESULT|PASSOU" "$OUT/log.txt" | head -40
echo "VISUAL pasta=$OUT folha=$OUT/folha.jpg log=$OUT/log.txt"
