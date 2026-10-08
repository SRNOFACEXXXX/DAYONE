"""Mixagem do trailer (120 s): música + narração + rádio + foley do jogo (áudio gravado pelo Godot) + efeitos de trailer.
Entrada : raw/trailer/musica/musica.wav, raw/trailer/voz/*.mp3, raw/trailer/bruto.avi (áudio do jogo, opcional)
Saída   : raw/trailer/mix.wav (estéreo 48 kHz) — usado por tools/trailer/pos.py para o MP4 final.
Técnicas: voz com EQ+compressão+reverb curto+eco, rádio (passa-banda 350–3200 Hz + saturação + estática), sidechain da música
sob a voz, foley do jogo recortado do AVI, ondas do mar sintetizadas, risers/impactos/whooshes nos cortes, silêncio de 0,5 s
antes do ato III e do logo, tinido após o primeiro tiro, fade final.  Uso: py -3.11 tools/trailer/mix.py [--sem-avi]
"""
import json, os, re, sys
import numpy as np
import soundfile as sf
import av
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RT = os.path.join(ROOT, "raw", "trailer")
SR = 48000
DUR = 120.0
N = int(DUR * SR)
rng = np.random.default_rng(1)


def z():
    return np.zeros((N, 2), np.float32)


def mono_para_estereo(x, pan=0.0):
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    return np.stack([x * l, x * r], 1).astype(np.float32)


def poe(dst, x, t, gain=1.0, pan=0.0):
    """soma x (mono ou estéreo) em dst em t segundos"""
    if x.ndim == 1:
        x = mono_para_estereo(x, pan)
    i = int(t * SR)
    if i < 0:
        x = x[-i:]
        i = 0
    n = min(len(x), N - i)
    if n > 0:
        dst[i:i + n] += x[:n] * gain


def decode(path, canais=2):
    c = av.open(path)
    st = c.streams.audio[0]
    rs = av.AudioResampler(format="fltp", layout="stereo" if canais == 2 else "mono", rate=SR)
    out = []
    for f in c.decode(st):
        for r in rs.resample(f):
            out.append(r.to_ndarray().T)
    for r in rs.resample(None):
        out.append(r.to_ndarray().T)
    c.close()
    x = np.concatenate(out).astype(np.float32)
    return x if canais == 2 else x[:, 0]


def lp(x, fc, o=2):
    b, a = signal.butter(o, fc / (SR / 2), "low"); return signal.lfilter(b, a, x, axis=0)


def hp(x, fc, o=2):
    b, a = signal.butter(o, fc / (SR / 2), "high"); return signal.lfilter(b, a, x, axis=0)


def bp(x, f1, f2, o=2):
    b, a = signal.butter(o, [f1 / (SR / 2), f2 / (SR / 2)], "band"); return signal.lfilter(b, a, x, axis=0)


def peak(x, f0, gain_db, q=1.0):
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    al = np.sin(w0) / (2 * q)
    b = np.array([1 + al * A, -2 * np.cos(w0), 1 - al * A])
    a = np.array([1 + al / A, -2 * np.cos(w0), 1 - al / A])
    return signal.lfilter(b / a[0], a / a[0], x, axis=0)


def ir_reverb(dur, decay, damp, seed=3):
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    tt = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for c in range(2):
        ir[:, c] = lp(r.normal(0, 1, n) * np.exp(-tt * decay), damp, 1)
    ir[:int(0.01 * SR)] *= 0.1
    return (ir / np.sqrt((ir ** 2).sum(0).mean())).astype(np.float32)


