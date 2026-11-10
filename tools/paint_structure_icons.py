#!/usr/bin/env python3
"""Paint the icons the bake has no model for: building sections, logs, furniture, stations, fires and lights (inventory redesign step 5; Kathleen, 9 Nov 2026).

The same rig as tools/paint_basic_icons.py (look doc section 6.7): low-poly flat-shaded facets, a warm key light from the top left,
a soft fill and a gold rim, three-quarter view, no background, 128 x 128 with the object filling about 80 %, drawn at 4x.
Each piece is built from boxes (and the log prism) in the colours of its material, so a wall reads as logs, stone, brick,
wattle or planks at slot size.

    python3 tools/paint_structure_icons.py [--out assets/ui/item_icons] [--only id,id]
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paint_basic_icons import FILL, KEY, KEY_COLOUR, SIZE, SS, VIEW, lift_dark, prism, rot_x, rot_y, rot_z   # noqa: E402  (the shared rig)
from PIL import Image   # noqa: E402

# Material colours (look doc 6.1 warm palette; the bake's wood and stone tones).
PLANK = (184, 140, 92)
PLANK_DARK = (150, 108, 66)
BARK = (122, 88, 56)
LOG_END = (226, 196, 146)
LOG_RING = (196, 158, 104)
STONE = (168, 160, 148)
STONE_DARK = (128, 122, 114)
MORTAR = (206, 196, 176)
BRICK = (170, 82, 54)
BRICK_DARK = (140, 64, 42)
TILE = (186, 98, 62)
SLATE = (104, 108, 112)
STRAW = (214, 182, 104)
STRAW_DARK = (176, 142, 70)
WATTLE = (150, 112, 70)
CLAY = (176, 132, 92)


def render(faces, model, colour_jitter=0.0, seed=0):
    """The rig of paint_basic_icons.render (same light, view and fit), drawn with a depth buffer instead of a painter's sort, so
    pieces made of many touching boxes (a brick course on its mortar) never show a back face through a front one."""
    rng = np.random.default_rng(seed)
    n = SIZE * SS
    placed = []

    for pts, colour in faces:
        world = [model @ p for p in pts]
        normal = np.cross(world[1] - world[0], world[2] - world[0])

        if np.linalg.norm(normal) < 1e-9:
            continue

        normal = normal / np.linalg.norm(normal)
        vn = VIEW @ normal

        if vn[2] <= 0.0:
            continue

        light = FILL + (1.0 - FILL) * max(0.0, float(np.dot(normal, KEY)))
        rim = 0.18 * max(0.0, float(np.dot(normal, np.array([0.6, 0.3, -0.75]))))
        base = np.array(colour[:3], dtype=float) / 255.0 * (1.0 + rng.uniform(-colour_jitter, colour_jitter))

        if len(colour) == 4:   # a glowing face (coals, a flame): its own colour, not lit
            rgb = np.clip(base, 0.0, 1.0)
        else:
            rgb = np.clip(base * light * KEY_COLOUR + rim * np.array([1.0, 0.84, 0.55]), 0.0, 1.0)

        placed.append((np.array([VIEW @ p for p in world]), rgb))

    allpts = np.concatenate([v for v, _ in placed])
    lo, hi = allpts[:, :2].min(axis=0), allpts[:, :2].max(axis=0)
    fit = n * 0.8 / max(hi - lo)
    centre = (lo + hi) / 2.0
    colour_buf = np.zeros((n, n, 4))
    depth = np.full((n, n), -np.inf)

    for view, rgb in placed:
        sx = (view[:, 0] - centre[0]) * fit + n / 2.0
        sy = n / 2.0 - (view[:, 1] - centre[1]) * fit
        sz = view[:, 2]

        for k in range(1, len(view) - 1):           # a fan of triangles
            tri = [(sx[0], sy[0], sz[0]), (sx[k], sy[k], sz[k]), (sx[k + 1], sy[k + 1], sz[k + 1])]
            _raster(tri, rgb, colour_buf, depth)

    img = Image.fromarray((np.clip(colour_buf, 0.0, 1.0) * 255).astype(np.uint8), "RGBA")
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def _raster(tri, rgb, colour_buf, depth):
    (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = tri
    area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)

    if abs(area) < 1e-6:
        return

    n = depth.shape[0]
    xa, xb = max(int(math.floor(min(x0, x1, x2))), 0), min(int(math.ceil(max(x0, x1, x2))) + 1, n)
    ya, yb = max(int(math.floor(min(y0, y1, y2))), 0), min(int(math.ceil(max(y0, y1, y2))) + 1, n)

    if xa >= xb or ya >= yb:
        return

    px, py = np.meshgrid(np.arange(xa, xb) + 0.5, np.arange(ya, yb) + 0.5)
    w0 = ((x1 - px) * (y2 - py) - (x2 - px) * (y1 - py)) / area
    w1 = ((x2 - px) * (y0 - py) - (x0 - px) * (y2 - py)) / area
    w2 = 1.0 - w0 - w1
    inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
    z = w0 * z0 + w1 * z1 + w2 * z2
    region = depth[ya:yb, xa:xb]
    win = inside & (z > region)
    region[win] = z[win]
    colour_buf[ya:yb, xa:xb][win] = np.append(rgb, 1.0)


def box(centre, size, colour):
    """A box's six faces, each wound so its normal points out (render culls faces turned away)."""
    c = np.array(centre, dtype=float)
    h = np.array(size, dtype=float) / 2.0
    corners = {}

    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                corners[(sx, sy, sz)] = c + h * np.array([sx, sy, sz])

    quads = [
        [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)],
        [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)],
        [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)],
        [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)],
        [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)],
        [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)],
    ]
    return [(_outward([corners[k] for k in q], c), colour) for q in quads]


def _outward(pts, centre):
    normal = np.cross(pts[1] - pts[0], pts[2] - pts[0])
    return pts if np.dot(normal, np.mean(pts, axis=0) - centre) >= 0.0 else pts[::-1]


def moved(faces, turn=None, shift=(0.0, 0.0, 0.0)):
    t = np.eye(3) if turn is None else turn
    s = np.array(shift, dtype=float)
    return [([t @ p + s for p in pts], colour) for pts, colour in faces]


def shade(colour, k):
    return tuple(int(max(0, min(255, c * k))) for c in colour[:3]) + tuple(colour[3:])


def log_x(length, radius, y, z, seed, x=0.0):
    """A log lying along x at (x, y, z)."""
    return moved(prism(radius, length, 8, BARK, LOG_END, ring=LOG_RING, seed=seed), shift=(x, y, z))


# ---------------------------------------------------------------- walls (2 m wide, 1.4 m shown, 0.25 thick)
W, H, T = 2.0, 1.4, 0.22


def plank_wall(opening=None):
    """Vertical planks; `opening` (x0, x1, y0, y1) leaves a door or window gap, framed in darker wood."""
    faces = []
    n = 8
    pw = W / n

    for i in range(n):
        x0 = -W / 2 + i * pw
        x1 = x0 + pw - 0.025
        colour = shade(PLANK, 0.92 + 0.16 * ((i * 37) % 7) / 6.0)

        if opening is not None and x1 > opening[0] and x0 < opening[1]:
            for y0, y1 in ((-H / 2, opening[2]), (opening[3], H / 2)):
                if y1 - y0 > 0.02:
                    faces += box(((x0 + x1) / 2, (y0 + y1) / 2, 0.0), (x1 - x0, y1 - y0, T), colour)
        else:
            faces += box(((x0 + x1) / 2, 0.0, 0.0), (x1 - x0, H, T), colour)

    faces += box((0.0, H / 2 - 0.06, T / 2 + 0.03), (W, 0.12, 0.06), PLANK_DARK)       # top rail
    faces += box((0.0, -H / 2 + 0.08, T / 2 + 0.03), (W, 0.12, 0.06), PLANK_DARK)      # bottom rail

    if opening is not None:
        x0, x1, y0, y1 = opening
        f = 0.07
        faces += box((x0 - f / 2, (y0 + y1) / 2, T / 2 + 0.04), (f, y1 - y0 + f, 0.08), PLANK_DARK)
        faces += box((x1 + f / 2, (y0 + y1) / 2, T / 2 + 0.04), (f, y1 - y0 + f, 0.08), PLANK_DARK)
        faces += box(((x0 + x1) / 2, y1 + f / 2, T / 2 + 0.04), (x1 - x0 + 2 * f, f, 0.08), PLANK_DARK)

        if y0 > -H / 2 + 0.01:
            faces += box(((x0 + x1) / 2, y0 - f / 2, T / 2 + 0.04), (x1 - x0 + 2 * f, f, 0.1), PLANK_DARK)

    return faces


