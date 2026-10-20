#!/usr/bin/env python3
"""Generates the fern card used at waterfall bases (ART_DIRECTION.md section 25).

Usage: python3 tools/make_fern_texture.py [--out assets/grass/fern.png]

An upright card (root at the bottom centre, UV y 1 at the root): a fan of arching fronds, each with
paired tapered leaflets. Close to neutral green, darker at the root and lighter at the tips; the
game tints it per card. Drawn 4x larger and averaged down. Deterministic.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw

SS = 4
W, H = 256, 192


def frond(draw, x0, y0, length, angle, droop, rng):
    n = 28
    pts = []
    a = angle
    x, y = x0, y0
    step = length / n
    for i in range(n + 1):
        pts.append((x, y, i / n, a))
        x += math.sin(a) * step
        y -= math.cos(a) * step
        a += droop
    # rachis
    draw.line([(p[0], p[1]) for p in pts], fill=(60, 96, 44, 255), width=2 * SS)
    for x, y, t, a in pts[3:]:
        size = length * 0.13 * math.sin(math.pi * min(1.0, t * 1.1)) ** 0.7 + length * 0.02
        shade = int(70 + 110 * t)
        col = (int(shade * 0.62), int(shade * 1.05 + 20), int(shade * 0.42), 255)
        for side in (-1, 1):
            la = a + side * 1.15
            ex, ey = x + math.sin(la) * size, y - math.cos(la) * size
            nx, ny = -math.cos(la), -math.sin(la)
            half = size * 0.17
            draw.polygon([(x, y), (x + (ex - x) * 0.5 + nx * half, y + (ey - y) * 0.5 + ny * half), (ex, ey), (x + (ex - x) * 0.5 - nx * half, y + (ey - y) * 0.5 - ny * half)], fill=col)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/grass/fern.png")
    args = ap.parse_args()
    rng = np.random.default_rng(9)
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    x0, y0 = W * SS * 0.5, H * SS - 4 * SS
    for angle in (-1.25, -0.8, -0.4, 0.0, 0.4, 0.8, 1.25):
        frond(draw, x0, y0, H * SS * (0.78 if abs(angle) < 0.5 else 0.62), angle, math.copysign(0.028 * min(1.0, abs(angle) * 1.6), angle), rng)
    a = np.asarray(img).astype(np.float32) / 255.0
    pre = np.dstack([a[..., :3] * a[..., 3:4], a[..., 3:4]])
    small = np.asarray(Image.fromarray((pre * 255 + 0.5).astype(np.uint8), "RGBA").resize((W, H), Image.BOX)).astype(np.float32) / 255.0
    alpha = small[..., 3:4]
    rgb = np.where(alpha > 0.002, small[..., :3] / np.maximum(alpha, 0.002), 0.0)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    Image.fromarray((np.dstack([rgb, alpha]) * 255 + 0.5).astype(np.uint8), "RGBA").save(args.out)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
