# Extrai os tiros/foley das gravações do usuário (Videos/pistola.mkv, m4.mkv, audiom249.mkv -> raw/audio_user/*.wav, via PyAV)
# e grava os clipes em game/assets/audio/weapons. Estruturas medidas: M4 T=0,0843 s (711 rpm), M249 T=0,0783 s (766 rpm).
# Uso: python tools/audio_usuario.py
import os, numpy as np, soundfile as sf
from scipy.signal import find_peaks, butter, sosfilt
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(R, "raw", "audio_user")
OUT = os.path.join(R, "game", "assets", "audio", "weapons")
SR = 48000


def carga(n):
    x, sr = sf.read(os.path.join(SRC, n + ".wav"))
    assert sr == SR
    return x.mean(1).astype(np.float32)


def pico_perto(m, t, janela=0.03):
    """Tempo do início real do transiente perto de t (primeiro cruzamento de 35% do pico local num envelope de 1 ms)."""
    a, b = int((t - janela) * SR), int((t + janela) * SR)
    e = np.abs(m[a:b])
    k = np.argmax(e)
    lim = 0.35 * e[k]
    i = int(np.argmax(e[:k + 1] > lim))
    return (a + i) / SR


def fatia(m, t0, dur, fade_in=0.002, fade_out=None, ganho=1.0):
    s = m[int(t0 * SR): int((t0 + dur) * SR)].copy()
    fi = int(fade_in * SR)
    fo = int((fade_out if fade_out is not None else min(0.03, dur * 0.3)) * SR)
    s[:fi] *= np.linspace(0, 1, fi)
    s[-fo:] *= np.linspace(1, 0, fo)
    return s * ganho


def pico(s):
    return float(np.abs(s).max())


def grava(nome, s, alvo=0.89):
    s = s / max(pico(s), 1e-6) * alvo
    sf.write(os.path.join(OUT, nome + ".wav"), s, SR, subtype="PCM_16")
    print("  ", nome, "%.2fs" % (len(s) / SR))


def passa_baixa(s, fc=1800):
    return sosfilt(butter(2, fc, "low", fs=SR, output="sos"), s).astype(np.float32)


def picos(m, a, b, dist=0.04, h=0.35):
    w = int(SR * 0.002)
    e = np.sqrt(np.convolve(m ** 2, np.ones(w) / w, "same"))
    seg = e[int(a * SR): int(b * SR)]
    pk, _ = find_peaks(seg, height=h * seg.max(), distance=int(dist * SR))
    return (pk + int(a * SR)) / SR


def mix(total, itens):
    out = np.zeros(int(total * SR), np.float32)
    for t, s in itens:
        i = int(t * SR)
        out[i:i + len(s)] += s[: len(out) - i]
    return out


# ---------------- Glock: 5 tiros isolados (2,2 .. 5,4 s) ----------------
m = carga("pistola")
for k, t in enumerate([2.28, 3.05, 3.85, 4.65, 5.41], 1):
    t0 = pico_perto(m, t) - 0.004
    s = fatia(m, t0, 0.78, fade_out=0.25)
    grava("glock_fire_%d" % k, s)
    grava("glock_fire_far_%d" % k, passa_baixa(s, 1400) * 0.7)
# recarga: cliques do fim da gravação (8,14 e 8,29 s) em composição de 2,2 s
c1 = fatia(m, pico_perto(m, 8.15) - 0.004, 0.12, fade_out=0.04)
c2 = fatia(m, pico_perto(m, 8.29) - 0.004, 0.16, fade_out=0.05)
grava("reload_glock", mix(2.2, [(0.55, c1), (1.35, c2 * 1.1)]), 0.6)

# ---------------- M4: fatias do disparo contínuo (T = 0,0843) + tiros isolados + cauda ----------------
m = carga("m4")
T = 0.0843
pk = picos(m, 1.4, 3.0)
for k, i in enumerate([5, 7, 9], 1):
    grava("m4u_fire_%d" % k, fatia(m, pk[i] - 0.004, T * 2.3, fade_out=T * 1.0))
    grava("m4u_fire_far_%d" % k, passa_baixa(fatia(m, pk[i] - 0.004, T * 2.6, fade_out=T * 1.2), 1500) * 0.7)
for k, t in enumerate([6.15, 7.0, 7.9], 1):
    grava("m4u_single_%d" % k, fatia(m, pico_perto(m, t, 0.06) - 0.004, 0.8, fade_out=0.3))
