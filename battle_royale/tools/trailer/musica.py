"""Trilha do trailer DAYONE (120 s): Americana sombria / country de suspense, Lá menor, 76 BPM.
Violão dedilhado e boom-chick (Karplus-Strong), slide guitar com vibrato, contrabaixo, drone, batimento, stomp/taiko, risers e impactos.
Tudo sintetizado aqui (sem samples, sem licença). Saída: raw/trailer/musica/{musica.wav, stems/*.wav}
Uso: python tools/trailer/musica.py
"""
import os
import numpy as np
from scipy import signal
import soundfile as sf

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "raw", "trailer", "musica")
os.makedirs(OUT + "/stems", exist_ok=True)
DUR = 121.0
BPM = 76.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
rng = np.random.default_rng(27)
N = int(DUR * SR)


def buf():
    return np.zeros((N, 2), np.float32)


def put(b, x, t, pan=0.0, gain=1.0):
    """soma o sinal mono x em b a partir do tempo t com pan (-1..1)"""
    i = int(t * SR)
    if i >= N or i < 0:
        return
    n = min(len(x), N - i)
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    b[i:i + n, 0] += x[:n] * l * gain
    b[i:i + n, 1] += x[:n] * r * gain


def lp(x, fc, order=2):
    b_, a_ = signal.butter(order, min(fc, SR * 0.45) / (SR / 2), "low"); return signal.lfilter(b_, a_, x)


def hp(x, fc, order=2):
    b_, a_ = signal.butter(order, fc / (SR / 2), "high"); return signal.lfilter(b_, a_, x)


def bp(x, f1, f2, order=2):
    b_, a_ = signal.butter(order, [f1 / (SR / 2), min(f2, SR * 0.45) / (SR / 2)], "band"); return signal.lfilter(b_, a_, x)


def peak(x, f0, gain_db, q=1.0):
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    al = np.sin(w0) / (2 * q)
    b_ = [1 + al * A, -2 * np.cos(w0), 1 - al * A]
    a_ = [1 + al / A, -2 * np.cos(w0), 1 - al / A]
    return signal.lfilter(np.array(b_) / a_[0], np.array(a_) / a_[0], x)


def env_adsr(n, a=0.005, d=0.1, s=0.7, r=0.2):
    e = np.ones(n)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, max(na, 1))
    e[na:na + nd] = np.linspace(1, s, max(nd, 1))[:max(0, n - na)]
    e[na + nd:] = s
    if nr > 0 and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


# ------------------------------------------------------------------ instrumentos
def pluck(freq, dur, bright=0.55, decay=0.9965, amp=1.0):
    """Karplus-Strong: realimentação com média de 2 amostras (lfilter, rápido)."""
    n = int(dur * SR)
    L = int(round(SR / freq))
    burst = rng.uniform(-1, 1, L)
    burst = lp(burst, 800 + 7000 * bright, 1)
    x = np.zeros(n)
    x[:L] = burst * np.hanning(L * 2)[L:] * 0 + burst
    a_ = np.zeros(L + 2)
    a_[0] = 1.0
    a_[L] = -decay * 0.5
    a_[L + 1] = -decay * 0.5
    y = signal.lfilter([1.0], a_, x)
    y *= np.linspace(1, 0.0, n) ** 0.5            # fim limpo
    return y / (np.abs(y).max() + 1e-9) * amp


def violao_bus(x):
    x = hp(x, 70)
    x = peak(x, 105, 3.0, 0.9)      # corpo
    x = peak(x, 240, 2.0, 1.2)
    x = peak(x, 3200, 3.0, 0.8)     # presença (palheta/dedo)
    x = peak(x, 520, -2.5, 1.0)     # tira caixa
    return lp(x, 8500, 2)


def strum(freqs, t0, vel=0.8, down=True, spread=0.018, dur=1.6, bright=0.6):
    out = np.zeros(int((dur + 0.2) * SR))
    order = freqs if down else freqs[::-1]
    for k, f in enumerate(order):
        y = pluck(f, dur, bright, 0.9972 - 0.0004 * k, vel * (0.85 + 0.15 * rng.random()))
        i = int(k * spread * SR)
        out[i:i + len(y)] += y[:len(out) - i]
    return out


