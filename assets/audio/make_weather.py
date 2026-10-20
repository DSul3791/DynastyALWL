"""Makes placeholder weather sounds for src/client/weather_sounds.gd.

Run: python3 assets/audio/make_weather.py   (needs numpy and ffmpeg)
Writes assets/audio/weather/<name>.ogg: seamless loops rain_light, rain_heavy, rain_leaves
(rain pattering on foliage), rain_water (rain on a pond or river), wind_storm (a howling
gale), and three one-shot thunder_N rolls. Recordings go in assets/audio/recorded/weather/
under the same names (thunder_N and the loops may have _N variants); the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, band, freqs, highpass, lowpass  # noqa: E402
from make_water import normalize, shaped_noise, slow_swell  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weather")


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


def drops(rng, n, rate, center, octaves, decay, gain=1.0):
    """Tiny noise ticks (rain drops hitting something), wrapped around the loop end."""
    out = np.zeros(n)
    m = int(decay * 6 * SR)
    t = np.arange(m) / SR

    for _ in range(int(rate * n / SR)):
        tick = shaped_noise(rng, m, lambda f: band(f, center * rng.uniform(0.7, 1.4), octaves)) * np.exp(-t / decay)
        idx = (rng.integers(0, n) + np.arange(m)) % n
        out[idx] += tick * rng.pareto(4.0) * gain

    return out


def rain_light(rng, n):
    hiss = shaped_noise(rng, n, lambda f: band(f, 5500, 1.2) * highpass(f, 1800, 2))
    hiss /= np.std(hiss)
    d = drops(rng, n, 160, 4000, 1.0, 0.004)
    d /= np.std(d) + 1e-9
    return normalize((0.7 * hiss + 0.5 * d) * slow_swell(rng, n, 0.12, (2, 4, 7)))


def rain_heavy(rng, n):
    hiss = shaped_noise(rng, n, lambda f: band(f, 4500, 1.6) * highpass(f, 900, 2))
    hiss /= np.std(hiss)
    body = shaped_noise(rng, n, lambda f: band(f, 600, 1.2) * highpass(f, 150, 2))
    body /= np.std(body)
    d = drops(rng, n, 420, 3000, 1.2, 0.006)
    d /= np.std(d) + 1e-9
    return normalize((hiss + 0.5 * body + 0.5 * d) * slow_swell(rng, n, 0.15, (2, 5, 9)))


def rain_leaves(rng, n):
    d = drops(rng, n, 380, 2200, 0.9, 0.007)
    d /= np.std(d) + 1e-9
    soft = shaped_noise(rng, n, lambda f: band(f, 2600, 1.0) * highpass(f, 900, 2))
    soft /= np.std(soft)
    return normalize((0.9 * d + 0.4 * soft) * slow_swell(rng, n, 0.1, (3, 6, 8)))


def rain_water(rng, n):
    hiss = shaped_noise(rng, n, lambda f: band(f, 3500, 1.3) * highpass(f, 1200, 2))
    hiss /= np.std(hiss)
    pits = drops(rng, n, 120, 1800, 0.7, 0.012)
    pits /= np.std(pits) + 1e-9
    return normalize((0.6 * hiss + 0.7 * pits) * slow_swell(rng, n, 0.1, (3, 5, 8)))


def wind_storm(rng, n):
    low = shaped_noise(rng, n, lambda f: lowpass(f, 500, 2) * highpass(f, 40, 2))
    low /= np.std(low)
    howl = shaped_noise(rng, n, lambda f: band(f, 650, 0.5) * highpass(f, 250, 2))
    howl /= np.std(howl)
    t = np.arange(n) / n
    sweep = 0.55 + 0.45 * np.sin(2 * np.pi * 3 * t + 1.0) * np.sin(2 * np.pi * 5 * t + 0.4)
    return normalize((low + 1.1 * howl * sweep) * slow_swell(rng, n, 0.35, (2, 3, 5)))


def thunder(rng, seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    crack = shaped_noise(rng, n, lambda f: band(f, 900, 1.5) * highpass(f, 200, 2)) * np.exp(-t / 0.12) * (t < 0.6)
    rumble = shaped_noise(rng, n, lambda f: lowpass(f, 220, 3) * highpass(f, 25, 2))
    rolls = np.zeros(n)

    for k in range(rng.integers(4, 8)):
        at = rng.uniform(0.1, seconds * 0.6)
        width = rng.uniform(0.6, 1.8)
        rolls += np.exp(-((t - at) / width) ** 2) * rng.uniform(0.4, 1.0)

    x = rumble / np.std(rumble) * (0.2 + rolls) * np.exp(-t / (seconds * 0.55)) + 1.4 * crack / (np.std(crack) + 1e-9) * 0.5
    x = x - np.mean(x)
    fade = int(0.03 * SR)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-int(0.5 * SR):] *= np.linspace(1, 0, int(0.5 * SR))
    return np.tanh(x / np.max(np.abs(x)) * 1.6) * 0.8


def thunder_near(rng, seconds):
    """A close strike: a sharp, wide crack and a heavy thud, a short tumble."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    crack = shaped_noise(rng, n, lambda f: highpass(f, 150, 2) * lowpass(f, 5500, 1)) * np.exp(-t / 0.09)
    thud = shaped_noise(rng, n, lambda f: lowpass(f, 250, 3) * highpass(f, 30, 2)) * np.exp(-t / 0.5)
    tumble = shaped_noise(rng, n, lambda f: lowpass(f, 400, 2) * highpass(f, 40, 2)) * np.exp(-t / 1.1) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.3 * t + rng.uniform(0, 6)))
    x = crack / np.std(crack) * 1.0 + thud / np.std(thud) * 0.9 + tumble / np.std(tumble) * 0.5
    x = x - np.mean(x)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    x[-int(0.4 * SR):] *= np.linspace(1, 0, int(0.4 * SR))
    return np.tanh(x / np.max(np.abs(x)) * 1.8) * 0.85


def thunder_far(rng, seconds):
    """A distant strike: only a long, low grumble, no crack."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rumble = shaped_noise(rng, n, lambda f: lowpass(f, 140, 3) * highpass(f, 25, 2))
    rolls = np.zeros(n)

    for k in range(rng.integers(3, 6)):
        rolls += np.exp(-((t - rng.uniform(0.5, seconds * 0.7)) / rng.uniform(0.8, 2.0)) ** 2) * rng.uniform(0.4, 1.0)

    x = rumble / np.std(rumble) * (0.15 + rolls) * np.minimum(t / 0.6, 1.0) * np.exp(-t / (seconds * 0.5))
    x[-int(0.6 * SR):] *= np.linspace(1, 0, int(0.6 * SR))
    return np.tanh(x / np.max(np.abs(x)) * 1.4) * 0.8


def main():
    rng = np.random.default_rng(20261020)
    for name, make, seconds in (("rain_light", rain_light, 14), ("rain_heavy", rain_heavy, 14),
                                ("rain_leaves", rain_leaves, 16), ("rain_water", rain_water, 14),
                                ("wind_storm", wind_storm, 16)):
        write_ogg(name, make(rng, seconds * SR))
    for v, seconds in enumerate((7.0, 9.0, 6.0)):
        write_ogg("thunder_%d" % v, thunder(rng, seconds))
    for v in range(3):
        write_ogg("thunder_near_%d" % v, thunder_near(rng, 3.5))
        write_ogg("thunder_far_%d" % v, thunder_far(rng, 11.0))

    print("Wrote 14 weather sounds to %s" % OUT)


if __name__ == "__main__":
    main()