fim = picos(m, 1.4, 3.1)[-1]
grava("m4u_cauda", fatia(m, fim + T * 2.3, 0.7, fade_in=0.01, fade_out=0.4), 0.5)
e1 = fatia(m, pico_perto(m, 12.07, 0.05) - 0.004, 0.36, fade_out=0.08)
e2 = fatia(m, pico_perto(m, 12.87, 0.05) - 0.004, 0.3, fade_out=0.08)
e3 = fatia(m, pico_perto(m, 14.86, 0.05) - 0.004, 0.75, fade_out=0.2)
grava("reload_m4", mix(3.05, [(0.5, e1), (1.5, e2), (2.25, e3)]), 0.6)

# ---------------- M249: fatias (T = 0,0783) + cauda ----------------
m = carga("audiom249")
T = 0.0783
pk = picos(m, 2.0, 4.8)
for k, i in enumerate([6, 9, 12], 1):
    grava("m249u_fire_%d" % k, fatia(m, pk[i] - 0.004, T * 2.3, fade_out=T * 1.0))
    grava("m249u_fire_far_%d" % k, passa_baixa(fatia(m, pk[i] - 0.004, T * 2.6, fade_out=T * 1.2), 1500) * 0.7)
fim = picos(m, 2.0, 4.8)[-1]
grava("m249u_cauda", fatia(m, fim + T * 2.3, 0.8, fade_in=0.01, fade_out=0.5), 0.5)
f1 = fatia(m, 12.32, 0.55, fade_out=0.15)
f2 = fatia(m, 14.2, 3.6, fade_out=0.5)
grava("reload_m249", mix(5.4, [(0.2, f1), (1.2, f2)]), 0.6)


# ======================= Biblioteca real (Prepared SFX Library, gravações de campo) =======================
from scipy.signal import resample_poly
L1 = os.path.join(R, "raw", "audio_user", "lib", "Prepared SFX Library")
L2 = os.path.join(R, "..", "dust_fps", ".local", "firearm-extract", "Prepared SFX Library")


def lib(caminho):
    x, sr = sf.read(caminho)
    m = x.mean(1) if x.ndim > 1 else x
    if sr != SR:
        m = resample_poly(m, SR, sr)
    return m.astype(np.float32)


def disparos(m, dist=0.035, h=0.3):
    w = int(SR * 0.002)
    e = np.sqrt(np.convolve(m ** 2, np.ones(w) / w, "same"))
    pk, _ = find_peaks(e, height=h * e.max(), distance=int(dist * SR))
    return pk / SR


def onset(m, t):
    return pico_perto(m, t, 0.02) - 0.003


def pitch(s, f):
    """Reamostra (muda tom e duração): f < 1 = mais grave."""
    from fractions import Fraction
    fr = Fraction(f).limit_denominator(100)
    return resample_poly(s, fr.denominator, fr.numerator).astype(np.float32)


print("== AK-47 (C_28P near, C_31P mid, C_27P/C_36P rajada) ==")
near = lib(os.path.join(L2, "AK-47", "C_28P.wav"))
mid = lib(os.path.join(L2, "AK-47", "C_31P.wav"))
for k, t in enumerate(disparos(near), 1):
    grava("ak47u_single_%d" % k, fatia(near, onset(near, t), 0.9, fade_out=0.4))
for k, t in enumerate(disparos(mid), 1):
    grava("ak47u_single_far_%d" % k, fatia(mid, onset(mid, t), 2.0, fade_out=0.9) * 0.8)
rj = lib(os.path.join(L2, "AK-47", "C_27P.wav"))
pk = [t for t in disparos(rj) if t < 3.0]
T = float(np.median(np.diff(pk)))
print("  T AK = %.4f" % T)
for k, i in enumerate([3, 5, 7], 1):
    grava("ak47u_fire_%d" % k, fatia(rj, onset(rj, pk[i]), T * 2.3, fade_out=T))
rjm = lib(os.path.join(L2, "AK-47", "C_36P.wav"))
pkm = [t for t in disparos(rjm) if t < 3.0]
for k, i in enumerate([2, 4, 5], 1):
    grava("ak47u_fire_far_%d" % k, fatia(rjm, onset(rjm, pkm[i]), T * 2.8, fade_out=T * 1.4) * 0.8)
grava("ak47u_cauda", fatia(rj, pk[-1] + T * 2.3, 0.6, fade_in=0.01, fade_out=0.35), 0.45)

