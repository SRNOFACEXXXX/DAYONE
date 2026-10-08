"""v3 da pós: look limpo (sem desfoque pesado), grading suave, nitidez, grão leve e TEXTO CINÉTICO (palavras grandes em branco, fonte bold moderna)
sincronizado com a narração: SCAVENGE, BUILD, FIGHT, DRIVE."""
import os, re
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
p = os.path.join(ROOT, "tools", "trailer", "pos.py")
s = open(p, encoding="utf-8").read()

# ---------------------------------------------------------------- grade(T) novo
a = s.index("def grade(T):")
b = s.index("def flash_cortes(T):")
novo_grade = '''def grade(T):
    """parâmetros de imagem (v3: look limpo e nítido; a profundidade da IA só dá névoa leve e foco seletivo nos closes)"""
    G = dict(sat=0.92, con=0.20, exp=1.0, sh=(-0.012, 0.004, 0.028), hi=(0.03, 0.016, -0.004), haze=0.0, haze_cor=(0.66, 0.68, 0.72),
             vig=0.30, dof=0.0, bloom=0.22, ca=0.35)
    if T < 14:    # praia ao amanhecer
        G.update(sat=0.78, con=0.22, sh=(-0.02, 0.006, 0.04), hi=(0.035, 0.02, 0.0), haze=0.10, vig=0.34, bloom=0.3)
    elif T < 22:  # POV acordando: borrão que foca
        u = np.clip((T - 14.0) / 4.8, 0, 1)
        G.update(sat=0.7, con=0.18, exp=0.3 + 0.7 * np.clip((T - 14.0) / 3.0, 0, 1), vig=0.62, bloom=0.4, ca=1.6 - 1.2 * u)
        G["blur_global"] = 10.0 * (1 - u) ** 2
    elif T < 30:  # duna / cidade em fumaça
        G.update(sat=0.86, con=0.22, haze=0.10, haze_cor=(0.7, 0.62, 0.55), vig=0.34)
    elif T < 40:  # montagem do caos
        G.update(sat=0.8, con=0.26, sh=(-0.015, 0.0, 0.03), hi=(0.045, 0.025, -0.006), haze=0.06, vig=0.38, bloom=0.34)
    elif T < 60:  # rua / casa
        close = (46.0 <= T < 48.6) or (51.0 <= T < 52.6)
        G.update(sat=0.9, con=0.24, haze=0.06, vig=0.4 if close else 0.32, dof=0.55 if close else 0.0, bloom=0.3)
    elif T < 68:  # saque dentro da casa
        G.update(sat=1.0, con=0.2, vig=0.3, dof=0.0, bloom=0.25)
    elif T < 78:  # base / time-lapse
        G.update(sat=1.04, con=0.18, vig=0.26, bloom=0.22)
    elif T < 90:  # arsenal (1ª pessoa, mira do jogo)
        G.update(sat=0.95, con=0.26, exp=1.28, sh=(-0.012, 0.0, 0.04), vig=0.34, bloom=0.4, ca=0.5)
    elif T < 100:  # horda / carro / combate noturno
        G.update(sat=0.92, con=0.3, exp=1.3, sh=(-0.014, 0.0, 0.05), hi=(0.05, 0.028, -0.006), vig=0.38, bloom=0.5, ca=0.6)
    else:        # amanhecer no cruzeiro
        G.update(sat=0.78, con=0.22, haze=0.10, haze_cor=(0.72, 0.66, 0.6), vig=0.4, dof=0.0, bloom=0.34)
    return G


'''
s = s[:a] + novo_grade + s[b:]

