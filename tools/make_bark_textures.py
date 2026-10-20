#!/usr/bin/env python3
"""Generates the bark textures (ART_DIRECTION.md step 4): assets/trees/bark.png (rough, furrowed)
and bark_smooth.png (smooth with mottling). RGB is the colour, A the height (the bark shader
turns the height into a bump and darkens the furrows). 128 by 256, seamless in both directions.
Usage: python3 tools/make_bark_textures.py [--out assets/trees]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_ground_textures import fbm, normalize  # noqa: E402


def furrowed(w, h, rng):
    # Long thin ridges running up the trunk: noise stretched along it (many columns, few rows),
    # folded into ridges, with a slow sideways wobble and a few breaks across.
    size = max(w, h)
    ridge = 1.0 - np.abs(2.0 * fbm(size, 20, 2, rng, aspect=0.07)[:h, :w] - 1.0)
    fine = fbm(size, 46, 2, rng, aspect=0.1)[:h, :w]
    wobble = fbm(size, 5, 3, rng)[:h, :w]
    cross = np.clip(fbm(size, 14, 2, rng, aspect=1.4)[:h, :w] - 0.58, 0, 1) * 2.5
    height = normalize(0.55 * ridge + 0.3 * fine + 0.15 * wobble - 0.12 * cross)
    tone = 0.38 + 0.5 * height           # near neutral: the game multiplies by the species colour
    return np.dstack([tone, tone * 0.98, tone * 0.95]), 0.15 + 0.7 * height


def smooth_bark(w, h, rng):
    size = max(w, h)
    blotch = fbm(size, 5, 4, rng)[:h, :w]
    fine = fbm(size, 40, 2, rng, aspect=0.7)[:h, :w]
    height = normalize(0.3 * blotch + 0.7 * fine)
    tone = 0.62 + 0.3 * (blotch - 0.5) + 0.08 * (fine - 0.5)
    tone = np.clip(tone + 0.1, 0, 1)
    return np.dstack([tone, tone, tone]), height


def save(rgb, height, path):
    out = np.dstack([np.clip(rgb, 0, 1), height])
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)
    print(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/trees")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(31)
    rgb, h = furrowed(128, 256, rng)
    save(rgb, h, os.path.join(args.out, "bark.png"))
    rgb, h = smooth_bark(128, 256, rng)
    save(rgb, h, os.path.join(args.out, "bark_smooth.png"))


if __name__ == "__main__":
    main()
