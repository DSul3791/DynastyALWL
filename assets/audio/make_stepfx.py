"""Makes placeholder step layers for src/client/step_fx.gd: wet-shoe squelches and the cloth rustle of walking.

Run: python3 assets/audio/make_stepfx.py   (needs numpy and ffmpeg)
Writes assets/audio/stepfx/: wet_squelch_N (a short wet suck and slap, 0.22 s, 4 variants) and
cloth_walk_N (a soft fabric swish, 0.25 s, 4 variants). Quiet by design: the game plays them well under the footstep.
Recordings go in assets/audio/recorded/stepfx/ under the same names; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stepfx")
VARIANTS = 4


def squelch(rng):
    n = int(0.22 * SR)
    out = np.zeros(n)
    # the suck: band noise whose centre rises quickly, then a small slap
    m = int(0.14 * SR)
    t = np.arange(m) / SR
    sweep = np.sin(2 * np.pi * (350 + 900 * t / 0.14) * t) * 0.5
    air = noise(rng, m, lambda f: band(f, rng.uniform(900, 1500), 1.3) * highpass(f, 250) * lowpass(f, 3500))
    w = (sweep + air / (np.max(np.abs(air)) + 1e-9) * 0.8) * env(m, 0.01, 0.1)
    add(out, w / (np.max(np.abs(w)) + 1e-9) * 0.7, 0.0)
    k = int(0.05 * SR)
    slap = noise(rng, k, lambda f: lowpass(f, 1800) * highpass(f, 150)) * env(k, 0.002, 0.03)
    add(out, slap / (np.max(np.abs(slap)) + 1e-9) * 0.9, 0.12)
    return make_stance.finish(out, 0.5)


def cloth(rng):
    return make_stance.finish(make_stance.rustle(rng, 0.25, rng.uniform(1500, 2200), 2, 0.8), 0.4)


SOUNDS = {"wet_squelch": squelch, "cloth_walk": cloth}


def main():
    rng = np.random.default_rng(20261124)

    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            make_stance.write_ogg("%s_%d" % (name, v), make(rng))

    print("Wrote %d step layer sounds to %s" % (len(SOUNDS) * VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