def log_wall():
    faces = []
    r = 0.17

    for i in range(4):
        faces += log_x(W + 0.25, r, -H / 2 + r + i * 2 * r * 0.98, 0.0, seed=20 + i)

    return faces


def block_wall(colour, dark, rows, cols, gap, seed, mortar=MORTAR, offset=True):
    """Stone or brick courses on a mortar core; every other course offset by half a block."""
    rng = np.random.default_rng(seed)
    faces = box((0.0, 0.0, -0.02), (W - 0.04, H - 0.04, T - 0.06), mortar)
    bh = H / rows
    bw = W / cols

    for r in range(rows):
        shift = (bw / 2 if (offset and r % 2) else 0.0)
        x = -W / 2 - shift

        while x < W / 2 - 0.02:
            x0 = max(x, -W / 2)
            x1 = min(x + bw, W / 2)

            if x1 - x0 > 0.08:
                k = rng.uniform(0.86, 1.1)
                c = colour if rng.random() > 0.25 else dark
                depth = T + rng.uniform(-0.02, 0.03)
                faces += box(((x0 + x1) / 2, -H / 2 + (r + 0.5) * bh, 0.0), (x1 - x0 - gap, bh - gap, depth), shade(c, k))

            x += bw

    return faces


def stone_wall():
    return block_wall(STONE, STONE_DARK, 4, 4, 0.06, seed=31)


def brick_wall():
    return block_wall(BRICK, BRICK_DARK, 8, 6, 0.04, seed=32)


def thatch_wall(opening=None):
    """Wattle and daub in a timber frame: posts and a top beam, a woven straw-and-wattle panel."""
    faces = []
    post = 0.14
    faces += box((-W / 2 + post / 2, 0.0, 0.03), (post, H, T + 0.06), BARK)
    faces += box((W / 2 - post / 2, 0.0, 0.03), (post, H, T + 0.06), BARK)
    faces += box((0.0, H / 2 - post / 2, 0.03), (W, post, T + 0.06), BARK)
    for a, b in ([(-W / 2, W / 2)] if opening is None else [(-W / 2, opening[0]), (opening[1], W / 2)]):     # the sill, not across a doorway
        faces += box(((a + b) / 2, -H / 2 + post / 2, 0.03), (b - a, post, T + 0.06), BARK)
    n = 11
    sw = (W - 2 * post) / n

    for i in range(n):
        x0 = -W / 2 + post + i * sw
        x1 = x0 + sw - 0.015
        colour = STRAW if i % 2 == 0 else STRAW_DARK

        if opening is not None and x1 > opening[0] and x0 < opening[1]:
            y1 = opening[3]
            faces += box(((x0 + x1) / 2, (y1 + H / 2 - post) / 2, 0.0), (x1 - x0, H / 2 - post - y1, T - 0.04), colour)
        else:
            faces += box(((x0 + x1) / 2, 0.0, 0.0), (x1 - x0, H - 2 * post, T - 0.04), colour)

    for y in (-0.22, 0.22):          # two wattle withies across the panel (either side of a doorway)
        spans = [(-W / 2 + post, W / 2 - post)] if opening is None else [(-W / 2 + post, opening[0] - 0.1), (opening[1] + 0.1, W / 2 - post)]

        for a, b in spans:
            faces += box(((a + b) / 2, y, T / 2 + 0.01), (b - a, 0.05, 0.05), WATTLE)

    if opening is not None:
        x0, x1, _, y1 = opening
        faces += box((x0 - 0.05, (y1 - H / 2) / 2, 0.04), (0.1, y1 + H / 2, T + 0.08), BARK)
        faces += box((x1 + 0.05, (y1 - H / 2) / 2, 0.04), (0.1, y1 + H / 2, T + 0.08), BARK)
        faces += box(((x0 + x1) / 2, y1 + 0.05, 0.04), (x1 - x0 + 0.2, 0.1, T + 0.08), BARK)

    return faces


DOOR = (-0.36, 0.36, -H / 2, 0.42)
WINDOW = (-0.42, 0.42, -0.18, 0.36)
WALL_VIEW = rot_y(math.radians(18.0))


# ---------------------------------------------------------------- floors and ceilings (2 m square slabs, seen from above)
S = 2.0


def plank_slab():
    faces = box((0.0, -0.08, 0.0), (S, 0.06, S), PLANK_DARK)
    n = 8

    for i in range(n):
        z = -S / 2 + (i + 0.5) * S / n
        faces += box((0.0, 0.0, z), (S, 0.1, S / n - 0.03), shade(PLANK, 0.9 + 0.2 * ((i * 5) % 7) / 6.0))

    return faces


def log_slab():
    faces = []

    for i in range(6):
        faces += moved(prism(0.17, S, 8, BARK, LOG_END, ring=LOG_RING, seed=40 + i), shift=(0.0, 0.0, -S / 2 + 0.17 + i * 0.334))

    return faces


def tile_slab(colour, dark, n, seed, base=MORTAR, offset=False, thick=0.12):
    rng = np.random.default_rng(seed)
    faces = box((0.0, -0.06, 0.0), (S, 0.08, S), base)
    t = S / n

    for r in range(n):
        shift = t / 2 if (offset and r % 2) else 0.0
        x = -S / 2 - shift

        while x < S / 2 - 0.02:
            x0, x1 = max(x, -S / 2), min(x + t, S / 2)

            if x1 - x0 > 0.06:
                c = colour if rng.random() > 0.3 else dark
                faces += box(((x0 + x1) / 2, rng.uniform(0.0, 0.02), -S / 2 + (r + 0.5) * t), (x1 - x0 - 0.05, thick, t - 0.05), shade(c, rng.uniform(0.88, 1.1)))

            x += t

    return faces


def brick_slab():
    rng = np.random.default_rng(52)
    faces = box((0.0, -0.06, 0.0), (S, 0.08, S), MORTAR)
    rows, bw = 8, S / 4

    for r in range(rows):
        x = -S / 2 - (bw / 2 if r % 2 else 0.0)

        while x < S / 2 - 0.02:
            x0, x1 = max(x, -S / 2), min(x + bw, S / 2)

            if x1 - x0 > 0.06:
                c = BRICK if rng.random() > 0.3 else BRICK_DARK
                faces += box(((x0 + x1) / 2, 0.0, -S / 2 + (r + 0.5) * S / rows), (x1 - x0 - 0.04, 0.1, S / rows - 0.04), shade(c, rng.uniform(0.9, 1.1)))

            x += bw

    return faces


def thatch_slab():
    """A thatch foundation on stakes: a woven straw mat on a pole frame, stakes under the corners."""
    faces = []

    for x in (-S / 2 + 0.1, S / 2 - 0.1):
        for z in (-S / 2 + 0.1, S / 2 - 0.1):
            faces += box((x, -0.32, z), (0.12, 0.5, 0.12), BARK)

    for z in (-S / 2 + 0.1, S / 2 - 0.1):
        faces += box((0.0, -0.1, z), (S, 0.12, 0.12), BARK)

    for i in range(10):
        z = -S / 2 + (i + 0.5) * S / 10
        faces += box((0.0, 0.0, z), (S - 0.1, 0.1, S / 10 - 0.03), STRAW if i % 2 == 0 else STRAW_DARK)

    return faces


def foundation():
    """A stone and clay slab: a thick block with a clay top and stone edge blocks."""
    rng = np.random.default_rng(61)
    faces = box((0.0, -0.05, 0.0), (S - 0.1, 0.36, S - 0.1), CLAY)

    for i in range(4):
        for side in (-1, 1):
            k = rng.uniform(0.88, 1.08)
            faces += box((-S / 2 + (i + 0.5) * S / 4, -0.05, side * (S / 2 - 0.08)), (S / 4 - 0.05, 0.42, 0.18), shade(STONE, k))
            faces += box((side * (S / 2 - 0.08), -0.05, -S / 2 + (i + 0.5) * S / 4), (0.18, 0.42, S / 4 - 0.05), shade(STONE_DARK, k))

    return faces


SLAB_VIEW = rot_y(math.radians(8.0)) @ rot_x(math.radians(12.0))


