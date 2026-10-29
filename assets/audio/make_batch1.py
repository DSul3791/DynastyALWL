"""Sound batch 1 (Kathleen, goal 7): species footsteps, doors by material, ladder rungs, water wheel loop, woodworking table, cloak rustle.

Run: python3 assets/audio/make_batch1.py   (needs numpy and ffmpeg). Writes assets/audio/batch1/<slot>_N.ogg (3 variants each, a loop is one file).
Own synthesis from the helpers in make_sounds.py (no downloads, no licence needed). Creature-class sounds peak at -12 dB, everything else at -6 dB; the game sets the mix level.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, finish, highpass, lowpass, noise, ping, soft_limit, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "batch1")
VARIANTS = 3
DB12 = 10 ** (-12 / 20)
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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def fade(x, ms=6):
    n = min(int(ms * SR / 1000), len(x) // 4)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


# ------------------------------------------------------------ creature steps (-12 dB)
def hoof(rng, f0, size):
    """A hoof on firm ground: a dull knock and a sharp tick; `size` scales the length and the weight."""
    n = int(0.28 * SR)
    out = np.zeros(n)
    add(out, thump(rng, 0.1, f0 * rng.uniform(0.92, 1.08), 0.02 * size, 2200), 0.003)
    add(out, 0.5 * burst(rng, 0.012, 2400 * rng.uniform(0.9, 1.1), 1.2), 0.002)
    add(out, 0.55 * thump(rng, 0.09, f0 * 1.15, 0.016 * size, 1800), 0.06 + 0.02 * size)
    return fade(out)


def paw(rng, f0):
    """A padded paw: a soft thud and a little dry leaf scuff."""
    n = int(0.22 * SR)
    out = np.zeros(n)
    add(out, thump(rng, 0.09, f0 * rng.uniform(0.9, 1.1), 0.02, 600), 0.003)
    add(out, 0.25 * noise(rng, int(0.08 * SR), lambda f: band(f, 1800, 1.2)) * env(int(0.08 * SR), 0.004, 0.03), 0.015)
    return fade(out)


def webbed(rng):
    """A duck's flat foot slap on ground: quick, wet, soft."""
    n = int(0.16 * SR)
    out = np.zeros(n)
    add(out, 0.8 * burst(rng, 0.03, 900 * rng.uniform(0.9, 1.1), 1.0), 0.002)
    add(out, 0.6 * thump(rng, 0.05, 140, 0.012, 900), 0.004)
    return fade(out)


def hop(rng):
    """A rabbit's hop landing: two quick soft thuds."""
    out = np.zeros(int(0.2 * SR))
    add(out, thump(rng, 0.07, 110 * rng.uniform(0.9, 1.1), 0.016, 500), 0.003)
    add(out, 0.6 * thump(rng, 0.06, 140, 0.012, 500), 0.05)
    return fade(out)


# ------------------------------------------------------------ doors (-6 dB)
def creak(rng, length, f0, f1, amount):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n) * (1 + 0.04 * np.sin(2 * np.pi * rng.uniform(9, 14) * t))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    tone *= np.sin(np.pi * t / length) ** 0.6
    grit = noise(rng, n, lambda fr: band(fr, f0 * 3, 1.2)) * 0.25
    return amount * (tone + grit * np.sin(np.pi * t / length))


def door(rng, material, opening):
    n = int(0.9 * SR)
    out = np.zeros(n)

    if material == "wood":
        if opening:
            add(out, 0.5 * thump(rng, 0.08, 160, 0.015, 1500), 0.0)           # latch lifts
            add(out, 0.6 * creak(rng, 0.55, 190 * rng.uniform(0.9, 1.1), 260, 1.0), 0.06)
        else:
            add(out, 0.5 * creak(rng, 0.3, 240, 170, 1.0), 0.0)
            add(out, 1.0 * thump(rng, 0.12, 110, 0.03, 1400), 0.3)             # the door meets its frame
            add(out, 0.4 * thump(rng, 0.06, 180, 0.012, 1800), 0.4)           # latch drops
    elif material == "iron":
        if opening:
            add(out, 0.6 * ping(900 * rng.uniform(0.95, 1.05), 0.04, 0.2), 0.0)
            add(out, 0.5 * creak(rng, 0.6, 420, 560, 1.0), 0.05)
        else:
            add(out, 0.4 * creak(rng, 0.3, 560, 420, 1.0), 0.0)
            add(out, 1.0 * thump(rng, 0.1, 90, 0.04, 2500), 0.28)
            add(out, 0.7 * ping(1100 * rng.uniform(0.95, 1.05), 0.12, 0.4), 0.28)    # iron rings
    else:  # steel: heavier, cleaner, a bar slides home
        if opening:
            add(out, 0.7 * ping(1500, 0.05, 0.25), 0.0)
            add(out, 0.4 * noise(rng, int(0.4 * SR), lambda fr: band(fr, 2200, 1.0)) * env(int(0.4 * SR), 0.05, 0.2), 0.04)
        else:
            add(out, 1.0 * thump(rng, 0.14, 80, 0.05, 3000), 0.1)
            add(out, 0.8 * ping(1800 * rng.uniform(0.97, 1.03), 0.18, 0.6), 0.1)
            add(out, 0.5 * ping(2700, 0.1, 0.4), 0.1)
    return fade(out, 10)


