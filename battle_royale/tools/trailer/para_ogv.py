"""Converte o trailer MP4 (catcine) para OGG Theora+Vorbis, o único formato de vídeo que o Godot toca nativamente.
Uso: py -3.11 tools/trailer/para_ogv.py [entrada.mp4] [saida.ogv]"""
import av, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ent = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "catcine", "DAYONE_trailer.mp4")
sai = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "game", "assets", "video", "intro.ogv")
os.makedirs(os.path.dirname(sai), exist_ok=True)
i = av.open(ent)
o = av.open(sai, "w", format="ogg")
vi, ai = i.streams.video[0], i.streams.audio[0]
vo = o.add_stream("theora", rate=30)
vo.width, vo.height, vo.pix_fmt = 1280, 720, "yuv420p"
vo.bit_rate = 2800000
ao = o.add_stream("libvorbis" if "libvorbis" in av.codecs_available else "vorbis", rate=44100)
ao.layout = "stereo"
try:
    ao.bit_rate = 128000
except Exception:
    pass
res = av.AudioResampler(format="fltp", layout="stereo", rate=44100)
n = 0
for pkt in i.demux(vi, ai):
    for fr in pkt.decode():
        if isinstance(fr, av.VideoFrame):
            f2 = fr.reformat(width=1280, height=720, format="yuv420p")
            f2.pts = None
            for p in vo.encode(f2):
                o.mux(p)
            n += 1
            if n % 600 == 0:
                print("quadros", n, flush=True)
        else:
            for r in res.resample(fr):
                for p in ao.encode(r):
                    o.mux(p)
for p in vo.encode(None): o.mux(p)
for p in ao.encode(None): o.mux(p)
o.close()
print("PRONTO", sai, os.path.getsize(sai) // 1048576, "MB")
