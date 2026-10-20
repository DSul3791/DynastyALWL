"""Makes placeholder tool hit sounds for src/client/hit_sounds.gd.

Run: python3 assets/audio/make_hits.py   (needs numpy and ffmpeg)
Writes assets/audio/hits/hit_<tool>_<material>_N.ogg for tools axe, pick, hammer and spade on
wood, stone and soil, 3 variants each. Recordings go in assets/audio/recorded/hits/ under the
same names (hit_axe_wood_0.ogg ...); the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import SR, add, band, burst, env, freqs, grains, highpass, lowpass, noise, shape, thump  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hits")
VARIANTS = 3

# tool: body weight (longer, lower thud), sharpness (crack on contact), ring (metal on stone), scrape
TOOLS = {
    "axe": {"weight": 1.0, "sharp": 0.8, "ring": 0.35, "scrape": 0.0, "pitch": 1.0},
    "pick": {"weight": 0.9, "sharp": 1.0, "ring": 0.8, "scrape": 0.0, "pitch": 1.1},
    "hammer": {"weight": 1.3, "sharp": 0.45, "ring": 1.0, "scrape": 0.0, "pitch": 0.9},
    "spade": {"weight": 0.8, "sharp": 0.3, "ring": 0.2, "scrape": 1.0, "pitch": 0.85},
}
# material: body pitch, thud decay, crack centre, ring share, crumble grains
MATERIALS = {
    "wood": {"f0": 150.0, "decay": 0.07, "crack": 1500.0, "ring": 0.0, "crumble": 0, "hollow": 1.0},
    "stone": {"f0": 230.0, "decay": 0.04, "crack": 3200.0, "ring": 1.0, "crumble": 6, "hollow": 0.0},
    "soil": {"f0": 85.0, "decay": 0.08, "crack": 900.0, "ring": 0.0, "crumble": 14, "hollow": 0.0},
}


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
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def finish(x, peak=0.85):
    x = x - np.mean(x)
    n = len(x)
    x = shape(x, lowpass(freqs(n), 8000, 1))
    rise = min(int(0.001 * SR), n // 4)
    x[:rise] *= np.linspace(0, 1, rise)
    fade = min(int(0.06 * SR), n // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def hit(rng, tool, material):
    t = TOOLS[tool]
    m = MATERIALS[material]
    n = int(0.7 * SR)
    out = np.zeros(n)
    f0 = m["f0"] * t["pitch"] * rng.uniform(0.95, 1.05)
    add(out, thump(rng, 0.3, f0, m["decay"] * t["weight"], 1200.0 if material != "stone" else 2500.0) * 1.0, 0.0)
    cn = int(0.05 * SR)
    crack = noise(rng, cn, lambda f: band(f, m["crack"] * t["sharp"] ** 0.5, 0.9)) * env(cn, 0.0005, 0.007 + 0.006 * (1.0 - t["sharp"]))
    add(out, crack / (np.max(np.abs(crack)) + 1e-9) * (0.4 + 0.6 * t["sharp"]), 0.0)

    if m["hollow"]:                                                   # wood rings hollow
        hn = int(0.25 * SR)
        hollow = noise(rng, hn, lambda f: band(f, rng.uniform(450, 700), 0.35)) * env(hn, 0.002, 0.07)
        add(out, hollow / (np.max(np.abs(hollow)) + 1e-9) * 0.7, 0.0)

    if m["ring"] and t["ring"]:                                       # steel on stone rings
        base = rng.uniform(1800, 2600) * (1.0 if tool != "hammer" else 0.8)
        tt = np.arange(int(0.4 * SR)) / SR
        ring = sum(np.sin(2 * np.pi * base * k * tt) * np.exp(-tt / d) * a for k, d, a in ((1.0, 0.1, 1.0), (1.51, 0.06, 0.6), (2.23, 0.035, 0.4)))
        add(out, ring * 0.28 * t["ring"], 0.0)

    if m["crumble"]:
        add(out, grains(rng, n, m["crumble"], 0.04, 0.35, lambda: burst(rng, rng.uniform(0.006, 0.02), rng.uniform(900, 2200), 0.7)) * (0.7 if material == "soil" else 0.5), 0.0)

    if t["scrape"]:                                                   # the spade drags after it strikes
        sn = int(0.3 * SR)
        scrape = noise(rng, sn, lambda f: band(f, 1900 if material == "stone" else 1100, 0.8)) * (np.minimum(np.arange(sn) / SR / 0.05, 1.0) * np.exp(-np.arange(sn) / SR / 0.12))
        add(out, scrape / (np.max(np.abs(scrape)) + 1e-9) * (0.5 if material == "stone" else 0.35), 0.06)

    return finish(out)


def main():
    rng = np.random.default_rng(20261020)
    made = 0
    for tool in TOOLS:
        for material in MATERIALS:
            for v in range(VARIANTS):
                write_ogg("hit_%s_%s_%d" % (tool, material, v), hit(rng, tool, material))
                made += 1
    print("Wrote %d tool hit sounds to %s" % (made, OUT))


if __name__ == "__main__":
    main()
