"""Sintetiza os áudios de clima (numpy -> wav 16-bit mono 22,05 kHz). Loops são periódicos (filtro no domínio da frequência)."""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "clima")
rng = np.random.default_rng(7)

def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def shaped_noise(n, f):  # f(freqs)->ganho
    spec = np.fft.rfft(rng.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(spec * f(fr), n)

def band(fr, lo, hi, slope=2.0):
    g = np.ones_like(fr)
    g *= 1 / (1 + (lo / np.maximum(fr, 1.0)) ** slope)
    g *= 1 / (1 + (fr / hi) ** slope)
    return g

n = SR * 8
t = np.arange(n) / SR
# chuva: ruído de banda larga 500-9k + "gotas" (impulsos filtrados) periódicas
chuva = shaped_noise(n, lambda fr: band(fr, 600, 8000, 1.5))
gotas = np.zeros(n)
for i in rng.integers(0, n, 2600):
    gotas[i] = rng.uniform(0.3, 1.0)
gotas = np.fft.irfft(np.fft.rfft(gotas) * band(np.fft.rfftfreq(n, 1 / SR), 2500, 9000, 2), n)
chuva = chuva / np.std(chuva) + 0.9 * gotas / np.std(gotas)
save("chuva_loop", chuva, 0.7)

# vento: ruído grave modulado lentamente (modulação com períodos que dividem 8 s)
v = shaped_noise(n, lambda fr: band(fr, 60, 900, 2.0))
mod = 0.6 + 0.4 * np.sin(2 * np.pi * t / 8 * 1) * np.sin(2 * np.pi * t / 8 * 3 + 1.0)
save("vento_loop", v / np.std(v) * mod, 0.6)

# grilos: pulsos de tom ~4,6 kHz em rajadas (3 vozes), periódico em 8 s
g = np.zeros(n)
for f0, rate, ph in [(4400, 14, 0.0), (4900, 11, 0.37), (5300, 17, 0.71)]:
    gate = (np.sin(2 * np.pi * rate * t + ph * 6) > 0.2).astype(float)
    burst = (np.sin(2 * np.pi * (t / 8 * 4) + ph * 9) > -0.3).astype(float)   # 4 rajadas por loop
    env = np.convolve(gate * burst, np.ones(40) / 40, "same")
    g += np.sin(2 * np.pi * f0 * t) * env * 0.5
g += 0.02 * shaped_noise(n, lambda fr: band(fr, 3000, 7000))
save("grilos_loop", g, 0.5)

# trovão: estouro + rolar grave com decaimento (3 variações)
for k in range(1, 4):
    d = SR * (5 + k)
    tt = np.arange(d) / SR
    ru = shaped_noise(d, lambda fr: band(fr, 25, 220 + 60 * k, 3.0))
    env = np.exp(-tt / (1.3 + 0.5 * k)) * (1 - np.exp(-tt / 0.03))
    # rolar: reforços irregulares
    for _ in range(4 + k):
        c = rng.uniform(0.3, 3.5); a = rng.uniform(0.2, 0.7)
        env += a * np.exp(-((tt - c) / 0.5) ** 2) * np.exp(-tt / 3)
    crack = shaped_noise(d, lambda fr: band(fr, 150, 2500, 2.0)) * np.exp(-tt / 0.12)
    x = ru / np.std(ru) * env + 0.5 * crack / np.std(crack) * np.exp(-tt / 0.15)
    x *= np.minimum(1, (d - np.arange(d)) / (SR * 0.3))
    save("trovao_%d" % k, x, 0.9)
print("ok")
