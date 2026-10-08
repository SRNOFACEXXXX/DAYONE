# Camadas extras de disparo (sintetizadas, determinísticas por semente fixa): estampido grave + cauda com ecos do terreno.
# Saída: game/assets/audio/weapons/<arma>_boom.wav e <arma>_cauda.wav (mono 44,1 kHz, 16 bits).
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio", "weapons")


def salvar(nome, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.97
    with wave.open(os.path.join(OUT, nome), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def passa_baixa(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def boom(dur, f0, f1, corpo, rng):
    t = np.arange(int(SR * dur)) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 18)                         # varredura grave (peito)
    seno = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * corpo)
    estalo = rng.standard_normal(len(t)) * np.exp(-t * 90)        # transiente seco (boca do cano)
    return seno * 1.0 + passa_baixa(estalo, 2500) * 0.9 + estalo * 0.25


def cauda(dur, ecos, brilho, rng):
    t = np.arange(int(SR * dur)) / SR
    ruido = passa_baixa(rng.standard_normal(len(t)), brilho)
    x = ruido * np.exp(-t * 3.2) * 0.5
    for atraso, ganho in ecos:                                     # reflexões do terreno/prédios
        k = int(atraso * SR)
        n = min(len(t) - k, int(0.35 * SR))
        x[k:k + n] += passa_baixa(rng.standard_normal(n), brilho * 0.7) * np.exp(-np.arange(n) / SR * 11) * ganho
    ataque = np.minimum(1.0, t / 0.01)
    return x * ataque


ARMAS = {   # arma: (dur boom, f0, f1, decaimento corpo, dur cauda, ecos, brilho da cauda)
    "ak47": (0.35, 95, 42, 9.0, 1.9, [(0.11, 0.55), (0.27, 0.4), (0.52, 0.28), (0.9, 0.15)], 1400),
    "m4": (0.3, 110, 50, 11.0, 1.6, [(0.11, 0.45), (0.27, 0.32), (0.52, 0.2)], 1800),
    "mosin": (0.45, 85, 38, 7.0, 2.4, [(0.14, 0.6), (0.33, 0.45), (0.65, 0.3), (1.1, 0.18)], 1200),
    "pistol": (0.22, 130, 60, 14.0, 1.1, [(0.1, 0.35), (0.25, 0.22)], 2200),
}
for i, (arma, (bd, f0, f1, c, cd, ecos, br)) in enumerate(ARMAS.items()):
    rng = np.random.default_rng(1000 + i)
    salvar(arma + "_boom.wav", boom(bd, f0, f1, c, rng))
    salvar(arma + "_cauda.wav", cauda(cd, ecos, br, rng))
    print("som", arma)
