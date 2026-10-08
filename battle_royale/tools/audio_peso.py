# Sons de tiro "de simulador" (peso + propagação) -> game/assets/audio/weapons/t2/<arma>_t2_<camada>_N.wav
# Fonte: Free Firearm Sound Library (royalty-free, sem atribuição; tratada como CC0) copiada em Assets/sons_novos/.
# Camadas por arma (tocadas por game/core/tiro_som.gd):
#   perto        estampido seco + reforço grave + "thump" sintetizado (sub 38-80 Hz), compressão e limitador (pico <= 0,95)
#   fatia        o mesmo, em fatias de 2,4 períodos com fade cruzado (rajada automática sem cortes)
#   mec          ferrolho/ação (cliques metálicos sintetizados, curtos)
#   cauda        eco/reverberação de campo aberto (IR sintética: reflexos do chão/mata + cauda difusa, 1,3-2,6 s), só "molhado"
#   longe        perspectiva distante (gravação "mid distance" filtrada + mais reverb); longe_fatia = versão curta p/ rajada
# Uso: python tools/audio_peso.py   (depois: Godot --headless --import --path game)
import os, json, numpy as np, soundfile as sf
from fractions import Fraction
from scipy.signal import butter, sosfilt, fftconvolve, resample_poly, find_peaks, lfilter
from scipy.ndimage import minimum_filter1d, uniform_filter1d

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(R, "Assets", "sons_novos", "free_firearm_sound_library")
OUT = os.path.join(R, "game", "assets", "audio", "weapons", "t2")
SR = 48000
TETO = 0.95
rng = np.random.default_rng(7)

# arma: perto, longe (mid), rajada perto, rajada longe, T (0 = semi), tom, thump f0, tau, ganho thump, RT60 da cauda, alvo ataque (dBFS, 50 ms)
ARMAS = {
    "ak47": dict(near="AK-47/C_28P.wav", mid="AK-47/C_31P.wav", raj="AK-47/C_27P.wav", rajm="AK-47/C_36P.wav", T=0.0916, tom=1.0, f0=52, tau=0.12, th=0.65, rt=2.0, alvo=-8.0),
    "m4": dict(near="AR-15/D_32P.wav", mid="AR-15/D_24P.wav", raj=None, rajm=None, T=0.0843, tom=1.0, f0=60, tau=0.10, th=0.55, rt=1.9, alvo=-8.5),
    "m249": dict(near="AR-15/D_32P.wav", mid="AR-15/D_24P.wav", raj=None, rajm=None, T=0.0783, tom=0.93, f0=50, tau=0.11, th=0.65, rt=2.0, alvo=-8.0),
    "m107": dict(near="Tikka/W_29P.wav", mid="Tikka/W_24P.wav", raj=None, rajm=None, T=0, tom=0.78, f0=36, tau=0.22, th=0.9, rt=2.6, alvo=-6.0),
    "mosin": dict(near="Mosin Nagant/M_21P.wav", mid="Mosin Nagant/M_26P.wav", raj=None, rajm=None, T=0, tom=1.0, f0=44, tau=0.16, th=0.7, rt=2.3, alvo=-7.0),
    "glock": dict(near="Walther PPQ/X_39P.wav", mid="Walther PPQ/X_31P.wav", raj=None, rajm=None, T=0, tom=1.0, f0=80, tau=0.06, th=0.4, rt=1.3, alvo=-10.5),
    "usp": dict(near="1911/A_42P.wav", mid="1911/A_34P.wav", raj=None, rajm=None, T=0, tom=1.0, f0=70, tau=0.07, th=0.45, rt=1.4, alvo=-10.0),
    "uzi": dict(near="Carl Gustav M45/G_31P.wav", mid="Carl Gustav M45/G_20P.wav", raj="Carl Gustav M45/G_35P.wav", rajm="Carl Gustav M45/G_24P.wav", T=0.062, tom=1.0, f0=72, tau=0.06, th=0.4, rt=1.5, alvo=-10.5),
}


