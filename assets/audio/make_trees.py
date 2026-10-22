"""Makes placeholder tree felling sounds for src/client/tree_sounds.gd.

Run: python3 assets/audio/make_trees.py   (needs numpy and ffmpeg)
Writes assets/audio/trees/ (3 variants each): tree_creak_N (the trunk groaning as it starts to go,
1.4 s), tree_leaves_N (branches and foliage rushing through the air, 1.2 s), tree_crash_N (the
crown hitting the ground: snapping branches, a heavy low thud, leaves settling, 2.2 s),
stump_chips_N (wood chips and a last crack as the stump is left, 0.5 s). Recordings go in
assets/audio/recorded/trees/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, highpass, lowpass, noise, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "trees")
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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.7, fade=0.05):
    n = int(fade * SR)
    x[-n:] *= np.linspace(1, 0, n)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def snap(rng, length=0.02, center=2500):
    m = int(length * SR)
    return burst(rng, length, center, 1.2) * np.exp(-np.arange(m) / SR / (length * 0.4))


def creak(rng):
    """A groaning trunk: a slowly falling, wobbling low tone with rough harmonics, plus fibres snapping."""
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(130, 190) * (1.0 - 0.28 * t / 1.4) * (1.0 + 0.05 * np.sin(2 * np.pi * rng.uniform(5, 9) * t))
    phase = np.cumsum(f0) * 2 * np.pi / SR
    tone = sum(np.sin(k * phase) / k ** 0.7 for k in range(1, 7))
    tone *= np.minimum(t / 0.25, 1.0) * np.exp(-np.maximum(t - 0.5, 0) / 0.5)
    grit = noise(rng, n, lambda f: band(f, 600, 1.2) * highpass(f, 200)) * (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(14, 24) * t)) ** 2
    grit /= np.max(np.abs(grit)) + 1e-9
    out = tone / (np.max(np.abs(tone)) + 1e-9) * 0.7 + grit * 0.4 * np.minimum(t / 0.3, 1.0) * np.exp(-np.maximum(t - 0.6, 0) / 0.4)

    for _ in range(rng.integers(3, 6)):
        add(out, snap(rng, rng.uniform(0.01, 0.03), rng.uniform(1500, 3500)) * rng.uniform(0.3, 0.8), rng.uniform(0.2, 1.2))

    return finish(out, 0.6, 0.15)


def leaves(rng):
    """A crown rushing down: soft rustling air that swells and passes."""
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    x = noise(rng, n, lambda f: band(f, 2600, 1.4) * highpass(f, 900)) * np.sin(np.pi * t / 1.2) ** 1.5
    x += noise(rng, n, lambda f: band(f, 600, 1.0) * lowpass(f, 1500)) * np.sin(np.pi * t / 1.2) * 0.5

    for _ in range(14):
        add(x, snap(rng, rng.uniform(0.005, 0.015), rng.uniform(2000, 5000)) * rng.uniform(0.1, 0.4), rng.uniform(0.1, 1.0))

    return finish(x, 0.5, 0.2)


def crash(rng):
    """The crown hits the ground: a burst of snapping branches, a deep thud and leaves settling."""
    n = int(2.2 * SR)
    out = np.zeros(n)
    t = np.arange(n) / SR

    for _ in range(rng.integers(14, 24)):
        add(out, snap(rng, rng.uniform(0.01, 0.04), rng.uniform(900, 3500)) * rng.uniform(0.2, 0.9), rng.uniform(0.0, 0.5))

    add(out, thump(rng, 0.9, rng.uniform(42, 55), 0.28) * 1.6, 0.0)
    add(out, thump(rng, 0.5, rng.uniform(85, 110), 0.12, 900.0) * 0.8, 0.02)
    settle = noise(rng, n, lambda f: band(f, 2200, 1.5) * highpass(f, 700)) * np.exp(-t / 0.7) * np.minimum(t / 0.15, 1.0)
    out += settle / (np.max(np.abs(settle)) + 1e-9) * 0.35

    for _ in range(10):
        add(out, snap(rng, rng.uniform(0.006, 0.02), rng.uniform(1500, 4000)) * rng.uniform(0.1, 0.35), rng.uniform(0.3, 1.8))

    return finish(np.tanh(out * 1.4), 0.85, 0.3)


def chips(rng):
    """Wood chips: a sharp last crack and a spray of small clicks."""
    n = int(0.5 * SR)
    out = np.zeros(n)
    add(out, snap(rng, 0.03, 1800), 0.0)

    for _ in range(rng.integers(6, 10)):
        add(out, snap(rng, rng.uniform(0.004, 0.012), rng.uniform(2500, 6000)) * rng.uniform(0.15, 0.5), rng.uniform(0.03, 0.4))

    return finish(out, 0.6, 0.08)


def main():
    rng = np.random.default_rng(20261028)

    for v in range(VARIANTS):
        write_ogg("tree_creak_%d" % v, creak(rng))
        write_ogg("tree_leaves_%d" % v, leaves(rng))
        write_ogg("tree_crash_%d" % v, crash(rng))
        write_ogg("stump_chips_%d" % v, chips(rng))

    print("Wrote %d tree sounds to %s" % (VARIANTS * 4, OUT))


if __name__ == "__main__":
    main()
