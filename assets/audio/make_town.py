"""Makes placeholder town sounds for src/client/town_sounds.gd.

Run: python3 assets/audio/make_town.py   (needs numpy and ffmpeg)
Writes assets/audio/town/: town_bell_N (3 one-shot bell strikes with a long ring), and seamless
loops town_hammering (a smith or builder at work), town_fire (a crackling hearth) and town_crowd
(a busy square's murmur, no words). Recordings go in assets/audio/recorded/town/ under the
same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import soft_limit, SR, add, band, burst, env, freqs, highpass, lowpass, noise, shape, thump  # noqa: E402
from make_water import normalize, shaped_noise, slow_swell  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "town")


def write_ogg(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(soft_limit(x), -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def bell(rng):
    """A tower bell: a strike, then inharmonic partials that ring and fade over about 5 s."""
    n = int(5.5 * SR)
    t = np.arange(n) / SR
    hum = rng.uniform(190, 260)
    out = np.zeros(n)

    for ratio, amp, decay in ((0.5, 0.5, 3.5), (1.0, 1.0, 3.0), (1.19, 0.6, 2.4), (1.56, 0.5, 1.8), (2.0, 0.55, 1.5), (2.5, 0.3, 1.0), (3.1, 0.25, 0.7), (4.2, 0.15, 0.4)):
        out += amp * np.sin(2 * np.pi * hum * ratio * t + rng.uniform(0, 6)) * np.exp(-t / decay) * (1.0 + 0.04 * np.sin(2 * np.pi * rng.uniform(0.5, 2.0) * t))

    strike = noise(rng, int(0.05 * SR), lambda f: band(f, 2500, 1.0)) * env(int(0.05 * SR), 0.0005, 0.01)
    add(out, strike / (np.max(np.abs(strike)) + 1e-9) * 0.6, 0.0)
    out = out - np.mean(out)
    out[-int(0.5 * SR):] *= np.linspace(1, 0, int(0.5 * SR))
    return out * (0.85 / np.max(np.abs(out)))


def hammering(rng, n):
    """Steady hammer blows on an anvil, with now and then a double tap."""
    out = np.zeros(n)
    base = rng.uniform(1500, 2100)
    at = 0.2

    while at < n / SR - 1.0:
        m = int(0.5 * SR)
        t = np.arange(m) / SR
        strike = sum(np.sin(2 * np.pi * base * k * t) * np.exp(-t / d) * a for k, d, a in ((1.0, 0.12, 1.0), (1.47, 0.07, 0.55), (2.1, 0.04, 0.4)))
        strike += 0.8 * thump(rng, 0.5, 140, 0.03, 2000)[:m]
        add(out, strike * rng.uniform(0.7, 1.0), at)

        if rng.random() < 0.3:
            add(out, strike * 0.6, at + 0.18)

        at += rng.uniform(0.9, 1.3)

    return normalize(out, 0.12) * 1.3


def fire(rng, n):
    """A hearth: a low soft roar, with crackles and sparse pops."""
    roar = shaped_noise(rng, n, lambda f: band(f, 220, 1.0) * lowpass(f, 900, 2))
    roar /= np.std(roar)
    out = roar * 0.5 * slow_swell(rng, n, 0.2, (3, 5, 9))

    for _ in range(int(14 * n / SR)):
        m = int(rng.uniform(0.004, 0.02) * SR)
        crack = shaped_noise(rng, m, lambda f: band(f, rng.uniform(1500, 4500), 0.8)) * np.hanning(m)
        crack /= np.max(np.abs(crack)) + 1e-9
        idx = (rng.integers(0, n) + np.arange(m)) % n
        out[idx] += crack * rng.pareto(3.0) * 0.5

    for _ in range(int(0.5 * n / SR)):
        m = int(0.03 * SR)
        pop = shaped_noise(rng, m, lambda f: band(f, 900, 0.8)) * np.exp(-np.arange(m) / SR / 0.006)
        pop /= np.max(np.abs(pop)) + 1e-9
        idx = (rng.integers(0, n) + np.arange(m)) % n
        out[idx] += pop * 1.0

    return normalize(out, 0.12) * 1.3


def crowd(rng, n):
    """A babble: many soft voices, shaped noise through vowel-like bands with syllable rhythm, no words."""
    out = np.zeros(n)
    t = np.arange(n) / SR

    for _ in range(14):
        f1 = rng.uniform(350, 800)
        f2 = rng.uniform(1100, 2300)
        voice = shaped_noise(rng, n, lambda f: band(f, f1, 0.35) + 0.6 * band(f, f2, 0.3))
        rate = rng.uniform(2.5, 5.5)
        syll = np.clip(0.5 + 0.9 * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6)) * np.sin(2 * np.pi * rng.uniform(0.1, 0.4) * t + rng.uniform(0, 6)), 0, 1)
        out += voice / (np.std(voice) + 1e-9) * syll * rng.uniform(0.3, 1.0)

    return normalize(out, 0.1) * 1.3


def main():
    rng = np.random.default_rng(20261020)
    for v in range(3):
        write_ogg("town_bell_%d" % v, bell(rng))
    write_ogg("town_hammering", hammering(rng, 12 * SR))
    write_ogg("town_fire", fire(rng, 14 * SR))
    write_ogg("town_crowd", crowd(rng, 16 * SR))
    print("Wrote 6 town sounds to %s" % OUT)


if __name__ == "__main__":
    main()
