#!/usr/bin/env python3
"""Score a night picture of the witness tree's crown against Dave's target picture.

Dave's target is art/references/witness_tree_dave_2026-11-25.jpg (right half: the
tree at night). Three passes tuned by description missed it, so every new night
picture is measured the same way and the numbers are put side by side:

  lit      share of the crown area that is lit violet vein
  vein     colour of the lit vein pixels: hue (degrees), saturation, brightness
           (median of all lit pixels, and of the brightest tenth = the vein core)
  width    vein stroke width as a share of leaf length
  across   how many leaves fill the crown width

Method (same for every picture, so the numbers compare):
  - The crown box is scaled to 800 px wide, so widths and counts do not depend on
    the picture's size.
  - A pixel is lit vein when it is violet (hue 250 to 320 degrees), has some colour
    (saturation >= 0.15) and is bright (value >= 0.35). Bark and blossoms are grey
    or pink and are left out.
  - The crown area is every 16 px cell holding a lit pixel (a cell grid, so dark
    gaps between leaves inside the crown count as crown, the open sky does not).
  - Stroke width: for each lit run along rows and columns, the shorter of the two
    runs through a pixel; the median over lit pixels.
  - Leaves: 8-connected groups of lit pixels (one leaf's vein feather joins at its
    midrib). Groups under 12 px are noise. Leaf length = median longer side of a
    group's box; leaves across = crown width / median group box width. When leaves
    overlap, groups merge and the count of groups per crown width drops: that is
    reported too (groups).

Usage:
  python3 tools/score_witness_night.py                      # Dave's target only
  python3 tools/score_witness_night.py PIC [PIC ...]        # target + each picture
  python3 tools/score_witness_night.py PIC --box x0,y0,x1,y1   # crop for the next PIC
Without --box a picture is scored whole (frame the crown when taking it).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "art", "references", "witness_tree_dave_2026-11-25.jpg")
# Right half of Dave's picture, the crown above where the big limbs leave the trunk.
TARGET_BOX = (900, 10, 1765, 620)
WIDTH = 800
CELL = 16
MIN_GROUP = 40
JOIN = int(os.environ.get('WITNESS_JOIN', '2'))


def load(path, box):
    im = Image.open(path).convert("RGB")
    if box:
        im = im.crop(box)
    h = max(1, round(im.height * WIDTH / im.width))
    im = im.resize((WIDTH, h), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0.0)
    dd = np.maximum(d, 1e-6)
    h = np.where(mx == r, ((g - b) / dd) % 6, np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4))
    h = np.where(d > 0, h * 60.0, 0.0)
    return h, s, mx


def runs(mask):
    """Length of the lit run each lit pixel sits in, along each row."""
    out = np.zeros(mask.shape, np.int32)
    for y in range(mask.shape[0]):
        row = mask[y]
        x = 0
        n = len(row)
        while x < n:
            if row[x]:
                e = x
                while e < n and row[e]:
                    e += 1
                out[y, x:e] = e - x
                x = e
            else:
                x += 1
    return out


def grow(mask, r):
    """Mask grown by r px (square), so a leaf's separate vein strokes join."""
    out = mask.copy()
    h, w = mask.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            src = mask[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)]
            out[max(0, dy):h - max(0, -dy), max(0, dx):w - max(0, -dx)] |= src
    return out


