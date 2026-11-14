#!/usr/bin/env python3
"""Paint the small items the bake draws too thin or too alike to read at slot size (Kathleen, 9 Nov 2026).

At the 1366 x 768 floor a recipe-list icon is 23 screen px and a hotbar icon 43 (docs/ui/item_icons.md), and the bake's spears,
arrows and stick shrink to hairlines there while its spades, grain seeds and pies come out as one picture each. These are painted
to the same rig as tools/paint_structure_icons.py, with three rules for small sizes (the bone needle, 10 Nov 2026, the same way):
  - thin things are drawn thick, on the diagonal, with an oversized head: the head is what tells them apart;
  - each item in a set has its own colour that survives at 23 px (spade blades wood, stone, iron, steel; each grain its own plant);
  - a set shares one layout, so the family still reads as one (every grain is a seed pile with its plant behind it).

    python3 tools/paint_item_icons.py [--out assets/ui/item_icons] [--only id,id]
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paint_basic_icons import prism, rot_x, rot_y, rot_z   # noqa: E402  (the shared rig)
from paint_structure_icons import _outward, box, moved, render, shade   # noqa: E402

# Colours (look doc 6.1 warm palette).
WOOD = (196, 160, 108)
WOOD_END = (232, 206, 160)
BARK = (128, 92, 58)
CHAR = (52, 36, 26)
CORD = (92, 66, 40)
STONE = (150, 144, 134)
FLINT = (112, 112, 118)
BONE = (236, 226, 198)
IRON = (82, 86, 96)
STEEL = (200, 208, 218)
LEATHER = (110, 64, 38)
FEATHER = (238, 234, 222)
FEATHER_BAND = (120, 92, 70)
FIBRE = (150, 168, 92)
LEAF = (98, 140, 62)
CRUST = (222, 170, 92)
CRUST_DARK = (176, 116, 56)


# ---------------------------------------------------------------- shapes
def _basis(d):
    """A rotation taking +x to the direction d."""
    x = np.array(d, dtype=float)
    x = x / np.linalg.norm(x)
    helper = np.array([0.0, 0.0, 1.0]) if abs(x[2]) < 0.9 else np.array([0.0, 1.0, 0.0])
    y = np.cross(helper, x)
    y = y / np.linalg.norm(y)
    return np.column_stack([x, y, np.cross(x, y)])


def rod(a, b, radius, colour, end=None, sides=7, taper=1.0, seed=0):
    """A faceted rod from point a to point b (its far end narrowed by taper)."""
    a, b = np.array(a, dtype=float), np.array(b, dtype=float)
    faces = prism(radius, float(np.linalg.norm(b - a)), sides, colour, end or shade(colour, 1.15), taper=taper, seed=seed)
    return moved(faces, turn=_basis(b - a), shift=(a + b) / 2.0)


def blob(centre, radii, colour, seed=0, seg=8, rings=5, rough=0.08):
    """A low-poly ellipsoid: a grain, a fish head, a seed."""
    rng = np.random.default_rng(seed)
    c = np.array(centre, dtype=float)
    r = np.array(radii, dtype=float)
    top, bottom = c + np.array([0.0, r[1], 0.0]), c - np.array([0.0, r[1], 0.0])
    grid = []

    for i in range(1, rings):
        phi = math.pi * i / rings
        row = []

        for j in range(seg):
            th = 2.0 * math.pi * j / seg
            k = 1.0 + rng.uniform(-rough, rough)
            row.append(c + k * r * np.array([math.sin(phi) * math.cos(th), math.cos(phi), math.sin(phi) * math.sin(th)]))

        grid.append(row)

    faces = []

    for j in range(seg):
        n = (j + 1) % seg
        faces.append((_outward([top, grid[0][j], grid[0][n]], c), colour))
        faces.append((_outward([bottom, grid[-1][n], grid[-1][j]], c), colour))

        for i in range(len(grid) - 1):
            faces.append((_outward([grid[i][j], grid[i + 1][j], grid[i + 1][n], grid[i][n]], c), colour))

    return faces


def point(base, tip, width, thick, colour, back=0.35, roll=40.0):
    """A flaked blade or arrowhead: a flat bipyramid from base to tip, widest a third of the way along. Its flat face is rolled
    toward the key light (roll, degrees), or a blade lying on the diagonal faces the viewer but not the light and comes out dark."""
    base, tip = np.array(base, dtype=float), np.array(tip, dtype=float)
    turn = _basis(tip - base)
    wide = base + (tip - base) * back
    r = math.radians(roll)
    face_y, face_z = turn[:, 1] * math.cos(r) - turn[:, 2] * math.sin(r), turn[:, 1] * math.sin(r) + turn[:, 2] * math.cos(r)
    side, up = face_y * width / 2.0, face_z * thick / 2.0
    ring = [wide + side, wide + up, wide - side, wide - up]
    centre = base + (tip - base) * back
    faces = []

    for i in range(4):
        j = (i + 1) % 4
        lit = colour if i in (0, 1) else shade(colour, 0.9)
        faces.append((_outward([tip, ring[i], ring[j]], centre), lit))
        faces.append((_outward([base - (tip - base) * 0.02, ring[j], ring[i]], centre), shade(colour, 0.85)))

    return faces


def vane(a, b, height, colour, normal):
    """A fletching vane: a thin box from a to b standing out along normal."""
    a, b, nrm = np.array(a, dtype=float), np.array(b, dtype=float), np.array(normal, dtype=float)
    turn = _basis(b - a)
    local = turn.T @ nrm
    size = np.array([float(np.linalg.norm(b - a)), 0.02, 0.02]) + np.abs(local) * height
    return moved(box((0.0, 0.0, 0.0), size, colour), turn=turn, shift=(a + b) / 2.0 + nrm * height / 2.0)


def leaf(centre, direction, length, width, colour):
    """A flat leaf seen from both sides."""
    c, d = np.array(centre, dtype=float), np.array(direction, dtype=float)
    turn = _basis(d)
    tip, back = c + turn[:, 0] * length / 2.0, c - turn[:, 0] * length / 2.0
    s = turn[:, 2] * width / 2.0
    quad = [back, c + s, tip, c - s]
    return [(quad, colour), (quad[::-1], shade(colour, 0.85))]


# ---------------------------------------------------------------- long things, drawn on the diagonal
# The model turn that cancels the bake's yaw so a piece built along x lies corner to corner on the icon.
DIAGONAL = rot_y(math.radians(35.0)) @ rot_z(math.radians(42.0))


def stone_spear():
    faces = rod((-1.3, 0, 0), (0.85, 0, 0), 0.1, WOOD, seed=1)
    faces += point((0.7, 0, 0), (1.65, 0, 0), 0.54, 0.07, STONE)
    faces += rod((0.6, 0, 0), (0.86, 0, 0), 0.13, CORD, sides=8, seed=2)
    return faces


def wooden_spear():
    faces = rod((-1.3, 0, 0), (0.95, 0, 0), 0.115, WOOD, seed=3)
    faces += rod((0.95, 0, 0), (1.6, 0, 0), 0.115, CHAR, end=CHAR, taper=0.05, seed=4)   # the fire-hardened point
    faces += rod((-1.3, 0, 0), (-1.0, 0, 0), 0.1, BARK, seed=5)                          # bark left at the butt
    return faces


def arrow(head, fletch, seed):
    """One arrow along x, tip at +x."""
    faces = rod((-1.1, 0, 0), (0.9, 0, 0), 0.05, WOOD, seed=seed)

    if head == "wood":
        faces += rod((0.9, 0, 0), (1.3, 0, 0), 0.06, CHAR, end=CHAR, taper=0.05, seed=seed + 1)
    else:
        colour = {"bone": BONE, "stone": STONE}[head]
        faces += point((0.8, 0, 0), (1.42, 0, 0), 0.42, 0.05, colour)
        faces += rod((0.78, 0, 0), (0.9, 0, 0), 0.07, CORD, sides=6, seed=seed + 2)

    feather, band = fletch
    for nrm in ((0, 1, 0), (0, -0.5, 0.87), (0, -0.5, -0.87)):
        faces += vane((-1.08, 0, 0), (-0.62, 0, 0), 0.17, feather, nrm)
        if band:
            faces += vane((-0.9, 0, 0), (-0.82, 0, 0), 0.175, band, nrm)
    return faces


def arrows(head, fletch):
    """Three arrows fanned out, so the slot shows a sheaf and not a hairline."""
    faces = []

    for k, angle in enumerate((-11.0, 0.0, 11.0)):
        faces += moved(arrow(head, fletch, seed=10 * k + 7), turn=rot_z(math.radians(angle)), shift=(0.0, 0.0, 0.12 * (k - 1)))
    return faces


def stick():
    faces = prism(0.15, 2.3, 7, (150, 112, 72), WOOD_END, bend=0.12, taper=0.75, seed=5)
    faces += rod((0.2, 0.05, 0), (0.75, 0.5, 0.05), 0.085, (150, 112, 72), end=WOOD_END, taper=0.6, seed=6)
    faces += leaf((0.98, 0.7, 0.05), (1.0, 0.4, 0.6), 0.6, 0.34, LEAF)
    faces += leaf((0.78, 0.78, -0.08), (0.2, 1.0, 0.5), 0.55, 0.3, shade(LEAF, 0.9))
    return faces


def sewing_needle():
    """Bone - Needle: a thick bone needle on the diagonal, its eye a split butt you can see through, a loop of sinew thread through it."""
    faces = rod((-0.55, 0, 0), (0.85, 0, 0), 0.19, BONE, seed=21)
    faces += rod((0.85, 0, 0), (1.6, 0, 0), 0.19, BONE, end=BONE, taper=0.08, seed=22)        # the point
    for side in (-1.0, 1.0):                                                                 # the eye: two prongs either side of a slot
        faces += rod((-0.5, 0.13 * side, 0), (-1.25, 0.13 * side, 0), 0.075, shade(BONE, 0.94), sides=6, seed=23)
    faces += rod((-1.25, -0.2, 0), (-1.25, 0.2, 0), 0.08, BONE, sides=6, seed=24)            # the eye's end
    loop = [(-0.9 - 0.32 * math.sin(t), 0.42 * (1.0 - math.cos(t)), 0.14 * math.sin(t)) for t in np.linspace(0.0, 2.0 * math.pi, 11)]
    for k in range(len(loop) - 1):                                                           # the thread, out of the eye and back
        faces += rod(loop[k], loop[k + 1], 0.06, (150, 104, 62), sides=5, seed=30 + k)
    return faces


# ---------------------------------------------------------------- items that had no icon (10 Nov 2026)
def charcoal():
    """Charcoal: split sticks burnt black, in a heap, their ends grey with the wood's rings still in them (coal is a lump; this is wood)."""
    faces = []
    for k, (a, b) in enumerate((((-1.0, -0.2, 0.3), (0.7, -0.35, 0.5)), ((-0.6, -0.25, -0.45), (1.0, -0.2, -0.1)),
                                ((-0.8, 0.12, 0.0), (0.8, 0.05, 0.25)), ((-0.3, 0.38, -0.2), (0.95, 0.3, 0.1)))):
        faces += rod(a, b, 0.24 - 0.02 * k, (74, 68, 64), end=(138, 130, 122), sides=6, seed=40 + k)
    for k, at in enumerate(((1.05, -0.45, 0.45), (-1.05, -0.4, -0.25))):                     # two broken bits
        faces += blob(at, (0.18, 0.14, 0.16), (84, 78, 74), seed=46 + k, seg=6, rings=3, rough=0.2)
    return faces


