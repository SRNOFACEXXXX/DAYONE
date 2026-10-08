# Nivela os sons de tiro: mesma loudness de ataque entre armas (calibre maior um pouco mais alto) e SEM clipping na rajada
# (as fatias se sobrepõem: antes a soma chegava a 1,9 de pico e o limitador do master distorcia). Roda depois de audio_usuario.py.
import soundfile as sf, numpy as np, glob, os
W = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio", "weapons")
SR = 48000
# arma: (prefixo das variações, período da rajada ou 0 = semi, alvo de loudness do ataque em dBFS, extras com o mesmo ganho)
ARMAS = {
    "m4": ("m4u_fire", 0.0843, -17.0, ["m4u_single", "m4u_cauda", "m4u_fire_far"]),
    "m249": ("m249u_fire", 0.0783, -16.5, ["m249u_cauda", "m249u_fire_far"]),
    "ak47": ("ak47u_fire", 0.0916, -16.5, ["ak47u_single", "ak47u_cauda", "ak47u_fire_far", "ak47u_single_far"]),
    "uzi": ("uzi_fire", 0.062, -18.0, ["uzi_cauda", "uzi_fire_far"]),
    "glock": ("glock_fire", 0, -18.0, ["glock_fire_far"]),
    "usp": ("usp_fire", 0, -17.5, ["usp_fire_far"]),
    "mosin": ("mosin_fire", 0, -15.0, ["mosin_fire_far"]),
    "m107": ("m107_fire", 0, -14.0, ["m107_fire_far"]),
}


def arquivos(pre):
    return sorted(f for f in glob.glob(os.path.join(W, pre + "_*.wav")) if os.path.basename(f)[len(pre) + 1:-4].isdigit())


def ataque_db(x):
    a = x[: int(0.12 * SR)]
    return 20 * np.log10(np.sqrt((a ** 2).mean()) + 1e-9)


def saturar(x, k):
    """Saturação suave (tanh): achata o pico do estampido e traz o corpo do tiro para frente, como no design de som de jogos."""
    pk = np.abs(x).max() + 1e-9
    return np.tanh(k * x / pk) / np.tanh(k) * pk


for arma, (pre, T, alvo, extras) in ARMAS.items():
    fs = arquivos(pre)
    clips = [sf.read(f)[0] for f in fs]
    clips = [c if c.ndim == 1 else c.mean(1) for c in clips]
    crista = np.mean([20 * np.log10(np.abs(c).max() / (np.sqrt((c[: int(0.12 * SR)] ** 2).mean()) + 1e-9)) for c in clips])
    if crista > 14.0:   # gravação de campo muito "pontuda": satura até a crista ficar ~12 dB
        k = min(4.0, 10 ** ((crista - 12.0) / 20))
        for f in fs:
            x, sr = sf.read(f)
            sf.write(f, saturar(x, k), sr, subtype="PCM_16")
        clips = [saturar(c, k) for c in clips]
        print("  %s crista %.1f dB -> saturação k=%.2f" % (arma, crista, k))
    atual = np.mean([ataque_db(c) for c in clips])
    g = 10 ** ((alvo - atual) / 20)
    if T > 0:   # rajada de 20 tiros: pico máximo 0,85
        out = np.zeros(int((20 * T + 1) * SR))
        for i in range(20):
            c = clips[i % len(clips)] * g
            s = int(i * T * SR)
            out[s:s + len(c)] += c[: len(out) - s]
        pk = np.abs(out).max()
    else:
        pk = max(np.abs(c).max() for c in clips) * g
    if pk > 0.85:
        g *= 0.85 / pk
    todos = list(fs)
    for e in extras:
        todos += arquivos(e) + ([os.path.join(W, e + ".wav")] if os.path.exists(os.path.join(W, e + ".wav")) else [])
    for f in todos:
        x, sr = sf.read(f)
        y = x * g
        if np.abs(y).max() > 0.95:
            y *= 0.95 / np.abs(y).max()
        sf.write(f, y, sr, subtype="PCM_16")
    print("%-6s ataque %.1f dB -> alvo %.1f  ganho %.2f  pico rajada %.2f  (%d arquivos)" % (arma, atual, alvo, g, min(pk, 0.85), len(todos)))
