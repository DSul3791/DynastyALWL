"""Makes placeholder wind-in-trees loops for src/client/tree_wind.gd.

Run: python3 assets/audio/make_treewind.py   (needs numpy and ffmpeg)
Writes assets/audio/treewind/ seamless 24 s loops (circular noise, so no seam):
  treewind_pine    a soft, steady hiss in needles, narrow band around 3 kHz
  treewind_leaves  broad leaf rustle (spring and summer): smooth, mid-high
  treewind_dry     autumn leaves: a crisper rustle with sparse dry ticks
  treewind_bare    winter branches: low, slow wood creak and moan, no hiss
No periodic pulse and no discrete bubbles (they read as surf or boiling in the water sounds).
Recordings go in assets/audio/recorded/treewind/ under the same names; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass  # noqa: E402
import make_water as mw  # noqa: E402
from make_water import drift, normalize, shaped_noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "treewind")
mw.OUT = OUT
SECONDS = 24


def smooth_gain(rng, n, floor, speed_hz):
    """A slow random level (circular, never repeating inside the loop) between floor and 1."""
    wob = shaped_noise(rng, n, lambda f: lowpass(f, speed_hz, 3) * highpass(f, 0.03, 1))
    wob = wob / (np.max(np.abs(wob)) + 1e-9)
    return floor + (1.0 - floor) * (0.5 + 0.5 * wob)


def pine(rng, n):
    x = shaped_noise(rng, n, lambda f: band(f, 3000, 0.7) * highpass(f, 1200, 2))
    x /= np.std(x) + 1e-9
    return normalize(x * smooth_gain(rng, n, 0.55, 0.5) * drift(rng, n, 0.08))


def leaves(rng, n):
    x = shaped_noise(rng, n, lambda f: band(f, 2200, 1.3) * highpass(f, 500, 2) * lowpass(f, 6000, 2))
    x /= np.std(x) + 1e-9
    flutter = smooth_gain(rng, n, 0.35, 3.0)
    return normalize(x * flutter * smooth_gain(rng, n, 0.6, 0.4))


def dry(rng, n):
    x = shaped_noise(rng, n, lambda f: band(f, 3500, 1.2) * highpass(f, 1200, 2))
    x /= np.std(x) + 1e-9
    out = x * smooth_gain(rng, n, 0.3, 4.0) * smooth_gain(rng, n, 0.55, 0.4)
    ticks = np.zeros(n)

    for _ in range(int(0.9 * n / SR)):
        m = int(0.008 * SR)
        tick = rng.standard_normal(m) * np.exp(-np.arange(m) / (0.002 * SR))
        idx = (rng.integers(0, n) + np.arange(m)) % n
        ticks[idx] += tick * rng.uniform(0.15, 0.6)

    return normalize(out / (np.std(out) + 1e-9) + 0.5 * ticks / (np.std(ticks) + 1e-9))


def bare(rng, n):
    low = shaped_noise(rng, n, lambda f: band(f, 220, 1.0) * highpass(f, 60, 2) * lowpass(f, 600, 2))
    low /= np.std(low) + 1e-9
    out = low * smooth_gain(rng, n, 0.25, 0.35)
    creak = np.zeros(n)

    for _ in range(int(rng.integers(5, 9))):
        d = rng.uniform(0.5, 1.4)
        m = int(d * SR)
        t = np.arange(m) / SR
        f0 = rng.uniform(140, 320)
        f = f0 * (1.0 + 0.25 * np.sin(2 * np.pi * rng.uniform(5, 11) * t)) * (1.0 + 0.15 * t / d)
        tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d) ** 2
        idx = (rng.integers(0, n) + np.arange(m)) % n
        creak[idx] += tone * rng.uniform(0.2, 0.5)

    return normalize(out + 0.8 * creak / (np.std(creak) + 1e-9) * 0.4)


LOOPS = {"treewind_pine": pine, "treewind_leaves": leaves, "treewind_dry": dry, "treewind_bare": bare}


def main():
    rng = np.random.default_rng(20261029)

    for name, make in LOOPS.items():
        mw.write_ogg(name, make(rng, SECONDS * SR))

    print("Wrote %d tree-wind loops to %s" % (len(LOOPS), OUT))


if __name__ == "__main__":
    main()