def wool_cloth():
    """Wool cloth: a bolt folded in three, cream, each fold edge a shade darker, tied round with a cord."""
    cream = (226, 214, 186)
    faces = []
    for k in range(3):
        faces += box((0.04 * k, -0.3 + 0.24 * k, -0.03 * k), (2.1, 0.22, 1.3), shade(cream, 1.0 - 0.05 * (2 - k)))
        faces += box((1.06 + 0.04 * k, -0.3 + 0.24 * k, -0.03 * k), (0.06, 0.2, 1.28), shade(cream, 0.82))   # the fold
    faces += box((-0.4, 0.06, -0.03), (0.12, 0.8, 1.36), CORD)
    return faces


def fur():
    """Fur: a whole pelt laid flat, its outline the stretched skin (four leg corners, a neck, a tail), thick dark tufts over the top."""
    brown = (128, 92, 58)
    faces = blob((0.0, 0.0, 0.0), (1.0, 0.1, 0.62), brown, seed=50, seg=12, rings=5, rough=0.1)
    for k, (x, z) in enumerate(((-0.72, 0.5), (0.68, 0.5), (-0.72, -0.5), (0.68, -0.5))):
        faces += blob((x, -0.01, z), (0.36, 0.08, 0.3), brown, seed=52 + k, seg=8, rings=3, rough=0.1)   # the leg corners
    faces += blob((1.08, -0.01, 0.0), (0.3, 0.08, 0.24), brown, seed=56, seg=8, rings=3, rough=0.1)       # the neck
    faces += blob((-1.2, -0.01, 0.0), (0.36, 0.07, 0.11), shade(brown, 0.85), seed=57, seg=6, rings=3, rough=0.1)   # the tail
    rng = np.random.default_rng(58)
    for k in range(14):                                                                       # tufts of guard hair
        faces += blob((rng.uniform(-0.8, 0.8), 0.08, rng.uniform(-0.45, 0.45)), (0.16, 0.05, 0.08), shade(brown, rng.uniform(0.7, 1.15)),
                      seed=60 + k, seg=5, rings=2, rough=0.2)
    return faces


def crystal_lens():
    """Crystal lens: a clear round lens ground convex on both faces and a darker rim. The rig's warm light greys it, so _glass() brightens
    it after the render and lays a white window highlight on it: it reads as glass and not a grey pebble at hotbar size."""
    glass = (206, 232, 240)
    faces = rod((-0.08, 0, 0), (0.08, 0, 0), 0.82, (112, 150, 162), end=glass, sides=16, seed=60)   # the rim
    for side in (-1.0, 1.0):
        faces += blob((0.08 * side, 0.0, 0.0), (0.1, 0.74, 0.74), glass, seed=61, seg=14, rings=5, rough=0.0)
    return faces


def spyglass():
    """Wooden - Spyglass: a turned wooden tube, a narrower draw tube out of it, bronze bands at the joins and ends, glass in the big end."""
    bronze = (184, 132, 70)
    faces = rod((-1.3, 0, 0), (0.35, 0, 0), 0.26, WOOD, end=WOOD_END, sides=10, seed=62)
    faces += rod((0.35, 0, 0), (1.35, 0, 0), 0.19, shade(WOOD, 1.1), end=WOOD_END, sides=10, seed=63)
    for x0, x1, r in ((-1.34, -1.12, 0.3), (0.22, 0.42, 0.29), (1.2, 1.38, 0.22)):
        faces += rod((x0, 0, 0), (x1, 0, 0), r, bronze, end=shade(bronze, 1.15), sides=10, seed=64)
    faces += blob((-1.36, 0.0, 0.0), (0.03, 0.22, 0.22), (176, 212, 222), seed=65, seg=10, rings=4, rough=0.0)   # the glass
    return faces


# ---------------------------------------------------------------- item system C1 (#933, 10 Nov 2026)
def _path(points, radii, colours, sides=7, seed=0):
    """A bent tube through points, its radius and colour per point (each segment tapers to the next)."""
    faces = []
    for k in range(len(points) - 1):
        faces += rod(points[k], points[k + 1], radii[k], colours[k], sides=sides, taper=radii[k + 1] / radii[k], seed=seed + k)
    return faces


def horn():
    """Horn: a hollow horn curling up to a dark tip, ridged, its open base toward the viewer."""
    n = 9
    pts = [(-1.0 + 1.9 * t - 0.25 * t * t, 0.9 * math.sin(math.pi * 0.85 * t) - 0.3, 0.2 * t) for t in np.linspace(0.0, 1.0, n)]
    radii = [0.36 * (1.0 - t) + 0.035 for t in np.linspace(0.0, 1.0, n)]
    cols = [tuple(int(a + (b - a) * t) for a, b in zip((206, 190, 158), (64, 52, 42))) for t in np.linspace(0.0, 1.0, n)]
    faces = _path(pts, radii, cols, sides=9, seed=70)
    faces += rod((-1.02, -0.3, 0.0), (-0.98, -0.3, 0.0), 0.3, (58, 46, 38), sides=9, seed=79)   # the hollow
    return faces


def gut():
    """Gut: a cleaned length of intestine coiled flat, pale pink."""
    pts = [(math.cos(a) * (0.95 - 0.07 * a), 0.06 * math.sin(a * 3.0), math.sin(a) * (0.95 - 0.07 * a)) for a in np.linspace(0.0, 4.2 * math.pi, 34)]
    cols = [(214, 168, 150) if k % 2 == 0 else (198, 150, 134) for k in range(len(pts))]
    return _path(pts, [0.12] * len(pts), cols, sides=6, seed=80)


def toggle():
    """Toggle: a short bone peg, round ends, a cut groove round its middle where the cord goes."""
    faces = rod((-0.8, 0, 0), (-0.1, 0, 0), 0.22, BONE, seed=90) + rod((0.1, 0, 0), (0.8, 0, 0), 0.22, BONE, seed=91)
    faces += rod((-0.1, 0, 0), (0.1, 0, 0), 0.15, shade(BONE, 0.7), seed=92)
    for side in (-1.0, 1.0):
        faces += blob((0.8 * side, 0, 0), (0.1, 0.22, 0.22), BONE, seed=93, seg=8, rings=3, rough=0.0)
    faces += rod((0.0, 0.0, 0.0), (0.0, 0.62, 0.3), 0.04, CORD, sides=5, seed=94)          # the cord out of the groove
    return faces


def hook():
    """Hook: a bone fish hook, a straight shank, the bend and the barbed point, a twine whipping at the eye."""
    faces = rod((0.0, 1.1, 0), (0.0, -0.35, 0), 0.11, BONE, seed=100)
    bend = [(0.38 - 0.38 * math.cos(a), -0.35 - 0.38 * math.sin(a), 0.0) for a in np.linspace(0.0, math.pi, 8)]
    faces += _path(bend, [0.11] * 8, [BONE] * 8, sides=7, seed=101)
    faces += rod((0.76, -0.35, 0), (0.76, 0.25, 0), 0.1, BONE, end=BONE, taper=0.1, seed=110)   # the point
    faces += rod((0.76, 0.0, 0), (0.6, 0.12, 0), 0.05, BONE, taper=0.1, seed=111)             # the barb
    faces += rod((0.0, 0.85, 0), (0.0, 1.1, 0), 0.14, CORD, sides=7, seed=112)
    return faces


def bone_club():
    """Bone - Club: a heavy leg bone, its knuckle end the head, twine bound round the grip."""
    faces = rod((-1.2, 0, 0), (0.95, 0, 0), 0.17, BONE, seed=120)
    for k, z in enumerate((-0.17, 0.17)):
        faces += blob((1.08, 0.02, z), (0.28, 0.27, 0.24), shade(BONE, 0.97 + 0.05 * k), seed=121 + k, seg=8, rings=4, rough=0.08)   # the knuckle
    faces += blob((-1.28, 0, 0), (0.18, 0.22, 0.22), BONE, seed=123, seg=7, rings=3, rough=0.08)
    faces += rod((-1.12, 0, 0), (-0.45, 0, 0), 0.2, CORD, sides=8, seed=124)                   # the grip binding
    return faces


def wooden_longbow():
    """Wooden - Longbow: one tall stave bent in a shallow arc, thick at the leather grip and thin at the tips, a sinew string tip to tip."""
    n = 11
    pts = [(-1.65 + 3.3 * t, 0.5 * math.sin(math.pi * t), 0.0) for t in np.linspace(0.0, 1.0, n)]
    radii = [0.06 + 0.07 * math.sin(math.pi * t) for t in np.linspace(0.0, 1.0, n)]
    faces = _path(pts, radii, [WOOD] * n, sides=7, seed=130)
    faces += rod((-0.18, 0.5, 0), (0.18, 0.5, 0), 0.15, LEATHER, sides=8, seed=141)            # the grip
    faces += rod((-1.62, 0.02, 0), (1.62, 0.02, 0), 0.025, (232, 222, 196), sides=5, seed=142) # the string
    return faces


def straw_hat():
    """Straw - Hat: a wide plaited brim, a round crown, a twine band."""
    straw = (214, 184, 112)
    faces = rod((0, -0.05, 0), (0, 0.05, 0), 1.25, straw, end=shade(straw, 1.08), sides=16, seed=150)
    faces += rod((0, 0.05, 0), (0, 0.42, 0), 0.6, shade(straw, 0.95), end=straw, sides=14, taper=0.9, seed=151)
    faces += blob((0, 0.42, 0), (0.54, 0.16, 0.54), straw, seed=152, seg=14, rings=4, rough=0.03)
    faces += rod((0, 0.07, 0), (0, 0.18, 0), 0.62, CORD, sides=14, seed=153)                   # the band
    return faces


