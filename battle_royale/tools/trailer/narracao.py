"""Gera a narração do trailer (edge-tts, voz neural gratuita) e as falas de rádio.
Saída: raw/trailer/voz/*.mp3 (+ duração em voz/_duracoes.json). Uso: python tools/trailer/narracao.py
"""
import asyncio, json, os, sys
import edge_tts

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "raw", "trailer", "voz")
os.makedirs(OUT, exist_ok=True)

NARRADOR = "en-US-ChristopherNeural"      # grave, calmo
LOCUTORA = "en-US-JennyNeural"            # rádio de emergência (filtrada depois)

LINHAS = [
    # (arquivo, voz, texto, rate, pitch)
    ("n01", NARRADOR, "They say the sea always gives back what it takes.", "-18%", "-10Hz"),
    ("n02", NARRADOR, "I wish it hadn't.", "-22%", "-12Hz"),
    ("n03", NARRADOR, "COROV twenty-seven. Ninety percent of the world... gone. Or worse.", "-16%", "-10Hz"),
    ("n04", NARRADOR, "Out here... silence is the only weapon.", "-20%", "-12Hz"),
    ("n05", NARRADOR, "Scavenge.", "-15%", "-12Hz"),
    ("n06", NARRADOR, "Build.", "-15%", "-12Hz"),
    ("n07", NARRADOR, "Fight.", "-15%", "-12Hz"),
    ("n08", NARRADOR, "And when the dead come knocking...", "-18%", "-10Hz"),
    ("n09", NARRADOR, "Answer.", "-25%", "-14Hz"),
    ("n10", NARRADOR, "Day one... is only the beginning.", "-20%", "-12Hz"),
    ("r01", LOCUTORA, "All stations. All stations. The containment lines have failed. Repeat, the containment lines have failed.", "+0%", "+0Hz"),
    ("r02", LOCUTORA, "C O R O V twenty-seven is now confirmed on every continent. Ninety percent of the global population is infected. Stay indoors. Do not", "-2%", "+0Hz"),
]


async def main():
    dur = {}
    for nome, voz, texto, rate, pitch in LINHAS:
        caminho = os.path.join(OUT, nome + ".mp3")
        com = edge_tts.Communicate(texto, voz, rate=rate, pitch=pitch)
        await com.save(caminho)
        print("ok", nome, os.path.getsize(caminho), "bytes")
    json.dump({n: t for n, _, t, _, _ in LINHAS}, open(os.path.join(OUT, "_textos.json"), "w", encoding="utf-8"), indent=1)

asyncio.run(main())
