"""Makes placeholder sounds for wet tunnels under water for src/client/wet_sounds.gd (art/WET_TUNNEL_PLAN.md).

Run: python3 assets/audio/make_wet.py   (needs numpy and ffmpeg)
Writes assets/audio/wet/:
  drip_plink_0..3   one drop landing on stone, 0.5 s
  drip_trickle_0..1 a soft stream running down rock, 4 s, loops
  wet_step_0..3     a small splash and squelch for one footstep on the wet floor, 0.35 s
Recordings go in assets/audio/recorded/wet/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, highpass, noise, ping  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wet")


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


def finish(x, peak=0.7):
    x = x - np.mean(x)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    fade = min(int(0.05 * SR), len(x) // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def rustle(rng, n, center, octaves=1.0):
    x = noise(rng, n, lambda f: band(f, center, octaves) * highpass(f, 300))
    return x / (np.max(np.abs(x)) + 1e-9)


def drip_plink(rng):
    # One drop on stone: a bright ping that falls a little in pitch, a tiny water click, sometimes a smaller second ring.
    out = np.zeros(int(0.5 * SR))
    f = rng.uniform(1300, 2300)
    add(out, ping(f, 0.09, 0.3) * 0.8, 0.0)
    add(out, ping(f * 1.5, 0.05, 0.2) * 0.3, 0.0)
    add(out, burst(rng, 0.012, 3500, 1.0) * 0.4, 0.0)

    if rng.random() < 0.5:
        add(out, ping(f * 0.8, 0.07, 0.2) * 0.25, 0.09)

    return finish(out, 0.6)


def drip_trickle(rng):
    # A soft stream down rock: filtered noise with a slow wobble, made seamless by blending the end into the start.
    n = int(4.0 * SR)
    x = rustle(rng, n + int(0.3 * SR), 2600, 1.6)
    wob = 0.75 + 0.25 * np.sin(np.linspace(0, 2 * np.pi * rng.uniform(5, 9), len(x)) + rng.uniform(0, 6))
    x = x * wob
    tail = x[n:]
    out = x[:n].copy()
    fade = np.linspace(0, 1, len(tail))
    out[:len(tail)] = out[:len(tail)] * fade + tail * (1 - fade)
    out = out - np.mean(out)
    return out * (0.35 / (np.max(np.abs(out)) + 1e-9))


def wet_step(rng):
    # One step on a wet floor: a soft thud, a short splash of noise and a low squelch.
    out = np.zeros(int(0.4 * SR))
    add(out, rustle(rng, int(0.12 * SR), 200, 0.8) * env(int(0.12 * SR), 0.01, 0.1) * 0.8, 0.0)
    add(out, rustle(rng, int(0.25 * SR), rng.uniform(1800, 3200), 1.5) * env(int(0.25 * SR), 0.02, 0.1) * 0.7, 0.01)

    for at in np.sort(rng.uniform(0.04, 0.2, 3)):
        add(out, burst(rng, 0.015, rng.uniform(2000, 4500), 1.0) * rng.uniform(0.15, 0.35), at)       # droplets

    return finish(out, 0.65)


def main():
    rng = np.random.default_rng(20261029)
    count = 0

    for name, make, n in (("drip_plink", drip_plink, 4), ("drip_trickle", drip_trickle, 2), ("wet_step", wet_step, 4)):
        for v in range(n):
            write_ogg("%s_%d" % (name, v), make(rng))
            count += 1

    print("Wrote %d wet-tunnel sounds to %s" % (count, OUT))


if __name__ == "__main__":
    main()