def ladder_rung(rng):
    """A hand-over-hand step on a wooden rung: a hollow knock and a creak of the rail."""
    out = np.zeros(int(0.25 * SR))
    add(out, thump(rng, 0.09, 170 * rng.uniform(0.9, 1.1), 0.02, 1200), 0.003)
    add(out, 0.18 * creak(rng, 0.12, 300, 340, 1.0), 0.03)
    return fade(out)


def wheel_loop(rng):
    """A water wheel turning: paddles slap the stream, a wooden axle creaks, water rushes; the bed repeats exactly every 2.4 s so it loops seamlessly."""
    seconds = 2.4
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    rush = noise(rng, n, lambda fr: band(fr, 700, 1.8) * lowpass(fr, 3000, 2))
    out += 0.35 * rush / (np.max(np.abs(rush)) + 1e-9)

    for k in range(6):                     # six paddles per turn
        at = k * seconds / 6.0
        slap = thump(rng, 0.14, 100, 0.03, 900) * 0.7
        add(out, slap, at)

    # a whole number of creak cycles in the loop, so it ends where it begins
    creak_osc = np.sin(2 * np.pi * 170 * t + 1.5 * np.sin(2 * np.pi * 2 * t / seconds * 2)) * (0.5 + 0.5 * np.sin(2 * np.pi * t / seconds + 1.0)) ** 2
    out += 0.08 * creak_osc
    wrapped = np.concatenate([out[-512:], out[:512]])   # crossfade the seam
    out[:512] = 0.5 * (out[:512] + np.linspace(1, 0, 512) * out[-512:])
    out[-512:] *= np.linspace(1, 0.5, 512)
    return out


def plane_stroke(rng):
    """A hand plane along a board: a rising scrape of wood with a quick shaving hiss."""
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    scrape = noise(rng, n, lambda fr: band(fr, 2200 + 1500 * rng.uniform(0, 1), 1.0))
    scrape *= np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 0.7
    rough = 1 + 0.5 * np.sin(2 * np.pi * rng.uniform(55, 80) * t)
    return fade(scrape * rough, 15)


def vice_clamp(rng):
    """A wooden vice screwed shut: three creaking turns and a final thunk."""
    out = np.zeros(int(0.8 * SR))

    for k in range(3):
        add(out, 0.5 * creak(rng, 0.14, 240 + 30 * k, 300 + 30 * k, 1.0), 0.05 + 0.17 * k)

    add(out, 1.0 * thump(rng, 0.1, 100, 0.03, 1400), 0.62)
    return fade(out)


def cloak_rustle(rng):
    """Heavy hide or cloth moving: a soft low swish."""
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    sw = noise(rng, n, lambda fr: band(fr, 900, 1.4) * lowpass(fr, 2500, 2))
    return fade(sw * np.sin(np.pi * np.clip(t / 0.48, 0, 1)) ** 1.5, 20)


def main():
    steps = {"deer": (180, 1.0), "moose": (120, 1.6), "horse": (130, 1.5)}

    for v in range(VARIANTS):
        rng = np.random.default_rng(1000 + v)

        for sp, (f0, size) in steps.items():
            write("%s_step_%d" % (sp, v), hoof(rng, f0, size), DB12)

        write("wolf_step_%d" % v, paw(rng, 90), DB12)
        write("fox_step_%d" % v, paw(rng, 120), DB12)
        write("duck_step_%d" % v, webbed(rng), DB12)
        write("rabbit_hop_%d" % v, hop(rng), DB12)

        for material in ["wood", "iron", "steel"]:
            write("door_%s_open_%d" % (material, v), door(rng, material, True), DB6)
            write("door_%s_close_%d" % (material, v), door(rng, material, False), DB6)

        write("ladder_rung_%d" % v, ladder_rung(rng), DB6)
        write("table_plane_%d" % v, plane_stroke(rng), DB6)
        write("cloak_rustle_%d" % v, cloak_rustle(rng), DB6)

    for v in range(2):
        write("table_vice_%d" % v, vice_clamp(np.random.default_rng(2000 + v)), DB6)

    write("water_wheel_loop_0", wheel_loop(np.random.default_rng(3000)), DB6)


if __name__ == "__main__":
    main()