def worm():
    """Worm: a fat earthworm in an S, ringed, the saddle band paler."""
    n = 14
    pts = [(-1.3 + 2.6 * t, 0.06 * math.sin(6.0 * t), 0.5 * math.sin(2.0 * math.pi * t)) for t in np.linspace(0.0, 1.0, n)]
    radii = [0.06 + 0.08 * math.sin(math.pi * min(1.0, t * 1.15)) for t in np.linspace(0.0, 1.0, n)]
    cols = [(226, 160, 150) if k in (4, 5) else ((190, 112, 104) if k % 2 == 0 else (176, 100, 94)) for k in range(n)]
    return _path(pts, radii, cols, sides=7, seed=160)


# ---------------------------------------------------------------- spades: one shape, four blades
def spade(material):
    """A spade along x, blade at +x; the blade (big, face to the viewer) carries the material."""
    shaft = LEATHER if material == "steel" else WOOD
    faces = rod((-1.15, 0, 0), (0.45, 0, 0), 0.07, WOOD, seed=21)
    faces += rod((-1.15, -0.2, 0), (-1.15, 0.2, 0), 0.06, WOOD, seed=22)          # the D grip
    faces += rod((-1.15, 0.2, 0), (-0.85, 0.05, 0), 0.05, WOOD, seed=23)
    faces += rod((-1.15, -0.2, 0), (-0.85, -0.05, 0), 0.05, WOOD, seed=24)

    if material == "steel":
        faces += rod((-0.85, 0, 0), (-0.55, 0, 0), 0.085, shaft, seed=25)            # a leather grip wrap

    if material == "wood":
        faces += box((0.8, 0, 0), (0.7, 0.5, 0.07), WOOD)
        faces += point((1.1, 0, 0), (1.3, 0, 0), 0.5, 0.07, WOOD, back=0.0, roll=0.0)
    elif material == "stone":
        faces += point((0.4, 0, 0), (1.35, 0, 0), 0.62, 0.12, STONE, back=0.45, roll=0.0)
        for x in (0.42, 0.55):
            faces += rod((x, 0, 0), (x + 0.07, 0, 0), 0.1, CORD, sides=6, seed=26)
    else:
        metal = IRON if material == "iron" else STEEL
        faces += rod((0.38, 0, 0), (0.6, 0, 0), 0.09, shade(metal, 0.85), sides=6, seed=27)   # the socket
        faces += box((0.88, 0, 0), (0.6, 0.6, 0.05), metal)
        faces += point((1.16, 0, 0), (1.34, 0, 0), 0.6, 0.05, metal, back=0.0, roll=0.0)
        edge = (150, 156, 166) if material == "iron" else (248, 250, 255)
        faces += box((1.2, 0.0, 0.03), (0.08, 0.58, 0.02), edge)                      # the worked edge catches the light
    return faces


SPADE_VIEW = rot_y(math.radians(35.0)) @ rot_x(math.radians(-62.0)) @ rot_z(math.radians(40.0))


# ---------------------------------------------------------------- grain seeds: a pile in front, the plant behind
def seed_pile(colour, grain, seed):
    """A heap of grains at the front left, the same for every grain so the family reads as one."""
    rng = np.random.default_rng(seed)
    faces = []
    size = np.array(grain) * 1.7

    for k in range(30):
        a, r = rng.uniform(0, 2 * math.pi), 0.6 * math.sqrt(rng.uniform(0, 1))
        x, z = -0.45 + r * math.cos(a), 0.35 + r * math.sin(a)
        y = -0.85 + 0.26 * (1.0 - r / 0.6) + rng.uniform(0, 0.04)
        tint = shade(colour, rng.uniform(0.88, 1.08))
        faces += moved(blob((0, 0, 0), size, tint, seed=seed + k, seg=6, rings=4), turn=rot_y(rng.uniform(0, math.pi)), shift=(x, y, z))
    return faces


STALK = (0.42, -0.85, -0.2)


def stalk(colour, top, seed):
    return rod(STALK, (STALK[0], top, STALK[2]), 0.045, shade(colour, 0.8), seed=seed)


def ear(colour, length, plump, awns, seed):
    """A grain head on a short stalk: pairs of plump grains, with awns for barley and rye."""
    faces = stalk(colour, 0.05, seed)
    n = 5

    for i in range(n):
        y = 0.08 + i * length / n
        taper = 1.0 - 0.35 * (i / n) ** 2

        for side in (-1, 1):
            c = (STALK[0] + side * plump * 0.85 * taper, y, STALK[2])
            faces += moved(blob((0, 0, 0), (plump * taper, plump * 1.6, plump * taper), shade(colour, 1.0 if side < 0 else 0.9),
                                seed=seed + i * 2 + side, seg=6, rings=4), turn=rot_z(math.radians(-side * 16.0)), shift=c)
            if awns:
                faces += rod(c, (c[0] + side * 0.16, c[1] + awns, c[2]), 0.02, shade(colour, 0.9), sides=4, seed=seed)
    return faces


def oat_head(colour, seed):
    """Oats hang: spikelets dangling off short arms."""
    faces = stalk(colour, 0.85, seed)

    for i, (dx, y) in enumerate(((-0.34, 0.72), (0.34, 0.66), (-0.36, 0.36), (0.38, 0.3), (-0.3, 0.02), (0.32, -0.04))):
        tip = (STALK[0] + dx, y - 0.1, STALK[2])
        faces += rod((STALK[0], y + 0.06, STALK[2]), tip, 0.025, shade(colour, 0.8), sides=4, seed=seed)
        faces += blob((tip[0], tip[1] - 0.12, tip[2]), (0.1, 0.17, 0.09), shade(colour, 1.0 - 0.04 * (i % 2)), seed=seed + i, seg=6, rings=4)
    return faces


def flax_plant(seed):
    """Flax by its blue flowers."""
    faces = stalk(LEAF, 0.35, seed)
    faces += rod((STALK[0], 0.0, STALK[2]), (STALK[0] + 0.32, 0.3, STALK[2]), 0.035, LEAF, seed=seed)

    for c in ((STALK[0] - 0.05, 0.55, STALK[2]), (STALK[0] + 0.38, 0.48, STALK[2] + 0.05)):
        for k in range(5):
            a = 2.0 * math.pi * k / 5 + 0.3
            faces += leaf((c[0] + 0.19 * math.cos(a), c[1] + 0.19 * math.sin(a), c[2] + 0.02), (math.cos(a), math.sin(a), 0.0), 0.38, 0.28,
                          (92, 128, 214))
        faces += blob(c, (0.06, 0.06, 0.06), (236, 214, 120), seed=seed)
    return faces


def carrot(seed):
    """Carrot seed by the carrot it grows."""
    faces = rod((STALK[0] + 0.1, -0.8, STALK[2]), (STALK[0] - 0.05, 0.2, STALK[2]), 0.2, (232, 120, 40), end=(240, 150, 70), taper=0.2,
                seed=seed)
    for k, d in enumerate(((-0.35, 1.0, 0.0), (0.0, 1.0, 0.15), (0.4, 1.0, -0.1))):
        faces += leaf((STALK[0] - 0.05 + d[0] * 0.25, 0.48, STALK[2]), d, 0.62, 0.22, shade(LEAF, 1.0 - 0.06 * k))
    return faces


def parsnip(seed):
    """Parsnip (#940): the carrot's shape in cream, a little fatter at the shoulder, its leaves a paler green."""
    faces = rod((STALK[0] + 0.1, -0.8, STALK[2]), (STALK[0] - 0.05, 0.2, STALK[2]), 0.25, (232, 216, 170), end=(242, 232, 200), taper=0.15,
                seed=seed)
    for k, d in enumerate(((-0.35, 1.0, 0.0), (0.0, 1.0, 0.15), (0.4, 1.0, -0.1))):
        faces += leaf((STALK[0] - 0.05 + d[0] * 0.25, 0.48, STALK[2]), d, 0.62, 0.24, shade((120, 156, 74), 1.0 - 0.06 * k))
    return faces


def leaves(base, colour, n=3, length=0.7, width=0.22, spread=0.4, stem=None, seed=0):
    """A fan of leaves standing up out of a root, on stems when stem is a colour (beet's red stalks)."""
    faces = []
    b = np.array(base, dtype=float)

    for k in range(n):
        dx = spread * (k - (n - 1) / 2.0) / max(1.0, (n - 1) / 2.0)
        d = np.array([dx, 1.0, 0.1 * (k % 2)])
        if stem:
            faces += rod(b, b + d * length * 0.45, 0.03, stem, sides=5, seed=seed + k)
        faces += leaf(b + d * length * 0.55, d, length * (0.75 if stem else 1.0), width, shade(colour, 1.0 - 0.06 * k))
    return faces


ROOT = np.array([STALK[0], -0.25, STALK[2]])


def root_veg(colour, radii, tip_len, leaf_colour=LEAF, top=None, stem=None, seed=0):
    """A root crop: the root, its thin tail, a coloured shoulder (turnip) and its leaves."""
    faces = blob(ROOT, radii, colour, seed=seed, seg=8, rings=6)
    faces += rod(ROOT - np.array([0.0, radii[1] * 0.8, 0.0]), ROOT - np.array([0.0, radii[1] + tip_len, 0.0]), radii[0] * 0.3, colour,
                 taper=0.1, seed=seed + 1)
    if top:
        faces += blob(ROOT + np.array([0.0, radii[1] * 0.45, 0.0]), np.array(radii) * np.array([0.92, 0.6, 0.92]), top, seed=seed + 2,
                      seg=8, rings=5)
    faces += leaves(ROOT + np.array([0.0, radii[1] * 0.9, 0.0]), leaf_colour, stem=stem, seed=seed + 3)
    return faces


def cabbage(seed):
    faces = blob(ROOT + np.array([0.0, 0.1, 0.0]), (0.42, 0.38, 0.42), (132, 172, 96), seed=seed, seg=10, rings=6)

    for k in range(6):                                          # the loose outer leaves cupping the head
        a = 2.0 * math.pi * k / 6 + 0.4
        out = np.array([math.cos(a), 0.55, math.sin(a)])
        faces += leaf(ROOT + np.array([0.0, -0.05, 0.0]) + out * 0.42, out, 0.55, 0.42, shade((92, 136, 96), 1.0 - 0.04 * (k % 3)))
    return faces


def lettuce(seed):
    faces = []

    for ring, (n, tilt, size) in enumerate(((8, 0.55, 0.62), (6, 0.95, 0.5), (4, 2.0, 0.36))):
        for k in range(n):
            a = 2.0 * math.pi * k / n + ring * 0.5
            d = np.array([math.cos(a), tilt, math.sin(a)])
            colour = shade((160, 206, 92), 1.0 + 0.05 * ring - 0.04 * (k % 2))
            faces += leaf(ROOT + np.array([0.0, -0.2 + 0.1 * ring, 0.0]) + d / np.linalg.norm(d) * size * 0.5, d, size, size * 1.1, colour)
    return faces


