"""Makes placeholder body sounds for src/client/breath_sounds.gd.

Run: python3 assets/audio/make_body.py   (needs numpy and ffmpeg)
Writes assets/audio/body/ (3 variants each): breath_in_N (a soft intake of air, 0.8 s),
breath_out_N (a soft release, 0.9 s), breath_gasp_N (a hard, ragged gulp of air for severe
exertion, 0.7 s) and heartbeat_N (a lub-dub, 0.4 s). Recordings go in assets/audio/recorded/body/
under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "body")
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


def finish(x, peak=0.6, fade=0.06):
    n = int(fade * SR)
    x[-n:] *= np.linspace(1, 0, n)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def air(rng, dur, center, octaves, rise, hold):
    """Airy breath noise: band-passed noise with a smooth swell (rise then hold-and-fade)."""
    n = int(dur * SR)
    t = np.arange(n) / dur
    shape = np.minimum(t / rise, 1.0) ** 1.5 * np.exp(-np.maximum(t - hold, 0) / (1.0 - hold) * 3.0)
    x = noise(rng, n, lambda f: band(f, center, octaves) * highpass(f, 250)) * shape
    return x / (np.max(np.abs(x)) + 1e-9)


def breath_in(rng):
    return finish(air(rng, 0.8, rng.uniform(1800, 2400), 1.3, 0.7, 0.8), 0.5)


def breath_out(rng):
    return finish(air(rng, 0.9, rng.uniform(1100, 1600), 1.3, 0.2, 0.3), 0.5)


def gasp(rng):
    n = int(0.7 * SR)
    x = air(rng, 0.7, rng.uniform(1500, 2200), 1.6, 0.35, 0.55)
    t = np.arange(n) / SR
    rough = 0.55 + 0.45 * np.sin(2 * np.pi * rng.uniform(35, 55) * t)
    voice = noise(rng, n, lambda f: band(f, 420, 1.0) * lowpass(f, 900)) * env(n, 0.1, 0.25)
    voice /= np.max(np.abs(voice)) + 1e-9
    return finish(x * rough + 0.25 * voice, 0.75)


def heartbeat(rng):
    out = np.zeros(int(0.45 * SR))

    for at, f0, level in ((0.0, rng.uniform(52, 62), 1.0), (0.17, rng.uniform(44, 52), 0.7)):
        n = int(0.16 * SR)
        t = np.arange(n) / SR
        thump = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 0.5 * np.exp(-t / 0.03))) / SR) * np.exp(-t / 0.05) * np.minimum(t / 0.004, 1.0)
        add(out, thump * level, at)

    return finish(out, 0.8, 0.05)


def main():
    rng = np.random.default_rng(20261029)

    for v in range(VARIANTS):
        write_ogg("breath_in_%d" % v, breath_in(rng))
        write_ogg("breath_out_%d" % v, breath_out(rng))
        write_ogg("breath_gasp_%d" % v, gasp(rng))
        write_ogg("heartbeat_%d" % v, heartbeat(rng))

    print("Wrote %d body sounds to %s" % (VARIANTS * 4, OUT))


if __name__ == "__main__":
    main()