def slide(freq0, freq1, dur, vib=5.4, vdepth=0.012, amp=0.5, onset=0.16, glide=0.35):
    """slide/steel guitar: serra filtrada, vibrato que entra depois do ataque, escorrega de baixo para a nota."""
    n = int(dur * SR)
    tt = np.arange(n) / SR
    gl = np.clip(tt / glide, 0, 1)
    gl = 1 - (1 - gl) ** 2
    f = freq0 * (freq1 / freq0) ** gl if freq0 != freq1 else np.full(n, freq1)
    f = np.asarray(f) * (1 + vdepth * np.sin(2 * np.pi * vib * tt) * np.clip((tt - 0.25) / 0.5, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.zeros(n)
    for h, a in [(1, 1.0), (2, 0.55), (3, 0.38), (4, 0.2), (5, 0.12), (6, 0.07)]:
        y += a * np.sin(h * ph + 0.3 * h)
    y = lp(y, 2600, 2)
    y = peak(y, 1250, 5.0, 1.5)       # vogal "slide"
    e = env_adsr(n, onset, 0.35, 0.62, 0.9)
    return y / np.abs(y).max() * e * amp


def contrabaixo(freq, dur, amp=0.9):
    y = pluck(freq, dur, 0.25, 0.9935, amp)
    y = lp(y, 650, 2)
    y = peak(y, 90, 4, 1.0)
    return y


def kick(amp=0.9):
    n = int(0.45 * SR)
    tt = np.arange(n) / SR
    f = 45 + 95 * np.exp(-tt * 28)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 9)
    y += 0.12 * lp(rng.uniform(-1, 1, n), 2500) * np.exp(-tt * 60)
    return y * amp


def stomp(amp=0.9):
    """pisada de bota no assoalho de madeira"""
    n = int(0.5 * SR)
    tt = np.arange(n) / SR
    y = np.sin(2 * np.pi * 62 * tt) * np.exp(-tt * 13) * 0.9
    y += lp(rng.uniform(-1, 1, n), 900) * np.exp(-tt * 38) * 0.6
    y += bp(rng.uniform(-1, 1, n), 1400, 2600) * np.exp(-tt * 70) * 0.2
    return y * amp


def vassoura(amp=0.5):
    n = int(0.28 * SR)
    tt = np.arange(n) / SR
    y = bp(rng.uniform(-1, 1, n), 1800, 7500) * np.exp(-tt * 14) * (1 - np.exp(-tt * 300))
    return y * amp


def taiko(amp=0.9):
    n = int(2.4 * SR)
    tt = np.arange(n) / SR
    y = np.sin(2 * np.pi * (58 + 22 * np.exp(-tt * 9)) * tt) * np.exp(-tt * 2.1)
    y += 0.25 * lp(rng.uniform(-1, 1, n), 600) * np.exp(-tt * 20)
    return y * amp


def batimento(amp=0.7):
    out = np.zeros(int(0.7 * SR))
    for t0, a in [(0.0, 1.0), (0.2, 0.7)]:
        n = int(0.22 * SR)
        tt = np.arange(n) / SR
        y = np.sin(2 * np.pi * 52 * tt) * np.exp(-tt * 18)
        i = int(t0 * SR)
        out[i:i + n] += y * a
    return lp(out, 220) * amp


def riser(dur, amp=0.7, f0=200, f1=9000):
    n = int(dur * SR)
    x = rng.uniform(-1, 1, n)
    tt = np.linspace(0, 1, n)
    # ruído com corte subindo (varredura por blocos)
    y = np.zeros(n)
    blocos = 40
    for k in range(blocos):
        a, b_ = int(k * n / blocos), int((k + 1) * n / blocos)
        fc = f0 * (f1 / f0) ** ((k + 1) / blocos)
        y[a:b_] = lp(x[a:b_ + 2048], fc, 1)[:b_ - a] if b_ - a > 0 else 0
    y *= tt ** 2.2
    # tom que sobe
    fr = 110 * 2 ** (tt * 2.2)
    y += 0.25 * np.sin(2 * np.pi * np.cumsum(fr) / SR) * tt ** 1.6
    return y / np.abs(y).max() * amp


def impacto(amp=1.0, dur=3.2):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    y = np.sin(2 * np.pi * (36 + 60 * np.exp(-tt * 6)) * tt) * np.exp(-tt * 1.15)
    y += 0.5 * lp(rng.uniform(-1, 1, n), 1800) * np.exp(-tt * 9)
    y += 0.2 * np.sin(2 * np.pi * 72 * tt) * np.exp(-tt * 2.0)
    return y / np.abs(y).max() * amp


def drone(dur, amp=0.4):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n)
    for f, a in [(55, 1.0), (82.4, 0.55), (110.3, 0.4), (164.8, 0.2)]:
        y += a * np.sin(2 * np.pi * f * (1 + 0.0015 * np.sin(2 * np.pi * 0.13 * tt + f)) * tt)
    y += 0.35 * lp(rng.uniform(-1, 1, n), 380, 2)
    y *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.07 * tt)
    return y / np.abs(y).max() * amp


