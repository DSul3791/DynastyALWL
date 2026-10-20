"""Makes the placeholder summer insect bed for src/client/insect_bed.gd (a quiet loop of chirring insects).

Run: python3 assets/audio/make_insects.py   (needs numpy and ffmpeg)
Writes assets/audio/insects/insect_bed_0..1.ogg: 16 s seamless loops of several overlapping insects (band-passed air at
3 to 7 kHz pulsed 30 to 80 times a second, each swelling and falling over a few seconds, a few steady buzzes
underneath). Nothing rhythmic, no single call stands out. Recordings go in assets/audio/recorded/insects/ under the
same names (insect_bed_0.ogg ...); the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, band, highpass, lowpass, noise  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "insects")
LOOP_S = 16.0
FADE_S = 1.5
VARIANTS = 2


def insect_layer(rng, n):
    t = np.arange(n) / SR
    center = rng.uniform(3500, 6500)
    air = noise(rng, n, lambda f: band(f, center, 1.6) * highpass(f, 2500) * lowpass(f, 8000))
    air /= np.max(np.abs(air)) + 1e-9
    rate = rng.uniform(30, 80)
    pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rate * t)) * 0.8
    pulse = np.convolve(pulse, np.ones(8) / 8, mode="same")
    swell = np.zeros(n)

    for _ in range(int(LOOP_S / 5)):
        at = rng.uniform(0, LOOP_S)
        width = rng.uniform(1.2, 3.0)
        swell += np.exp(-0.5 * ((t - at) / width) ** 2) * rng.uniform(0.4, 1.0)

    return air * pulse * np.minimum(swell, 1.0) * rng.uniform(0.5, 1.0)


def bed(rng):
    n = int((LOOP_S + FADE_S) * SR)
    x = np.zeros(n)

    for _ in range(int(rng.integers(5, 8))):
        x += insect_layer(rng, n)

    buzz = noise(rng, n, lambda f: band(f, 1800, 1.5) * lowpass(f, 3000)) * 0.12
    x += buzz / (np.max(np.abs(buzz)) + 1e-9) * 0.25
    m = int(FADE_S * SR)
    y = x[:-m].copy()
    w = np.linspace(0, 1, m)
    y[:m] = y[:m] * w + x[-m:] * (1 - w)
    y -= np.mean(y)
    return y * (0.35 / (np.max(np.abs(y)) + 1e-9))


def main():
    rng = np.random.default_rng(20261126)

    for v in range(VARIANTS):
        make_stance.write_ogg("insect_bed_%d" % v, bed(rng))

    print("Wrote %d insect beds to %s" % (VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
