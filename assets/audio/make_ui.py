"""Makes placeholder interface sounds for src/client/ui_sounds.gd.

Run: python3 assets/audio/make_ui.py   (needs numpy and ffmpeg)
Writes assets/audio/ui/: ui_click_N (a soft menu tick), ui_on_N and ui_off_N (inspection mode and
other toggles: a short rising or falling two-note), ui_quality_N (a settled soft chime when the
quality tier changes), ui_goal_0 (the Goal Achieved placard's short trumpet fanfare, played by
src/client/ui/goals/goal_placard.gd: two synthesized brass voices, three quick notes and a held fourth,
an original figure). All short. Recordings go in assets/audio/recorded/ui/ under the same names; the
game prefers them.
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


def brass(f, dur, accent=1.0):
    """One brass note: harmonics that brighten as the note swells, a small scoop up to pitch, a late gentle vibrato."""
    t = np.arange(int(dur * SR)) / SR
    attack = np.minimum(t / 0.035, 1.0)
    release = np.clip((dur - t) / 0.06, 0.0, 1.0)
    swell = attack * release * (0.85 + 0.15 * np.minimum(t / 0.25, 1.0))
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.25) / 0.2, 0.0, 1.0)
    scoop = 1.0 - 0.025 * np.exp(-t / 0.03)
    phase = 2 * np.pi * f * np.cumsum(vib * scoop) / SR
    x = np.zeros_like(t)
    for k in range(1, 11):
        x += np.sin(k * phase) * (1.0 / k ** 0.9) * swell ** (1.0 + 0.35 * (k - 1))
    return x * swell * accent


def fanfare():
    """The goal fanfare, about 1.5 s: G4 G4 G4 then a held C5 over E4 E4 E4 G4 (C major), with a little room echo."""
    out = np.zeros(int(1.75 * SR))
    lead = [(392.0, 0.0, 0.13), (392.0, 0.15, 0.13), (392.0, 0.30, 0.13), (523.25, 0.45, 0.95)]
    second = [(329.63, 0.0, 0.13), (329.63, 0.15, 0.13), (329.63, 0.30, 0.13), (392.0, 0.45, 0.95)]
    for f, at, dur in lead:
        add(out, brass(f, dur, 1.0), at)
    for f, at, dur in second:
        add(out, brass(f, dur, 0.55), at + 0.008)
    room = out.copy()
    for delay, gain in ((0.043, 0.22), (0.071, 0.16), (0.113, 0.11), (0.167, 0.07)):
        n = int(delay * SR)
        room[n:] += out[:-n] * gain
    return finish(room, 0.7)


def main():
    rng = np.random.default_rng(20261023)

    for v in range(VARIANTS):
        write_ogg("ui_click_%d" % v, click(rng))
        write_ogg("ui_on_%d" % v, toggle(rng, True))
        write_ogg("ui_off_%d" % v, toggle(rng, False))
        write_ogg("ui_quality_%d" % v, quality(rng))

    write_ogg("ui_goal_0", fanfare())
    print("Wrote %d interface sounds to %s" % (VARIANTS * 4 + 1, OUT))


if __name__ == "__main__":
    main()
