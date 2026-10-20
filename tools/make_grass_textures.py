#!/usr/bin/env python3
"""Generates the painted grass card textures (ART_DIRECTION.md step 3).

Usage: python3 tools/make_grass_textures.py [--out assets/grass]

ground_cover : blades splayed flat, seen from above (lies on the ground)
grass_short  : an upright tuft of fine blades, about 0.4 m
grass_tall   : taller blades with a few seed heads, about 0.75 m
The card is multiplied by a per-card green from the game, so the textures stay close to neutral:
dark at the root, lighter at the tip, each blade a little different. Drawn 4x larger and
averaged down for clean edges. Deterministic.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw

SS = 4


def blade(draw, w, h, x0, y0, length, lean, width, color, curve):
    """One tapered, curved blade from (x0, y0) upward; lean and curve in pixels."""
    n = 14
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        x = x0 + lean * t + curve * t * t
        y = y0 - length * t
        half = width * 0.5 * (1.0 - t) ** 0.8 + 0.4
        left.append((x - half, y))
        right.append((x + half, y))
    draw.polygon(left + right[::-1], fill=color)


def shaded_blade(img, w, h, x0, y0, length, lean, width, curve, base, tip, rng):
    """Draws a blade as short colour bands so the root is darker than the tip."""
    n = 10
    draw = ImageDraw.Draw(img)
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + lean * t + curve * t * t, y0 - length * t, t))
    for i in range(n):
        (xa, ya, ta), (xb, yb, tb) = pts[i], pts[i + 1]
        ha = width * 0.5 * (1.0 - ta) ** 0.8 + 0.4
        hb = width * 0.5 * (1.0 - tb) ** 0.8 + 0.4
        tm = (ta + tb) * 0.5
        col = tuple(int(base[c] + (tip[c] - base[c]) * (tm ** 0.8)) for c in range(3)) + (255,)
        draw.polygon([(xa - ha, ya), (xa + ha, ya), (xb + hb, yb), (xb - hb, yb)], fill=col)


def finish(img, size, path):
    # Average down with premultiplied colour, so the clear pixels do not darken the edges.
    a = np.asarray(img).astype(np.float32) / 255.0
    pre = Image.fromarray((np.dstack([a[..., :3] * a[..., 3:4], a[..., 3:4]]) * 255.0 + 0.5).astype(np.uint8), "RGBA")
    pre = np.asarray(pre.resize((size[0], size[1]), Image.BOX)).astype(np.float32) / 255.0
    alpha = pre[..., 3:4]
    rgb = np.where(alpha > 0.002, pre[..., :3] / np.maximum(alpha, 0.002), 0.0)
    out = np.dstack([np.clip(rgb, 0, 1), alpha])
    img = Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")
    img.save(path, optimize=True)
    print(path, img.size)


def tuft(size, count, min_len, max_len, rng, seeds=0, spread=0.55):
    w, h = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for _ in range(count):
        x0 = w * (0.5 + (rng.random() - 0.5) * spread)
        y0 = h * (0.985 + rng.random() * 0.01)
        length = h * (min_len + (max_len - min_len) * rng.random())
        lean = (x0 - w * 0.5) * (0.6 + rng.random() * 0.9) + (rng.random() - 0.5) * w * 0.12
        width = w * (0.022 + 0.02 * rng.random())
        curve = (rng.random() - 0.5) * w * 0.28 + math.copysign(w * 0.06, lean)
        v = 0.8 + 0.2 * rng.random()
        base = (int(95 * v), int(130 * v), int(60 * v))
        tip = (int(205 * v), int(235 * v), int(125 * v))
        shaded_blade(img, w, h, x0, y0, length, lean, width, curve, base, tip, rng)
    draw = ImageDraw.Draw(img)
    for _ in range(seeds):
        x0 = w * (0.5 + (rng.random() - 0.5) * spread * 0.8)
        y0 = h * 0.985
        length = h * (0.78 + 0.2 * rng.random())
        lean = (x0 - w * 0.5) * 0.5
        width = w * 0.012
        curve = (rng.random() - 0.5) * w * 0.1
        shaded_blade(img, w, h, x0, y0, length, lean, width, curve, (130, 140, 70), (190, 175, 95), rng)
        # the seed head: a small plume of short strokes at the top
        tx = x0 + lean + curve
        ty = y0 - length
        for k in range(14):
            a = (k / 13.0 - 0.5) * 0.9
            ln = h * (0.045 + 0.02 * rng.random())
            draw.line([(tx, ty + ln * 0.2), (tx + math.sin(a) * ln, ty - math.cos(a) * ln)], fill=(215, 190, 105, 255), width=int(SS * 1.3))
    return img


def cover(size, count, rng):
    """Blades fanning out from many roots over the whole card, as seen from above."""
    w, h = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for _ in range(count):
        cx, cy = rng.random() * w, rng.random() * h
        for _ in range(rng.integers(4, 8)):
            a = rng.random() * math.tau
            ln = w * (0.06 + 0.07 * rng.random())
            curve = (rng.random() - 0.5) * ln * 0.7
            v = 0.78 + 0.22 * rng.random()
            base = (int(110 * v), int(145 * v), int(70 * v))
            tip = (int(200 * v), int(232 * v), int(120 * v))
            n = 8
            pts = []
            for i in range(n + 1):
                t = i / n
                dx = math.cos(a) * ln * t - math.sin(a) * curve * t * t
                dy = math.sin(a) * ln * t + math.cos(a) * curve * t * t
                pts.append((cx + dx, cy + dy, t))
            for i in range(n):
                (xa, ya, ta), (xb, yb, tb) = pts[i], pts[i + 1]
                wa = w * 0.006 * (1.0 - ta) + 0.5
                wb = w * 0.006 * (1.0 - tb) + 0.5
                col = tuple(int(base[c] + (tip[c] - base[c]) * ((ta + tb) * 0.5)) for c in range(3)) + (255,)
                draw.line([(xa, ya), (xb, yb)], fill=col, width=max(1, int((wa + wb) * 0.6)))
    return img


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/grass")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(77)
    finish(cover((256, 256), 120, rng), (256, 256), os.path.join(args.out, "ground_cover.png"))
    finish(tuft((256, 256), 70, 0.45, 0.98, rng, spread=0.8), (256, 256), os.path.join(args.out, "grass_short.png"))
    finish(tuft((128, 256), 30, 0.5, 1.0, rng, seeds=5, spread=0.7), (128, 256), os.path.join(args.out, "grass_tall.png"))


if __name__ == "__main__":
    main()