def reverb_ir(dur=2.4, decay=3.2, damp=5000):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for c in range(2):
        r = rng.normal(0, 1, n) * np.exp(-tt * decay)
        r = lp(r, damp, 1)
        ir[:, c] = r
    ir[:int(0.012 * SR)] *= 0.2
    return (ir / np.sqrt((ir ** 2).sum(0).mean())).astype(np.float32)


IR_SALA = reverb_ir(1.8, 3.4, 5500)
IR_LONGA = reverb_ir(3.4, 1.9, 3800)


def reverbera(b, ir, mix=0.3):
    wet = np.stack([signal.fftconvolve(b[:, c], ir[:, c])[:N] for c in range(2)], 1)
    return b * (1 - mix * 0.5) + wet.astype(np.float32) * mix


def delay(b, tempo=BEAT * 0.75, fb=0.32, mix=0.22):
    d = int(tempo * SR)
    out = b.copy()
    wet = np.zeros_like(b)
    for k in range(1, 6):
        i = d * k
        if i >= N:
            break
        wet[i:] += b[:N - i] * (fb ** k) * (1.0 if k % 2 else 0.8)
    wet = wet[:, ::-1] if False else wet
    return out + wet * mix


# ------------------------------------------------------------------ composição
CH = {
    "Am": dict(bass=(110.0, 164.8), notas=[164.8, 220.0, 261.6, 329.6], arp=[220.0, 261.6, 329.6]),
    "G": dict(bass=(98.0, 146.8), notas=[146.8, 196.0, 246.9, 293.7], arp=[196.0, 246.9, 293.7]),
    "F": dict(bass=(87.3, 130.8), notas=[130.8, 174.6, 220.0, 261.6], arp=[220.0, 261.6, 349.2]),
    "E": dict(bass=(82.4, 123.5), notas=[123.5, 164.8, 207.7, 246.9, 329.6], arp=[207.7, 246.9, 329.6]),
    "Dm": dict(bass=(73.4, 110.0), notas=[146.8, 220.0, 293.7, 349.2], arp=[220.0, 293.7, 349.2]),
    "C": dict(bass=(65.4, 98.0), notas=[130.8, 164.8, 196.0, 261.6, 329.6], arp=[196.0, 261.6, 329.6]),
}

violao = buf()
slidebus = buf()
baixo = buf()
perc = buf()
atmos = buf()


def compasso(i):
    return i * BAR