def groups(mask):
    """8-connected groups: list of (pixels, box width, box height)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    found = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        seen[y0, x0] = True
        stack = [(y0, x0)]
        n = 0
        ylo = yhi = y0
        xlo = xhi = x0
        while stack:
            y, x = stack.pop()
            n += 1
            ylo, yhi, xlo, xhi = min(ylo, y), max(yhi, y), min(xlo, x), max(xhi, x)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack.append((yy, xx))
        found.append((n, xhi - xlo + 1, yhi - ylo + 1))
    return found


def score(path, box=None):
    rgb = load(path, box)
    hue, sat, val = hsv(rgb)
    lit = (hue >= 250) & (hue <= 320) & (sat >= 0.15) & (val >= 0.35)
    h, w = lit.shape
    gh, gw = (h + CELL - 1) // CELL, (w + CELL - 1) // CELL
    pad = np.zeros((gh * CELL, gw * CELL), bool)
    pad[:h, :w] = lit
    cells = pad.reshape(gh, CELL, gw, CELL).any(axis=(1, 3))
    crown_px = int(cells.sum()) * CELL * CELL
    cols = np.nonzero(cells.any(0))[0]
    crown_w = (cols.max() - cols.min() + 1) * CELL if len(cols) else 0
    res = {"name": os.path.basename(path), "lit": 0.0}
    if not lit.any():
        return res
    res["lit"] = lit.sum() / max(crown_px, 1)
    v = val[lit]
    core = v >= np.percentile(v, 90)
    res["hue"] = float(np.median(hue[lit]))
    res["sat"] = float(np.median(sat[lit]))
    res["val"] = float(np.median(v))
    res["core_sat"] = float(np.median(sat[lit][core]))
    res["core_val"] = float(np.median(v[core]))
    crown = np.repeat(np.repeat(cells, CELL, 0), CELL, 1)[:h, :w]
    mean = rgb[crown].mean(0)
    res["crown_val"] = float(mean.max())
    dark_in = crown & ~lit
    gaps = runs(dark_in)[dark_in & ~grow(~crown, CELL // 2)]
    if len(gaps):
        res["gap_px"] = float(np.median(gaps))
    stroke = np.minimum(runs(lit), runs(lit.T).T)[lit]
    res["stroke_px"] = float(np.median(stroke))
    g = [x for x in groups(grow(lit, JOIN)) if x[0] >= MIN_GROUP]
    if g:
        res["leaf_px"] = float(np.median([max(bw, bh) for _, bw, bh in g]))
        res["width"] = res["stroke_px"] / res["leaf_px"]
        res["across"] = crown_w / float(np.median([bw for _, bw, _ in g]))
        res["groups"] = len(g) * WIDTH / max(crown_w, 1)
    return res


ROWS = [
    ("lit", "lit vein share of crown", "{:.1%}"),
    ("hue", "vein hue (deg)", "{:.0f}"),
    ("sat", "vein saturation", "{:.2f}"),
    ("val", "vein brightness", "{:.2f}"),
    ("core_sat", "vein core saturation", "{:.2f}"),
    ("core_val", "vein core brightness", "{:.2f}"),
    ("crown_val", "crown mean brightness", "{:.3f}"),
    ("gap_px", "dark gap between veins (px)", "{:.1f}"),
    ("stroke_px", "vein stroke (px of 800)", "{:.1f}"),
    ("leaf_px", "leaf length (px of 800)", "{:.0f}"),
    ("width", "vein width / leaf length", "{:.3f}"),
    ("across", "leaves across crown", "{:.1f}"),
    ("groups", "separate leaves per crown width", "{:.0f}"),
]


def table(results):
    names = [r["name"][:28] for r in results]
    out = ["{:<30}".format("") + "".join("{:>30}".format(n) for n in names)]
    for key, label, fmt in ROWS:
        cells = [fmt.format(r[key]) if key in r else "-" for r in results]
        out.append("{:<30}".format(label) + "".join("{:>30}".format(c) for c in cells))
    return "\n".join(out)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("items", nargs="*", help="pictures, each optionally preceded by --box")
    args, rest = ap.parse_known_args(argv)
    todo = []
    box = None
    tokens = list(argv)
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t == "--box":
            box = tuple(int(x) for x in tokens[i + 1].split(","))
            i += 2
            continue
        todo.append((t, box))
        box = None
        i += 1
    results = [score(TARGET, TARGET_BOX)] + [score(p, b) for p, b in todo]
    results[0]["name"] = "Dave's target"
    print(table(results))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
