"""Makes placeholder creature calls for src/client/creature_sounds.gd.

Run: python3 assets/audio/make_creatures.py   (needs numpy and ffmpeg)
Writes assets/audio/creatures/<kind>_<call>_N (2 variants each): deer_grunt, deer_snort,
rabbit_thump, rabbit_squeak, fox_bark, fox_scream, wolf_howl, wolf_growl, bear_growl, bear_roar.
They are tone and noise sketches, good enough to test placement, distance and timing. Recordings
go in assets/audio/recorded/creatures/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, freqs, highpass, lowpass, noise, shape  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "creatures")
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


def finish(x, peak=0.8, fade_s=0.04):
    x = x - np.mean(x)
    fade = min(int(fade_s * SR), len(x) // 4)
    x[:fade // 2] *= np.linspace(0, 1, fade // 2)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def voiced(rng, dur, f0, f1, formants, rough=0.0, breath=0.0, vib_hz=0.0, vib_depth=0.0, bend=1.0):
    """A voice: a glottal pulse train gliding f0 to f1, shaped by formant bands, optional rasp and breath."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = (f0 + (f1 - f0) * (t / dur) ** bend)

    if vib_hz:
        f = f * (1.0 + vib_depth * np.sin(2 * np.pi * vib_hz * t))

    phase = np.cumsum(f) / SR
    saw = 2.0 * (phase % 1.0) - 1.0
    saw *= 1.0 + rough * rng.standard_normal(n)
    spec = freqs(n)
    gain = sum(a * band(spec, fc, 0.5) for fc, a in formants)
    x = shape(saw, gain)

    if breath:
        x += breath * noise(rng, n, lambda fr: band(fr, formants[0][0] * 2, 1.2)) * 4

    return x


def deer_grunt(rng):
    out = np.zeros(int(0.9 * SR))

    for k in range(rng.integers(1, 3)):
        d = rng.uniform(0.18, 0.3)
        g = voiced(rng, d, rng.uniform(95, 125), rng.uniform(75, 95), [(300, 1.0), (900, 0.5)], rough=0.25)
        g *= np.sin(np.pi * np.arange(len(g)) / len(g)) ** 0.6
        add(out, g / (np.max(np.abs(g)) + 1e-9), 0.03 + 0.32 * k)

    return finish(out[:int(0.75 * SR)], 0.75)


def deer_snort(rng):
    n = int(0.35 * SR)
    x = noise(rng, n, lambda f: band(f, rng.uniform(1400, 2200), 1.3) * highpass(f, 500)) * env(n, 0.01, 0.07)
    x += 0.3 * noise(rng, n, lambda f: lowpass(f, 400, 2)) * env(n, 0.01, 0.1)
    return finish(x, 0.7)


def rabbit_thump(rng):
    out = np.zeros(int(0.35 * SR))

    for k in range(2):
        m = int(0.1 * SR)
        t = np.arange(m) / SR
        thud = np.sin(2 * np.pi * np.cumsum(70 * (1.0 + 0.5 * np.exp(-t / 0.02))) / SR) * np.exp(-t / 0.03)
        thud += 0.4 * noise(rng, m, lambda f: lowpass(f, 300, 2)) * env(m, 0.001, 0.02)
        add(out, thud / (np.max(np.abs(thud)) + 1e-9), 0.0 + 0.13 * k)

    return finish(out, 0.8, 0.03)


def rabbit_squeak(rng):
    d = rng.uniform(0.12, 0.2)
    x = voiced(rng, d, rng.uniform(2300, 2800), rng.uniform(3200, 3800), [(3000, 1.0), (6000, 0.3)], rough=0.05, bend=0.8)
    x *= np.sin(np.pi * np.arange(len(x)) / len(x)) ** 0.5
    return finish(x, 0.6, 0.02)


def fox_bark(rng):
    out = np.zeros(int(1.6 * SR))
    at = 0.03

    for _ in range(rng.integers(2, 4)):
        d = rng.uniform(0.12, 0.2)
        b = voiced(rng, d, rng.uniform(650, 800), rng.uniform(420, 520), [(900, 1.0), (1800, 0.7), (3000, 0.3)], rough=0.2, breath=0.15)
        b *= env(len(b), 0.008, d * 0.5)
        add(out, b / (np.max(np.abs(b)) + 1e-9), at)
        at += d + rng.uniform(0.25, 0.4)

    return finish(out[:int((at + 0.1) * SR)], 0.75)


def fox_scream(rng):
    d = rng.uniform(0.9, 1.2)
    x = voiced(rng, d, rng.uniform(750, 900), rng.uniform(1100, 1400), [(1400, 1.0), (2800, 0.8), (4200, 0.4)], rough=0.12, breath=0.1, vib_hz=rng.uniform(8, 14), vib_depth=0.05, bend=0.6)
    x *= np.sin(np.pi * np.arange(len(x)) / len(x)) ** 0.7
    return finish(x, 0.7, 0.08)


