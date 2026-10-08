"""Folha de contato do AVI cru: um quadro a cada 1,5 s do filme do Godot (6–110 s), com o tempo global."""
import av, sys, os
from PIL import Image, ImageDraw
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RT = os.path.join(ROOT, "raw", "trailer")
import re
ini = int(re.search(r"TRAILER_INICIO frame=(\d+)", open(os.path.join(RT, "render.log"), encoding="utf-8", errors="ignore").read()).group(1))
passo = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
t_a = float(sys.argv[2]) if len(sys.argv) > 2 else 6.0
t_b = float(sys.argv[3]) if len(sys.argv) > 3 else 110.0
alvos = {}
t = t_a
while t < t_b:
    alvos[ini + int(round((t - 6.0) * 30))] = t
    t += passo
c = av.open(os.path.join(RT, "bruto.avi"))
v = c.streams.video[0]
imgs = []
for k, fr in enumerate(c.decode(v)):
    if k in alvos:
        im = fr.to_image().resize((384, 216))
        ImageDraw.Draw(im).text((6, 4), "%.1f" % alvos[k], fill=(255, 255, 0))
        imgs.append(im)
c.close()
cols = 5
por = 25
for p in range(0, len(imgs), por):
    bloco = imgs[p:p + por]
    rows = (len(bloco) + cols - 1) // cols
    sh = Image.new("RGB", (384 * cols, 216 * rows))
    for k, im in enumerate(bloco):
        sh.paste(im, ((k % cols) * 384, (k // cols) * 216))
    sh.save(os.path.join(RT, "bruto_folha_%d.png" % (p // por)))
print(len(imgs), "quadros")