def reverb(x, ir, mix):
    if x.ndim == 1:
        x = mono_para_estereo(x)
    wet = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x) + len(ir) - 1] for c in range(2)], 1)
    wet = wet[:len(x) + len(ir) // 2]
    out = np.zeros_like(wet)
    out[:len(x)] += x * (1 - mix * 0.4)
    out += wet.astype(np.float32) * mix
    return out


def compressor(x, thr_db=-22, ratio=3.0, atk=0.01, rel=0.18, makeup_db=6):
    mono = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    env = np.zeros_like(mono)
    a_a = np.exp(-1 / (atk * SR))
    a_r = np.exp(-1 / (rel * SR))
    e = 0.0
    # envelope follower vetorizado em blocos (suficiente para fala)
    blk = 256
    for i in range(0, len(mono), blk):
        seg = mono[i:i + blk]
        m = seg.max()
        e = a_a * e + (1 - a_a) * m if m > e else a_r * e + (1 - a_r) * m
        env[i:i + blk] = e
    db = 20 * np.log10(np.maximum(env, 1e-6))
    gr = np.where(db > thr_db, (db - thr_db) * (1 - 1 / ratio), 0.0)
    g = 10 ** ((-gr + makeup_db) / 20)
    return x * (g[:, None] if x.ndim == 2 else g)


def envelope(x, atk=0.02, rel=0.4):
    m = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    n = len(m)
    out = np.zeros(n, np.float32)
    blk = 480
    e = 0.0
    a_a = np.exp(-blk / (atk * SR))
    a_r = np.exp(-blk / (rel * SR))
    for i in range(0, n, blk):
        v = m[i:i + blk].max()
        e = a_a * e + (1 - a_a) * v if v > e else a_r * e + (1 - a_r) * v
        out[i:i + blk] = e
    return out


# ------------------------------------------------------------------ vozes
IR_CURTO = ir_reverb(1.3, 4.0, 4500)
IR_SALA = ir_reverb(2.2, 2.6, 5200, 5)


def voz_narrador(p):
    x = decode(p, 1)
    x = hp(x, 70)
    x = peak(x, 130, 3.5, 0.9)
    x = peak(x, 3000, 2.0, 1.0)
    x = compressor(x[:, None], -26, 3.2, 0.006, 0.16, 7)[:, 0]
    st = reverb(x, IR_CURTO, 0.16)
    d = int(0.34 * SR)
    eco = np.zeros_like(st)
    eco[d:] = st[:-d] * 0.22
    eco = lp(eco, 3500, 1)
    out = np.zeros((len(st) + d * 2, 2), np.float32)
    out[:len(st)] += st
    out[d:d + len(eco)] += eco[:len(out) - d] if len(eco) > len(out) - d else eco
    return out


def estatica(dur, nivel=0.05):
    n = int(dur * SR)
    r = rng.normal(0, 1, n)
    r = bp(r, 600, 5200)
    tt = np.arange(n) / SR
    r *= (0.6 + 0.4 * np.sin(2 * np.pi * 7.3 * tt + 1.0)) * (rng.random(n) > 0.05)
    return (r * nivel).astype(np.float32)


def voz_radio(p, corte=None):
    x = decode(p, 1)
    if corte is not None:
        x = x[:int(corte * SR)]
        fade = int(0.04 * SR)
        x[-fade:] *= np.linspace(1, 0, fade)
    x = bp(x, 380, 3200, 3)
    x = np.tanh(x * 3.0) * 0.5          # saturação de rádio
    x = compressor(x[:, None], -24, 4.0, 0.004, 0.1, 8)[:, 0]
    st = estatica(len(x) / SR + 0.6, 0.06)
    out = np.zeros(len(st), np.float32)
    out[:len(x)] += x * 0.9
    out += st * (0.5 + 0.5 * (np.arange(len(st)) / SR > len(x) / SR - 0.1))   # a estática sobe quando o sinal corta
    return reverb(out, IR_CURTO, 0.08)


# ------------------------------------------------------------------ efeitos de trailer
def whoosh(dur=0.7, amp=0.5, subir=True):
    n = int(dur * SR)
    x = rng.normal(0, 1, n)
    tt = np.linspace(0, 1, n)
    y = np.zeros(n)
    blocos = 24
    for k in range(blocos):
        a, b = int(k * n / blocos), int((k + 1) * n / blocos)
        fc = 300 * (9000 / 300) ** ((k / blocos) if subir else (1 - k / blocos))
        bb, aa = signal.butter(1, min(fc, SR * 0.45) / (SR / 2), "low")
        y[a:b] = signal.lfilter(bb, aa, x[a:b + 64])[:b - a]
    env = np.sin(np.pi * tt) ** 1.6
    return (y * env / (np.abs(y).max() + 1e-9) * amp).astype(np.float32)


def impacto_sub(amp=1.0, dur=2.6):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    y = np.sin(2 * np.pi * (34 + 70 * np.exp(-tt * 7)) * tt) * np.exp(-tt * 1.4)
    y += 0.4 * lp(rng.normal(0, 1, n), 1500) * np.exp(-tt * 10)
    return (y / np.abs(y).max() * amp).astype(np.float32)


def tinido(dur=3.0, amp=0.07):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    return (np.sin(2 * np.pi * 3150 * tt) * amp * np.exp(-tt * 0.9) * np.minimum(tt / 0.08, 1)).astype(np.float32)


def ondas(dur, amp=0.35):
    """ondas do mar: ruído filtrado com varreduras lentas (espuma que vai e vem)"""
    n = int(dur * SR)
    x = rng.normal(0, 1, n)
    tt = np.arange(n) / SR
    lento = 0.5 + 0.5 * np.sin(2 * np.pi * (1 / 7.5) * tt + 0.7)
    base = lp(x, 900, 2) * (0.25 + 0.75 * lento ** 2)
    espuma = hp(lp(x, 6500, 2), 1800) * (0.1 + 0.9 * lento ** 3)
    y = base * 0.8 + espuma * 0.5
    return (y / np.abs(y).max() * amp).astype(np.float32)


def vento(dur, amp=0.18):
    n = int(dur * SR)
    x = lp(rng.normal(0, 1, n), 500, 2)
    tt = np.arange(n) / SR
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * tt)
    return (x / np.abs(x).max() * amp).astype(np.float32)


# ------------------------------------------------------------------ montagem
SEM_AVI = "--sem-avi" in sys.argv
musica = decode(os.path.join(RT, "musica", "musica.wav"), 2)
mus = z()
poe(mus, musica, 0.0, 1.0)

