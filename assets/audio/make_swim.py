"""Makes placeholder swimming and diving sounds for src/client/swim_sounds.gd.

Run: python3 assets/audio/make_swim.py   (needs numpy and ffmpeg)
Writes assets/audio/swim/: swim_splash_small_N and swim_splash_big_N (entering the water, by
speed), swim_stroke_N (an arm pulling through water), swim_dive_N (going under: a gulp of
bubbles), swim_surface_N (breaking the surface: a breath and running drips) and the seamless
loop swim_under (the muffled hum under the water). Recordings go in assets/audio/recorded/swim/
under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, freqs, highpass, lowpass, noise, shape  # noqa: E402
from make_water import bubbles, normalize, shaped_noise, slow_swell  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "swim")
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


def finish(x, peak=0.85):
    x = x - np.mean(x)
    fade = min(int(0.05 * SR), len(x) // 4)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def splash(rng, seconds, low, high, body_cut, drips):
    """A body hitting water: a broad wet burst, a deep thump, and falling drops."""
    n = int(seconds * SR)
    out = np.zeros(n)
    m = int(0.5 * seconds * SR)
    burst = noise(rng, m, lambda f: band(f, high, 1.5) * highpass(f, 200) * lowpass(f, 6000)) * env(m, 0.006, 0.12 * seconds)
    thump = noise(rng, m, lambda f: lowpass(f, body_cut, 2) * highpass(f, 40)) * env(m, 0.008, 0.18 * seconds)
    add(out, burst / (np.max(np.abs(burst)) + 1e-9) * 0.8 + thump / (np.max(np.abs(thump)) + 1e-9) * low, 0.0)

    for _ in range(drips):
        d = int(0.04 * SR)
        t = np.arange(d) / SR
        f0 = rng.uniform(700, 1800)
        drop = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.6 * t / 0.04)) / SR) * np.exp(-t / 0.01)
        add(out, drop * rng.uniform(0.08, 0.3), rng.uniform(0.1, seconds * 0.85))

    return finish(out)


def stroke(rng):
    """An arm pulling through water: a soft rising wash that falls away, with a few bubbles."""
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    wash = noise(rng, n, lambda f: band(f, 900, 1.3) * lowpass(f, 3000, 2) * highpass(f, 120))
    wash *= np.sin(np.pi * np.minimum(t / 0.55, 1.0)) ** 1.5 * np.exp(-t / 0.35)
    wash /= np.max(np.abs(wash)) + 1e-9
    b = bubbles(rng, n, 25, 400, 1400, 0.008, 1.0)
    b *= np.exp(-t / 0.3)
    b /= np.max(np.abs(b)) + 1e-9
    return finish(0.9 * wash + 0.25 * b, 0.7)


def dive(rng):
    """Going under: a rush of bubbles that rises, then thins."""
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    rush = noise(rng, n, lambda f: band(f, 1200, 1.6) * highpass(f, 200)) * env(n, 0.02, 0.35)
    rush /= np.max(np.abs(rush)) + 1e-9
    b = bubbles(rng, n, 120, 300, 1600, 0.012, 1.0) * np.exp(-t / 0.5)
    b /= np.max(np.abs(b)) + 1e-9
    return finish(0.7 * rush + 0.7 * b, 0.7)


def surface(rng):
    """Breaking the surface: a wash of water falling off, a quick breath, running drips."""
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    wash = noise(rng, n, lambda f: band(f, 1400, 1.4) * highpass(f, 200) * lowpass(f, 5000)) * env(n, 0.01, 0.2)
    wash /= np.max(np.abs(wash)) + 1e-9
    m = int(0.4 * SR)
    breath = noise(rng, m, lambda f: band(f, 2200, 1.2) * highpass(f, 400)) * np.sin(np.pi * np.arange(m) / m) ** 2
    breath /= np.max(np.abs(breath)) + 1e-9
    out = 0.8 * wash
    add(out, breath * 0.35, 0.18)

    for _ in range(rng.integers(5, 10)):
        d = int(0.035 * SR)
        tt = np.arange(d) / SR
        f0 = rng.uniform(800, 1900)
        add(out, np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.5 * tt / 0.035)) / SR) * np.exp(-tt / 0.009) * rng.uniform(0.1, 0.3), rng.uniform(0.15, 1.2))

    return finish(out, 0.75)


def under(rng, n):
    """The muffled hum of being underwater: a deep rumble and slow pressure swells."""
    low = shaped_noise(rng, n, lambda f: lowpass(f, 350, 2) * highpass(f, 30, 2))
    low /= np.std(low)
    mid = shaped_noise(rng, n, lambda f: band(f, 600, 1.0) * lowpass(f, 1200, 2))
    mid /= np.std(mid)
    return normalize((1.0 * low + 0.3 * mid) * slow_swell(rng, n, 0.3, (2, 3, 5)))


def main():
    rng = np.random.default_rng(20261020)
    made = 0

    for v in range(VARIANTS):
        write_ogg("swim_splash_small_%d" % v, splash(rng, 0.7, 0.5, 2200, 500, 3))
        write_ogg("swim_splash_big_%d" % v, splash(rng, 1.6, 1.0, 1500, 300, 9))
        write_ogg("swim_stroke_%d" % v, stroke(rng))
        write_ogg("swim_dive_%d" % v, dive(rng))
        write_ogg("swim_surface_%d" % v, surface(rng))
        made += 5

    write_ogg("swim_under", under(rng, 14 * SR))
    print("Wrote %d swim sounds to %s" % (made + 1, OUT))


if __name__ == "__main__":
    main()
