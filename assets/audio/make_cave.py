"""Makes placeholder cave sounds for src/client/cave_sounds.gd.

Run: python3 assets/audio/make_cave.py   (needs numpy and ffmpeg)
Writes assets/audio/cave/cave_drip_N.ogg: single water drops falling into a puddle, each with a
short echo tail. Recordings go in assets/audio/recorded/cave/ under the same names.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, freqs, lowpass, noise, shape  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cave")
VARIANTS = 5


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


def drip(rng):
    n = int(1.4 * SR)
    out = np.zeros(n)
    m = int(0.12 * SR)
    t = np.arange(m) / SR
    f0 = rng.uniform(900, 1700)
    plink = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.5 * np.exp(-t / 0.02))) / SR) * np.exp(-t / 0.03)
    tick = noise(rng, m, lambda f: band(f, 2500, 0.8)) * np.exp(-t / 0.004)
    drop = plink + 0.35 * tick / (np.max(np.abs(tick)) + 1e-9)
    add(out, drop, 0.0)
    # a small stone room around it: a few decaying echoes, each duller than the last
    for k, (delay, gain) in enumerate(((0.07, 0.45), (0.15, 0.3), (0.26, 0.2), (0.4, 0.12), (0.6, 0.07))):
        echo = shape(drop, lowpass(freqs(len(drop)), 3500.0 / (1 + k), 2))
        add(out, echo * gain, delay + rng.uniform(-0.01, 0.01))
    tail = noise(rng, n, lambda f: band(f, 1800, 1.0)) * np.exp(-np.arange(n) / SR / 0.35) * 0.04
    out += tail
    out = out - np.mean(out)
    fade = int(0.1 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out * (0.8 / (np.max(np.abs(out)) + 1e-9))


def main():
    rng = np.random.default_rng(20261020)
    for v in range(VARIANTS):
        write_ogg("cave_drip_%d" % v, drip(rng))
    print("Wrote %d cave sounds to %s" % (VARIANTS, OUT))


if __name__ == "__main__":
    main()
