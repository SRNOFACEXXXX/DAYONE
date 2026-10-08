"""Prepara os sons CC0 baixados do OpenGameArt (raw/audio_net) para o jogo.
Fontes (todas CC0): zombienoises.zip (ianzazz), monster-sounds-volume-2.zip (Ogrebane), loop_*.wav (domasx2, 'racing car engine sound loops').
Saída: game/assets/audio/zombie/*.wav e game/assets/audio/vehicle/engine_*.wav
"""
import numpy as np, soundfile as sf, os, glob
from scipy import signal
ROOT = os.path.dirname(os.path.abspath(__file__)) + "/.."
SRC = ROOT + "/raw/audio_net"
OUT = ROOT + "/game/assets/audio"
SR = 44100

def load(p):
    x, sr = sf.read(p)
    if x.ndim > 1: x = x.mean(1)
    if sr != SR: x = signal.resample_poly(x, SR, sr)
    return x.astype(np.float64)

def pitch(x, ratio):   # ratio<1 = mais grave (e mais longo), como mudar a velocidade da fita
    from fractions import Fraction
    f = Fraction(ratio).limit_denominator(100)
    return signal.resample_poly(x, f.denominator, f.numerator)

def lp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "low"); return signal.lfilter(b, a, x)

def hp(x, fc):
    b, a = signal.butter(2, fc / (SR / 2), "high"); return signal.lfilter(b, a, x)

def low_shelf(x, gain_db=6.0, fc=400.0):
    return x + (10 ** (gain_db / 20) - 1) * lp(x, fc, 1)

def norm(x, peak):
    x = x - x.mean()
    return x / max(np.abs(x).max(), 1e-9) * peak

def fade(x, ms=6):
    n = int(SR * ms / 1000); x = x.copy()
    x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n); return x

def save(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, np.clip(x, -1, 1), SR, subtype="PCM_16")
    print("ok", os.path.relpath(path, ROOT), f"{len(x)/SR:.2f}s")

# ---- zumbis ----
Z = OUT + "/zombie"
for i, n in enumerate(["zombienoise1", "zombienoise2", "zombienoise3"], 1):
    x = load(f"{SRC}/zombienoises/{n}.ogg")
    x = low_shelf(lp(hp(x, 70), 4200), 5.0, 350)
    save(f"{Z}/zombie_groan_{i + 3}.wav", fade(norm(x, 0.6)))
x = load(f"{SRC}/zombienoises/fastzombie1.ogg")
save(f"{Z}/zombie_run_1.wav", fade(norm(low_shelf(lp(hp(x, 70), 4500), 4.0), 0.7)))
mon = lambda k: load(f"{SRC}/monster-sounds-volume-2/Monster-Sounds-Volume-2/" + (f"Monster-{k}.wav" if k <= 8 else f"monster-{k}.wav"))
grupos = {"zombie_alert": ([1, 2, 3], 0.72, 0.9), "zombie_attack": ([4, 5, 6, 7, 8], 0.8, 0.9),
          "zombie_hurt": ([9, 10, 11, 12, 13], 0.85, 0.85), "zombie_die": ([14, 15, 16, 17, 18], 0.66, 0.9)}
for gid, (ks, r, pk) in grupos.items():
    for j, k in enumerate(ks, 1):
        x = pitch(mon(k), r)
        x = low_shelf(lp(hp(x, 80), 3800), 6.0, 350)
        save(f"{Z}/{gid}_{j}.wav", fade(norm(x, pk)))

# ---- motor (loops de 0,6 s em degraus de rotação; o jogo faz pitch + crossfade) ----
V = OUT + "/vehicle"
for nome, src in [("engine_idle", "loop_1_0"), ("engine_mid", "loop_3_0"), ("engine_high", "loop_5_0")]:
    x = load(f"{SRC}/{src}.wav")
    x = lp(hp(x, 40), 5000)
    save(f"{V}/{nome}.wav", norm(x, 0.8))
