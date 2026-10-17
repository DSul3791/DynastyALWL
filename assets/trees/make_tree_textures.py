"""Paints the tree textures (hand-painted style, made in code).

Run: python3 assets/trees/make_tree_textures.py
Writes leaf_broad.png, leaf_conifer.png, leaf_palm.png and bark.png next to this file.
Foliage and bark are painted in light neutral values; the tree shader multiplies
them by a per-tree color (autumn leaf color, species green, bark brown).
Replace with real hand-painted art under the same names and sizes any time.
"""
import math
import os
import random
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SS = 4


def finish(rgb, alpha, name, size, wrap=False):
    rgb = rgb.resize(size, Image.LANCZOS)
    alpha = alpha.resize(size, Image.LANCZOS)
    img = rgb.convert("RGBA")
    img.putalpha(alpha)
    img.save(os.path.join(HERE, name))


def grey(v, warm=0.0):
    v = max(0, min(255, int(v)))
    return (v, int(v * (0.98 + 0.02 * warm)), int(v * (0.92 + 0.06 * (1 - warm))))


def leaf(rd, ad, cx, cy, length, width, angle, shade):
    # A pointed leaf with a darker midrib and a lighter edge.
    pts = []
    n = 10
    for i in range(n + 1):
        t = i / n
        w = math.sin(t * math.pi) ** 0.8 * width * 0.5
        pts.append((t * length, -w))
    for i in range(n, -1, -1):
        t = i / n
        w = math.sin(t * math.pi) ** 0.8 * width * 0.5
        pts.append((t * length, w))
    ca, sa = math.cos(angle), math.sin(angle)
    poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    rd.polygon(poly, fill=grey(shade))
    ad.polygon(poly, fill=255)
    mid = [(cx + x * ca, cy + x * sa) for x in (0, length)]
    rd.line(mid, fill=grey(shade * 0.72), width=max(1, int(width * 0.06)))
    # light upper half
    half = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts[: n + 1]]
    rd.line(half, fill=grey(min(shade * 1.18, 255)), width=max(1, int(width * 0.05)))


def broad(name, size, seed):
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    rgb = Image.new("RGB", (w, h), grey(150))
    alpha = Image.new("L", (w, h), 0)
    rd, ad = ImageDraw.Draw(rgb), ImageDraw.Draw(alpha)
    for n in range(300):
        # Denser toward the middle so the card reads as a leafy clump.
        r = rng.random() ** 0.55 * 0.46
        a = rng.uniform(0, math.tau)
        cx, cy = w * (0.5 + r * math.cos(a)), h * (0.5 + r * math.sin(a))
        length = w * rng.uniform(0.11, 0.18)
        width = length * rng.uniform(0.42, 0.6)
        angle = rng.uniform(0, math.tau)
        shade = rng.uniform(120, 235) * (1.0 - 0.3 * r)
        leaf(rd, ad, cx - math.cos(angle) * length / 2, cy - math.sin(angle) * length / 2, length, width, angle, shade)
    finish(rgb, alpha, name, size)


def conifer(name, size, seed):
    # A fir bough: a stem across the card with layered needle fronds.
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    rgb = Image.new("RGB", (w, h), grey(140))
    alpha = Image.new("L", (w, h), 0)
    rd, ad = ImageDraw.Draw(rgb), ImageDraw.Draw(alpha)
    stem_y = h * 0.5
    for side in (-1, 1):
        for k in range(36):
            t = k / 35.0
            x = w * (0.04 + 0.92 * t)
            length = h * 0.5 * (1.0 - 0.55 * abs(t - 0.5) * 2.0) * rng.uniform(0.8, 1.05)
            for j in range(4):
                spread = 0.55 + 0.25 * j
                ang = side * (math.pi / 2 - spread * 0.5 + rng.uniform(-0.1, 0.1)) 
                ex = x + math.sin(ang) * length * 0.35 * (j + 1) * 0.5
                ey = stem_y + side * length * (0.45 + 0.18 * j) * math.cos(0.3)
                shade = rng.uniform(110, 225) * (0.75 + 0.25 * (1 - abs(side) * 0.3))
                rd.line([(x, stem_y), (ex, ey)], fill=grey(shade), width=int(w * 0.026))
                ad.line([(x, stem_y), (ex, ey)], fill=255, width=int(w * 0.026))
    rd.line([(0, stem_y), (w, stem_y)], fill=grey(90), width=int(h * 0.012))
    ad.line([(0, stem_y), (w, stem_y)], fill=255, width=int(h * 0.012))
    finish(rgb, alpha, name, size)


def palm(name, size, seed):
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    rgb = Image.new("RGB", (w, h), grey(140))
    alpha = Image.new("L", (w, h), 0)
    rd, ad = ImageDraw.Draw(rgb), ImageDraw.Draw(alpha)
    my = h * 0.5
    rd.line([(0, my), (w, my)], fill=grey(90), width=int(h * 0.016))
    ad.line([(0, my), (w, my)], fill=255, width=int(h * 0.016))
    for k in range(22):
        t = k / 21.0
        x = w * (0.03 + 0.94 * t)
        length = h * 0.46 * math.sin(math.pi * (0.12 + 0.82 * t)) 
        for side in (-1, 1):
            ex = x + w * 0.05
            ey = my + side * length
            shade = rng.uniform(130, 230)
            rd.line([(x, my), (ex, ey)], fill=grey(shade), width=int(w * 0.016))
            ad.line([(x, my), (ex, ey)], fill=255, width=int(w * 0.016))
    finish(rgb, alpha, name, size)


def bark(name, size, seed):
    # Vertical bark ridges; fully opaque; tiles vertically (ridges wrap).
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    rgb = Image.new("RGB", (w, h), grey(150))
    d = ImageDraw.Draw(rgb)
    for n in range(46):
        x = rng.uniform(0, w)
        y0 = rng.uniform(0, h)
        length = rng.uniform(0.2, 0.7) * h
        width = rng.uniform(0.012, 0.04) * w
        shade = rng.uniform(115, 190)
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                x0 = x + dx + math.sin(y0 * 0.01) * 6
                d.line([(x0, y0 + dy), (x0 + rng.uniform(-6, 6), y0 + dy + length)], fill=grey(shade), width=int(width))
    alpha = Image.new("L", (w, h), 255)
    finish(rgb, alpha, name, size)


if __name__ == "__main__":
    broad("leaf_broad.png", (256, 256), 11)
    conifer("leaf_conifer.png", (256, 128), 5)
    palm("leaf_palm.png", (256, 128), 3)
    bark("bark.png", (128, 256), 2)
    print("wrote tree textures to", HERE)