# ---------------------------------------------------------------- roofs (a gable: two slopes meeting at the ridge)
RW, RL = 2.0, 1.25            # along the ridge, down each slope
PITCH = math.radians(35.0)


def _slope(side):
    """The turn and shift that lay a flat panel (along x, down z from the ridge at z = -RL/2) as one slope of the gable."""
    turn = rot_x(side * PITCH) if side > 0 else rot_y(math.pi) @ rot_x(PITCH)
    shift = turn @ np.array([0.0, 0.0, RL / 2])
    return turn, shift


def roof(course_colour, dark, rows, cols, seed, thick=0.08, overlap=0.06, base=PLANK_DARK, straw=False):
    """Both slopes of a pitched roof: a deck, then courses laid from the eaves up, each overlapping the one below, and a ridge."""
    rng = np.random.default_rng(seed)
    faces = []

    for side in (1, -1):
        turn, shift = _slope(side)
        faces += moved(box((0.0, 0.0, 0.0), (RW, 0.05, RL), base), turn, shift)
        rh = RL / rows

        for r in range(rows):
            z = RL / 2 - (r + 0.5) * rh
            cw = RW / cols
            x = -RW / 2 - (cw / 2 if r % 2 else 0.0)

            while x < RW / 2 - 0.02:
                x0, x1 = max(x, -RW / 2), min(x + cw, RW / 2)

                if x1 - x0 > 0.05:
                    c = course_colour if rng.random() > 0.3 else dark
                    lift = 0.03 + thick / 2 + 0.03 * (rows - r) / rows
                    faces += moved(box(((x0 + x1) / 2, lift, z), (x1 - x0 - (0.0 if straw else 0.025), thick, rh + overlap), shade(c, rng.uniform(0.9, 1.08))), turn, shift)

                x += cw

    faces += box((0.0, 0.06, 0.0), (RW + 0.12, 0.16, 0.2), dark)
    return faces


def plank_roof():
    return roof(PLANK, PLANK_DARK, 5, 4, seed=71)


def log_roof():
    """Rustic - Roof (seven-tier ladder, 10 Nov 2026): bark shingles over log rafters, grey-brown and rough, not the logs themselves."""
    return roof((112, 92, 72), (70, 56, 42), 6, 6, seed=70, thick=0.07, base=BARK)


def stone_roof():
    return roof(SLATE, shade(SLATE, 0.8), 6, 5, seed=72, thick=0.06, base=STONE_DARK)


def brick_roof():
    return roof(TILE, BRICK_DARK, 7, 7, seed=73, thick=0.07)


def thatch_roof():
    return roof(STRAW, STRAW_DARK, 4, 12, seed=74, thick=0.18, overlap=0.1, base=BARK, straw=True)


ROOF_VIEW = rot_y(math.radians(-62.0))


# ---------------------------------------------------------------- stairs and ladder
def stairs():
    """Five wooden steps: each a tread on its riser, closed in by a side board on the far side."""
    faces = []
    steps, rise, run = 5, 0.24, 0.3

    for i in range(steps):
        top = -0.6 + (i + 1) * rise
        z = 0.6 - i * run
        faces += box((0.0, (top - 0.6) / 2, z), (1.0, top + 0.6 - 0.05, run), shade(PLANK_DARK, 0.95 + 0.05 * (i % 2)))
        faces += box((0.0, top - 0.025, z + 0.02), (1.06, 0.06, run + 0.06), PLANK)

    for i in range(steps):
        top = -0.6 + (i + 1) * rise
        faces += box((-0.53, (top - 0.6) / 2, 0.6 - i * run), (0.06, top + 0.6, run), BARK)

    return faces


def ladder():
    """Two thick rails and five rungs, short and leaned on the diagonal so it fills the square (a tall thin ladder was a few lines at 57 px)."""
    faces = []

    for side in (-1, 1):
        faces += moved(prism(0.085, 2.0, 6, BARK, LOG_END, seed=90 + side), rot_z(math.radians(90.0)), shift=(side * 0.4, 0.0, 0.0))

    for i in range(5):
        faces += moved(prism(0.06, 0.92, 6, PLANK, LOG_END, seed=95 + i), shift=(0.0, -0.76 + i * 0.38, 0.0))

    return faces


LADDER_VIEW = rot_y(math.radians(25.0)) @ rot_z(math.radians(-38.0))


# ---------------------------------------------------------------- logs by species and driftwood (a small stack of three)
SPECIES = {                    # bark, end grain, ring
    "log_beech": ((150, 146, 138), (226, 200, 154), (204, 172, 120)),
    "log_birch": ((228, 224, 212), (234, 214, 172), (210, 184, 136)),
    "log_maple": ((124, 108, 92), (232, 208, 162), (208, 178, 128)),
    "log_oak": ((96, 74, 52), (208, 172, 120), (176, 138, 88)),
    "log_scots_pine": ((172, 98, 58), (234, 206, 152), (206, 170, 110)),
    "log_spruce": ((106, 92, 76), (238, 216, 172), (214, 186, 136)),
    "log_tropical_hardwood": ((92, 54, 40), (156, 76, 50), (126, 58, 38)),
    "log_walnut": ((80, 66, 54), (136, 96, 64), (108, 74, 48)),
}
BIRCH_MARK = (52, 48, 44)


def species_log(bark, end, ring, length, radius, seed, marks=False):
    faces = prism(radius, length, 9, bark, end, ring=ring, seed=seed)

    if marks:                  # birch: dark lenticel bands on some of the bark facets
        faces = [(pts, BIRCH_MARK if i < 9 and i % 3 == 1 else colour) for i, (pts, colour) in enumerate(faces)]

    return faces


def log_stack(name):
    bark, end, ring = SPECIES[name]
    r = 0.3
    faces = []

    for i, (x, y, z) in enumerate(((0.0, -r, -r * 1.02), (0.06, -r, r * 1.02), (-0.05, r * 0.72, 0.0))):
        faces += moved(species_log(bark, end, ring, 2.0 - 0.15 * i, r, seed=100 + i + len(name), marks=name == "log_birch"), shift=(x, y, z))

    return faces


def driftwood():
    """A bleached, barkless branch, bent and tapering, with a snapped side limb."""
    grey, end = (184, 178, 166), (204, 196, 180)
    faces = prism(0.36, 2.2, 7, grey, end, bend=0.6, taper=0.55, seed=111)
    limb = prism(0.16, 0.8, 6, grey, end, taper=0.5, seed=112)
    faces += moved(limb, rot_z(math.radians(42.0)), shift=(0.35, 0.28, 0.0))
    return faces


LOG_VIEW = rot_y(math.radians(-120.0))


# ---------------------------------------------------------------- furniture, beds and storage
LINEN = (232, 224, 204)
BLANKET = (150, 62, 48)
WOOL_RED = (168, 64, 50)
WOOL_CREAM = (226, 210, 176)
HIDE = (150, 112, 74)
FUR = (122, 92, 64)
IRON = (74, 72, 72)
STEEL = (150, 150, 156)
LEAF = (88, 132, 64)
PETAL = (214, 92, 84)
POT = (178, 96, 60)
ANTLER = (222, 204, 170)


def upright(radius, height, sides, colour, top, x=0.0, y=0.0, z=0.0, taper=1.0, seed=0):
    """A vertical prism standing on (x, y, z): its foot at y, its top at y + height."""
    return moved(prism(radius, height, sides, colour, top, taper=taper, seed=seed), rot_z(math.pi / 2), shift=(x, y + height / 2, z))


def legs(w, d, h, size, colour, inset=0.06):
    faces = []

    for sx in (-1, 1):
        for sz in (-1, 1):
            faces += box((sx * (w / 2 - inset), h / 2, sz * (d / 2 - inset)), (size, h, size), colour)

    return faces


def stool():
    faces = upright(0.42, 0.1, 8, PLANK, shade(PLANK, 1.08), y=0.62, seed=120)

    for a in (90.0, 210.0, 330.0):
        r = math.radians(a)
        faces += moved(box((0.0, 0.0, 0.0), (0.08, 0.7, 0.08), PLANK_DARK), rot_x(math.radians(8.0) * math.sin(r)) @ rot_z(math.radians(8.0) * math.cos(r)), shift=(0.28 * math.cos(r), 0.33, 0.28 * math.sin(r)))

    return faces


