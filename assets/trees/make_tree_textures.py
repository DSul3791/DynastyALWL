"""Paints the tree textures (hand-painted style, made in code).

Run: python3 assets/trees/make_tree_textures.py
Writes leaf_broad.png, leaf_conifer.png, leaf_palm.png, bark.png, bark_birch.png
and twig_birch.png next to this file.
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


def birch_bark(name, size, seed):
    # Paper birch: chalk-white bark ringed with thin dark lenticel dashes, and
    # black wedge-shaped patches below old branch scars; fully opaque, tiles
    # both ways (owner's photos, 2026-10-18).
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    rgb = Image.new("RGB", (w, h), grey(236, 1.0))
    d = ImageDraw.Draw(rgb)

    def tiled(draw_fn):
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                draw_fn(dx, dy)

    # Faint cream and gray mottling, so the white is not flat.
    for n in range(70):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        rx, ry = rng.uniform(0.05, 0.2) * w, rng.uniform(0.01, 0.04) * h
        shade = rng.uniform(205, 248)
        tiled(lambda dx, dy: d.ellipse([x + dx - rx, y + dy - ry, x + dx + rx, y + dy + ry], fill=grey(shade, 1.0)))
    # Lenticels: thin horizontal dashes running around the trunk.
    for n in range(100):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        length = rng.uniform(0.04, 0.22) * w
        thick = max(2, int(rng.uniform(0.004, 0.011) * h))
        shade = rng.uniform(40, 110)
        tiled(lambda dx, dy: d.line([(x + dx, y + dy), (x + dx + length, y + dy + rng.uniform(-3, 3))], fill=grey(shade), width=thick))
    # Black patches: wide on top, tapering down, rough edged.
    for n in range(9):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        half = rng.uniform(0.07, 0.2) * w
        tall = rng.uniform(0.04, 0.1) * h
        pts = []
        for k in range(9):
            t = k / 8.0
            pts.append((x - half + 2 * half * t, y + rng.uniform(-0.15, 0.15) * tall))
        for k in range(6):
            t = k / 5.0
            pts.append((x + half * (1 - 2 * t) * 0.6, y + tall * (0.6 + 0.4 * math.sin(t * math.pi)) + rng.uniform(-0.2, 0.2) * tall))
        shade = rng.uniform(25, 55)
        tiled(lambda dx, dy: d.polygon([(px + dx, py + dy) for px, py in pts], fill=grey(shade)))
    alpha = Image.new("L", (w, h), 255)
    finish(rgb, alpha, name, size)


def twig_birch(name, size, seed):
    # A curtain of fine birch twigs hanging from the top edge, for bare winter
    # crowns: thin dark lines, branching and drooping; light neutral values so
    # the shader tint gives the twig color.
    rng = random.Random(seed)
    w, h = size[0] * SS, size[1] * SS
    rgb = Image.new("RGB", (w, h), grey(140))
    alpha = Image.new("L", (w, h), 0)
    rd, ad = ImageDraw.Draw(rgb), ImageDraw.Draw(alpha)

    def twig(x, y, ang, length, width, depth):
        steps = 6
        for s in range(steps):
            nx = x + math.sin(ang) * length / steps
            ny = y + math.cos(ang) * length / steps
            shade = rng.uniform(110, 170)
            rd.line([(x, y), (nx, ny)], fill=grey(shade), width=max(1, int(width)))
            ad.line([(x, y), (nx, ny)], fill=255, width=max(1, int(width)))
            x, y = nx, ny
            ang += rng.uniform(-0.12, 0.12) - ang * 0.08   # bend toward hanging straight down
            width *= 0.9
            if depth > 0 and rng.random() < 0.45:
                twig(x, y, ang + rng.choice((-1, 1)) * rng.uniform(0.3, 0.7), length * rng.uniform(0.35, 0.6), width * 0.8, depth - 1)

    for n in range(10):
        x0 = rng.uniform(0.05, 0.95) * w
        twig(x0, 0, rng.uniform(-0.35, 0.35), h * rng.uniform(0.6, 0.98), w * 0.008, 2)
    finish(rgb, alpha, name, size)


if __name__ == "__main__":
    broad("leaf_broad.png", (256, 256), 11)
    conifer("leaf_conifer.png", (256, 128), 5)
    palm("leaf_palm.png", (256, 128), 3)
    bark("bark.png", (128, 256), 2)
    birch_bark("bark_birch.png", (128, 256), 7)
    twig_birch("twig_birch.png", (256, 256), 9)
    print("wrote tree textures to", HERE)
