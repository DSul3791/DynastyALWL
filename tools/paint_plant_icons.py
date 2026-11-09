#!/usr/bin/env python3
"""Paint the gathered herbs and leaves, flowers and roots so each reads as itself (Kathleen, 9 Nov 2026).

The bake draws each of these families with one shape from looks.json (a green sprig, a stem with a daisy, a pale wedge), so at
slot size they differ only by tint and are thin at 23 px (docs/ui/item_icons.md). Here each plant gets its own form: the leaf
shape and how the leaves grow (a bunch, a sprig of pairs, a fern frond, needles on a twig), the flower's form (daisy, bell, spike,
umbel, thistle, star, lily) and the root's (taproot, thick root, knotted, bulb, a bunch of thin roots), drawn large enough to fill
the icon. Each item keeps its looks.json colour, so the icon matches the thing in the world.

    python3 tools/paint_plant_icons.py [--out assets/ui/item_icons] [--only id,id]
"""
import argparse
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paint_basic_icons import KEY, VIEW, rot_z   # noqa: E402  (the shared rig)
from paint_item_icons import CORD, blob, rod   # noqa: E402
from paint_structure_icons import moved, render, shade   # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOOKS = os.path.join(ROOT, "data", "items", "looks.json")
STEM = (92, 120, 58)
SOIL = (96, 70, 46)

def _toward_key(k):
    """Plants are laid out in the x-y plane facing +z. This turn cancels the bake's three-quarter view, then tips the plant a share k of
    the way from facing the viewer to facing the key light: face-on, a leaf only catches the fill light and comes out dark on the slot."""
    z = np.array([0.0, 0.0, 1.0])
    key = VIEW @ KEY
    axis = np.cross(z, key)
    axis = axis / np.linalg.norm(axis)
    angle = k * math.acos(float(np.clip(key @ z, -1.0, 1.0)))
    cross = np.array([[0.0, -axis[2], axis[1]], [axis[2], 0.0, -axis[0]], [-axis[1], axis[0], 0.0]])
    tip = np.eye(3) + math.sin(angle) * cross + (1.0 - math.cos(angle)) * cross @ cross
    return VIEW.T @ tip


FACE = _toward_key(0.6)


def look_colour(item):
    with open(LOOKS, encoding="utf-8") as f:
        row = json.load(f)["items"][item]

    hex_colour = str(row["color"]).lstrip("#")
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4))


def _quad(a, b, c, d, colour):
    """A quad seen from both sides: its top (the side facing +z, toward the viewer) in its colour, the underside a shade darker."""
    if np.cross(b - a, c - a)[2] < 0.0:
        a, b, c, d = d, c, b, a
    return [([a, b, c, d], colour), ([d, c, b, a], shade(colour, 0.78))]


# ---------------------------------------------------------------- leaves
def _width(shape, t):
    """Half-width of a leaf of `shape` at t (0 at the stalk, 1 at the tip), for a leaf of width 1."""
    if shape == "oval":
        return 0.5 * math.sin(math.pi * t) ** 0.8
    if shape == "broad":
        return 0.5 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.55 if t < 0.87 else 0.5 * math.sin(math.pi * 0.999) + 0.5 * (1.0 - t) * 3.0
    if shape == "lance":
        return 0.5 * math.sin(math.pi * t) ** 1.4
    if shape == "heart":
        return 0.5 * math.sin(math.pi * (0.25 + 0.75 * t)) ** 0.7
    if shape == "arrow":
        return 0.5 * (1.0 - t) ** 0.8 if t > 0.12 else 0.5 * (1.0 - t) ** 0.8 * (1.0 + 2.0 * (0.12 - t))
    if shape == "needle":
        return 0.5 * (1.0 - t) ** 0.6
    if shape == "round":
        return 0.5 * math.sin(math.pi * t) ** 0.5
    return 0.5 * math.sin(math.pi * t)


def blade(base, angle, length, width, colour, shape="oval", teeth=0, curl=0.35, steps=10, z=0.0):
    """One leaf from base, pointing at angle (degrees, in the x-y plane), folded along its midrib so the two halves shade apart."""
    steps = max(steps, 14) if teeth else steps
    a = math.radians(angle)
    d = np.array([math.cos(a), math.sin(a), 0.0])
    s = np.array([-math.sin(a), math.cos(a), 0.0])
    up = np.array([0.0, 0.0, 1.0])
    b = np.array([base[0], base[1], z])
    faces = []
    prev = None

    for i in range(steps + 1):
        t = i / steps
        w = _width(shape, t) * width

        if teeth and 0 < i < steps:                              # a saw edge: every other step pulled in
            w *= 1.0 if i % 2 else 1.0 - 0.16 * teeth

        mid = b + d * t * length + up * 0.02 * math.sin(math.pi * t)
        lift = up * w * curl
        cur = (mid, mid + s * w + lift, mid - s * w + lift)

        if prev is not None:
            faces += _quad(prev[0], prev[1], cur[1], cur[0], shade(colour, 1.06))
            faces += _quad(prev[2], prev[0], cur[0], cur[2], shade(colour, 0.92))
        prev = cur
    return faces


def leaf_bunch(colour, shape, n=4, length=1.5, width=0.6, spread=(20.0, 85.0), teeth=0, stem=True, seed=0):
    """Leaves fanning up from one point at the lower left, longest in the middle of the fan."""
    rng = np.random.default_rng(seed)
    faces = []
    base = (-0.75, -0.75)

    for k in range(n):
        f = k / max(1, n - 1)
        ang = spread[0] + (spread[1] - spread[0]) * f
        ln = length * (0.78 + 0.22 * math.sin(math.pi * f)) * rng.uniform(0.92, 1.05)
        start = (base[0] + 0.12 * math.cos(math.radians(ang)), base[1] + 0.12 * math.sin(math.radians(ang)))
        faces += blade(start, ang, ln, width, shade(colour, rng.uniform(0.92, 1.06)), shape, teeth, z=0.02 * k)

    if stem:
        faces += rod((base[0] - 0.12, base[1] - 0.12, 0.0), (base[0] + 0.1, base[1] + 0.1, 0.0), 0.05, shade(colour, 0.75), sides=6, seed=seed)
    return faces


