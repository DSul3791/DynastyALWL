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


CLASSES = ["wood", "stone", "metal", "cloth", "soft", "food", "glass", "bone"]


def class_sound(rng, cls, kind):
    """Placeholder pick-up and put-down sound for a material class (stage one: about eight classes cover every item)."""
    out = np.zeros(int(0.4 * SR))
    drop_k = kind == "drop"
    low = 0.6 if drop_k else 1.0

    if cls == "wood":
        add(out, thump(rng.uniform(260, 340) * low, 0.12, 0.03) * 0.9, 0.0)
        add(out, burst(rng, 0.08, rng.uniform(1200, 1800), 1.0, 0.001, 0.02) * 0.4, 0.01)
    elif cls == "stone":
        add(out, burst(rng, 0.05, rng.uniform(1800, 2600) * low, 1.0, 0.0005, 0.012) * 0.9, 0.0)
        add(out, thump(rng.uniform(150, 220), 0.1, 0.025) * 0.5, 0.0)
        add(out, burst(rng, 0.04, 3200, 1.0, 0.0005, 0.01) * 0.4, rng.uniform(0.05, 0.1))
    elif cls == "metal":
        add(out, tone(rng.uniform(2000, 2600) * low, 0.3, 0.09) * 0.8, 0.0)
        add(out, tone(rng.uniform(3600, 4300) * low, 0.2, 0.05) * 0.4, 0.0)
    elif cls == "cloth":
        add(out, burst(rng, 0.25, rng.uniform(2200, 3200), 1.5, 0.05, 0.1, 600) * 0.5, 0.0)

        if drop_k:
            add(out, thump(90, 0.12, 0.04) * 0.5, 0.0)
    elif cls == "soft":
        add(out, thump(rng.uniform(80, 120), 0.15, 0.04) * 0.8, 0.0)
        add(out, burst(rng, 0.15, rng.uniform(500, 800), 1.0, 0.01, 0.05, 100) * 0.5, 0.0)
    elif cls == "food":
        add(out, burst(rng, 0.1, rng.uniform(800, 1100), 1.0, 0.004, 0.03, 200) * 0.7, 0.0)
        add(out, thump(rng.uniform(100, 150), 0.08, 0.02) * 0.4, 0.0)
    elif cls == "glass":
        add(out, tone(rng.uniform(3200, 4200), 0.25, 0.06) * 0.6, 0.0)
        add(out, thump(rng.uniform(200, 260), 0.06, 0.015) * 0.4, 0.0)
    else:
        add(out, burst(rng, 0.04, rng.uniform(1200, 1700), 1.0, 0.0005, 0.01) * 0.9, 0.0)
        add(out, burst(rng, 0.03, 2500, 1.0, 0.0005, 0.008) * 0.4, 0.05)

    return finish(out, 0.5)


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

    rng_cls = np.random.default_rng(20261022)      # own stream again: nothing above changes

    for cls in CLASSES:
        for kind in ("pickup", "drop"):
            for v in range(VARIANTS):
                write_ogg("item_%s_%s_%d" % (kind, cls, v), class_sound(rng_cls, cls, kind))

    print("Wrote %d item sounds to %s" % (VARIANTS * 8 + len(CLASSES) * 2 * VARIANTS, OUT))


if __name__ == "__main__":
    main()
