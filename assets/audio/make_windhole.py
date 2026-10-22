"""Makes placeholder wind-through-an-opening loops for src/client/wind_structures.gd.

Run: python3 assets/audio/make_windhole.py   (needs numpy and ffmpeg)
Writes assets/audio/windhole/ seamless 20 s loops (circular noise and whole-cycle phase, so no seam):
  wind_whistle  wind through a gap: a thin, wandering tone around 900 Hz in a breathy hiss (lean-to, a door ajar)
  wind_hollow   wind across a cave mouth or a big opening: a low moan around 120 Hz with a soft rushing breath
Recordings go in assets/audio/recorded/windhole/ under the same names; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, band, highpass, lowpass  # noqa: E402
from make_water import normalize, shaped_noise  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "windhole")
SECONDS = 20


def wander(rng, n, speed_hz):
    w = shaped_noise(rng, n, lambda f: lowpass(f, speed_hz, 3) * highpass(f, 0.04, 1))
    return w / (np.max(np.abs(w)) + 1e-9)


def tone(rng, n, f0, spread):
    f = f0 * (1.0 + spread * wander(rng, n, 0.6))
    ph = np.cumsum(f) / SR
    ph_end = ph[-1] + f[-1] / SR
    ph = ph * (np.round(ph_end) / ph_end)                 # whole cycles: the loop seam is silent
    return np.sin(2 * np.pi * ph)


def swell(rng, n, floor):
    return floor + (1.0 - floor) * (0.5 + 0.5 * wander(rng, n, 0.35))


def whistle(rng, n):
    breath = shaped_noise(rng, n, lambda f: band(f, 1000, 0.5) * highpass(f, 400, 2) * lowpass(f, 3500, 2))
    breath /= np.std(breath) + 1e-9
    x = 0.8 * tone(rng, n, 900, 0.14) * swell(rng, n, 0.2) + 0.5 * breath * swell(rng, n, 0.5)
    return normalize(x)


def hollow(rng, n):
    low = shaped_noise(rng, n, lambda f: band(f, 120, 0.35) * lowpass(f, 300, 2))
    low /= np.std(low) + 1e-9
    breath = shaped_noise(rng, n, lambda f: band(f, 350, 1.0) * lowpass(f, 900, 2) * highpass(f, 80, 2))
    breath /= np.std(breath) + 1e-9
    x = (0.9 * tone(rng, n, 115, 0.1) + 0.6 * low) * swell(rng, n, 0.25) + 0.4 * breath * swell(rng, n, 0.4)
    return normalize(x)


def main():
    rng = np.random.default_rng(20261122)
    n = SECONDS * SR

    for name, make in (("wind_whistle", whistle), ("wind_hollow", hollow)):
        make_stance.write_ogg(name, make(rng, n))

    print("Wrote 2 wind loops to %s" % make_stance.OUT)


if __name__ == "__main__":
    main()
