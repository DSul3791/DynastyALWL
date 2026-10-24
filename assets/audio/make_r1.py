"""Sound batch R1 (Kathleen, goal 7): the first-hour sounds Dave's early-game list needs: lying on the rough bed and getting up, casting and hauling the shore net,
picking thatching grass, lashing a tripod. Own synthesis from make_sounds.py helpers.

Run: python3 assets/audio/make_r1.py   (needs numpy and ffmpeg). Writes assets/audio/r1/<slot>_N.ogg (3 variants each), peak -6 dB; the game sets the mix level.
Fire sizes need no new clips: fire_small (survival fire and campfire at low level) and fire_large (bonfire) already exist; Steve maps tier to clip and level.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, highpass, lowpass, noise, soft_limit, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "r1")
VARIANTS = 3
DB6 = 10 ** (-6 / 20)


def write(name, x, peak):
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

        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def fade(x, ms=10):
    n = min(int(ms * SR / 1000), len(x) // 4)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def straw(rng, seconds, density, level):
    """Dry straw crackling: many tiny bright grains, uneven."""
    n = int(seconds * SR)
    out = np.zeros(n)

    for _ in range(int(density * seconds)):
        at = rng.uniform(0, seconds - 0.05)
        add(out, burst(rng, rng.uniform(0.004, 0.02), rng.uniform(2500, 6000), 1.0) * rng.pareto(2.5) * 0.3 * level, at)

    return out


def bed_lie(rng):
    """A body settling onto a straw mat: a soft low weight, a long straw crackle that eases off, one last shift."""
    n = int(1.6 * SR)
    out = np.zeros(n)
    add(out, thump(rng, 0.25, 70, 0.08, 500) * 0.5, 0.05)
    out += straw(rng, 1.6, 140, 1.0) * np.exp(-np.arange(n) / SR / 0.6)
    add(out, noise(rng, int(0.4 * SR), lambda f: band(f, 900, 1.3) * lowpass(f, 2500, 2)) * np.hanning(int(0.4 * SR)) * 0.12, 0.6)
    return fade(out, 30)


def bed_rise(rng):
    """Getting up: a short strained crackle and the mat springing back."""
    n = int(1.0 * SR)
    out = np.zeros(n)
    out += straw(rng, 1.0, 110, 0.9) * np.exp(-np.arange(n) / SR / 0.35)
    add(out, thump(rng, 0.15, 90, 0.05, 700) * 0.25, 0.0)
    return fade(out, 25)


def net_cast(rng):
    """A cast net: a twine whirr and flutter, a rising whoosh, a wide soft splash and a long trickle as it sinks."""
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    whoosh = noise(rng, int(0.5 * SR), lambda f: band(f, 1400, 1.2) * highpass(f, 400))
    add(out, whoosh * np.hanning(len(whoosh)) * 0.35, 0.05)
    add(out, straw(rng, 0.5, 90, 0.4)[:int(0.5 * SR)], 0.05)
    splash = noise(rng, int(0.5 * SR), lambda f: band(f, 2500, 1.6) * highpass(f, 600)) * env(int(0.5 * SR), 0.004, 0.12)
    add(out, splash * 0.7, 0.62)
    trickle = np.zeros(n)

    for _ in range(70):
        add(trickle, burst(rng, rng.uniform(0.01, 0.04), rng.uniform(1500, 4000), 0.8) * rng.pareto(3.0) * 0.12, 0.8 + rng.exponential(0.5))

    out += trickle
    return fade(out, 40)


def net_haul(rng):
    """Dragging a wet net in: a heavy wet drag with twine creaks and drips."""
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    drag = noise(rng, n, lambda f: band(f, 600, 1.4) * lowpass(f, 1800, 2))
    drag *= 0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 1.7 * t + rng.uniform(0, 6)))
    drag *= np.sin(np.pi * np.clip(t / 1.95, 0, 1)) ** 0.7
    out = drag * 0.5

    for _ in range(14):
        add(out, burst(rng, rng.uniform(0.02, 0.06), rng.uniform(1200, 2500), 0.5) * 0.2, rng.uniform(0.1, 1.8))

    return fade(out, 40)


def thatch_pick(rng):
    """Pulling a handful of tall grass: a tearing rip of fibres and a dry rustle as it comes free."""
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    rip = noise(rng, n, lambda f: band(f, 3200, 1.2) * highpass(f, 900)) * np.exp(-t / 0.12) * (np.sin(2 * np.pi * 38 * t) > -0.2)
    out = rip * 0.5 + straw(rng, 0.9, 120, 0.7) * np.exp(-t / 0.3)
    return fade(out, 15)


def lash_twine(rng):
    """Lashing sticks together: three quick twine pulls with a small wood knock between them."""
    n = int(1.4 * SR)
    out = np.zeros(n)

    for k in range(3):
        at = 0.05 + 0.42 * k
        pull = noise(rng, int(0.22 * SR), lambda f: band(f, 2200, 1.0) * highpass(f, 700))
        add(out, pull * np.hanning(len(pull)) * 0.35, at)
        add(out, thump(rng, 0.1, 200, 0.03, 2500) * 0.35, at + 0.2)

    return fade(out, 20)


SLOTS = {
    "bed_lie": bed_lie,
    "bed_rise": bed_rise,
    "net_cast": net_cast,
    "net_haul": net_haul,
    "thatch_pick": thatch_pick,
    "twine_lash": lash_twine,
}


def main():
    for slot, make in SLOTS.items():
        for v in range(VARIANTS):
            write("%s_%d" % (slot, v), make(np.random.default_rng(7000 + 100 * list(SLOTS).index(slot) + v)), DB6)


if __name__ == "__main__":
    main()
