"""Sound batch 2 (Kathleen, goal 7): ambience. Beds (seamless loops) plus randomised one-shots, all synthesized.

Run: python3 assets/audio/make_batch2.py   (needs numpy and ffmpeg). Writes assets/audio/batch2/<slot>_N.ogg.
Beds are built from whole-signal FFT noise and modulations with a whole number of cycles per loop, so they are periodic by construction
(the loop seam is then checked numerically by tools/validate_sound_slots.py). Beds are 24 kHz, 20 s, peak -14 dB; one-shots 44.1 kHz, peak -14 dB.
The game picks slots by the tags in data/sound/batch2_slots.json (season, time of day, biome, water, altitude) and plays one-shots on a
random 4-20 s gap with pitch +/-5 percent, never the same variant twice in a row (engine side is Steve's).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, highpass, lowpass, noise, soft_limit, thump, wind_loop  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "batch2")
DB14 = 10 ** (-14 / 20)
BED_S = 20
BED_SR = 24000


def write(name, x, peak, sr=SR, quality=4):
    os.makedirs(OUT, exist_ok=True)
    x = x - np.mean(x)
    x = x * (peak / (np.max(np.abs(x)) + 1e-9))
    data = (np.clip(soft_limit(x), -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-ar", str(sr), "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        "-c:a", "libvorbis", "-q:a", str(quality), os.path.join(OUT, name + ".ogg")], check=True)


def fade(x, ms=8):
    n = min(int(ms * SR / 1000), len(x) // 4)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def swell(n, cycles, phases, weights):
    """A slow periodic 0..1 modulation: sines with a whole number of cycles per loop."""
    t = np.arange(n) / n
    g = sum(w * np.sin(2 * np.pi * c * t + p) for w, c, p in zip(weights, cycles, phases)) / sum(weights)
    return 0.5 + 0.5 * g


# ------------------------------------------------------------ beds (loops)
def bed_forest_day(rng):
    """Leaves and grass stirring, a soft airy hush with slow lulls (spring, summer, autumn by day)."""
    return wind_loop(rng, BED_S, "gust") * 0.7 + wind_loop(rng, BED_S, "low") * 0.5


def bed_forest_winter(rng):
    """Bare branches: a thin, sparse wind with long calm."""
    x = wind_loop(rng, BED_S, "low")
    n = len(x)
    return x * (0.15 + 0.85 * swell(n, [1, 2], [0.4, 2.0], [0.7, 0.3]) ** 2)


def bed_night(rng):
    """Still night air: a very quiet low hush that breathes slowly."""
    n = BED_S * SR
    x = noise(rng, n, lambda f: lowpass(f, 300, 2) * highpass(f, 60, 2) / np.sqrt(np.maximum(f, 40.0)))
    return x * (0.5 + 0.5 * swell(n, [1, 3], [1.0, 4.0], [0.7, 0.3]))


def bed_crickets(rng):
    """Crickets on a warm night: many pulsing 4.3 kHz chirpers, each a whole number of pulses per loop."""
    n = BED_S * SR
    t = np.arange(n) / SR
    out = np.zeros(n)

    for k in range(7):
        freq = rng.uniform(4000, 4900)
        rate = rng.integers(40, 56)                      # pulses per loop-second group: chirp groups of three
        pulses = (0.5 + 0.5 * np.sin(2 * np.pi * rate * t / 3.0 * 1.0 + rng.uniform(0, 6.28))) ** 3
        groups = 0.5 + 0.5 * np.sin(2 * np.pi * rng.integers(2, 4) * t / BED_S * 4.0 + rng.uniform(0, 6.28))
        carrier = np.sin(2 * np.pi * freq * t + 2.0 * np.sin(2 * np.pi * rate * t / 3.0))
        out += carrier * pulses * (0.3 + 0.7 * groups) * rng.uniform(0.5, 1.0)

    return out + 0.02 * noise(rng, n, lambda f: band(f, 4400, 1.0))


def bed_surf(rng):
    """Waves on a beach: a swell every 5 s (loop = 4 swells), a long roar and a hissing wash receding."""
    n = BED_S * SR
    t = np.arange(n) / SR
    period = BED_S / 4.0
    body = noise(rng, n, lambda f: band(f, 500, 1.3) * highpass(f, 120))
    hiss = noise(rng, n, lambda f: band(f, 3000, 1.2) * highpass(f, 1200))

    p = (t / period) % 1.0
    ebb = np.exp(-(p - 0.45) / 0.22) - np.exp(-0.55 / 0.22) * (p - 0.45) / 0.55     # reaches 0 at the end of the swell, so the loop seam is continuous
    env_one = np.where(p < 0.45, (p / 0.45) ** 2, np.maximum(ebb, 0.0))
    wobble = 0.8 + 0.2 * np.sin(2 * np.pi * 3 * t / BED_S + rng.uniform(0, 6.28))
    return (body * (0.25 + 0.75 * env_one) + 0.6 * hiss * env_one ** 1.5) * wobble


def bed_desert_wind(rng):
    """Dry wind over sand: a steady low sweep with a fine hissing grain of blown sand."""
    n = BED_S * SR
    g = swell(n, [1, 2, 3], [0.2, 1.7, 3.1], [0.5, 0.3, 0.2])
    low = noise(rng, n, lambda f: band(f, 280, 1.2) / np.sqrt(np.maximum(f, 30.0)))
    sand = noise(rng, n, lambda f: band(f, 4200, 1.0) * highpass(f, 2000))
    return low * (0.3 + 0.7 * g) + 0.35 * sand * g ** 2


def bed_canyon_wind(rng):
    """Wind moving through rock: hollow, slowly changing pipe tones over a faint hush."""
    n = BED_S * SR
    g = swell(n, [1, 2, 3], [0.9, 2.2, 4.0], [0.5, 0.3, 0.2])
    out = noise(rng, n, lambda f: band(f, 220, 0.12) + 0.7 * band(f, 330, 0.1) + 0.4 * band(f, 490, 0.1))
    hush = noise(rng, n, lambda f: band(f, 600, 1.3) * highpass(f, 120)) * 0.4
    return (out / (np.max(np.abs(out)) + 1e-9) * 1.5 + hush) * (0.2 + 0.8 * g)


def bed_volcano(rng):
    """A far, moderate rumble: low body that slowly swells, with a faint lava hiss on top."""
    n = BED_S * SR
    g = swell(n, [1, 2, 5], [0.3, 1.1, 2.5], [0.5, 0.3, 0.2])
    low = noise(rng, n, lambda f: lowpass(f, 70, 3) * highpass(f, 22, 2))
    mid = noise(rng, n, lambda f: band(f, 130, 0.8))
    hiss = noise(rng, n, lambda f: band(f, 3500, 1.0) * highpass(f, 1800))
    return low / np.max(np.abs(low)) * (0.5 + 0.5 * g) + 0.2 * mid / np.max(np.abs(mid)) * g + 0.07 * hiss / np.max(np.abs(hiss)) * g ** 2


def bed_pond(rng):
    """The quiet at a pond: a very low hush with a faint bubbling ripple."""
    n = BED_S * SR
    g = swell(n, [3, 7], [0.5, 2.0], [0.6, 0.4])
    hush = noise(rng, n, lambda f: band(f, 350, 1.2) * highpass(f, 80)) * 0.5
    ripple = noise(rng, n, lambda f: band(f, 1800, 0.8) * highpass(f, 900)) * g ** 3
    return hush + 0.35 * ripple


# ------------------------------------------------------------ one-shots
def chirp(freq0, freq1, length, vibrato=0.0, vib_rate=0.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = np.linspace(freq0, freq1, n) * (1 + vibrato * np.sin(2 * np.pi * vib_rate * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(phase) + 0.25 * np.sin(2 * phase)) * np.hanning(n)


def bird_tweet(rng):
    """Three to five short rising-falling notes: a small bird in a hedge."""
    out = np.zeros(int(1.1 * SR))
    at = 0.04
    base = rng.uniform(3000, 4200)

    for k in range(rng.integers(3, 6)):
        length = rng.uniform(0.05, 0.09)
        add(out, chirp(base * rng.uniform(0.9, 1.1), base * rng.uniform(1.15, 1.5), length), at)
        at += length + rng.uniform(0.04, 0.08)

    return fade(out)


def bird_whistle(rng):
    """Two or three clear, slow, falling whistled notes: a thrush."""
    out = np.zeros(int(1.6 * SR))
    at = 0.05
    base = rng.uniform(2200, 2900)

    for k in range(rng.integers(2, 4)):
        length = rng.uniform(0.22, 0.32)
        add(out, chirp(base * rng.uniform(1.05, 1.25), base * rng.uniform(0.8, 0.95), length, 0.012, 22), at)
        at += length + rng.uniform(0.12, 0.2)

    return fade(out)


def bird_trill(rng):
    """A quick trilling run on one pitch: a wren."""
    out = np.zeros(int(1.2 * SR))
    freq = rng.uniform(3600, 4600)
    t = np.arange(int(0.8 * SR)) / SR
    trill = np.sin(2 * np.pi * freq * t + 3.0 * np.sin(2 * np.pi * rng.uniform(26, 34) * t)) * np.hanning(len(t)) ** 0.7
    add(out, trill, 0.05)
    return fade(out)


def owl_hoot(rng):
    """A soft hoot: one short note, then a pause and a longer one; warm, round, never sharp."""
    out = np.zeros(int(2.2 * SR))
    base = rng.uniform(300, 360)

    for at, length, drop in [(0.1, 0.35, 0.93), (0.65, 0.9, 0.88)]:
        n = int(length * SR)
        t = np.arange(n) / SR
        f = base * np.linspace(1.0, drop, n)
        phase = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sin(phase) + 0.3 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
        add(out, tone * np.hanning(n) ** 1.5, at)

    return fade(out, 30)


def frog_croak(rng):
    """A pond frog: a short pulsed croak, a low buzz of about 38 pulses a second, pitch dipping."""
    n = int(rng.uniform(0.28, 0.4) * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(260, 340) * np.linspace(1.0, 0.85, n)
    phase = 2 * np.pi * np.cumsum(f0) / SR
    carrier = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.3 * np.sin(3 * phase)
    pulses = (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)) ** 1.5
    out = carrier * pulses * np.hanning(n) ** 0.6
    out = out + 0.15 * noise(rng, n, lambda f: band(f, 900, 1.0)) * np.hanning(n)
    pad = np.zeros(int(0.5 * SR))
    pad[:n] = out
    return fade(pad)


def canyon_echo(rng):
    """A far crack of stone and its echoes off the walls: three taps, each softer and duller."""
    out = np.zeros(int(4.5 * SR))
    first = thump(rng, 0.18, 150, 0.03, 2000)

    for k, (at, gain, cut) in enumerate([(0.05, 1.0, 5000), (0.9, 0.5, 2400), (1.8, 0.28, 1400), (3.0, 0.14, 900)]):
        x = first.copy()
        n = len(x)
        spec = np.fft.rfft(x)
        f = np.fft.rfftfreq(n, 1.0 / SR)
        x = np.fft.irfft(spec * lowpass(f, cut, 2), n)
        add(out, x * gain, at)

    return fade(out, 40)


def ice_crack(rng):
    """Ice under strain, moderate: a short dry tick that runs into a few quick, falling creaks."""
    out = np.zeros(int(1.4 * SR))
    add(out, 0.8 * burst(rng, 0.012, 3800, 0.8), 0.02)
    t0 = 0.05

    for k in range(rng.integers(3, 6)):
        length = rng.uniform(0.04, 0.09)
        add(out, 0.5 * burst(rng, length, rng.uniform(1800, 3200), 0.6) * env(int(length * SR) + 8, 0.002, 0.02)[: max(int(length * SR), 8)], t0)
        t0 += rng.uniform(0.04, 0.16)

    n = int(0.5 * SR)
    t = np.arange(n) / SR
    creak = np.sin(2 * np.pi * np.cumsum(np.linspace(900, 380, n)) / SR) * np.exp(-t / 0.12) * 0.25
    add(out, creak, t0)
    return fade(out, 12)


def lava_hiss(rng):
    """Lava seeping: a soft steady hiss with a slow gurgle underneath; a bed of its own for the crater edge."""
    n = BED_S * SR
    g = swell(n, [2, 5], [1.0, 3.3], [0.6, 0.4])
    hiss = noise(rng, n, lambda f: band(f, 4500, 0.9) * highpass(f, 1500)) * (0.4 + 0.6 * g)
    gurgle = noise(rng, n, lambda f: band(f, 220, 0.7) * lowpass(f, 500)) * g
    return hiss / np.max(np.abs(hiss)) * 0.5 + gurgle / np.max(np.abs(gurgle)) * 0.5


def main():
    seeds = {"forest_day": 5001, "forest_winter": 5002, "night": 5003, "crickets": 5004, "surf": 5045, "desert_wind": 5006, "canyon_wind": 5007,
             "volcano_rumble": 5008, "pond": 5009, "lava_hiss": 5010}
    beds = {"forest_day": bed_forest_day, "forest_winter": bed_forest_winter, "night": bed_night, "crickets": bed_crickets, "surf": bed_surf,
            "desert_wind": bed_desert_wind, "canyon_wind": bed_canyon_wind, "volcano_rumble": bed_volcano, "pond": bed_pond, "lava_hiss": lava_hiss}

    for name, make in beds.items():
        write("bed_%s_0" % name, make(np.random.default_rng(seeds[name])), DB14, BED_SR, 2)

    shots = {"bird_tweet": (bird_tweet, 3), "bird_whistle": (bird_whistle, 3), "bird_trill": (bird_trill, 3), "owl_hoot": (owl_hoot, 3),
             "frog_croak": (frog_croak, 4), "canyon_echo": (canyon_echo, 2), "ice_crack": (ice_crack, 3)}

    for name, (make, count) in shots.items():
        for v in range(count):
            write("%s_%d" % (name, v), make(np.random.default_rng(6000 + 100 * list(shots).index(name) + v)), DB14)


if __name__ == "__main__":
    main()
