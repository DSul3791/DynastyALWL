"""Makes the placeholder tool swing whoosh for src/client/hit_sounds.gd (`swing`): a tool moved through the air.

Run: python3 assets/audio/make_swing.py   (needs numpy and ffmpeg)
Writes assets/audio/hits/hit_swing_N (3 variants, 0.5 s): a low-passed air rush that swells to its peak at 0.27 s
(where held_item.gd's blow lands, half of SWING_S) and falls away, a faint handle creak at the start.
Recordings go in assets/audio/recorded/hits/ under the same name; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hits")
VARIANTS = 3


def swing(rng):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    rush = noise(rng, n, lambda f: band(f, rng.uniform(600, 900), 0.9) * lowpass(f, 2600) * highpass(f, 200))
    shape = np.exp(-0.5 * ((t - 0.27) / 0.11) ** 2)
    out = rush / (np.max(np.abs(rush)) + 1e-9) * shape
    low = np.sin(2 * np.pi * (110 + 70 * t) * t) * 0.15 * shape
    return make_stance.finish(out + low, 0.55)


def main():
    rng = np.random.default_rng(20261125)

    for v in range(VARIANTS):
        make_stance.write_ogg("hit_swing_%d" % v, swing(rng))

    print("Wrote %d swing sounds to %s" % (VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
