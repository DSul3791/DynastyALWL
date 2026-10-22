"""Builds the take-off sounds for src/client/ambient_life.gd (`flush`) from single wing flaps cut out of Dave's recording.

Run: python3 assets/audio/make_wings.py                    builds wing_small/medium/large_N from the grains
     python3 assets/audio/make_wings.py --extract FILE     first cuts the grains wing_grain_N out of Dave's bird_wings_flapping_normal.mp3
                                                           (the file is not kept in the repo; the grains are)

Why: the old wing_flap_0..4 were one slow, big-bird take-off played at several speeds, so every flush sounded like the same low slow
bird. A real take-off is a burst of quick flaps that starts uneven, speeds up and moves away, and a small bird beats faster and higher.
Each burst here is single flaps (the grains) laid at a bird-size rate, every flap a different grain, a little different in pitch,
level and timing, and the burst fades as the bird leaves. Sizes: small (finch, wren; 9 to 12 flaps a second, grain pitched up
1.7 to 2.1x), medium (pigeon, thrush; 5.5 to 7.5 a second, 1.2 to 1.5x), large (crow, hawk; 3 to 4 a second, the grain as recorded).
Recordings go in assets/audio/recorded/ambient/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_stance  # noqa: E402
from make_sounds import SR  # noqa: E402

GRAIN_DIR = os.path.join(HERE, "recorded", "ambient")
make_stance.OUT = os.path.join(HERE, "ambient")
VARIANTS = 4

# size -> (flaps a second [lo, hi], grain pitch ratio [lo, hi], flap count [lo, hi])
SIZES = {
    "small": ((9.0, 12.0), (1.7, 2.1), (9, 14)),
    "medium": ((5.5, 7.5), (1.2, 1.5), (7, 11)),
    "large": ((3.0, 4.0), (0.97, 1.03), (5, 8)),
}


def decode(path):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def extract(source):
    """Cut the single flaps out of the recording: each loud envelope peak, from 40 ms before to 180 ms after."""
    x = decode(source)
    w = SR // 100
    n = len(x) // w
    e = np.sqrt(np.mean(x[:n * w].reshape(n, w) ** 2, axis=1))
    e = np.convolve(e, np.ones(3) / 3, "same")
    floor = e.max() * 0.12
    peaks = [k for k in range(2, n - 2) if e[k] > floor and e[k] >= e[k - 1] and e[k] > e[k + 1] and e[k] > 2.0 * e[k - 2]]
    kept = []

    for k in peaks:
        if not kept or k - kept[-1] >= 20:
            kept.append(k)

    for i, k in enumerate(kept):
        a = max(int((k * 0.01 - 0.04) * SR), 0)
        grain = x[a:a + int(0.22 * SR)].copy()
        grain *= np.minimum(np.arange(len(grain)) / (0.006 * SR), 1.0)
        grain *= np.minimum((len(grain) - np.arange(len(grain))) / (0.05 * SR), 1.0)
        make_stance.OUT = GRAIN_DIR
        make_stance.write_ogg("wing_grain_%d" % i, grain / (np.max(np.abs(grain)) + 1e-9) * 0.7)
        print("grain %d: peak at %.2f s" % (i, k * 0.01))

    make_stance.OUT = os.path.join(HERE, "ambient")


def load_grains():
    grains = []

    for f in sorted(os.listdir(GRAIN_DIR)):
        if f.startswith("wing_grain_") and f.endswith(".ogg"):
            grains.append(decode(os.path.join(GRAIN_DIR, f)))

    if not grains:
        sys.exit("No wing_grain_N.ogg in %s: run with --extract FILE first" % GRAIN_DIR)

    return grains


def resample(g, ratio):
    """Pitch up by `ratio`: plays faster and shorter, as a smaller wing would."""
    idx = np.arange(0, len(g) - 1, ratio)
    return np.interp(idx, np.arange(len(g)), g)


# the recording is thumpy (its strongest part is 50 to 90 Hz, a boom no small bird makes), so the low end is cut by bird size
CUT_HZ = {"small": 320.0, "medium": 220.0, "large": 140.0}


def highpass(x, hz):
    spec = np.fft.rfft(x)
    freq = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec *= np.clip((freq - hz * 0.6) / (hz * 0.8), 0.0, 1.0) ** 2
    return np.fft.irfft(spec, len(x))


def burst(rng, grains, size):
    rate, pitch, count = SIZES[size]
    flaps = int(rng.integers(count[0], count[1] + 1))
    ratio = rng.uniform(*pitch)
    period = 1.0 / rng.uniform(*rate)
    out = np.zeros(int((flaps * period * 1.7 + 0.6) * SR))
    t = 0.0
    last = -1

    for k in range(flaps):
        pick = int(rng.integers(0, len(grains)))
        pick = (pick + 1) % len(grains) if pick == last and len(grains) > 1 else pick
        last = pick
        g = resample(grains[pick], ratio * rng.uniform(0.96, 1.04))
        # a take-off starts uneven and slow, then settles at the full rate
        slow = 1.0 + 0.7 * max(0.0, 1.0 - k / 3.0)
        # level: the first beats build up, then the bird flies away and the rest fall off
        build = min((k + 1) / 2.5, 1.0)
        away = np.exp(-1.6 * k / flaps)
        gain = build * away * rng.uniform(0.75, 1.0)
        a = int(t * SR)
        out[a:a + len(g)] += g * gain
        t += period * slow * rng.uniform(0.88, 1.12)

    out = out[:int((t + 0.25) * SR)]
    out = highpass(out, CUT_HZ[size])
    return make_stance.finish(out, 0.7)


def main():
    if "--extract" in sys.argv:
        extract(sys.argv[sys.argv.index("--extract") + 1])

    grains = load_grains()
    rng = np.random.default_rng(20261127)

    for size in SIZES:
        for v in range(VARIANTS):
            make_stance.write_ogg("wing_%s_%d" % (size, v), burst(rng, grains, size))

    print("Wrote %d take-off sounds from %d grains to %s" % (len(SIZES) * VARIANTS, len(grains), make_stance.OUT))


if __name__ == "__main__":
    main()
