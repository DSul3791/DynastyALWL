"""Makes placeholder cooking and eating sounds for src/client/fire_sounds.gd and item_sounds.gd.

Run: python3 assets/audio/make_cooking.py   (needs numpy and ffmpeg)
Writes assets/audio/cooking/ (2 or 3 variants each):
  cook_sizzle   food laid on the embers: a fat hiss with pops that dies away, 3 s
  fire_fuel     a stick or log laid on the fire: a wooden knock and a brief flare of crackles, 1.2 s
  eat_crunch    a crisp bite and a few chews (roast forage, nuts, roots), 1.2 s
  eat_soft      soft chewing (berries, greens, mushrooms), 1.0 s
  drink_gulp    two swallows, 0.9 s
  heal_poultice a wet leaf poultice pressed onto skin: soft pats and a squelch, 0.8 s
  heal_bandage  a bandage wrapped round: cloth rustle and a tug, 0.9 s
  stomach_growl a hungry stomach: a low gurgling rumble, 1.6 s
Recordings go in assets/audio/recorded/cooking/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise, ping, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cooking")


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
    x[:int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    fade = min(int(0.08 * SR), len(x) // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def pops(rng, n, count, center, level):
    out = np.zeros(n)

    for _ in range(count):
        m = int(0.006 * SR)
        g = noise(rng, m, lambda f: band(f, center * rng.uniform(0.7, 1.4), 1.0)) * env(m, 0.0003, 0.0015)
        add(out, g / (np.max(np.abs(g)) + 1e-9) * rng.uniform(0.3, 1.0) * level, rng.uniform(0.0, n / SR - 0.01))

    return out


def cook_sizzle(rng):
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    hiss = noise(rng, n, lambda f: band(f, 5000, 1.2) * highpass(f, 1500))
    hiss /= np.std(hiss) + 1e-9
    shape = np.minimum(t / 0.08, 1.0) * (0.35 + 0.65 * np.exp(-t / 1.1))
    flutter = 0.75 + 0.25 * np.abs(np.sin(2 * np.pi * rng.uniform(5, 9) * t))
    return finish(0.25 * hiss * shape * flutter + pops(rng, n, 30, 2500, 0.6) * np.exp(-t / 1.6))


def fire_fuel(rng):
    n = int(1.2 * SR)
    out = np.zeros(n)
    add(out, thump(rng, 0.15, rng.uniform(100, 130), 0.03, 1100), 0.0)
    t = np.arange(n) / SR
    flare = pops(rng, n, 25, 1800, 0.5) * np.where(t > 0.15, np.exp(-(t - 0.15) / 0.4), 0.0)
    return finish(out + flare)


def chew(rng, at, out, crisp):
    m = int(0.09 * SR)
    g = noise(rng, m, lambda f: band(f, 900 if not crisp else 2200, 1.2) * lowpass(f, 4000)) * env(m, 0.01, 0.03)
    add(out, g / (np.max(np.abs(g)) + 1e-9) * rng.uniform(0.25, 0.45), at)


def eat_crunch(rng):
    n = int(1.2 * SR)
    out = np.zeros(n)
    bite = noise(rng, int(0.05 * SR), lambda f: highpass(f, 900) * lowpass(f, 6000)) * env(int(0.05 * SR), 0.0005, 0.01)
    add(out, bite / (np.max(np.abs(bite)) + 1e-9), 0.0)
    add(out, pops(rng, int(0.12 * SR), 8, 3000, 0.5), 0.005)

    for k in range(4):
        chew(rng, 0.3 + k * rng.uniform(0.18, 0.22), out, True)

    return finish(out)


def eat_soft(rng):
    n = int(1.0 * SR)
    out = np.zeros(n)

    for k in range(4):
        chew(rng, 0.03 + k * rng.uniform(0.2, 0.24), out, False)

    return finish(out, 0.6)


def drink_gulp(rng):
    n = int(0.9 * SR)
    out = np.zeros(n)

    for at in (0.1, 0.5):
        m = int(0.12 * SR)
        tt = np.arange(m) / SR
        f0 = rng.uniform(140, 200)
        gulp = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.8 * tt / 0.12)) / SR) * env(m, 0.01, 0.03)
        add(out, gulp * 0.8, at)
        add(out, thump(rng, 0.08, 70, 0.02, 400) * 0.5, at)

    return finish(out, 0.6)


def heal_poultice(rng):
    out = np.zeros(int(0.8 * SR))

    for at in (0.0, 0.18, 0.34):
        add(out, thump(rng, 0.1, rng.uniform(90, 130), 0.02, 500) * rng.uniform(0.5, 0.9), at)

    wet = noise(rng, int(0.3 * SR), lambda f: band(f, 700, 1.2) * lowpass(f, 1800, 2)) * env(int(0.3 * SR), 0.03, 0.08)
    add(out, wet / (np.max(np.abs(wet)) + 1e-9) * 0.5, 0.05)
    return finish(out, 0.6)


def heal_bandage(rng):
    out = np.zeros(int(0.9 * SR))

    for at in (0.0, 0.3):
        cloth = noise(rng, int(0.3 * SR), lambda f: band(f, 2000, 1.3) * highpass(f, 600)) * env(int(0.3 * SR), 0.08, 0.1)
        add(out, cloth / (np.max(np.abs(cloth)) + 1e-9) * 0.5, at)

    add(out, thump(rng, 0.06, 140, 0.012, 900) * 0.4, 0.62)
    return finish(out, 0.55)


def stomach_growl(rng):
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    low = noise(rng, n, lambda f: band(f, 110, 0.9) * lowpass(f, 300, 3))
    low /= np.max(np.abs(low)) + 1e-9
    wobble = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(6, 11) * t + rng.uniform(0, 6))
    swell = np.sin(np.pi * t / 1.6) ** 2
    gurgle = noise(rng, n, lambda f: band(f, 380, 1.0) * lowpass(f, 800, 2))
    gurgle /= np.max(np.abs(gurgle)) + 1e-9
    return finish(low * swell * (0.4 + 0.6 * wobble) + 0.35 * gurgle * swell * wobble ** 2, 0.6)


SOUNDS = {"cook_sizzle": (cook_sizzle, 2), "fire_fuel": (fire_fuel, 2), "eat_crunch": (eat_crunch, 3), "eat_soft": (eat_soft, 3), "drink_gulp": (drink_gulp, 2),
          "heal_poultice": (heal_poultice, 2), "heal_bandage": (heal_bandage, 2), "stomach_growl": (stomach_growl, 2)}


def main():
    rng = np.random.default_rng(20261028)
    count = 0

    for name, (make, variants) in SOUNDS.items():
        for v in range(variants):
            write_ogg("%s_%d" % (name, v), make(rng))
            count += 1

    print("Wrote %d cooking sounds to %s" % (count, OUT))


if __name__ == "__main__":
    main()
