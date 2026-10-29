"""Makes placeholder footsteps for built floors, for src/client/sound_stage.gd (set_floor / floor_under).

Run: python3 assets/audio/make_floors.py   (needs numpy and ffmpeg)
Writes assets/audio/floors/step_<surface>_N (3 variants each):
  plank  hollow wooden boards: a dull knock and a short board creak   slab   stone slabs: a hard tap and a short ring
  carpet a muffled thud, almost no top                                 thatch dry straw: a soft crunchy rustle
  path   packed gravel path: a firm crunch                             ice    a frozen pond: a hard tap, a hollow tock, a glassy ring
(--only ice makes just that one.)
Recordings go in assets/audio/recorded/ as step_<surface>_left_N / step_<surface>_right_N like the ground sets.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, finish, highpass, lowpass, noise, ping, step_base, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "floors")
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


def step_plank(rng):
    out, toe = step_base(rng, 0.4, rng.uniform(110, 140), 0.03, heel=1.0, toe=0.5, click_cut=1400)
    n = len(out)
    body = sum(ping(rng.uniform(160, 300), rng.uniform(0.03, 0.07), 0.25) * rng.uniform(0.2, 0.5) for _ in range(3))
    add(out, body * 0.5, 0.004)
    creak = noise(rng, int(0.12 * SR), lambda f: band(f, rng.uniform(500, 900), 0.5) * highpass(f, 250)) * env(int(0.12 * SR), 0.03, 0.05)
    add(out, creak / (np.max(np.abs(creak)) + 1e-9) * 0.12, 0.03)
    return finish(out / 2.2)


def step_slab(rng):
    n = int(0.34 * SR)
    out = np.zeros(n)
    toe = rng.uniform(0.07, 0.1)

    for at, amp in ((0.003, 1.0), (toe, 0.5)):
        tap = noise(rng, int(0.012 * SR), lambda f: highpass(f, 700) * lowpass(f, 4200)) * env(int(0.012 * SR), 0.0005, 0.003)
        tap /= np.max(np.abs(tap)) + 1e-9
        ring = sum(ping(rng.uniform(500, 1300), rng.uniform(0.02, 0.05), 0.2) * rng.uniform(0.2, 0.4) for _ in range(2))
        add(out, amp * tap, at)
        add(out, amp * 0.4 * ring, at)
        add(out, amp * 0.6 * thump(rng, 0.08, 100, 0.014, 1500), at)

    return finish(out)


def step_carpet(rng):
    out, toe = step_base(rng, 0.34, rng.uniform(70, 85), 0.022, heel=0.7, toe=0.3, click_cut=350)
    n = len(out)
    fuzz = noise(rng, n, lambda f: band(f, 500, 1.0) * lowpass(f, 1100, 3)) * env(n, 0.01, 0.04, int(0.004 * SR))
    return finish(out / 2.2 + 0.12 * fuzz / (np.max(np.abs(fuzz)) + 1e-9))


def step_thatch(rng):
    out, toe = step_base(rng, 0.42, rng.uniform(70, 85), 0.022, heel=0.5, toe=0.25, click_cut=600)
    n = len(out)
    rustle = noise(rng, n, lambda f: band(f, 2600, 0.9) * highpass(f, 900))
    grains = np.zeros(n)

    for _ in range(int(rng.integers(10, 18))):
        at = rng.uniform(0.0, 0.3)
        add(grains, rng.standard_normal(int(0.004 * SR)) * rng.uniform(0.3, 1.0), at)

    rustle = rustle * env(n, 0.01, 0.07) * (0.5 + 0.5 * (grains != 0))
    return finish(out / 2.4 + 0.3 * rustle / (np.max(np.abs(rustle)) + 1e-9))


def step_path(rng):
    out, toe = step_base(rng, 0.38, rng.uniform(80, 95), 0.025, heel=0.9, toe=0.4, click_cut=1000)
    n = len(out)
    crunch = noise(rng, n, lambda f: band(f, 2200, 1.0) * highpass(f, 700)) * env(n, 0.006, 0.05)
    return finish(out / 2.2 + 0.28 * crunch / (np.max(np.abs(crunch)) + 1e-9))


def step_ice(rng):
    # A boot on a frozen pond: a hard dry tap, a hollow low tock from the sheet under it, a faint glassy ring.
    out, toe = step_base(rng, 0.45, rng.uniform(140, 170), 0.03, heel=0.5, toe=0.25, click_cut=2500)
    m = int(0.05 * SR)
    tap = noise(rng, m, lambda f: band(f, rng.uniform(2400, 3600), 0.8) * highpass(f, 900)) * env(m, 0.0005, 0.012)
    tap /= np.max(np.abs(tap)) + 1e-9
    mix = out / 3.0
    add(mix, tap * 0.5, 0.0)
    add(mix, ping(rng.uniform(2800, 4200), 0.09, 0.3) * 0.12, 0.004)
    return finish(mix)


SURFACES = {"plank": step_plank, "slab": step_slab, "carpet": step_carpet, "thatch": step_thatch, "path": step_path, "ice": step_ice}


def main():
    rng = np.random.default_rng(20261021)
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""

    for name, make in SURFACES.items():
        if only and name != only:
            continue

        for v in range(VARIANTS):
            write_ogg("step_%s_%d" % (name, v), make(rng))

    print("Wrote %d floor footsteps to %s" % (len(SURFACES) * VARIANTS, OUT))


if __name__ == "__main__":
    main()
