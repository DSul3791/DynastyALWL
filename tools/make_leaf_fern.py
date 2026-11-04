#!/usr/bin/env python3
"""Paints the frond card of the ground ferns (fern, hushfern, whisperfern; tree_builder.gd _fern_rosette). Kathreen, 3 Nov 2026.

Usage: python3 tools/make_leaf_fern.py [--out assets/trees/leaf_fern.png]

The ferns used to wear leaf_palm.png: straight strips of the same width on a stiff rib, which read as a comb in the
game (art/CRITIQUES/dynasty_base_male_2026-11-01/game/right_walk4.png). Dave's art direction (art/Art_Direction.md)
asks for nature that looks formed, not arranged, so this card follows a real bracken or male fern frond:
  - a bare stipe at the base;
  - pinnae that grow to the widest point at about a third of the length, then taper to a pointed tip;
  - each pinna swept forward and curved, cut into rounded pinnules that shrink toward its tip;
  - pinnae alternate on the rachis instead of sitting in mirrored pairs.

Card layout (as _frond maps it): U runs along the frond, base at u = 0 and tip at u = 1; V runs across it, with the
rachis at v = 0.5. Colours are near neutral, like leaf_palm.png, because the game tints the card per species.
Drawn 4x larger and averaged down. Deterministic.
"""
import argparse
import math
import os
import random

from PIL import Image, ImageDraw

SS = 4
W, H = 512, 256


def envelope(t):
    """Pinna length share along the frond (0 at the stipe and the tip, 1 at the widest point)."""
    if t < 0.1:
        return 0.0
    if t < 0.34:
        x = (t - 0.1) / 0.24
        return 0.35 + 0.65 * (x * x * (3 - 2 * x))
    x = (t - 0.34) / 0.66
    return max(0.0, 1.0 - x ** 1.35)


def shade(base, k):
    return tuple(max(0, min(255, int(c * k))) for c in base)


def width0_of(length):
    return max(2.0 * SS, length * 0.075)


def pinna(draw, rng, x0, y0, side, length, tilt, base_col):
    """One pinna from the rachis point (x0, y0) toward `side` (+1 down, -1 up), swept toward the tip by `tilt` radians from straight across."""
    n = max(3, int(length / (width0_of(length) * 0.92)))
    pts = []
    for i in range(n + 1):
        f = i / n
        a = tilt + 0.35 * f * f          # curves further toward the tip near its end
        pts.append((x0 + math.sin(a) * length * f, y0 + side * math.cos(a) * length * f, f))
    k = rng.uniform(0.9, 1.08)
    col = shade(base_col, k)
    edge = shade(col, 0.82)
    # Pinnules: rounded lobes on both sides of the pinna midrib, alternating, shrinking to the tip.
    width0 = width0_of(length)
    for i in range(n):
        x, y, f = pts[i]
        x1, y1, _ = pts[i + 1]
        r = width0 * (1.0 - 0.75 * f) * rng.uniform(0.9, 1.1)
        dx, dy = x1 - x, y1 - y
        seg = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / seg, dx / seg
        for s in (1, -1):
            off = 0.5 if s > 0 else 0.0
            cx = x + dx * off + nx * s * r * 0.55
            cy = y + dy * off + ny * s * r * 0.55
            rx, ry = r * 0.8, r * 0.55
            draw.ellipse([cx - rx - 1, cy - ry - 1, cx + rx + 1, cy + ry + 1], fill=edge)
            draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=shade(col, rng.uniform(0.95, 1.06)))
    tx, ty, _ = pts[-1]
    tr = width0 * 0.3
    draw.ellipse([tx - tr, ty - tr, tx + tr, ty + tr], fill=col)
    # The pinna midrib: a thin lighter line.
    draw.line([(p[0], p[1]) for p in pts], fill=shade(col, 1.18), width=max(1, SS))


def paint(seed=7):
    rng = random.Random(seed)
    w, h = W * SS, H * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mid = h / 2
    max_len = h * 0.47
    base_col = (190, 194, 176, 255)       # near neutral with a little green: the species tint does the colour
    count = 15
    for side in (-1, 1):
        for i in range(count):
            t = 0.1 + 0.87 * (i + (0.5 if side > 0 else 0.0)) / count
            env = envelope(t)
            if env <= 0.02:
                continue
            length = max_len * env * rng.uniform(0.93, 1.05)
            tilt = math.radians(rng.uniform(28, 38) + 18 * t)      # swept toward the tip, more so near it
            # Lighter toward the tip (young growth), darker near the base.
            pinna(draw, rng, t * w, mid, side, length, tilt, shade(base_col, 0.86 + 0.22 * t))
    # Rachis: from the stipe to the tip, thicker at the base.
    steps = 60
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        width = int(SS * (3.2 - 2.2 * t0))
        draw.line([(t0 * w * 0.985, mid), (t1 * w * 0.985, mid)], fill=(150, 150, 118, 255), width=max(SS, width))
    return img.resize((W, H), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/trees/leaf_fern.png")
    args = ap.parse_args()
    img = paint()
    # Hard alpha (the shader discards below 0.5): keep the soft edge colour but snap coverage, so mip-less cards do not fringe.
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
