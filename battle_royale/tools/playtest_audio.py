#!/usr/bin/env python
"""Análise de áudio do playtester (tests/playtest.gd).

Uso:  python tools/playtest_audio.py raw/playtest/01
Lê  : dados.json (eventos de áudio, medidores por bus, metricas) e audio_*.wav (gravações do Master/Music/SFX por etapa)
Grava: audio_analise.json  {wavs, ambiente, armas, mixagem, eventos, ids, achados[]}
Cada achado: {id, severidade, categoria, etapa, titulo, evidencia, captura}
As regras são objetivas e os limiares ficam em LIMITES (editáveis).
"""
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

import numpy as np
import soundfile as sf
from scipy import signal

LIMITES = {
    "silencio_dbfs": -60.0,          # janela de 100 ms abaixo disto = silêncio
    "ambiente_rms_min_dbfs": -48.0,  # ambiente mais baixo que isto = praticamente inaudível
    "ambiente_variacao_min_db": 1.5, # desvio-padrão do nível (janelas 1 s) abaixo disto = plano
    "cauda_min_s": 0.8,              # tempo de queda do último tiro até -40 dB do pico
    "pico_maximo_dbfs": -0.2,        # acima disto = encostando no 0 dBFS
    "tiro_vs_ambiente_max_db": 45.0, # tiro mais alto que o ambiente por mais disto = mixagem desproporcional
    "tiro_vs_ambiente_min_db": 6.0,
    "repeticao_seguida_max": 2,      # mesmo arquivo tocado N vezes seguidas
    "arquivos_min_por_id_frequente": 2,
}

K1_B = [1.53512485958697, -2.69169618940638, 1.19839281085285]
K1_A = [1.0, -1.69065929318241, 0.73248077421585]
K2_B = [1.0, -2.0, 1.0]
K2_A = [1.0, -1.99004745483398, 0.99007225036621]


def limpa_json(txt):
    return json.loads(re.sub(r'(?<=[:\[,\s])-?(inf|nan)\b', 'null', txt))


def db(x, piso=-120.0):
    return 20.0 * math.log10(x) if x > 1e-6 else piso


def mono(y):
    return y.mean(axis=1) if y.ndim > 1 else y


def lufs_integrado(y, sr):
    """LUFS aproximado (BS.1770 K-weighting, blocos de 400 ms, gates -70 e -10 LU)."""
    if sr != 48000:
        y = signal.resample_poly(y, 48000, sr, axis=0)
        sr = 48000
    ch = y if y.ndim > 1 else y[:, None]
    z = signal.lfilter(K1_B, K1_A, ch, axis=0)
    z = signal.lfilter(K2_B, K2_A, z, axis=0)
    n = int(0.4 * sr)
    hop = int(0.1 * sr)
    if len(z) < n:
        return None
    bl = []
    for i in range(0, len(z) - n + 1, hop):
        ms = np.mean(z[i:i + n] ** 2, axis=0)
        bl.append(float(np.sum(ms)))
    bl = np.array(bl)
    lk = -0.691 + 10 * np.log10(np.maximum(bl, 1e-12))
    ok = lk > -70
    if not ok.any():
        return None
    rel = -0.691 + 10 * np.log10(np.mean(bl[ok])) - 10
    ok2 = lk > rel
    if not ok2.any():
        return None
    return float(-0.691 + 10 * np.log10(np.mean(bl[ok2])))


def bandas(m, sr):
    f, p = signal.welch(m, sr, nperseg=min(8192, len(m)))
    tot = float(np.sum(p)) + 1e-20
    lim = [(0, 60, "sub"), (60, 250, "grave"), (250, 2000, "medio"), (2000, 8000, "agudo"), (8000, sr / 2, "ar")]
    out = {}
    for a, b, nome in lim:
        sel = (f >= a) & (f < b)
        out[nome] = round(100.0 * float(np.sum(p[sel])) / tot, 2)
    cent = float(np.sum(f * p) / tot)
    return out, cent


def janelas_rms_db(m, sr, seg):
    n = max(1, int(seg * sr))
    r = []
    for i in range(0, len(m) - n + 1, n):
        r.append(db(float(np.sqrt(np.mean(m[i:i + n] ** 2)))))
    return np.array(r)


