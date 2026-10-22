#!/usr/bin/env python3
"""Generates the tileable ground detail textures (ART_DIRECTION.md step 2).

Usage: python3 tools/make_ground_textures.py [--size 512] [--out assets/ground] [--sheet PATH]

One PNG per layer, RGBA8, seamless in both directions:
  R = detail brightness (0.5 is neutral, the shader multiplies the soil colour by it)
  G, B = surface normal x and y (0.5 is flat)
  A = height (used to blend materials and for the bump)
Layers: 0 turf, 1 forest litter, 2 gravel, 3 mud and clay, 4 sand, 5 rock.
Deterministic (fixed seeds), so a rebuild gives the same files.
"""
import argparse
import os

import numpy as np
from PIL import Image

NAMES = ["turf", "litter", "gravel", "mud", "sand", "rock"]


def smooth(t):
    return t * t * (3.0 - 2.0 * t)


def pnoise(size, cx, cy, rng):
    """Periodic value noise with cx by cy lattice cells, values 0..1."""
    grid = rng.random((cy, cx))
    ys = np.arange(size) * cy / size
    xs = np.arange(size) * cx / size
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = smooth(ys - y0)[:, None]
    fx = smooth(xs - x0)[None, :]
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    a = grid[np.ix_(y0 % cy, x0 % cx)]
    b = grid[np.ix_(y0 % cy, x1)]
    c = grid[np.ix_(y1, x0 % cx)]
    d = grid[np.ix_(y1, x1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, cells, octaves, rng, aspect=1.0, gain=0.5):
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        cx = max(2, int(cells * (2 ** o)))
        cy = max(2, int(cells * (2 ** o) * aspect))
        total += amp * pnoise(size, cx, cy, rng)
        norm += amp
        amp *= gain
    return total / norm


def voronoi(size, cells, rng, warp=0.0):
    """Periodic Voronoi: returns F1, F2 (in cell units) and the id of the nearest point.
    warp bends the cell borders so blocks and stones are not regular."""
    pts = rng.random((cells, cells, 2))
    ids = rng.random((cells, cells))
    ys, xs = np.mgrid[0:size, 0:size] / size * cells
    if warp > 0.0:
        ys = ys + (fbm(size, 6, 3, rng) - 0.5) * 2.0 * warp * cells / 5.0
        xs = xs + (fbm(size, 6, 3, rng) - 0.5) * 2.0 * warp * cells / 5.0
    ys = ys % cells
    xs = xs % cells
    cy = np.floor(ys).astype(int)
    cx = np.floor(xs).astype(int)
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    nid = np.zeros((size, size))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ny = (cy + dy) % cells
            nx = (cx + dx) % cells
            py = cy + dy + pts[ny, nx, 0]
            px = cx + dx + pts[ny, nx, 1]
            d = np.sqrt((py - ys) ** 2 + (px - xs) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            nid = np.where(closer, ids[ny, nx], nid)
            f1 = np.where(closer, d, f1)
    return f1, f2, nid


def stamp_lines(img, rng, count, length, width, value, mode, angle_spread=None, base_angle=0.0):
    """Draws wrapped line segments (needles, sticks) onto img; mode 'set' or 'max'."""
    size = img.shape[0]
    for _ in range(count):
        cx, cy = rng.random(2) * size
        ang = base_angle + (rng.random() - 0.5) * angle_spread if angle_spread is not None else rng.random() * np.pi
        ln = length * (0.6 + 0.8 * rng.random())
        v = value * (0.7 + 0.6 * rng.random())
        for t in np.linspace(-0.5, 0.5, int(ln) + 1):
            for w in np.linspace(-width / 2, width / 2, max(2, int(width) + 1)):
                x = int(round(cx + np.cos(ang) * t * ln - np.sin(ang) * w)) % size
                y = int(round(cy + np.sin(ang) * t * ln + np.cos(ang) * w)) % size
                if mode == "max":
                    img[y, x] = max(img[y, x], v)
                else:
                    img[y, x] = v


def stamp_blobs(img, rng, count, radius, value):
    """Leaf-sized soft ellipses, wrapped."""
    size = img.shape[0]
    for _ in range(count):
        cx, cy = rng.random(2) * size
        r = radius * (0.6 + 0.8 * rng.random())
        ang = rng.random() * np.pi
        ca, sa = np.cos(ang), np.sin(ang)
        ext = int(r * 2) + 2
        v = value * (0.7 + 0.6 * rng.random())
        for oy in range(-ext, ext + 1):
            for ox in range(-ext, ext + 1):
                u = (ox * ca + oy * sa) / (r * 1.8)
                w = (-ox * sa + oy * ca) / (r * 0.8)
                d = u * u + w * w
                if d < 1.0:
                    x = int(cx + ox) % size
                    y = int(cy + oy) % size
                    img[y, x] = max(img[y, x], v * (1.0 - d * 0.4))


def blur(img, passes=1):
    for _ in range(passes):
        img = (img * 4 + np.roll(img, 1, 0) + np.roll(img, -1, 0) + np.roll(img, 1, 1) + np.roll(img, -1, 1)) / 8.0
    return img


def normalize(a, lo=0.02, hi=0.98):
    a = a - np.percentile(a, 1)
    a = a / max(np.percentile(a, 99), 1e-6)
    return np.clip(a, 0.0, 1.0) * (hi - lo) + lo


def layer_turf(size, rng):
    crumbs = fbm(size, 40, 4, rng, gain=0.55)
    streaks = fbm(size, 90, 2, rng, aspect=0.12)          # fine vertical streaks like root mat
    patches = fbm(size, 5, 3, rng)
    height = normalize(0.55 * crumbs + 0.35 * streaks + 0.1 * patches)
    detail = normalize(0.45 * crumbs + 0.4 * streaks + 0.25 * patches)
    return detail, height, 1.2


def layer_litter(size, rng):
    base = fbm(size, 24, 4, rng)
    litter = np.zeros((size, size))
    stamp_blobs(litter, rng, int(size * 0.3), size / 36.0, 0.55)              # fallen leaves
    stamp_lines(litter, rng, int(size * 1.6), size / 16.0, 1.0, 0.6, "max")   # needles
    stamp_lines(litter, rng, int(size * 0.12), size / 4.5, 2.6, 0.35, "max")  # twigs, darker
    litter = blur(litter, 1)
    height = normalize(0.45 * base + 0.8 * litter)
    detail = normalize(0.35 * base + 0.75 * litter) * 0.9 + 0.05
    return detail, height, 2.2


def layer_gravel(size, rng):
    # Loose gravel (owner, 2026-10-20: "gravel and boulders ... sometimes more like sand and
    # gravel"): pebbles of three sizes dropped on a bed of coarse sand, bigger stones sparse and
    # the rest filled by smaller ones, so it reads as scattered rubble, not a tiled cobble sheet.
    height = 0.12 * fbm(size, 90, 2, rng)
    shade = 0.62 + 0.3 * fbm(size, 150, 2, rng)             # the sand between the stones
    for cells, keep, radius, lift in ((46, 0.85, 0.55, 0.30), (19, 0.5, 0.58, 0.5), (8, 0.2, 0.6, 0.75)):
        f1, f2, nid = voronoi(size, cells, rng, warp=0.35)
        present = nid > (1.0 - keep)
        dome = np.sqrt(np.clip(1.0 - f1 / radius, 0.0, 1.0)) * present
        rim = np.clip((f2 - f1) / 0.14, 0.0, 1.0)
        tone = 0.5 + 0.5 * ((nid * 7.31) % 1.0)             # each stone its own brightness
        top = dome * lift * (0.5 + 0.5 * rim)
        over = top > height
        height = np.where(over, top, height)
        shade = np.where(over & (dome > 0.05), 0.35 + 0.65 * tone * (0.75 + 0.25 * rim), shade)
    height = normalize(height)
    detail = normalize(0.55 * shade + 0.45 * height)
    return detail, height, 3.0


def layer_mud(size, rng):
    broad = fbm(size, 6, 4, rng)
    f1, f2, _ = voronoi(size, 7, rng, warp=0.3)
    cracks = 0.6 * (1.0 - np.clip((f2 - f1) / 0.05, 0.0, 1.0))    # thin dry cracks
    fine = fbm(size, 70, 2, rng)
    height = normalize(0.7 * broad + 0.2 * fine - 0.35 * cracks)
    detail = normalize(0.55 * broad + 0.3 * fine - 0.5 * cracks)
    return detail, height, 1.0


def layer_sand(size, rng):
    warp = fbm(size, 6, 3, rng)
    ys, xs = np.mgrid[0:size, 0:size] / size
    ripple = 0.5 + 0.5 * np.sin((ys * 18 + warp * 3.0) * 2 * np.pi)     # whole number of waves: seamless
    grain = fbm(size, 220, 1, rng)
    height = normalize(0.55 * ripple + 0.25 * warp + 0.25 * grain)
    detail = normalize(0.35 * ripple + 0.35 * grain + 0.3 * warp)
    return detail, height, 0.8


def layer_rock(size, rng):
    f1, f2, nid = voronoi(size, 5, rng, warp=0.3)
    crack = np.clip((f2 - f1) / 0.07, 0.0, 1.0)           # dark cracks between blocks
    ys, xs = np.mgrid[0:size, 0:size] / size
    warp = fbm(size, 4, 3, rng)
    strata = 0.5 + 0.5 * np.sin((ys * 9 + warp * 2.5) * 2 * np.pi)
    rough = fbm(size, 36, 4, rng, gain=0.6)
    block = 0.55 + 0.45 * nid
    height = normalize(0.45 * block + 0.5 * rough + 0.25 * crack + 0.15 * strata)
    detail = normalize((0.3 + 0.7 * crack) * (0.6 + 0.4 * block) * (0.65 + 0.35 * rough) * (0.85 + 0.15 * strata))
    return detail, height, 3.5


BUILDERS = [layer_turf, layer_litter, layer_gravel, layer_mud, layer_sand, layer_rock]


def pack(detail, height, strength):
    size = detail.shape[0]
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * size / 64.0 * strength
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * size / 64.0 * strength
    n = np.stack([-gx, -gy, np.ones_like(gx)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    out = np.zeros((size, size, 4))
    out[..., 0] = detail
    out[..., 1] = n[..., 0] * 0.5 + 0.5
    out[..., 2] = n[..., 1] * 0.5 + 0.5
    out[..., 3] = height
    return (np.clip(out, 0, 1) * 255.0 + 0.5).astype(np.uint8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, default=512)
    parser.add_argument("--out", default="assets/ground")
    parser.add_argument("--sheet", default=None)
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    tiles = []

    for index, build in enumerate(BUILDERS):
        rng = np.random.default_rng(1000 + index)
        detail, height, strength = build(args.size, rng)
        data = pack(detail, height, strength)
        path = os.path.join(args.out, "layer_%d_%s.png" % (index, NAMES[index]))
        Image.fromarray(data, "RGBA").save(path, optimize=True)
        print(path, os.path.getsize(path) // 1024, "KB", "mean detail %.2f" % detail.mean())
        tiles.append(data)

    if args.sheet:
        # Contact sheet: each layer tiled 2 by 2 as grey detail with the normal's light on it.
        rows = []
        for data in tiles:
            grey = data[..., 0:1].astype(float) * (0.6 + 0.8 * (data[..., 1:2].astype(float) / 255.0))
            rgb = np.clip(np.repeat(grey, 3, axis=2), 0, 255).astype(np.uint8)
            rows.append(np.tile(rgb, (2, 2, 1))[: args.size, : args.size])
        top = np.concatenate(rows[:3], axis=1)
        bottom = np.concatenate(rows[3:], axis=1)
        Image.fromarray(np.concatenate([top, bottom], axis=0), "RGB").save(args.sheet)


if __name__ == "__main__":
    main()
