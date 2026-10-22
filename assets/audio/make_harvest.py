"""Makes placeholder plant-picking sounds for src/client/harvest_sounds.gd.

Run: python3 assets/audio/make_harvest.py   (needs numpy and ffmpeg)
Writes assets/audio/harvest/ (3 variants each):
  pick_pluck   a berry or nut pulled off its stalk: a tiny snap and a soft leaf flick, 0.3 s
  pick_snip    a herb or leaf nipped off: a crisp little snip, 0.25 s
  pick_pull    a root or bulb drawn out of the soil: a tearing earth drag and a soft pop, 0.6 s
  pick_twist   a mushroom twisted off: a short squeak and a soft break, 0.35 s
  pick_snap    a stalk, reed or twig snapped: a dry crack, 0.3 s
and 2 variants of the plant moving when it is picked:
  plant_rustle_leaves  leaves and twigs shaking, 0.9 s          plant_rustle_reeds  reeds and grass swishing, 0.9 s
Recordings go in assets/audio/recorded/harvest/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise, ping, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "harvest")


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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.7):
    x = x - np.mean(x)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    fade = min(int(0.04 * SR), len(x) // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def grain(rng, length, center, octaves, attack, decay):
    n = int(length * SR)
    g = noise(rng, n, lambda f: band(f, center, octaves) * highpass(f, 300)) * env(n, attack, decay)
    return g / (np.max(np.abs(g)) + 1e-9)


def pick_pluck(rng):
    out = np.zeros(int(0.3 * SR))
    add(out, grain(rng, 0.02, rng.uniform(3000, 4500), 1.0, 0.0004, 0.004), 0.0)
    add(out, grain(rng, 0.15, rng.uniform(1800, 2800), 1.2, 0.02, 0.05) * 0.35, 0.02)
    add(out, ping(rng.uniform(900, 1400), 0.012, 0.06) * 0.15, 0.003)
    return finish(out)


def pick_snip(rng):
    out = np.zeros(int(0.25 * SR))
    add(out, grain(rng, 0.012, rng.uniform(4500, 6500), 0.8, 0.0003, 0.003), 0.0)
    add(out, grain(rng, 0.012, rng.uniform(3500, 5000), 0.8, 0.0003, 0.003) * 0.6, 0.03)
    add(out, grain(rng, 0.1, 2400, 1.2, 0.015, 0.03) * 0.25, 0.04)
    return finish(out, 0.6)


def pick_pull(rng):
    out = np.zeros(int(0.6 * SR))
    add(out, grain(rng, 0.45, rng.uniform(500, 900), 1.2, 0.18, 0.12) * 0.55, 0.0)
    add(out, grain(rng, 0.2, 1800, 1.0, 0.05, 0.05) * 0.2, 0.12)
    add(out, thump(rng, 0.1, rng.uniform(90, 130), 0.025, 600) * 0.7, 0.4)
    return finish(out)


def pick_twist(rng):
    out = np.zeros(int(0.35 * SR))
    d = int(0.15 * SR)
    t = np.arange(d) / SR
    f0 = rng.uniform(900, 1500)
    squeak = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.4 * t / 0.15)) / SR) * np.sin(np.pi * t / 0.15)
    add(out, squeak * 0.12 * rng.uniform(0.7, 1.0), 0.0)
    add(out, grain(rng, 0.15, 1200, 1.0, 0.005, 0.02), 0.16)
    add(out, thump(rng, 0.08, 150, 0.015, 800) * 0.4, 0.17)
    return finish(out)


def pick_snap(rng):
    out = np.zeros(int(0.3 * SR))
    add(out, grain(rng, 0.02, rng.uniform(2500, 3800), 1.2, 0.0003, 0.006), 0.0)
    add(out, thump(rng, 0.06, rng.uniform(250, 380), 0.01, 2500) * 0.5, 0.0)
    add(out, grain(rng, 0.12, 2000, 1.0, 0.01, 0.03) * 0.2, 0.02)
    return finish(out)


def rustle(rng, center, octaves, length, bursts):
    n = int(length * SR)
    out = np.zeros(n)

    for k in range(bursts):
        at = rng.uniform(0.0, length * 0.55)
        add(out, grain(rng, rng.uniform(0.08, 0.2), center * rng.uniform(0.8, 1.3), octaves, 0.02, 0.05) * rng.uniform(0.3, 1.0), at)

    return finish(out * env(n, 0.03, length * 0.4), 0.55)


def plant_rustle_leaves(rng):
    return rustle(rng, 2600, 1.4, 0.9, 9)


def plant_rustle_reeds(rng):
    return rustle(rng, 1500, 1.0, 0.9, 6)


SOUNDS = {"pick_pluck": pick_pluck, "pick_snip": pick_snip, "pick_pull": pick_pull, "pick_twist": pick_twist, "pick_snap": pick_snap,
          "plant_rustle_leaves": plant_rustle_leaves, "plant_rustle_reeds": plant_rustle_reeds}


def main():
    rng = np.random.default_rng(20261030)
    count = 0

    for name, make in SOUNDS.items():
        for v in range(2 if name.startswith("plant_rustle") else 3):
            write_ogg("%s_%d" % (name, v), make(rng))
            count += 1

    print("Wrote %d harvest sounds to %s" % (count, OUT))


if __name__ == "__main__":
    main()
