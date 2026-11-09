#!/usr/bin/env python3
"""Paint the icons the bake has no model for: building sections, logs by species, furniture, beds and storage (inventory redesign step 5; Kathleen, 9 Nov 2026).

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
from paint_basic_icons import FILL, KEY, KEY_COLOUR, SIZE, SS, VIEW, prism, rot_x, rot_y, rot_z   # noqa: E402  (the shared rig)
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
        base = np.array(colour, dtype=float) / 255.0 * (1.0 + rng.uniform(-colour_jitter, colour_jitter))
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
    return tuple(int(max(0, min(255, c * k))) for c in colour)


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
    faces = []

    for side in (1, -1):
        turn, shift = _slope(side)

        for i in range(6):            # logs laid down the slope, side by side along the ridge
            log = moved(prism(0.16, RL + 0.25, 8, BARK, LOG_END, ring=LOG_RING, seed=80 + i + (6 if side < 0 else 0)), rot_y(math.pi / 2))
            faces += moved(log, turn, shift + turn @ np.array([-RW / 2 + 0.17 + i * 0.33, 0.16, 0.1]))

    return faces


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
    faces = []

    for side in (-1, 1):
        faces += moved(prism(0.05, 2.4, 6, BARK, LOG_END, seed=90 + side), rot_z(math.radians(90.0)), shift=(side * 0.32, 0.0, 0.0))

    for i in range(6):
        faces += moved(prism(0.035, 0.72, 6, PLANK, LOG_END, seed=95 + i), shift=(0.0, -0.95 + i * 0.38, 0.0))

    return faces


LADDER_VIEW = rot_y(math.radians(25.0)) @ rot_z(math.radians(-14.0))


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
        "roof_section": (plank_roof, ROOF_VIEW),
        "log_roof": (log_roof, ROOF_VIEW),
        "stone_roof": (stone_roof, ROOF_VIEW),
        "brick_roof": (brick_roof, ROOF_VIEW),
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
        "driftwood": (driftwood, rot_y(math.radians(-120.0)) @ rot_z(math.radians(16.0))),
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
