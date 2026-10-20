"""Makes placeholder fire sounds for src/client/fire_sounds.gd.

Run: python3 assets/audio/make_fire.py   (needs numpy and ffmpeg)
Writes assets/audio/fire/: seamless loops fire_small (a few embers: quiet, sparse snaps),
fire_large (a bonfire: low roar, many crackles, pops), fire_rain (rain falling on an open fire:
sparse sharp sizzles, no steady hiss bed), flame_torch (a held torch: soft quick flutter), flame_lantern (a hushed steady burn), and one-shots fire_light_N (a strike and soft whoomph
as it catches) and fire_out_N (a hiss that fades, steam). Recordings go in assets/audio/recorded/fire/
under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import soft_limit, SR, add, band, highpass, lowpass  # noqa: E402
from make_water import flow, normalize, shaped_noise, slow_swell  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fire")


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


def snaps(rng, n, rate, lo, hi, decay, gain):
    """Short crackles at random times (wrapped around the loop end), heavy-tailed in level."""
    out = np.zeros(n)

    for _ in range(int(rate * n / SR)):
        m = int(max(decay * 6, 0.01) * SR)
        t = np.arange(m) / SR
        c = shaped_noise(rng, m, lambda f: band(f, rng.uniform(lo, hi), 0.9)) * np.exp(-t / decay)
        c /= np.max(np.abs(c)) + 1e-9
        idx = (rng.integers(0, n) + np.arange(m)) % n
        out[idx] += c * rng.pareto(3.0) * gain

    return out


def small(rng, n):
    roar = shaped_noise(rng, n, lambda f: band(f, 180, 1.0) * lowpass(f, 600, 2))
    roar /= np.std(roar)
    x = roar * 0.12 * slow_swell(rng, n, 0.3, (3, 5, 9)) + snaps(rng, n, 6, 1500, 4200, 0.004, 0.6)
    return normalize(x, 0.1) * 1.2


def large(rng, n):
    roar = shaped_noise(rng, n, lambda f: band(f, 160, 1.1) * lowpass(f, 800, 2))
    roar /= np.std(roar)
    x = roar * 0.45 * slow_swell(rng, n, 0.25, (2, 4, 7)) + snaps(rng, n, 26, 1200, 4500, 0.006, 0.5)
    x += snaps(rng, n, 1.2, 700, 1100, 0.015, 1.1)
    return normalize(x, 0.13) * 1.3


def rain_on_fire(rng, n):
    # Sparse sharp sizzles and tiny spits; deliberately no steady broadband bed (owner dislikes sheeting).
    x = snaps(rng, n, 70, 3500, 6500, 0.005, 0.8)
    x += snaps(rng, n, 12, 1800, 2800, 0.02, 0.6)
    return normalize(x * slow_swell(rng, n, 0.25, (2, 5, 8)), 0.1)


def torch(rng, n):
    """A held torch: a soft, quick flutter of flame with small snaps (a fast, uneven 'fwup', never regular)."""
    flutter = flow(rng, n, 120, 1800, 0.5)
    mod = np.abs(shaped_noise(rng, n, lambda f: (f < 9.0) * (f > 1.5) * 1.0))
    mod = mod / (np.max(mod) + 1e-9)
    x = flutter * (0.45 + 0.55 * mod) + snaps(rng, n, 7, 1500, 4000, 0.004, 0.35)
    return normalize(x, 0.1) * 1.2


def lantern(rng, n):
    """A lantern flame behind glass: a faint, steady, hushed burn with the odd tiny tick."""
    x = flow(rng, n, 200, 2400, 0.7) + snaps(rng, n, 2, 2000, 4500, 0.003, 0.25)
    return normalize(x, 0.08)


def light(rng):
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    strike = shaped_noise(rng, int(0.06 * SR), lambda f: band(f, 2800, 1.0)) * np.exp(-np.arange(int(0.06 * SR)) / SR / 0.01)
    add(out, strike / (np.max(np.abs(strike)) + 1e-9) * 0.5, 0.0)
    whoomph = shaped_noise(rng, n, lambda f: band(f, 220, 1.0) * lowpass(f, 700, 2))
    whoomph = whoomph / np.std(whoomph) * np.minimum(np.maximum(t - 0.1, 0) / 0.25, 1.0) * np.exp(-np.maximum(t - 0.35, 0) / 0.5)
    out += whoomph * 0.5
    out += snaps(rng, n, 14, 1500, 4000, 0.005, 0.4) * np.minimum(t / 0.4, 1.0)
    out[-int(0.2 * SR):] *= np.linspace(1, 0, int(0.2 * SR))
    return out * (0.65 / (np.max(np.abs(out)) + 1e-9))


def put_out(rng):
    n = int(2.6 * SR)
    t = np.arange(n) / SR
    hiss = shaped_noise(rng, n, lambda f: band(f, 5200, 1.0) * highpass(f, 2500, 2))
    hiss = hiss / np.std(hiss) * np.exp(-t / 0.8) * np.minimum(t / 0.03, 1.0)
    low = shaped_noise(rng, n, lambda f: lowpass(f, 400, 2)) 
    low = low / np.std(low) * np.exp(-t / 0.3) * 0.5
    out = hiss + low + snaps(rng, n, 10, 2000, 5000, 0.004, 0.3) * np.exp(-t / 1.0)
    out[-int(0.3 * SR):] *= np.linspace(1, 0, int(0.3 * SR))
    return out * (0.6 / (np.max(np.abs(out)) + 1e-9))


def main():
    rng = np.random.default_rng(20261027)
    write_ogg("fire_small", small(rng, 12 * SR))
    write_ogg("fire_large", large(rng, 14 * SR))
    write_ogg("fire_rain", rain_on_fire(rng, 12 * SR))
    write_ogg("flame_torch", torch(rng, 10 * SR))
    write_ogg("flame_lantern", lantern(rng, 10 * SR))

    for v in range(3):
        write_ogg("fire_light_%d" % v, light(rng))
        write_ogg("fire_out_%d" % v, put_out(rng))

    print("Wrote 11 fire sounds to %s" % OUT)


if __name__ == "__main__":
    main()
