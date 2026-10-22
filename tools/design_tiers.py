"""Draws the building-tier design sheets (art/BUILDING_TIERS_PLAN.md, art/BUILDING_TIERS_LOOKS.md): wall, floor and roof of the six tiers.

Run: python3 tools/design_tiers.py [out_dir]   (needs numpy and Pillow)
Writes tiers_walls.png, tiers_floors.png, tiers_roofs.png, tiers_plan.png (foundations and wall thickness to scale) and tiers_all.png.
Scale: 150 px per metre. A wall is 2 m by 2.4 m, a floor 2 m square, a roof 2.4 m square seen from above.
These are DESIGN pictures (what the in-game textures and shapes should read as), not engine renders.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

PPM = 150
WALL = (2 * PPM, int(2.4 * PPM))
FLOOR = (2 * PPM, 2 * PPM)
ROOF = (int(2.4 * PPM), int(2.4 * PPM))
NAMES = ["1 Basic", "2 Plank", "3 Fine wood", "4 Log", "5 Cobblestone", "6 Mason"]


def rng_for(n):
    return np.random.default_rng(1000 + n)


def noise(rng, w, h, blur):
    img = Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(img, dtype=np.float32)
    return (a - a.min()) / max(float(a.max() - a.min()), 1.0)


def tint(base, k):
    return tuple(int(max(0, min(255, c * k))) for c in base)


def canvas(size, color):
    return Image.new("RGB", size, color)


def apply_shade(img, shade):
    a = np.asarray(img, dtype=np.float32) * shade[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


# ---------------------------------------------------------------- walls
def wall_basic(rng):
    w, h = WALL
    img = canvas((w, h), (70, 52, 30))
    d = ImageDraw.Draw(img)
    stake = 22
    xs = list(range(14, w - 8, stake))

    for y in range(12, h - 30, 9):          # woven rods: over, under, over
        row = (y // 9) % 2

        for i in range(len(xs) - 1):
            x0, x1 = xs[i], xs[i + 1]
            over = (i + row) % 2 == 0
            col = tint((176, 134, 80), rng.uniform(0.85, 1.15))
            d.line([(x0 - 2, y + (2 if over else -2)), (x1 + 2, y + (-2 if over else 2))], fill=col, width=8)
            d.line([(x0, y - 3), (x1, y - 3)], fill=tint(col, 0.75), width=1)

    for x in xs:                             # stakes
        d.rectangle([x - 3, 0, x + 3, h], fill=tint((100, 70, 40), rng.uniform(0.85, 1.1)))

    for y in range(12, h - 30, 9):           # a rod passes behind a stake: the stake shows in front
        row = (y // 9) % 2

        for i, x in enumerate(xs):
            if (i + row) % 2 == 0:
                d.rectangle([x - 3, y - 4, x + 3, y + 4], fill=(122, 88, 52))

    for _ in range(900):                     # thatch stuffed along the top and loose straw
        x = int(rng.integers(0, w))
        y = int(rng.integers(0, 34)) if rng.random() < 0.75 else int(rng.integers(0, h - 20))
        ln = int(rng.integers(10, 32))
        d.line([(x, y), (x + int(rng.integers(-3, 4)), y + ln)], fill=tint((205, 176, 98), rng.uniform(0.7, 1.1)), width=1)

    for y in (60, h - 70):                   # twine lashing across the posts
        d.line([(0, y), (w, y + 6)], fill=(214, 196, 150), width=3)
        d.line([(0, y + 4), (w, y + 10)], fill=(150, 130, 90), width=1)

    d.rectangle([0, 0, 10, h], fill=(80, 56, 30))
    d.rectangle([w - 10, 0, w, h], fill=(80, 56, 30))
    return img


def wall_plank(rng):
    w, h = WALL
    img = canvas((w, h), (24, 18, 12))
    d = ImageDraw.Draw(img)
    x = 0

    while x < w:
        pw = int(rng.integers(26, 42))
        gap = int(rng.integers(1, 4))
        top = int(rng.integers(0, 8))
        bark = tint((104, 82, 62), rng.uniform(0.8, 1.1))
        left = [(x + int(rng.integers(-2, 3)), yy) for yy in range(top, h, 24)]
        right = [(x + pw - gap + int(rng.integers(-2, 3)), yy) for yy in range(h, top - 1, -24)]
        d.polygon([(x, top)] + left + [(x, h)] + right, fill=bark)

        for _ in range(7):                   # bark fissures
            fx = x + int(rng.integers(3, max(4, pw - 3)))
            fy = int(rng.integers(top, h - 60))
            d.line([(fx, fy), (fx + int(rng.integers(-2, 3)), fy + int(rng.integers(30, 90)))], fill=tint(bark, 0.5), width=1)

        d.line([(x + 1, top), (x + 1, h)], fill=tint(bark, 1.18), width=2)
        x += pw

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    d = ImageDraw.Draw(img)
    d.rectangle([w - 70, h - 90, w - 6, h - 6], fill=(230, 214, 168), outline=(30, 20, 12), width=2)   # inset: the smooth face inside
    inset = Image.new("RGB", (60, 80), (222, 196, 140))
    di = ImageDraw.Draw(inset)

    for ix in range(0, 60, 14):
        di.line([(ix, 0), (ix, 80)], fill=(150, 120, 80), width=1)

    img.paste(inset, (w - 67, h - 87))
    return img


def wall_fine(rng):
    w, h = WALL
    img = canvas((w, h), (190, 150, 100))
    d = ImageDraw.Draw(img)
    row = 18

    for y in range(0, h, row):
        base = tint((200, 160, 108), rng.uniform(0.93, 1.07))
        d.rectangle([0, y, w, y + row - 3], fill=base)
        d.line([(0, y + row - 3), (w, y + row - 3)], fill=tint(base, 0.78), width=1)
        d.line([(0, y + row - 2), (w, y + row - 1)], fill=tint(base, 0.55), width=2)    # the shadow under each lap

        for _ in range(4):                   # grain
            gy = y + int(rng.integers(2, row - 5))
            gx = int(rng.integers(0, w - 60))
            d.line([(gx, gy), (gx + int(rng.integers(30, 90)), gy)], fill=tint(base, 0.9), width=1)

        for nx in (22, w - 22):
            d.ellipse([nx - 1, y + 6, nx + 1, y + 8], fill=(60, 50, 44))                # nail heads

    d.rectangle([0, 0, 14, h], fill=(166, 124, 78))                                      # corner trim
    d.rectangle([w - 14, 0, w, h], fill=(166, 124, 78))
    d.line([(14, 0), (14, h)], fill=(100, 70, 44), width=2)
    d.line([(w - 14, 0), (w - 14, h)], fill=(100, 70, 44), width=2)
    d.rectangle([0, 0, w, 10], fill=(150, 110, 70))
    return img


def wall_log(rng):
    w, h = WALL
    img = canvas((w, h), (34, 26, 16))
    d = ImageDraw.Draw(img)
    dia = 45
    n = h // dia

    for i in range(n + 1):
        y = i * dia
        x0 = 4 if i % 2 == 0 else 20            # notched corners: every other log sticks out further
        x1 = w - x0
        bark = tint((132, 96, 58), rng.uniform(0.85, 1.1))
        d.rectangle([x0, y + 2, x1, y + dia - 2], fill=bark)

        for k in range(1, 6):                # cylinder shading
            f = 0.55 + 0.5 * np.sin(np.pi * k / 6.0)
            yy = y + 2 + k * (dia - 4) // 6
            d.line([(x0, yy), (x1, yy)], fill=tint(bark, f), width=(dia - 4) // 6 + 1)

        for _ in range(12):                  # bark ridges
            rx = int(rng.integers(x0, x1 - 40))
            ry = y + int(rng.integers(6, dia - 6))
            d.line([(rx, ry), (rx + int(rng.integers(20, 70)), ry)], fill=tint(bark, 0.55), width=1)

        d.line([(x0, y + 1), (x1, y + 1)], fill=(184, 176, 128), width=2)               # chinking: moss and clay between the logs
        d.ellipse([x0 - 6, y + 5, x0 + 8, y + dia - 5], fill=(212, 180, 126), outline=(120, 84, 48))   # cut ends at the corners
        d.ellipse([x1 - 8, y + 5, x1 + 6, y + dia - 5], fill=(212, 180, 126), outline=(120, 84, 48))

    return img


def voronoi(rng, w, h, cells):
    """d1, d2 and a cell id per pixel for jittered points (cells[0] x cells[1] grid over the picture)."""
    cw, ch = w / cells[0], h / cells[1]
    pts = []

    for j in range(cells[1] + 2):
        for i in range(cells[0] + 2):
            pts.append(((i - 0.5) * cw + rng.uniform(0.1, 0.9) * cw, (j - 0.5) * ch + rng.uniform(0.1, 0.9) * ch))

    pts = np.array(pts)
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.sqrt((xx[..., None] - pts[:, 0]) ** 2 + (yy[..., None] - pts[:, 1]) ** 2)
    order = np.sort(dist, axis=2)
    return order[..., 0], order[..., 1], np.argmin(dist, axis=2)


def wall_cobble(rng):
    w, h = WALL
    d1, d2, cid = voronoi(rng, w, h, (7, 9))
    edge = d2 - d1
    tints = rng.uniform(0.7, 1.15, cid.max() + 1)
    warm = rng.uniform(-14, 14, cid.max() + 1)
    stone = np.clip(1.0 - np.exp(-edge / 7.0), 0, 1)                    # 0 at the joint, 1 in the stone
    shade = 0.62 + 0.5 * stone ** 0.8
    a = np.zeros((h, w, 3), dtype=np.float32)
    base = np.array([138, 132, 122], dtype=np.float32)

    for c in range(3):
        a[..., c] = (base[c] + warm[cid] * (1 if c == 0 else -0.4 if c == 2 else 0.2)) * tints[cid] * shade

    mortar = np.array([176, 166, 140], dtype=np.float32)
    m = (edge < 5.0)[..., None]
    a = np.where(m, mortar * (0.82 + 0.25 * noise(rng, w, h, 2)[..., None]), a)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def wall_mason(rng):
    w, h = WALL
    img = canvas((w, h), (110, 106, 98))
    d = ImageDraw.Draw(img)
    bw, bh = 120, 60
    stains = noise(rng, w, h, 14)

    for r in range(0, h // bh + 1):
        off = 0 if r % 2 == 0 else bw // 2

        for x in range(-bw, w + bw, bw):
            x0, y0 = x + off, r * bh
            face = tint((184, 178, 164), rng.uniform(0.92, 1.08))
            d.rectangle([x0 + 2, y0 + 2, x0 + bw - 2, y0 + bh - 2], fill=face)
            d.rectangle([x0 + 8, y0 + 8, x0 + bw - 8, y0 + bh - 8], fill=tint(face, 1.04))              # smooth dressed centre
            d.line([(x0 + 2, y0 + 2), (x0 + bw - 2, y0 + 2)], fill=tint(face, 1.2), width=3)            # chisel-draft margin: light above and left
            d.line([(x0 + 2, y0 + 2), (x0 + 2, y0 + bh - 2)], fill=tint(face, 1.15), width=3)
            d.line([(x0 + 2, y0 + bh - 2), (x0 + bw - 2, y0 + bh - 2)], fill=tint(face, 0.72), width=3)  # dark below and right
            d.line([(x0 + bw - 2, y0 + 2), (x0 + bw - 2, y0 + bh - 2)], fill=tint(face, 0.78), width=3)

    img = apply_shade(img, 0.9 + 0.2 * stains)
    d = ImageDraw.Draw(img)
    d.rectangle([0, h - 18, w, h], fill=(138, 132, 120))                # projecting plinth course
    d.line([(0, h - 18), (w, h - 18)], fill=(220, 214, 200), width=2)
    d.rectangle([0, 0, w, 10], fill=(150, 144, 132))
    d.line([(0, 10), (w, 10)], fill=(90, 86, 78), width=2)
    return img


# ---------------------------------------------------------------- floors
def floor_basic(rng):
    w, h = FLOOR
    img = apply_shade(canvas((w, h), (112, 84, 54)), 0.8 + 0.4 * noise(rng, w, h, 3))
    d = ImageDraw.Draw(img)

    for _ in range(300):                     # straw trodden in
        x, y = int(rng.integers(0, w)), int(rng.integers(0, h))
        d.line([(x, y), (x + int(rng.integers(-12, 13)), y + int(rng.integers(-12, 13)))], fill=tint((196, 168, 96), rng.uniform(0.7, 1.0)), width=1)

    d.rectangle([60, 70, w - 60, h - 50], fill=(190, 160, 96))          # the woven mat
    step = 8

    for i, x in enumerate(range(60, w - 60, step)):
        for j, y in enumerate(range(70, h - 50, step)):
            if (i + j) % 2 == 0:
                d.rectangle([x, y, x + step - 1, y + step - 1], fill=(168, 138, 78))

    d.rectangle([60, 70, w - 60, h - 50], outline=(120, 90, 50), width=3)
    return img


def floor_plank(rng):
    w, h = FLOOR
    img = canvas((w, h), (30, 22, 14))
    d = ImageDraw.Draw(img)
    x = 0

    while x < w:
        pw = int(rng.integers(30, 52))
        col = tint((150, 114, 70), rng.uniform(0.8, 1.1))
        d.rectangle([x, 0, x + pw - 3, h], fill=col)

        for _ in range(9):
            gx = x + int(rng.integers(3, pw - 5))
            gy = int(rng.integers(0, h - 80))
            d.line([(gx, gy), (gx, gy + int(rng.integers(30, 110)))], fill=tint(col, 0.78), width=1)

        for ay in (90, 210):                 # one peg per joist
            d.ellipse([x + pw // 2 - 3, ay - 3, x + pw // 2 + 3, ay + 3], fill=tint(col, 0.6))

        x += pw

    return img


def floor_fine(rng):
    w, h = FLOOR
    img = canvas((w, h), (160, 120, 78))
    d = ImageDraw.Draw(img)
    bw = 22

    for x in range(0, w, bw):
        col = tint((206, 166, 112), rng.uniform(0.93, 1.07))
        d.rectangle([x, 0, x + bw - 2, h], fill=col)
        d.line([(x + bw - 1, 0), (x + bw - 1, h)], fill=(90, 62, 36), width=1)

        for _ in range(3):
            gx = x + int(rng.integers(3, bw - 4))
            gy = int(rng.integers(0, h - 100))
            d.line([(gx, gy), (gx, gy + int(rng.integers(40, 120)))], fill=tint(col, 0.88), width=1)

        for ny in (75, 225):
            d.ellipse([x + 4, ny - 1, x + 6, ny + 1], fill=(64, 52, 46))
            d.ellipse([x + bw - 8, ny - 1, x + bw - 6, ny + 1], fill=(64, 52, 46))

    return img


def floor_log(rng):
    w, h = FLOOR
    img = canvas((w, h), (32, 24, 14))
    d = ImageDraw.Draw(img)
    x = 0

    while x < w:
        pw = int(rng.integers(30, 44))
        col = tint((176, 136, 88), rng.uniform(0.85, 1.1))
        d.rectangle([x + 4, 0, x + pw - 5, h], fill=col)                # the adzed flat face
        d.rectangle([x, 0, x + 4, h], fill=(86, 62, 38))                 # the rounded bark edges either side
        d.rectangle([x + pw - 5, 0, x + pw, h], fill=(86, 62, 38))

        for _ in range(14):                  # adze scoops
            gy = int(rng.integers(0, h))
            d.arc([x + 6, gy, x + pw - 6, gy + 12], 20, 160, fill=tint(col, 0.8), width=1)

        x += pw

    return img


def floor_flag(rng):
    w, h = FLOOR
    d1, d2, cid = voronoi(rng, w, h, (4, 4))
    edge = d2 - d1
    tints = rng.uniform(0.82, 1.1, cid.max() + 1)
    warm = rng.uniform(-8, 8, cid.max() + 1)
    base = np.array([128, 124, 116], dtype=np.float32)
    a = np.zeros((h, w, 3), dtype=np.float32)
    n = noise(rng, w, h, 1.5)

    for c in range(3):
        a[..., c] = (base[c] + warm[cid] * (1 if c == 0 else -0.5 if c == 2 else 0.1)) * tints[cid] * (0.9 + 0.2 * n)

    m = (edge < 4.0)[..., None]
    a = np.where(m, np.array([76, 70, 62], dtype=np.float32), a)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def floor_block(rng):
    w, h = FLOOR
    img = canvas((w, h), (110, 106, 98))
    d = ImageDraw.Draw(img)
    s = 75

    for j in range(0, h, s):
        for i in range(0, w, s):
            k = rng.uniform(0.94, 1.06) * (1.0 if (i // s + j // s) % 2 == 0 else 0.96)
            col = tint((190, 184, 170), k)
            d.rectangle([i + 1, j + 1, i + s - 1, j + s - 1], fill=col)
            d.line([(i + 1, j + 1), (i + s - 1, j + 1)], fill=tint(col, 1.15), width=2)
            d.line([(i + 1, j + s - 1), (i + s - 1, j + s - 1)], fill=tint(col, 0.8), width=2)

    return img


# ---------------------------------------------------------------- roofs (seen from above; eave at the bottom)
def roof_thatch(rng):
    w, h = ROOF
    img = canvas((w, h), (150, 124, 70))
    d = ImageDraw.Draw(img)

    for _ in range(5200):
        x = int(rng.integers(0, w))
        y = int(rng.integers(0, h))
        d.line([(x, y), (x + int(rng.integers(-2, 3)), y + int(rng.integers(14, 40)))], fill=tint((214, 184, 108), rng.uniform(0.55, 1.05)), width=1)

    for y in range(40, h, 52):               # bound courses
        d.line([(0, y), (w, y + 3)], fill=(110, 84, 44), width=3)

    d.rectangle([0, h - 22, w, h], fill=(130, 104, 56))                  # the thick eave edge
    return img


def shingle_rows(rng, w, h, row, colors, nails=False, ragged=0):
    img = canvas((w, h), (30, 22, 14))
    d = ImageDraw.Draw(img)

    for y in range(0, h, row):
        x = -int(rng.integers(0, 30))

        while x < w:
            sw = int(rng.integers(24, 40)) if ragged else 38
            col = tint(colors[int(rng.integers(0, len(colors)))], rng.uniform(0.88, 1.1))
            d.rectangle([x, y, x + sw - 2, y + row + 6 + int(rng.integers(0, ragged + 1))], fill=col)
            d.line([(x, y + row + 4), (x + sw - 2, y + row + 4)], fill=tint(col, 0.55), width=2)

            for _ in range(2):
                gx = x + int(rng.integers(2, sw - 3))
                d.line([(gx, y + 2), (gx, y + row)], fill=tint(col, 0.82), width=1)

            if nails:
                d.ellipse([x + 5, y + 4, x + 7, y + 6], fill=(60, 50, 44))
                d.ellipse([x + sw - 9, y + 4, x + sw - 7, y + 6], fill=(60, 50, 44))

            x += sw

    return img


def roof_plank(rng):
    return shingle_rows(rng, ROOF[0], ROOF[1], 32, [(140, 110, 72), (118, 92, 62), (150, 120, 80)], ragged=6)


def roof_fine(rng):
    return shingle_rows(rng, ROOF[0], ROOF[1], 26, [(196, 154, 102)], nails=True)


def roof_log(rng):
    w, h = ROOF
    img = canvas((w, h), (62, 48, 30))
    d = ImageDraw.Draw(img)

    for y in range(0, h, 70):                # big bark sheets, overlapping like shingles
        x = -int(rng.integers(0, 40))

        while x < w:
            sw = int(rng.integers(70, 110))
            col = tint((92, 70, 48), rng.uniform(0.8, 1.1))
            d.rectangle([x, y, x + sw - 3, y + 80], fill=col)
            d.line([(x, y + 78), (x + sw - 3, y + 78)], fill=tint(col, 0.5), width=3)

            for _ in range(8):
                fx = x + int(rng.integers(4, sw - 6))
                fy = y + int(rng.integers(2, 40))
                d.line([(fx, fy), (fx + int(rng.integers(-2, 3)), fy + int(rng.integers(14, 38)))], fill=tint(col, 0.55), width=1)

            x += sw

    for x in range(30, w, 90):               # round log rafters on top
        d.rectangle([x - 9, 0, x + 9, h], fill=(110, 78, 46))
        d.line([(x - 5, 0), (x - 5, h)], fill=(150, 112, 70), width=2)
        d.line([(x + 6, 0), (x + 6, h)], fill=(70, 50, 30), width=2)

    d.rectangle([0, 0, w, 14], fill=(104, 74, 44))                       # ridge log
    return img


def roof_slab(rng):
    w, h = ROOF
    img = canvas((w, h), (50, 50, 52))
    d = ImageDraw.Draw(img)
    y = 0

    while y < h:
        rh = int(rng.integers(34, 46))
        x = -int(rng.integers(0, 50))

        while x < w:
            sw = int(rng.integers(60, 100))
            col = tint((112, 114, 120), rng.uniform(0.82, 1.12))
            d.polygon([(x, y), (x + sw, y + int(rng.integers(-2, 3))), (x + sw - 2, y + rh + 8), (x + int(rng.integers(0, 4)), y + rh + 8)], fill=col)
            d.line([(x, y + rh + 7), (x + sw - 2, y + rh + 7)], fill=tint(col, 0.5), width=2)
            x += sw

        y += rh

    for x in range(40, w, 120):              # beam ends along the eave
        d.rectangle([x - 8, h - 14, x + 8, h], fill=(96, 70, 44))

    return img


def roof_stone(rng):
    w, h = ROOF
    img = canvas((w, h), (62, 62, 66))
    d = ImageDraw.Draw(img)
    rows = 5
    rh = h // rows

    for r in range(rows):
        off = 0 if r % 2 == 0 else 45

        for x in range(-90, w + 90, 90):
            col = tint((150, 152, 156), rng.uniform(0.94, 1.06))
            d.rectangle([x + off + 1, r * rh + 1, x + off + 88, r * rh + rh - 1], fill=col)
            d.line([(x + off + 1, r * rh + 1), (x + off + 88, r * rh + 1)], fill=tint(col, 1.18), width=2)
            d.line([(x + off + 1, r * rh + rh - 2), (x + off + 88, r * rh + rh - 2)], fill=tint(col, 0.6), width=3)

    d.rectangle([0, 0, w, 16], fill=(120, 122, 128))                       # carved ridge cap
    d.line([(0, 16), (w, 16)], fill=(60, 60, 64), width=2)
    return img


# ---------------------------------------------------------------- sheets
def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)

    return ImageFont.load_default()


def sheet(title, makers, size, out, notes):
    gap = 24
    head = 72
    foot = 52
    w = len(makers) * size[0] + (len(makers) + 1) * gap
    h = head + size[1] + foot + gap
    img = canvas((w, h), (34, 34, 38))
    d = ImageDraw.Draw(img)
    d.text((gap, 10), title, fill=(240, 240, 240), font=font(22))

    for i, make in enumerate(makers):
        x = gap + i * (size[0] + gap)
        img.paste(make(rng_for(i + len(title))), (x, head))
        d.rectangle([x - 1, head - 1, x + size[0], head + size[1]], outline=(15, 15, 15))
        d.text((x, head - 24), NAMES[i], fill=(250, 220, 140), font=font(15))
        d.text((x, head + size[1] + 6), notes[i], fill=(200, 200, 200), font=font(12))

    img.save(out)


def plan(out):
    """Foundation footprints (4, 6, 8 m) on the 2 m grid, with a wall-thickness strip for each tier, all to the same scale."""
    scale = 40
    grids = [(4, "standard 4 x 4 m: tiers 2 and 3"), (6, "LARGE 6 x 6 m: tiers 4 and 5"), (8, "MASON 8 x 8 m: tier 6")]
    thick = [0.10, 0.10, 0.15, 0.40, 0.50, 0.60]
    img = canvas((1260, 8 * scale + 330), (34, 34, 38))
    d = ImageDraw.Draw(img)
    d.text((24, 10), "Foundation footprints and wall thickness, to scale (40 px = 1 m, grid lines every 2 m)", fill=(240, 240, 240), font=font(18))
    x = 40

    for size, label in grids:
        d.rectangle([x, 60, x + size * scale, 60 + size * scale], fill=(120, 116, 108), outline=(230, 230, 230))

        for g in range(0, size + 1, 2):
            d.line([(x + g * scale, 60), (x + g * scale, 60 + size * scale)], fill=(80, 78, 72))
            d.line([(x, 60 + g * scale), (x + size * scale, 60 + g * scale)], fill=(80, 78, 72))

        d.text((x, 60 + size * scale + 8), label, fill=(250, 220, 140), font=font(12))
        x += size * scale + 60

    y0 = 60 + 8 * scale + 70
    d.text((24, y0 - 34), "Wall thickness on a grid line (2 m wall piece, top view, thickness drawn 4 times too thick)", fill=(240, 240, 240), font=font(15))

    for i, t in enumerate(thick):
        x0 = 40 + i * 200
        d.rectangle([x0, y0 + 40 - t * scale * 2, x0 + 2 * scale * 2, y0 + 40 + t * scale * 2], fill=(190, 170, 130), outline=(240, 240, 240))
        d.text((x0, y0 + 90), "%s  %.2f m" % (NAMES[i], t), fill=(250, 220, 140), font=font(12))

    img.save(out)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    sheet("WALLS: 2 m wide, 2.4 m high (seen from outside)", [wall_basic, wall_plank, wall_fine, wall_log, wall_cobble, wall_mason], WALL, os.path.join(out, "tiers_walls.png"),
          ["woven rods, stakes, straw on top", "bark face out (inset: smooth face in)", "lapped boards, nails, trim", "stacked logs, notched ends", "round stones, thick mortar", "large carved blocks, plinth"])
    sheet("FLOORS: 2 m square (seen from above)", [floor_basic, floor_plank, floor_fine, floor_log, floor_flag, floor_block], FLOOR, os.path.join(out, "tiers_floors.png"),
          ["beaten earth, straw, woven mat", "rough planks, gaps, pegs", "planed boards, nail pairs", "split logs, flat side up", "flagstone, narrow joints", "cut stone blocks, tight joints"])
    sheet("ROOFS: 2.4 m square (seen from above, eave at the bottom)", [roof_thatch, roof_plank, roof_fine, roof_log, roof_slab, roof_stone], ROOF, os.path.join(out, "tiers_roofs.png"),
          ["thatch, bound courses, thick eave", "riven plank shingles, ragged", "sawn shingles, nailed", "bark sheets over log rafters", "stone slabs on beams", "dressed slabs, carved ridge"])
    plan(os.path.join(out, "tiers_plan.png"))
    parts = [Image.open(os.path.join(out, n)) for n in ("tiers_walls.png", "tiers_floors.png", "tiers_roofs.png")]
    allimg = canvas((max(p.width for p in parts), sum(p.height for p in parts)), (34, 34, 38))
    y = 0

    for p in parts:
        allimg.paste(p, (0, y))
        y += p.height

    allimg.save(os.path.join(out, "tiers_all.png"))
    print("wrote", out)


if __name__ == "__main__":
    main()