def chair():
    faces = box((0.0, 0.62, 0.0), (0.8, 0.08, 0.76), PLANK)
    faces += legs(0.8, 0.76, 0.6, 0.08, PLANK_DARK)

    for sx in (-1, 1):
        faces += box((sx * 0.34, 1.05, -0.34), (0.08, 0.9, 0.08), PLANK_DARK)

    for y in (0.95, 1.22, 1.44):
        faces += box((0.0, y, -0.34), (0.68, 0.1, 0.05), PLANK)

    return faces


def bench():
    faces = box((0.0, 0.66, 0.0), (2.0, 0.1, 0.5), PLANK)

    for sx in (-1, 1):
        faces += box((sx * 0.75, 0.32, 0.0), (0.1, 0.62, 0.42), PLANK_DARK)
        faces += box((sx * 0.75, 0.06, 0.0), (0.16, 0.1, 0.5), PLANK_DARK)

    faces += box((0.0, 0.28, 0.0), (1.5, 0.08, 0.06), PLANK_DARK)
    return faces


def table():
    faces = box((0.0, 0.92, 0.0), (1.8, 0.1, 1.0), PLANK)

    for i in range(5):
        faces += box((0.0, 0.975, -0.4 + i * 0.2), (1.8, 0.012, 0.012), PLANK_DARK)

    faces += legs(1.8, 1.0, 0.88, 0.1, PLANK_DARK, inset=0.12)
    faces += box((0.0, 0.8, 0.0), (1.4, 0.1, 0.06), PLANK_DARK)
    return faces


def log_seat():
    faces = moved(prism(0.3, 1.8, 9, BARK, LOG_END, ring=LOG_RING, seed=121), shift=(0.0, 0.3, 0.0))
    faces += box((0.0, 0.57, 0.0), (1.7, 0.06, 0.36), shade(LOG_END, 0.95))     # the adzed seat
    return faces


def bed(frame, mattress, blanket, posts=0.0, canopy=None, logs=False, low=False):
    """A frame (or logs), a mattress, a pillow and a blanket over the foot; posts and a canopy for the canopy bed."""
    faces = []
    w, l, h = 1.2, 2.0, (0.12 if low else 0.36)

    if logs:
        for sx in (-1, 1):
            faces += moved(prism(0.13, l + 0.15, 8, BARK, LOG_END, ring=LOG_RING, seed=125 + sx), rot_y(math.pi / 2), shift=(sx * (w / 2 - 0.08), 0.13, 0.0))
    elif not low:
        faces += box((0.0, 0.22, 0.0), (w, 0.16, l), frame)
        faces += legs(w, l, 0.18, 0.1, shade(frame, 0.85))
        faces += box((0.0, 0.5, -l / 2 + 0.05), (w, 0.7, 0.1), frame)        # headboard

    top = h + 0.14
    faces += box((0.0, h + 0.07, 0.03), (w - 0.1, 0.16, l - 0.12), mattress)
    faces += box((0.0, top + 0.06, -l / 2 + 0.3), (w - 0.3, 0.12, 0.34), LINEN)
    faces += box((0.0, top + 0.02, 0.38), (w - 0.04, 0.06, l * 0.6), blanket)

    if posts:
        for sx in (-1, 1):
            for sz in (-1, 1):
                faces += box((sx * (w / 2 - 0.04), posts / 2, sz * (l / 2 - 0.04)), (0.08, posts, 0.08), frame)

    if canopy is not None:
        faces += box((0.0, posts, 0.0), (w + 0.04, 0.06, l + 0.04), canopy)
        faces += box((0.0, posts - 0.2, l / 2 - 0.03), (w, 0.36, 0.03), canopy)

    return faces


def straw_bed():
    """A mattress of straw on the ground: a low heaped bed, loose tufts round its edge and a hide over half of it."""
    rng = np.random.default_rng(130)
    faces = box((0.0, 0.1, 0.0), (1.1, 0.2, 1.9), STRAW)
    faces += box((0.0, 0.24, -0.1), (0.9, 0.1, 1.6), shade(STRAW, 1.06))

    for i in range(22):
        a = i * 2 * math.pi / 22
        x, z = 0.6 * math.cos(a), 1.0 * math.sin(a)
        faces += moved(box((0.0, 0.0, 0.0), (0.32, 0.07, 0.07), STRAW_DARK if i % 2 else STRAW), rot_y(-a + rng.uniform(-0.4, 0.4)), shift=(x, 0.05 + rng.uniform(0.0, 0.06), z))

    faces += box((0.0, 0.31, 0.45), (1.0, 0.05, 0.85), shade(HIDE, 1.05))
    faces += box((0.0, 0.33, -0.65), (0.6, 0.1, 0.3), LINEN)
    return faces


def woven_chest():
    faces = []
    n = 9

    for i in range(n):
        x = -0.6 + (i + 0.5) * 1.2 / n
        faces += box((x, 0.32, 0.0), (1.2 / n - 0.01, 0.62, 0.82), STRAW if i % 2 else STRAW_DARK)

    for y in (0.14, 0.34, 0.54):
        faces += box((0.0, y, 0.0), (1.24, 0.05, 0.86), WATTLE)

    faces += box((0.0, 0.68, 0.0), (1.28, 0.1, 0.9), STRAW_DARK)
    faces += box((0.0, 0.75, 0.0), (0.3, 0.05, 0.12), WATTLE)
    return faces


def plank_chest():
    faces = box((0.0, 0.32, 0.0), (1.2, 0.62, 0.8), PLANK)

    for y in (0.16, 0.32, 0.48):
        faces += box((0.0, y, 0.0), (1.21, 0.012, 0.81), PLANK_DARK)

    faces += box((0.0, 0.7, 0.0), (1.26, 0.14, 0.86), shade(PLANK, 1.06))

    for x in (-0.42, 0.42):
        faces += box((x, 0.42, 0.0), (0.08, 0.86, 0.9), IRON)

    faces += box((0.0, 0.58, 0.44), (0.14, 0.18, 0.04), IRON)
    return faces


def tool_rack():
    faces = []

    for sx in (-1, 1):
        faces += box((sx * 0.8, 0.7, 0.0), (0.1, 1.4, 0.1), PLANK_DARK)
        faces += box((sx * 0.8, 0.04, 0.0), (0.12, 0.08, 0.5), PLANK_DARK)

    faces += box((0.0, 1.3, 0.0), (1.7, 0.1, 0.1), PLANK)
    faces += box((0.0, 0.5, 0.0), (1.7, 0.08, 0.08), PLANK)

    for i, x in enumerate((-0.5, 0.0, 0.5)):
        faces += box((x, 0.82, 0.08), (0.06, 0.95, 0.06), PLANK)      # handle
        head = [(0.34, 0.2), (0.16, 0.36), (0.42, 0.14)][i]       # an axe, a spade, a hoe
        faces += box((x + (head[0] / 2 - 0.03 if i != 1 else 0.0), 0.36, 0.08), (head[0], head[1], 0.06), STEEL)

    return faces


def rug(colours, stripes, fringe=None, hide=False, seed=0):
    if hide:
        rng = np.random.default_rng(seed)
        faces = []
        outline = [(math.cos(a) * (1.0 + 0.18 * math.cos(4 * a)) * 1.1, math.sin(a) * (1.0 + 0.18 * math.cos(4 * a)) * 0.75) for a in np.linspace(0, 2 * math.pi, 16, endpoint=False)]

        for i, (x, z) in enumerate(outline):
            nx, nz = outline[(i + 1) % len(outline)]
            c = shade(HIDE, rng.uniform(0.9, 1.06))
            faces.append(([np.array([0.0, 0.05, 0.0]), np.array([nx, 0.05, nz]), np.array([x, 0.05, z])], c))
            faces.append(([np.array([x, 0.0, z]), np.array([nx, 0.0, nz]), np.array([nx, 0.05, nz]), np.array([x, 0.05, z])], shade(FUR, 0.9)))

        return [(_outward(pts, np.array([0.0, -1.0, 0.0])), c) for pts, c in faces]

    faces = []
    n = len(stripes)

    for i, k in enumerate(stripes):
        faces += box((0.0, 0.03, -0.75 + (i + 0.5) * 1.5 / n), (2.2, 0.05, 1.5 / n), colours[k])

    if fringe:
        for x in np.linspace(-1.05, 1.05, 14):
            for side in (-1, 1):
                faces += box((x, 0.02, side * 0.8), (0.04, 0.02, 0.12), fringe)

    return faces