# ---------------------------------------------------------------- texto cinético
marca = "def compor(base, cart, alpha):"
texto = '''PALAVRAS = [("SCAVENGE", 60.6, 63.4), ("BUILD", 68.6, 71.4), ("FIGHT", 78.2, 81.2), ("DRIVE", 92.4, 95.4)]
_PAL_CACHE = {}


def fonte_bold(tam):
    f = ImageFont.truetype(r"C:\\Windows\\Fonts\\bahnschrift.ttf", tam)
    try:
        f.set_variation_by_name("Bold")
    except Exception:
        pass
    return f


def palavra_rgba(pal, tam=250, esp=14):
    """RGBA (OWxOH) com a palavra inteira; cada letra é desenhada separadamente para a animação por letra"""
    if pal in _PAL_CACHE:
        return _PAL_CACHE[pal]
    f = fonte_bold(tam)
    dummy = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    larg = [dummy.textlength(ch, font=f) for ch in pal]
    total = sum(larg) + esp * (len(pal) - 1)
    x0 = 150
    letras = []
    x = x0
    for ch, w in zip(pal, larg):
        im = Image.new("RGBA", (OW, OH), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.text((x, 560), ch, font=f, fill=(255, 255, 255, 255))
        letras.append(np.array(im).astype(np.float32) / 255.0)
        x += w + esp
    _PAL_CACHE[pal] = (letras, x0, total)
    return _PAL_CACHE[pal]


def ease_out(u):
    u = float(np.clip(u, 0, 1))
    return 1 - (1 - u) ** 3


def aplica_texto(out, T):
    """compõe a palavra do instante T (slide + fade por letra, sombra, linha de destaque)"""
    for pal, t0, t1 in PALAVRAS:
        if not (t0 <= T < t1 + 0.4):
            continue
        letras, x0, total = palavra_rgba(pal)
        u_out = np.clip((T - (t1 - 0.25)) / 0.25, 0, 1)
        acc = np.zeros((OH, OW, 4), np.float32)
        for k, a in enumerate(letras):
            uk = ease_out((T - t0 - 0.045 * k) / 0.32)
            if uk <= 0:
                continue
            dx = int(round((1 - uk) * 90))
            alfa = uk * (1 - u_out)
            if dx:
                a = np.roll(a, -dx, axis=1)
                a[:, OW - dx:, :] = 0
            acc[:, :, :3] = np.maximum(acc[:, :, :3], a[:, :, :3] * a[:, :, 3:4])
            acc[:, :, 3] = np.maximum(acc[:, :, 3], a[:, :, 3] * alfa)
        # sombra suave (legibilidade sobre qualquer cena)
        sombra = cv2.GaussianBlur(acc[:, :, 3], (0, 0), 14)
        sombra = np.roll(np.roll(sombra, 7, axis=0), 7, axis=1) * 0.75
        out = out * (1 - sombra[:, :, None] * 0.7)
        # linha de destaque embaixo da palavra
        uk2 = ease_out((T - t0 - 0.12) / 0.4) * (1 - u_out)
        if uk2 > 0:
            y0 = 560 + 250 + 30
            x1 = int(x0 + total * uk2)
            out[y0:y0 + 9, x0:x1, :] = out[y0:y0 + 9, x0:x1, :] * (1 - uk2 * 0.97) + uk2 * 0.97
        a3 = acc[:, :, 3:4]
        out = out * (1 - a3) + np.clip(acc[:, :, :3] / np.maximum(a3, 1e-4), 0, 1) * a3
    return out


'''
s = s.replace(marca, texto + marca, 1)

# integrar o texto antes das faixas (no loop principal) e nitidez/grão mais leves
s = s.replace("        out = moldura(out)\n        escreve((np.clip(out, 0, 1) * 255).astype(np.uint8))\n        total += 1\n        if i % 100 == 0:",
              "        out = aplica_texto(out, T)\n        out = moldura(out)\n        escreve((np.clip(out, 0, 1) * 255).astype(np.uint8))\n        total += 1\n        if i % 100 == 0:", 1)
s = s.replace("out = cv2.addWeighted(out, 1.32, cv2.GaussianBlur(out, (0, 0), 1.3), -0.32, 0)   # nitidez após o redimensionamento\n    out = grao(out, 0.021)",
              "out = cv2.addWeighted(out, 1.28, cv2.GaussianBlur(out, (0, 0), 1.2), -0.28, 0)   # nitidez após o redimensionamento\n    out = grao(out, 0.011)", 1)
# modo --teste também mostra o texto
s = s.replace("                out = moldura(out)\n                cv2.imwrite(os.path.join(d, \"t%06.2f.png\" % T)",
              "                out = aplica_texto(out, T)\n                out = moldura(out)\n                cv2.imwrite(os.path.join(d, \"t%06.2f.png\" % T)", 1)
# flash só nos cortes de ação mais fortes
s = s.replace("for tc in (32.0, 34.0, 36.0, 38.0, 84.0, 87.0, 89.6, 92.0):", "for tc in (32.0, 34.0, 36.0, 38.0, 80.6, 83.2, 86.4, 89.6, 92.0):")
open(p, "w", encoding="utf-8").write(s)
print("pos v3 ok")
