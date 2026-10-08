"""Pós-produção OFFLINE do trailer DAYONE (nenhum custo de GPU no jogo): AVI cru do Godot -> MP4 1920x1080 com cor de cinema.
Técnicas (todas em CPU):
  * Depth Anything V2 Small (ONNX, IA) -> mapa de profundidade por tomada (a cada 10 quadros, interpolado) usado para
    - desfoque de campo (DoF) com 3 níveis de desfoque misturados pelo círculo de confusão,
    - névoa atmosférica por distância (contra-luz e profundidade que o renderizador Compatibility não faz);
  * grading por ato (curva em S, saturação, tons frios nas sombras/quentes nas luzes), bloom por limiar, vinheta, aberração
    cromática radial, grão de filme por quadro, tremor de câmera/gate weave, flashes de corte, fades, faixas 2,39:1;
  * cartões de título (DAY ONE, logo DAYONE), mux com mix.wav (tools/trailer/mix.py) em H.264 + AAC.
Uso:  py -3.11 tools/trailer/pos.py --teste 8,20,44,64,86,106      -> PNGs em raw/trailer/pos_teste/ (conferir antes)
      py -3.11 tools/trailer/pos.py --tudo [--saida caminho.mp4]    -> vídeo final
"""
import os, re, sys, time, json
import numpy as np
import cv2
import av
import onnxruntime as ort
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RT = os.path.join(ROOT, "raw", "trailer")
W, H = 1280, 720
OW, OH = 1920, 1080
FPS = 30
T0, FIM = 6.0, 110.0
CORTES = [6, 14, 22, 30, 32, 34, 36, 38, 40, 46, 48.6, 51, 52.6, 56, 58.2, 59.5, 60, 62.8, 65.4, 68, 78, 84, 87, 89.6, 92, 96.4, 100, 110]
DEPTH_PASSO = 10
SAIDA_PADRAO = r"C:\Users\satoshi\Documents\ChatGPT\teste\teste GPT\catcine\DAYONE_trailer.mp4"

cv2.setNumThreads(4)


# ------------------------------------------------------------------ grading por trecho
def grade(T):
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


def flash_cortes(T):
    """brilho de queima de filme nos cortes rápidos da montagem e em momentos de impacto"""
    f = 0.0
    for tc in (32.0, 34.0, 36.0, 38.0, 80.6, 83.2, 86.4, 89.6, 92.0):
        d = T - tc
        if 0 <= d < 0.14:
            f = max(f, 0.45 * (1 - d / 0.14))
    return f


def fade_preto(T):
    """1 = preto total. fade in no início do filme, mergulho no silêncio de 59,7–60,35, fade antes do logo"""
    f = 0.0
    if T < 6.8:
        f = 1.0
    if T < 8.4:
        f = max(f, 1.0 - (T - 6.8) / 1.6) if T >= 6.8 else 1.0
    if 59.55 <= T < 59.75:
        f = max(f, (T - 59.55) / 0.2)
    if 59.75 <= T < 60.3:
        f = 1.0
    if 60.3 <= T < 60.75:
        f = max(f, 1.0 - (T - 60.3) / 0.45)
    if 109.3 <= T < 110.0:
        f = max(f, (T - 109.3) / 0.7)
    return float(np.clip(f, 0, 1))


# ------------------------------------------------------------------ profundidade (IA)
class Profundidade:
    def __init__(self):
        p = os.path.join(RT, "modelos", "depth_anything_v2_small_q.onnx")
        so = ort.SessionOptions()
        so.intra_op_num_threads = 6
        self.s = ort.InferenceSession(p, so, providers=["CPUExecutionProvider"])
        self.nome = self.s.get_inputs()[0].name
        self.m = np.array([0.485, 0.456, 0.406], np.float32)
        self.d = np.array([0.229, 0.224, 0.225], np.float32)

    def __call__(self, rgb_u8):
        x = cv2.resize(rgb_u8, (448, 252), interpolation=cv2.INTER_AREA).astype(np.float32) / 255.0
        x = ((x - self.m) / self.d).transpose(2, 0, 1)[None]
        o = self.s.run(None, {self.nome: x})[0][0]
        lo, hi = np.percentile(o, 2), np.percentile(o, 98)
        o = np.clip((o - lo) / max(hi - lo, 1e-6), 0, 1)
        return o.astype(np.float32)          # 1 = perto, 0 = longe (disparidade relativa)


