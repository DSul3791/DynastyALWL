"""Makes placeholder den sounds for src/client/den_sounds.gd (animals asleep in cave side branches).

Run: python3 assets/audio/make_den.py   (needs numpy and ffmpeg)
Writes assets/audio/den/den_breath_N.ogg (slow sleeping breath, in and out) and den_shuffle_N.ogg (a soft turn on dry grass and fur).
No growls, on purpose (Dave decides). Recordings in assets/audio/recorded/den/ under the same names win.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import subprocess, tempfile, wave  # noqa: E402
from make_sounds import SR, band, shape, soft_limit  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "den")
VARIANTS = 3


def write_ogg(name, x):
    data = (np.clip(soft_limit(x), -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def tone(rng, n, center, octaves):
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1.0)
    return shape(rng.standard_normal(n), band(f, center, octaves))


def breath(rng):
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    cycle = 3.0 + rng.uniform(-0.3, 0.3)
    swell = np.sin(np.pi * np.clip(t / cycle, 0.0, 1.0)) ** 1.6
    x = tone(rng, n, 420.0 + rng.uniform(-60, 60), 1.2) * swell
    return x / (np.abs(x).max() + 1e-9) * 0.5


def shuffle(rng):
    n = int(1.2 * SR)
    out = np.zeros(n)
    for _ in range(int(rng.integers(5, 9))):
        at = int(rng.uniform(0.0, 0.8) * SR)
        m = int(rng.uniform(0.04, 0.12) * SR)
        g = rng.standard_normal(m) * np.exp(-np.arange(m) / (m * 0.3))
        out[at:at + m] += g * rng.uniform(0.2, 0.6)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1.0)
    out = shape(out, band(f, 900.0, 2.0))
    return out / (np.abs(out).max() + 1e-9) * 0.45


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(VARIANTS):
        rng = np.random.default_rng(900 + i)
        write_ogg("den_breath_%d" % i, breath(rng))
        write_ogg("den_shuffle_%d" % i, shuffle(rng))


if __name__ == "__main__":
    main()
