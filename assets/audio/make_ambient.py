"""Makes placeholder nature sounds for the ambient layer (src/client/ambient_life.gd).

Run: python3 assets/audio/make_ambient.py   (needs numpy and ffmpeg)
Writes assets/audio/ambient/<name>_N.ogg. They are tone and noise sketches of
bird calls, crickets and frogs, good enough to test placement and timing.
Real recordings go in assets/audio/recorded/ambient/ under the same names
(assets/audio/README.md lists them); the game prefers those.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, freqs, highpass, lowpass, noise, shape  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ambient")
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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.8):
    x = x - np.mean(x)
    n = len(x)
    fade = min(int(0.02 * SR), n // 4)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def note(f0, f1, dur, vib_hz=0.0, vib_depth=0.0, harmonic=0.2, attack=0.01):
    """A tone gliding from f0 to f1 with smooth edges."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 + (f1 - f0) * (t / dur) ** 1.2
    if vib_hz:
        f = f * (1.0 + vib_depth * np.sin(2 * np.pi * vib_hz * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + harmonic * np.sin(2 * phase)
    shape_env = np.minimum(t / attack, 1.0) * np.sin(np.pi * np.minimum(t / dur, 1.0)) ** 0.6
    return x * shape_env


def bird_whistle(rng):
    base = rng.uniform(2200, 3400)
    out = np.zeros(int(1.4 * SR))
    at = 0.02
    for _ in range(rng.integers(2, 5)):
        dur = rng.uniform(0.12, 0.28)
        f0 = base * rng.uniform(0.85, 1.25)
        add(out, note(f0, f0 * rng.uniform(0.82, 1.2), dur, vib_hz=rng.uniform(0, 30), vib_depth=0.01), at)
        at += dur + rng.uniform(0.05, 0.12)
    return finish(out[:int((at + 0.1) * SR)])


def bird_feebee(rng):
    f = rng.uniform(3500, 4100)
    out = np.zeros(int(1.0 * SR))
    add(out, note(f * 1.02, f * 0.97, 0.28, harmonic=0.1), 0.02)
    add(out, note(f * 0.83, f * 0.8, 0.4, harmonic=0.1), 0.38)
    return finish(out[:int(0.9 * SR)])


def bird_trill(rng):
    dur = rng.uniform(0.7, 1.1)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = rng.uniform(2900, 3500) * (1.0 + 0.2 * t / dur)
    am = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(13, 19) * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.3 + 0.7 * am) * np.sin(np.pi * t / dur) ** 0.7
    return finish(x)


def bird_chirp(rng):
    out = np.zeros(int(0.8 * SR))
    at = 0.02
    for _ in range(rng.integers(2, 4)):
        f = rng.uniform(3300, 4200)
        add(out, note(f, f * 1.35, 0.07, harmonic=0.15, attack=0.004), at)
        at += rng.uniform(0.1, 0.16)
    return finish(out[:int((at + 0.1) * SR)])


def crow_caw(rng):
    out = np.zeros(int(2.0 * SR))
    at = 0.03
    for _ in range(rng.integers(2, 4)):
        dur = rng.uniform(0.28, 0.4)
        n = int(dur * SR)
        t = np.arange(n) / SR
        f0 = rng.uniform(320, 420) * (1.0 - 0.2 * t / dur)
        phase = 2 * np.pi * np.cumsum(f0) / SR
        x = sum(np.sin(k * phase) / k ** 0.8 for k in range(1, 14))
        x = shape(x, band(freqs(n), 1100, 0.9) + 0.3 * band(freqs(n), 2200, 0.8))
        x += 0.15 * noise(rng, n, lambda f: band(f, 1500, 1.0)) * 5
        x *= np.minimum(t / 0.02, 1.0) * np.exp(-t / (dur * 0.7))
        add(out, x / (np.max(np.abs(x)) + 1e-9), at)
        at += dur + rng.uniform(0.12, 0.25)
    return finish(out[:int((at + 0.1) * SR)])


def woodpecker(rng):
    knocks = rng.integers(10, 17)
    out = np.zeros(int(1.3 * SR))
    at = 0.02
    gap = rng.uniform(0.05, 0.065)
    for k in range(knocks):
        m = int(0.02 * SR)
        hit = noise(rng, m, lambda f: band(f, 1900, 1.0)) * env(m, 0.0005, 0.006)
        hit /= np.max(np.abs(hit)) + 1e-9
        tt = np.arange(m) / SR
        hit += 0.6 * np.sin(2 * np.pi * 850 * tt) * np.exp(-tt / 0.004)
        add(out, hit * (1.0 - 0.3 * k / knocks), at)
        at += gap * (1.0 + 0.012 * k)
    return finish(out[:int((at + 0.1) * SR)])


def owl_hoot(rng):
    out = np.zeros(int(3.0 * SR))
    f = rng.uniform(340, 420)
    for at, dur in ((0.05, 0.4), (0.8, 0.28), (1.2, 0.28), (1.7, 0.75)):
        add(out, note(f * 1.04, f * 0.95, dur, harmonic=0.12, attack=0.06), at)
    return finish(out[:int(2.6 * SR)])


def hawk_screech(rng):
    dur = rng.uniform(0.8, 1.1)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = rng.uniform(3300, 3800) * (1.0 - 0.45 * (t / dur) ** 0.8)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + 0.4 * np.sin(2 * phase)
    x += 0.5 * noise(rng, n, lambda fr: band(fr, 3000, 0.8)) * 6
    x *= np.minimum(t / 0.05, 1.0) * np.exp(-((t - 0.15) / (dur * 0.6)) ** 2 * 0.5 * (t > 0.15))
    return finish(x)


def cricket(rng):
    fc = rng.uniform(4300, 5000)
    out = np.zeros(int(2.2 * SR))
    at = 0.03
    for _ in range(rng.integers(4, 7)):
        for p in range(3):
            m = int(0.026 * SR)
            tt = np.arange(m) / SR
            pulse = np.sin(2 * np.pi * fc * tt) * np.sin(np.pi * tt / tt[-1]) ** 1.5
            add(out, pulse, at + p * 0.04)
        at += 0.3
    return finish(out[:int((at + 0.1) * SR)], 0.6)


def frog_croak(rng):
    """A low, rough "gunk" or bullfrog-like croak: a buzzy pulse train under a nasal formant."""
    out = np.zeros(int(2.4 * SR))
    at = 0.03
    for _ in range(rng.integers(1, 3)):
        dur = rng.uniform(0.35, 0.7)
        n = int(dur * SR)
        t = np.arange(n) / SR
        f0 = rng.uniform(95, 140) * (1.0 - 0.08 * t / dur)
        phase = np.cumsum(f0) / SR
        buzz = (phase % 1.0 < 0.18).astype(float)                 # narrow glottal-like pulses
        buzz *= 1.0 + 0.35 * rng.standard_normal(n)              # roughness
        f = freqs(n)
        x = shape(buzz, band(f, rng.uniform(380, 520), 0.7) + 0.6 * band(f, rng.uniform(900, 1200), 0.6) + 0.3 * lowpass(f, 250, 2))
        x *= np.minimum(t / 0.03, 1.0) * np.minimum((dur - t) / 0.08, 1.0)
        add(out, x / (np.max(np.abs(x)) + 1e-9), at)
        at += dur + rng.uniform(0.2, 0.45)
    return finish(out[:int((at + 0.1) * SR)], 0.7)


def tree_frog_peep(rng):
    out = np.zeros(int(1.0 * SR))
    at = 0.02
    f = rng.uniform(2200, 2700)
    for _ in range(rng.integers(3, 6)):
        add(out, note(f, f * 1.2, 0.07, harmonic=0.1, attack=0.004), at)
        at += rng.uniform(0.12, 0.2)
    return finish(out[:int((at + 0.1) * SR)])


def fish_plop(rng):
    """A small splash at the surface: a soft wet burst, a short rising bubble, then a few drips."""
    n = int(0.7 * SR)
    out = np.zeros(n)
    m = int(0.12 * SR)
    burst = noise(rng, m, lambda f: lowpass(f, 2500, 2) * highpass(f, 200, 2)) * env(m, 0.002, 0.03)
    add(out, burst / (np.max(np.abs(burst)) + 1e-9) * 0.8, 0.0)
    m = int(0.08 * SR)
    t = np.arange(m) / SR
    f0 = rng.uniform(450, 700)
    bubble = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.8 * t / 0.08)) / SR) * np.exp(-t / 0.02)
    add(out, bubble * 0.6, 0.01)
    at = 0.12
    for _ in range(rng.integers(2, 5)):
        m = int(0.03 * SR)
        t = np.arange(m) / SR
        f1 = rng.uniform(900, 1600)
        drip = np.sin(2 * np.pi * np.cumsum(f1 * (1.0 + 0.5 * t / 0.03)) / SR) * np.exp(-t / 0.008)
        add(out, drip * rng.uniform(0.1, 0.25), at)
        at += rng.uniform(0.06, 0.15)
    return finish(shape(out, lowpass(freqs(n), 4000, 2)), 0.6)


SOUNDS = {
    "bird_whistle": bird_whistle,
    "bird_feebee": bird_feebee,
    "bird_trill": bird_trill,
    "bird_chirp": bird_chirp,
    "crow_caw": crow_caw,
    "woodpecker": woodpecker,
    "owl_hoot": owl_hoot,
    "hawk_screech": hawk_screech,
    "cricket_chirp": cricket,
    "frog_croak": frog_croak,
    "tree_frog_peep": tree_frog_peep,
    "fish_splash": fish_plop,
}


def main():
    rng = np.random.default_rng(20261020)
    made = 0
    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            write_ogg("%s_%d" % (name, v), make(rng))
            made += 1
    print("Wrote %d sounds to %s" % (made, OUT))


if __name__ == "__main__":
    main()