def room_tail(rng, x, seconds=1.6, wet=0.35):
    """Distance: a dense decaying noise tail (cheap reverb) mixed behind the dry call, with the highs rolled off."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * 3.2)
    ir = shape(ir, lowpass(freqs(n), 2400))
    size = len(x) + n
    wetsig = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    wetsig *= np.max(np.abs(x)) / (np.max(np.abs(wetsig)) + 1e-9)
    out = np.zeros(size)
    out[:len(x)] += x
    return out + wet * wetsig


def wolf_howl(rng):
    """A wolf howl: breathy low start, a long rise to a held note that wobbles and cracks slightly, then a long sliding fall.
    A pulse-train source (rich harmonics) goes through a throat/mouth formant filter that opens up as the note rises; breath and
    throat noise ride on top, and a reverb tail gives the far-off feel."""
    d = rng.uniform(4.2, 5.4)
    n = int(d * SR)
    t = np.arange(n) / SR
    u = t / d
    f_hold = rng.uniform(380, 470)
    contour = np.interp(u, [0.0, 0.08, 0.30, 0.45, 0.72, 0.88, 1.0],
                        [f_hold * 0.55, f_hold * 0.62, f_hold * 1.0, f_hold * 1.04, f_hold * 1.0, f_hold * 0.8, f_hold * 0.55])
    slow = np.cumsum(rng.standard_normal(n)) / SR
    slow = slow / (np.max(np.abs(slow)) + 1e-9)
    wobble = 1.0 + 0.012 * np.sin(2 * np.pi * 5.2 * t + 1.1) + 0.02 * slow + 0.006 * np.sin(2 * np.pi * 0.9 * t)
    # A small voice crack (a quick jump up) late in the held note.
    crack_at = rng.uniform(0.58, 0.66)
    wobble *= 1.0 + 0.07 * np.exp(-((u - crack_at) / 0.012) ** 2)
    phase = np.cumsum(contour * wobble) / SR
    pulse = 2.0 * (phase % 1.0) - 1.0
    pulse = np.sign(pulse) * np.abs(pulse) ** 0.7 * 0.6 + pulse * 0.4
    spec = freqs(n)
    # Open throat: the formants rise a little as the howl climbs, so blend two filtered copies.
    low = shape(pulse, 1.0 * band(spec, 450, 0.55) + 0.7 * band(spec, 1000, 0.5) + 0.35 * band(spec, 2300, 0.5) + 0.2 * band(spec, 150, 0.8))
    high = shape(pulse, 1.0 * band(spec, 700, 0.55) + 0.8 * band(spec, 1500, 0.5) + 0.4 * band(spec, 2800, 0.5) + 0.2 * band(spec, 150, 0.8))
    mix = np.clip(np.interp(u, [0.0, 0.3, 0.75, 1.0], [0.0, 1.0, 0.8, 0.0]), 0, 1)
    x = low * (1.0 - mix) + high * mix
    breath = noise(rng, n, lambda fr: band(fr, 1800, 1.0)) * 3.0
    throat = noise(rng, n, lambda fr: band(fr, 600, 0.8)) * 2.0
    rise_env = np.clip(u / 0.25, 0, 1)
    x = x + breath * (0.10 + 0.25 * (1.0 - rise_env)) + throat * 0.05
    swell = np.minimum(u / 0.22, 1.0) ** 0.8 * np.minimum((1.0 - u) / 0.28, 1.0) ** 1.1
    x = x * (0.25 + 0.75 * swell) * (0.2 + 0.8 * np.minimum(u / 0.05, 1.0))
    x = finish(x, 0.7, 0.2)
    return finish(room_tail(rng, x), 0.7, 0.3)


def wolf_growl(rng):
    d = rng.uniform(1.0, 1.5)
    x = voiced(rng, d, rng.uniform(70, 90), rng.uniform(55, 70), [(250, 1.0), (700, 0.7), (1600, 0.3)], rough=0.45, breath=0.2)
    n = len(x)
    t = np.arange(n) / SR
    x *= (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t)) * np.minimum(t / 0.15, 1.0) * np.minimum((d - t) / 0.3, 1.0)
    return finish(x, 0.75, 0.1)


def bear_growl(rng):
    d = rng.uniform(1.2, 1.8)
    x = voiced(rng, d, rng.uniform(55, 70), rng.uniform(42, 55), [(180, 1.0), (500, 0.9), (1200, 0.4)], rough=0.5, breath=0.25)
    n = len(x)
    t = np.arange(n) / SR
    x *= (0.55 + 0.45 * np.sin(2 * np.pi * 22 * t)) * np.minimum(t / 0.2, 1.0) * np.minimum((d - t) / 0.4, 1.0)
    return finish(x, 0.85, 0.12)


def bear_roar(rng):
    d = rng.uniform(1.3, 1.9)
    x = voiced(rng, d, rng.uniform(95, 125), rng.uniform(60, 80), [(300, 1.0), (900, 1.0), (2200, 0.6)], rough=0.55, breath=0.5, bend=0.8)
    n = len(x)
    t = np.arange(n) / SR
    x *= np.minimum(t / 0.05, 1.0) * np.exp(-t / (d * 0.55))
    return finish(np.tanh(x * 2.0 / (np.max(np.abs(x)) + 1e-9)), 0.9, 0.15)


def moose_grunt(rng):
    # A low, short cow-like grunt, one or two.
    out = np.zeros(int(1.0 * SR))

    for k in range(rng.integers(1, 3)):
        d = rng.uniform(0.3, 0.5)
        g = voiced(rng, d, rng.uniform(70, 90), rng.uniform(55, 70), [(250, 1.0), (700, 0.7)], rough=0.35, breath=0.15)
        g *= np.sin(np.pi * np.arange(len(g)) / len(g)) ** 0.5
        add(out, g / (np.max(np.abs(g)) + 1e-9), 0.03 + 0.45 * k)

    return finish(out[:int(0.9 * SR)], 0.8)


def moose_snort(rng):
    n = int(0.6 * SR)
    x = noise(rng, n, lambda f: band(f, rng.uniform(700, 1100), 1.4) * highpass(f, 250)) * env(n, 0.02, 0.15)
    x += 0.5 * noise(rng, n, lambda f: lowpass(f, 300, 2)) * env(n, 0.02, 0.2)
    return finish(x, 0.75)


def moose_bellow(rng):
    # The warning: a long loud rough bellow that rises then falls, unmistakable.
    d = rng.uniform(1.6, 2.0)
    x = voiced(rng, d, rng.uniform(95, 115), rng.uniform(70, 85), [(300, 1.0), (800, 1.0), (1800, 0.5)], rough=0.5, breath=0.2, bend=0.85)
    t = np.arange(len(x)) / SR
    x *= np.minimum(t / 0.12, 1.0) * np.minimum((d - t) / 0.3, 1.0)
    return finish(np.tanh(x * 2.0 / (np.max(np.abs(x)) + 1e-9)), 0.9, 0.12)


def horse_snort(rng):
    n = int(0.7 * SR)
    x = noise(rng, n, lambda f: band(f, rng.uniform(900, 1400), 1.2) * highpass(f, 300)) * env(n, 0.02, 0.12)
    x += 0.4 * noise(rng, n, lambda f: lowpass(f, 500, 2)) * env(n, 0.03, 0.2)
    return finish(x, 0.7)


def horse_whinny(rng):
    # A rising squeal then a falling whicker.
    d = rng.uniform(1.2, 1.6)
    x = voiced(rng, d, rng.uniform(380, 460), rng.uniform(260, 320), [(600, 1.0), (1600, 0.8), (3200, 0.4)], rough=0.2, breath=0.15, vib_hz=7.0, vib_depth=0.03, bend=0.7)
    t = np.arange(len(x)) / SR
    x *= np.minimum(t / 0.08, 1.0) * np.minimum((d - t) / 0.3, 1.0)
    return finish(x, 0.8, 0.1)


def duck_quack(rng):
    out = np.zeros(int(0.9 * SR))

    for k in range(rng.integers(2, 4)):
        d = rng.uniform(0.12, 0.18)
        q = voiced(rng, d, rng.uniform(480, 560), rng.uniform(380, 440), [(900, 1.0), (2200, 0.7)], rough=0.4, breath=0.1)
        q *= np.sin(np.pi * np.arange(len(q)) / len(q)) ** 0.4
        add(out, q / (np.max(np.abs(q)) + 1e-9), 0.02 + 0.2 * k)

    return finish(out[:int(0.7 * SR)], 0.7)


SOUNDS = {
    "deer_grunt": deer_grunt, "deer_snort": deer_snort, "rabbit_thump": rabbit_thump, "rabbit_squeak": rabbit_squeak,
    "fox_bark": fox_bark, "fox_scream": fox_scream, "wolf_howl": wolf_howl, "wolf_growl": wolf_growl,
    "bear_growl": bear_growl, "bear_roar": bear_roar,
    "moose_grunt": moose_grunt, "moose_snort": moose_snort, "moose_bellow": moose_bellow, "horse_snort": horse_snort,
    "horse_whinny": horse_whinny, "duck_quack": duck_quack,
}


def main():
    rng = np.random.default_rng(20261024)

    for name, make in SOUNDS.items():
        for v in range(VARIANTS):
            write_ogg("%s_%d" % (name, v), make(rng))

    print("Wrote %d creature sounds to %s" % (len(SOUNDS) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
