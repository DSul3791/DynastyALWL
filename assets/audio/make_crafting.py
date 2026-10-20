"""Makes placeholder crafting work sounds for src/client/item_sounds.gd.

Run: python3 assets/audio/make_crafting.py   (needs numpy and ffmpeg)
Writes assets/audio/crafting/craft_<type>_N (2 variants, 4.5 s each; the game plays one from the
start of a craft and cuts it with a short fade when the craft ends):
  twine  twisting fibre into cord: rubbing strokes     knap   chipping stone: sharp clacks and scrapes
  bind   binding with cord: tight rasps and tugs       carve  scraping a point on wood: long scrapes
  stack  laying sticks and stones: clatter and thunks  pound  pounding leaves: dull wet thuds
  wrap   wrapping a bandage: cloth and leaf rustle
Recordings go in assets/audio/recorded/crafting/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, highpass, lowpass, noise, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "crafting")
VARIANTS = 2
SECONDS = 4.5
TYPES = ("twine", "knap", "bind", "carve", "stack", "pound", "wrap")


def write_ogg(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.6):
    n = int(0.08 * SR)
    x[-n:] *= np.linspace(1, 0, n)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def stroke(rng, dur, center, octaves, rough=0.0):
    """One rubbing stroke: band noise with a swell, optionally rough (amplitude chatter)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = noise(rng, n, lambda f: band(f, center, octaves) * highpass(f, 500)) * np.sin(np.pi * t / dur)
    if rough:
        x *= 1.0 - rough + rough * np.abs(np.sin(2 * np.pi * rng.uniform(60, 120) * t))
    return x / (np.max(np.abs(x)) + 1e-9)


def clack(rng, center=3000, length=0.014):
    m = int(length * SR)
    return burst(rng, length, center, 1.0) * np.exp(-np.arange(m) / SR / (length * 0.35))


def events(rng, n, gap_lo, gap_hi, make, start=0.1):
    out = np.zeros(n)
    at = start
    while at < SECONDS - 0.3:
        add(out, make(), at)
        at += rng.uniform(gap_lo, gap_hi)
    return out


def twine(rng):
    return events(rng, int(SECONDS * SR), 0.5, 0.8, lambda: stroke(rng, rng.uniform(0.25, 0.4), rng.uniform(1800, 3000), 1.5) * rng.uniform(0.4, 0.8))


def knap(rng):
    def blow():
        out = np.zeros(int(0.3 * SR))
        add(out, clack(rng, rng.uniform(2500, 4500)) * 0.9, 0.0)
        add(out, thump(rng, 0.08, rng.uniform(300, 420), 0.02, 1500.0) * 0.4, 0.0)
        add(out, stroke(rng, 0.12, 2200, 1.0, 0.5) * 0.25, 0.08)
        return out
    return events(rng, int(SECONDS * SR), 0.45, 0.8, blow)


def bind(rng):
    def pull():
        out = np.zeros(int(0.45 * SR))
        add(out, stroke(rng, 0.3, rng.uniform(2200, 3400), 1.2, 0.6) * 0.6, 0.0)
        add(out, clack(rng, 1500, 0.01) * 0.3, 0.32)
        return out
    return events(rng, int(SECONDS * SR), 0.6, 0.9, pull)


def carve(rng):
    return events(rng, int(SECONDS * SR), 0.2, 0.45, lambda: stroke(rng, rng.uniform(0.35, 0.55), rng.uniform(1600, 2400), 1.0, 0.8) * rng.uniform(0.6, 1.0))


def stack(rng):
    def piece():
        out = np.zeros(int(0.35 * SR))
        if rng.random() < 0.6:
            for k in range(rng.integers(1, 3)):
                add(out, clack(rng, rng.uniform(700, 1300), 0.025) * 0.7, 0.03 * k)
        else:
            add(out, thump(rng, 0.15, rng.uniform(110, 170), 0.05, 1000.0) * 0.9, 0.0)
        return out
    return events(rng, int(SECONDS * SR), 0.35, 0.7, piece)


def pound(rng):
    def blow():
        out = np.zeros(int(0.4 * SR))
        add(out, thump(rng, 0.14, rng.uniform(120, 180), 0.045, 900.0) * 0.9, 0.0)
        add(out, stroke(rng, 0.18, 1200, 1.2) * 0.3, 0.03)
        return out
    return events(rng, int(SECONDS * SR), 0.45, 0.7, blow)


def wrap(rng):
    def turn():
        out = np.zeros(int(0.7 * SR))
        add(out, stroke(rng, rng.uniform(0.45, 0.65), rng.uniform(2800, 4200), 1.6) * rng.uniform(0.4, 0.8), 0.0)
        add(out, clack(rng, 2000, 0.008) * 0.2, rng.uniform(0.05, 0.4))
        return out
    return events(rng, int(SECONDS * SR), 0.6, 0.95, turn)


def main():
    rng = np.random.default_rng(20261030)
    makers = {"twine": twine, "knap": knap, "bind": bind, "carve": carve, "stack": stack, "pound": pound, "wrap": wrap}

    for kind in TYPES:
        for v in range(VARIANTS):
            write_ogg("craft_%s_%d" % (kind, v), finish(makers[kind](rng)))

    print("Wrote %d crafting sounds to %s" % (len(TYPES) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
