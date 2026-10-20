#!/usr/bin/env python3
"""Generates the forest-floor leaf litter card (ART_DIRECTION.md section 24).

Usage: python3 tools/make_litter_texture.py [--out assets/grass/litter.png]

One 256 px card lying on the ground: a scatter of fallen leaves and needle clumps in muted browns,
ochres and a few dull reds, each with a darker vein and a slightly curled edge. Kept close to
neutral warm brown; the game tints it per card. Drawn 4x larger and averaged down. Deterministic.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw

SS = 4
SIZE = 256


def leaf(draw, cx, cy, length, width, angle, color, vein):
    pts = []
    n = 16
    for i in range(n + 1):
        t = i / n
        w = width * 0.5 * math.sin(math.pi * t) ** 0.8
        pts.append((t * length - length * 0.5, w))
    for i in range(n, -1, -1):
        t = i / n
        w = width * 0.5 * math.sin(math.pi * t) ** 0.8
        pts.append((t * length - length * 0.5, -w))
    ca, sa = math.cos(angle), math.sin(angle)
    poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    draw.polygon(poly, fill=color)
    x0, y0 = cx - length * 0.5 * ca, cy - length * 0.5 * sa
    x1, y1 = cx + length * 0.5 * ca, cy + length * 0.5 * sa
    draw.line([(x0, y0), (x1, y1)], fill=vein, width=max(1, int(width * 0.06)))


def needles(draw, cx, cy, rng, color):
    for _ in range(18):
        a = rng.uniform(0, math.tau)
        l = rng.uniform(14, 26) * SS
        x = cx + rng.uniform(-10, 10) * SS
        y = cy + rng.uniform(-10, 10) * SS
        c = tuple(int(v * rng.uniform(0.8, 1.1)) for v in color) + (255,)
        draw.line([(x, y), (x + math.cos(a) * l, y + math.sin(a) * l)], fill=c, width=SS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/grass/litter.png")
    args = ap.parse_args()
    rng = np.random.default_rng(5)
    palette = [(112, 82, 48), (132, 98, 52), (96, 70, 42), (146, 108, 56), (122, 62, 40), (84, 66, 40), (156, 124, 68)]
    big = SIZE * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for _ in range(70):
        cx, cy = rng.uniform(0, big), rng.uniform(0, big)
        length = rng.uniform(22, 44) * SS
        width = length * rng.uniform(0.38, 0.6)
        base = palette[int(rng.integers(len(palette)))]
        shade = rng.uniform(0.8, 1.1)
        color = tuple(int(min(255, v * shade)) for v in base) + (255,)
        vein = tuple(int(v * 0.6) for v in base) + (255,)
        leaf(draw, cx, cy, length, width, rng.uniform(0, math.tau), color, vein)
    for _ in range(6):
        needles(draw, rng.uniform(0, big), rng.uniform(0, big), rng, (104, 74, 42))
    a = np.asarray(img).astype(np.float32) / 255.0
    pre = np.dstack([a[..., :3] * a[..., 3:4], a[..., 3:4]])
    small = np.asarray(Image.fromarray((pre * 255 + 0.5).astype(np.uint8), "RGBA").resize((SIZE, SIZE), Image.BOX)).astype(np.float32) / 255.0
    alpha = small[..., 3:4]
    rgb = np.where(alpha > 0.002, small[..., :3] / np.maximum(alpha, 0.002), 0.0)
    out = np.dstack([rgb, alpha])
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(args.out)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
