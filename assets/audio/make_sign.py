"""Makes the sign-spotted sound (slot sign_spot, batch3_slots.json): a slight, natural cue when a player spots an animal sign.

Dave (23 Nov 2026): "spotting animal markings should highlight the markings, make a slight sound and give xp for finding them".
Run: python3 assets/audio/make_sign.py   (needs numpy and ffmpeg)
Writes assets/audio/sign/ (3 variants): a soft short intake of breath with a faint low hum under it, 0.4 s, quiet (peak -16 dB),
the small "oh" of noticing something, not a chime. Seeded, so a rerun writes the same samples. A recording dropped in its place wins.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, band, highpass, noise  # noqa: E402
import make_bow  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sign")
VARIANTS = 3


def notice(rng):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    rise = np.minimum(t / 0.12, 1.0) * np.exp(-np.maximum(t - 0.12, 0.0) / 0.08)   # swells in, falls away
    air = noise(rng, n, lambda fr: band(fr, rng.uniform(1500, 1900), 0.9) * highpass(fr, 400)) * rise
    air /= np.max(np.abs(air)) + 1e-9
    f = rng.uniform(210, 240)
    hum = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 1.5 * t)) * rise * 0.35
    return air * 0.8 + hum


def main():
    make_bow.OUT = OUT
    rng = np.random.default_rng(23112026)
    for i in range(VARIANTS):
        make_bow.write_ogg("sign_spot_%d" % i, make_bow.finish(notice(rng), 10 ** (-16 / 20)))


if __name__ == "__main__":
    main()
