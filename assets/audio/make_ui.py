"""Makes placeholder interface sounds for src/client/ui_sounds.gd.

Run: python3 assets/audio/make_ui.py   (needs numpy and ffmpeg)
Writes assets/audio/ui/: ui_click_N (a soft menu tick), ui_on_N and ui_off_N (inspection mode and
other toggles: a short rising or falling two-note), ui_quality_N (a settled soft chime when the
quality tier changes). All quiet and short. Recordings go in assets/audio/recorded/ui/ under the
same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui")
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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def tone(f, dur, decay, harmonic=0.15):
    t = np.arange(int(dur * SR)) / SR
    x = np.sin(2 * np.pi * f * t) + harmonic * np.sin(4 * np.pi * f * t)
    return x * np.minimum(t / 0.004, 1.0) * np.exp(-t / decay)


def finish(x, peak=0.6):
    fade = min(int(0.02 * SR), len(x) // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def click(rng):
    out = np.zeros(int(0.07 * SR))
    m = int(0.012 * SR)
    tick = noise(rng, m, lambda f: band(f, 2600, 1.0) * highpass(f, 900)) * env(m, 0.0004, 0.003)
    add(out, tick / (np.max(np.abs(tick)) + 1e-9) * 0.7, 0.0)
    add(out, tone(rng.uniform(1100, 1300), 0.05, 0.012, 0.0) * 0.5, 0.0)
    return finish(out, 0.5)


def toggle(rng, rising):
    f = rng.uniform(780, 860)
    a, b = (f, f * 1.5) if rising else (f * 1.5, f)
    out = np.zeros(int(0.22 * SR))
    add(out, tone(a, 0.1, 0.03), 0.0)
    add(out, tone(b, 0.14, 0.05), 0.07)
    return finish(out)


def quality(rng):
    f = rng.uniform(520, 580)
    out = np.zeros(int(0.5 * SR))
    for k, ratio in enumerate((1.0, 1.5, 2.0)):
        add(out, tone(f * ratio, 0.4, 0.12), 0.06 * k)
    return finish(out, 0.55)


def main():
    rng = np.random.default_rng(20261023)

    for v in range(VARIANTS):
        write_ogg("ui_click_%d" % v, click(rng))
        write_ogg("ui_on_%d" % v, toggle(rng, True))
        write_ogg("ui_off_%d" % v, toggle(rng, False))
        write_ogg("ui_quality_%d" % v, quality(rng))

    print("Wrote %d interface sounds to %s" % (VARIANTS * 4, OUT))


if __name__ == "__main__":
    main()