# ------------------------------------------------------------------ efeitos
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
RAD = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
VIG = None
LUM = np.array([0.2126, 0.7152, 0.0722], np.float32)


_VIG_CACHE = {}


def vinheta(forca):
    k = round(float(forca) * 20) / 20.0
    if k not in _VIG_CACHE:
        _VIG_CACHE[k] = (1.0 - np.clip((RAD - 0.35) / 1.0, 0, 1) ** 1.8 * k)[:, :, None].astype(np.float32)
    return _VIG_CACHE[k]


def smooth(x):
    return x * x * (3 - 2 * x)


def dof(img, d, foco, quant):
    """3 níveis de desfoque (em meia resolução) misturados pelo círculo de confusão da profundidade (IA)"""
    if quant <= 0.01:
        return img
    hw, hh = W // 2, H // 2
    dh = cv2.resize(d, (hw, hh), interpolation=cv2.INTER_LINEAR)
    coc = np.clip((np.abs(dh - foco) - 0.17) * 2.4 * quant, 0, 0.78)
    coc = cv2.GaussianBlur(coc, (0, 0), 3.0)
    ih = cv2.resize(img, (hw, hh), interpolation=cv2.INTER_AREA)
    b1 = cv2.GaussianBlur(ih, (0, 0), 1.2)
    b2 = cv2.GaussianBlur(ih, (0, 0), 2.8)
    b3 = cv2.GaussianBlur(ih, (0, 0), 5.5)
    nivel = coc * 3.0
    w1 = np.clip(1 - np.abs(nivel - 1), 0, 1)
    w2 = np.clip(1 - np.abs(nivel - 2), 0, 1)
    w3 = np.clip(nivel - 2, 0, 1)
    soma = w1 + w2 + w3 + 1e-4
    mist = (b1 * w1[:, :, None] + b2 * w2[:, :, None] + b3 * w3[:, :, None]) / soma[:, :, None]
    mist = cv2.resize(mist, (W, H), interpolation=cv2.INTER_LINEAR)
    alfa = cv2.resize(np.clip(soma, 0, 1) * np.clip(nivel, 0, 1) ** 0.6, (W, H), interpolation=cv2.INTER_LINEAR)[:, :, None]
    return img * (1 - alfa) + mist * alfa


LUM_M = np.array([[0.2126, 0.7152, 0.0722]], np.float32)


def lumin(x):
    return cv2.transform(x, LUM_M)[:, :, None]


def correcao(img, G):
    x = img * np.float32(G["exp"])
    lum = lumin(x)
    x = lum + (x - lum) * np.float32(G["sat"])
    np.clip(x, 0, 1, out=x)
    c = np.float32(G["con"])
    x = x * (1 - c) + (x * x * (3 - 2 * x)) * c
    lum = lumin(x)
    x += (1 - lum) ** 2 * np.array(G["sh"], np.float32)
    x += (lum * lum) * np.array(G["hi"], np.float32)
    return np.clip(x, 0, 1, out=x)