def dedilhado(ib, acorde, vel=0.55, bright=0.45, pan=-0.25):
    c = CH[acorde]
    t0 = compasso(ib)
    padrao = [("b0", 0), ("a", 1), ("a", 2), ("a", 0), ("b1", 0), ("a", 2), ("a", 1), ("a", 0)]
    for k, (tipo, ix) in enumerate(padrao):
        t = t0 + k * BEAT / 2 + rng.normal(0, 0.004)
        if tipo == "b0":
            f = c["bass"][0]
        elif tipo == "b1":
            f = c["bass"][1]
        else:
            f = c["arp"][ix % len(c["arp"])]
        y = pluck(f, 1.5, bright, 0.9968, vel * (0.8 + 0.4 * rng.random()) * (1.15 if tipo.startswith("b") else 0.85))
        put(violao, violao_bus(y), t, pan if tipo != "a" else pan + 0.12)


def boom_chick(ib, acorde, vel=0.8, pan=-0.15, oitavas=False):
    c = CH[acorde]
    t0 = compasso(ib)
    for k in range(4):
        t = t0 + k * BEAT + rng.normal(0, 0.003)
        if k in (0, 2):
            f = c["bass"][0] if k == 0 else c["bass"][1]
            y = pluck(f, 1.2, 0.35, 0.997, vel * 1.1)
            put(violao, violao_bus(y), t, pan)
            put(baixo, contrabaixo(f * (1 if oitavas else 1), 0.9, 0.85), t, 0.0)
        else:
            y = strum(c["notas"], t, vel * 0.8, down=(k == 1), spread=0.011, dur=0.55, bright=0.7)
            put(violao, violao_bus(y), t, pan + 0.2)
        if k in (1, 3):
            put(perc, vassoura(0.55 * vel), t + 0.0, 0.1)


def boom_chick_8(ib, acorde, vel=0.9, pan=-0.1):
    """versão 8ths (ato III): baixo/strum/baixo/strum + contratempos"""
    c = CH[acorde]
    t0 = compasso(ib)
    for k in range(8):
        t = t0 + k * BEAT / 2 + rng.normal(0, 0.002)
        if k in (0, 4):
            f = c["bass"][0] if k == 0 else c["bass"][1]
            put(violao, violao_bus(pluck(f, 1.0, 0.4, 0.997, vel * 1.1)), t, pan)
            put(baixo, contrabaixo(f, 0.75, 0.95), t)
        elif k in (2, 6):
            put(violao, violao_bus(strum(c["notas"], t, vel * 0.9, down=True, spread=0.009, dur=0.45, bright=0.75)), t, pan + 0.2)
        elif k in (3, 7):
            put(violao, violao_bus(strum(c["notas"][1:], t, vel * 0.55, down=False, spread=0.008, dur=0.3, bright=0.8)), t, pan + 0.25)
        if k in (0, 4):
            put(perc, kick(0.5), t)
        if k in (2, 6):
            put(perc, vassoura(0.8), t, 0.15)
            put(perc, stomp(0.35), t)


# 0–6 s: só atmosfera; drone entra a partir de 3 s
put(atmos, drone(DUR - 3.0, 0.55) * np.concatenate([np.linspace(0, 1, int(8 * SR)), np.ones(int((DUR - 11) * SR))]), 3.0)

# ATO I (6–30 s = compassos 2–9)
prog1 = ["Am", "Am", "F", "E", "Am", "Am", "F", "E"]
for k, ac in enumerate(prog1):
    ib = 2 + k
    dedilhado(ib, ac, vel=0.42 + 0.03 * k, bright=0.4)
# slide longo entrando em 14 s (compasso 4.5)
put(slidebus, slide(196.0, 220.0, 5.2, amp=0.5), compasso(4) + 2 * BEAT)
put(slidebus, slide(246.9, 261.6, 4.6, amp=0.45), compasso(6))
put(slidebus, slide(293.7, 329.6, 5.6, amp=0.5), compasso(7) + BEAT)