def lib_tom(rel, tom):
    x, sr = sf.read(os.path.join(SRC, rel))
    m = x.mean(1) if x.ndim > 1 else x
    m = resample_poly(m, SR, sr)
    if tom != 1.0:
        fr = Fraction(tom).limit_denominator(100)
        m = resample_poly(m, fr.denominator, fr.numerator)
    return m.astype(np.float64)


def sos(kind, fc, o=2):
    return butter(o, fc, kind, fs=SR, output="sos")


def lp(x, fc, o=2):
    return sosfilt(sos("low", fc, o), x)


def hp(x, fc, o=2):
    return sosfilt(sos("high", fc, o), x)


def bp(x, a, b, o=2):
    return sosfilt(butter(o, [a, b], "band", fs=SR, output="sos"), x)


def env(m, ms=2.0):
    w = max(1, int(SR * ms / 1000))
    return np.sqrt(uniform_filter1d(m ** 2, w))


def disparos(m, dist=0.035, h=0.3):
    e = env(m)
    pk, _ = find_peaks(e, height=h * e.max(), distance=int(dist * SR))
    return pk / SR


def onset(m, t, jan=0.02):
    a, b = max(0, int((t - jan) * SR)), int((t + jan) * SR)
    e = np.abs(m[a:b])
    k = int(np.argmax(e))
    i = int(np.argmax(e[:k + 1] > 0.35 * e[k]))
    return (a + i) / SR - 0.002


def corta(m, t0, dur, fi=0.0015, fo=None):
    s = m[int(t0 * SR): int((t0 + dur) * SR)].copy()
    fi, fo = int(fi * SR), int((fo if fo is not None else dur * 0.3) * SR)
    s[:fi] *= np.linspace(0, 1, fi)
    s[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    return s


def thump(f0, tau, n):
    t = np.arange(n) / SR
    f = f0 * (1 + 1.4 * np.exp(-t / 0.010))            # queda de tom rápida = "soco" no peito
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / tau)
    n = lp(rng.standard_normal(len(t)), 350) * np.exp(-t / 0.007)
    s = s + 0.35 * n / (np.abs(n).max() + 1e-9)
    s[: int(0.0012 * SR)] *= np.linspace(0, 1, int(0.0012 * SR))
    return s / (np.abs(s).max() + 1e-9)


def compressor(x, thr_db=-18.0, ratio=3.0, rel=0.07):
    a = np.exp(-1.0 / (rel * SR))
    lvl = np.maximum(env(x, 1.0), 1e-9)
    e = np.maximum(lfilter([1 - a], [1, -a], lvl), lvl)     # ataque instantâneo, liberação de 70 ms
    db = 20 * np.log10(e)
    red = np.minimum(0.0, (thr_db - db) * (1 - 1 / ratio))
    return x * 10 ** (red / 20)


def limitador(x, teto=TETO):
    g = np.minimum(1.0, teto / np.maximum(np.abs(x), 1e-9))
    g = minimum_filter1d(g, 97)                               # ~1 ms de antecipação para os dois lados
    g = uniform_filter1d(g, 49)
    g = np.minimum(g, minimum_filter1d(np.minimum(1.0, teto / np.maximum(np.abs(x), 1e-9)), 3))
    return np.clip(x * g, -teto, teto)


def ataque_db(x, jan=0.05):
    a = x[: int(jan * SR)]
    return 20 * np.log10(np.sqrt((a ** 2).mean()) + 1e-12)