def analisa_wav(caminho):
    y, sr = sf.read(caminho, always_2d=True)
    y = y.astype(np.float64)
    m = mono(y)
    dur = len(m) / sr
    r = {"arquivo": os.path.basename(caminho), "duracao_s": round(dur, 2), "taxa": sr, "canais": y.shape[1]}
    if len(m) < sr * 0.2:
        r["vazio"] = True
        return r
    pico = float(np.max(np.abs(y)))
    r["pico_dbfs"] = round(db(pico), 2)
    r["rms_dbfs"] = round(db(float(np.sqrt(np.mean(m ** 2)))), 2)
    r["clip_amostras"] = int(np.sum(np.abs(y) >= 0.999))
    r["lufs_aprox"] = None
    try:
        l = lufs_integrado(y, sr)
        r["lufs_aprox"] = round(l, 2) if l is not None else None
    except Exception as e:  # noqa
        r["lufs_erro"] = str(e)
    j100 = janelas_rms_db(m, sr, 0.1)
    r["silencio_pct"] = round(100.0 * float(np.mean(j100 < LIMITES["silencio_dbfs"])), 1) if len(j100) else None
    j1 = janelas_rms_db(m, sr, 1.0)
    r["rms_1s_media_db"] = round(float(np.mean(j1)), 2) if len(j1) else None
    r["rms_1s_desvio_db"] = round(float(np.std(j1)), 2) if len(j1) > 1 else None
    r["rms_1s_min_max_db"] = [round(float(np.min(j1)), 1), round(float(np.max(j1)), 1)] if len(j1) else None
    b, c = bandas(m, sr)
    r["bandas_pct"] = b
    r["centroide_espectral_hz"] = round(c, 0)
    r["dc_offset"] = round(float(np.mean(m)), 6)
    return r


def cauda_do_ultimo_tiro(m, sr, t_ultimo_s):
    """Depois do último tiro: tempo até o envelope (janelas 20 ms, RMS) cair 20/40 dB abaixo do pico do tiro."""
    i0 = int(t_ultimo_s * sr)
    seg = m[i0:i0 + int(6 * sr)]
    if len(seg) < sr * 0.3:
        return None
    n = int(0.02 * sr)
    env = np.array([db(float(np.sqrt(np.mean(seg[i:i + n] ** 2)))) for i in range(0, len(seg) - n, n)])
    pk = float(np.max(env[:max(1, int(0.3 / 0.02))]))
    ipk = int(np.argmax(env[:max(1, int(0.3 / 0.02))]))
    res = {"pico_env_db": round(pk, 1)}
    for queda in (20, 40):
        alvo = pk - queda
        t = None
        for k in range(ipk, len(env)):
            if env[k] <= alvo and np.all(env[k:k + 5] <= alvo + 3):
                t = (k - ipk) * 0.02
                break
        res["t_queda_%ddb_s" % queda] = round(t, 2) if t is not None else None
    res["nivel_apos_5s_db"] = round(float(env[min(len(env) - 1, int(5.0 / 0.02))]), 1) if len(env) > 10 else None
    return res


