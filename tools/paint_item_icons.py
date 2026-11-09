#!/usr/bin/env python3
"""Paint the small items the bake draws too thin or too alike to read at slot size (Kathleen, 9 Nov 2026).

At the 1366 x 768 floor a recipe-list icon is 23 screen px and a hotbar icon 43 (docs/ui/item_icons.md), and the bake's spears,
arrows and stick shrink to hairlines there while its spades, grain seeds and pies come out as one picture each. These are painted
to the same rig as tools/paint_structure_icons.py, with three rules for small sizes:
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


GRAINS = {
    # id: (seed colour, grain radii, the plant)
    "barley_seeds": ((222, 196, 128), (0.07, 0.04, 0.045), lambda: ear((228, 202, 122), 0.62, 0.1, 0.5, 40)),
    "wheat_seeds": ((204, 146, 64), (0.075, 0.05, 0.055), lambda: ear((214, 152, 52), 0.7, 0.13, 0.0, 41)),
    "oats_seeds": ((214, 208, 166), (0.085, 0.032, 0.04), lambda: oat_head((208, 206, 150), 42)),
    "rye_seeds": ((150, 140, 116), (0.08, 0.03, 0.035), lambda: ear((172, 170, 126), 0.8, 0.085, 0.4, 43)),
    "flax_seeds": ((140, 86, 44), (0.06, 0.03, 0.045), lambda: flax_plant(44)),
    "carrot_seeds": ((168, 132, 92), (0.05, 0.025, 0.04), lambda: carrot(45)),
}


def grain_seeds(item):
    """The pile at the front left, the plant leaning across the icon behind it, drawn large: at 23 px the plant's colour names the grain."""
    colour, grain, plant = GRAINS[item]
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


def _pieces():
    return {
        "spear": (stone_spear, DIAGONAL),
        "wooden_spear": (wooden_spear, DIAGONAL),
        "wooden_arrow": (lambda: arrows("wood", (FEATHER, FEATHER_BAND)), DIAGONAL),
        "bone_arrow": (lambda: arrows("bone", (FEATHER, None)), DIAGONAL),
        "stone_arrow": (lambda: arrows("stone", ((176, 150, 120), FEATHER_BAND)), DIAGONAL),
        "fibre_arrow": (lambda: arrows("wood", (FIBRE, None)), DIAGONAL),
        "stick": (stick, DIAGONAL),
        "wooden_spade": (lambda: spade("wood"), SPADE_VIEW),
        "stone_spade": (lambda: spade("stone"), SPADE_VIEW),
        "iron_spade": (lambda: spade("iron"), SPADE_VIEW),
        "steel_spade": (lambda: spade("steel"), SPADE_VIEW),
        **{item: ((lambda i=item: grain_seeds(i)), SEED_VIEW) for item in GRAINS},
        "apple_pie": (apple_pie, PIE_VIEW),
        "fish_pie": (fish_pie, PIE_VIEW),
        "venison_pie": (venison_pie, PIE_VIEW),
    }


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
        render(build(), turn, colour_jitter=0.04, seed=len(name)).save(path)
        print("painted", path)


if __name__ == "__main__":
    main()