def sprig(colour, shape="oval", pairs=4, leaf_len=0.5, leaf_w=0.3, stem_len=1.9, angle=55.0, teeth=0, seed=0, tip=True):
    """A stem with leaves in opposite pairs (mint, marjoram, sage on the stalk)."""
    a = math.radians(angle)
    d = np.array([math.cos(a), math.sin(a)])
    base = np.array([-0.8, -0.85])
    faces = rod((base[0], base[1], 0.0), (base[0] + d[0] * stem_len, base[1] + d[1] * stem_len, 0.0), 0.055, shade(colour, 0.7), sides=6, seed=seed)

    for k in range(pairs):
        t = 0.25 + 0.7 * k / max(1, pairs - 1)
        p = base + d * stem_len * t
        size = 1.0 - 0.35 * (k / max(1, pairs - 1))

        for side in (-1, 1):
            faces += blade(p, angle + side * 62.0, leaf_len * size, leaf_w * size, shade(colour, 1.0 if side > 0 else 0.94), shape, teeth, z=0.03)
    if tip:
        p = base + d * stem_len
        faces += blade(p, angle, leaf_len * 0.7, leaf_w * 0.6, colour, shape, teeth, z=0.04)
    return faces


def frond(colour, n=12, length=2.4, leaflet=0.5, leaflet_w=0.16, angle=50.0, bend=0.25, shape="lance", sweep=58.0, taper=0.7, seed=0):
    """A fern frond or palm frond: a curving stalk with leaflets down both sides, shorter toward the tip."""
    faces = []
    pts = []

    for i in range(n + 1):
        t = i / n
        a = math.radians(angle - bend * 90.0 * t)
        r = length * t
        pts.append(np.array([-0.95 + r * math.cos(a), -0.9 + r * math.sin(a), 0.0]))

    for i in range(n):
        faces += rod(pts[i], pts[i + 1], 0.035, shade(colour, 0.75), sides=5, seed=seed + i)
        seg = pts[i + 1] - pts[i]
        heading = math.degrees(math.atan2(seg[1], seg[0]))
        size = 1.0 - taper * (i / n)

        for side in (-1, 1):
            faces += blade(pts[i + 1][:2], heading + side * sweep, leaflet * size, leaflet_w * (0.6 + 0.4 * size),
                           shade(colour, 1.0 if side > 0 else 0.92), shape, z=0.02)
    return faces


