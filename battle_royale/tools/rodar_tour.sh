#!/bin/bash
# uso: tools/rodar_tour.sh pasta_saida vistas(,) [perf]
G="/c/Users/satoshi/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
cd "$(dirname "$0")/../game"
"$G" --path . res://tests/ilha_tour.tscn -- --out="../raw/$1" ${2:+$( [ "$2" != all ] && echo --only="$2")} ${3:+--perf} 2>&1 | grep -E "PERF|VIEW|ERROR|SCRIPT" | head -400
