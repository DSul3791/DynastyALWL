"""Makes placeholder stance cloth sounds for src/client/stance_sounds.gd (crouch, sit, lie, rise, settle).

Run: python3 assets/audio/make_stance.py   (needs numpy and ffmpeg)
Writes assets/audio/stance/stance_<name>_N (3 variants each): crouch (cloth rustle going down, 0.45 s),
sit (a settling rustle and a soft weight, 0.7 s), lie (a longer slide down onto the ground, 1.0 s),
rise (getting up: rustle and a small effort of cloth, 0.7 s) and settle (a tiny shift while resting, 0.3 s).
Recordings go in assets/audio/recorded/stance/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stance")
VARIANTS = 3


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


def finish(x, peak=0.55):
    x = x - np.mean(x)
    n = int(0.04 * SR)
    x[:int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    x[-n:] *= np.linspace(1, 0, n)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def rustle(rng, dur, center, bursts, soft=1.0):
    """Cloth: a few overlapping bursts of soft band-passed noise, nothing bright or rhythmic."""
    n = int(dur * SR)
    out = np.zeros(n)

    for _ in range(bursts):
        m = int(rng.uniform(0.08, 0.22) * SR)
        burst = noise(rng, m, lambda f: band(f, center * rng.uniform(0.7, 1.3), 1.4) * highpass(f, 300) * lowpass(f, 4500)) * env(m, 0.3 * m / SR, 0.6 * m / SR)
        add(out, burst / (np.max(np.abs(burst)) + 1e-9) * rng.uniform(0.4, 1.0) * soft, rng.uniform(0.0, max(dur - 0.25, 0.01)))

    return out


def thump(rng, level, at, out):
    t = np.arange(int(0.12 * SR)) / SR
    w = np.sin(2 * np.pi * rng.uniform(70, 95) * t) * np.exp(-t / 0.035) * level
    add(out, w, at)


def crouch(rng):
    return finish(rustle(rng, 0.45, 1800, 3))


def sit(rng):
    out = rustle(rng, 0.7, 1500, 4)
    thump(rng, 0.5, 0.32, out)
    return finish(out)


def lie(rng):
    out = rustle(rng, 1.0, 1300, 6)
    thump(rng, 0.45, 0.35, out)
    thump(rng, 0.65, 0.62, out)
    return finish(out)


def rise(rng):
    out = rustle(rng, 0.7, 1700, 4)
    return finish(out)


def settle(rng):
    return finish(rustle(rng, 0.3, 1600, 2, 0.7), 0.4)


SOUNDS = {"crouch": crouch, "sit": sit, "lie": lie, "rise": rise, "settle": settle}


def main():
    rng = np.random.default_rng(20261122)

    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            write_ogg("stance_%s_%d" % (name, v), make(rng))

    print("Wrote %d stance sounds to %s" % (len(SOUNDS) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