def antler_mount():
    """A pair of antlers on a round wooden plaque, hung flat on the wall (seen from the front)."""
    faces = moved(prism(0.5, 0.12, 10, PLANK_DARK, PLANK, seed=140), rot_y(math.pi / 2))

    for sx in (-1, 1):
        root = np.array([sx * 0.12, 0.12, 0.12])
        beam = rot_z(math.radians(90.0 - sx * 38.0))        # up and out
        tip = root + beam @ np.array([1.0, 0.0, 0.0])
        faces += moved(prism(0.06, 1.0, 6, ANTLER, ANTLER, taper=0.45, seed=141), beam, shift=tuple(root + beam @ np.array([0.5, 0.0, 0.0])))

        for t in (0.35, 0.7):
            start = root + beam @ np.array([t, 0.0, 0.0])
            tine = rot_z(math.radians(90.0 - sx * 14.0))
            faces += moved(prism(0.04, 0.38, 6, ANTLER, ANTLER, taper=0.4, seed=142), tine, shift=tuple(start + tine @ np.array([0.19, 0.0, 0.0])))

        faces += box(tuple(tip), (0.07, 0.07, 0.07), ANTLER)

    return faces


def flower_pot():
    faces = upright(0.3, 0.5, 8, POT, shade(POT, 0.7), taper=1.3, seed=150)
    faces += upright(0.4, 0.08, 8, shade(POT, 1.08), (70, 50, 36), y=0.46, seed=151)
    rng = np.random.default_rng(152)

    for i in range(7):
        a = i * 2 * math.pi / 7
        lean = 18.0 + 14.0 * (i % 2)
        stem = rot_y(a) @ rot_z(math.radians(90.0 - lean))
        base = np.array([0.0, 0.54, 0.0])
        length = 0.75 + 0.15 * (i % 3)
        faces += moved(prism(0.03, length, 5, LEAF, LEAF, seed=153 + i), stem, shift=tuple(base + stem @ np.array([length / 2, 0.0, 0.0])))
        faces += box(tuple(base + stem @ np.array([length, 0.0, 0.0])), (0.2, 0.16, 0.2), PETAL if i % 2 == 0 else (236, 200, 90))
        leaf_at = base + stem @ np.array([length * 0.4, 0.0, 0.0])
        faces += moved(box((0.1, 0.0, 0.0), (0.22, 0.03, 0.1), shade(LEAF, rng.uniform(0.9, 1.15))), rot_y(a), shift=tuple(leaf_at))

    return faces


FURNITURE_VIEW = rot_y(math.radians(-25.0))


# ---------------------------------------------------------------- stations, fires, lights and the rest
COAL = (236, 112, 40, 1)        # a fourth value marks a glowing face (not lit by the rig)
EMBER = (196, 64, 30, 1)
FLAME = (255, 196, 80, 1)
FLAME_CORE = (255, 236, 160, 1)
BLACK_IRON = (46, 44, 46)
GOLD = (212, 170, 76)
GEM = (190, 30, 40, 1)
SOIL = (104, 76, 54)
SOIL_DARK = (78, 56, 40)
CORD = (200, 180, 140)
WATER = (84, 130, 156)
CLOTH = (112, 98, 78)
LEATHER = (124, 82, 50)


def coals(x, y, z, w, d):
    rng = np.random.default_rng(int(abs(x * 100 + z * 10 + w * 7)))
    faces = box((x, y, z), (w, 0.06, d), EMBER)

    for _ in range(7):
        faces += box((x + rng.uniform(-w / 3, w / 3), y + 0.05, z + rng.uniform(-d / 3, d / 3)), (w / 4, 0.08, d / 4), COAL)

    return faces


def flame(x, y, z, size):
    faces = box((x, y + size * 0.35, z), (size * 0.7, size * 0.7, size * 0.7), FLAME)
    faces += box((x, y + size * 0.85, z), (size * 0.38, size * 0.5, size * 0.38), FLAME)
    faces += box((x, y + size * 0.3, z + size * 0.2), (size * 0.36, size * 0.4, size * 0.36), FLAME_CORE)
    return faces


def stones_ring(r, n, y=0.08, size=0.2, seed=0):
    rng = np.random.default_rng(seed)
    faces = []

    for i in range(n):
        a = i * 2 * math.pi / n
        faces += moved(box((0.0, 0.0, 0.0), (size * 1.3, size, size), shade(STONE, rng.uniform(0.85, 1.1))), rot_y(-a), shift=(r * math.cos(a), y, r * math.sin(a)))

    return faces


def stone_forge():
    """Basic forge: a rough stone and clay hearth under a log lean-to, coals glowing."""
    rng = np.random.default_rng(170)
    faces = box((0.0, 0.35, 0.0), (1.2, 0.7, 0.9), CLAY)

    for i in range(10):
        faces += box((rng.uniform(-0.6, 0.6), rng.uniform(0.1, 0.65), 0.46), (0.24, 0.18, 0.06), shade(STONE, rng.uniform(0.8, 1.1)))

    faces += coals(0.0, 0.72, 0.0, 0.8, 0.55)

    for sx in (-1, 1):
        faces += box((sx * 0.8, 0.8, -0.55), (0.1, 1.6, 0.1), BARK)

    roof = rot_x(math.radians(28.0))         # the log lean-to over it

    for i in range(6):
        faces += moved(moved(prism(0.07, 1.9, 6, BARK, LOG_END, seed=171 + i), shift=(0.0, 0.0, -0.4 + i * 0.16)), roof, shift=(0.0, 1.6, -0.4))

    return faces


def stepped_forge():
    """Medium forge: a dressed stone block, a stepped hood over the fire and iron straps."""
    faces = box((0.0, 0.4, 0.0), (1.3, 0.8, 1.0), shade(STONE, 1.05))
    faces += box((0.0, 0.62, 0.48), (0.7, 0.3, 0.08), (40, 32, 28))
    faces += coals(0.0, 0.62, 0.52, 0.6, 0.04)
    faces += coals(0.0, 0.82, 0.0, 0.9, 0.6)

    for i, (w, h) in enumerate(((1.2, 0.3), (0.9, 0.3), (0.6, 0.3), (0.35, 0.5))):
        faces += box((0.0, 1.05 + i * 0.3 + h / 2 - 0.15, -0.15), (w, h, 0.6 - 0.08 * i), shade(STONE, 0.95 - 0.04 * i))

    for x in (-0.45, 0.45):
        faces += box((x, 0.4, 0.0), (0.07, 0.82, 1.02), IRON)

    return faces


def large_forge():
    """Large forge: a brick firebox with a glowing arch, a riveted iron frame and a chimney."""
    faces = box((0.0, 0.6, 0.0), (1.6, 1.2, 1.1), BRICK)
    faces += box((0.0, 0.5, 0.54), (0.8, 0.6, 0.06), (40, 30, 26))
    faces += box((0.0, 0.83, 0.54), (0.56, 0.12, 0.06), (40, 30, 26))
    faces += coals(0.0, 0.32, 0.56, 0.7, 0.04)
    faces += box((0.0, 0.5, 0.575), (0.5, 0.3, 0.02), FLAME)
    faces += box((0.0, 1.6, -0.2), (0.6, 0.8, 0.5), BRICK_DARK)

    for x in (-0.8, 0.8):
        faces += box((x, 0.6, 0.0), (0.1, 1.24, 1.14), BLACK_IRON)

    for y in (0.08, 1.18):
        faces += box((0.0, y, 0.0), (1.64, 0.1, 1.14), BLACK_IRON)

    for x in np.linspace(-0.7, 0.7, 6):
        faces += box((x, 1.18, 0.575), (0.05, 0.05, 0.02), STEEL)

    return faces


def master_forge():
    """Master forge: black iron with gold trim and red gems, always glowing."""
    faces = box((0.0, 0.55, 0.0), (1.5, 1.1, 1.0), BLACK_IRON)
    faces += box((0.0, 0.55, 0.51), (0.8, 0.55, 0.04), (255, 140, 50, 1))
    faces += box((0.0, 0.55, 0.53), (0.5, 0.3, 0.02), FLAME_CORE)

    for y in (0.06, 1.08):
        faces += box((0.0, y, 0.0), (1.56, 0.08, 1.06), GOLD)

    for x in (-0.77, 0.77):
        faces += box((x, 0.57, 0.0), (0.06, 1.1, 1.06), GOLD)

    for x in (-0.55, 0.55):
        faces += box((x, 0.85, 0.52), (0.14, 0.14, 0.06), GEM)

    faces += box((0.0, 1.35, -0.1), (1.0, 0.5, 0.7), BLACK_IRON)
    faces += box((0.0, 1.62, -0.1), (1.06, 0.06, 0.76), GOLD)
    faces += box((0.0, 1.38, 0.26), (0.18, 0.18, 0.04), GEM)
    return faces


