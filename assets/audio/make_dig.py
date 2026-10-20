"""Makes placeholder dig sounds for src/client/dig_sounds.gd.

Run: python3 assets/audio/make_dig.py   (needs numpy and ffmpeg)
Writes assets/audio/dig/<name>_N.ogg, 3 variants each: dig_soil (a spade scoop and crumbling
earth), dig_clay (wet and sticky), dig_sand (a hissing pour), dig_gravel (crunching stones),
dig_rock (a heavy chunk and tumbling pieces), dig_ore (rock with a metal clink), dig_water
(water splashing and gurgling into a hole). Recordings go in assets/audio/recorded/dig/
under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, freqs, grains, highpass, lowpass, noise, shape, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dig")
VARIANTS = 3


def write_ogg(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.85, top=6000.0):
    x = x - np.mean(x)
    n = len(x)
    x = shape(x, lowpass(freqs(n), top, 1))
    rise = min(int(0.004 * SR), n // 4)
    x[:rise] *= np.linspace(0, 1, rise)
    fade = min(int(0.05 * SR), n // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def swell(n, rise, fall):
    t = np.arange(n) / SR
    return np.minimum(t / rise, 1.0) * np.exp(-np.maximum(t - rise, 0) / fall)


def soil(rng):
    n = int(0.8 * SR)
    out = np.zeros(n)
    scoop = noise(rng, int(0.22 * SR), lambda f: band(f, 1200, 1.0) * highpass(f, 200)) * env(int(0.22 * SR), 0.03, 0.08)
    add(out, scoop / (np.max(np.abs(scoop)) + 1e-9) * 0.8, 0.0)
    add(out, thump(rng, 0.2, 85, 0.07, 700) * 0.7, 0.05)
    add(out, grains(rng, n, 22, 0.18, 0.5, lambda: burst(rng, rng.uniform(0.008, 0.02), rng.uniform(700, 1500), 0.8)), 0.0)
    return finish(out, top=3500.0)


def clay(rng):
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    body = noise(rng, n, lambda f: band(f, 500, 0.9) * highpass(f, 120)) * swell(n, 0.04, 0.22)
    body *= 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(18, 30) * t)
    out = body / (np.max(np.abs(body)) + 1e-9)
    add(out, thump(rng, 0.25, 70, 0.1, 500) * 0.6, 0.02)
    pop = noise(rng, int(0.05 * SR), lambda f: band(f, 900, 0.6)) * env(int(0.05 * SR), 0.002, 0.012)
    add(out, pop / (np.max(np.abs(pop)) + 1e-9) * 0.5, 0.35 + rng.uniform(0, 0.2))
    return finish(out, top=2500.0)


def sand(rng):
    n = int(1.0 * SR)
    hiss = noise(rng, n, lambda f: band(f, 3000, 1.1) * highpass(f, 900)) * swell(n, 0.12, 0.28)
    out = hiss / (np.max(np.abs(hiss)) + 1e-9) * 0.7
    scoop = noise(rng, int(0.2 * SR), lambda f: band(f, 1500, 1.0)) * env(int(0.2 * SR), 0.03, 0.07)
    add(out, scoop / (np.max(np.abs(scoop)) + 1e-9) * 0.6, 0.0)
    return finish(out, top=5000.0)


def gravel(rng):
    n = int(0.9 * SR)
    out = grains(rng, n, 60, 0.0, 0.7, lambda: burst(rng, rng.uniform(0.005, 0.014), rng.uniform(1800, 3200), 0.7), 0.5)
    add(out, thump(rng, 0.2, 100, 0.06, 900) * 0.5, 0.02)
    return finish(out, top=5500.0)


def rock(rng):
    n = int(1.1 * SR)
    out = np.zeros(n)
    add(out, thump(rng, 0.3, 120, 0.09, 1800) * 1.0, 0.0)
    crack = noise(rng, int(0.12 * SR), lambda f: band(f, 1800, 0.8)) * env(int(0.12 * SR), 0.001, 0.02)
    add(out, crack / (np.max(np.abs(crack)) + 1e-9) * 0.7, 0.0)
    add(out, grains(rng, n, 9, 0.12, 0.8, lambda: burst(rng, rng.uniform(0.012, 0.03), rng.uniform(900, 1800), 0.6) * 1.6, 0.6), 0.0)
    return finish(out, top=5000.0)


def ore(rng):
    out = rock(rng) * 0.8
    out = np.pad(out, (0, int(0.2 * SR)))
    base = rng.uniform(2300, 2900)
    t = np.arange(int(0.35 * SR)) / SR
    clink = sum(np.sin(2 * np.pi * base * k * t) * np.exp(-t / d) * a for k, d, a in ((1.0, 0.08, 1.0), (1.53, 0.05, 0.6), (2.1, 0.03, 0.4)))
    add(out, clink * 0.22, 0.03)
    return finish(out, top=7000.0)


def water(rng):
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    splash = noise(rng, n, lambda f: band(f, 1300, 1.2) * highpass(f, 250)) * (env(n, 0.005, 0.12) + 0.35 * swell(n, 0.2, 0.4))
    splash *= 0.7 + 0.3 * np.sin(2 * np.pi * rng.uniform(9, 16) * t)
    out = splash / (np.max(np.abs(splash)) + 1e-9) * 0.8
    for _ in range(rng.integers(4, 8)):
        m = int(0.07 * SR)
        tt = np.arange(m) / SR
        f0 = rng.uniform(380, 800)
        bub = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 1.2 * tt / 0.07)) / SR) * np.exp(-tt / 0.02)
        add(out, bub * rng.uniform(0.15, 0.4), rng.uniform(0.08, 0.9))
    return finish(out, top=5000.0)


SOUNDS = {"dig_soil": soil, "dig_clay": clay, "dig_sand": sand, "dig_gravel": gravel,
          "dig_rock": rock, "dig_ore": ore, "dig_water": water}


def main():
    rng = np.random.default_rng(20261020)
    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            write_ogg("%s_%d" % (name, v), make(rng))
    print("Wrote %d dig sounds to %s" % (len(SOUNDS) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
