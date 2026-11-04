"""Makes placeholder bow sounds for the bow in src/client/held_item.gd (slots bow_draw and bow_loose, batch3_slots.json).

Run: python3 assets/audio/make_bow.py   (needs numpy and ffmpeg)
Writes assets/audio/bow/ (3 variants each): bow_draw (the wooden limbs flexing and the string
stretching as it is pulled back, 0.9 s) and bow_loose (the string's low twang, the limbs' knock and the
arrow's short swish leaving, 0.6 s). Recordings dropped in their place win (swap_recording.py).
Seeded, so a rerun writes the same samples.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, band, highpass, lowpass, noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bow")
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


def finish(x, peak):
    x = x - np.mean(x)
    fade = min(int(0.04 * SR), len(x) // 4)
    x[:int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def draw(rng):
    # Wood under load: a run of small creak grains that come closer together and rise in pitch as the pull
    # goes on, over a faint string rasp. No tone held, so it never hums.
    dur = rng.uniform(0.8, 1.0)
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    at = 0.03
    while at < dur - 0.08:
        share = at / dur
        f = rng.uniform(260, 340) * (1.0 + 0.5 * share)
        m = int(rng.uniform(0.012, 0.025) * SR)
        tt = np.arange(m) / SR
        grain = np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.28)) * np.exp(-tt / 0.006)
        grain += 0.4 * np.sin(2 * np.pi * f * 2.7 * tt) * np.exp(-tt / 0.003)
        i = int(at * SR)
        out[i:i + m] += grain[:n - i] * rng.uniform(0.5, 1.0) * (0.5 + 0.5 * share)
        at += rng.uniform(0.018, 0.045) * (1.1 - 0.6 * share)
    rasp = noise(rng, n, lambda f: band(f, 2200, 1.2) * highpass(f, 900)) * 0.18
    rasp *= np.clip(t / 0.15, 0, 1) * (0.6 + 0.4 * t / dur)
    out = lowpass_np(out, 3000) + rasp
    return finish(out, 0.55)


def lowpass_np(x, cut):
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) * lowpass(f, cut), len(x))


def loose(rng):
    # The string's twang (a low fundamental that bends down a little and dies fast), the limbs' wooden
    # knock at the start, and the arrow's swish, high and short, fading as it leaves.
    dur = 0.6
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(95, 125)
    bend = f0 * (1.0 + 0.15 * np.exp(-t / 0.02))
    phase = 2 * np.pi * np.cumsum(bend) / SR
    twang = (np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.25 * np.sin(3 * phase + 0.7)) * np.exp(-t / rng.uniform(0.07, 0.1))
    knock = np.sin(2 * np.pi * rng.uniform(380, 480) * t) * np.exp(-t / 0.012)
    knock += noise(rng, n, lambda f: band(f, 1500, 1.0)) * np.exp(-t / 0.006) * 0.6
    swish = noise(rng, n, lambda f: band(f, rng.uniform(3000, 4200), 1.3) * highpass(f, 1200))
    swish /= np.max(np.abs(swish)) + 1e-9
    swish *= np.exp(-((t - 0.06) / 0.05) ** 2) * 0.35
    return finish(twang + 0.7 * knock + swish, 0.7)


def main():
    rng = np.random.default_rng(6201)
    for i in range(VARIANTS):
        write_ogg("bow_draw_%d" % i, draw(rng))
        write_ogg("bow_loose_%d" % i, loose(rng))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
