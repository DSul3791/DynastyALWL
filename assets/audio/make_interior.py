"""Makes placeholder interior sounds for src/client/interior_sounds.gd.

Run: python3 assets/audio/make_interior.py   (needs numpy and ffmpeg)
Writes assets/audio/interior/: seamless loops interior_room (a quiet room tone) and
interior_rain_roof (rain on a roof from inside), and one-shots with 2 variants each:
interior_creak, door_open, door_close, door_knock, chest_open, chest_close, furniture_drag.
Recordings go in assets/audio/recorded/interior/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import soft_limit, SR, add, band, env, highpass, lowpass, noise  # noqa: E402
from make_water import normalize, shaped_noise, slow_swell  # noqa: E402
from make_weather import drops  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "interior")
VARIANTS = 2


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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.7):
    x = x - np.mean(x)
    fade = min(int(0.03 * SR), len(x) // 4)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def room(rng, n):
    low = shaped_noise(rng, n, lambda f: lowpass(f, 220, 2) * highpass(f, 35, 2))
    low /= np.std(low)
    air = shaped_noise(rng, n, lambda f: band(f, 900, 1.2) * lowpass(f, 2000, 2))
    air /= np.std(air)
    return normalize((low + 0.15 * air) * slow_swell(rng, n, 0.15, (2, 3, 5)))


def rain_roof(rng, n):
    fine = drops(rng, n, 500, 1500, 1.0, 0.005)
    fine /= np.std(fine) + 1e-9
    big = drops(rng, n, 90, 800, 0.8, 0.012)
    big /= np.std(big) + 1e-9
    return normalize((0.8 * fine + 0.7 * big) * slow_swell(rng, n, 0.12, (3, 5, 8)))


def creak_tone(rng, dur, f0, f1, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 + (f1 - f0) * t / dur
    f = f * (1.0 + 0.04 * np.sin(2 * np.pi * rng.uniform(18, 30) * t))
    ph = np.cumsum(f) / SR
    x = np.sign(np.sin(2 * np.pi * ph)) * 0.3 + np.sin(2 * np.pi * ph)
    return x * amp * np.sin(np.pi * t / dur) ** 1.2


def thunk(rng, f0=110.0, dur=0.18, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.6 * np.exp(-t / 0.02))) / SR) * np.exp(-t / 0.05)
    x += 0.5 * noise(rng, n, lambda f: lowpass(f, 500, 2) * highpass(f, 60)) * env(n, 0.001, 0.03) * 3
    return amp * x / (np.max(np.abs(x)) + 1e-9)


def creak(rng):
    return finish(creak_tone(rng, rng.uniform(0.5, 0.9), rng.uniform(150, 230), rng.uniform(110, 180)) * 0.5, 0.45)


def door_open(rng):
    out = np.zeros(int(1.0 * SR))
    add(out, thunk(rng, 220, 0.04, 0.5), 0.0)
    add(out, creak_tone(rng, rng.uniform(0.6, 0.8), rng.uniform(180, 260), rng.uniform(300, 420)) * 0.5, 0.05)
    return finish(out, 0.65)


def door_close(rng):
    out = np.zeros(int(0.8 * SR))
    add(out, creak_tone(rng, 0.35, 300, 200) * 0.3, 0.0)
    add(out, thunk(rng, 90, 0.25, 1.0), 0.32)
    add(out, thunk(rng, 260, 0.04, 0.4), 0.36)
    return finish(out, 0.75)


def door_knock(rng):
    out = np.zeros(int(0.9 * SR))

    for k in range(3):
        add(out, thunk(rng, rng.uniform(140, 180), 0.1, 1.0 - 0.1 * k), 0.05 + 0.25 * k + rng.uniform(0, 0.03))

    return finish(out, 0.7)


def chest_open(rng):
    out = np.zeros(int(0.9 * SR))
    add(out, thunk(rng, 300, 0.03, 0.5), 0.0)
    add(out, creak_tone(rng, 0.5, rng.uniform(250, 330), rng.uniform(380, 480)) * 0.4, 0.06)
    add(out, thunk(rng, 140, 0.15, 0.6), 0.6)
    return finish(out, 0.65)


def chest_close(rng):
    out = np.zeros(int(0.6 * SR))
    add(out, thunk(rng, 120, 0.22, 1.0), 0.0)
    add(out, thunk(rng, 350, 0.03, 0.5), 0.03)
    return finish(out, 0.75)


def furniture_drag(rng):
    n = int(rng.uniform(0.9, 1.3) * SR)
    t = np.arange(n) / SR
    x = noise(rng, n, lambda f: band(f, rng.uniform(250, 450), 1.2) * highpass(f, 80)) * (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(6, 11) * t)) ** 1.5
    x *= np.minimum(t / 0.05, 1.0) * np.minimum((t[-1] - t) / 0.1, 1.0)
    return finish(x, 0.6)


def click(rng, hz=2600.0, dur=0.05, amp=1.0):
    n = int(dur * SR)
    x = noise(rng, n, lambda f: band(f, hz * rng.uniform(0.9, 1.1), 0.6) * highpass(f, 900)) * env(n, 0.0005, dur / 4)
    return amp * x / (np.max(np.abs(x)) + 1e-9)


def gate_open(rng):
    out = np.zeros(int(1.3 * SR))
    add(out, click(rng, 2200, 0.05, 0.6), 0.0)
    add(out, creak_tone(rng, rng.uniform(0.8, 1.0), rng.uniform(110, 150), rng.uniform(190, 240)) * 0.55, 0.08)
    add(out, thunk(rng, 80, 0.2, 0.6), 1.0)
    return finish(out, 0.65)


def gate_close(rng):
    out = np.zeros(int(1.0 * SR))
    add(out, creak_tone(rng, 0.5, 230, 140) * 0.35, 0.0)
    add(out, thunk(rng, 70, 0.3, 1.0), 0.45)
    add(out, click(rng, 2400, 0.05, 0.7), 0.52)
    return finish(out, 0.75)


def hatch_open(rng):
    out = np.zeros(int(0.9 * SR))
    add(out, creak_tone(rng, rng.uniform(0.3, 0.45), rng.uniform(200, 280), rng.uniform(330, 420)) * 0.4, 0.0)
    add(out, thunk(rng, 130, 0.2, 0.7), 0.42)
    return finish(out, 0.65)


def hatch_close(rng):
    out = np.zeros(int(0.7 * SR))
    add(out, thunk(rng, 100, 0.25, 1.0), 0.0)
    add(out, noise(rng, int(0.2 * SR), lambda f: band(f, 1800, 1.0) * highpass(f, 600)) * env(int(0.2 * SR), 0.01, 0.06) * 0.15, 0.04)
    return finish(out, 0.75)


def latch_click(rng):
    out = np.zeros(int(0.25 * SR))
    add(out, click(rng, 2800, 0.04, 0.8), 0.0)
    add(out, click(rng, 2000, 0.05, 0.5), 0.09)
    return finish(out, 0.55)


ONE_SHOTS = {"interior_creak": creak, "door_open": door_open, "door_close": door_close, "door_knock": door_knock,
             "chest_open": chest_open, "chest_close": chest_close, "furniture_drag": furniture_drag,
             "gate_open": gate_open, "gate_close": gate_close, "hatch_open": hatch_open, "hatch_close": hatch_close, "latch_click": latch_click}


def main():
    rng = np.random.default_rng(20261026)
    write_ogg("interior_room", room(rng, 14 * SR))
    write_ogg("interior_rain_roof", rain_roof(rng, 14 * SR))

    for name, make in ONE_SHOTS.items():
        for v in range(VARIANTS):
            write_ogg("%s_%d" % (name, v), make(rng))

    print("Wrote %d interior sounds to %s" % (2 + len(ONE_SHOTS) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
