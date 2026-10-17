"""Paints the three grass card textures (hand-painted style, made in code).

Run: python3 assets/grass/make_grass_textures.py
Writes grass_short.png, grass_tall.png and ground_cover.png next to this file.
Swap in real hand-painted art with the same names and sizes whenever it exists.
The card shader multiplies these by a per-clump green, so they are kept light.
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SS = 4  # supersampling


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def blade(rgb_d, a_d, w, h, x0, lean, width, height, rng, base_c, tip_c, steps=14):
    # A curved tapering blade from the bottom edge, painted in vertical bands.
    left, right = [], []
    for n in range(steps + 1):
        t = n / steps
        cx = x0 + lean * t * t * w
        y = h - 2 - t * height * h
        half = width * w * 0.5 * (1.0 - t) ** 0.75
        left.append((cx - half, y))
        right.append((cx + half, y))
    for n in range(steps):
        t = n / steps
        poly = [left[n], right[n], right[n + 1], left[n + 1]]
        shade = rng.uniform(-0.05, 0.05)
        col = lerp(base_c, tip_c, min(max(t + shade, 0), 1))
        rgb_d.polygon(poly, fill=col)
        a_d.polygon(poly, fill=255)
    # darker center vein, lighter on the right edge for a painted feel
    pts = [((l[0] + r[0]) / 2, l[1]) for l, r in zip(left, right)]
    rgb_d.line(pts, fill=lerp(base_c, (30, 60, 25), 0.35), width=max(1, int(w * 0.004)))


def finish(rgb, alpha, name, size):
    rgb = rgb.resize(size, Image.LANCZOS)
    alpha = alpha.resize(size, Image.LANCZOS)
    img = rgb.convert("RGBA")
    img.putalpha(alpha)
    img.save(os.path.join(HERE, name))


def clump(name, size, count, height_range, width, spread, seed, base_c, tip_c):
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    rgb = Image.new("RGB", (w, h), lerp(base_c, tip_c, 0.4))
    alpha = Image.new("L", (w, h), 0)
    rd, ad = ImageDraw.Draw(rgb), ImageDraw.Draw(alpha)
    blades = []
    for n in range(count):
        x0 = w * (0.5 + rng.uniform(-spread, spread))
        lean = rng.uniform(-0.3, 0.3) + (x0 / w - 0.5) * 0.6
        blades.append((rng.uniform(*height_range), x0, lean))
    for height, x0, lean in sorted(blades):
        blade(rd, ad, w, h, x0, lean, width * rng.uniform(0.8, 1.2), height, rng, base_c, tip_c)
    finish(rgb, alpha, name, size)


def cover(name, size, seed):
    # Ground cover: clover leaves (three round lobes), little rosette leaves and
    # a few short blades, all low and flat.
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    base_c, tip_c = (118, 168, 78), (188, 222, 120)
    rgb = Image.new("RGB", (w, h), base_c)
    alpha = Image.new("L", (w, h), 0)
    rd, ad = ImageDraw.Draw(rgb), ImageDraw.Draw(alpha)
    for n in range(26):
        cx = rng.uniform(0.1, 0.9) * w
        cy = h - rng.uniform(0.08, 0.5) * h
        r = rng.uniform(0.035, 0.055) * w
        ang = rng.uniform(0, math.tau)
        stem = rng.uniform(0.04, 0.12) * h
        rd.line([(cx, h), (cx, cy + stem)], fill=lerp(base_c, (40, 80, 30), 0.4), width=int(w * 0.006))
        ad.line([(cx, h), (cx, cy + stem)], fill=255, width=int(w * 0.006))
        for k in range(3):
            a = ang + k * math.tau / 3
            lx, ly = cx + math.cos(a) * r * 0.8, cy + stem * 0.0 + math.sin(a) * r * 0.8
            col = lerp(base_c, tip_c, rng.uniform(0.2, 0.9))
            box = [lx - r * 0.75, ly - r * 0.75, lx + r * 0.75, ly + r * 0.75]
            rd.ellipse(box, fill=col)
            ad.ellipse(box, fill=255)
            rd.ellipse([lx - r * 0.45, ly - r * 0.15, lx + r * 0.45, ly + r * 0.15], fill=lerp(col, (235, 240, 215), 0.45))
    for n in range(8):
        blade(rd, ad, w, h, rng.uniform(0.1, 0.9) * w, rng.uniform(-0.2, 0.2), 0.05, rng.uniform(0.2, 0.45), rng, base_c, tip_c)
    finish(rgb, alpha, name, size)


if __name__ == "__main__":
    clump("grass_short.png", (256, 256), 11, (0.55, 0.95), 0.07, 0.22, 3, (84, 130, 54), (186, 218, 112))
    clump("grass_tall.png", (128, 256), 7, (0.7, 1.0), 0.09, 0.2, 5, (96, 138, 62), (200, 220, 128))
    cover("ground_cover.png", (256, 128), 9)
    print("wrote grass textures to", HERE)