def bloom(x, forca):
    if forca <= 0.01:
        return x
    p = np.clip((x @ LUM - 0.62) / 0.38, 0, 1)[:, :, None] * x
    p = cv2.resize(p, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    p = cv2.GaussianBlur(p, (0, 0), 5.0)
    p = cv2.resize(p, (W, H), interpolation=cv2.INTER_LINEAR)
    return np.clip(x + p * forca, 0, 1)


def aberracao(x, forca):
    """aberração cromática radial (R e B escalonados em sentidos opostos)"""
    if forca <= 0.01:
        return x
    s = 0.0028 * forca
    out = x.copy()
    for c, esc in ((0, 1 + s), (2, 1 - s)):
        mx = ((xx - W / 2) / esc + W / 2).astype(np.float32)
        my = ((yy - H / 2) / esc + H / 2).astype(np.float32)
        out[:, :, c] = cv2.remap(x[:, :, c], mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    return out


rng = np.random.default_rng(7)


def grao(img_1080, forca=0.03):
    n = rng.standard_normal((OH // 2, OW // 2)).astype(np.float32)
    n = cv2.resize(n, (OW, OH), interpolation=cv2.INTER_LINEAR)
    lum = img_1080.mean(axis=2, keepdims=True)
    peso = 0.55 + 0.9 * (1 - np.abs(lum - 0.5) * 2)
    return img_1080 + n[:, :, None] * (forca * peso)


def fonte(tam, bold=False):
    for nome in ("bahnschrift.ttf", "arialbd.ttf", "arial.ttf"):
        p = os.path.join(r"C:\Windows\Fonts", nome)
        if os.path.exists(p):
            return ImageFont.truetype(p, tam)
    return ImageFont.load_default()


def texto_espacado(draw, xy, txt, fnt, fill, esp):
    x, y = xy
    for ch in txt:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + esp


def largura_espacada(draw, txt, fnt, esp):
    return sum(draw.textlength(ch, font=fnt) + esp for ch in txt) - esp


def cartao(txt, tam, cor, esp, y_rel=0.5, glow=0.0, sub=None, sub_tam=34, sub_cor=(200, 200, 200)):
    im = Image.new("RGBA", (OW, OH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = fonte(tam)
    w = largura_espacada(d, txt, f, esp)
    x = (OW - w) / 2
    y = OH * y_rel - tam * 0.6
    texto_espacado(d, (x, y), txt, f, cor + (255,), esp)
    if sub:
        f2 = fonte(sub_tam)
        w2 = largura_espacada(d, sub, f2, 10)
        texto_espacado(d, ((OW - w2) / 2, y + tam * 1.18), sub, f2, sub_cor + (255,), 10)
    a = np.array(im).astype(np.float32) / 255.0
    if glow > 0:
        g = cv2.GaussianBlur(a[:, :, :3] * a[:, :, 3:4], (0, 0), 22)
        a[:, :, :3] = np.clip(a[:, :, :3] * a[:, :, 3:4] + g * glow, 0, 1)
        a[:, :, 3] = np.clip(a[:, :, 3] + g.max(axis=2) * glow, 0, 1)
    return a


PALAVRAS = [("SCAVENGE", 60.6, 63.4), ("BUILD", 68.6, 71.4), ("FIGHT", 78.2, 81.2), ("DRIVE", 92.4, 95.4)]
_PAL_CACHE = {}


def fonte_bold(tam):
    f = ImageFont.truetype(r"C:\Windows\Fonts\bahnschrift.ttf", tam)
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


def compor(base, cart, alpha):
    if alpha <= 0.001:
        return base
    a = cart[:, :, 3:4] * alpha
    return base * (1 - a) + cart[:, :, :3] * a


# ------------------------------------------------------------------ leitura do AVI e processamento
def ler_inicio():
    log = os.path.join(RT, "render.log")
    txt = open(log, encoding="utf-8", errors="ignore").read()
    m = re.search(r"TRAILER_INICIO frame=(\d+)", txt)
    return int(m.group(1)) if m else 0


def frames_do_avi(ini):
    c = av.open(os.path.join(RT, "bruto.avi"))
    v = c.streams.video[0]
    v.thread_type = "AUTO"
    n = 0
    for fr in c.decode(v):
        if n >= ini:
            yield fr.to_ndarray(format="rgb24")
        n += 1
    c.close()


def tempo_global(i):
    return T0 + i / FPS


def segmento(T):
    k = 0
    for j, c in enumerate(CORTES):
        if T >= c - 1e-6:
            k = j
    return k


def processa_quadro(rgb, T, d_small, foco_estado, prev_seg, G, cartoes, seg):
    img = rgb.astype(np.float32) / 255.0
    # desfoque do POV (acordando) e DoF por profundidade
    if "blur_global" in G and G["blur_global"] > 0.3:
        img = cv2.GaussianBlur(img, (0, 0), G["blur_global"])
    d = cv2.resize(d_small, (W, H), interpolation=cv2.INTER_LINEAR)
    cx = d[int(H * 0.30):int(H * 0.64), int(W * 0.42):int(W * 0.58)]
    alvo_foco = float(np.percentile(cx, 55))
    foco = alvo_foco if prev_seg != seg or foco_estado[0] is None else 0.9 * foco_estado[0] + 0.1 * alvo_foco
    foco_estado[0] = foco
    img = dof(img, d, foco, G["dof"])
    if G["haze"] > 0:
        far = (1.0 - d) ** 1.6
        a = (far * G["haze"])[:, :, None]
        img = img * (1 - a) + np.array(G["haze_cor"], np.float32) * a
    img = correcao(img, G)
    img = bloom(img, G["bloom"])
    v = vinheta(G["vig"] * (1.0 + 0.12 * np.sin(T * 5.0) if T < 22 else 1.0))
    img = img * v
    img = aberracao(img, G["ca"])
    out = cv2.resize(img, (OW, OH), interpolation=cv2.INTER_LANCZOS4)
    # gate weave + brilho do projetor
    dx, dy = float(np.sin(T * 9.1) * 0.7), float(np.sin(T * 7.3 + 1) * 0.6)
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    out = cv2.warpAffine(out, M, (OW, OH), borderMode=cv2.BORDER_REPLICATE)
    out = out * (1.0 + 0.012 * np.sin(T * 41.0) + 0.006 * rng.standard_normal())
    out = cv2.addWeighted(out, 1.28, cv2.GaussianBlur(out, (0, 0), 1.2), -0.28, 0)   # nitidez após o redimensionamento
    out = grao(out, 0.011)
    fl = flash_cortes(T)
    if fl > 0:
        out = out + fl * np.array([1.0, 0.92, 0.78], np.float32)
    return np.clip(out, 0, 1)


def moldura(out):
    barra = int(round((OH - OW / 2.39) / 2))
    out[:barra] = 0
    out[OH - barra:] = 0
    return out


def construir_cartoes():
    return dict(
        dayone=cartao("DAY ONE", 74, (235, 235, 235), 22, 0.5),
        logo=cartao("DAYONE", 210, (242, 194, 0), 26, 0.47, glow=0.7, sub="SURVIVE THE FIRST DAY", sub_tam=40, sub_cor=(225, 225, 225)),
        coro=cartao("COROV-27  ·  COMING SOON", 38, (150, 150, 150), 9, 0.78),
    )


def quadro_cartao(T, cartoes):
    """quadros fora do filme do Godot: 0–6 s (preto + DAY ONE) e 110–120 s (logo)"""
    base = np.zeros((OH, OW, 3), np.float32)
    if T < T0:
        a = np.clip((T - 2.2) / 0.8, 0, 1) * np.clip((T0 - 0.2 - T) / 0.5, 0, 1) if T < T0 - 0.2 else 0.0
        base = compor(base, cartoes["dayone"], a)
        base = grao(base + 0.02, 0.02)
    else:
        u = T - FIM
        base = base + 0.02
        # logo entra com impacto (110.0) e estabiliza; "COMING SOON" depois
        a = np.clip(u / 0.12, 0, 1) * np.clip((9.4 - u) / 1.2, 0, 1)
        escala = 1.0 + 0.045 * np.exp(-u * 2.2)
        c = cartoes["logo"]
        if escala > 1.001:
            M = cv2.getRotationMatrix2D((OW / 2, OH * 0.47), 0, escala)
            c = cv2.warpAffine(c, M, (OW, OH))
        base = compor(base, c, a)
        base = compor(base, cartoes["coro"], np.clip((u - 3.2) / 0.8, 0, 1) * np.clip((9.4 - u) / 1.2, 0, 1))
        flash = np.exp(-u * 14.0) * 0.8 if u >= 0 else 0.0
        base = base + flash
        base = grao(base, 0.03)
    return np.clip(base, 0, 1)


def decodifica(ini, limite_n=None):
    """gera (i, T, rgb) do filme do Godot (6–110 s), em fluxo (sem guardar tudo na memória)"""
    c = av.open(os.path.join(RT, "bruto.avi"))
    v = c.streams.video[0]
    v.thread_type = "AUTO"
    for k, fr in enumerate(c.decode(v)):
        if k < ini:
            continue
        i = k - ini
        T = tempo_global(i)
        if T >= FIM + 0.001 or (limite_n is not None and i >= limite_n):
            break
        yield i, T, fr.to_ndarray(format="rgb24")
    c.close()


def main():
    teste = None
    if "--teste" in sys.argv:
        teste = [float(x) for x in sys.argv[sys.argv.index("--teste") + 1].split(",")]
    saida = SAIDA_PADRAO
    if "--saida" in sys.argv:
        saida = sys.argv[sys.argv.index("--saida") + 1]
    limite = None
    if "--max" in sys.argv:
        limite = int(sys.argv[sys.argv.index("--max") + 1])
    ini = ler_inicio()
    prof = Profundidade()
    cartoes = construir_cartoes()
    print("início do filme no quadro", ini)
    if teste is not None:
        d = os.path.join(RT, "pos_teste")
        os.makedirs(d, exist_ok=True)
        for i, T, rgb in decodifica(ini):
            if any(abs(T - t) < 0.5 / FPS for t in teste):
                seg = segmento(T)
                out = processa_quadro(rgb, T, prof(rgb), [None], -1, grade(T), cartoes, seg)
                out = aplica_texto(out, T)
                out = moldura(out)
                cv2.imwrite(os.path.join(d, "t%06.2f.png" % T), (out[:, :, ::-1] * 255).astype(np.uint8))
        print("ok ->", d)
        return
    import bisect
    import soundfile as sf
    # ------------------------------------------------ passo 1: profundidade (IA) nas chaves de cada tomada
    t_ini = time.time()
    chaves = {}          # seg -> {i: mapa}
    cont = {}
    ant = None
    for i, T, rgb in decodifica(ini, limite):
        seg = segmento(T)
        if ant is not None and ant[0] != seg:
            chaves.setdefault(ant[0], {})[ant[1]] = prof(ant[2])      # último quadro da tomada anterior
        j = cont.get(seg, 0)
        if j % DEPTH_PASSO == 0:
            chaves.setdefault(seg, {})[i] = prof(rgb)
        cont[seg] = j + 1
        ant = (seg, i, rgb)
        if i % 300 == 0:
            print("  profundidade: quadro", i, "T=%.1f" % T, flush=True)
    if ant is not None:
        chaves.setdefault(ant[0], {})[ant[1]] = prof(ant[2])
    listas = {s_: sorted(d_.keys()) for s_, d_ in chaves.items()}
    print("profundidade pronta em %.0f s (%d mapas)" % (time.time() - t_ini, sum(len(v_) for v_ in listas.values())), flush=True)

    def mapa(i, seg):
        ks = listas[seg]
        p = bisect.bisect_right(ks, i)
        if p == 0:
            return chaves[seg][ks[0]]
        if p >= len(ks):
            return chaves[seg][ks[-1]]
        a, b = ks[p - 1], ks[p]
        u = (i - a) / max(b - a, 1)
        return chaves[seg][a] * (1 - u) + chaves[seg][b] * u

    # ------------------------------------------------ passo 2: imagem + codificação
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    out_c = av.open(saida, "w")
    sv = out_c.add_stream("libx264", rate=FPS)
    sv.width, sv.height, sv.pix_fmt = OW, OH, "yuv420p"
    sv.options = {"crf": "17", "preset": "medium"}
    sa = out_c.add_stream("aac", rate=48000)
    sa.layout = "stereo"
    audio, sr = sf.read(os.path.join(RT, "mix.wav"), dtype="float32")

    def escreve(arr_u8):
        fr = av.VideoFrame.from_ndarray(arr_u8, format="rgb24")
        for p in sv.encode(fr):
            out_c.mux(p)

    total = 0
    if limite is None:
        for i in range(int(T0 * FPS)):
            escreve((moldura(quadro_cartao(i / FPS, cartoes)) * 255).astype(np.uint8))
            total += 1
    foco_estado = [None]
    prev_seg = -1
    t_ini = time.time()
    for i, T, rgb in decodifica(ini, limite):
        seg = segmento(T)
        out = processa_quadro(rgb, T, mapa(i, seg), foco_estado, prev_seg, grade(T), cartoes, seg)
        prev_seg = seg
        fp = fade_preto(T)
        if fp > 0:
            out = out * (1 - fp)
        out = aplica_texto(out, T)
        out = moldura(out)
        escreve((np.clip(out, 0, 1) * 255).astype(np.uint8))
        total += 1
        if i % 100 == 0:
            dt = time.time() - t_ini
            print("  quadro %d (T=%.1f s)  %.2f s/quadro" % (i, T, dt / (i + 1)), flush=True)
    if limite is None:
        for i in range(int(FPS * (120.0 - FIM))):
            escreve((moldura(quadro_cartao(FIM + i / FPS, cartoes)) * 255).astype(np.uint8))
            total += 1
    for p in sv.encode():
        out_c.mux(p)
    # áudio (recorta para a duração do vídeo)
    n_a = int(total / FPS * sr)
    if limite is not None:
        audio = audio[int(T0 * sr):int(T0 * sr) + n_a]
    blk = 1024
    for k in range(0, min(audio.shape[0], n_a), blk):
        seg_a = np.ascontiguousarray(audio[k:k + blk].T)
        fa = av.AudioFrame.from_ndarray(seg_a, format="fltp", layout="stereo")
        fa.sample_rate = sr
        fa.pts = k
        for p in sa.encode(fa):
            out_c.mux(p)
    for p in sa.encode():
        out_c.mux(p)
    out_c.close()
    print("PRONTO:", saida, "quadros:", total, flush=True)


if __name__ == "__main__":
    main()