print("== Mosin (M_21P near, M_26P mid) ==")
n = lib(os.path.join(L1, "Mosin Nagant", "M_21P.wav"))
f = lib(os.path.join(L1, "Mosin Nagant", "M_26P.wav"))
for k, t in enumerate(disparos(n, 0.5), 1):
    grava("mosin_fire_%d" % k, fatia(n, onset(n, t), 2.2, fade_out=1.0))
for k, t in enumerate([t for t in disparos(f, 0.5)][:3], 1):
    grava("mosin_fire_far_%d" % k, fatia(f, onset(f, t), 3.0, fade_out=1.4) * 0.8)

print("== M107 .50: Tikka .30-06 mais grave (x0,78) + cauda do mid ==")
n = lib(os.path.join(L1, "Tikka", "W_29P.wav"))
f = lib(os.path.join(L1, "Tikka", "W_24P.wav"))
for k, t in enumerate([t for t in disparos(n, 0.5)][:2], 1):
    s = fatia(n, onset(n, t), 2.0, fade_out=0.9)
    grava("m107_fire_%d" % k, pitch(s, 0.78))
tf = [t for t in disparos(f, 0.5)][:2]
for k, t in enumerate(tf, 1):
    grava("m107_fire_far_%d" % k, pitch(fatia(f, onset(f, t), 2.6, fade_out=1.2), 0.78) * 0.8)

print("== USP (1911 .45) ==")
n = lib(os.path.join(L1, "1911", "A_42P.wav"))
f = lib(os.path.join(L1, "1911", "A_34P.wav"))
for k, t in enumerate(disparos(n, 0.5), 1):
    grava("usp_fire_%d" % k, fatia(n, onset(n, t), 1.0, fade_out=0.5))
for k, t in enumerate(disparos(f, 0.5)[:2], 1):
    grava("usp_fire_far_%d" % k, fatia(f, onset(f, t), 1.8, fade_out=0.8) * 0.8)

print("== Uzi (Carl Gustav M45 9 mm): tiros curtos + cauda ==")
n = lib(os.path.join(L1, "Carl Gustav M45", "G_31P.wav"))
for k, t in enumerate(disparos(n, 0.5), 1):
    grava("uzi_fire_%d" % k, fatia(n, onset(n, t), 0.17, fade_out=0.09))
rj = lib(os.path.join(L1, "Carl Gustav M45", "G_35P.wav"))
pk = [t for t in disparos(rj) if t < 3.0]
grava("uzi_cauda", fatia(rj, pk[-1] + 0.12, 0.6, fade_in=0.01, fade_out=0.35), 0.45)
fm = lib(os.path.join(L1, "Carl Gustav M45", "G_20P.wav"))
for k, t in enumerate(disparos(fm, 0.5)[:2], 1):
    grava("uzi_fire_far_%d" % k, fatia(fm, onset(fm, t), 0.9, fade_out=0.5) * 0.8)


# ======================= Recargas (OpenGameArt, CC0: SpringySpringo, BMacZero, zer0_sol) =======================
OGA = os.path.join(R, "raw", "audio_user", "oga")


def oga(n, ganho=1.0):
    x, sr = sf.read(os.path.join(OGA, n))
    m = x.mean(1) if x.ndim > 1 else x
    if sr != SR:
        m = resample_poly(m, SR, sr)
    return (m / max(float(np.abs(m).max()), 1e-6) * ganho).astype(np.float32)


print("== recargas CC0 ==")
ar = oga("assaultriflereload1_0.wav", 0.9)
gr = oga("gunreload1.wav", 0.9)
cock = oga("shotguncock_0.wav", 0.9)
c1, c2, sb = oga("clipload1.wav", 0.7), oga("clipload2.wav", 0.7), oga("singlebullet1.wav", 0.6)
grava("reload_ak47", mix(2.45, [(0.35, ar)]), 0.6)
grava("reload_usp", mix(2.2, [(0.3, oga("reload.wav", 0.9))]), 0.6)
grava("reload_mosin", mix(3.2, [(0.25, cock), (0.95, c1), (1.45, c2), (1.9, sb), (2.35, sb * 0.9), (2.55, cock * 0.9)]), 0.6)
grava("reload_m107", mix(3.8, [(0.3, gr), (2.3, cock), (3.1, cock * 0.8)]), 0.6)
grava("reload_uzi", mix(2.1, [(0.2, pitch(ar, 1 / 1.12))]), 0.6)
