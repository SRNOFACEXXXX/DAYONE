"""Refaz os sons de zumbi SÓ a partir das gravações reais de zumbi (CC0, ianzazz 'zombienoises', OpenGameArt) que já estão
no jogo: zombie_groan_4..6 e zombie_run_1. Antes, alerta/ataque/dor/morte vinham de 'monster sounds' com pitch (soavam
como monstro de desenho) e groan_1..3 eram ~4x mais altos que o resto (RMS 0,21 contra 0,05). Tudo sai com RMS parecido.
Uso: python tools/gen_zumbi_audio.py <pasta_com_originais>   (lê groan_4..6 e run_1 de lá; escreve em assets/audio/zombie)
"""
import sys, os
import numpy as np, soundfile as sf
from scipy import signal

SR = 44100
SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "zombie")
rng = np.random.default_rng(27)


def load(n):
    x, sr = sf.read(os.path.join(SRC, n + ".wav"))
    if x.ndim > 1:
        x = x.mean(1)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr)
    return x


def pitch(x, r):   # r > 1 = mais agudo e mais curto (reamostragem, como fita)
    n = int(len(x) / r)
    return signal.resample(x, n)


def fade(x, a=0.01, b=0.08):
    n = len(x)
    e = np.ones(n)
    ia, ib = int(a * SR), int(b * SR)
    if ia:
        e[:ia] = np.linspace(0, 1, ia)
    if ib:
        e[-ib:] *= np.linspace(1, 0, ib)
    return x * e


def rms_norm(x, alvo=0.07, pico=0.6):
    r = np.sqrt((x ** 2).mean()) + 1e-9
    x = x * (alvo / r)
    p = np.abs(x).max()
    if p > pico:
        x = x * (pico / p)
    return x


def trecho(x, ini, dur):
    a = int(ini * SR)
    return x[a:a + int(dur * SR)]


def energia_pico(x, dur):   # trecho de maior energia com a duração pedida
    w = int(dur * SR)
    if len(x) <= w:
        return x
    e = np.convolve(x ** 2, np.ones(w), "valid")
    i = int(np.argmax(e))
    return x[i:i + w]


def save(nome, x, alvo=0.07):
    x = rms_norm(fade(x), alvo)
    sf.write(os.path.join(OUT, nome + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")
    print("ok", nome, "%.2fs" % (len(x) / SR))


g4, g5, g6, run = load("zombie_groan_4"), load("zombie_groan_5"), load("zombie_groan_6"), load("zombie_run_1")
reais = [g4, g5, g6]

# gemidos (ocioso/andando): 1..3 = variações graves/agudas das 3 gravações; 4..6 ficam como estão (só nível)
for i, (x, r) in enumerate([(g4, 0.9), (g5, 1.07), (g6, 0.95)], 1):
    save("zombie_groan_%d" % i, pitch(x, r), 0.055)
for i, x in enumerate(reais, 4):
    save("zombie_groan_%d" % i, x, 0.055)
# corrida (perseguindo): trecho curto e ofegante
save("zombie_run_1", run, 0.07)
# alerta (viu o jogador): gemido agudo e mais forte, ~1 s
for i, (x, r) in enumerate([(g5, 1.12), (g4, 1.18), (g6, 1.08)], 1):
    save("zombie_alert_%d" % i, energia_pico(pitch(x, r), 1.0), 0.09)
# ataque (golpe): rosnado curto 0,35–0,5 s do trecho mais forte
for i, (x, r, d) in enumerate([(run, 1.05, 0.34), (g4, 1.2, 0.45), (g5, 1.25, 0.4), (g6, 1.15, 0.38), (run, 0.95, 0.34)], 1):
    save("zombie_attack_%d" % i, energia_pico(pitch(x, r), d), 0.09)
# dor (levou tiro): grunhido curto e agudo
for i, (x, r) in enumerate([(g6, 1.3), (g4, 1.35), (g5, 1.4), (run, 1.25), (g6, 1.45)], 1):
    save("zombie_hurt_%d" % i, energia_pico(pitch(x, r), 0.35), 0.08)
# morte: gemido que cai de tom e some
for i, (x, r) in enumerate([(g4, 0.85), (g5, 0.8), (g6, 0.82), (g4, 0.78), (g5, 0.88)], 1):
    y = energia_pico(pitch(x, r), 1.0)
    y = y * np.linspace(1.0, 0.15, len(y)) ** 1.5
    save("zombie_die_%d" % i, y, 0.07)
