#!/usr/bin/env python3
"""Paints the leaf card of the big-leaved herbs (comfrey, burdock, mugwort, belladonna, henbane; tree_builder.gd _leafy_herb). Kathreen, 3 Nov 2026.

Usage: python3 tools/make_leaf_herb.py [--out assets/trees/leaf_herb.png]

These herbs are shape "fern" in data/tables/flora.json, so they wore the palm frond card: even strips on a rib, which made
comfrey and burdock look like small combs. A real comfrey or burdock leaf is one large ovate blade with a heart-shaped base,
a pale midrib, curving side veins and a softly waved edge, and that is what this card paints.

Card layout (as _leaf_spray maps it through Acc.card): U runs across the leaf; V runs along it, with the tip at v = 0
(the top of the image) and the base at v = 1 (the bottom). The card is 0.68 as wide as it is long, so the blade is painted
nearly full width. Colours are near neutral because the game tints per species. Drawn 4x larger and averaged down.
Deterministic.
"""
import argparse
import math
import os
import random

from PIL import Image, ImageDraw

SS = 4
W, H = 256, 256


def outline(w, h, rng):
    """The blade outline: base at the bottom middle, tip at the top middle; heart-shaped base, widest at 40% from the base, waved edge."""
    cx = w / 2
    base_y = h * 0.97
    tip_y = h * 0.03
    pts_r = []
    n = 60
    for i in range(n + 1):
        t = i / n                       # 0 base, 1 tip
        y = base_y + (tip_y - base_y) * t
        width = math.sin(math.pi * (t ** 0.72)) ** 0.85      # widest about 40% up, drawn to a point at the tip
        lobe = 0.12 * math.exp(-((t - 0.03) / 0.06) ** 2)     # the heart-shaped lobes beside the stalk
        wave = 0.025 * math.sin(t * 38.0 + rng.uniform(0, 0.3))
        half = (w * 0.47) * min(1.0, width + lobe + wave)
        pts_r.append((cx + half, y))
    pts_l = [(2 * cx - x, y) for (x, y) in reversed(pts_r)]
    return [(cx, base_y - h * 0.035)] + pts_r + pts_l, cx, base_y, tip_y


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def paint(seed=11):
    rng = random.Random(seed)
    w, h = W * SS, H * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pts, cx, base_y, tip_y = outline(w, h, rng)
    base = (182, 188, 168, 255)
    draw.polygon(pts, fill=shade(base, 0.86))
    # Inner blade a touch lighter, leaving a darker rim at the edge.
    inner = [(cx + (x - cx) * 0.94, base_y + (y - base_y) * 0.97) for (x, y) in pts]
    draw.polygon(inner, fill=base)
    # Soft tonal patches across the blade (the surface is never one flat tone), kept inside the blade.
    patch_alpha = img.getchannel("A")
    patches = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(patches)
    for i in range(140):
        x = rng.uniform(w * 0.1, w * 0.9)
        y = rng.uniform(tip_y + h * 0.05, base_y - h * 0.05)
        r = rng.uniform(w * 0.02, w * 0.06)
        if img.getpixel((int(x), int(y)))[3] == 0:
            continue
        draw.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=shade(base, rng.uniform(0.96, 1.03)))
    img.alpha_composite(Image.composite(patches, Image.new("RGBA", (w, h), (0, 0, 0, 0)), patch_alpha))
    # Side veins: curving out and up from the midrib, alternate, fading toward the tip; drawn on their own layer and kept inside the blade.
    blade_alpha = img.getchannel("A")
    vein_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(vein_layer)
    veins = 9
    for side in (-1, 1):
        for i in range(veins):
            t = 0.08 + 0.8 * (i + (0.5 if side > 0 else 0.0)) / veins
            y0 = base_y + (tip_y - base_y) * t
            length = w * 0.44 * math.sin(math.pi * (t ** 0.72)) ** 0.85
            pts_v = []
            for k in range(12):
                f = k / 11
                pts_v.append((cx + side * length * f, y0 - length * (0.55 * f + 0.35 * f * f)))
            draw.line(pts_v, fill=shade(base, 1.12), width=max(1, int(SS * (1.6 - t))))
    clear = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    vein_layer = Image.composite(vein_layer, clear, blade_alpha)
    img.alpha_composite(vein_layer)
    draw = ImageDraw.Draw(img)
    # The midrib, broad and pale at the base, thinning to the tip, and the stalk below the blade.
    for i in range(40):
        t0, t1 = i / 40, (i + 1) / 40
        y0 = base_y + (tip_y - base_y) * t0
        y1 = base_y + (tip_y - base_y) * t1
        draw.line([(cx, y0), (cx, y1)], fill=shade(base, 1.18), width=max(SS, int(SS * (4.0 - 3.2 * t0))))
    draw.line([(cx, base_y - h * 0.02), (cx, h)], fill=shade(base, 1.05), width=SS * 4)
    return img.resize((W, H), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/trees/leaf_herb.png")
    args = ap.parse_args()
    img = paint()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    img.save(args.out)
    print("wrote", args.out, img.size)


if __name__ == "__main__":
    main()
