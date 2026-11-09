#!/usr/bin/env python3
"""Paint the first icons the bake never had: log and stone (inventory redesign step 5; Kathleen, 9 Nov 2026). The stick moved to
tools/paint_item_icons.py, drawn thicker so it reads at 23 px.

They are drawn to the icon rig's look (docs/ui/inventory_crafting_redesign.md section 6.7, the bake in item_icon_sheet.png):
low-poly, flat-shaded facets under a warm key light from the top left, a soft fill, three-quarter view, no background,
128 x 128 with the object filling about 80 %. Drawn at 4x and scaled down so the facet edges are smooth.

    python3 tools/paint_basic_icons.py [--out assets/ui/item_icons]
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw

SIZE = 128
SS = 4
KEY = np.array([-0.55, 0.65, 0.52])          # light from the top left, a little in front
KEY = KEY / np.linalg.norm(KEY)
KEY_COLOUR = np.array([1.0, 0.95, 0.86])     # warm white (look doc 6.6)
FILL = 0.38                                  # ambient: the shadow side stays readable


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


VIEW = rot_x(math.radians(28.0)) @ rot_y(math.radians(-35.0))   # the three-quarter view of the bake


def prism(radius, length, sides, colour_side, colour_end, ring=None, bend=0.0, taper=1.0, seed=0):
    """A faceted cylinder along x, centred on the origin: its side facets and two end caps (with an inner ring on the caps)."""
    rng = np.random.default_rng(seed)
    faces = []
    jitter = [1.0 + rng.uniform(-0.08, 0.08) for _ in range(sides)]
    ends = []

    for k, x in enumerate((-length / 2.0, length / 2.0)):
        r = radius * (taper if k == 1 else 1.0)
        ring_pts = []

        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            ring_pts.append(np.array([x, bend * (x / length) ** 2 + r * jitter[i] * math.sin(a), r * jitter[i] * math.cos(a)]))

        ends.append(ring_pts)

    for i in range(sides):
        j = (i + 1) % sides
        faces.append(([ends[0][i], ends[1][i], ends[1][j], ends[0][j]], colour_side))

    for k, pts in enumerate(ends):
        faces.append((pts[::-1] if k == 1 else pts, colour_end))

        if ring is not None:
            c = np.mean(pts, axis=0)
            inner = [c + (p - c) * 0.55 + np.array([0.002 if k else -0.002, 0, 0]) for p in pts]
            faces.append((inner[::-1] if k == 1 else inner, ring))
            core = [c + (p - c) * 0.18 + np.array([0.004 if k else -0.004, 0, 0]) for p in pts]
            faces.append((core[::-1] if k == 1 else core, colour_end))

    return faces


def rock(radius, colour, seed):
    """An irregular low-poly stone: a jittered icosahedron, squashed a little."""
    rng = np.random.default_rng(seed)
    t = (1.0 + math.sqrt(5.0)) / 2.0
    verts = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
             (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    tris = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    v = [np.array(p, dtype=float) / np.linalg.norm(p) for p in verts]
    # one subdivision so the stone has more, smaller facets
    cache = {}

    def mid(a, b):
        key = (min(a, b), max(a, b))

        if key not in cache:
            m = (v[a] + v[b]) / 2.0
            v.append(m / np.linalg.norm(m))
            cache[key] = len(v) - 1

        return cache[key]

    fine = []

    for a, b, c in tris:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        fine += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]

    scale = np.array([1.25, 0.78, 1.0]) * radius
    pts = [p * scale * (1.0 + rng.uniform(-0.13, 0.13)) for p in v]
    return [([pts[a], pts[b], pts[c]], colour) for a, b, c in fine]


def render(faces, model, colour_jitter=0.0, seed=0):
    rng = np.random.default_rng(seed)
    n = SIZE * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    placed = []

    for pts, colour in faces:
        world = [model @ p for p in pts]
        normal = np.cross(world[1] - world[0], world[2] - world[0])

        if np.linalg.norm(normal) < 1e-9:
            continue

        normal = normal / np.linalg.norm(normal)
        view = [VIEW @ p for p in world]
        vn = VIEW @ normal

        if vn[2] <= 0.0:          # back face
            continue

        light = FILL + (1.0 - FILL) * max(0.0, float(np.dot(normal, KEY)))
        rim = 0.18 * max(0.0, float(np.dot(normal, np.array([0.6, 0.3, -0.75]))))     # the gold rim from behind right
        base = np.array(colour, dtype=float) / 255.0 * (1.0 + rng.uniform(-colour_jitter, colour_jitter))
        rgb = np.clip(base * light * KEY_COLOUR + rim * np.array([1.0, 0.84, 0.55]), 0.0, 1.0)
        depth = float(np.mean([p[2] for p in view]))
        placed.append((depth, view, tuple(int(c * 255) for c in rgb)))

    placed.sort(key=lambda f: f[0])
    allpts = np.array([p for _, view, _ in placed for p in view])
    lo, hi = allpts[:, :2].min(axis=0), allpts[:, :2].max(axis=0)
    span = max(hi - lo)
    fit = n * 0.8 / span
    centre = (lo + hi) / 2.0

    for _, view, rgb in placed:
        poly = [((p[0] - centre[0]) * fit + n / 2.0, n / 2.0 - (p[1] - centre[1]) * fit) for p in view]
        d.polygon(poly, fill=rgb + (255,))

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def log_icon():
    bark = (122, 88, 56)
    end = (226, 196, 146)
    ring = (196, 158, 104)
    faces = prism(0.42, 2.0, 10, bark, end, ring=ring, seed=3)
    return render(faces, rot_z(math.radians(30.0)) @ rot_y(math.radians(10.0)), colour_jitter=0.06, seed=3)


def stone_icon():
    faces = rock(1.0, (172, 162, 146), seed=11)
    return render(faces, rot_y(math.radians(25.0)) @ rot_x(math.radians(-8.0)), colour_jitter=0.07, seed=11)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui", "item_icons"))
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    for name, painter in (("log", log_icon), ("stone", stone_icon)):
        path = os.path.join(args.out, name + ".png")
        painter().save(path)
        print("painted", path)


if __name__ == "__main__":
    main()