def oven():
    """A brick oven: a stepped dome, an iron door and a short flue."""
    faces = box((0.0, 0.3, 0.0), (1.4, 0.6, 1.3), BRICK_DARK)

    for i, (w, h) in enumerate(((1.3, 0.3), (1.1, 0.25), (0.8, 0.2), (0.45, 0.15))):
        faces += box((0.0, 0.6 + sum(hh for _, hh in ((1.3, 0.3), (1.1, 0.25), (0.8, 0.2), (0.45, 0.15))[:i]) + h / 2, 0.0), (w, h, w * 0.95), shade(BRICK, 1.0 - 0.04 * i))

    faces += box((0.0, 0.78, 0.6), (0.5, 0.36, 0.06), IRON)
    faces += box((0.18, 0.78, 0.64), (0.06, 0.06, 0.04), STEEL)
    faces += box((0.35, 1.5, -0.3), (0.2, 0.4, 0.2), BRICK_DARK)
    return faces


def clay_hearth():
    """A clay hearth ring with a fire and a spit on two forked sticks."""
    faces = upright(0.7, 0.3, 10, CLAY, shade(CLAY, 0.8), seed=180)
    faces += coals(0.0, 0.31, 0.0, 0.8, 0.8)
    faces += flame(0.0, 0.32, 0.0, 0.5)

    for sx in (-1, 1):
        faces += box((sx * 0.85, 0.55, 0.0), (0.07, 1.1, 0.07), BARK)
        faces += moved(box((0.0, 0.0, 0.0), (0.06, 0.25, 0.06), BARK), rot_z(sx * 0.5), shift=(sx * 0.9, 1.15, 0.0))

    faces += box((0.0, 1.08, 0.0), (1.9, 0.05, 0.05), PLANK)
    faces += moved(prism(0.13, 0.5, 8, (150, 70, 50), (190, 110, 80), seed=181), shift=(0.0, 0.98, 0.0))
    return faces


def fireplace():
    """A brick hearth with a chimney stack and a fire in the opening."""
    faces = box((0.0, 0.55, 0.0), (1.4, 1.1, 0.7), BRICK)
    faces += box((0.0, 0.45, 0.34), (0.8, 0.7, 0.06), (36, 28, 24))
    faces += coals(0.0, 0.16, 0.38, 0.6, 0.06)
    faces += flame(0.0, 0.18, 0.38, 0.4)
    faces += box((0.0, 1.14, 0.08), (1.6, 0.1, 0.86), STONE)
    faces += box((0.0, 1.75, -0.05), (0.7, 1.2, 0.55), BRICK_DARK)
    return faces


def campfire_pot():
    """A pot on a tripod over a small fire in a ring of stones."""
    faces = stones_ring(0.62, 9, seed=185)
    faces += coals(0.0, 0.05, 0.0, 0.7, 0.7)
    faces += flame(0.0, 0.08, 0.0, 0.42)

    for a in (90.0, 210.0, 330.0):
        r = math.radians(a)
        foot = np.array([0.8 * math.cos(r), 0.0, 0.8 * math.sin(r)])
        top = np.array([0.0, 1.6, 0.0])
        mid = (foot + top) / 2.0
        d = top - foot
        length = float(np.linalg.norm(d))
        yaw = math.atan2(-d[2], d[0])
        pitch = math.asin(d[1] / length)
        faces += moved(prism(0.04, length, 6, BARK, LOG_END, seed=186), rot_y(yaw) @ rot_z(pitch), shift=tuple(mid))

    faces += box((0.0, 1.2, 0.0), (0.02, 0.6, 0.02), IRON)
    faces += upright(0.32, 0.4, 8, IRON, (60, 58, 58), y=0.62, taper=0.85, seed=187)
    return faces


def chandelier():
    """A hanging hoop of candles on three chains."""
    faces = []
    n, r = 12, 0.8

    for i in range(n):
        a, b = i * 2 * math.pi / n, (i + 1) * 2 * math.pi / n
        mid = ((math.cos(a) + math.cos(b)) * r / 2, 0.0, (math.sin(a) + math.sin(b)) * r / 2)
        faces += moved(box((0.0, 0.0, 0.0), (2 * r * math.sin(math.pi / n) + 0.02, 0.08, 0.08), BLACK_IRON), rot_y(-(a + b) / 2 + math.pi / 2), shift=mid)

    for i in range(6):
        a = i * 2 * math.pi / 6
        x, z = r * math.cos(a), r * math.sin(a)
        faces += box((x, 0.18, z), (0.1, 0.28, 0.1), LINEN)
        faces += box((x, 0.38, z), (0.07, 0.12, 0.07), FLAME)

    for i in range(3):
        a = i * 2 * math.pi / 3 + 0.5
        top = np.array([0.0, 1.5, 0.0])
        foot = np.array([r * math.cos(a), 0.0, r * math.sin(a)])
        for t in np.linspace(0.08, 0.92, 7):
            faces += box(tuple(foot + (top - foot) * t), (0.04, 0.09, 0.04), IRON)

    faces += box((0.0, 1.55, 0.0), (0.14, 0.1, 0.14), BLACK_IRON)
    return faces


def torch(length=1.3, radius=0.05, flame_size=0.32):
    faces = moved(prism(radius, length, 6, PLANK_DARK, LOG_END, seed=190), rot_z(math.pi / 2), shift=(0.0, length / 2, 0.0))
    faces += upright(radius * 1.8, 0.22, 6, CLOTH, (60, 50, 40), y=length - 0.2, seed=191)
    faces += flame(0.0, length, 0.0, flame_size)
    return faces


def standing_torch():
    """A short thick torch on a wide base of earth and stones, so the pole is not a hairline at 57 px."""
    faces = torch(1.1, radius=0.09, flame_size=0.46)
    faces += box((0.0, 0.05, 0.0), (0.7, 0.1, 0.7), SOIL)
    faces += stones_ring(0.3, 6, y=0.12, size=0.14, seed=192)
    return faces


def torch_sconce():
    """A torch wedged on a wall: a board on the wall, the torch leaning out of a crack in it."""
    faces = box((0.0, 0.6, -0.1), (0.9, 1.4, 0.12), PLANK)
    faces += moved(torch(1.0), rot_x(math.radians(28.0)), shift=(0.0, 0.2, 0.0))
    return faces


def wall_torch():
    """A torch in an iron bracket on a stone plate."""
    faces = box((0.0, 0.6, -0.12), (0.6, 1.2, 0.1), STONE)
    faces += box((0.0, 0.55, 0.0), (0.12, 0.08, 0.26), BLACK_IRON)
    faces += box((0.0, 0.62, 0.12), (0.2, 0.06, 0.2), BLACK_IRON)
    faces += moved(torch(0.9), rot_x(math.radians(18.0)), shift=(0.0, 0.25, 0.1))
    return faces


def camp_bench():
    """A camp bench: split logs on two stumps."""
    faces = []

    for sx in (-1, 1):
        faces += upright(0.24, 0.7, 8, BARK, LOG_END, x=sx * 0.7, seed=195 + sx)

    for z in (-0.18, 0.18):
        faces += box((0.0, 0.76, z), (2.0, 0.12, 0.34), shade(LOG_END, 0.92))
        faces += moved(prism(0.17, 2.0, 8, BARK, LOG_END, seed=197), shift=(0.0, 0.68, z))

    return faces


def log_workbench():
    """A log workbench with its own tool rack and a vice on the end."""
    faces = camp_bench()
    faces += box((-0.5, 1.4, -0.4), (0.08, 1.2, 0.08), BARK)
    faces += box((0.5, 1.4, -0.4), (0.08, 1.2, 0.08), BARK)
    faces += box((0.0, 1.8, -0.4), (1.1, 0.08, 0.08), BARK)
    faces += box((-0.25, 1.5, -0.36), (0.22, 0.14, 0.04), STEEL)
    faces += box((0.25, 1.45, -0.36), (0.08, 0.5, 0.04), PLANK)
    faces += vice_faces(shift=(0.95, 0.82, 0.0), scale=0.6)
    return faces