def main(pasta):
    dados = limpa_json(open(os.path.join(pasta, "dados.json"), encoding="utf8").read())
    ev = dados.get("audio_eventos", [])
    ext = dados.get("audio_externos", [])
    bus = dados.get("bus_amostras", [])
    met = dados.get("metricas", {})
    existentes = set(dados.get("ids_som_existentes", []))
    out = {"limites": LIMITES, "wavs": {}, "achados": []}
    ach = out["achados"]

    def achado(id_, sev, cat, etapa, titulo, evid, cap=""):
        ach.append({"id": id_, "severidade": sev, "categoria": cat, "etapa": etapa, "titulo": titulo, "evidencia": evid, "captura": cap})

    # ---------------------------------------------------------------- WAVs
    wavs = {}
    for f in sorted(os.listdir(pasta)):
        if f.startswith("audio_") and f.endswith(".wav"):
            try:
                wavs[f] = analisa_wav(os.path.join(pasta, f))
            except Exception as e:  # noqa
                wavs[f] = {"erro": str(e)}
    out["wavs"] = wavs
    for f, w in wavs.items():
        if w.get("pico_dbfs") is not None and w["pico_dbfs"] >= LIMITES["pico_maximo_dbfs"]:
            achado("AUDIO_PICO_0DBFS", "alto", "Áudio armas", f, "Pico de %.2f dBFS em %s (limiter em -0,5 dB encostando no 0)" % (w["pico_dbfs"], f),
                   {"pico_dbfs": w["pico_dbfs"], "clip_amostras": w.get("clip_amostras")})
        if w.get("clip_amostras", 0) > 20:
            achado("AUDIO_CLIPPING", "alto", "Áudio armas", f, "%d amostras em clipping em %s" % (w["clip_amostras"], f), {"clip_amostras": w["clip_amostras"]})

    # ---------------------------------------------------------------- ambiente
    amb = {}
    est = met.get("som", {}).get("estado_audio", {})
    amb["estado"] = est.get("ambiente")
    amb["buses"] = est.get("buses")
    amb["volumes_settings"] = est.get("volumes_settings")
    for tag, arq_master, arq_music in [("usuario", "audio_som_quieto_master.wav", "audio_som_quieto_music.wav"),
                                      ("volume_padrao", "audio_som_quieto_padrao_master.wav", "audio_som_quieto_padrao_music.wav")]:
        if arq_master in wavs and not wavs[arq_master].get("vazio"):
            amb[tag] = {"master": wavs[arq_master], "music": wavs.get(arq_music)}
    mestre_usuario = wavs.get("audio_som_quieto_master.wav")
    if mestre_usuario and not mestre_usuario.get("vazio"):
        if mestre_usuario["rms_dbfs"] < LIMITES["ambiente_rms_min_dbfs"]:
            achado("AMBIENTE_INAUDIVEL", "critico", "Áudio ambiente", "som",
                   "Com as configurações do usuário, o Master em silêncio de jogo mede %.1f dBFS RMS (limite audível %.0f): não há som ambiente audível" % (mestre_usuario["rms_dbfs"], LIMITES["ambiente_rms_min_dbfs"]),
                   {"rms_dbfs": mestre_usuario["rms_dbfs"], "pico_dbfs": mestre_usuario["pico_dbfs"], "silencio_pct": mestre_usuario["silencio_pct"], "arquivo": "audio_som_quieto_master.wav"})
    ref = wavs.get("audio_som_quieto_padrao_music.wav") or wavs.get("audio_som_quieto_music.wav")
    ref_nome = "audio_som_quieto_padrao_music.wav" if "audio_som_quieto_padrao_music.wav" in wavs else "audio_som_quieto_music.wav"
    amb["referencia_do_som_em_si"] = ref_nome
    if ref and not ref.get("vazio"):
        if ref["rms_dbfs"] < LIMITES["ambiente_rms_min_dbfs"] and "padrao" in ref_nome:
            achado("AMBIENTE_MUITO_BAIXO", "alto", "Áudio ambiente", "som",
                   "Mesmo com music_volume padrão (0,55) o ambiente mede %.1f dBFS RMS: baixo demais para ser percebido" % ref["rms_dbfs"], {"rms_dbfs": ref["rms_dbfs"], "arquivo": ref_nome})
        if ref.get("rms_1s_desvio_db") is not None and ref["rms_1s_desvio_db"] < LIMITES["ambiente_variacao_min_db"] and ref["rms_dbfs"] > -70:
            achado("AMBIENTE_PLANO", "medio", "Áudio ambiente", "som",
                   "O ambiente varia só %.2f dB (desvio de janelas de 1 s) em %.0f s: som plano/sem eventos (vento, animais, distantes)" % (ref["rms_1s_desvio_db"], ref["duracao_s"]),
                   {"desvio_db": ref["rms_1s_desvio_db"], "min_max_db": ref["rms_1s_min_max_db"], "centroide_hz": ref["centroide_espectral_hz"], "bandas": ref["bandas_pct"], "arquivo": ref_nome})
    out["ambiente"] = amb

    # ---------------------------------------------------------------- armas: cauda real no WAV
    armas = {}
    arq_t = "audio_som_tiros_master.wav"
    if arq_t in wavs and not wavs[arq_t].get("vazio"):
        y, sr = sf.read(os.path.join(pasta, arq_t), always_2d=True)
        m = mono(y.astype(np.float64))
        t0 = met.get("som", {}).get("tiros", {}).get("t0", 0.0)
        ev_t = [e for e in ev if e.get("etapa") == "som" and t0 <= e["t"] <= met.get("som", {}).get("tiros", {}).get("t1", 1e9) and str(e["id"]).startswith("ak47_t2_perto") or
                (e.get("etapa") == "som" and t0 <= e["t"] and str(e["id"]).startswith("ak47_t2_fatia"))]
        # último tiro de AK = último evento ak47_t2_perto/fatia/mec
        ak = [e["t"] - t0 for e in ev if e.get("etapa") == "som" and str(e["id"]).startswith("ak47_t2_") and not str(e["id"]).endswith("cauda") and e["t"] >= t0]
        gl = [e["t"] - t0 for e in ev if e.get("etapa") == "som" and str(e["id"]).startswith("glock_t2_") and not str(e["id"]).endswith("cauda") and e["t"] >= t0]
        if ak:
            armas["ak47_ultimo_tiro_t"] = round(max(ak), 2)
            c = cauda_do_ultimo_tiro(m, sr, max(ak))
            armas["ak47_cauda"] = c
            if c and c.get("t_queda_40db_s") is not None and c["t_queda_40db_s"] < LIMITES["cauda_min_s"]:
                achado("ARMA_CAUDA_CURTA", "medio", "Áudio armas", "som",
                       "AK: o som cai 40 dB em %.2f s após o último tiro (< %.1f s): cauda/eco curto demais para campo aberto" % (c["t_queda_40db_s"], LIMITES["cauda_min_s"]), c)
        if gl:
            armas["glock_ultimo_tiro_t"] = round(max(gl), 2)
            armas["glock_cauda"] = cauda_do_ultimo_tiro(m, sr, max(gl))
        armas["pico_dbfs"] = wavs[arq_t].get("pico_dbfs")
        armas["lufs_aprox"] = wavs[arq_t].get("lufs_aprox")
    out["armas"] = armas

    # ---------------------------------------------------------------- mixagem tiro x ambiente (WAV + medidores)
    mix = {}
    ref_amb = None
    for k in ("audio_som_quieto_padrao_master.wav", "audio_som_quieto_master.wav"):
        if k in wavs and not wavs[k].get("vazio"):
            ref_amb = wavs[k]["rms_dbfs"]
            mix["ambiente_referencia"] = k
            break
    if "audio_som_tiros_master.wav" in wavs and ref_amb is not None:
        pk = wavs["audio_som_tiros_master.wav"]["pico_dbfs"]
        mix["ambiente_rms_dbfs"] = ref_amb
        mix["tiro_pico_dbfs"] = pk
        mix["tiro_pico_menos_ambiente_db"] = round(pk - ref_amb, 1)
        if pk - ref_amb > LIMITES["tiro_vs_ambiente_max_db"]:
            achado("MIX_TIRO_MUITO_ALTO_VS_AMBIENTE", "medio", "Áudio armas", "som",
                   "Pico do tiro %.1f dB acima do ambiente (limite %.0f dB): o tiro 'esmaga' o resto da mixagem" % (pk - ref_amb, LIMITES["tiro_vs_ambiente_max_db"]), mix)
    # pelos medidores de pico por bus (etapa combate): Tiros/SFX vs Music
    por_etapa = defaultdict(list)
    for a in bus:
        por_etapa[a["etapa"]].append(a["db"])
    resumo_bus = {}
    for et, lst in por_etapa.items():
        r = {}
        for b in ("Master", "SFX", "Music", "Tiros", "Voice", "UI"):
            vals = [x[b] for x in lst if b in x and x[b] > -79.0]
            r[b] = {"max": round(max(vals), 1), "media": round(float(np.mean(vals)), 1)} if vals else {"max": None, "media": None, "amostras_acima_de_-79": 0}
        resumo_bus[et or "fora_de_etapa"] = r
    mix["medidores_por_bus_e_etapa"] = resumo_bus
    out["mixagem"] = mix

    # ---------------------------------------------------------------- eventos
    c_id = Counter()
    por_id = defaultdict(list)
    for e in ev:
        if e["tipo"] == "faltando":
            continue
        c_id[e["id"]] += 1
        por_id[e["id"]].append(e)
    faltando = Counter(e["id"] for e in ev if e["tipo"] == "faltando")
    out["ids_tocados"] = dict(c_id.most_common())
    out["ids_pedidos_e_inexistentes_em_tempo_de_execucao"] = dict(faltando)
    for id_, n in faltando.items():
        etapas = sorted({e["etapa"] for e in ev if e["tipo"] == "faltando" and e["id"] == id_})
        achado("SOM_INEXISTENTE_" + id_, "alto", "Áudio ambiente" if id_ in ("splash",) else "Áudio armas" if "reload" in id_ or "fire" in id_ else "Zumbis áudio" if "zombie" in id_ else "Passos" if id_.startswith("step") else "Áudio ambiente",
               "/".join(etapas), "O jogo pede o som '%s' (%d vezes) e ele não existe em assets/audio" % (id_, n), {"id": id_, "pedidos": n, "etapas": etapas})
    # repetição e variação
    repet = {}
    for id_, lst in por_id.items():
        arqs = [e.get("arquivo") for e in lst]
        n = len(arqs)
        seg = 0
        melhor = 0
        for i in range(1, n):
            if arqs[i] == arqs[i - 1] and arqs[i]:
                seg += 1
                melhor = max(melhor, seg + 1)
            else:
                seg = 0
        pitches = [e.get("pitch") for e in lst if e.get("pitch") is not None]
        repet[id_] = {"usos": n, "arquivos_distintos": len(set(arqs)), "maior_sequencia_identica": melhor,
                      "pitch_desvio": round(float(np.std(pitches)), 4) if pitches else None}
        if n >= 6 and len(set(arqs)) < LIMITES["arquivos_min_por_id_frequente"]:
            achado("SOM_UM_ARQUIVO_SO_" + id_, "medio", "Passos" if id_.startswith("step") else "Áudio armas",
                   "/".join(sorted({e["etapa"] for e in lst})), "'%s' tocou %d vezes com um único arquivo (%s): sem variação" % (id_, n, arqs[0]),
                   {"usos": n, "arquivo": arqs[0], "pitch_desvio": repet[id_]["pitch_desvio"]})
        elif melhor > LIMITES["repeticao_seguida_max"] + 1 and len(set(arqs)) >= 2 and not id_.startswith("step"):
            achado("SOM_REPETIDO_SEGUIDO_" + id_, "baixo", "Áudio armas", "/".join(sorted({e["etapa"] for e in lst})),
                   "'%s' repetiu o mesmo arquivo %d vezes seguidas" % (id_, melhor), repet[id_])
    out["variacao_por_id"] = repet

    # tiros: camadas por arma (etapa combate): cauda e eco
    por_arma = {}
    for arma, r in met.get("combate", {}).get("armas", {}).items():
        por_arma[arma] = {"sons_por_id": r.get("sons_por_id"), "tem_cauda": r.get("tem_cauda"), "arquivos_distintos": r.get("arquivos_distintos"),
                          "intervalo_medido_s": r.get("intervalo_medido_s")}
    out["armas_camadas"] = por_arma

    # passos: cadência e intervalos regulares (caminhada de 60 m)
    andar = met.get("andar", {})
    cm = andar.get("caminhada_60m", {})
    pas = andar.get("passos_na_caminhada", {})
    passos = {"na_caminhada": pas}
    st = sorted([e["t"] for e in ev if e.get("etapa") == "andar" and str(e["id"]).startswith("step_")])
    if len(st) > 6:
        ints = np.diff(st[:40])
        ints = ints[ints < 2.0]
        if len(ints):
            passos["intervalo_medio_s"] = round(float(np.mean(ints)), 3)
            passos["intervalo_desvio_s"] = round(float(np.std(ints)), 3)
            passos["velocidade_media_m_s"] = cm.get("vel_media")
            if cm.get("vel_media"):
                passos["metros_por_passo"] = round(float(cm["vel_media"]) * float(np.mean(ints)), 2)
    if pas and pas.get("eventos", 0) == 0 and cm.get("distancia_m", 0) > 10:
        achado("PASSOS_FALTANDO", "critico", "Passos", "andar", "Andou %.0f m e nenhum som de passo foi tocado" % cm["distancia_m"], pas)
    elif pas and pas.get("por_metro") is not None:
        r = pas["por_metro"] / max(pas.get("esperado_por_metro", 0.49), 1e-6)
        passos["razao_cadencia_vs_esperada"] = round(r, 2)
        if r < 0.7 or r > 1.4:
            achado("PASSOS_CADENCIA_FORA", "medio", "Passos", "andar",
                   "Cadência de passos %.2f por metro (esperado ~%.2f pela regra do código; razão %.2f)" % (pas["por_metro"], pas.get("esperado_por_metro", 0.49), r), pas)
    out["passos"] = passos

    # por superfície (etapa andar): cada superfície visitada deve ter arquivo e tocar
    sup = andar.get("passos_por_superficie", [])
    out["passos_por_superficie"] = sup

    # zumbis
    zum = {}
    ev_z = [e for e in ev if str(e["id"]).startswith("zombie") or "groan" in str(e["id"]) or "scream" in str(e["id"])]
    zum["eventos"] = len(ev_z)
    zum["por_etapa"] = dict(Counter(e["etapa"] for e in ev_z))
    zum["ids_zombie_existentes"] = sorted(i for i in existentes if "zomb" in i or "groan" in i)
    zum["arquivos_zumbi_existentes_em_assets"] = os.listdir(os.path.join(pasta, "..", "..", "..", "game", "assets", "audio", "zombie")) if os.path.isdir(os.path.join(pasta, "..", "..", "..", "game", "assets", "audio", "zombie")) else []
    out["zumbis"] = zum

    # veículos
    car = met.get("carro", {})
    out["carro"] = {"conducao": car.get("conducao"), "som_de_motor_detectado": car.get("som_de_motor_detectado")}
    if "audio_etapa_carro_master.wav" in wavs and not wavs["audio_etapa_carro_master.wav"].get("vazio"):
        out["carro"]["wav_master"] = wavs["audio_etapa_carro_master.wav"]

    # ids pedidos pelo código (estático) que não existem
    out["estatico"] = varre_codigo(pasta, existentes)
    json.dump(out, open(os.path.join(pasta, "audio_analise.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print("AUDIO_ANALISE_OK", pasta, "wavs=%d achados=%d" % (len(wavs), len(ach)))
    return out


def varre_codigo(pasta, existentes):
    """Procura no código-fonte os ids literais pedidos a Audio.* e compara com a biblioteca real (Audio._library)."""
    raiz = os.path.abspath(os.path.join(pasta, "..", "..", "..", "game"))
    pedidos = defaultdict(set)
    guardados = defaultdict(set)
    pat = re.compile(r'Audio\.(play|play_at|ui|voice|music|ambient|has_sound)\(\s*"([A-Za-z0-9_]+)"')
    for d, _, fs in os.walk(raiz):
        if os.sep + "tests" in d or os.sep + ".godot" in d or os.sep + "assets" in d:
            continue
        for f in fs:
            if not f.endswith(".gd"):
                continue
            rel = os.path.relpath(os.path.join(d, f), raiz).replace("\\", "/")
            try:
                t = open(os.path.join(d, f), encoding="utf8", errors="ignore").read()
            except OSError:
                continue
            for m in pat.finditer(t):
                (guardados if m.group(1) == "has_sound" else pedidos)[m.group(2)].add(rel)
    res = {"pedidos_sem_arquivo": {}, "has_sound_sem_arquivo": {}}
    if not existentes:
        return res
    for id_, arq in sorted(pedidos.items()):
        if id_ not in existentes and not id_.endswith("_"):
            res["pedidos_sem_arquivo"][id_] = sorted(arq)
    for id_, arq in sorted(guardados.items()):
        if id_ not in existentes and not id_.endswith("_"):
            res["has_sound_sem_arquivo"][id_] = sorted(arq)
    return res


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