# --- vozes
voz = z()
narr = {  # arquivo: tempo (s no trailer)
    "n01": 8.0, "n02": 25.4, "n03": 33.4, "n04": 53.6, "n05": 60.7, "n06": 68.7, "n07": 78.3,
    "n08": 86.8, "n09": 93.6, "n10": 101.6,
}
for k, t in narr.items():
    poe(voz, voz_narrador(os.path.join(RT, "voz", k + ".mp3")), t, 1.0)
radio = z()
poe(radio, voz_radio(os.path.join(RT, "voz", "r01.mp3"), corte=7.0), 0.6, 0.8, pan=-0.15)
poe(radio, voz_radio(os.path.join(RT, "voz", "r02.mp3"), corte=8.6), 16.0, 0.8, pan=-0.15)

# --- foley do jogo (gravado pelo Godot no AVI)
foley = z()
avi = os.path.join(RT, "bruto.avi")
if os.path.exists(avi) and not SEM_AVI:
    m = None
    log = os.path.join(RT, "render.log")
    ini = 0
    if os.path.exists(log):
        mm = re.search(r"TRAILER_INICIO frame=(\d+)", open(log, encoding="utf-8", errors="ignore").read())
        if mm:
            ini = int(mm.group(1))
    g = decode(avi, 2)
    off = ini / 30.0
    print("foley: AVI com", round(len(g) / SR, 1), "s; início do filme em", round(off, 2), "s")
    g = g[int(off * SR):]
    g = hp(g, 40)
    poe(foley, g, 6.0, 0.9)           # o filme do Godot começa no instante 6,0 do trailer
else:
    print("foley: sem AVI — só música e vozes")

# --- ambiente sintético: ondas e vento nos primeiros 30 s
amb = z()
poe(amb, ondas(31.0, 0.5), 0.0, 1.0, pan=-0.2)
poe(amb, vento(40.0, 0.25), 0.0, 1.0)
# fade do ambiente de mar quando chega a cidade (22–31 s)
fade = np.ones(N, np.float32)
fade[int(22 * SR):int(31 * SR)] = np.linspace(1, 0, int(9 * SR))
fade[int(31 * SR):] = 0.0
amb[:, 0] *= fade
amb[:, 1] *= fade

# --- efeitos
fx = z()
poe(fx, impacto_sub(0.9), 30.0)
for t in (32.0, 34.0, 36.0, 38.0):
    poe(fx, whoosh(0.55, 0.35, True), t - 0.45)
poe(fx, whoosh(1.2, 0.5, True), 21.0)       # entrada do ato I -> cidade
poe(fx, impacto_sub(0.7, 1.8), 14.0)         # abre os olhos
poe(fx, impacto_sub(1.0), 60.35)             # volta o som depois do silêncio
poe(fx, whoosh(0.6, 0.45, False), 59.5)
poe(fx, whoosh(0.9, 0.5, True), 67.2)
poe(fx, impacto_sub(0.6, 1.5), 68.0)
poe(fx, impacto_sub(0.6, 1.5), 78.0)
poe(fx, impacto_sub(0.9, 2.0), 84.0)
poe(fx, tinido(3.5, 0.06), 87.2)
poe(fx, whoosh(0.8, 0.5, True), 99.3)
poe(fx, impacto_sub(1.2, 3.2), 110.0)       # logo
poe(fx, whoosh(1.4, 0.4, True), 108.5)

# --- silêncio do corte (59.75–60.35): derruba música/foley/ambiente
sil = np.ones(N, np.float32)
a, b = int(59.7 * SR), int(60.35 * SR)
sil[a:b] = 0.0
sil[int(59.4 * SR):a] = np.linspace(1, 0, a - int(59.4 * SR))
sil[b:int(60.7 * SR)] = np.linspace(0, 1, int(60.7 * SR) - b)
for st in (mus, foley, amb):
    st *= sil[:, None]
# silêncio antes do logo (109.4–110.0): só o rufar
sil2 = np.ones(N, np.float32)
sil2[int(109.4 * SR):int(110.0 * SR)] = 0.0
mus *= sil2[:, None]
foley *= sil2[:, None]

# --- sidechain: música e foley abaixam sob a voz/rádio
vz = envelope(voz + radio, 0.02, 0.55)
duck = 1.0 - 0.58 * np.clip(vz / 0.12, 0, 1)
mus_d = mus * duck[:, None]
foley_d = foley * (1.0 - 0.35 * np.clip(vz / 0.12, 0, 1))[:, None]

mix = mus_d * 0.9 + foley_d * 0.85 + amb * 0.8 + fx * 0.9 + voz * 1.0 + radio * 0.9
# fade in/out
mix[:int(0.6 * SR)] *= np.linspace(0, 1, int(0.6 * SR))[:, None]
mix[-int(2.0 * SR):] *= np.linspace(1, 0, int(2.0 * SR))[:, None]
# limitador suave
mix = mix * 2.1                       # ganho de trailer (RMS médio ~ -16 dB)
mix = np.tanh(mix * 0.85) * 0.97          # limitador suave (nunca passa de 0,97)
sf.write(os.path.join(RT, "mix.wav"), mix, SR)
print("mix ok", round(len(mix) / SR, 1), "s, pico", round(float(np.abs(mix).max()), 2))
