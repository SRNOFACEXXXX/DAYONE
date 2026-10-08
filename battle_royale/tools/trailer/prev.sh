#!/bin/bash
# uso: tools/trailer/prev.sh <shot> <t1,t2,...>   -> raw/trailer/prev/q_<shot>_*.png e folha prev_<shot>.png
G="/c/Users/satoshi/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
cd "$(dirname "$0")/../../game"
rm -f ../raw/trailer/prev/q_$1_*.png
timeout 280 "$G" --path . res://cinematic/trailer.tscn --resolution 1280x720 -- --shot=$1 --quadros=$2 2>&1 | grep -E "TRAILER|SCRIPT|Parse|Invalid|WARNING: prop|Null|TIRO|CARRO|DBG"
cd ..
python - "$1" <<'P'
import sys,glob
from PIL import Image
n=sys.argv[1]
fs=sorted(glob.glob(f"raw/trailer/prev/q_{n}_*.png"))
W,H=640,360
cols=2; rows=(len(fs)+1)//2
sh=Image.new("RGB",(W*cols,H*max(rows,1)))
for k,f in enumerate(fs):
    sh.paste(Image.open(f).convert("RGB").resize((W,H)),((k%cols)*W,(k//cols)*H))
sh.save(f"raw/trailer/prev_{n}.png"); print(len(fs),"quadros")
P