def onion(seed):
    faces = blob(ROOT, (0.32, 0.3, 0.32), (206, 146, 72), seed=seed, seg=8, rings=6)
    faces += rod(ROOT + np.array([0.0, 0.2, 0.0]), ROOT + np.array([0.0, 0.48, 0.0]), 0.08, (196, 138, 70), taper=0.4, seed=seed + 1)
    for k, dx in enumerate((-0.18, 0.0, 0.2)):                 # green shoots
        faces += rod(ROOT + np.array([0.0, 0.42, 0.0]), ROOT + np.array([dx, 1.05 - 0.12 * abs(k - 1), 0.0]), 0.035, LEAF, sides=5,
                     taper=0.4, seed=seed + 2 + k)
    for k in range(4):                                          # the pale root tuft
        faces += rod(ROOT - np.array([0.0, 0.26, 0.0]), ROOT + np.array([-0.15 + 0.1 * k, -0.42, 0.0]), 0.015, (226, 212, 180), sides=4,
                     seed=seed + 6)
    return faces


def pea_pod(seed):
    pod = (124, 176, 72)
    faces = moved(blob((0, 0, 0), (0.55, 0.16, 0.12), pod, seed=seed, seg=8, rings=5), turn=rot_z(math.radians(30.0)), shift=tuple(ROOT))
    for k in range(4):                                          # the peas showing along the split
        t = -0.36 + 0.24 * k
        c = ROOT + np.array([t * math.cos(math.radians(30.0)), t * math.sin(math.radians(30.0)) + 0.1, 0.06])
        faces += blob(c, (0.1, 0.1, 0.1), (164, 210, 96), seed=seed + k, seg=6, rings=4)
    faces += rod(ROOT + np.array([0.47, 0.27, 0.0]), ROOT + np.array([0.62, 0.55, 0.0]), 0.025, shade(pod, 0.8), sides=5, seed=seed)
    return faces


def potato(seed):
    skin = (176, 130, 80)
    faces = blob(ROOT, (0.44, 0.3, 0.32), skin, seed=seed, seg=9, rings=6, rough=0.14)
    faces += blob(ROOT + np.array([0.3, -0.18, 0.3]), (0.24, 0.18, 0.2), shade(skin, 0.95), seed=seed + 1, seg=7, rings=5, rough=0.14)
    for k, (x, y) in enumerate(((-0.2, 0.12), (0.1, 0.2), (0.25, 0.02), (-0.05, -0.08))):      # eyes
        faces += blob(ROOT + np.array([x, y, 0.29]), (0.035, 0.035, 0.02), (110, 76, 46), seed=seed + 3 + k, seg=5, rings=3)
    return faces


VEG = {
    # id: (seed colour, seed radii, the plant)
    "beet_seeds": ((150, 108, 70), (0.07, 0.06, 0.07), lambda: root_veg((108, 22, 50), (0.34, 0.32, 0.34), 0.32, (104, 128, 62),
                                                                             stem=(170, 40, 60), seed=50)),
    "cabbage_seeds": ((92, 52, 42), (0.04, 0.04, 0.04), lambda: cabbage(51)),
    "lettuce_seeds": ((196, 190, 166), (0.065, 0.02, 0.025), lambda: lettuce(52)),
    "onion_seeds": ((48, 42, 40), (0.05, 0.03, 0.035), lambda: onion(53)),
    "peas_seeds": ((184, 196, 124), (0.07, 0.07, 0.07), lambda: pea_pod(54)),
    "potato_seeds": ((176, 132, 84), (0.07, 0.055, 0.06), lambda: potato(55)),
    "radish_seeds": ((142, 98, 62), (0.045, 0.045, 0.045), lambda: root_veg((236, 76, 104), (0.22, 0.22, 0.22), 0.3, top=None, seed=56)),
    "turnip_seeds": ((124, 72, 52), (0.04, 0.04, 0.04), lambda: root_veg((236, 230, 214), (0.34, 0.3, 0.34), 0.34, top=(150, 62, 124),
                                                                         seed=57)),
}


GRAINS = {
    # id: (seed colour, grain radii, the plant)
    "barley_seeds": ((222, 196, 128), (0.07, 0.04, 0.045), lambda: ear((228, 202, 122), 0.62, 0.1, 0.5, 40)),
    "wheat_seeds": ((204, 146, 64), (0.075, 0.05, 0.055), lambda: ear((214, 152, 52), 0.7, 0.13, 0.0, 41)),
    "oats_seeds": ((214, 208, 166), (0.085, 0.032, 0.04), lambda: oat_head((208, 206, 150), 42)),
    "rye_seeds": ((150, 140, 116), (0.08, 0.03, 0.035), lambda: ear((172, 170, 126), 0.8, 0.085, 0.4, 43)),
    "flax_seeds": ((140, 86, 44), (0.06, 0.03, 0.045), lambda: flax_plant(44)),
    "carrot_seeds": ((168, 132, 92), (0.05, 0.025, 0.04), lambda: carrot(45)),
    "parsnip_seeds": ((196, 170, 118), (0.07, 0.014, 0.06), lambda: parsnip(46)),   # flat papery seeds (#940)
}


def grain_seeds(item):
    """The pile at the front left, the plant leaning across the icon behind it, drawn large: at 23 px the plant's colour names the crop."""
    colour, grain, plant = {**GRAINS, **VEG}[item]
    lean = 1.25 * rot_z(math.radians(-28.0))
    base = np.array(STALK)
    return seed_pile(colour, grain, seed=len(item)) + [([lean @ (p - base) + base + np.array([-0.15, 0.0, 0.0]) for p in pts], c)
                                                       for pts, c in plant()]


SEED_VIEW = rot_y(math.radians(30.0))


# ---------------------------------------------------------------- pies: one dish, three tops
def dish(crust, rim_bumps=14):
    faces = moved(prism(1.0, 0.32, 16, shade(crust, 0.85), crust, seed=60), turn=rot_z(math.radians(90.0)), shift=(0, -0.1, 0))

    for k in range(rim_bumps):
        a = 2.0 * math.pi * k / rim_bumps
        faces += blob((0.95 * math.cos(a), 0.08, 0.95 * math.sin(a)), (0.12, 0.08, 0.12), shade(crust, 0.95), seed=61 + k, seg=6, rings=3)
    return faces


def apple_pie():
    faces = dish(CRUST)
    faces += moved(prism(0.86, 0.02, 16, (226, 214, 120), (226, 214, 120), seed=62), turn=rot_z(math.radians(90.0)), shift=(0, 0.07, 0))

    for k in (-0.5, 0.0, 0.5):                                  # a lattice over the pale apple
        faces += box((k, 0.11, 0), (0.16, 0.05, 1.7 * math.sqrt(max(0.0, 1.0 - k * k))), CRUST)
        faces += box((0, 0.13, k), (1.7 * math.sqrt(max(0.0, 1.0 - k * k)), 0.05, 0.16), shade(CRUST, 1.05))
    faces += blob((1.05, 0.15, 0.75), (0.32, 0.3, 0.32), (196, 44, 36), seed=63)          # a red apple beside it
    faces += rod((1.05, 0.42, 0.75), (1.1, 0.58, 0.75), 0.025, BARK, seed=64)
    faces += leaf((1.2, 0.52, 0.75), (1.0, 0.3, 0.0), 0.22, 0.12, LEAF)
    return faces


def fish_pie():
    faces = dish(CRUST)
    faces += moved(prism(0.9, 0.04, 16, CRUST, shade(CRUST, 1.06), seed=65), turn=rot_z(math.radians(90.0)), shift=(0, 0.08, 0))

    for k, (x, z) in enumerate(((-0.4, -0.25), (0.15, 0.3), (0.5, -0.35))):    # fish heads looking up through the crust
        tilt = rot_x(math.radians(8.0 * (k - 1))) @ rot_z(math.radians(10.0 * (k - 1)))
        head = blob((0, 0.42, 0), (0.15, 0.4, 0.12), (168, 182, 196), seed=66 + k, seg=6, rings=5)
        head += blob((0.0, 0.6, 0.11), (0.05, 0.05, 0.03), (24, 24, 28), seed=70 + k, seg=6, rings=3)   # the eye
        faces += moved(head, turn=tilt, shift=(x, 0.05, z))
    return faces


def venison_pie():
    crust = (176, 104, 50)                                      # a dark, long-baked crust
    faces = dish(crust)
    faces += moved(prism(0.9, 0.04, 16, crust, shade(crust, 1.08), seed=72), turn=rot_z(math.radians(90.0)), shift=(0, 0.08, 0))
    # a slice cut out, showing the dark meat
    wedge_c = np.array([0.55, 0.06, 0.3])
    faces += box(tuple(wedge_c), (0.7, 0.2, 0.5), (110, 40, 30))
    faces += box(tuple(wedge_c + np.array([0.0, 0.11, 0.0])), (0.66, 0.02, 0.46), (132, 52, 36))
    faces += leaf((-0.3, 0.13, -0.25), (1.0, 0.0, 0.4), 0.5, 0.24, shade(crust, 0.8))         # a pastry leaf on top
    return faces


PIE_VIEW = rot_y(math.radians(20.0)) @ rot_x(math.radians(14.0))


# ---------------------------------------------------------------- gathered materials the fire and the first shelter use (gathered.json)
def _bundle(n, length, radius, colours, spread, seed, tie=None, ties=(), fan=0.0):
    """Rods laid side by side along x in a loose round bundle, optionally tied; fan splays the far ends."""
    rng = np.random.default_rng(seed)
    faces = []

    for k in range(n):
        a, r = rng.uniform(0, 2 * math.pi), spread * math.sqrt(rng.uniform(0, 1))
        y, z = r * math.sin(a), r * math.cos(a)
        dx = rng.uniform(-0.08, 0.08) * length
        end = (length / 2 + dx, y * (1.0 + fan), z * (1.0 + fan))
        faces += rod((-length / 2 + dx, y, z), end, radius * rng.uniform(0.8, 1.2), colours[k % len(colours)], sides=5, seed=seed + k)

    for x in ties:
        faces += rod((x - 0.05, 0, 0), (x + 0.05, 0, 0), spread * (1.0 + fan * (x / length + 0.5)) + radius * 0.6, tie, sides=10, seed=seed)
    return faces


def kindling():
    """Thin split twigs in a little tied bundle: pale split faces and bark."""
    return _bundle(7, 1.5, 0.095, [(214, 184, 132), (130, 92, 56), (196, 164, 116)], 0.24, seed=80, tie=CORD, ties=(0.0,), fan=0.9)


