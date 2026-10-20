"""Makes placeholder water loops for src/client/water_sounds.gd.

Run: python3 assets/audio/make_water.py   (needs numpy and ffmpeg)
Writes assets/audio/water/water_<kind>.ogg, each a seamless loop (circular noise
and bubbles that wrap around the end). Kinds: brook (babbling, bright), river
(broad soft rush), pond (slow soft lapping at a shore), fall (heavy roar).
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


# Owner 2026-10-20: the river sounded like a raging ocean surf, wrong in character, not only loud. The
# wide low rumble and the broadband wash were the surf. Brook and river are now made of small
# bubbles and trickles (higher, brighter, many tiny events) with only a faint wash and no rumble;
# real roar is left to the waterfall. The river is the same babble a little deeper and softer.

def brook(rng, n):
    bed = shaped_noise(rng, n, lambda f: band(f, 2600, 1.0) * highpass(f, 900, 2))
    bed /= np.std(bed)
    b = bubbles(rng, n, 200, 400, 2000, 0.010, 1.0)
    b /= np.std(b) + 1e-9
    trickle = bubbles(rng, n, 140, 1400, 4200, 0.005, 1.0)
    trickle /= np.std(trickle) + 1e-9
    return normalize((0.2 * bed + 1.0 * b + 0.7 * trickle) * slow_swell(rng, n, 0.2))


def river(rng, n):
    wash = shaped_noise(rng, n, lambda f: band(f, 2200, 1.0) * highpass(f, 900, 2))
    wash /= np.std(wash)
    b = bubbles(rng, n, 110, 250, 1200, 0.016, 1.0)
    b /= np.std(b) + 1e-9
    trickle = bubbles(rng, n, 100, 1000, 3200, 0.006, 1.0)
    trickle /= np.std(trickle) + 1e-9
    return normalize((0.12 * wash + 1.0 * b + 0.6 * trickle) * slow_swell(rng, n, 0.2))


def pond(rng, n):
    """Soft laps at a shore: slow swells of hushed noise, now and then a tiny plink."""
    out = np.zeros(n)
    laps = int(n / SR / 2.2)
    for _ in range(laps):
        d = rng.uniform(0.5, 1.0)
        m = int(d * SR)
        t = np.arange(m) / SR
        lap = shaped_noise(rng, m, lambda f: band(f, 700, 1.0) * lowpass(f, 2200, 2)) * np.sin(np.pi * t / d) ** 2
        lap /= np.max(np.abs(lap)) + 1e-9
        at = rng.integers(0, n)
        idx = (at + np.arange(m)) % n
        out[idx] += lap * rng.uniform(0.3, 1.0)
    b = bubbles(rng, n, 6, 500, 1400, 0.01, 1.0)
    b /= np.std(b) + 1e-9
    out /= np.std(out) + 1e-9
    return normalize(out * 0.9 + b * 0.35)


def fall(rng, n):
    roar = shaped_noise(rng, n, lambda f: lowpass(f, 6500, 2) * highpass(f, 60, 2) / (np.maximum(f, 120) / 500) ** 0.3)
    roar /= np.std(roar)
    rumble = shaped_noise(rng, n, lambda f: lowpass(f, 180, 2) * highpass(f, 30, 2))
    rumble /= np.std(rumble)
    hiss = shaped_noise(rng, n, lambda f: band(f, 4000, 0.8))
    hiss /= np.std(hiss)
    return normalize((roar + 0.7 * rumble + 0.4 * hiss) * slow_swell(rng, n, 0.12, (2, 5, 9)))


def main():
    rng = np.random.default_rng(20261020)
    for name, make, seconds in (("water_brook", brook, 14), ("water_river", river, 16),
                                ("water_pond", pond, 20), ("water_fall", fall, 12)):
        write_ogg(name, make(rng, seconds * SR))
    print("Wrote 4 water loops to %s" % OUT)


if __name__ == "__main__":
    main()
