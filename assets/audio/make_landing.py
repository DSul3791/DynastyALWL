"""Makes placeholder landing sounds for src/client/landing_sounds.gd (a body hitting the ground after a fall).

Run: python3 assets/audio/make_landing.py   (needs numpy and ffmpeg)
Writes assets/audio/landing/land_<name>_N (3 variants each): thud (a body weight and a breath knocked out, 0.5 s,
for falls of 2.5 to 5 m) and hard (a heavy double impact, a pack and gear rattle and a grunt, 0.9 s, 5 m and more).
Recordings go in assets/audio/recorded/landing/ under the same names; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "landing")
VARIANTS = 3


def impact(rng, level, at, out, freq=(55, 80), decay=0.06):
    t = np.arange(int(0.25 * SR)) / SR
    w = np.sin(2 * np.pi * rng.uniform(*freq) * t) * np.exp(-t / decay) * level
    add(out, w, at)
    m = int(0.05 * SR)
    click = noise(rng, m, lambda f: lowpass(f, 900) * highpass(f, 80)) * env(m, 0.002, 0.03)
    add(out, click / (np.max(np.abs(click)) + 1e-9) * level * 0.5, at)


def breath_out(rng, dur, at, out, level):
    """A grunt: voiced-ish noise falling in pitch (band-passed noise with a low hum)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    hum = np.sin(2 * np.pi * (150 - 70 * t / dur) * t) * 0.5
    air = noise(rng, n, lambda f: band(f, 700, 1.2) * lowpass(f, 2500)) * 0.8
    w = (hum + air) * env(n, 0.04, dur * 0.7)
    add(out, w / (np.max(np.abs(w)) + 1e-9) * level, at)


def thud(rng):
    out = np.zeros(int(0.5 * SR))
    impact(rng, 0.9, 0.0, out)
    breath_out(rng, 0.2, 0.05, out, 0.3)
    return make_stance.finish(out, 0.65)


def hard(rng):
    out = np.zeros(int(0.9 * SR))
    impact(rng, 1.0, 0.0, out, (45, 65), 0.09)
    impact(rng, 0.5, 0.11, out, (60, 85))
    rattle = make_stance.rustle(rng, 0.5, 2600, 6, 0.6)
    add(out, rattle * 0.5, 0.05)
    breath_out(rng, 0.35, 0.12, out, 0.45)
    return make_stance.finish(out, 0.8)


SOUNDS = {"thud": thud, "hard": hard}


def main():
    rng = np.random.default_rng(20261123)

    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            make_stance.write_ogg("land_%s_%d" % (name, v), make(rng))

    print("Wrote %d landing sounds to %s" % (len(SOUNDS) * VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