def tinder():
    """A nest of fine dry grass and shavings that takes a spark."""
    rng = np.random.default_rng(81)
    faces = []

    for ring in range(3):
        r, y = 0.75 - 0.18 * ring, 0.06 * ring
        for k in range(16):
            a0 = 2.0 * math.pi * k / 16 + ring * 0.3 + rng.uniform(-0.1, 0.1)
            a1 = a0 + 0.55
            colour = [(216, 194, 138), (190, 160, 104), (232, 214, 164)][(k + ring) % 3]
            faces += rod((r * math.cos(a0), y + rng.uniform(0, 0.08), r * math.sin(a0)), (r * math.cos(a1), y + rng.uniform(0, 0.08), r * math.sin(a1)),
                         0.035, colour, sides=4, seed=81 + k)
    faces += blob((0, 0.0, 0), (0.42, 0.1, 0.42), (120, 92, 60), seed=82, seg=8, rings=4)      # the dark hollow
    for k in range(5):                                          # curled shavings on top
        a = 2.0 * math.pi * k / 5
        faces += moved(blob((0, 0, 0), (0.16, 0.05, 0.08), (236, 210, 160), seed=83 + k, seg=6, rings=3),
                       turn=rot_y(a), shift=(0.35 * math.cos(a), 0.14, 0.35 * math.sin(a)))
    return faces


def thatch():
    """A tight sheaf of reed tied in two places, cut square at one end and splayed at the other."""
    return _bundle(26, 2.1, 0.045, [(196, 166, 92), (176, 144, 76), (212, 184, 108)], 0.28, seed=84, tie=CORD, ties=(-0.55, 0.25), fan=0.7)


def straw():
    """A loose heap of pale stalks lying every way."""
    rng = np.random.default_rng(85)
    faces = []

    for k in range(34):
        a = rng.uniform(0, math.pi)
        c = np.array([rng.normal(0, 0.28), abs(rng.normal(0, 0.12)), rng.normal(0, 0.28)])
        d = np.array([math.cos(a), rng.uniform(-0.1, 0.25), math.sin(a)]) * rng.uniform(0.7, 1.0)
        colour = [(232, 212, 142), (214, 190, 116), (240, 224, 164)][k % 3]
        faces += rod(c - d * 0.6, c + d * 0.6, 0.035, colour, sides=4, seed=85 + k)
    return faces


def birch_bark():
    """A curled sheet of white bark, dark lenticel bands outside and tan inside."""
    faces = []
    outer, inner = (236, 232, 220), (204, 150, 102)
    n, width = 12, 1.6

    for k in range(n):                                          # a curl: the sheet rolls up from flat to most of a turn
        t0, t1 = k / n, (k + 1) / n
        a0, a1 = 1.6 * math.pi * t0, 1.6 * math.pi * t1
        r0, r1 = 0.55 - 0.25 * t0, 0.55 - 0.25 * t1
        p = [np.array([-width / 2, r0 * math.cos(a0), r0 * math.sin(a0)]), np.array([width / 2, r0 * math.cos(a0), r0 * math.sin(a0)]),
             np.array([width / 2, r1 * math.cos(a1), r1 * math.sin(a1)]), np.array([-width / 2, r1 * math.cos(a1), r1 * math.sin(a1)])]
        out = p if np.dot(np.cross(p[1] - p[0], p[3] - p[0]), (p[0] + p[2]) / 2 * np.array([0, 1, 1])) > 0 else p[::-1]
        faces.append((out, outer))
        faces.append((out[::-1], inner))

        if k % 3 == 1:                                          # dark lenticel dashes across the white
            for x in (-0.45, 0.1, 0.5):
                mid = (p[0] + p[3]) / 2 + np.array([x + width / 2, 0, 0])
                nrm = mid * np.array([0, 1, 1])
                nrm = nrm / np.linalg.norm(nrm)
                faces += box(tuple(mid + nrm * 0.012), (0.3, 0.02, 0.05), (60, 54, 50))
    return faces


def withies():
    """A coil of long thin willow shoots, green-brown."""
    faces = []
    colours = [(150, 132, 72), (122, 112, 58), (168, 146, 86)]

    for strand in range(5):
        r = 0.62 + 0.05 * strand
        pts = []
        for k in range(29):
            a = 2.0 * math.pi * 1.3 * k / 28 + strand * 0.7
            pts.append(np.array([r * math.cos(a), 0.035 * strand + 0.04 * math.sin(a * 2), r * math.sin(a)]))
        for a, b in zip(pts, pts[1:]):
            faces += rod(a, b, 0.032, colours[strand % 3], sides=5, seed=90 + strand)
    return faces


LYING = rot_y(math.radians(35.0)) @ rot_z(math.radians(28.0))   # a bundle lying corner to corner, tilted toward the viewer
HEAP_VIEW = rot_x(math.radians(18.0))


# ---------------------------------------------------------------- buildables and item system C4 (10 Nov 2026)
BRONZE = (184, 132, 70)
METALS = {"bronze": (BRONZE, (226, 176, 104)), "iron": (IRON, (150, 156, 166)), "steel": (STEEL, (248, 250, 255))}   # body, worked edge


def hammer(material):
    """A hammer of every tier in one layout, on the diagonal with its head big: the head tells them apart (a wooden mallet, a lashed
    stone, a bronze, iron or steel head with a broad face and a wedge peen, the face's worked edge bright)."""
    faces = rod((-1.2, 0, 0), (0.62, 0, 0), 0.085, WOOD, seed=100)

    if material == "steel":
        faces += rod((-1.2, 0, 0), (-0.75, 0, 0), 0.105, LEATHER, seed=101)                   # a leather grip wrap

    if material == "wooden":
        faces += rod((0.66, -0.5, 0), (0.66, 0.5, 0), 0.3, WOOD, end=WOOD_END, sides=8, seed=102)
    elif material == "stone":
        faces += blob((0.66, 0.02, 0.0), (0.3, 0.5, 0.27), STONE, seed=103, seg=8, rings=5, rough=0.12)
        for y in (-0.13, 0.13):
            faces += box((0.66, y, 0.0), (0.6, 0.07, 0.56), CORD)                              # the lashing, bound round the head
    else:
        metal, edge = METALS[material]
        faces += box((0.66, 0.08, 0.0), (0.34, 0.8, 0.34), metal)
        faces += box((0.66, 0.53, 0.0), (0.42, 0.12, 0.42), shade(metal, 1.08))               # the striking face
        faces += box((0.66, 0.6, 0.0), (0.4, 0.02, 0.4), edge)
        faces += point((0.66, -0.3, 0), (0.66, -0.72, 0), 0.34, 0.12, metal, back=0.0, roll=0.0)   # the peen
    return faces


def chisel(material):
    """Tier - Chisel (the Stonecutter's bench): a turned wooden handle, a ferrule, a square shank and a flat blade with a bright edge."""
    metal, edge = METALS[material]
    faces = rod((-1.25, 0, 0), (-0.25, 0, 0), 0.14, WOOD, end=WOOD_END, sides=8, seed=110)
    faces += rod((-0.3, 0, 0), (-0.12, 0, 0), 0.16, shade(metal, 0.85), sides=8, seed=111)
    faces += rod((-0.12, 0, 0), (0.8, 0, 0), 0.08, metal, sides=4, seed=112)
    faces += box((1.0, 0.0, 0.0), (0.42, 0.36, 0.08), metal)
    faces += box((1.23, 0.0, 0.0), (0.06, 0.36, 0.09), edge)
    return faces


def horn_pane():
    """Horn pane: a sheet of horn pressed flat and scraped thin, amber and a little uneven, lighter where it is thinnest, with streaks."""
    amber = (206, 158, 88)
    faces = box((0.0, 0.0, 0.0), (1.7, 0.06, 1.3), amber)
    faces += box((0.05, 0.004, -0.02), (1.3, 0.06, 0.95), (232, 194, 126))
    for k, z in enumerate((-0.32, 0.05, 0.38)):
        faces += box((0.1 * (k - 1), 0.008, z), (1.1 - 0.2 * k, 0.06, 0.04), (184, 132, 70))
    return faces


def carved_stone_block():
    """Carved stone block: a squared ashlar block, its faces dressed with a raised panel inside a tooled margin."""
    stone = (184, 178, 166)
    faces = box((0.0, 0.0, 0.0), (1.6, 0.9, 1.0), shade(stone, 0.92))
    faces += box((0.0, 0.03, 0.03), (1.36, 0.7, 1.0), stone)                                  # the raised panel on the front
    faces += box((0.0, 0.03, 0.0), (1.36, 0.9, 0.78), stone)                                  # and on the top
    for k in range(5):
        faces += box((-0.54 + 0.27 * k, 0.03, 0.54), (0.02, 0.62, 0.02), shade(stone, 0.86))  # tool marks
    return faces


def carved_stone_shingle():
    """Carved stone shingle: three thin split stone shingles fanned, each with its nail hole near the top."""
    slate = (132, 134, 136)
    faces = []
    for k in range(3):
        faces += moved(box((0.0, 0.0, 0.0), (0.9, 0.08, 1.4), shade(slate, 0.92 + 0.06 * k)), rot_y(math.radians(-24.0 + 20.0 * k)), (0.25 * k - 0.25, 0.1 * k, 0.0))
        faces += moved(box((0.0, 0.045, -0.5), (0.1, 0.01, 0.1), (52, 50, 50)), rot_y(math.radians(-24.0 + 20.0 * k)), (0.25 * k - 0.25, 0.1 * k, 0.0))
    return faces


# ---------------------------------------------------------------- item system parts D and E (#940, #941, 10 Nov 2026)
CLAY_RED = (186, 120, 78)
MEAT = (150, 70, 46)


def meat_skewer():
    """Meat skewer: a green stick on the diagonal threaded with four roasted chunks of meat and wild garlic cloves between them."""
    faces = rod((-1.3, 0, 0), (1.25, 0, 0), 0.05, (150, 112, 72), end=WOOD_END, taper=0.4, seed=200)
    for k in range(4):
        faces += blob((-0.7 + 0.45 * k, 0.0, 0.0), (0.2, 0.19, 0.19), shade(MEAT, 0.9 + 0.06 * (k % 2)), seed=201 + k, seg=7, rings=4, rough=0.2)
    for k in range(3):
        faces += blob((-0.47 + 0.45 * k, 0.0, 0.0), (0.07, 0.11, 0.1), (236, 228, 204), seed=210 + k, seg=6, rings=3, rough=0.1)
    return faces


