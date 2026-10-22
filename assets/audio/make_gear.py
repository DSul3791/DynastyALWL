"""Makes placeholder gear sounds for src/client/gear_sounds.gd (armour and clothing on footsteps).

Run: python3 assets/audio/make_gear.py   (needs numpy and ffmpeg)
Writes assets/audio/gear/gear_<layer>_N (3 variants each): cloth (a soft rustle), leather (a creak),
chain (a jingle of links), plate (a clank of plates), hobnail (a hard boot nail click) and iron
(an iron-shod boot clang). Recordings go in assets/audio/recorded/gear/ under the same names;
the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gear")
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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.7):
    x = x - np.mean(x)
    fade = min(int(0.03 * SR), len(x) // 4)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def ring(f, decay, dur):
    t = np.arange(int(dur * SR)) / SR
    return np.sin(2 * np.pi * f * t) * np.exp(-t / decay)


def cloth(rng):
    n = int(0.22 * SR)
    x = noise(rng, n, lambda f: band(f, rng.uniform(1800, 2600), 1.2) * highpass(f, 600)) * env(n, 0.03, 0.06)
    return finish(x, 0.5)


def leather(rng):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    f = rng.uniform(380, 620) * (1.0 + 0.25 * np.sin(2 * np.pi * rng.uniform(5, 9) * t) * t)
    sq = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    sq *= np.sin(np.pi * t / t[-1]) ** 1.5
    x = sq * 0.5 + 0.5 * noise(rng, n, lambda fr: band(fr, 1500, 1.0)) * np.sin(np.pi * t / t[-1]) ** 2 * 3
    return finish(x, 0.5)


def chain(rng):
    out = np.zeros(int(0.45 * SR))

    for _ in range(rng.integers(8, 16)):
        add(out, ring(rng.uniform(3500, 7500), rng.uniform(0.01, 0.03), 0.12) * rng.uniform(0.2, 1.0), rng.uniform(0.0, 0.25))

    return finish(out, 0.55)


def plate(rng):
    out = np.zeros(int(0.5 * SR))
    base = rng.uniform(600, 900)

    for ratio, amp, decay in ((1.0, 1.0, 0.05), (2.3, 0.6, 0.035), (3.7, 0.4, 0.025), (5.1, 0.25, 0.02)):
        add(out, ring(base * ratio, decay, 0.4) * amp, 0.0)

    m = int(0.01 * SR)
    add(out, noise(rng, m, lambda f: band(f, 3500, 1.0)) * env(m, 0.0004, 0.003) * 3, 0.0)
    return finish(out, 0.65)


def hobnail(rng):
    out = np.zeros(int(0.12 * SR))

    for k in range(rng.integers(2, 4)):
        m = int(0.015 * SR)
        add(out, noise(rng, m, lambda f: band(f, 3800, 1.0) * highpass(f, 1500)) * env(m, 0.0003, 0.002) * 2, 0.012 * k)

    return finish(out, 0.5)


def iron(rng):
    out = np.zeros(int(0.45 * SR))
    base = rng.uniform(300, 450)

    for ratio, amp, decay in ((1.0, 1.0, 0.07), (2.76, 0.5, 0.04), (5.4, 0.3, 0.02)):
        add(out, ring(base * ratio, decay, 0.35) * amp, 0.0)

    return finish(out, 0.6)


SOUNDS = {"cloth": cloth, "leather": leather, "chain": chain, "plate": plate, "hobnail": hobnail, "iron": iron}


def main():
    rng = np.random.default_rng(20261025)

    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            write_ogg("gear_%s_%d" % (name, v), make(rng))

    print("Wrote %d gear sounds to %s" % (len(SOUNDS) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
