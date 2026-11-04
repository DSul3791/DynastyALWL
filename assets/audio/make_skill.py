"""Makes the skill-up sound (slot skill_tock, batch3_slots.json): a soft wooden tock when a skill rises.

Dave (QA jason-skill-chime, 4 Nov 2026): A, a soft wooden tock, at most once every 20 s (COOLDOWN_S "skill" in slot_sounds.gd).
Run: python3 assets/audio/make_skill.py   (needs numpy and ffmpeg)
Writes assets/audio/skill/ (3 variants): a short hollow knock of a small wooden block, 0.25 s, no ring.
Seeded, so a rerun writes the same samples. A recording dropped in its place wins (swap_recording.py).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, lowpass, noise  # noqa: E402
import make_bow  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "skill")
VARIANTS = 3


def tock(rng):
    # A small hollow block struck with a soft stick: two damped body modes (wood is inharmonic, about 1 : 2.4)
    # and a tiny filtered tap at the start. Short decays, so it reads as wood, not a bell.
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = rng.uniform(560, 640)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.035)
    x += 0.35 * np.sin(2 * np.pi * f * 2.42 * t + rng.uniform(0, 6.28)) * np.exp(-t / 0.014)
    x += 0.12 * np.sin(2 * np.pi * f * 0.5 * t) * np.exp(-t / 0.05)
    tap = noise(rng, n, lambda fr: lowpass(fr, 2500)) * np.exp(-t / 0.003)
    x += 0.25 * tap / (np.max(np.abs(tap)) + 1e-9)
    return x


def main():
    make_bow.OUT = OUT
    rng = np.random.default_rng(4112026)
    for i in range(VARIANTS):
        make_bow.write_ogg("skill_tock_%d" % i, make_bow.finish(tock(rng), 10 ** (-14 / 20)))


if __name__ == "__main__":
    main()