def sausage():
    """Sausage: a link of three sausages in their gut, curved, tied off with twine between them."""
    faces = []
    for k in range(3):
        a0 = math.radians(-60.0 + 45.0 * k)
        pts = [(1.0 * math.cos(a0 + t), 0.0, 1.0 * math.sin(a0 + t) - 0.4) for t in np.linspace(0.0, math.radians(38.0), 5)]
        radii = [0.13, 0.2, 0.22, 0.2, 0.13]
        faces += _path(pts, radii, [shade((156, 82, 62), 1.0 + 0.04 * (j % 2)) for j in range(5)], sides=8, seed=220 + k)
    for k in range(4):
        a = math.radians(-62.0 + 45.0 * k)
        faces += blob((1.0 * math.cos(a), 0.0, 1.0 * math.sin(a) - 0.4), (0.07, 0.07, 0.07), CORD, seed=230 + k, seg=5, rings=3, rough=0.1)
    return faces


def mug(drink=None):
    """Mug: a small fired clay cup with a loop handle, dark inside, or full of a drink."""
    faces = rod((0, -0.62, 0), (0, 0.55, 0), 0.52, CLAY_RED, end=drink or (70, 46, 32), sides=12, seed=240)
    faces += rod((0, 0.5, 0), (0, 0.6, 0), 0.56, shade(CLAY_RED, 1.08), end=drink or (70, 46, 32), sides=12, seed=241)   # the lip
    handle = [(0.5 + 0.34 * math.sin(a), 0.3 * math.cos(a), 0.0) for a in np.linspace(0.0, math.pi, 7)]
    faces += _path(handle, [0.1] * 7, [shade(CLAY_RED, 0.95)] * 7, sides=6, seed=242)
    return faces


def mortar_pestle():
    """Mortar and pestle: a hollowed round stone with crushed green herb in it, the round-ended grinder leaning in it."""
    stone = (160, 154, 144)
    faces = rod((0, -0.6, 0), (0, 0.15, 0), 0.75, stone, end=(96, 120, 64), sides=12, seed=250)
    faces += rod((0, 0.1, 0), (0, 0.22, 0), 0.82, shade(stone, 1.06), end=(96, 120, 64), sides=12, seed=251)
    faces += rod((-0.1, 0.0, 0.1), (0.75, 1.0, -0.1), 0.15, shade(stone, 1.1), seed=252)
    faces += blob((0.78, 1.02, -0.1), (0.2, 0.2, 0.2), shade(stone, 1.1), seed=253, seg=7, rings=4, rough=0.05)
    return faces


def herb_antidote():
    """Herb antidote: a small stoppered clay flask of green cure, a plantain leaf laid against it."""
    faces = blob((0.0, -0.25, 0.0), (0.5, 0.55, 0.5), CLAY_RED, seed=260, seg=10, rings=6, rough=0.02)
    faces += rod((0, 0.2, 0), (0, 0.65, 0), 0.17, CLAY_RED, end=CLAY_RED, sides=8, seed=261)
    faces += rod((0, 0.62, 0), (0, 0.85, 0), 0.15, (176, 140, 96), end=(196, 160, 112), sides=8, seed=262)     # the stopper
    faces += box((0.0, -0.2, 0.47), (0.6, 0.3, 0.06), (110, 150, 80))                                          # a green band where it is marked
    faces += leaf((0.55, -0.35, 0.35), (0.4, 1.0, 0.2), 1.0, 0.42, (96, 140, 62))
    return faces


def bonemeal():
    """Bonemeal: a heap of pale ground bone with a broken bone end sticking out of it."""
    faces = blob((0.0, -0.45, 0.0), (1.0, 0.42, 0.85), (230, 224, 204), seed=270, seg=12, rings=5, rough=0.06)
    faces += rod((0.2, -0.1, 0.1), (0.9, 0.5, -0.1), 0.13, BONE, end=(214, 200, 168), seed=271)
    faces += blob((0.95, 0.55, -0.1), (0.2, 0.17, 0.17), BONE, seed=272, seg=7, rings=4, rough=0.05)
    return faces


def sling():
    """Sling: a hide pouch with a stone in it, its two cords laid out long and nearly straight to either side, a knot at one end and a
    small finger loop at the other (curled cords read as claws at slot size)."""
    faces = blob((0.0, 0.0, 0.0), (0.42, 0.12, 0.3), LEATHER, seed=280, seg=9, rings=4, rough=0.06)
    faces += blob((0.0, 0.1, 0.0), (0.2, 0.17, 0.2), (150, 144, 134), seed=281, seg=7, rings=4, rough=0.03)
    for side in (-1.0, 1.0):
        pts = [(0.38 * side, 0.0, 0.0), (0.9 * side, -0.04, 0.02), (1.45 * side, -0.02, 0.0)]
        faces += _path(pts, [0.065] * 3, [CORD] * 3, sides=6, seed=282)
    faces += blob((-1.5, -0.02, 0.0), (0.12, 0.12, 0.12), CORD, seed=284, seg=6, rings=3)                   # the knot
    loop = [(1.45 + 0.13 * (1.0 - math.cos(a)), 0.0, 0.13 * math.sin(a)) for a in np.linspace(0.0, 2.0 * math.pi, 9)]
    faces += _path(loop, [0.055] * 9, [CORD] * 9, sides=6, seed=285)                                         # the finger loop
    return faces


def sling_stone():
    """Sling stone: three smooth egg-sized river stones."""
    faces = []
    for k, (at, tone) in enumerate((((-0.45, -0.2, 0.25), 1.0), ((0.45, -0.25, 0.1), 0.9), ((0.0, 0.25, -0.25), 1.08))):
        faces += blob(at, (0.46, 0.36, 0.38), shade((150, 140, 124), tone), seed=290 + k, seg=10, rings=6, rough=0.02)
    return faces


def whetstone():
    """Whetstone: a fine flat bar of blue-grey stone, worn hollow and pale down its middle by honing."""
    grey = (124, 132, 140)
    faces = box((0.0, 0.0, 0.0), (2.0, 0.3, 0.62), grey)
    faces += box((0.0, 0.006, 0.0), (1.5, 0.3, 0.3), (164, 172, 178))
    return faces


def fishing_spear():
    """Fishing spear: a long shaft bound with twine where it splits into three sharpened, barbed prongs."""
    faces = rod((-1.4, 0, 0), (0.45, 0, 0), 0.07, WOOD, seed=300)
    faces += rod((0.3, 0, 0), (0.5, 0, 0), 0.1, CORD, sides=6, seed=301)
    for k, spread in enumerate((-0.2, 0.0, 0.2)):
        tip = (1.45, spread, 0.05 * (k - 1))
        faces += rod((0.45, spread * 0.3, 0), tip, 0.045, WOOD, end=WOOD_END, taper=0.2, seed=302 + k)
        faces += rod((1.2, spread * 0.85, 0.0), (1.08, spread * 0.85 + 0.07 * (1 if spread >= 0 else -1), 0.0), 0.025, WOOD, taper=0.2, seed=306 + k)   # its barb
    return faces


def fire_arrow():
    """Fire arrow: the wooden arrow with a ball of pitch-soaked fibre bound behind its head, fanned three as every arrow."""
    faces = arrows("wood", (FEATHER, FEATHER_BAND))
    for k, angle in enumerate((-11.0, 0.0, 11.0)):
        faces += moved(blob((0.68, 0.0, 0.0), (0.2, 0.12, 0.12), (52, 38, 26), seed=310 + k, seg=7, rings=4, rough=0.2),
                       turn=rot_z(math.radians(angle)), shift=(0.0, 0.0, 0.12 * (k - 1)))
    return faces


def fishing_bait():
    """Fishing bait: the bone hook with a cut piece of worm threaded on its bend."""
    faces = hook()
    pts = [(0.38 - 0.42 * math.cos(a), -0.35 - 0.42 * math.sin(a), 0.0) for a in np.linspace(0.3, 2.6, 6)]
    faces += _path(pts, [0.13, 0.17, 0.18, 0.18, 0.17, 0.13], [(196, 116, 106), (184, 106, 98)] * 3, sides=7, seed=320)
    return faces


def bedroll():
    """Bedroll: sewn hides rolled tight, the fur side showing in the spiral at the end, two leather straps round it."""
    hide = (166, 124, 82)
    faces = rod((-1.1, 0, 0), (1.1, 0, 0), 0.5, hide, end=(118, 86, 58), sides=12, seed=330)
    faces += rod((1.1, 0, 0), (1.12, 0, 0), 0.33, (150, 108, 70), end=(150, 108, 70), sides=12, seed=331)       # the spiral, a ring in
    faces += rod((1.12, 0, 0), (1.14, 0, 0), 0.16, (118, 86, 58), end=(118, 86, 58), sides=10, seed=332)
    for x in (-0.6, 0.6):
        faces += rod((x - 0.07, 0, 0), (x + 0.07, 0, 0), 0.53, LEATHER, sides=12, seed=333)
    return faces


def wooden_snowshoes():
    """Wooden - Snowshoes: two bent-wood oval frames laced across with leather, one lying on the other, crossed a little."""
    faces = []
    for k, (turn, shift) in enumerate(((rot_y(math.radians(-14.0)), (-0.18, 0.0, 0.0)), (rot_y(math.radians(14.0)), (0.18, 0.12, 0.0)))):
        ring = [(0.55 * math.sin(a), 0.0, -1.05 * math.cos(a)) for a in np.linspace(0.0, 2.0 * math.pi, 15)]
        shoe = _path(ring, [0.06] * 15, [(170, 128, 80)] * 15, sides=6, seed=340 + k)
        for z in np.linspace(-0.7, 0.7, 6):                                                    # the lacing across
            w = 0.55 * math.sqrt(max(0.0, 1.0 - (z / 1.05) ** 2))
            shoe += box((0.0, 0.0, z), (2.0 * w, 0.025, 0.035), LEATHER)
        shoe += box((0.0, 0.0, 0.0), (0.035, 0.025, 1.6), LEATHER)
        shoe += box((0.0, 0.03, -0.1), (0.4, 0.05, 0.12), shade(LEATHER, 0.85))              # the toe strap
        faces += moved(shoe, turn, shift)
    return faces


def leather_belt():
    """Leather - Belt (waist slot): the strap laid in a loop on its edge, its end running out through a bone toggle at the front."""
    brown = (122, 74, 42)
    faces = []
    n = 18
    for k in range(n):
        a0, a1 = 2.0 * math.pi * k / n, 2.0 * math.pi * (k + 1) / n
        p0 = np.array([0.95 * math.cos(a0), 0.0, 0.62 * math.sin(a0)])
        p1 = np.array([0.95 * math.cos(a1), 0.0, 0.62 * math.sin(a1)])
        mid, d = (p0 + p1) / 2.0, p1 - p0
        faces += moved(box((0.0, 0.0, 0.0), (float(np.linalg.norm(d)) + 0.02, 0.34, 0.08), shade(brown, 0.94 + 0.08 * (k % 2))),
                       rot_y(-math.atan2(d[2], d[0])), tuple(mid))
    faces += moved(box((0.0, 0.0, 0.0), (0.7, 0.34, 0.08), shade(brown, 1.05)), rot_y(math.radians(-12.0)), (0.35, 0.02, 0.72))   # the end, out to the front
    faces += rod((-0.02, -0.2, 0.68), (-0.02, 0.22, 0.68), 0.07, BONE, end=shade(BONE, 1.05), sides=7, seed=350)   # the toggle
    return faces


