"""Desenha a silhueta lateral (z, y em cm) da arma + mira a partir de raw/holo_offset/<arma>_tris.json (tests/holo_offset).
Cinza = arma, vermelho = mira, azul = eixo do cano, verde = linha de visada (ponto). Uso: python tools/perfil_mira.py ak47 [m4 ...]"""
import json, sys, os
from PIL import Image, ImageDraw
D = os.path.join(os.path.dirname(__file__), "..", "raw", "holo_offset")
for arma in sys.argv[1:]:
    j = json.load(open(os.path.join(D, arma + "_tris.json")))
    pz = j["ponto"][0]
    PX = 14
    z0, z1 = pz - 22, pz + 22   # janela de 44 cm em volta da mira
    ys = [t[i] for t in j["arma"] + j["mira"] for i in (1, 4, 7)]
    y0, y1 = j["cano"][1] - 8, j["ponto"][1] + 8
    W, H = int((z1 - z0) * PX), int((y1 - y0) * PX)
    im = Image.new("RGB", (W, H), (242, 242, 242))
    d = ImageDraw.Draw(im)
    f = lambda z, y: ((z - z0) * PX, H - (y - y0) * PX)
    for cor, chave in (((90, 90, 90), "arma"), ((210, 30, 30), "mira")):
        for t in j[chave]:
            d.polygon([f(t[0], t[1]), f(t[3], t[4]), f(t[6], t[7])], fill=cor)
    d.line([f(z0, j["cano"][1]), f(z1, j["cano"][1])], fill=(30, 90, 230), width=2)
    d.line([f(z0, j["ponto"][1]), f(z1, j["ponto"][1])], fill=(30, 170, 60), width=2)
    for c in range(int(z0), int(z1) + 1):   # régua de 1 cm
        x, _ = f(c, y0)
        d.line([(x, H - 1), (x, H - (12 if c % 5 == 0 else 5))], fill=(0, 0, 0))
    d.text((6, 6), f"{arma}: cinza arma, vermelho mira, azul eixo do cano, verde ponto. 1 traco = 1 cm", fill=(0, 0, 0))
    im.save(os.path.join(D, arma + "_perfil.png"))
    print("ok", arma, W, H)
