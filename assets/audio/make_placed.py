"""Makes placeholder sounds for placed things and tools for src/client/placed_sounds.gd.

Run: python3 assets/audio/make_placed.py   (needs numpy and ffmpeg)
Writes assets/audio/placed/ (2 variants each):
  place_leanto     poles planted and brush laid over, 1.1 s        place_chest     a heavy box set down, 0.6 s
  place_thump      anything else set on the ground, 0.35 s          pickup_placed   a scrape and lift, 0.6 s
  container_put    something set into a chest, 0.35 s              container_take  something lifted out, 0.35 s
  tool_break       a sharp crack and splinters, 0.8 s              tool_repair     scraping, tapping and a cord rasp, 2.2 s
Recordings go in assets/audio/recorded/placed/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, highpass, lowpass, noise, ping, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "placed")
VARIANTS = 2


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


def finish(x, peak=0.8):
    x = x - np.mean(x)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    fade = min(int(0.05 * SR), len(x) // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def knock(rng, f0, decay, click=1500.0, level=1.0):
    return level * thump(rng, 0.18, f0 * rng.uniform(0.92, 1.08), decay, click)


def rustle(rng, n, center, octaves=1.0):
    x = noise(rng, n, lambda f: band(f, center, octaves) * highpass(f, 400))
    return x / (np.max(np.abs(x)) + 1e-9)


def place_leanto(rng):
    out = np.zeros(int(1.1 * SR))

    for at in (0.0, 0.18, 0.34):
        add(out, knock(rng, rng.uniform(95, 130), 0.03, 1100, 0.9), at)

    brush = rustle(rng, int(0.6 * SR), 2200, 1.2) * env(int(0.6 * SR), 0.12, 0.2)
    add(out, brush * 0.45, 0.4)
    return finish(out)


def place_chest(rng):
    out = np.zeros(int(0.6 * SR))
    add(out, knock(rng, rng.uniform(60, 80), 0.05, 900, 1.2), 0.0)
    add(out, knock(rng, rng.uniform(120, 160), 0.03, 1400, 0.5), 0.07)
    add(out, ping(rng.uniform(220, 320), 0.05, 0.2) * 0.2, 0.01)
    return finish(out)


def place_thump(rng):
    out = np.zeros(int(0.35 * SR))
    add(out, knock(rng, rng.uniform(70, 95), 0.03, 800, 1.0), 0.0)
    return finish(out)


def pickup_placed(rng):
    n = int(0.6 * SR)
    out = np.zeros(n)
    scrape = rustle(rng, int(0.35 * SR), 1100, 1.0) * env(int(0.35 * SR), 0.1, 0.12)
    add(out, scrape * 0.5, 0.0)
    add(out, knock(rng, rng.uniform(100, 130), 0.025, 1000, 0.5), 0.3)
    return finish(out)


def container_put(rng):
    out = np.zeros(int(0.35 * SR))
    add(out, knock(rng, rng.uniform(130, 170), 0.02, 1500, 0.9), 0.0)
    add(out, rustle(rng, int(0.1 * SR), 3000, 1.0) * env(int(0.1 * SR), 0.003, 0.03) * 0.3, 0.02)
    return finish(out)


def container_take(rng):
    out = np.zeros(int(0.35 * SR))
    add(out, rustle(rng, int(0.2 * SR), 1800, 1.0) * env(int(0.2 * SR), 0.05, 0.06) * 0.4, 0.0)
    add(out, knock(rng, rng.uniform(140, 180), 0.02, 1300, 0.4), 0.14)
    return finish(out)


def tool_break(rng):
    out = np.zeros(int(0.8 * SR))
    crack = noise(rng, int(0.06 * SR), lambda f: highpass(f, 600) * lowpass(f, 6000)) * env(int(0.06 * SR), 0.0005, 0.012)
    add(out, crack / (np.max(np.abs(crack)) + 1e-9), 0.0)
    add(out, knock(rng, rng.uniform(90, 120), 0.025, 1200, 0.7), 0.004)

    for _ in range(int(rng.integers(4, 8))):
        add(out, ping(rng.uniform(900, 2400), 0.01, 0.05) * rng.uniform(0.1, 0.3), rng.uniform(0.04, 0.4))

    return finish(out)


def tool_repair(rng):
    out = np.zeros(int(2.2 * SR))

    for at in (0.0, 0.5):
        add(out, rustle(rng, int(0.35 * SR), 1300, 0.9) * env(int(0.35 * SR), 0.08, 0.12) * 0.5, at)

    for at in (1.0, 1.2, 1.4):
        add(out, knock(rng, rng.uniform(150, 220), 0.015, 1800, 0.55), at)

    add(out, rustle(rng, int(0.5 * SR), 2600, 0.8) * env(int(0.5 * SR), 0.1, 0.18) * 0.4, 1.6)
    return finish(out)


def tool_warn(rng):
    """A worn tool complaining: a small dry crack and a short creak, much gentler than the break."""
    out = np.zeros(int(0.4 * SR))
    crack = noise(rng, int(0.03 * SR), lambda f: highpass(f, 900) * lowpass(f, 5000)) * env(int(0.03 * SR), 0.0004, 0.008)
    add(out, crack / (np.max(np.abs(crack)) + 1e-9) * 0.7, 0.0)
    add(out, knock(rng, rng.uniform(110, 150), 0.02, 1100, 0.45), 0.003)
    m = int(0.18 * SR)
    t = np.arange(m) / SR
    f = rng.uniform(420, 560) * (1.0 + 0.2 * t / t[-1])
    creak = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1]) ** 2 * 0.25
    add(out, creak, 0.08)
    return finish(out, 0.6)


def place_timber(rng):
    # A wall, floor or roof piece set in place: a stand-down thud, two or three hammer blows on a peg, a short wood creak as it settles.
    out = np.zeros(int(1.0 * SR))
    add(out, knock(rng, rng.uniform(75, 100), 0.04, 900, 1.0), 0.0)

    for at in (0.22, 0.4, 0.55)[:rng.integers(2, 4)]:
        add(out, knock(rng, rng.uniform(150, 210), 0.02, 2600, 0.8), at)
        add(out, ping(rng.uniform(1500, 2100), 0.04, 0.2) * 0.25, at)

    creak = rustle(rng, int(0.35 * SR), 700, 0.7) * env(int(0.35 * SR), 0.2, 0.3)
    add(out, creak * 0.3, 0.62)
    return finish(out)


def place_foundation(rng):
    # A stone and earth slab laid down: a deep thud, a grinding scrape of stone on stone, gravel settling.
    out = np.zeros(int(1.2 * SR))
    add(out, knock(rng, rng.uniform(45, 60), 0.07, 700, 1.3), 0.0)
    add(out, knock(rng, rng.uniform(90, 120), 0.04, 1200, 0.6), 0.09)
    scrape = rustle(rng, int(0.5 * SR), 900, 1.0) * env(int(0.5 * SR), 0.15, 0.4)
    add(out, scrape * 0.4, 0.15)
    gravel = rustle(rng, int(0.4 * SR), 2600, 1.5) * env(int(0.4 * SR), 0.05, 0.6)
    add(out, gravel * 0.25, 0.5)
    return finish(out)


ONE_SHOTS = {"place_leanto": place_leanto, "place_chest": place_chest, "place_thump": place_thump, "pickup_placed": pickup_placed,
             "container_put": container_put, "container_take": container_take, "tool_break": tool_break, "tool_repair": tool_repair, "tool_warn": tool_warn, "place_timber": place_timber, "place_foundation": place_foundation}


def main():
    rng = np.random.default_rng(20261027)

    for name, make in ONE_SHOTS.items():
        for v in range(VARIANTS):
            write_ogg("%s_%d" % (name, v), make(rng))

    print("Wrote %d placed-thing sounds to %s" % (len(ONE_SHOTS) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
