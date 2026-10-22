"""Makes placeholder spear sounds for src/client/spear_sounds.gd.

Run: python3 assets/audio/make_spear.py   (needs numpy and ffmpeg)
Writes assets/audio/spear/ (3 variants each): spear_jab (a quick thrust through the air),
spear_throw (the heave and release), spear_flight (a thin air whistle of the spear in flight, 1.5 s,
played pitched and moved along the path) and spear_hit_wood, spear_hit_stone, spear_hit_soil,
spear_hit_flesh. Recordings go in assets/audio/recorded/spear/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spear")
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


def finish(x, peak=0.75):
    x = x - np.mean(x)
    fade = min(int(0.04 * SR), len(x) // 4)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def whoosh(rng, dur, f_lo, f_hi, peak_at):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = noise(rng, n, lambda f: band(f, (f_lo + f_hi) / 2, 1.5) * highpass(f, f_lo * 0.5))
    shape = np.exp(-((t - peak_at * dur) / (dur * 0.22)) ** 2)
    return x * shape / (np.max(np.abs(x)) + 1e-9)


def jab(rng):
    return finish(whoosh(rng, rng.uniform(0.22, 0.32), rng.uniform(500, 800), rng.uniform(2500, 3500), 0.5), 0.6)


def throw(rng):
    n = int(0.7 * SR)
    out = np.zeros(n)
    m = int(0.25 * SR)
    t = np.arange(m) / SR
    heave = noise(rng, m, lambda f: lowpass(f, 700, 2) * highpass(f, 80)) * np.sin(np.pi * t / t[-1]) ** 2
    add(out, heave / (np.max(np.abs(heave)) + 1e-9) * 0.5, 0.0)
    add(out, whoosh(rng, 0.4, 700, 4000, 0.35) * 0.9, 0.22)
    return finish(out, 0.7)


def flight(rng):
    n = int(1.5 * SR)
    t = np.arange(n) / SR
    air = noise(rng, n, lambda f: band(f, rng.uniform(3000, 4500), 0.8) * highpass(f, 1500))
    air = air / (np.max(np.abs(air)) + 1e-9) * (0.7 + 0.3 * np.sin(2 * np.pi * rng.uniform(40, 70) * t))
    tone = np.sin(2 * np.pi * rng.uniform(1100, 1500) * t) * 0.15
    x = (air + tone) * np.minimum(t / 0.1, 1.0) * np.minimum((t[-1] - t) / 0.2, 1.0)
    return finish(x, 0.45)


def ring(f, decay, dur):
    t = np.arange(int(dur * SR)) / SR
    return np.sin(2 * np.pi * f * t) * np.exp(-t / decay)


def thunk(rng, f0, dur, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.5 * np.exp(-t / 0.02))) / SR) * np.exp(-t / (dur * 0.3))
    x += 0.6 * noise(rng, n, lambda f: lowpass(f, 800, 2) * highpass(f, 50)) * env(n, 0.001, dur * 0.2) * 3
    return amp * x / (np.max(np.abs(x)) + 1e-9)


def hit_wood(rng):
    out = np.zeros(int(0.9 * SR))
    add(out, thunk(rng, 130, 0.16, 1.0), 0.0)
    add(out, ring(rng.uniform(180, 240), 0.25, 0.8) * 0.35, 0.02)      # the shaft quivering
    return finish(out, 0.8)


def hit_stone(rng):
    out = np.zeros(int(0.5 * SR))
    m = int(0.02 * SR)
    add(out, noise(rng, m, lambda f: band(f, 3500, 1.0)) * env(m, 0.0004, 0.004) * 4, 0.0)
    add(out, ring(rng.uniform(1200, 1800), 0.04, 0.3) * 0.6, 0.0)
    s = int(0.25 * SR)
    add(out, noise(rng, s, lambda f: band(f, 1800, 1.2) * highpass(f, 600)) * env(s, 0.01, 0.07) * 1.5, 0.03)
    return finish(out, 0.75)


def hit_soil(rng):
    out = np.zeros(int(0.5 * SR))
    add(out, thunk(rng, 80, 0.25, 1.0), 0.0)
    add(out, ring(rng.uniform(150, 200), 0.12, 0.4) * 0.2, 0.02)
    return finish(out, 0.75)


def hit_flesh(rng):
    out = np.zeros(int(0.5 * SR))
    add(out, thunk(rng, 100, 0.2, 1.0), 0.0)
    m = int(0.15 * SR)
    add(out, noise(rng, m, lambda f: band(f, 600, 1.0)) * env(m, 0.005, 0.04) * 2, 0.0)
    return finish(out, 0.75)


SOUNDS = {"spear_jab": jab, "spear_throw": throw, "spear_flight": flight, "spear_hit_wood": hit_wood,
          "spear_hit_stone": hit_stone, "spear_hit_soil": hit_soil, "spear_hit_flesh": hit_flesh}


def main():
    rng = np.random.default_rng(20261027)

    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            write_ogg("%s_%d" % (name, v), make(rng))

    print("Wrote %d spear sounds to %s" % (len(SOUNDS) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
