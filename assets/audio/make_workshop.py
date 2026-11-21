"""Makes placeholder chopping block and saw mill sounds for src/client/workshop_sounds.gd.

Run: python3 assets/audio/make_workshop.py   (needs numpy and ffmpeg)
Writes assets/audio/workshop/:
  chop_split_N   an axe biting a log on the block and the log splitting: a thock, a crack and a halves-falling clatter, 0.8 s (3 variants)
  chop_thock_N   an axe stroke that does not split: a dull hard thock, 0.3 s (3 variants)
  saw_mill       a saw mill running: a reciprocating blade rasp about 2 strokes a second over a low wheel-and-frame rumble, 12 s, seamless loop
  plank_drop_N   a sawn plank dropping on a stack: a flat clap and a short rattle, 0.5 s (2 variants)
  bellows_blow_N one push of a smelter's leather bellows: a creak of the boards, a breathy rush of air through the nozzle and the fire
                 roaring up with it, 1.1 s (2 variants; PROVISIONAL BW-4, Dave 21 Nov 2026 asked for a bellows sound and the pack had none)
Recordings go in assets/audio/recorded/workshop/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise, ping, thump  # noqa: E402
from make_water import drift, normalize, shaped_noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "workshop")


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


def finish(x, peak=0.8):
    x = x - np.mean(x)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    fade = min(int(0.05 * SR), len(x) // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def grain(rng, length, center, octaves, attack, decay):
    n = int(length * SR)
    g = noise(rng, n, lambda f: band(f, center, octaves) * highpass(f, 150)) * env(n, attack, decay)
    return g / (np.max(np.abs(g)) + 1e-9)


def chop_split(rng):
    out = np.zeros(int(0.8 * SR))
    add(out, thump(rng, 0.14, rng.uniform(110, 150), 0.03, 1400), 0.0)
    add(out, grain(rng, 0.05, rng.uniform(2200, 3200), 1.2, 0.0004, 0.008) * 0.6, 0.0)
    add(out, grain(rng, 0.2, rng.uniform(1200, 1800), 1.0, 0.002, 0.05) * 0.7, 0.04)       # the crack running through
    add(out, thump(rng, 0.1, rng.uniform(150, 210), 0.02, 1800) * 0.7, 0.26)               # one half hitting the ground
    add(out, thump(rng, 0.1, rng.uniform(180, 240), 0.02, 1800) * 0.5, 0.36)               # the other
    add(out, grain(rng, 0.3, 1700, 1.0, 0.01, 0.07) * 0.25, 0.3)
    return finish(out)


def chop_thock(rng):
    out = np.zeros(int(0.3 * SR))
    add(out, thump(rng, 0.12, rng.uniform(120, 170), 0.025, 1600), 0.0)
    add(out, grain(rng, 0.04, rng.uniform(1800, 2800), 1.0, 0.0004, 0.01) * 0.5, 0.0)
    return finish(out)


def plank_drop(rng):
    out = np.zeros(int(0.5 * SR))
    add(out, grain(rng, 0.03, rng.uniform(1500, 2300), 1.2, 0.0004, 0.006), 0.0)
    add(out, thump(rng, 0.1, rng.uniform(140, 190), 0.02, 1400) * 0.8, 0.0)

    for at in (0.07, 0.12, 0.18):
        add(out, ping(rng.uniform(400, 900), 0.015, 0.06) * rng.uniform(0.1, 0.3), at)

    return finish(out)


def saw_mill(rng, seconds=12, strokes_per_s=2.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    cycle = strokes_per_s * seconds                       # whole strokes per loop, so the loop is seamless
    phase = np.cos(2 * np.pi * cycle * t / seconds)       # blade position
    speed = np.abs(np.sin(2 * np.pi * cycle * t / seconds))  # blade speed: loud mid-stroke, quiet at the turn
    rasp = shaped_noise(rng, n, lambda f: band(f, 2600, 0.9) * highpass(f, 900, 2))
    rasp /= np.std(rasp) + 1e-9
    rasp = rasp * (0.15 + 0.85 * speed ** 1.5)
    body = shaped_noise(rng, n, lambda f: band(f, 600, 0.9) * highpass(f, 200, 2))
    body /= np.std(body) + 1e-9
    body = body * (0.1 + 0.4 * speed)
    rumble = shaped_noise(rng, n, lambda f: lowpass(f, 140, 2) * highpass(f, 30, 2))
    rumble /= np.std(rumble) + 1e-9
    knock = np.zeros(n)

    for k in range(int(cycle)):                            # the frame knocking at each end of the stroke
        add(knock, thump(rng, 0.07, 95, 0.015, 600) * 0.5, (k + 0.0) / strokes_per_s)

    x = rasp * 0.7 + body * 0.35 + rumble * 0.5 + knock
    return normalize(x * drift(rng, n, 0.05), 0.12)


def bellows_blow(rng):
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    push = np.sin(np.pi * np.clip(t / 0.75, 0.0, 1.0)) ** 1.5      # the boards closing: the air swells and dies away in 0.75 s
    air = shaped_noise(rng, n, lambda f: band(f, rng.uniform(700, 950), 1.1) * highpass(f, 250, 2))
    air /= np.std(air) + 1e-9
    roar = shaped_noise(rng, n, lambda f: lowpass(f, 220, 2) * highpass(f, 45, 2))   # the fire drawing up behind the blast, a little later
    roar /= np.std(roar) + 1e-9
    roar_env = np.sin(np.pi * np.clip((t - 0.12) / 0.95, 0.0, 1.0)) ** 2
    out = air * push * 0.55 + roar * roar_env * 0.5
    add(out, thump(rng, 0.09, rng.uniform(90, 120), 0.02, 700) * 0.35, 0.0)          # the top board pressed down
    add(out, grain(rng, 0.12, rng.uniform(1400, 2000), 0.6, 0.01, 0.04) * 0.12, 0.02)  # a leather creak
    return finish(out, 0.7)


SOUNDS = {"chop_split": (chop_split, 3), "chop_thock": (chop_thock, 3), "plank_drop": (plank_drop, 2)}


def main():
    rng = np.random.default_rng(20261031)
    count = 0

    for name, (make, variants) in SOUNDS.items():
        for v in range(variants):
            write_ogg("%s_%d" % (name, v), make(rng))
            count += 1

    write_ogg("saw_mill", saw_mill(rng))
    bellows_rng = np.random.default_rng(20261121)   # its own seed, so adding it left every older sound byte for byte as it was

    for v in range(2):
        write_ogg("bellows_blow_%d" % v, bellows_blow(bellows_rng))
        count += 1

    print("Wrote %d workshop sounds to %s" % (count + 1, OUT))


if __name__ == "__main__":
    main()