def woodworking_table():
    """A plank table with a board on it, a plane and a bench stop."""
    faces = table()
    faces += box((0.1, 1.0, 0.0), (1.2, 0.06, 0.4), shade(PLANK, 1.12))
    faces += box((-0.2, 1.1, 0.0), (0.4, 0.12, 0.14), PLANK_DARK)
    faces += box((-0.2, 1.18, 0.0), (0.06, 0.1, 0.06), PLANK_DARK)
    faces += box((-0.8, 1.02, -0.3), (0.06, 0.1, 0.06), IRON)
    return faces


def vice_faces(shift=(0.0, 0.0, 0.0), scale=1.0):
    k = scale
    faces = box((0.0, 0.0, -0.16 * k), (0.5 * k, 0.6 * k, 0.16 * k), PLANK_DARK)
    faces += box((0.0, 0.0, 0.16 * k), (0.5 * k, 0.6 * k, 0.16 * k), PLANK)
    faces += moved(prism(0.05 * k, 0.9 * k, 6, PLANK_DARK, LOG_END, seed=199), rot_y(math.pi / 2), shift=(0.0, -0.1 * k, 0.1 * k))
    faces += box((0.0, -0.1 * k, 0.58 * k), (0.5 * k, 0.05 * k, 0.05 * k), PLANK_DARK)
    return moved(faces, shift=shift)


def vice():
    faces = vice_faces(shift=(0.0, 0.9, 0.0))
    faces += box((0.0, 0.42, 0.0), (0.4, 0.84, 0.5), BARK)
    return faces


def saw_mill():
    """A water-driven sawmill: a wheel in its race, the frame and a log on the carriage under the blade."""
    faces = []
    n, r = 12, 0.75
    hub = np.array([-1.0, 0.85, 0.0])

    for i in range(n):              # the wheel, in the y-z plane: rim, spokes and paddles
        a = i * 2 * math.pi / n
        b = a + 2 * math.pi / n
        radial = np.array([0.0, math.cos(a), math.sin(a)])
        mid = np.array([0.0, (math.cos(a) + math.cos(b)) / 2, (math.sin(a) + math.sin(b)) / 2]) * r
        faces += moved(box((0.0, 0.0, 0.0), (0.12, 0.07, 2 * r * math.sin(math.pi / n) + 0.04), PLANK_DARK), rot_x(-(a + b) / 2), shift=tuple(hub + mid))
        faces += moved(box((0.0, 0.0, 0.0), (0.05, r, 0.05), PLANK_DARK), rot_x(-a), shift=tuple(hub + radial * r / 2))
        faces += moved(box((0.0, 0.0, 0.0), (0.3, 0.24, 0.04), PLANK), rot_x(-a), shift=tuple(hub + radial * (r + 0.1)))

    faces += moved(prism(0.08, 0.6, 6, PLANK_DARK, LOG_END, seed=200), shift=(-0.8, 0.85, 0.0))
    faces += box((-1.0, 0.06, 0.0), (0.5, 0.12, 1.8), WATER)
    faces += box((0.4, 0.5, 0.0), (1.8, 0.1, 0.8), PLANK_DARK)
    faces += legs(1.8, 0.8, 0.5, 0.12, PLANK_DARK)
    faces += moved(prism(0.2, 1.6, 8, BARK, LOG_END, ring=LOG_RING, seed=201), shift=(0.4, 0.75, 0.0))

    for sx in (-1, 1):
        faces += box((0.4 + sx * 0.0, 1.2, sx * 0.4), (0.12, 1.4, 0.12), PLANK)

    faces += box((0.4, 1.85, 0.0), (0.16, 0.12, 0.92), PLANK)
    faces += box((0.4, 1.3, 0.0), (0.04, 0.9, 0.3), STEEL)
    return faces


def timber_prop():
    """A stout post under a wide cap board (thicker and shorter than the first paint, which was a stick at 57 px)."""
    faces = upright(0.26, 1.2, 8, BARK, LOG_END, seed=205)
    faces += box((0.0, 1.27, 0.0), (1.0, 0.16, 0.5), PLANK)
    faces += box((0.0, -0.02, 0.0), (0.7, 0.06, 0.7), SOIL)
    return faces


def timber_set():
    """Two posts under a cap log, thick enough to read as a frame at 57 px."""
    faces = []

    for sx in (-1, 1):
        faces += moved(upright(0.21, 1.3, 8, BARK, LOG_END, seed=206 + sx), rot_z(sx * -0.08), shift=(sx * 0.55, 0.0, 0.0))

    faces += moved(prism(0.22, 1.6, 8, BARK, LOG_END, ring=LOG_RING, seed=208), shift=(0.0, 1.42, 0.0))
    return faces


def lean_to():
    """A ridge pole on two forks, sticks and boughs leaned from it to the ground."""
    faces = []

    for sx in (-1, 1):
        faces += box((sx * 0.9, 0.6, -0.5), (0.08, 1.2, 0.08), BARK)
        faces += moved(box((0.0, 0.0, 0.0), (0.06, 0.25, 0.06), BARK), rot_z(sx * 0.5), shift=(sx * 0.95, 1.25, -0.5))

    faces += moved(prism(0.06, 2.1, 6, BARK, LOG_END, seed=210), shift=(0.0, 1.18, -0.5))
    slope = rot_x(math.radians(50.0))         # from the ridge (z -0.5, 1.18 m up) down to the ground at z 0.5

    for i in range(11):
        x = -0.95 + i * 0.19
        faces += moved(moved(prism(0.05, 1.6, 6, BARK, LOG_END, seed=211 + i), rot_y(math.pi / 2)), slope, shift=(x, 0.59, 0.0))

    for i in range(6):
        x = -0.8 + i * 0.32
        faces += moved(box((0.0, 0.07, 0.0), (0.3, 0.05, 1.3), shade(LEAF, 0.8 + 0.06 * (i % 3))), slope, shift=(x, 0.6, 0.02))

    return faces


def snare_trap():
    """A snare: a bent sapling held by a trigger peg, a cord loop over the ground."""
    faces = box((0.0, 0.02, 0.0), (1.4, 0.04, 1.0), SOIL)

    for i in range(8):
        t = i / 7.0
        x = -0.6 + t * 1.0
        y = 0.04 + 1.3 * math.sin(t * math.pi * 0.5) * (1.0 - 0.35 * t)
        nxt = (-0.6 + (t + 1 / 7) * 1.0, 0.04 + 1.3 * math.sin((t + 1 / 7) * math.pi * 0.5) * (1.0 - 0.35 * (t + 1 / 7)))
        ang = math.atan2(nxt[1] - y, nxt[0] - x)
        faces += moved(box((0.0, 0.0, 0.0), (0.18, 0.05, 0.05), BARK), rot_z(ang), shift=(x, y, -0.3))

    faces += box((0.4, 0.15, -0.3), (0.05, 0.3, 0.05), PLANK)
    faces += box((0.4, 0.55, -0.3), (0.01, 0.8, 0.01), CORD)

    for i in range(12):
        a = i * 2 * math.pi / 12
        faces += box((0.4 + 0.25 * math.cos(a), 0.08, 0.15 + 0.25 * math.sin(a)), (0.08, 0.025, 0.025), CORD)

    return faces


def tilled_bed():
    faces = box((0.0, 0.03, 0.0), (1.4, 0.06, 1.4), SOIL_DARK)

    for i in range(5):
        faces += moved(prism(0.1, 1.3, 5, SOIL, SOIL_DARK, seed=215 + i), shift=(0.0, 0.08, -0.56 + i * 0.28))

    return faces


def path_patch():
    rng = np.random.default_rng(220)
    faces = box((0.0, 0.03, 0.0), (1.4, 0.06, 1.4), (150, 124, 92))

    for i in range(14):
        faces += box((rng.uniform(-0.6, 0.6), 0.07, rng.uniform(-0.6, 0.6)), (rng.uniform(0.06, 0.14), 0.04, rng.uniform(0.06, 0.12)), shade(STONE, rng.uniform(0.8, 1.1)))

    for sx in (-1, 1):
        faces += box((sx * 0.72, 0.06, 0.0), (0.12, 0.08, 1.4), shade(LEAF, 0.85))

    return faces


