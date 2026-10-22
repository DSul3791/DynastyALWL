"""Makes placeholder item sounds for src/client/item_sounds.gd.

Run: python3 assets/audio/make_items.py   (needs numpy and ffmpeg)
Writes assets/audio/items/: item_pickup_N (a soft scoop and rustle), item_drop_N (a dull thud and
scatter), inv_open_N and inv_close_N (leather pouch flap, rising and falling), item_swap_N (a short
slide and tap) and craft_done_N (a bright wooden knock and a small chime). All short and quiet.
Recordings go in assets/audio/recorded/items/ under the same names; the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, env, highpass, lowpass, noise  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "items")
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


def burst(rng, dur, center, octaves, attack, decay, hp=200):
    m = int(dur * SR)
    x = noise(rng, m, lambda f: band(f, center, octaves) * highpass(f, hp)) * env(m, attack, decay)
    return x / (np.max(np.abs(x)) + 1e-9)


def thump(f, dur, decay):
    t = np.arange(int(dur * SR)) / SR
    return np.sin(2 * np.pi * f * t * (1.0 - 0.3 * t / dur)) * np.minimum(t / 0.002, 1.0) * np.exp(-t / decay)


def tone(f, dur, decay):
    t = np.arange(int(dur * SR)) / SR
    return (np.sin(2 * np.pi * f * t) + 0.2 * np.sin(4 * np.pi * f * t)) * np.minimum(t / 0.004, 1.0) * np.exp(-t / decay)


def finish(x, peak=0.6):
    fade = min(int(0.03 * SR), len(x) // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def pickup(rng):
    out = np.zeros(int(0.3 * SR))
    add(out, burst(rng, 0.12, rng.uniform(1800, 2600), 1.2, 0.02, 0.05) * 0.6, 0.0)
    add(out, burst(rng, 0.08, rng.uniform(900, 1300), 1.0, 0.003, 0.025) * 0.7, 0.07)
    return finish(out, 0.55)


def drop(rng):
    out = np.zeros(int(0.35 * SR))
    add(out, thump(rng.uniform(110, 160), 0.2, 0.05) * 0.9, 0.0)
    add(out, burst(rng, 0.1, 1400, 1.2, 0.001, 0.02) * 0.5, 0.0)
    add(out, burst(rng, 0.06, 2000, 1.0, 0.001, 0.015) * 0.3, rng.uniform(0.06, 0.12))
    return finish(out, 0.6)


def pouch(rng, opening):
    out = np.zeros(int(0.28 * SR))
    lo, hi = (900, 2200) if opening else (2200, 900)
    sweep = burst(rng, 0.2, (lo + hi) / 2, 1.6, 0.04, 0.09, 300)
    sweep *= np.linspace(0.4, 1.0, len(sweep)) if opening else np.linspace(1.0, 0.4, len(sweep))
    add(out, sweep * 0.7, 0.0)
    add(out, thump(rng.uniform(180, 240), 0.07, 0.02) * 0.4, 0.02 if opening else 0.15)
    return finish(out, 0.5)


def swap(rng):
    out = np.zeros(int(0.2 * SR))
    add(out, burst(rng, 0.09, 1600, 1.3, 0.02, 0.04) * 0.5, 0.0)
    add(out, thump(rng.uniform(220, 300), 0.06, 0.015) * 0.6, 0.08)
    return finish(out, 0.5)


def craft_done(rng):
    out = np.zeros(int(0.7 * SR))
    add(out, thump(rng.uniform(260, 340), 0.1, 0.025) * 0.9, 0.0)
    add(out, burst(rng, 0.05, 2400, 1.0, 0.001, 0.01) * 0.5, 0.0)
    f = rng.uniform(780, 880)
    add(out, tone(f, 0.45, 0.14) * 0.5, 0.12)
    add(out, tone(f * 1.5, 0.4, 0.12) * 0.35, 0.18)
    return finish(out, 0.55)


def hotbar_tick(rng):
    """Choosing a hotbar slot: one short dry wooden tick, quiet."""
    out = np.zeros(int(0.07 * SR))
    add(out, burst(rng, 0.05, rng.uniform(1700, 2300), 1.0, 0.001, 0.012) * 0.6, 0.0)
    add(out, thump(rng.uniform(300, 420), 0.04, 0.01) * 0.4, 0.0)
    return finish(out, 0.4)


def craft_start(rng):
    """Starting a craft: a soft two-part click, like setting the materials down."""
    out = np.zeros(int(0.16 * SR))
    add(out, burst(rng, 0.05, rng.uniform(1300, 1800), 1.1, 0.002, 0.015) * 0.6, 0.0)
    add(out, thump(rng.uniform(200, 280), 0.07, 0.02) * 0.5, 0.06)
    return finish(out, 0.45)


def main():
    rng = np.random.default_rng(20261026)
    rng_ui = np.random.default_rng(20261124)      # its own stream: the older item sounds stay as they were

    for v in range(VARIANTS):
        write_ogg("item_pickup_%d" % v, pickup(rng))
        write_ogg("item_drop_%d" % v, drop(rng))
        write_ogg("inv_open_%d" % v, pouch(rng, True))
        write_ogg("inv_close_%d" % v, pouch(rng, False))
        write_ogg("item_swap_%d" % v, swap(rng))
        write_ogg("craft_done_%d" % v, craft_done(rng))
        write_ogg("hotbar_tick_%d" % v, hotbar_tick(rng_ui))
        write_ogg("craft_start_%d" % v, craft_start(rng_ui))

    print("Wrote %d item sounds to %s" % (VARIANTS * 8, OUT))


if __name__ == "__main__":
    main()