def needles(colour, twig=(120, 84, 52), twigs=3, n=16, length=1.9, needle=0.62, seed=0):
    """Twigs thick with narrow needle leaves (rosemary, everember)."""
    rng = np.random.default_rng(seed)
    faces = []

    for j in range(twigs):
        a = math.radians(45.0 + 22.0 * (j - (twigs - 1) / 2.0))
        d = np.array([math.cos(a), math.sin(a)])
        base = np.array([-0.75, -0.75])
        ln = length * (1.0 if j == (twigs - 1) // 2 else 0.8)
        tip = base + d * ln
        faces += rod((base[0], base[1], 0.0), (tip[0], tip[1], 0.0), 0.045, twig, sides=6, seed=seed + j)

        for k in range(n):
            t = 0.12 + 0.88 * k / n
            p = base + d * ln * t
            side = 1 if k % 2 else -1
            faces += blade(p, math.degrees(a) + side * rng.uniform(35.0, 60.0), needle * (1.0 - 0.4 * t), 0.15, shade(colour, rng.uniform(0.9, 1.1)),
                           "needle", curl=0.1, steps=4, z=0.02 + 0.03 * j)
    return faces


def tiny_leaf_twigs(colour, twigs=3, seed=0):
    """Thyme: a few woody twigs crowded with tiny round leaves."""
    rng = np.random.default_rng(seed)
    faces = []

    for j in range(twigs):
        a = 40.0 + 18.0 * (j - (twigs - 1) / 2.0)
        d = np.array([math.cos(math.radians(a)), math.sin(math.radians(a))])
        base = np.array([-0.7, -0.8])
        tip = base + d * 2.0
        faces += rod((base[0], base[1], 0.0), (tip[0], tip[1], 0.0), 0.03, (110, 86, 60), sides=5, seed=seed + j)

        for k in range(10):
            p = base + d * 2.0 * (0.15 + 0.85 * k / 10)
            faces += blob((p[0] + rng.uniform(-0.08, 0.08), p[1] + rng.uniform(-0.08, 0.08), 0.03), (0.13, 0.13, 0.05),
                          shade(colour, rng.uniform(0.9, 1.1)), seed=seed + k, seg=6, rings=3)
    return faces


def fiddleheads(colour, seed=0):
    """Tightly curled young fern fronds: three green coils on short stalks."""
    faces = []

    for j, (bx, by, r) in enumerate(((-0.4, -0.2, 0.42), (0.35, 0.15, 0.36), (-0.15, 0.55, 0.3))):
        pts = []

        for i in range(22):
            t = i / 21
            a = 3.6 * math.pi * t
            rr = r * (1.0 - 0.85 * t)
            pts.append(np.array([bx + rr * math.cos(a), by + rr * math.sin(a), 0.02 * j]))
        faces += rod((bx + r, by - 0.9, 0.0), pts[0], 0.07, shade(colour, 0.85), sides=6, seed=seed + j)

        for i in range(21):
            faces += rod(pts[i], pts[i + 1], 0.08 * (1.0 - 0.5 * i / 21), shade(colour, 1.0 + 0.1 * (i % 2)), sides=6, seed=seed + i)
    return faces


def jointed_shoots(colour, seed=0):
    """Samphire: crisp jointed green shoots, branching."""
    faces = []
    rng = np.random.default_rng(seed)

    for j in range(5):
        a = math.radians(35.0 + 14.0 * j)
        p = np.array([-0.6 + 0.12 * j, -0.85, 0.0])

        for k in range(5):
            q = p + np.array([math.cos(a), math.sin(a), 0.0]) * 0.36
            faces += rod(p, q, 0.075, shade(colour, rng.uniform(0.92, 1.08)), sides=6, seed=seed + k)
            faces += blob(q, (0.085, 0.06, 0.085), shade(colour, 0.85), seed=seed + j, seg=6, rings=3)
            a += math.radians(rng.uniform(-14.0, 14.0))
            p = q
    return faces


def ribbons(colour, n=3, seed=0):
    """Tideglass: wavy glassy ribbons of sea frond."""
    faces = []

    for j in range(n):
        base = np.array([-0.8 + 0.42 * j, -0.85])
        prev = None

        for i in range(14):
            t = i / 13
            y = base[1] + 2.0 * t
            x = base[0] + 0.3 * math.sin(6.0 * t + 1.7 * j) + 0.6 * t
            w = 0.26 * (1.0 - 0.5 * t)
            cur = (np.array([x - w, y, 0.02 * j]), np.array([x + w, y, 0.02 * j + 0.04 * math.sin(6.0 * t)]))

            if prev is not None:
                faces += _quad(prev[0], prev[1], cur[1], cur[0], shade(colour, 1.0 + 0.08 * math.sin(6.0 * t + j)))
            prev = cur
    return faces


def tied_herbs(colour, seed=0):
    """A bundle of mixed sprigs tied with cord: herbs."""
    faces = []

    for j, (shape, ang) in enumerate((("oval", 50.0), ("lance", 62.0), ("round", 40.0), ("oval", 72.0))):
        faces += moved(sprig(shade(colour, 0.9 + 0.06 * j), shape, pairs=3, leaf_len=0.6, leaf_w=0.34, stem_len=1.9, angle=ang, seed=seed + j),
                       shift=(0.0, 0.0, 0.03 * j))
    faces += rod((-0.62, -0.62, -0.1), (-0.56, -0.56, 0.2), 0.16, CORD, sides=10, seed=seed)
    return faces


def trefoil(colour, seed=0):
    """Raspberry leaves: toothed leaflets in threes on a stalk, two sets."""
    faces = rod((-0.85, -0.85, 0.0), (0.2, 0.2, 0.0), 0.04, (126, 70, 60), sides=6, seed=seed)

    for p, scale in (((0.2, 0.2), 1.0), ((-0.35, -0.35), 0.75)):
        for ang in (5.0, 45.0, 85.0):
            faces += blade(p, ang, 1.05 * scale, 0.66 * scale, shade(colour, 1.0 if ang != 45.0 else 1.06), "oval", teeth=2, z=0.03)
    return faces


def round_leaflets(colour, seed=0):
    """Watercress: stems of small round leaflets."""
    faces = []

    for j, ang in enumerate((40.0, 60.0, 80.0)):
        faces += moved(frond(shade(colour, 0.95 + 0.05 * j), n=5, length=1.7, leaflet=0.36, leaflet_w=0.32, angle=ang, bend=0.1, shape="round",
                             seed=seed + j), shift=(0.1 * j, 0.0, 0.03 * j))
    return faces


def vine_leaves(colour, seed=0):
    """Sunsilver: heart-shaped silver leaves on a curling vine."""
    faces = []
    pts = [np.array([-0.9 + 0.12 * i + 0.15 * math.sin(i * 0.9), -0.85 + 0.15 * i, 0.0]) for i in range(12)]

    for i in range(11):
        faces += rod(pts[i], pts[i + 1], 0.03, (120, 120, 100), sides=5, seed=seed + i)
    for i in (2, 5, 8, 11):
        side = 1 if i % 2 else -1
        faces += blade(pts[i][:2], 50.0 + side * 55.0, 0.75, 0.6, shade(colour, 1.0 if side > 0 else 0.92), "heart", z=0.03)
    return faces


def big_leaf(colour, split=True, seed=0):
    """Banana: one huge glossy leaf, its edge torn into strips."""
    faces = blade((-0.95, -0.95), 45.0, 2.7, 1.2, colour, "oval", curl=0.25, steps=14)
    faces += rod((-1.1, -1.1, 0.0), (-0.95, -0.95, 0.0), 0.06, shade(colour, 0.8), sides=6, seed=seed)

    if split:                                                   # tears: dark slits across the blade
        for k in range(4):
            t = 0.3 + 0.15 * k
            c = np.array([-0.95, -0.95, 0.05]) + np.array([1.0, 1.0, 0.0]) / math.sqrt(2.0) * 2.7 * t
            off = np.array([-1.0, 1.0, 0.0]) / math.sqrt(2.0) * (0.42 if k % 2 else -0.42)
            faces += rod(c + off * 0.35, c + off, 0.015, shade(colour, 0.45), sides=4, seed=seed + k)
    return faces


# ---------------------------------------------------------------- flowers
def _petal_ring(centre, n, length, width, colour, shape="oval", tilt=0.25, start=0.0, z=0.0):
    faces = []

    for k in range(n):
        ang = start + 360.0 * k / n
        faces += blade(centre, ang, length, width, shade(colour, 1.0 - 0.05 * (k % 2)), shape, curl=tilt, steps=6, z=z)
    return faces


def daisy(colour, centre=(224, 176, 32), n=14, petal=0.62, width=0.22, disc=0.24, heads=((0.1, 0.15, 1.0), (-0.65, -0.55, 0.55)), dome=0.6,
          seed=0):
    """Daisy-like heads: a ring of ray petals round a raised disc, on a short stem."""
    faces = []

    for j, (x, y, s) in enumerate(heads):
        faces += rod((x - 0.35 * s, y - 1.1 * s, -0.05), (x, y, -0.02), 0.04, STEM, sides=6, seed=seed + j)
        faces += _petal_ring((x, y), n, petal * s, width * s, colour, z=0.02 * j)
        faces += blob((x, y, 0.06 + 0.02 * j), (disc * s, disc * s, disc * s * dome), centre, seed=seed + j, seg=8, rings=4)
    return faces


def pompom(colour, seed=0):
    """Dandelion: a dense round head of many thin petals in layers."""
    faces = rod((-0.6, -1.0, -0.05), (0.0, 0.0, -0.02), 0.05, STEM, sides=6, seed=seed)

    for layer, (n, ln) in enumerate(((22, 0.8), (18, 0.62), (14, 0.44), (10, 0.26))):
        faces += _petal_ring((0.0, 0.0), n, ln, 0.12, shade(colour, 0.92 + 0.04 * layer), "lance", tilt=0.15, start=layer * 7.0, z=0.04 * layer)
    return faces


def bells(colour, n=4, size=0.36, seed=0):
    """Bell flowers hanging from an arching stem (brinebells, quenchbell)."""
    faces = []
    pts = [np.array([-0.9 + 0.32 * i, -0.9 + 1.6 * math.sin(math.pi * 0.45 * i / 5), 0.0]) for i in range(6)]

    for i in range(5):
        faces += rod(pts[i], pts[i + 1], 0.035, STEM, sides=5, seed=seed + i)
    for k in range(n):
        p = pts[1 + k * 4 // n] if n <= 4 else pts[1 + k % 5]
        top = p + np.array([0.12 * k, -0.08, 0.04])
        faces += rod(p, top, 0.02, STEM, sides=4, seed=seed)
        bell = moved(blob((0, 0, 0), (size * 0.8, size, size * 0.8), shade(colour, 1.0 - 0.05 * k), seed=seed + k, seg=8, rings=5),
                     turn=rot_z(math.radians(-15.0 + 10.0 * k)), shift=tuple(top - np.array([0.0, size * 0.9, 0.0])))
        faces += bell
        faces += _petal_ring(tuple((top - np.array([0.0, size * 1.75, 0.0]))[:2]), 5, size * 0.45, size * 0.3, colour, "oval", tilt=0.6,
                             start=-90.0, z=top[2] + 0.1)
    return faces


def spikes(colour, n=3, seed=0):
    """Lavender, heather: tall spikes of tiny florets."""
    faces = []
    rng = np.random.default_rng(seed)

    for j in range(n):
        a = math.radians(62.0 + 12.0 * (j - (n - 1) / 2.0))
        base = np.array([-0.55 + 0.15 * j, -1.0, 0.0])
        tip = base + np.array([math.cos(a), math.sin(a), 0.0]) * 2.2
        faces += rod(base, tip, 0.03, STEM, sides=5, seed=seed + j)

        for k in range(14):
            t = 0.5 + 0.5 * k / 14
            p = base + (tip - base) * t
            for side in (-1, 1):
                faces += blob((p[0] + side * 0.07, p[1], 0.04 + 0.01 * j), (0.08, 0.07, 0.06), shade(colour, rng.uniform(0.85, 1.1)), seed=seed + k,
                              seg=6, rings=3)
    return faces


def umbel(colour, heads=((0.1, 0.25, 0.95), (-0.55, -0.35, 0.6)), seed=0):
    """Elder, meadowsweet, yarrow: a flat or domed cluster of tiny florets on spreading stalks."""
    faces = []
    rng = np.random.default_rng(seed)

    for j, (x, y, s) in enumerate(heads):
        stem_base = np.array([x - 0.3 * s, y - 1.1 * s, -0.1])
        hub = np.array([x, y - 0.35 * s, 0.0])
        faces += rod(stem_base, hub, 0.04, STEM, sides=6, seed=seed + j)

        for k in range(26):
            a, r = rng.uniform(0, 2 * math.pi), s * 0.62 * math.sqrt(rng.uniform(0, 1))
            p = np.array([x + r * math.cos(a), y + 0.12 * s * math.sin(a) + 0.18 * s, 0.05 + r * 0.3 * math.sin(a)])
            if k % 4 == 0:
                faces += rod(hub, p, 0.015, STEM, sides=4, seed=seed)
            faces += blob(tuple(p), (0.09 * s, 0.08 * s, 0.09 * s), shade(colour, rng.uniform(0.9, 1.08)), seed=seed + k, seg=6, rings=3)
    return faces


def thistle(colour, seed=0):
    """Spiny thistle heads: a green spiny cup with a dark tuft."""
    faces = []

    for j, (x, y, s) in enumerate(((0.15, 0.2, 1.0), (-0.6, -0.4, 0.65))):
        faces += rod((x - 0.3 * s, y - 1.0 * s, -0.05), (x, y - 0.25 * s, 0.0), 0.05, STEM, sides=6, seed=seed + j)
        faces += blob((x, y - 0.1 * s, 0.0), (0.4 * s, 0.38 * s, 0.4 * s), (84, 112, 62), seed=seed + j, seg=8, rings=5, rough=0.15)
        for k in range(9):                                      # spines on the cup
            a = math.radians(-160.0 + 140.0 * k / 8)
            p = np.array([x + 0.38 * s * math.cos(a), y - 0.1 * s + 0.36 * s * math.sin(a), 0.05])
            faces += rod(p, p + np.array([math.cos(a), math.sin(a), 0.0]) * 0.2 * s, 0.015, (190, 196, 150), sides=4, seed=seed)
        for k in range(16):                                     # the tuft of florets
            a = math.radians(30.0 + 120.0 * k / 15)
            faces += rod((x, y + 0.15 * s, 0.05), (x + 0.5 * s * math.cos(a), y + 0.15 * s + 0.5 * s * math.sin(a), 0.08), 0.04 * s,
                         shade(colour, 1.0 + 0.1 * (k % 2)), sides=4, seed=seed + k)
    return faces


def star(colour, centre=(224, 176, 32), n=5, petal=0.75, width=0.42, shape="oval", heads=((0.1, 0.15, 1.0), (-0.6, -0.55, 0.6)), stamens=0,
         seed=0):
    """Five-petalled flowers seen face on (st john's wort, hawthorn, mallow, gloaming star)."""
    faces = []

    for j, (x, y, s) in enumerate(heads):
        faces += rod((x - 0.35 * s, y - 1.1 * s, -0.05), (x, y, -0.02), 0.04, STEM, sides=6, seed=seed + j)
        faces += _petal_ring((x, y), n, petal * s, width * s, colour, shape, tilt=0.2, start=90.0, z=0.02 * j)
        faces += blob((x, y, 0.06), (0.12 * s, 0.12 * s, 0.06 * s), centre, seed=seed + j, seg=6, rings=3)
        for k in range(stamens):
            a = 2.0 * math.pi * k / max(1, stamens)
            tip = np.array([x + 0.32 * s * math.cos(a), y + 0.32 * s * math.sin(a), 0.14])
            faces += rod((x, y, 0.08), tip, 0.012, centre, sides=4, seed=seed)
            faces += blob(tuple(tip), (0.035, 0.035, 0.035), shade(centre, 0.8), seed=seed + k, seg=5, rings=3)
    return faces


def lily(colour, n=6, petal=1.15, width=0.42, layers=1, centre=(224, 176, 32), rim=None, seed=0):
    """Big open flowers: lily, lotus, night bloom, orchid (layers of pointed petals)."""
    faces = rod((-0.7, -1.1, -0.1), (0.0, -0.05, -0.05), 0.05, STEM, sides=6, seed=seed)

    if rim:                                                     # a paler ring behind a dark flower
        faces += _petal_ring((0.0, 0.0), n, petal * 1.08, width * 1.15, rim, "lance", tilt=0.45, start=90.0, z=-0.04)
    for layer in range(layers):
        faces += _petal_ring((0.0, 0.0), n, petal * (1.0 - 0.25 * layer), width * (1.0 - 0.15 * layer), shade(colour, 1.0 + 0.08 * layer), "lance",
                             tilt=0.45, start=90.0 + 30.0 * layer, z=0.05 * layer)
    for k in range(6):
        a = 2.0 * math.pi * k / 6
        tip = np.array([0.3 * math.cos(a), 0.3 * math.sin(a), 0.3])
        faces += rod((0.0, 0.0, 0.1), tip, 0.018, centre, sides=4, seed=seed)
        faces += blob(tuple(tip), (0.05, 0.05, 0.05), shade(centre, 0.8), seed=seed + k, seg=5, rings=3)
    return faces


def loose_petals(colour, spots=None, rim=None, seed=0):
    """A handful of loose petals (rose petals, mournbloom, owlpetals). A dark petal gets a paler rim so it shows on the slot."""
    rng = np.random.default_rng(seed)
    faces = []

    for k in range(9):
        x, y = rng.normal(0.0, 0.45), rng.normal(0.0, 0.4)
        ang = rng.uniform(0, 360)
        faces += blade((x, y), ang, 0.75, 0.62, shade(colour, rng.uniform(0.85, 1.1)), "round", curl=0.5, steps=6, z=0.04 * k)
        if rim:
            a = math.radians(ang)
            faces += blade((x - 0.06 * math.cos(a), y - 0.06 * math.sin(a)), ang, 0.87, 0.74, rim, "round", curl=0.5, steps=6, z=0.04 * k - 0.02)
        if spots:
            a = math.radians(ang)
            faces += blob((x + 0.38 * math.cos(a), y + 0.38 * math.sin(a), 0.04 * k + 0.12), (0.08, 0.08, 0.02), spots, seed=seed + k, seg=6, rings=3)
    return faces


def seed_clock(colour, seed=0):
    """Wispbloom: a round seed-head clock of fine plumed seeds."""
    faces = rod((-0.6, -1.1, -0.05), (0.0, -0.1, -0.02), 0.04, STEM, sides=6, seed=seed)
    faces += blob((0.0, 0.0, 0.0), (0.12, 0.12, 0.12), (200, 190, 150), seed=seed, seg=6, rings=4)

    for k in range(40):
        z = 1.0 - 2.0 * (k + 0.5) / 40
        r = math.sqrt(1.0 - z * z)
        a = k * 2.399963
        d = np.array([r * math.cos(a), r * math.sin(a), z * 0.6])
        tip = d * 0.85
        faces += rod(d * 0.12, tip, 0.01, (220, 220, 200), sides=4, seed=seed)
        faces += blob(tuple(tip), (0.09, 0.09, 0.03), shade(colour, 1.0 + 0.1 * (k % 2)), seed=seed + k, seg=5, rings=3)
    return faces


# ---------------------------------------------------------------- roots
def taproot(colour, length=2.4, thick=0.22, n=1, rootlets=6, top=True, seed=0):
    """Long tapering roots lying across the icon, with hair roots and a cut green top."""
    faces = []
    rng = np.random.default_rng(seed)

    for j in range(n):
        off = np.array([0.45, 0.45, 0.06]) * (j - (n - 1) / 2.0)
        a = np.array([-1.0, 1.0, 0.0]) * 0.5 * length / math.sqrt(2.0) + off
        mid = np.array([0.08, -0.1, 0.0]) + off
        b = np.array([1.0, -1.0, 0.0]) * 0.5 * length / math.sqrt(2.0) + off
        faces += rod(a, mid, thick * (1.0 - 0.08 * j), shade(colour, rng.uniform(0.92, 1.05)), taper=0.7, sides=8, seed=seed + j)
        faces += rod(mid, b, thick * 0.7 * (1.0 - 0.08 * j), shade(colour, rng.uniform(0.92, 1.05)), taper=0.1, sides=8, seed=seed + j + 5)

        for k in range(rootlets):                               # hair roots off the lower half
            t = 0.35 + 0.6 * k / rootlets
            p = a + (b - a) * t
            side = 1 if k % 2 else -1
            q = p + np.array([0.35, 0.35 * side, 0.0]) * rng.uniform(0.6, 1.0) * 0.6
            faces += rod(p, q, 0.015, shade(colour, 0.85), sides=4, seed=seed + k)
        if top:
            faces += rod(a, a + np.array([-0.18, 0.22, 0.0]), thick * 0.55, (96, 128, 60), sides=6, seed=seed)
    return faces


def knotted(colour, seed=0):
    """Heartroots: red knotted roots, knobbed like fists."""
    faces = []
    rng = np.random.default_rng(seed)

    for k, (x, y, r) in enumerate(((-0.35, 0.1, 0.42), (0.3, -0.2, 0.36), (0.0, 0.5, 0.3), (0.55, 0.35, 0.24), (-0.6, -0.45, 0.26))):
        faces += blob((x, y, 0.0), (r, r * 0.85, r * 0.8), shade(colour, rng.uniform(0.88, 1.08)), seed=seed + k, seg=8, rings=5, rough=0.2)
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        p = np.array([0.6 * math.cos(a), 0.6 * math.sin(a), 0.0])
        faces += rod(p * 0.7, p * 1.5, 0.03, shade(colour, 0.8), sides=4, seed=seed + k)
    return faces


def bulbs(colour, n=3, size=0.42, seed=0):
    """Bulbs (wild garlic, sevenyear lily): round bulbs with a pointed neck and a tuft of roots."""
    faces = []
    spots = ((0.0, 0.0, 1.0), (-0.62, -0.32, 0.75), (0.55, -0.42, 0.65))

    for j in range(n):
        x, y, s = spots[j]
        r = size * s
        faces += blob((x, y, 0.05 * j), (r, r * 0.95, r), shade(colour, 1.0 - 0.04 * j), seed=seed + j, seg=9, rings=6)
        faces += rod((x, y + r * 0.7, 0.05 * j), (x, y + r * 1.6, 0.05 * j), r * 0.25, shade(colour, 0.92), taper=0.3, sides=6, seed=seed + j)
        for k in range(5):
            faces += rod((x, y - r * 0.85, 0.05 * j), (x - 0.2 * r + 0.1 * r * k, y - r * 1.5, 0.05 * j), 0.015, (220, 206, 176), sides=4, seed=seed)
    return faces


def turnip_root(colour, seed=0):
    """Wolfsbane: dark turnip-like roots with a tail."""
    faces = []

    for j, (x, y, s) in enumerate(((0.0, 0.15, 1.0), (-0.55, -0.45, 0.7))):
        faces += blob((x, y, 0.05 * j), (0.45 * s, 0.42 * s, 0.45 * s), shade(colour, 1.0 - 0.05 * j), seed=seed + j, seg=9, rings=6, rough=0.12)
        faces += rod((x, y - 0.35 * s, 0.05 * j), (x + 0.4 * s, y - 1.0 * s, 0.05 * j), 0.12 * s, shade(colour, 0.9), taper=0.1, sides=6, seed=seed)
        faces += rod((x, y + 0.38 * s, 0.05 * j), (x - 0.1 * s, y + 0.7 * s, 0.05 * j), 0.08 * s, (86, 112, 60), sides=6, seed=seed)
    return faces


def root_bunch(colour, n=7, thick=0.09, glow=False, seed=0):
    """A bunch of thin roots tied at the crown (duskmallow, emberroots)."""
    faces = []
    rng = np.random.default_rng(seed)
    crown = np.array([-0.75, 0.75, 0.0])

    for k in range(n):
        a = math.radians(-20.0 - 50.0 * k / (n - 1))
        tip = crown + np.array([math.cos(a), math.sin(a), 0.0]) * rng.uniform(1.8, 2.3)
        mid = (crown + tip) / 2.0 + np.array([0.0, 0.0, 0.05 * k]) + np.array([-math.sin(a), math.cos(a), 0.0]) * rng.uniform(-0.12, 0.12)
        c = shade(colour, rng.uniform(0.88, 1.1))
        faces += rod(crown, mid, thick, c, sides=6, seed=seed + k)
        faces += rod(mid, tip, thick * 0.78, c, taper=0.15, sides=6, seed=seed + k)

        if glow and k % 2 == 0:                                 # emberroots stay warm: glowing tips
            faces += [(pts, (255, 150, 60, 1)) for pts, _ in blob(tuple(tip), (0.07, 0.07, 0.07), colour, seed=seed + k, seg=6, rings=3)]
    faces += rod(crown + np.array([0.08, -0.08, 0.0]), crown + np.array([-0.1, 0.1, 0.0]), 0.2, CORD, sides=10, seed=seed)
    return faces


def rosette(colour, n=7, length=1.15, width=0.62, seed=0):
    """Plantain: broad leaves in a flat rosette, each with dark parallel ribs."""
    faces = []

    for k in range(n):
        ang = 90.0 + 360.0 * k / n
        a = math.radians(ang)
        start = (0.1 * math.cos(a), 0.1 * math.sin(a))
        faces += blade(start, ang, length, width, shade(colour, 1.0 - 0.04 * (k % 2)), "oval", curl=0.15, z=0.02 * k)
        d, s = np.array([math.cos(a), math.sin(a), 0.0]), np.array([-math.sin(a), math.cos(a), 0.0])

        for r in (-0.13, 0.0, 0.13):                            # the ribs run the leaf's length
            p0 = np.array([start[0], start[1], 0.03 + 0.02 * k + 0.02]) + d * 0.15
            faces += rod(p0 + s * r * 0.4, p0 + d * length * 0.75 + s * r, 0.015, shade(colour, 0.62), sides=4, seed=seed + k)
    return faces


def berry(centre, colour=(26, 22, 30), r=0.22, seed=0):
    """A glossy berry sitting in a green star of sepals (belladonna)."""
    faces = _petal_ring(centre[:2], 5, r * 1.6, r * 0.7, (70, 110, 50), "lance", tilt=0.3, z=centre[2] - 0.05)
    faces += blob(centre, (r, r, r), colour, seed=seed, seg=10, rings=6, rough=0.02)
    faces += [(pts, (235, 235, 245, 1)) for pts, _ in blob((centre[0] - r * 0.4, centre[1] + r * 0.4, centre[2] + r * 0.8),
                                                           (r * 0.22, r * 0.22, r * 0.1), colour, seed=seed, seg=6, rings=3)]
    return faces


def ramsons(colour, seed=0):
    """Wild garlic leaves: long bright blades with a little head of white star flowers."""
    faces = leaf_bunch(colour, "lance", n=3, length=2.0, width=0.58, spread=(40.0, 75.0), seed=seed)
    hub = np.array([0.05, 0.75, 0.15])
    faces += rod((-0.6, -0.6, 0.1), tuple(hub), 0.03, STEM, sides=5, seed=seed)

    for k in range(6):
        a = 2.0 * math.pi * k / 6
        p = hub + np.array([0.32 * math.cos(a), 0.18 + 0.2 * math.sin(a), 0.08])
        faces += rod(hub, p, 0.012, STEM, sides=4, seed=seed)
        faces += _petal_ring(tuple(p[:2]), 6, 0.22, 0.12, (246, 244, 236), "lance", tilt=0.1, z=p[2])
    return faces


def mixed_greens(colour, seed=0):
    """Greens: a handful of different leaves (round, lance, toothed) in a few shades."""
    faces = []

    for k, (shape, ang, ln, w, teeth, k_shade) in enumerate((("oval", 22.0, 1.4, 0.7, 0, 0.9), ("lance", 48.0, 1.7, 0.45, 1, 1.08),
                                                              ("round", 72.0, 1.2, 0.8, 0, 1.0), ("oval", 95.0, 1.3, 0.6, 2, 0.95))):
        a = math.radians(ang)
        faces += blade((-0.75 + 0.1 * math.cos(a), -0.75 + 0.1 * math.sin(a)), ang, ln, w, shade(colour, k_shade), shape, teeth, z=0.03 * k)
    return faces


def plume(colour, stem=(150, 90, 80), seed=0):
    """Meadowsweet: frothy upright plumes of tiny cream florets on reddish stems."""
    faces = []
    rng = np.random.default_rng(seed)

    for j, (x, s) in enumerate(((0.1, 1.0), (-0.55, 0.75))):
        base = np.array([x - 0.35, -1.1, 0.05 * j])
        top = np.array([x + 0.15, 0.85 * s, 0.05 * j])
        faces += rod(base, top, 0.035, stem, sides=5, seed=seed + j)

        for k in range(34):
            t = rng.uniform(0.0, 1.0)
            c = base + (top - base) * (0.35 + 0.65 * t)
            r = 0.38 * s * (1.0 - t) + 0.06
            a = rng.uniform(0, 2 * math.pi)
            faces += blob((c[0] + r * math.cos(a), c[1], c[2] + r * math.sin(a) * 0.5), (0.1 * s, 0.09 * s, 0.1 * s),
                          shade(colour, rng.uniform(0.88, 1.06)), seed=seed + k, seg=6, rings=3, rough=0.2)
    return faces


def elder(colour, seed=0):
    """Elderflowers: one wide flat umbel over a dark pinnate leaf."""
    faces = []

    for k, (side, t) in enumerate(((-1, 0.0), (1, 0.0), (-1, 0.35), (1, 0.35), (0, 0.7))):
        base = np.array([-0.9 + 0.55 * t, -1.0 + 0.4 * t])
        ang = 70.0 + side * 55.0
        faces += blade(tuple(base), ang, 0.62, 0.3, (60, 96, 50), "lance", teeth=1, z=-0.1)
    faces += umbel(colour, heads=((0.2, 0.3, 1.7),), seed=seed)
    return faces


def yarrow_heads(colour, seed=0):
    """Yarrow: tight flat-topped heads of florets with a feathery leaf."""
    faces = frond((96, 130, 70), n=9, length=1.4, leaflet=0.26, leaflet_w=0.07, angle=30.0, bend=0.05, sweep=70.0, taper=0.3, seed=seed)
    rng = np.random.default_rng(seed)

    for j, (x, y, s) in enumerate(((0.1, 0.45, 1.35), (-0.65, -0.1, 0.95))):
        faces += rod((x - 0.3 * s, y - 1.2 * s, 0.1), (x, y - 0.1, 0.1), 0.035, STEM, sides=5, seed=seed + j)

        for k in range(22):                                     # a dense dome, wider than it is tall
            a, r = rng.uniform(0, 2 * math.pi), s * 0.42 * math.sqrt(rng.uniform(0, 1))
            faces += blob((x + r * math.cos(a), y + 0.08 * math.sin(a) * s, 0.15 + r * 0.6 * math.sin(a)), (0.09 * s, 0.08 * s, 0.09 * s),
                          shade(colour, rng.uniform(0.9, 1.04)), seed=seed + k, seg=6, rings=3)
    return faces


def cups(colour, seed=0):
    """Quenchbell: upturned bell cups on stalks, each holding a bead of water."""
    faces = []
    water = (190, 228, 250, 1)

    for j, (x, y, s) in enumerate(((0.15, 0.25, 1.0), (-0.55, -0.35, 0.72))):
        faces += rod((x - 0.3 * s, y - 1.1 * s, -0.05), (x, y - 0.35 * s, 0.0), 0.04, STEM, sides=6, seed=seed + j)
        faces += moved(blob((0, 0, 0), (0.42 * s, 0.4 * s, 0.42 * s), shade(colour, 1.0 - 0.06 * j), seed=seed + j, seg=9, rings=5),
                       shift=(x, y - 0.05 * s, 0.02 * j))
        faces += _petal_ring((x, y + 0.32 * s), 6, 0.32 * s, 0.24 * s, shade(colour, 1.1), "oval", tilt=0.2, start=90.0, z=0.3 * s)
        faces += [(pts, water) for pts, _ in blob((x, y + 0.36 * s, 0.38 * s), (0.17 * s, 0.11 * s, 0.17 * s), colour, seed=seed, seg=8, rings=4)]
    return faces


def root_pieces(colour, inside=(236, 228, 208), seed=0):
    """Comfrey roots: thick black roots cut into lengths, white where cut."""
    faces = []

    for k, (a, b, r) in enumerate(((( -0.9, 0.2, 0.0), (0.5, -0.9, 0.0), 0.26), ((-0.5, 0.85, 0.15), (0.8, -0.3, 0.15), 0.3),
                                   ((-0.95, -0.55, 0.3), (-0.15, -1.0, 0.3), 0.22))):
        faces += rod(a, b, r, shade(colour, 1.0 + 0.12 * k), end=inside, sides=8, taper=0.85, seed=seed + k)
    return faces


def with_top(faces, colour, at=(-0.9, 0.9, 0.0), toothed=False, feathery=False, seed=0):
    """Roots with their cut green top: a tuft of toothed leaves or feathery fronds at the crown."""
    if feathery:
        for k, ang in enumerate((95.0, 120.0, 145.0)):
            faces = faces + moved(frond(colour, n=7, length=1.0, leaflet=0.22, leaflet_w=0.06, angle=ang, bend=0.05, sweep=60.0, seed=seed + k),
                                  shift=(at[0] + 0.95, at[1] + 0.9, at[2] + 0.05))
        return faces
    for k, ang in enumerate((100.0, 125.0, 150.0)):
        faces = faces + blade(at[:2], ang, 0.9, 0.34, shade(colour, 1.0 - 0.06 * k), "lance", teeth=2 if toothed else 0, z=at[2] + 0.05)
    return faces


# ---------------------------------------------------------------- the plants
def _plants():
    c = look_colour
    return {
        # herbs and leaves
        "banana_leaves": lambda: big_leaf(c("banana_leaves")),
        "belladonna_leaves": lambda: leaf_bunch(c("belladonna_leaves"), "oval", n=3, width=0.8, seed=1) + berry((0.35, -0.45, 0.3), seed=1),
        "comfrey_leaves": lambda: leaf_bunch(c("comfrey_leaves"), "lance", n=3, length=1.7, width=0.62, seed=2),
        "dandelion_leaves": lambda: leaf_bunch(c("dandelion_leaves"), "lance", n=4, length=1.8, width=0.55, teeth=2, seed=3),
        "everember_needles": lambda: needles(c("everember_needles"), seed=4),
        "fiddleheads": lambda: fiddleheads(c("fiddleheads"), seed=5),
        "foxglove_leaves": lambda: leaf_bunch(c("foxglove_leaves"), "lance", n=4, length=1.9, width=0.66, teeth=1, spread=(30.0, 80.0), seed=6),
        "greens": lambda: mixed_greens(c("greens"), seed=7),
        "henbane_leaves": lambda: leaf_bunch(c("henbane_leaves"), "broad", n=3, length=1.6, width=0.8, teeth=2, seed=8),
        "herbs": lambda: tied_herbs(c("herbs"), seed=9),
        "hushfern_fronds": lambda: frond(c("hushfern_fronds"), n=10, length=2.4, leaflet=0.9, leaflet_w=0.28, bend=0.12, taper=0.85, seed=10),
        "marjoram": lambda: sprig(c("marjoram"), "oval", pairs=4, leaf_len=0.62, leaf_w=0.44, seed=11),
        "mint": lambda: sprig(c("mint"), "oval", pairs=3, leaf_len=0.9, leaf_w=0.6, teeth=1, seed=12),
        "mugwort": lambda: leaf_bunch(c("mugwort"), "lance", n=5, length=1.6, width=0.4, teeth=2, seed=13),
        "palm_fronds": lambda: frond(c("palm_fronds"), n=11, length=2.2, leaflet=1.3, leaflet_w=0.26, bend=0.3, sweep=32.0, taper=0.3, seed=14),
        "plantain_leaves": lambda: rosette(c("plantain_leaves"), seed=15),
        "raspberry_leaves": lambda: trefoil(c("raspberry_leaves"), seed=16),
        "rosemary": lambda: needles(c("rosemary"), twig=(110, 90, 60), seed=17),
        "sage": lambda: sprig(c("sage"), "oval", pairs=3, leaf_len=1.0, leaf_w=0.5, seed=18),
        "samphire": lambda: jointed_shoots(c("samphire"), seed=19),
        "sorrel_leaves": lambda: leaf_bunch(c("sorrel_leaves"), "arrow", n=3, length=1.6, width=0.62, seed=20),
        "sunsilver_leaves": lambda: vine_leaves(c("sunsilver_leaves"), seed=21),
        "thyme": lambda: tiny_leaf_twigs(c("thyme"), seed=22),
        "tideglass_fronds": lambda: ribbons(c("tideglass_fronds"), seed=23),
        "truthsage_leaves": lambda: sprig(c("truthsage_leaves"), "lance", pairs=3, leaf_len=1.05, leaf_w=0.42, seed=24),
        "watercress": lambda: round_leaflets(c("watercress"), seed=25),
        "whisperfern_fronds": lambda: frond(c("whisperfern_fronds"), n=14, length=2.4, leaflet=0.62, leaflet_w=0.16, bend=0.75, sweep=50.0, seed=26)
        + moved(frond(shade(c("whisperfern_fronds"), 0.9), n=10, length=1.8, leaflet=0.5, leaflet_w=0.14, bend=0.8, sweep=50.0, seed=27),
                shift=(0.5, -0.1, -0.05)),
        "wild_garlic_leaves": lambda: ramsons(c("wild_garlic_leaves"), seed=27),
        "witness_leaves": lambda: leaf_bunch(c("witness_leaves"), "oval", n=2, length=1.9, width=1.0, spread=(30.0, 70.0), seed=28),
        # flowers
        "arnica_flowers": lambda: daisy(c("arnica_flowers"), centre=(214, 130, 30), n=12, petal=0.72, width=0.2, seed=30),
        "brinebells": lambda: bells(c("brinebells"), n=4, seed=31),
        "chamomile_flowers": lambda: daisy(c("chamomile_flowers"), n=16, petal=0.5, width=0.16, disc=0.26, dome=1.0,
                                           heads=((0.1, 0.2, 1.0), (-0.6, -0.4, 0.75), (0.5, -0.55, 0.6)), seed=32),
        "dandelion_flowers": lambda: pompom(c("dandelion_flowers"), seed=33),
        "duskmallow_flowers": lambda: star(c("duskmallow_flowers"), centre=(236, 220, 236), petal=0.75, width=0.6, shape="round", seed=34),
        "elderflowers": lambda: elder(c("elderflowers"), seed=35),
        "feverfew": lambda: daisy(c("feverfew"), n=10, petal=0.36, width=0.2, disc=0.28, dome=0.8,
                                  heads=((0.15, 0.3, 1.0), (-0.55, -0.15, 0.85), (0.4, -0.5, 0.75), (-0.2, 0.8, 0.6)), seed=36),
        "frostglass_petals": lambda: lily(c("frostglass_petals"), n=5, petal=0.95, width=0.6, centre=(240, 250, 255), seed=37),
        "gloaming_star": lambda: star(c("gloaming_star"), centre=(255, 236, 160), petal=0.9, width=0.36, shape="lance", seed=38),
        "gloomthistle_heads": lambda: thistle(c("gloomthistle_heads"), seed=39),
        "hawthorn_blossom": lambda: star(c("hawthorn_blossom"), centre=(196, 90, 110), petal=0.42, width=0.4, shape="round", stamens=8,
                                         heads=((0.1, 0.25, 1.0), (-0.55, -0.2, 0.85), (0.5, -0.4, 0.8), (-0.1, -0.7, 0.7)), seed=40),
        "honey_flowers": lambda: spikes(c("honey_flowers"), seed=41),
        "lavender_flowers": lambda: spikes(c("lavender_flowers"), n=4, seed=42),
        "meadowsweet_flowers": lambda: plume(c("meadowsweet_flowers"), seed=43),
        "mournbloom_petals": lambda: loose_petals(c("mournbloom_petals"), rim=(132, 108, 156), seed=44),
        "nightcrown_blooms": lambda: lily(c("nightcrown_blooms"), n=8, petal=1.1, width=0.5, layers=2, centre=(232, 226, 255),
                                           rim=(120, 110, 180), seed=45),
        "owlpetals": lambda: loose_petals(c("owlpetals"), spots=(40, 30, 50), seed=46),
        "quenchbell_heads": lambda: cups(c("quenchbell_heads"), seed=47),
        "rose_petals": lambda: loose_petals(c("rose_petals"), seed=48),
        "sevenyear_blossoms": lambda: lily(c("sevenyear_blossoms"), n=6, petal=1.2, width=0.46, seed=49),
        "st_johns_wort": lambda: star(c("st_johns_wort"), centre=(214, 150, 20), petal=0.6, width=0.36, stamens=12, seed=50),
        "stillwater_petals": lambda: lily(c("stillwater_petals"), n=8, petal=1.0, width=0.48, layers=3, centre=(250, 220, 120), seed=51),
        "wispbloom_heads": lambda: seed_clock(c("wispbloom_heads"), seed=52),
        "yarrow": lambda: yarrow_heads(c("yarrow"), seed=53),
        # roots
        "angelica_roots": lambda: root_bunch(c("angelica_roots"), n=5, thick=0.16, seed=60),
        "burdock_roots": lambda: taproot(c("burdock_roots"), length=2.8, thick=0.24, seed=61),
        "comfrey_roots": lambda: root_pieces(c("comfrey_roots"), seed=62),
        "dandelion_roots": lambda: with_top(taproot(c("dandelion_roots"), length=2.4, thick=0.22, n=2, top=False, seed=63), c("dandelion_leaves"),
                                            toothed=True, seed=63),
        "duskmallow_roots": lambda: root_bunch(c("duskmallow_roots"), seed=64),
        "emberroots": lambda: root_bunch(c("emberroots"), n=6, glow=True, seed=65),
        "heartroots": lambda: knotted(c("heartroots"), seed=66),
        "marrowroots": lambda: taproot(c("marrowroots"), length=2.2, thick=0.42, rootlets=4, seed=67),
        "sevenyear_bulbs": lambda: bulbs(c("sevenyear_bulbs"), n=1, size=0.8, seed=68),
        "valerian_roots": lambda: root_bunch(c("valerian_roots"), n=9, seed=69),
        "wild_carrot_roots": lambda: with_top(taproot(c("wild_carrot_roots"), length=2.4, thick=0.15, n=2, top=False, seed=70), (100, 150, 70),
                                              feathery=True, seed=70),
        "wild_garlic_bulbs": lambda: bulbs(c("wild_garlic_bulbs"), n=3, seed=71),
        "wolfsbane_roots": lambda: turnip_root(shade(c("wolfsbane_roots"), 1.35), seed=72),
    }


PIECES = _plants()
NAMES = tuple(PIECES)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=os.path.join(ROOT, "assets", "ui", "item_icons"))
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    only = set(filter(None, args.only.split(",")))

    for name, build in PIECES.items():
        if only and name not in only:
            continue

        path = os.path.join(args.out, name + ".png")
        render(build(), FACE, colour_jitter=0.03, seed=len(name)).save(path)
        print("painted", path)


if __name__ == "__main__":
    main()