def carcass():
    """A fresh deer carcass lying on its side: the body, a pale belly, the neck and head with an ear, four legs out."""
    hide, belly, dark = (156, 106, 66), (214, 190, 156), (60, 44, 36)
    faces = moved(prism(0.34, 1.3, 9, hide, shade(hide, 0.9), seed=225), shift=(0.0, 0.34, 0.0))
    faces += box((0.0, 0.2, 0.22), (1.0, 0.16, 0.12), belly)
    neck = rot_z(math.radians(28.0))
    faces += moved(prism(0.14, 0.6, 7, hide, hide, seed=226), neck, shift=(0.82, 0.5, 0.0))
    faces += box((1.12, 0.66, 0.0), (0.42, 0.2, 0.2), hide)
    faces += box((1.36, 0.62, 0.0), (0.1, 0.12, 0.14), dark)
    faces += moved(box((0.0, 0.0, 0.0), (0.06, 0.2, 0.1), hide), rot_z(-0.4), shift=(1.0, 0.82, 0.0))

    for x in (-0.48, -0.32, 0.36, 0.52):
        faces += box((x, 0.12, 0.62), (0.08, 0.08, 0.7), hide)
        faces += box((x, 0.12, 0.98), (0.09, 0.09, 0.08), dark)

    faces += box((-0.7, 0.42, 0.0), (0.1, 0.12, 0.12), belly)
    return faces


def remains():
    """A fallen traveller's things: a cloak on the ground, the pack and a staff."""
    faces = box((0.0, 0.06, 0.0), (1.4, 0.12, 0.9), CLOTH)
    faces += box((0.2, 0.18, 0.1), (0.8, 0.14, 0.5), shade(CLOTH, 0.85))
    faces += box((-0.25, 0.4, -0.05), (0.55, 0.6, 0.35), LEATHER)
    faces += box((-0.25, 0.75, -0.05), (0.57, 0.12, 0.37), shade(LEATHER, 1.1))
    faces += moved(prism(0.12, 0.6, 8, (140, 46, 40), (170, 70, 60), seed=230), shift=(-0.25, 0.86, -0.05))
    faces += box((-0.25, 0.4, 0.14), (0.08, 0.5, 0.02), shade(LEATHER, 0.7))
    faces += moved(prism(0.035, 1.8, 6, PLANK_DARK, LOG_END, seed=231), rot_y(math.radians(25.0)), shift=(0.1, 0.05, 0.5))
    return faces


STATION_VIEW = rot_y(math.radians(-25.0))


# ---------------------------------------------------------------- the table: item id -> (faces, model turn)
def _pieces():
    return {
        "wall_section": (plank_wall, WALL_VIEW),
        "doorway_section": (lambda: plank_wall(DOOR), WALL_VIEW),
        "window_section": (lambda: plank_wall(WINDOW), WALL_VIEW),
        "log_wall": (log_wall, WALL_VIEW),
        "stone_wall": (stone_wall, WALL_VIEW),
        "brick_wall": (brick_wall, WALL_VIEW),
        "thatch_wall": (thatch_wall, WALL_VIEW),
        "thatch_doorway": (lambda: thatch_wall(DOOR), WALL_VIEW),
        "floor_section": (plank_slab, SLAB_VIEW),
        "log_floor": (log_slab, SLAB_VIEW),
        "stone_floor": (lambda: tile_slab(STONE, STONE_DARK, 4, seed=50), SLAB_VIEW),
        "brick_floor": (brick_slab, SLAB_VIEW),
        "thatch_floor": (thatch_slab, SLAB_VIEW),
        "foundation_section": (foundation, SLAB_VIEW),
        "wood_foundation": (plank_slab, SLAB_VIEW),
        "roof_section": (plank_roof, ROOF_VIEW),
        "log_roof": (log_roof, ROOF_VIEW),
        "stone_roof": (stone_roof, ROOF_VIEW),
        "brick_roof": (brick_roof, ROOF_VIEW),
        "engineered_roof": (brick_roof, ROOF_VIEW),   # Engineered roofs are clay tile over planks too: no concrete roof
        "thatch_roof": (thatch_roof, ROOF_VIEW),
        "stairs_wood": (stairs, rot_y(math.radians(-50.0))),
        "ladder": (ladder, LADDER_VIEW),
        **{name: ((lambda n=name: log_stack(n)), LOG_VIEW) for name in SPECIES},
        "stool": (stool, FURNITURE_VIEW),
        "chair": (chair, rot_y(math.radians(-40.0))),
        "bench": (bench, FURNITURE_VIEW),
        "table": (table, FURNITURE_VIEW),
        "log_seat": (log_seat, FURNITURE_VIEW),
        "rough_bed": (lambda: bed(BARK, shade(HIDE, 1.05), FUR, logs=True), rot_y(math.radians(-55.0))),
        "straw_bed": (straw_bed, rot_y(math.radians(-55.0)) @ rot_x(math.radians(22.0))),
        "feather_bed": (lambda: bed(PLANK, LINEN, BLANKET), rot_y(math.radians(-55.0))),
        "canopy_bed": (lambda: bed(PLANK_DARK, LINEN, (60, 82, 120), posts=1.9, canopy=(150, 62, 48)), rot_y(math.radians(-55.0))),
        "chest": (woven_chest, FURNITURE_VIEW),
        "plank_chest": (plank_chest, FURNITURE_VIEW),
        "tool_rack": (tool_rack, rot_y(math.radians(-20.0))),
        "hide_rug": (lambda: rug(None, None, hide=True, seed=160), rot_y(math.radians(-10.0)) @ rot_x(math.radians(20.0))),
        "wool_rug": (lambda: rug({0: WOOL_RED, 1: WOOL_CREAM, 2: (60, 82, 120)}, [0, 1, 0, 2, 0, 1, 0], fringe=WOOL_CREAM), rot_y(math.radians(-10.0)) @ rot_x(math.radians(20.0))),
        "antler_mount": (antler_mount, rot_y(math.radians(28.0))),
        "flower_pot": (flower_pot, FURNITURE_VIEW),
        "stone_forge": (stone_forge, STATION_VIEW),
        "blacksmithy": (stepped_forge, STATION_VIEW),
        "large_forge": (large_forge, STATION_VIEW),
        "master_forge": (master_forge, STATION_VIEW),
        "oven": (oven, STATION_VIEW),
        "clay_hearth": (clay_hearth, STATION_VIEW),
        "fireplace": (fireplace, STATION_VIEW),
        "campfire_pot": (campfire_pot, STATION_VIEW),
        "chandelier": (chandelier, rot_x(math.radians(-6.0))),
        "standing_torch": (standing_torch, STATION_VIEW),
        "torch_sconce": (torch_sconce, rot_y(math.radians(20.0))),
        "wall_torch": (wall_torch, rot_y(math.radians(20.0))),
        "workbench": (camp_bench, STATION_VIEW),
        "log_workbench": (log_workbench, STATION_VIEW),
        "woodworking_table": (woodworking_table, STATION_VIEW),
        "vice": (vice, rot_y(math.radians(-40.0))),
        "saw_mill": (saw_mill, rot_y(math.radians(-50.0))),
        "timber_prop": (timber_prop, STATION_VIEW),
        "timber_set": (timber_set, STATION_VIEW),
        "lean_to": (lean_to, rot_y(math.radians(-30.0))),
        "snare_trap": (snare_trap, STATION_VIEW),
        "tilled_bed": (tilled_bed, SLAB_VIEW),
        "path_patch": (path_patch, SLAB_VIEW),
        "carcass": (carcass, rot_y(math.radians(-20.0))),
        "remains": (remains, rot_y(math.radians(-20.0))),
        "driftwood": (driftwood, rot_y(math.radians(-120.0)) @ rot_z(math.radians(16.0))),
    }


PIECES = _pieces()
NAMES = tuple(PIECES)
# Too dark to read on the slot at 57 px (the 9 Nov style review, inventory/icons_style_review.md): brightened by lift_dark after the render.
LIFT = ("log_tropical_hardwood", "log_walnut", "log_oak", "vice", "tilled_bed")


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
        icon = render(build(), turn, colour_jitter=0.04, seed=len(name))
        (lift_dark(icon) if name in LIFT else icon).save(path)
        print("painted", path)


if __name__ == "__main__":
    main()