def ir_campo(rt, seed):
    r = np.random.default_rng(seed)
    n = int((rt + 0.4) * SR)
    t = np.arange(n) / SR
    ir = np.zeros(n)
    for lo, hi, k in [(40, 500, 1.0), (500, 2500, 0.7), (2500, 9000, 0.4)]:   # agudos morrem antes (ar + mata)
        b = bp(r.standard_normal(n), lo, hi)
        ir += b * np.exp(-6.91 * t / (rt * k)) * (1.0 if lo == 40 else 0.6)
    ir[: int(0.03 * SR)] = 0
    ir[int(0.03 * SR): int(0.09 * SR)] *= np.linspace(0, 1, int(0.06 * SR))
    for _ in range(7):                                        # reflexos discretos: chão, casas, linha de árvores
        d = r.uniform(0.045, 0.42)
        ir[int(d * SR)] += r.uniform(0.25, 0.7) * np.exp(-d / 0.5) * 40 / np.sqrt(len(ir))
    ir = lp(ir, 6000)
    return ir / np.sqrt((ir ** 2).sum())


def cauda(dry, rt, seed):
    w = fftconvolve(dry[: int(0.3 * SR)], ir_campo(rt, seed))[: int((rt + 0.3) * SR)]
    w[: int(0.025 * SR)] = 0
    w[int(0.025 * SR): int(0.06 * SR)] *= np.linspace(0, 1, int(0.035 * SR))
    fo = int(len(w) * 0.45)
    w[-fo:] *= np.linspace(1, 0, fo) ** 2
    return w


def processa(dry, c, ganho=None, dur_th=None):
    x = hp(dry, 30)
    x = x + 0.5 * lp(x, 170) + 0.6 * hp(x, 2500)        # corpo grave + estalo (crack) do disparo                                  # reforço grave (corpo do calibre)
    pk = np.abs(x).max()
    th = thump(c["f0"], min(c["tau"], dur_th or 9), len(x))
    x = x + 0.45 * c["th"] * pk * th   # thump presente sem afogar o estalo
    x = compressor(x / (np.abs(x).max() + 1e-9), -16.0, 3.0)
    x = np.tanh(1.6 * x / (np.abs(x).max() + 1e-9)) / np.tanh(1.6)
    if ganho is None:
        ganho = 10 ** ((c["alvo"] - ataque_db(x)) / 20)
    return limitador(x * ganho), ganho


def grava(nome, s):
    s = np.clip(s, -TETO, TETO)
    sf.write(os.path.join(OUT, nome + ".wav"), s.astype(np.float32), SR, subtype="PCM_16")


def mec(arma, k):
    t = np.arange(int(0.12 * SR)) / SR
    def clique(f, dec, amp):
        n = bp(rng.standard_normal(len(t)), f * 0.6, min(f * 1.8, 20000))
        return amp * (n / (np.abs(n).max() + 1e-9) * np.exp(-t / dec) + 0.4 * np.sin(2 * np.pi * f * 1.07 * t) * np.exp(-t / (dec * 3)))
    def em(s, d):
        o = np.zeros(len(t)); i = int(d * SR); o[i:] += s[: len(t) - i]; return o
    v = 1 + (k - 1) * 0.04
    if arma in ("mosin", "m107"):
        s = clique(2600 * v, 0.004, 1.0)
    elif arma in ("glock", "usp"):
        s = clique(3800 * v, 0.003, 1.0) + em(clique(2900 * v, 0.005, 0.8), 0.028)
    else:
        s = clique(3200 * v, 0.003, 1.0) + em(clique(2300 * v, 0.006, 0.9), 0.045 + 0.005 * k)
    return s / np.abs(s).max() * 0.35


