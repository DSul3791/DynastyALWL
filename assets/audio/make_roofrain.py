"""Makes the placeholder rain-on-a-roof loop for src/client/weather_sounds.gd (`rain_roof`).

Run: python3 assets/audio/make_roofrain.py   (needs numpy and ffmpeg)
Writes assets/audio/weather/rain_roof.ogg: a 16 s seamless loop of rain drops landing close overhead on boards or
thatch: sharper, denser ticks than the leaf patter, some low board knocks, a soft low body. Recordings go in
assets/audio/recorded/weather/ as rain_roof_0.ogg (the game prefers them).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_weather as mw  # noqa: E402
from make_sounds import SR, band, highpass  # noqa: E402


def rain_roof(rng, n):
    ticks = mw.drops(rng, n, 520, 3200, 0.8, 0.0045)
    ticks /= np.std(ticks) + 1e-9
    knocks = mw.drops(rng, n, 55, 950, 0.6, 0.02)
    knocks /= np.std(knocks) + 1e-9
    body = mw.shaped_noise(rng, n, lambda f: band(f, 220, 1.0) * highpass(f, 90, 2))
    body /= np.std(body) + 1e-9
    return mw.normalize((0.8 * ticks + 0.5 * knocks + 0.2 * body) * mw.slow_swell(rng, n, 0.1, (3, 6, 8)))


def main():
    rng = np.random.default_rng(20261128)
    mw.write_ogg("rain_roof", rain_roof(rng, 16 * SR))
    print("Wrote rain_roof.ogg to", mw.OUT)


if __name__ == "__main__":
    main()