def pickled_vegetables():
    """Pickled vegetables (#955): a squat lidded clay crock, a cloth tied over its mouth, a cut carrot and a beet laid against it."""
    faces = rod((0, -0.7, 0), (0, 0.25, 0), 0.62, CLAY_RED, end=CLAY_RED, sides=12, taper=0.92, seed=360)
    faces += rod((0, 0.22, 0), (0, 0.42, 0), 0.6, shade(CLAY_RED, 1.06), end=(214, 196, 150), sides=12, seed=361)   # the rim
    faces += blob((0.0, 0.45, 0.0), (0.66, 0.14, 0.66), (214, 196, 150), seed=362, seg=12, rings=4, rough=0.05)     # the cloth over it
    faces += rod((0, 0.28, 0), (0, 0.36, 0), 0.64, CORD, end=CORD, sides=12, seed=363)                               # its tie
    faces += rod((0.55, -0.72, 0.62), (0.95, -0.55, 0.3), 0.15, (226, 120, 40), end=(240, 170, 90), taper=0.8, seed=364)   # a cut carrot
    faces += blob((-0.6, -0.5, 0.62), (0.3, 0.3, 0.3), (150, 36, 60), seed=365, seg=8, rings=5, rough=0.04)          # a beet
    return faces


def copper_pot():
    """Copper - Pot (#955): a hammered copper pot, wider than it is tall, its rolled rim bright, an iron bail handle arched over it."""
    faces = rod((0, -0.75, 0), (0, 0.3, 0), 0.74, (206, 128, 64), end=(120, 72, 40), sides=14, taper=1.1, seed=370)
    faces += rod((0, 0.27, 0), (0, 0.38, 0), 0.86, (236, 172, 106), end=(120, 72, 40), sides=14, seed=371)            # the rolled rim
    bail = [(-0.86 * math.cos(a), 0.34 + 0.7 * math.sin(a), 0.0) for a in np.linspace(0.0, math.pi, 9)]
    faces += _path(bail, [0.05] * 9, [(70, 72, 80)] * 9, sides=6, seed=372)                                            # the bail handle
    return faces


def _bowl(food, seed):
    """A wooden bowl (the wooden_bowl's shape, drawn small and high), food heaped or poured in it."""
    faces = rod((0, -0.55, 0), (0, 0.15, 0), 0.95, WOOD, end=food, sides=14, taper=1.25, seed=seed)
    faces += rod((0, 0.12, 0), (0, 0.2, 0), 1.0, WOOD_END, end=food, sides=14, seed=seed + 1)
    return faces


def fish_soup():
    """Fish soup (#955): a bowl of pale broth with a fish's tail and a chunk of its flesh standing out of it, green wild garlic floating."""
    faces = _bowl((222, 182, 108), 380)
    faces += rod((0.1, 0.18, -0.1), (0.45, 0.6, -0.25), 0.11, (140, 146, 156), taper=0.5, seed=382)                  # the fish's tail end
    faces += point((0.42, 0.56, -0.24), (0.8, 1.0, -0.4), 0.62, 0.06, (128, 134, 146), back=0.85, roll=30.0)         # its tail fin
    faces += blob((-0.35, 0.22, 0.2), (0.3, 0.15, 0.24), (240, 226, 204), seed=381, seg=7, rings=4, rough=0.15)
    for k, (x, z) in enumerate(((0.35, 0.35), (-0.2, -0.4), (-0.55, -0.05))):
        faces += leaf((x, 0.215, z), (1.0, 0.0, 0.6 * (k - 1)), 0.34, 0.12, (96, 150, 62))
    return faces


def meatballs():
    """Meatballs (#955): six round browned balls heaped in a bowl, a little dark gravy round them."""
    faces = _bowl((110, 62, 36), 390)
    for k, (x, y, z) in enumerate(((-0.4, 0.3, 0.25), (0.35, 0.3, 0.3), (0.0, 0.3, -0.4), (-0.45, 0.3, -0.3), (0.45, 0.3, -0.25), (0.0, 0.55, 0.0))):
        faces += blob((x, y, z), (0.3, 0.27, 0.3), shade((128, 70, 42), 0.92 + 0.05 * (k % 3)), seed=391 + k, seg=8, rings=5, rough=0.1)
    return faces


def claw_necklace():
    """Claw - Necklace (#955): a cord laid in a loop, five big pale claws strung on its lower half, curving out, a bead between each."""
    faces = []
    ring = [(1.0 * math.cos(a), 0.0, 0.7 * math.sin(a)) for a in np.linspace(0.0, 2.0 * math.pi, 17)]
    faces += _path(ring, [0.05] * 17, [CORD] * 17, sides=6, seed=400)
    for k in range(5):
        a = math.radians(35.0 + 27.5 * k)
        at = np.array([1.0 * math.cos(a), 0.0, 0.7 * math.sin(a)])
        out = np.array([math.cos(a), 0.0, math.sin(a)])
        pts = [at, at + out * 0.3 + np.array([0.0, 0.05, 0.0]), at + out * 0.52 + np.array([0.06 * math.sin(a), 0.14, 0.0])]
        faces += _path([tuple(p) for p in pts], [0.1, 0.07, 0.02], [(216, 200, 160), (226, 212, 176), (90, 70, 52)], sides=6, seed=401 + k)
    for k in range(4):
        a = math.radians(48.75 + 27.5 * k)
        faces += blob((1.0 * math.cos(a), 0.0, 0.7 * math.sin(a)), (0.08, 0.08, 0.08), (150, 60, 40), seed=410 + k, seg=6, rings=3, rough=0.05)
    return faces


def bronze_scale_shirt():
    """Bronze - Scale shirt (#955): a short-sleeved shirt laid flat, its body and sleeves covered in rows of overlapping bronze scales,
    each row's lower edge bright, a leather collar at the neck."""
    leather = (110, 70, 40)
    faces = box((0.0, 0.0, 0.0), (1.1, 1.5, 0.12), leather)                                             # the leather under it
    faces += moved(box((0.0, 0.0, 0.0), (0.7, 0.46, 0.12), leather), rot_z(math.radians(-28.0)), (0.72, 0.5, 0.0))
    faces += moved(box((0.0, 0.0, 0.0), (0.7, 0.46, 0.12), leather), rot_z(math.radians(28.0)), (-0.72, 0.5, 0.0))
    for row in range(6):                                                                                 # the scales, top row first
        y = 0.6 - 0.24 * row
        for col in range(5):
            x = -0.44 + 0.22 * col + (0.11 if row % 2 else 0.0)
            if abs(x) > 0.5:
                continue
            faces += moved(box((0.0, 0.0, 0.0), (0.2, 0.26, 0.04), shade(BRONZE, 0.94 + 0.05 * ((row + col) % 3))),
                           rot_x(math.radians(-14.0)), (x, y, 0.09 + 0.012 * row))
            faces += box((x, y - 0.12, 0.13 + 0.012 * row), (0.17, 0.035, 0.02), (232, 186, 116))       # its bright lower edge
    for side in (-1.0, 1.0):                                                                             # the sleeves' scales
        for k in range(2):
            at = (side * (0.62 + 0.2 * k), 0.54 - 0.105 * k, 0.09)
            faces += moved(box((0.0, 0.0, 0.0), (0.18, 0.34, 0.04), shade(BRONZE, 0.96 + 0.05 * k)), rot_z(math.radians(side * -28.0)), at)
    faces += moved(box((0.0, 0.0, 0.0), (0.46, 0.12, 0.16), shade(leather, 0.85)), rot_x(0.0), (0.0, 0.76, 0.04))   # the collar
    return faces


# ---------------------------------------------------------------- seven-tier ladder materials (Dave, 10 Nov 2026)
def _shingles(colour, shape, seed):
    """Three roof shingles fanned the way the carved stone shingle is (one layout for the set): `shape(k)` builds the k-th one lying flat."""
    faces = []
    for k in range(3):
        faces += moved(shape(k, shade(colour, 0.92 + 0.06 * k)), rot_y(math.radians(-24.0 + 20.0 * k)), (0.25 * k - 0.25, 0.1 * k, 0.0))
    return faces


def bark_shingle():
    """Bark shingle (Rustic roofs): three flat slabs of stripped bark, rough and grey-brown, ridged along their length, fanned."""
    def one(k, colour):
        faces = box((0.0, 0.0, 0.0), (0.85, 0.07, 1.4), colour)
        for x in (-0.25, 0.05, 0.3):
            faces += box((x + 0.03 * k, 0.045, 0.0), (0.07, 0.03, 1.3), shade(colour, 0.72))   # the bark's ridges
        return faces
    return _shingles((116, 94, 72), one, 420)


def wooden_shingle():
    """Wooden shingle (Refined roofs): three split shakes, thick at the butt and thin at the head, pale split wood with a grain line, fanned."""
    def one(k, colour):
        faces = box((0.0, 0.0, 0.0), (0.8, 0.06, 1.4), colour)
        faces += box((0.0, 0.04, 0.55), (0.8, 0.05, 0.3), shade(colour, 0.95))                # the thick butt end
        faces += box((0.15 - 0.1 * k, 0.035, -0.1), (0.03, 0.01, 1.0), shade(colour, 0.8))   # a grain line
        return faces
    return _shingles((206, 160, 102), one, 430)


def clay_roof_tile():
    """Clay roof tile (Superior and Engineered roofs): three curved fired-clay tiles nested in a row, each a half round channel, orange-red."""
    tile = (190, 96, 58)
    faces = []
    for k in range(3):                                                                                # side by side, each a little higher
        x0, y0 = -0.78 + 0.78 * k, 0.08 * k
        pts = [(0.42 * math.cos(a), 0.42 * math.sin(a), 0.0) for a in np.linspace(math.radians(195.0), math.radians(345.0), 6)]
        for j in range(5):                                                                            # the curve, five flat strips
            a, b = np.array(pts[j]), np.array(pts[j + 1])
            mid, d = (a + b) / 2.0, b - a
            faces += moved(box((0.0, 0.0, 0.0), (float(np.linalg.norm(d)) + 0.01, 0.07, 1.3), shade(tile, 0.9 + 0.04 * (j % 3) + 0.03 * k)),
                           rot_z(math.atan2(d[1], d[0])), (mid[0] + x0, mid[1] + y0, mid[2]))
    return faces


