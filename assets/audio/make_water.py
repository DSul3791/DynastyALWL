"""Makes placeholder water loops for src/client/water_sounds.gd.

Run: python3 assets/audio/make_water.py   (needs numpy and ffmpeg)
Writes assets/audio/water/water_<kind>.ogg, each a seamless loop (circular noise
that wraps around the end, 24 s, no bubbles and no periodic swell). Kinds: brook (thin bright
rush, a few small drips), river (fuller smooth rush), pond (soft hush, few soft laps), fall (smooth wide rush).
Real recordings go in assets/audio/recorded/water/ under the same names.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, band, freqs, highpass, lowpass  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "water")


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


def shaped_noise(rng, n, gain_fn):
    f = freqs(n)
    return np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * gain_fn(f), n)


def slow_swell(rng, n, depth, cycles=(3, 5, 8)):
    """A gentle loop-safe amplitude wobble (whole cycles per loop)."""
    t = np.arange(n) / n
    w = sum(np.sin(2 * np.pi * c * t + rng.uniform(0, 2 * np.pi)) for c in cycles) / len(cycles)
    return 1.0 + depth * w


def bubbles(rng, n, rate, f_lo, f_hi, decay, gain):
    """Many tiny rising bubble chirps, wrapped around the loop end."""
    out = np.zeros(n)
    count = int(rate * n / SR)
    for _ in range(count):
        f0 = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        d = rng.uniform(0.5, 1.5) * decay
        m = int(d * 6 * SR)
        t = np.arange(m) / SR
        chirp = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 3.0 * t / d * 0.3)) / SR) * np.exp(-t / d)
        at = rng.integers(0, n)
        idx = (at + np.arange(m)) % n
        out[idx] += chirp * rng.pareto(3.0) * gain
    return out


def normalize(x, rms=0.12):
    """Equal loudness for every loop (the game sets each one's level); a soft clip tames bubble peaks."""
    x = x - np.mean(x)
    return np.tanh(x * (rms / (np.std(x) + 1e-9)) * 1.5)


# Owner 2026-10-20 (third round): the first loops were a raging ocean surf; the bubble rebuild
# (build 145) read as "a witches caldron and a horse brush sweeping". Both came from structure the
# ear picks up: discrete bubbles and a repeating wash pulse. Water is now only steady, smooth,
# broadband flowing noise, shaped by gentle band-passes, with no bubble layer and no periodic
# amplitude swell (a tiny, random, never-repeating drift only). The loops are circular noise, so
# there is no seam, and long (24 s) so the grain does not repeat quickly. Brooks get a few sparse
# small drips; ponds a very soft hush with a few soft, irregular laps; falls a smooth wide rush.

def drift(rng, n, depth=0.05):
    """A random, never-repeating, nearly imperceptible level drift (noise below 0.2 Hz, loop-safe)."""
    w = shaped_noise(rng, n, lambda f: (f < 0.2) * 1.0 + 0.0 * f)
    w /= np.max(np.abs(w)) + 1e-9
    return 1.0 + depth * w


def flow(rng, n, lo, hi, tilt):
    """Smooth flowing-water noise: a band from lo to hi Hz with a gentle spectral tilt (1/f^tilt above lo)."""
    x = shaped_noise(rng, n, lambda f: highpass(f, lo, 2) * lowpass(f, hi, 2) / np.maximum(f / 1000.0, 0.05) ** tilt)
    return x / (np.std(x) + 1e-9)


def drips(rng, n, rate, f_lo, f_hi, gain):
    """A few small, quiet drips: short soft plinks at random times (sparse; wrapped around the loop end)."""
    out = np.zeros(n)

    for _ in range(max(int(rate * n / SR), 1)):
        f0 = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        d = rng.uniform(0.012, 0.03)
        m = int(d * 6 * SR)
        t = np.arange(m) / SR
        plink = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 1.5 * t / d * 0.3)) / SR) * np.exp(-t / d) * np.minimum(t / 0.002, 1.0)
        idx = (rng.integers(0, n) + np.arange(m)) % n
        out[idx] += plink * rng.uniform(0.4, 1.0) * gain

    return out


def brook(rng, n):
    """Brighter and quieter: a thin smooth rush above 1 kHz, a few small drips."""
    body = flow(rng, n, 900, 6500, 0.4)
    air = flow(rng, n, 2500, 9000, 0.1)
    x = (body + 0.5 * air) * drift(rng, n, 0.05)
    x = x / np.std(x) + drips(rng, n, 0.12, 900, 2200, 0.5)
    return normalize(x)


def river(rng, n):
    """Fuller but smooth: a wide soft rush from 300 Hz up, no rumble, no bubbles at all."""
    body = flow(rng, n, 300, 5000, 0.2)
    top = flow(rng, n, 1500, 7000, 0.3)
    x = (body + 0.35 * top) * drift(rng, n, 0.05)
    return normalize(x)


def pond(rng, n):
    """A very soft hush, with a few soft, irregular, widely spaced laps (no regular rhythm)."""
    out = flow(rng, n, 450, 2400, 0.3) * 0.6 * drift(rng, n, 0.05)

    for _ in range(max(int(n / SR / 5.0), 1)):
        d = rng.uniform(0.7, 1.4)
        m = int(d * SR)
        t = np.arange(m) / SR
        lap = shaped_noise(rng, m, lambda f: band(f, 600, 1.0) * lowpass(f, 1800, 2)) * np.sin(np.pi * t / d) ** 3
        lap /= np.max(np.abs(lap)) + 1e-9
        idx = (rng.integers(0, n) + np.arange(m)) % n
        out[idx] += lap * rng.uniform(0.2, 0.6)

    return normalize(out / (np.std(out) + 1e-9))


def fall(rng, n):
    """A smooth wide rush with a soft low body: no rhythm, no pulses."""
    body = flow(rng, n, 150, 6500, 0.2)
    low = flow(rng, n, 80, 400, 0.0)
    x = (body + 0.15 * low) * drift(rng, n, 0.04)
    return normalize(x)


def fall_base(rng, n):
    """The spray and churn where a fall lands, heard close: a steady bright hiss over a wide splashing body, smooth
    (no bubbles, no rhythm: the earlier cauldron and horse-brush complaints)."""
    hiss = flow(rng, n, 2500, 10500, 0.0)
    body = flow(rng, n, 500, 3800, 0.2)
    x = (body + 0.8 * hiss) * drift(rng, n, 0.05)
    return normalize(x)


def main():
    rng = np.random.default_rng(20261020)
    for name, make, seconds in (("water_brook", brook, 24), ("water_river", river, 24),
                                ("water_pond", pond, 24), ("water_fall", fall, 24)):
        write_ogg(name, make(rng, seconds * SR))
    write_ogg("water_fall_base", fall_base(np.random.default_rng(20261121), 24 * SR))   # its own stream: the older loops stay as they were
    print("Wrote 5 water loops to %s" % OUT)


if __name__ == "__main__":
    main()
