"""Folha de contato: junta todos os PNGs de uma pasta numa grade (com o nome de cada um) -> <pasta>/folha.jpg."""
import sys, glob, os
from PIL import Image, ImageDraw
pasta = sys.argv[1]
fs = sorted(glob.glob(os.path.join(pasta, "*.png")))
if not fs:
    print("FOLHA sem PNGs em", pasta); sys.exit(0)
W, H, COL = 480, 270, 3
lin = (len(fs) + COL - 1) // COL
im = Image.new("RGB", (W * COL, (H + 18) * lin), (20, 20, 20))
d = ImageDraw.Draw(im)
for i, f in enumerate(fs):
    x, y = (i % COL) * W, (i // COL) * (H + 18)
    im.paste(Image.open(f).convert("RGB").resize((W, H)), (x, y + 18))
    d.text((x + 4, y + 3), os.path.basename(f)[:70], fill=(240, 220, 120))
im.save(os.path.join(pasta, "folha.jpg"), quality=80)
print("FOLHA", os.path.join(pasta, "folha.jpg"), len(fs), "imagens")
