"""Makes the placeholder 'action refused' cue for src/client/item_sounds.gd (`reject`).

Run: python3 assets/audio/make_reject.py   (needs numpy and ffmpeg)
Writes assets/audio/items/item_reject_N (3 variants, 0.22 s): two soft low wooden taps, the second lower, like a hand
knocking on something that will not give. Quiet and unobtrusive: it must never nag. Recordings go in
assets/audio/recorded/items/ under the same name; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, add  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "items")
VARIANTS = 3


def tap(rng, freq, level, at, out):
    t = np.arange(int(0.1 * SR)) / SR
    w = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.022) * level
    w += np.sin(2 * np.pi * freq * 2.3 * t) * np.exp(-t / 0.01) * level * 0.3
    add(out, w, at)


def reject(rng):
    out = np.zeros(int(0.22 * SR))
    f = rng.uniform(190, 230)
    tap(rng, f, 0.8, 0.0, out)
    tap(rng, f * 0.8, 0.65, 0.09, out)
    return make_stance.finish(out, 0.5)


def main():
    rng = np.random.default_rng(20261127)

    for v in range(VARIANTS):
        make_stance.write_ogg("item_reject_%d" % v, reject(rng))

    print("Wrote %d reject cues to %s" % (VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
