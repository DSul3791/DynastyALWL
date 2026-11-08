"""Makes placeholder frozen-pond sounds for src/client/ice_sounds.gd.

Run: python3 assets/audio/make_ice.py   (needs numpy and ffmpeg)
Writes assets/audio/ice/ (3 variants each):
  ice_crack_N  a sharp crack under a step: a fast falling zip, a dry snap and a short glassy ring (0.5 s)
  ice_groan_N  the pond ice settling in the cold: a long low sweep with pings, heard from the shore (2.5 to 3.5 s)
  --ice-feel (docs/design/ice_walk_feel.md):
  ice_skim_N   a wader's step through skim: a glassy tinkle of thin plates (0.4 s)
  ice_film_N   a step pushed through film ice: a heavy crunch, plates knocking, a slosh (0.6 s)
  ice_plunge_N breaking through film to the bed: a crack, a low thump and a splash (1.2 s)
  ice_zing_N   a crack running off through a thin sheet: a long falling chirp, high notes first (0.6 to 1.2 s)
  ice_boom_N   a thick sheet cracking as the air warms or cools: a low thud and rumble (1.5 s)
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


def _finish(out, peak=0.8, fade_s=0.05):
    out *= peak / (np.max(np.abs(out)) + 1e-9)
    fade = int(fade_s * SR)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def skim(rng):
    out = np.zeros(int(0.45 * SR))

    for _ in range(int(rng.integers(8, 14))):
        add(out, rng.uniform(0.15, 0.4) * ping(rng.uniform(3000, 7500), rng.uniform(0.008, 0.03), 0.12), rng.uniform(0.0, 0.25))

    crunch = noise(rng, int(0.12 * SR), lambda f: highpass(f, 2500) * lowpass(f, 9000)) * env(int(0.12 * SR), 0.002, 0.03)
    add(out, 0.3 * crunch / (np.max(np.abs(crunch)) + 1e-9), 0.0)
    return _finish(out, 0.7)


def film(rng):
    out = np.zeros(int(0.65 * SR))
    crunch = noise(rng, int(0.25 * SR), lambda f: band(f, 1400, 1.3)) * env(int(0.25 * SR), 0.004, 0.06)
    add(out, crunch / (np.max(np.abs(crunch)) + 1e-9), 0.0)

    for _ in range(int(rng.integers(3, 6))):
        add(out, 0.25 * ping(rng.uniform(600, 2200), rng.uniform(0.02, 0.06), 0.2), rng.uniform(0.03, 0.3))

    slosh = noise(rng, int(0.4 * SR), lambda f: band(f, 500, 1.0)) * np.sin(np.linspace(0, np.pi, int(0.4 * SR))) ** 2
    add(out, 0.35 * slosh / (np.max(np.abs(slosh)) + 1e-9), 0.15)
    return _finish(out, 0.75)


def plunge(rng):
    out = np.zeros(int(1.25 * SR))
    add(out, crack(rng), 0.0)
    t = np.arange(int(0.4 * SR)) / SR
    thud = np.sin(2 * np.pi * rng.uniform(55, 80) * t) * np.exp(-t / 0.09)
    add(out, 0.9 * thud, 0.04)
    splash = noise(rng, int(0.9 * SR), lambda f: band(f, 900, 1.6)) * env(int(0.9 * SR), 0.01, 0.25)
    add(out, 0.7 * splash / (np.max(np.abs(splash)) + 1e-9), 0.06)
    return _finish(out, 0.85, 0.1)


def zing(rng):
    dur = rng.uniform(0.6, 1.2)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = rng.uniform(5000, 7000) * (rng.uniform(300, 500) / 6000.0) ** (t / dur) ** 0.6
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph) * np.exp(-t / (dur * 0.45)) * np.minimum(t / 0.004, 1.0)
    out = np.zeros(n + int(0.1 * SR))
    add(out, x, 0.0)
    return _finish(out, 0.6)


def boom(rng):
    dur = 1.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * rng.uniform(40, 70) * t) * np.exp(-t / 0.25)
    rumble = noise(rng, n, lambda f: band(f, 80, 0.8)) * env(n, 0.02, 0.45)
    out = 0.8 * thud + 0.5 * rumble / (np.max(np.abs(rumble)) + 1e-9)
    add(out, 0.15 * ping(rng.uniform(900, 1600), 0.08, 0.4), rng.uniform(0.05, 0.3))
    return _finish(out, 0.75, 0.15)


def main():
    rng = np.random.default_rng(20261121)

    makers = (("ice_crack", crack), ("ice_groan", groan))

    for name, make in makers:
        for v in range(VARIANTS):
            make_stance.write_ogg("%s_%d" % (name, v), make(rng))

    # --ice-feel sounds from their own seed, so the old two keep their exact waves.
    rng2 = np.random.default_rng(20261108)
    feel_makers = (("ice_skim", skim), ("ice_film", film), ("ice_plunge", plunge), ("ice_zing", zing), ("ice_boom", boom))

    for name, make in feel_makers:
        for v in range(VARIANTS):
            make_stance.write_ogg("%s_%d" % (name, v), make(rng2))

    print("Wrote %d ice sounds to %s" % ((len(makers) + len(feel_makers)) * VARIANTS, make_stance.OUT))


if __name__ == "__main__":
    main()