# ATO II (30–60 s = compassos 9.5–19): mais sombrio
prog2 = ["Dm", "Am", "F", "E", "Dm", "Am", "E", "E"]
for k, ac in enumerate(prog2):
    ib = 10 + k
    dedilhado(ib, ac, vel=0.5 + 0.02 * k, bright=0.5)
    put(perc, batimento(0.8), compasso(ib) + 0.0, 0.0)
    put(perc, batimento(0.55), compasso(ib) + 2 * BEAT, 0.0)
for t in (29.6, 38.0, 46.0):
    put(perc, taiko(0.65), t, -0.1)
put(slidebus, slide(220.0, 261.6, 6.0, amp=0.5), compasso(10) + BEAT)
put(slidebus, slide(164.8, 207.7, 6.2, amp=0.45), compasso(14))
put(slidebus, slide(329.6, 311.0, 5.0, amp=0.4), compasso(17) + BEAT)
# riser para o corte seco de 60 s
put(atmos, riser(5.4, 0.65), 54.2)
put(atmos, batimento(0.9), 58.2)
put(atmos, batimento(0.8), 58.9)

# ATO III (60–100 s): boom-chick, mais ritmo
SILENCIO_ATE = 60.0
prog3 = ["Am", "G", "F", "E", "Am", "G", "F", "E", "Dm", "Am", "F", "E", "Am", "C", "G", "E"]
for k, ac in enumerate(prog3):
    t0 = 60.0 + k * BAR
    ib = int(round(t0 / BAR))
    if k < 8:
        boom_chick(ib, ac, vel=0.8 + 0.01 * k, pan=-0.15)
        put(perc, stomp(0.55), t0, 0.0)
        put(perc, stomp(0.45), t0 + 2 * BEAT, 0.0)
    else:
        boom_chick_8(ib, ac, vel=0.95, pan=-0.1)
        put(atmos, taiko(0.5), t0, -0.1) if k % 2 == 0 else None
put(slidebus, slide(329.6, 392.0, 4.0, amp=0.55), 76.0)
put(slidebus, slide(392.0, 440.0, 3.4, amp=0.55), 92.0)
put(slidebus, slide(329.6, 311.0, 5.6, amp=0.5), 96.0)
put(atmos, riser(3.6, 0.6, 400, 12000), 96.2)

# ATO IV (100–110 s): calmo, esperança sombria
prog4 = ["Am", "C", "G", "E"]
for k, ac in enumerate(prog4):
    ib = int(round((100.0 + k * BAR) / BAR))
    dedilhado(ib, ac, vel=0.45, bright=0.4, pan=-0.1)
put(slidebus, slide(329.6, 392.0, 6.0, amp=0.5), 101.5)
put(atmos, riser(2.4, 0.5, 300, 8000), 107.2)

# Título (110 s): impacto e último acorde
put(atmos, impacto(1.0), 110.0)
put(perc, taiko(0.9), 110.0, 0.0)
put(violao, violao_bus(strum(CH["Am"]["notas"] + [110.0, 55.0 * 2], 110.05, 0.9, True, 0.03, 6.5, 0.4)), 110.05, -0.1)
put(slidebus, slide(220.0, 220.0, 8.0, amp=0.45, onset=0.4), 110.5)

# ------------------------------------------------------------------ mix por stem
stems = {
    "violao": reverbera(delay(violao, mix=0.1), IR_SALA, 0.28),
    "slide": reverbera(delay(slidebus, BEAT * 0.75, 0.38, 0.35), IR_LONGA, 0.38),
    "baixo": baixo,
    "perc": reverbera(perc, IR_SALA, 0.18),
    "atmos": reverbera(atmos, IR_LONGA, 0.3),
}
ganhos = {"violao": 0.95, "slide": 0.8, "baixo": 0.9, "perc": 0.9, "atmos": 0.9}
mix = np.zeros((N, 2), np.float32)
for k, v in stems.items():
    sf.write(f"{OUT}/stems/{k}.wav", v, SR)
    mix += v * ganhos[k]
mix = mix / (np.abs(mix).max() + 1e-9) * 0.92
sf.write(f"{OUT}/musica.wav", mix, SR)
print("ok", OUT, round(N / SR, 1), "s")
