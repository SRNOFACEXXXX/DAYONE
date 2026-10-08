"""Gera batidas mecânicas curtas e autorais para portas do carro."""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "game/assets/audio/vehicle"
RATE = 44100


def write(name, closing):
    rng = random.Random(771 if closing else 419)
    length = 0.34 if closing else 0.28
    samples = []
    for i in range(int(RATE * length)):
        t = i / RATE
        hit = math.exp(-t * (31 if closing else 25))
        metal = math.sin(2 * math.pi * (118 if closing else 156) * t) * hit
        latch_t = t - (0.055 if closing else 0.09)
        latch = 0.0
        if latch_t >= 0:
            latch = math.sin(2 * math.pi * 430 * latch_t) * math.exp(-latch_t * 70)
        noise = (rng.random() * 2 - 1) * math.exp(-t * 48)
        value = (metal * .56 + latch * .31 + noise * .14) * (.92 if closing else .72)
        samples.append(max(-1.0, min(1.0, value)))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in samples))


write("door_open.wav", False)
write("door_close.wav", True)