def limestone():
    """Limestone: three pale cream chunks of soft rock, blocky and rough, a darker grey vein in one."""
    faces = []
    for k, (at, r, tone) in enumerate((((-0.4, -0.25, 0.3), (0.55, 0.42, 0.5), 1.0), ((0.45, -0.3, 0.1), (0.5, 0.36, 0.45), 0.93), ((0.0, 0.2, -0.3), (0.5, 0.42, 0.45), 1.05))):
        faces += blob(at, r, shade((214, 206, 182), tone), seed=440 + k, seg=6, rings=4, rough=0.16)
    faces += box((0.05, 0.62, -0.3), (0.5, 0.02, 0.06), (150, 146, 136))
    return faces


def lime_powder():
    """Lime powder: a heap of white burnt-lime powder with a small wooden scoop pushed into it."""
    faces = blob((0.0, -0.45, 0.0), (1.0, 0.68, 0.85), (238, 236, 228), seed=450, seg=12, rings=5, rough=0.05)
    faces += rod((0.25, 0.0, 0.1), (1.0, 0.55, -0.05), 0.08, WOOD, seed=451)
    faces += blob((0.18, -0.05, 0.12), (0.26, 0.12, 0.2), WOOD, seed=452, seg=8, rings=3, rough=0.03)
    return faces


def concrete():
    """Concrete (Engineered and Fortified): a cast grey block with its board-form lines, a little gravel at its foot."""
    grey = (150, 150, 146)
    faces = box((0.0, 0.0, 0.0), (1.5, 0.9, 1.0), grey)
    for y in (-0.15, 0.15):
        faces += box((0.0, y, 0.0), (1.52, 0.025, 1.02), shade(grey, 0.72))   # board-form lines
    for k, (x, z) in enumerate(((0.95, 0.4), (0.85, -0.2), (-0.95, 0.45))):
        faces += blob((x, -0.38, z), (0.12, 0.1, 0.11), (120, 116, 108), seed=460 + k, seg=6, rings=3, rough=0.2)
    return faces


def iron_band():
    """Iron band (Fortified): a flat forged iron strap bent into a hoop on its edge, rivets round it, a second band leaning behind."""
    faces = []
    for turn, shift, tone in ((rot_y(0.0), (0.0, 0.0, 0.25), 1.0), (rot_x(math.radians(-25.0)), (0.3, 0.25, -0.35), 0.85)):
        n = 16
        hoop = []
        for k in range(n):
            a0, a1 = 2.0 * math.pi * k / n, 2.0 * math.pi * (k + 1) / n
            p0 = np.array([0.85 * math.cos(a0), 0.85 * math.sin(a0), 0.0])
            p1 = np.array([0.85 * math.cos(a1), 0.85 * math.sin(a1), 0.0])
            mid, d = (p0 + p1) / 2.0, p1 - p0
            hoop += moved(box((0.0, 0.0, 0.0), (float(np.linalg.norm(d)) + 0.02, 0.07, 0.28), shade((96, 98, 108), tone)), rot_z(math.atan2(d[1], d[0])), tuple(mid))
            if k % 4 == 0:
                hoop += moved(box((0.0, 0.0, 0.0), (0.08, 0.04, 0.08), (150, 152, 160)), rot_z(math.atan2(d[1], d[0])), tuple(mid * 0.94))   # a rivet
        faces += moved(hoop, turn, shift)
    return faces


def _pieces():
    return {
        "spear": (stone_spear, DIAGONAL),
        "wooden_spear": (wooden_spear, DIAGONAL),
        "wooden_arrow": (lambda: arrows("wood", (FEATHER, FEATHER_BAND)), DIAGONAL),
        "bone_arrow": (lambda: arrows("bone", (FEATHER, None)), DIAGONAL),
        "stone_arrow": (lambda: arrows("stone", ((176, 150, 120), FEATHER_BAND)), DIAGONAL),
        "fibre_arrow": (lambda: arrows("wood", (FIBRE, None)), DIAGONAL),
        "stick": (stick, DIAGONAL),
        "sewing_needle": (sewing_needle, DIAGONAL),
        "charcoal": (charcoal, HEAP_VIEW),
        "wool_cloth": (wool_cloth, HEAP_VIEW),
        "fur": (fur, rot_x(math.radians(50.0)) @ rot_y(math.radians(18.0))),
        "crystal_lens": (crystal_lens, rot_y(math.radians(-40.0)) @ rot_z(math.radians(10.0))),
        "spyglass": (spyglass, DIAGONAL),
        "horn": (horn, rot_y(math.radians(20.0))),
        "gut": (gut, rot_x(math.radians(48.0))),
        "toggle": (toggle, DIAGONAL),
        "hook": (hook, rot_y(math.radians(20.0)) @ rot_z(math.radians(-15.0))),
        "bone_club": (bone_club, DIAGONAL),
        "wooden_longbow": (wooden_longbow, rot_z(math.radians(42.0))),
        "straw_hat": (straw_hat, rot_x(math.radians(28.0))),
        "worm": (worm, rot_x(math.radians(50.0))),
        "wooden_spade": (lambda: spade("wood"), SPADE_VIEW),
        "stone_spade": (lambda: spade("stone"), SPADE_VIEW),
        "iron_spade": (lambda: spade("iron"), SPADE_VIEW),
        "steel_spade": (lambda: spade("steel"), SPADE_VIEW),
        **{item: ((lambda i=item: grain_seeds(i)), SEED_VIEW) for item in (*GRAINS, *VEG)},
        "apple_pie": (apple_pie, PIE_VIEW),
        "fish_pie": (fish_pie, PIE_VIEW),
        "venison_pie": (venison_pie, PIE_VIEW),
        "kindling": (kindling, LYING),
        "tinder": (tinder, HEAP_VIEW),
        "thatch": (thatch, LYING),
        "straw": (straw, HEAP_VIEW),
        "birch_bark": (birch_bark, LYING),
        "withies": (withies, HEAP_VIEW),
        **{m + "_hammer": ((lambda m=m: hammer(m)), SPADE_VIEW) for m in ("wooden", "stone", "bronze", "iron", "steel")},
        **{m + "_chisel": ((lambda m=m: chisel(m)), SPADE_VIEW) for m in ("bronze", "iron", "steel")},
        "horn_pane": (horn_pane, rot_x(math.radians(40.0)) @ rot_y(math.radians(15.0))),
        "carved_stone_block": (carved_stone_block, rot_y(math.radians(-28.0))),
        "carved_stone_shingle": (carved_stone_shingle, rot_x(math.radians(35.0))),
        "parsnip": (lambda: parsnip(46), rot_z(math.radians(-28.0))),
        "meat_skewer": (meat_skewer, DIAGONAL),
        "sausage": (sausage, rot_x(math.radians(40.0))),
        "mug": (mug, rot_x(math.radians(14.0))),
        "fruit_juice": (lambda: mug((150, 40, 64)), rot_x(math.radians(24.0))),
        "mortar_pestle": (mortar_pestle, rot_x(math.radians(18.0))),
        "herb_antidote": (herb_antidote, rot_y(math.radians(-20.0))),
        "bonemeal": (bonemeal, rot_x(math.radians(14.0))),
        "sling": (sling, rot_z(math.radians(24.0)) @ rot_x(math.radians(30.0))),
        "sling_stone": (sling_stone, rot_x(math.radians(20.0))),
        "whetstone": (whetstone, rot_y(math.radians(-25.0)) @ rot_x(math.radians(25.0))),
        "fishing_spear": (fishing_spear, DIAGONAL),
        "fire_arrow": (fire_arrow, DIAGONAL),
        "fishing_bait": (fishing_bait, rot_y(math.radians(20.0)) @ rot_z(math.radians(-15.0))),
        "bedroll": (bedroll, rot_y(math.radians(-30.0))),
        "wooden_snowshoes": (wooden_snowshoes, rot_x(math.radians(45.0)) @ rot_y(math.radians(30.0))),
        "leather_belt": (leather_belt, rot_x(math.radians(38.0))),
        "pickled_vegetables": (pickled_vegetables, rot_x(math.radians(14.0))),
        "copper_pot": (copper_pot, rot_x(math.radians(6.0))),
        "fish_soup": (fish_soup, rot_x(math.radians(18.0))),
        "meatballs": (meatballs, rot_x(math.radians(26.0))),
        "claw_necklace": (claw_necklace, rot_x(math.radians(50.0))),
        "bark_shingle": (bark_shingle, rot_x(math.radians(35.0))),
        "wooden_shingle": (wooden_shingle, rot_x(math.radians(35.0))),
        "clay_roof_tile": (clay_roof_tile, rot_x(math.radians(32.0)) @ rot_y(math.radians(-18.0))),
        "limestone": (limestone, rot_x(math.radians(14.0))),
        "lime_powder": (lime_powder, rot_x(math.radians(14.0))),
        "concrete": (concrete, rot_y(math.radians(-30.0)) @ rot_x(math.radians(20.0))),
        "iron_band": (iron_band, rot_y(math.radians(-25.0)) @ rot_x(math.radians(10.0))),
        "bronze_scale_shirt": (bronze_scale_shirt, rot_y(math.radians(-15.0))),
    }


def _glass(image):
    """After the render: lift and cool the lens, then two white streaks (a window's reflection) across its upper left."""
    from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
    alpha = image.getchannel("A")
    lifted = ImageEnhance.Brightness(image.convert("RGB")).enhance(1.35)
    r, g, b = lifted.split()
    lifted = Image.merge("RGB", (r.point(lambda v: int(v * 0.92)), g, b.point(lambda v: min(255, int(v * 1.08))))).convert("RGBA")
    lifted.putalpha(alpha)
    left, top, right, bottom = alpha.getbbox()
    w, h = right - left, bottom - top
    shine = Image.new("RGBA", image.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(shine)
    d.line([(left + w * 0.3, top + h * 0.62), (left + w * 0.5, top + h * 0.2)], fill=(255, 255, 255, 230), width=max(3, w // 11))
    d.line([(left + w * 0.46, top + h * 0.7), (left + w * 0.6, top + h * 0.4)], fill=(255, 255, 255, 170), width=max(2, w // 20))
    shine = shine.filter(ImageFilter.GaussianBlur(0.8))
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", image.size, 0), alpha))
    lifted.alpha_composite(shine)
    return lifted


AFTER = {"crystal_lens": _glass}   # a touch after the render for an item the rig alone cannot make read
PIECES = _pieces()
NAMES = tuple(PIECES)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui", "item_icons"))
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    only = set(filter(None, args.only.split(",")))

    for name, (build, turn) in PIECES.items():
        if only and name not in only:
            continue

        path = os.path.join(args.out, name + ".png")
        image = render(build(), turn, colour_jitter=0.04, seed=len(name))
        AFTER.get(name, lambda i: i)(image).save(path)
        print("painted", path)


if __name__ == "__main__":
    main()
