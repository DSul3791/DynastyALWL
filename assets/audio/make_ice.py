"""Makes placeholder frozen-pond sounds for src/client/ice_sounds.gd.

Run: python3 assets/audio/make_ice.py   (needs numpy and ffmpeg)
Writes assets/audio/ice/ (3 variants each):
  ice_crack_N  a sharp crack under a step: a fast falling zip, a dry snap and a short glassy ring (0.5 s)
  ice_groan_N  the pond ice settling in the cold: a long low sweep with pings, heard from the shore (2.5 to 3.5 s)
Recordings go in assets/audio/recorded/ice/ under the same names; the game prefers them.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_stance  # noqa: E402
from make_sounds import SR, add, band, env, highpass, lowpass, noise, ping  # noqa: E402

make_stance.OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ice")
VARIANTS = 3


def zip_tone(rng, dur, f0, f1, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = np.cumsum(f) / SR
    return amp * np.sin(2 * np.pi * ph) * np.exp(-t / (dur * 0.35))


def crack(rng):
    out = np.zeros(int(0.7 * SR))
    snap = noise(rng, int(0.03 * SR), lambda f: highpass(f, 1500) * lowpass(f, 7000)) * env(int(0.03 * SR), 0.0003, 0.007)
    add(out, snap / (np.max(np.abs(snap)) + 1e-9), 0.0)
    add(out, 0.6 * zip_tone(rng, rng.uniform(0.12, 0.2), rng.uniform(5500, 7500), rng.uniform(900, 1400)), 0.002)

    for _ in range(int(rng.integers(2, 4))):
        add(out, 0.12 * ping(rng.uniform(2500, 5200), rng.uniform(0.05, 0.12), 0.4), rng.uniform(0.0, 0.1))

    add(out, 0.25 * ping(rng.uniform(220, 320), 0.08, 0.3), 0.003)
    out *= 0.8 / (np.max(np.abs(out)) + 1e-9)
    out[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    return out


def groan(rng):
    dur = rng.uniform(2.5, 3.5)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(130, 220)
    f = f0 * (1.0 + 0.9 * np.sin(np.pi * t / dur) ** 2 * rng.choice([-0.35, 0.5]))
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph) + 0.4 * np.sin(2 * np.pi * 2.01 * ph) + 0.2 * np.sin(2 * np.pi * 3.02 * ph)
    x *= np.sin(np.pi * t / dur) ** 1.5
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * rng.uniform(7, 14) * t)
    x /= np.max(np.abs(x)) + 1e-9
    out = 0.6 * x

    for _ in range(int(rng.integers(3, 7))):
        add(out, 0.35 * ping(rng.uniform(1200, 3600), rng.uniform(0.04, 0.1), 0.4), rng.uniform(0.2, dur - 0.6))

    out *= 0.7 / (np.max(np.abs(out)) + 1e-9)
    fade = int(0.05 * SR)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def main():
    rng = np.random.default_rng(20261121)

    for name, make in (("ice_crack", crack), ("ice_groan", groan)):
        for v in range(VARIANTS):
            make_stance.write_ogg("%s_%d" % (name, v), make(rng))

    print("Wrote %d ice sounds to %s" % (2 * VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