def variacoes(m, dist=0.5, maxn=4, h=0.3):
    ts = list(disparos(m, dist, h))[:maxn]
    return [onset(m, t) for t in ts]


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".wav"):
            os.remove(os.path.join(OUT, f))           # pasta gerada por este script (não contém áudio do usuário)
    resumo = {}
    for arma, c in ARMAS.items():
        near = lib_tom(c["near"], c["tom"])
        mid = lib_tom(c["mid"], c["tom"])
        T = c["T"]
        ts = variacoes(near)
        pertos, ganho = [], None
        for t0 in ts:
            s, ganho = processa(corta(near, t0, 0.6, fo=0.3), c, ganho)
            pertos.append(s)
        while len(pertos) < 3:                        # completa variações com tom ±3%
            f = [0.97, 1.03][len(pertos) % 2]
            fr = Fraction(f).limit_denominator(100)
            pertos.append(limitador(resample_poly(pertos[0], fr.denominator, fr.numerator)))
        for k, s in enumerate(pertos, 1):
            grava("%s_t2_perto_%d" % (arma, k), s)
        if T > 0:
            if c["raj"]:
                rj = lib_tom(c["raj"], c["tom"])
                pk = list(disparos(rj, T * 0.7, 0.25))
                idx = [i for i in (3, 5, 7, 9, 2, 4, 6, 1) if i < len(pk) - 1][:4]
                fonte = [(rj, onset(rj, pk[i], 0.012)) for i in idx] if len(idx) >= 2 else [(near, t0) for t0 in ts]
                print("  rajada", arma, len(pk), "disparos")
            else:
                fonte = [(near, t0) for t0 in ts]
            fatias = [processa(corta(m, t0, T * 2.4, fo=T), c, ganho, dur_th=T * 0.9)[0] for m, t0 in fonte[:4]]
            while len(fatias) < 3:                    # tom ±3% para não repetir a mesma fatia
                fr = Fraction([0.97, 1.03][len(fatias) % 2]).limit_denominator(100)
                fatias.append(limitador(resample_poly(fatias[0], fr.denominator, fr.numerator)))
            for k, s in enumerate(fatias, 1):
                grava("%s_t2_fatia_%d" % (arma, k), s)
        for k in (1, 2, 3):
            grava("%s_t2_mec_%d" % (arma, k), mec(arma, k))
        for k in (1, 2, 3):
            w = cauda(pertos[(k - 1) % len(pertos)], c["rt"], 100 + k)
            w *= 10 ** ((c["alvo"] - 10.0 - 20 * np.log10(np.sqrt((w[: int(0.6 * SR)] ** 2).mean()) + 1e-12)) / 20)
            grava("%s_t2_cauda_%d" % (arma, k), limitador(w))
        tm = variacoes(mid, 0.5, 3, 0.25)
        for k, t0 in enumerate(tm, 1):
            s = corta(mid, t0, 1.2, fo=0.5)
            s = lp(hp(s, 70), 1700)
            w = cauda(s, c["rt"] * 1.25, 200 + k)
            s = np.concatenate([s, np.zeros(len(w) - len(s))]) if len(w) > len(s) else s[: len(w)]
            s = s / (np.abs(s).max() + 1e-9) + 0.9 * w / (np.abs(w).max() + 1e-9)
            s = compressor(s / np.abs(s).max(), -20.0, 3.0)
            s = s * 10 ** ((c["alvo"] - 2.0 - ataque_db(s, 0.08)) / 20)
            grava("%s_t2_longe_%d" % (arma, k), limitador(s))
            if T > 0:
                f = corta(lp(hp(mid, 70), 1700), t0, T * 2.6, fo=T * 1.2)
                f = f * 10 ** ((c["alvo"] - 2.0 - ataque_db(f, 0.04)) / 20)
                grava("%s_t2_longe_fatia_%d" % (arma, k), limitador(f))
        resumo[arma] = {"variacoes_perto": len(pertos), "longe": len(tm), "ganho": round(float(ganho), 2)}
        print(arma, resumo[arma])
    for f in os.listdir(OUT):                         # .import órfãos (variações que deixaram de existir)
        if f.endswith(".wav.import") and not os.path.exists(os.path.join(OUT, f[:-7])):
            os.remove(os.path.join(OUT, f))
    print(json.dumps(resumo))


if __name__ == "__main__":
    main()
