"""Sintetiza o som da fogueira (laço de 6 s, sem emenda): chiado grave filtrado + estalos aleatórios.
Uso: python tools/gen_fogueira_audio.py   (escreve assets/audio/ambient/fogueira_loop.wav)"""
import os
import numpy as np, soundfile as sf
from scipy import signal

SR = 44100
DUR = 6.0
N = int(SR * DUR)
rng = np.random.default_rng(11)

# base: ruído rosa-ish passa-banda (chama) com modulação lenta
b = rng.standard_normal(N)
sos = signal.butter(2, [120, 1800], "bandpass", fs=SR, output="sos")
base = signal.sosfilt(sos, b)
t = np.arange(N) / SR
mod = 0.75 + 0.25 * np.sin(2 * np.pi * t / DUR * 3 + 1.0) * np.sin(2 * np.pi * t / DUR * 5)
base *= mod * 0.35

# estalos: cliques curtos filtrados em alturas variadas
est = np.zeros(N)
for _ in range(34):
    p = rng.integers(0, N - 2000)
    ln = rng.integers(60, 600)
    env = np.exp(-np.arange(ln) / (ln * rng.uniform(0.15, 0.4)))
    est[p:p + ln] += rng.standard_normal(ln) * env * rng.uniform(0.15, 0.8)
est = signal.sosfilt(signal.butter(2, [900, 6000], "bandpass", fs=SR, output="sos"), est)

x = base + est * 0.8
# emenda: cross-fade do fim com o começo
f = int(SR * 0.25)
x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
x = x[:-f]
x *= 0.5 / np.max(np.abs(x))
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "ambient", "fogueira_loop.wav")
sf.write(out, x.astype(np.float32), SR, subtype="PCM_16")
print("ok", out, len(x) / SR, "s")
