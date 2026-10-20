"""Makes the lake lapping sounds for src/client/water_sounds.gd (still lake and pond shores).

Run: python3 assets/audio/make_lake.py   (needs numpy and ffmpeg)
Dave, 2026-10-20: a lake should lap softly, like slowed-down fish-jump splashes, not rush like a river. Writes
assets/audio/water/lake_lap_N (3 variants): each is one of Dave's fish splash recordings
(assets/audio/recorded/ambient/fish_splash_N) slowed to 0.62 (pitch drops with it), low-passed at 2.4 kHz, softened
and faded out over 2.4 s. Without those recordings it falls back to synthetic soft laps. Recordings of real
lake lapping go in assets/audio/recorded/water/ as lake_lap_N and win.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, band, lowpass, noise  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "water")
FISH = os.path.join(HERE, "recorded", "ambient")
VARIANTS = 3
SPEED = 0.62
LENGTH = 2.4


def from_fish(src, dst):
    filt = ("asetrate=%d,aresample=%d,lowpass=f=2400,volume=0.55,afade=t=in:d=0.05,"
            "atrim=0:%.2f,afade=t=out:st=%.2f:d=%.2f") % (int(44100 * SPEED), 44100, LENGTH, LENGTH - 0.9, 0.9)
    subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-af", filt,
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)


def synthetic(rng, dst):
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)

    for at in sorted(rng.uniform(0.0, 0.9, 3)):
        m = int(0.7 * SR)
        d = np.arange(m) / SR
        lap = noise(rng, m, lambda f: band(f, rng.uniform(450, 800), 1.0) * lowpass(f, 1600, 2)) * np.sin(np.pi * d / 0.7) ** 3
        lap /= np.max(np.abs(lap)) + 1e-9
        i = int(at * SR)
        x[i:i + m] += lap[:n - i] * rng.uniform(0.3, 0.8)

    x *= 0.4 / (np.max(np.abs(x)) + 1e-9)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(20261123)
    used = 0

    for v in range(VARIANTS):
        dst = os.path.join(OUT, "lake_lap_%d.ogg" % v)
        src = os.path.join(FISH, "fish_splash_%d.ogg" % v)

        if os.path.exists(src):
            from_fish(src, dst)
            used += 1
        else:
            synthetic(rng, dst)

    print("Wrote %d lake lapping sounds to %s (%d from fish splash recordings)" % (VARIANTS, OUT, used))


if __name__ == "__main__":
    main()
