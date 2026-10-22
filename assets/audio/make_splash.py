"""Makes the placeholder rain drops for src/client/rain_splashes.gd (single drops landing near the player, by ground).

Run: python3 assets/audio/make_splash.py   (needs numpy and ffmpeg)
Writes assets/audio/splash/rain_splash_<ground>_N (3 variants each, 60 to 180 ms): stone (a sharp tick), gravel (a tiny
scatter of clicks), grass (a soft pat), dirt (a dull pat), sand (a short soft hiss), mud (a wet plop), litter (a dry leaf
tick), water (a plip with a quick pitch rise). Quiet, one drop each; the layer sets the level and the rate.
Recordings go in assets/audio/recorded/splash/ under the same names; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, band, env, highpass, lowpass, noise  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "splash")
VARIANTS = 3
GROUNDS = ["stone", "gravel", "grass", "dirt", "sand", "mud", "litter", "water"]


def tick(rng, n, center, octaves, decay, hp=0.0):
    x = noise(rng, n, lambda f: band(f, center * rng.uniform(0.85, 1.15), octaves) * highpass(f, max(hp, 100.0)))
    return x / (np.max(np.abs(x)) + 1e-9) * env(n, 0.001, decay)


def drop(rng, ground):
    n = int(0.18 * SR)
    t = np.arange(n) / SR

    if ground == "stone":
        x = tick(rng, n, 4200, 0.8, 0.012, 1500)
        x += 0.35 * np.sin(2 * np.pi * rng.uniform(1800, 2600) * t) * np.exp(-t / 0.01)
    elif ground == "gravel":
        x = np.zeros(n)

        for _ in range(rng.integers(3, 6)):
            at = int(rng.uniform(0, 0.05) * SR)
            m = int(0.012 * SR)
            x[at:at + m] += tick(rng, m, rng.uniform(2500, 5000), 0.9, 0.004, 1200) * rng.uniform(0.4, 1.0)
    elif ground == "grass":
        x = tick(rng, n, 2200, 1.0, 0.02, 600)
    elif ground == "dirt":
        x = tick(rng, n, 900, 1.0, 0.025, 200)
    elif ground == "sand":
        x = noise(rng, n, lambda f: band(f, 3500, 1.1) * highpass(f, 1200)) * env(n, 0.004, 0.035)
    elif ground == "mud":
        f0 = rng.uniform(260, 380)
        x = np.sin(2 * np.pi * (f0 + 500 * t) * t) * np.exp(-t / 0.03) + 0.4 * tick(rng, n, 700, 1.0, 0.02, 150)
    elif ground == "litter":
        x = tick(rng, n, 3800, 0.9, 0.008, 1800) + 0.5 * tick(rng, n, 2600, 0.9, 0.015, 1000)
    else:                                                    # water: a plip, pitch rising as the bubble closes
        f0 = rng.uniform(700, 1100)
        x = np.sin(2 * np.pi * (f0 * t + 3500 * t * t)) * np.exp(-t / 0.035) + 0.25 * tick(rng, n, 3000, 0.9, 0.006, 1500)

    x = x[:int(0.17 * SR)]
    return make_stance.finish(x, 0.6)


def main():
    rng = np.random.default_rng(20261128)

    for ground in GROUNDS:
        for v in range(VARIANTS):
            make_stance.write_ogg("rain_splash_%s_%d" % (ground, v), drop(rng, ground))

    print("Wrote %d rain drops to %s" % (len(GROUNDS) * VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
