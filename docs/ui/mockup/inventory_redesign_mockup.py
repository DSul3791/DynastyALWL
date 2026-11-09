#!/usr/bin/env python3
# Inventory and crafting redesign mockup, version 3 (docs/ui/inventory_crafting_redesign.md; Kathleen, 9 Nov 2026).
# Draws the measured layout on the 1920 x 1080 design canvas (Dave, 9 Nov 2026) from the numbers below and nothing else, so the
# picture and the doc cannot drift apart. Every coordinate is a 1920 x 1080 canvas px; the picture is drawn at twice that and
# scaled down, so edges are smooth.
#
#   python3 docs/ui/mockup/inventory_redesign_mockup.py --out DIR [--icons item_icon_sheet.png] [--measured]
#
# Writes DIR/inventory_redesign_1920_v3.png (pack, you, craft by hand). --measured also writes a copy with every box outlined.
# --icons: the icon bake sheet (tools/icon_bake.gd --sheet; NEEDS_PAINTING.txt beside it); its icons stand in for the painted ones.

import argparse
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FONTS = os.path.join(ROOT, "assets", "ui", "fonts")
W, H = 1920, 1080
S = 2                    # drawn at 2x, scaled down at the end
RNG = random.Random(7)

# ---- colours (doc section 6.2) ----
BACKDROP = (23, 21, 15)          # #17150F, the darkest level, with a vignette and leather grain
FIELD = (35, 26, 18)             # #231A12, panel field, one step lighter, faint parchment texture
RAISED = (48, 36, 25)            # #302419, buttons, cards, tabs: one step lighter again
RAISED_LIT = (64, 47, 31)        # #402F1F, hover and the selected row
RAISED_EDGE = (82, 62, 41)       # #523E29, 1 px top highlight on raised things
WELL = (18, 12, 8)               # #120C08, recessed slot well
WELL_LIP = (70, 54, 38)          # #463626, the light line at the bottom of a well
LEATHER = (58, 35, 21)           # #3A2315, the frame edge
LEATHER_DARK = (22, 12, 6)       # #160C06
STITCH = (184, 154, 104)         # #B89A68
BRASS_HI = (240, 207, 130)       # #F0CF82
BRASS = (201, 160, 84)           # #C9A054
BRASS_LO = (122, 88, 38)         # #7A5826
BRASS_DARK = (74, 52, 22)        # #4A3416
GOLD_LINE = (140, 105, 51)       # #8C6933
GOLD_BRIGHT = (255, 214, 122)    # #FFD67A
CREAM = (245, 230, 189)          # #F5E6BD body text
HEADING = (242, 199, 107)        # #F2C76B titles, names, keys
DIM = (138, 126, 104)            # #8A7E68 secondary text ("needs Forge")
DISABLED = (106, 96, 80)         # #6A6050
BAD = (191, 46, 36)              # #BF2E24 shortfalls only
INK = (43, 27, 11)               # #2B1B0B text engraved into brass
ENGRAVE = (201, 168, 105)        # #C9A869 engraved glyphs
GHOST = (74, 60, 46)             # #4A3C2E empty gear silhouettes
OUTLINE = (10, 6, 4)             # #0A0604 outline on every number
STAT_FILL = {"Health": (168, 69, 47), "Exertion": (192, 143, 62), "Energy": (156, 123, 82),
             "Temperature": (200, 111, 53), "Food": (168, 138, 68), "Water": (111, 138, 134)}
WEAR_GOOD = (143, 163, 90)       # #8FA35A

# ---- type (doc section 6.3; nothing under 18) ----
T_PANEL = ("Cinzel-Bold.ttf", 34)       # panel titles, letter-spaced, engraved on the brass plate
T_NAME = ("Cinzel-Bold.ttf", 30)        # item names
T_HEAD = ("Cinzel-Regular.ttf", 22)     # section heads (Cinzel's lower case is small caps)
T_BUTTON = ("Cinzel-Bold.ttf", 26)
T_KEY = ("Cinzel-Bold.ttf", 18)
T_BODY = ("EBGaramond-Regular.ttf", 18)
T_BODY_SB = ("EBGaramond-SemiBold.ttf", 18)
T_COUNT = ("EBGaramond-SemiBold.ttf", 24)

# ---- layout (canvas px; doc section 4) ----
MARGIN, GUTTER, FRAME, AIR = 24, 22, 14, 6
SLOT, SLOT_GAP = 100, 10
HOT, HOT_GAP = 60, 5
PACK = (24, 24, 714, 1056)
YOU = (736, 24, 1184, 1056)
CRAFT = (1206, 24, 1896, 1056)

L = {
    "pack.plate": (72, 30, 0, 76),          # width follows the title
    "pack.search": (414, 48, 646, 84),
    "pack.sort": (656, 48, 694, 84),
    "pack.weight": (44, 98, 694, 122),
    "pack.hotbar": (47, 136, 692, 196),
    "pack.grid": (44, 214, 694, 754),
    "pack.info": (44, 784, 694, 1036),
    "pack.keys": (44, 1000, 694, 1032),
    "you.plate": (960, 30, 0, 76),          # centred
    "you.gear_left": (756, 96, 852, 630),
    "you.figure": (862, 86, 1058, 636),
    "you.gear_right": (1068, 96, 1164, 630),
    "you.stats": (756, 690, 1164, 1002),
    "craft.plate": (1254, 30, 0, 76),
    "craft.tabs": (1226, 100, 1274, 688),
    "craft.search": (1282, 100, 1478, 136),
    "craft.list": (1282, 146, 1478, 1036),
    "craft.card": (1490, 100, 1876, 1036),
    "craft.icon": (1504, 114, 1616, 226),
    "craft.name": (1630, 118, 1864, 226),
    "craft.desc": (1504, 244, 1864, 292),
    "craft.stats": (1504, 306, 1864, 410),
    "craft.needs": (1504, 430, 1864, 600),
    "craft.qty": (1504, 618, 1864, 662),
    "craft.short": (1504, 676, 1864, 700),
    "craft.made_at": (1504, 716, 1864, 776),
    "craft.used_in": (1504, 790, 1864, 850),
    "craft.queue": (1504, 876, 1864, 932),
    "craft.button": (1504, 958, 1864, 1022),
}


# ======================================================================================================== drawing helpers
def sc(v):
    return int(round(v * S))


def sbox(box):
    return tuple(sc(v) for v in box)


def font(spec):
    return ImageFont.truetype(os.path.join(FONTS, spec[0]), spec[1] * S)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (W * S, H * S), rgba(BACKDROP))

    @property
    def d(self):
        return ImageDraw.Draw(self.img)

    def layer(self, draw_fn, blur=0):
        lay = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        draw_fn(ImageDraw.Draw(lay))
        if blur:
            lay = lay.filter(ImageFilter.GaussianBlur(blur * S))
        self.img.alpha_composite(lay)

    def rect(self, box, r=0, fill=None, outline=None, width=1):
        self.d.rounded_rectangle(sbox(box), sc(r), fill=fill, outline=outline, width=max(1, sc(width)) if outline else 0)

    def line(self, pts, fill, width=1):
        self.d.line([(sc(x), sc(y)) for x, y in pts], fill=fill, width=max(1, sc(width)))

    def text(self, xy, s, spec, fill=CREAM, anchor="la", stroke=0, track=0.0):
        f = font(spec)
        if track <= 0:
            self.d.text((sc(xy[0]), sc(xy[1])), s, font=f, fill=fill, anchor=anchor, stroke_width=sc(stroke), stroke_fill=OUTLINE)
            return
        # letter-spaced: lay the letters out by hand
        widths = [f.getlength(ch) for ch in s]
        total = sum(widths) + sc(track) * (len(s) - 1)
        x = sc(xy[0]) - (total / 2 if anchor[0] == "m" else (total if anchor[0] == "r" else 0))
        for ch, w in zip(s, widths):
            self.d.text((x, sc(xy[1])), ch, font=f, fill=fill, anchor="l" + anchor[1], stroke_width=sc(stroke), stroke_fill=OUTLINE)
            x += w + sc(track)

    def text_width(self, s, spec, track=0.0):
        f = font(spec)
        return (sum(f.getlength(ch) for ch in s) + sc(track) * (len(s) - 1)) / S

    def paste(self, im, xy):
        self.img.alpha_composite(im, (sc(xy[0]), sc(xy[1])))


def noise(w, h, scale, amp, seed):
    rs = np.random.RandomState(seed)
    small = rs.rand(max(2, h // scale), max(2, w // scale)).astype(np.float32)
    big = np.array(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0
    return (big - 0.5) * 2.0 * amp


def texture(w, h, base, grain, fibres, seed):
    # base colour + soft blotches + fine grain (+ faint horizontal fibres for the parchment field)
    n = noise(w, h, 90 * S, grain * 0.8, seed) + noise(w, h, 3, grain * 0.5, seed + 1)
    if fibres:
        streak = np.random.RandomState(seed + 3).rand(h, 1).astype(np.float32)
        streak = np.array(Image.fromarray((streak * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), dtype=np.float32) / 255.0
        n += (streak - 0.5) * fibres
    arr = np.clip(np.array(base, dtype=np.float32)[None, None, :] + n[:, :, None], 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def gradient(w, h, top, bottom, diagonal=False):
    if diagonal:
        t = (np.linspace(0, 1, w)[None, :] * 0.5 + np.linspace(0, 1, h)[:, None] * 0.5)
    else:
        t = np.repeat(np.linspace(0, 1, h)[:, None], w, axis=1)
    a = np.array(top, dtype=np.float32)
    b = np.array(bottom, dtype=np.float32)
    arr = a[None, None, :] * (1 - t[:, :, None]) + b[None, None, :] * t[:, :, None]
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


def round_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    return m


def fill_textured(cv, box, tex_img, r):
    x0, y0, x1, y1 = sbox(box)
    tex = tex_img.resize((x1 - x0, y1 - y0)) if tex_img.size != (x1 - x0, y1 - y0) else tex_img
    cv.img.paste(tex, (x0, y0), round_mask(x1 - x0, y1 - y0, sc(r)))


# ======================================================================================================== glyphs
# Engraved line glyphs (doc art brief rows 7, 15, 17, 19), drawn on a 0..1 square at 4x the final size, then scaled.
def glyph(name, px, colour, shadow=True):
    n = px * S * 4
    m = Image.new("L", (n, n), 0)
    g = ImageDraw.Draw(m)

    def P(*pts):
        return [(x * n, y * n) for x, y in pts]

    def ln(pts, w=0.07):
        g.line(P(*pts), fill=255, width=int(w * n), joint="curve")

    def poly(pts):
        g.polygon(P(*pts), fill=255)

    def ell(x0, y0, x1, y1, w=None):
        if w is None:
            g.ellipse((x0 * n, y0 * n, x1 * n, y1 * n), fill=255)
        else:
            g.ellipse((x0 * n, y0 * n, x1 * n, y1 * n), outline=255, width=int(w * n))

    def rr(x0, y0, x1, y1, r=0.05):
        g.rounded_rectangle((x0 * n, y0 * n, x1 * n, y1 * n), int(r * n), fill=255)

    if name == "heart":
        ell(0.12, 0.2, 0.52, 0.58)
        ell(0.48, 0.2, 0.88, 0.58)
        poly([(0.14, 0.46), (0.86, 0.46), (0.5, 0.88)])
    elif name == "bolt":
        poly([(0.58, 0.06), (0.22, 0.54), (0.46, 0.54), (0.38, 0.94), (0.78, 0.4), (0.53, 0.4)])
    elif name == "moon":
        ell(0.14, 0.12, 0.86, 0.84)
        g.ellipse((0.36 * n, 0.04 * n, 1.02 * n, 0.7 * n), fill=0)
    elif name == "flame":
        poly([(0.5, 0.04), (0.74, 0.36), (0.82, 0.62), (0.7, 0.86), (0.5, 0.94), (0.3, 0.86), (0.18, 0.62), (0.3, 0.42), (0.38, 0.56), (0.42, 0.3)])
        g.polygon(P((0.5, 0.52), (0.62, 0.7), (0.58, 0.84), (0.5, 0.88), (0.42, 0.84), (0.4, 0.7)), fill=0)
    elif name == "bread":
        g.chord((0.08 * n, 0.26 * n, 0.92 * n, 1.0 * n), 180, 360, fill=255)
        rr(0.08, 0.6, 0.92, 0.78, 0.04)
        for x in (0.32, 0.5, 0.68):
            g.line(P((x - 0.06, 0.42), (x + 0.04, 0.56)), fill=0, width=int(0.05 * n))
    elif name == "drop":
        poly([(0.5, 0.06), (0.76, 0.5), (0.24, 0.5)])
        ell(0.22, 0.34, 0.78, 0.92)
    elif name == "helmet":
        g.chord((0.16 * n, 0.14 * n, 0.84 * n, 0.86 * n), 180, 360, fill=255)
        rr(0.12, 0.48, 0.88, 0.58, 0.02)
        rr(0.46, 0.5, 0.54, 0.8, 0.02)
    elif name == "tunic":
        poly([(0.3, 0.1), (0.42, 0.1), (0.5, 0.2), (0.58, 0.1), (0.7, 0.1), (0.94, 0.32), (0.84, 0.46), (0.74, 0.38), (0.74, 0.92), (0.26, 0.92), (0.26, 0.38), (0.16, 0.46), (0.06, 0.32)])
    elif name == "trousers":
        poly([(0.24, 0.08), (0.76, 0.08), (0.84, 0.92), (0.58, 0.92), (0.5, 0.38), (0.42, 0.92), (0.16, 0.92)])
    elif name == "boot":
        poly([(0.28, 0.06), (0.58, 0.06), (0.58, 0.56), (0.86, 0.66), (0.9, 0.88), (0.2, 0.88), (0.24, 0.56)])
    elif name == "glove":
        rr(0.26, 0.42, 0.74, 0.92, 0.1)
        for i, x in enumerate((0.27, 0.39, 0.51, 0.63)):
            rr(x, 0.12 + (0.06 if i in (0, 3) else 0), x + 0.1, 0.5, 0.05)
        poly([(0.26, 0.6), (0.1, 0.42), (0.16, 0.36), (0.3, 0.5)])
    elif name == "pack":
        rr(0.2, 0.2, 0.8, 0.92, 0.14)
        g.arc((0.34 * n, 0.04 * n, 0.66 * n, 0.36 * n), 180, 360, fill=255, width=int(0.07 * n))
        g.rounded_rectangle((0.3 * n, 0.5 * n, 0.7 * n, 0.74 * n), int(0.04 * n), fill=0)
    elif name in ("axe", "hand_axe"):
        ln([(0.2, 0.88), (0.72, 0.18)], 0.08)
        poly([(0.58, 0.08), (0.9, 0.3), (0.82, 0.46), (0.62, 0.34)])
    elif name == "shield":
        poly([(0.16, 0.12), (0.84, 0.12), (0.84, 0.46), (0.5, 0.92), (0.16, 0.46)])
        g.polygon(P((0.46, 0.2), (0.54, 0.2), (0.54, 0.76), (0.46, 0.76)), fill=0)
    elif name == "all":
        for x, y in ((0.12, 0.12), (0.54, 0.12), (0.12, 0.54), (0.54, 0.54)):
            rr(x, y, x + 0.34, y + 0.34, 0.06)
    elif name == "spear":
        ln([(0.14, 0.86), (0.7, 0.3)], 0.06)
        poly([(0.62, 0.3), (0.9, 0.1), (0.7, 0.38)])
    elif name == "house":
        poly([(0.08, 0.48), (0.5, 0.1), (0.92, 0.48)])
        rr(0.18, 0.46, 0.82, 0.9, 0.02)
        g.rectangle((0.42 * n, 0.62 * n, 0.58 * n, 0.9 * n), fill=0)
    elif name == "anvil":
        poly([(0.06, 0.26), (0.84, 0.26), (0.94, 0.36), (0.72, 0.46), (0.62, 0.62), (0.76, 0.86), (0.24, 0.86), (0.38, 0.62), (0.3, 0.46), (0.1, 0.4)])
    elif name == "bench":
        rr(0.06, 0.3, 0.94, 0.44, 0.02)
        for x in (0.14, 0.76):
            rr(x, 0.42, x + 0.1, 0.9, 0.02)
        ln([(0.18, 0.66), (0.82, 0.66)], 0.06)
    elif name == "bowl":
        g.chord((0.08 * n, 0.12 * n, 0.92 * n, 0.88 * n), 0, 180, fill=255)
        rr(0.34, 0.84, 0.66, 0.92, 0.02)
        for x in (0.36, 0.52, 0.68):
            g.arc(((x - 0.06) * n, 0.08 * n, (x + 0.06) * n, 0.42 * n), 120, 240, fill=255, width=int(0.05 * n))
    elif name == "leaf":
        g.chord((0.12 * n, 0.08 * n, 0.88 * n, 0.92 * n), 225, 405, fill=255)
        g.line(P((0.22, 0.78), (0.74, 0.26)), fill=0, width=int(0.05 * n))
    elif name == "chest":
        rr(0.08, 0.38, 0.92, 0.88, 0.04)
        g.chord((0.08 * n, 0.12 * n, 0.92 * n, 0.64 * n), 180, 360, fill=255)
        g.rectangle((0.08 * n, 0.4 * n, 0.92 * n, 0.46 * n), fill=0)
        g.rectangle((0.44 * n, 0.46 * n, 0.56 * n, 0.6 * n), fill=0)
    elif name == "planks":
        for i, y in enumerate((0.16, 0.42, 0.68)):
            rr(0.08 + i * 0.04, y, 0.92 - i * 0.04, y + 0.18, 0.04)
    elif name == "search":
        ell(0.1, 0.1, 0.66, 0.66, 0.1)
        ln([(0.58, 0.58), (0.9, 0.9)], 0.12)
    elif name == "sort":
        for i, w in enumerate((0.8, 0.58, 0.36)):
            rr(0.1, 0.16 + i * 0.28, 0.1 + w, 0.28 + i * 0.28, 0.04)

    m = m.resize((px * S, px * S), Image.LANCZOS)
    out = Image.new("RGBA", m.size, (0, 0, 0, 0))
    if shadow:
        sh = Image.new("RGBA", m.size, (0, 0, 0, 255))
        sh.putalpha(m.point(lambda v: int(v * 0.7)))
        out.alpha_composite(ImageChops.offset(sh, 0, S))
    col = Image.new("RGBA", m.size, rgba(colour))
    col.putalpha(m)
    out.alpha_composite(col)
    return out


# ======================================================================================================== icons
ICON_CELL, ICON_PX = (172, 136), 128
ICONS = {}


def load_icons(path, wanted):
    if not path or not os.path.exists(path):
        return
    with open(os.path.join(ROOT, "data", "items", "items.json")) as f:
        items = json.load(f)["items"]
    missing = set()
    needs = os.path.join(os.path.dirname(path), "NEEDS_PAINTING.txt")
    if os.path.exists(needs):
        with open(needs) as f:
            missing = {ln.strip() for ln in f if ln.strip() and not ln.startswith("#")}
    # the sheet holds items.json sorted by id, minus the ones still to paint
    order = {item_id: n for n, item_id in enumerate(i for i in sorted(items) if i not in missing)}
    sheet = Image.open(path).convert("RGBA")
    for item_id in wanted:
        if item_id not in order:
            continue
        n = order[item_id]
        x, y = (n % 10) * ICON_CELL[0] + 4, (n // 10) * ICON_CELL[1] + 4
        icon = np.array(sheet.crop((x, y, x + ICON_PX, y + ICON_PX)))
        near = np.all(np.abs(icon[:, :, :3].astype(int) - np.array([20, 13, 9])) < 6, axis=2)
        icon[near, 3] = 0
        ICONS[item_id] = Image.fromarray(icon, "RGBA")


def draw_icon(cv, item_id, box, share=0.8, alpha=1.0):
    # the icon at 80 % of its box, with a 2 px soft drop shadow; a clearly marked tile when there is no icon yet
    x0, y0, x1, y1 = box
    side = (x1 - x0) * share
    if item_id not in ICONS:
        missing_tile(cv, box)
        return
    px = sc(side)
    icon = ICONS[item_id].resize((px, px), Image.LANCZOS)
    if alpha < 1.0:
        icon.putalpha(icon.getchannel("A").point(lambda v: int(v * alpha)))
    sh = Image.new("RGBA", icon.size, (0, 0, 0, 255))
    sh.putalpha(icon.getchannel("A").point(lambda v: int(v * 0.65 * alpha)))
    sh = sh.filter(ImageFilter.GaussianBlur(S * 1.5))
    at = (x0 + (x1 - x0 - side) / 2, y0 + (y1 - y0 - side) / 2)
    cv.paste(sh, (at[0] + 2, at[1] + 2))
    cv.paste(icon, at)


def missing_tile(cv, box):
    x0, y0, x1, y1 = box
    lay = Image.new("RGBA", (sc(x1 - x0), sc(y1 - y0)), (0, 0, 0, 0))
    g = ImageDraw.Draw(lay)
    for k in range(-lay.height, lay.width, sc(10)):
        g.line((k, lay.height, k + lay.height, 0), fill=rgba((58, 44, 31)), width=S)
    lay.putalpha(ImageChops.multiply(lay.getchannel("A"), round_mask(lay.width, lay.height, sc(4))))
    cv.paste(lay, (x0, y0))
    i = 6
    for a, b in [((x0 + i, y0 + i), (x1 - i, y0 + i)), ((x0 + i, y1 - i), (x1 - i, y1 - i)),
                 ((x0 + i, y0 + i), (x0 + i, y1 - i)), ((x1 - i, y0 + i), (x1 - i, y1 - i))]:
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        k = 0.0
        while k < length:
            t0, t1 = k / length, min(k + 6, length) / length
            cv.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0), (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], rgba(GOLD_LINE), 1)
            k += 11
    cv.text(((x0 + x1) / 2, (y0 + y1) / 2 + 1), "?", T_NAME, rgba(GOLD_LINE), "mm")


# ======================================================================================================== pieces
def backdrop(cv):
    tex = texture(W * S, H * S, BACKDROP, 5, 0, 11)
    yy, xx = np.mgrid[0:H * S, 0:W * S].astype(np.float32)
    r = np.sqrt(((xx / (W * S)) - 0.5) ** 2 * 1.2 + ((yy / (H * S)) - 0.5) ** 2 * 1.6)
    v = np.clip(1.0 - (r - 0.25) * 1.1, 0.45, 1.0)
    arr = (np.array(tex)[:, :, :3].astype(np.float32) * v[:, :, None]).astype(np.uint8)
    cv.img = Image.fromarray(arr, "RGB").convert("RGBA")


def brass_fill(w, h, diagonal=True):
    g = gradient(w, h, BRASS_HI, BRASS_LO, diagonal)
    arr = np.array(g).astype(np.float32)
    arr[:, :, :3] += noise(w, h, 2, 10, RNG.randint(0, 9999))[:, :, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def brass_corner(cv, x, y, flip_x, flip_y):
    n = sc(46)
    m = Image.new("L", (n, n), 0)
    g = ImageDraw.Draw(m)
    t = sc(15)
    g.rounded_rectangle((0, 0, n - 1, t), sc(3), fill=255)
    g.rounded_rectangle((0, 0, t, n - 1), sc(3), fill=255)
    g.polygon([(t, t), (sc(30), t), (t, sc(30))], fill=255)              # the gusset
    g.polygon([(n - 1, t // 2), (n - sc(9), -1), (n, -1)], fill=0)       # cut tips
    g.polygon([(n - 1, t // 2), (n - sc(9), t + 1), (n, t + 1)], fill=0)
    g.polygon([(t // 2, n - 1), (-1, n - sc(9)), (-1, n)], fill=0)
    g.polygon([(t // 2, n - 1), (t + 1, n - sc(9)), (t + 1, n)], fill=0)
    piece = brass_fill(n, n)
    sg = ImageDraw.Draw(piece)
    for _ in range(14):                                                  # wear: a few scuffs
        px, py = RNG.randint(0, n), RNG.randint(0, n)
        sg.line((px, py, px + RNG.randint(-sc(6), sc(6)), py + RNG.randint(-sc(3), sc(3))), fill=rgba(BRASS_LO, 180), width=1)
    piece.putalpha(m)
    rim = Image.new("RGBA", (n, n), rgba(BRASS_DARK))
    rim.putalpha(ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(3))))
    piece.alpha_composite(rim)
    hi = Image.new("RGBA", (n, n), rgba(BRASS_HI))
    hi.putalpha(ImageChops.subtract(m, ImageChops.offset(m, S, S)).point(lambda v: v // 2))
    piece.alpha_composite(hi)
    rg = ImageDraw.Draw(piece)
    c = sc(8)
    rg.ellipse((c - sc(3.5), c - sc(3.5), c + sc(3.5), c + sc(3.5)), fill=rgba(BRASS_DARK))
    rg.ellipse((c - sc(2.5), c - sc(2.5), c + sc(2), c + sc(2)), fill=rgba(BRASS_HI))
    if flip_x:
        piece = piece.transpose(Image.FLIP_LEFT_RIGHT)
    if flip_y:
        piece = piece.transpose(Image.FLIP_TOP_BOTTOM)
    sh = Image.new("RGBA", piece.size, (0, 0, 0, 255))
    sh.putalpha(piece.getchannel("A").point(lambda v: int(v * 0.6)))
    cv.paste(sh.filter(ImageFilter.GaussianBlur(S * 2)), (x + 1, y + 3))
    cv.paste(piece, (x, y))


def panel(cv, box):
    x0, y0, x1, y1 = box
    cv.layer(lambda d: d.rounded_rectangle(sbox((x0, y0 + 8, x1, y1 + 8)), sc(12), fill=(0, 0, 0, 190)), blur=14)
    # aged leather edge, 14 px
    fill_textured(cv, box, texture(sc(x1 - x0), sc(y1 - y0), LEATHER, 14, 0, 21), 12)
    cv.rect(box, 12, outline=rgba(LEATHER_DARK), width=2)
    cv.line([(x0 + 10, y0 + 2.5), (x1 - 10, y0 + 2.5)], rgba((96, 64, 40)), 1)
    # stitching, 7 px in
    i = 7
    for a, b in [((x0 + 24, y0 + i), (x1 - 24, y0 + i)), ((x0 + 24, y1 - i), (x1 - 24, y1 - i)),
                 ((x0 + i, y0 + 24), (x0 + i, y1 - 24)), ((x1 - i, y0 + 24), (x1 - i, y1 - 24))]:
        horiz = a[1] == b[1]
        k = a[0] if horiz else a[1]
        end = b[0] if horiz else b[1]
        while k < end:
            if horiz:
                cv.line([(k, a[1] + 1), (k + 5, a[1] + 1)], (0, 0, 0, 150), 1.5)
                cv.line([(k, a[1]), (k + 5, a[1])], rgba(STITCH), 1.5)
            else:
                cv.line([(a[0] + 1, k), (a[0] + 1, k + 5)], (0, 0, 0, 150), 1.5)
                cv.line([(a[0], k), (a[0], k + 5)], rgba(STITCH), 1.5)
            k += 9
    # the field: one step lighter than the backdrop, faint parchment
    f = (x0 + FRAME, y0 + FRAME, x1 - FRAME, y1 - FRAME)
    fill_textured(cv, f, texture(sc(f[2] - f[0]), sc(f[3] - f[1]), FIELD, 4, 5, 31), 5)
    cv.rect(f, 5, outline=rgba(GOLD_LINE, 150), width=1)
    shade = Image.new("RGBA", (sc(f[2] - f[0]) - 2, sc(10)), (0, 0, 0, 255))
    shade.putalpha(gradient(shade.width, shade.height, (130, 130, 130), (0, 0, 0)).getchannel("R"))
    cv.img.alpha_composite(shade, (sc(f[0]) + 1, sc(f[1]) + 1))
    for cx, cy, fx, fy in [(x0 - 4, y0 - 4, False, False), (x1 - 42, y0 - 4, True, False), (x0 - 4, y1 - 42, False, True), (x1 - 42, y1 - 42, True, True)]:
        brass_corner(cv, cx, cy, fx, fy)


def title_plate(cv, box, s, centred=False, room=10000):
    # a cast brass plate behind the panel name: 30 px of brass each side of the letter-spaced title;
    # a long name (a character's full name) steps down 34, 30, 26 px and letter-spacing 3 to 2 until it fits the room
    x0, y0, _, y1 = box
    spec, track = T_PANEL, 3
    for size, tr in ((34, 3), (30, 2), (26, 2)):
        spec, track = (T_PANEL[0], size), tr
        if cv.text_width(s, spec, track) + 60 <= room:
            break
    w = cv.text_width(s, spec, track) + 60
    if centred:
        x0 -= w / 2
    x1 = x0 + w
    box = (x0, y0, x1, y1)
    cv.layer(lambda d: d.rounded_rectangle(sbox((x0, y0 + 3, x1, y1 + 3)), sc(5), fill=(0, 0, 0, 170)), blur=4)
    w, h = sc(x1 - x0), sc(y1 - y0)
    plate = brass_fill(w, h, diagonal=False)
    plate.putalpha(round_mask(w, h, sc(5)))
    cv.paste(plate, (x0, y0))
    cv.rect(box, 5, outline=rgba(BRASS_DARK), width=1.5)
    cv.line([(x0 + 4, y0 + 2), (x1 - 4, y0 + 2)], rgba(BRASS_HI), 1)
    cv.line([(x0 + 4, y1 - 2), (x1 - 4, y1 - 2)], rgba(BRASS_LO), 1)
    for rx in (x0 + 10, x1 - 10):
        cy = (y0 + y1) / 2
        cv.d.ellipse(sbox((rx - 3.5, cy - 3.5, rx + 3.5, cy + 3.5)), fill=rgba(BRASS_DARK))
        cv.d.ellipse(sbox((rx - 2.5, cy - 2.5, rx + 1.5, cy + 1.5)), fill=rgba(BRASS_HI))
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 1
    cv.text((cx, cy + 1), s, spec, rgba((250, 226, 160), 150), "mm", track=track)
    cv.text((cx, cy), s, spec, rgba(INK), "mm", track=track)


def raised(cv, box, r=5, lit=False, shadow=True):
    x0, y0, x1, y1 = box
    if shadow:
        cv.layer(lambda d: d.rounded_rectangle(sbox((x0, y0 + 3, x1, y1 + 3)), sc(r), fill=(0, 0, 0, 150)), blur=3)
    base = RAISED_LIT if lit else RAISED
    fill_textured(cv, box, gradient(sc(x1 - x0), sc(y1 - y0), tuple(min(255, v + 8) for v in base), base), r)
    cv.rect(box, r, outline=rgba((20, 13, 8)), width=1)
    cv.line([(x0 + r, y0 + 1), (x1 - r, y0 + 1)], rgba(RAISED_EDGE if not lit else (110, 84, 54)), 1)


def well(cv, box, r=4, selected=False, hover=False):
    x0, y0, x1, y1 = box
    if hover:
        cv.layer(lambda d: d.rounded_rectangle(sbox((x0 - 4, y0 - 4, x1 + 4, y1 + 4)), sc(8), fill=(255, 179, 77, 110)), blur=5)
    cv.rect(box, r, fill=rgba(WELL))
    w, h = sc(x1 - x0), sc(y1 - y0)
    a = np.zeros((h, w), dtype=np.float32)
    depth, side = sc(7), sc(4)
    a[:depth, :] = np.maximum(a[:depth, :], np.linspace(0.75, 0, depth)[:, None])
    a[:, :side] = np.maximum(a[:, :side], np.linspace(0.5, 0, side)[None, :])
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    sh.putalpha(ImageChops.multiply(Image.fromarray((a * 255).astype(np.uint8)), round_mask(w, h, sc(r))))
    cv.paste(sh, (x0, y0))
    cv.line([(x0 + r, y1 - 0.5), (x1 - r, y1 - 0.5)], rgba(WELL_LIP), 1)
    cv.line([(x1 - 0.5, y0 + r), (x1 - 0.5, y1 - r)], rgba(WELL_LIP, 110), 1)
    if selected or hover:
        gm = round_mask(w, h, sc(r))
        inner = gm.filter(ImageFilter.MinFilter(sc(8) | 1)).filter(ImageFilter.GaussianBlur(sc(5)))
        gc = Image.new("RGBA", (w, h), rgba(GOLD_BRIGHT))
        gc.putalpha(ImageChops.subtract(gm, inner).point(lambda v: int(v * 0.55)))
        cv.paste(gc, (x0, y0))
        cv.rect(box, r, outline=rgba(GOLD_BRIGHT), width=1.5)


def keycap(cv, x, y, key):
    spec = T_KEY if key.isalpha() else ("EBGaramond-SemiBold.ttf", 18)   # Cinzel's 1 reads as I, so digits use EB Garamond
    w = max(26, cv.text_width(key, spec) + 14)
    raised(cv, (x, y, x + w, y + 26), 4, shadow=False)
    cv.line([(x + 3, y + 26.5), (x + w - 3, y + 26.5)], rgba(OUTLINE), 1.5)
    cv.text((x + w / 2, y + 13), key, spec, rgba(HEADING), "mm")
    return w


def ornament_rule(cv, x0, x1, y):
    cv.line([(x0, y), (x1, y)], rgba(GOLD_LINE, 170), 1)
    cx = (x0 + x1) / 2
    cv.d.polygon([(sc(cx), sc(y - 5)), (sc(cx + 6), sc(y)), (sc(cx), sc(y + 5)), (sc(cx - 6), sc(y))], fill=rgba(GOLD_LINE))
    cv.d.polygon([(sc(cx), sc(y - 2.5)), (sc(cx + 3), sc(y)), (sc(cx), sc(y + 2.5)), (sc(cx - 3), sc(y))], fill=rgba(FIELD))


def number(cv, xy, s, spec=T_COUNT, fill=CREAM, anchor="rs"):
    cv.text(xy, s, spec, rgba(fill), anchor, stroke=1)


def bar(cv, box, frac, fill):
    x0, y0, x1, y1 = box
    cv.rect(box, (y1 - y0) / 2, fill=rgba(WELL))
    cv.line([(x0 + 3, y1), (x1 - 3, y1)], rgba(WELL_LIP, 140), 1)
    fx = x0 + (x1 - x0) * frac
    if fx - x0 < 4:
        return
    g = gradient(sc(fx - x0), sc(y1 - y0), tuple(min(255, int(v * 1.25)) for v in fill), tuple(int(v * 0.8) for v in fill))
    g.putalpha(round_mask(g.width, g.height, sc((y1 - y0) / 2)))
    cv.paste(g, (x0, y0))
    cv.line([(x0 + 3, y0 + 1.5), (fx - 3, y0 + 1.5)], (255, 240, 210, 70), 1)


def wear_bar(cv, box, frac):
    x0, y0, x1, y1 = box
    col = WEAR_GOOD if frac > 0.6 else (BRASS if frac > 0.3 else BAD)
    cv.rect((x0 + 7, y1 - 10, x1 - 7, y1 - 6), 2, fill=rgba(OUTLINE))
    cv.rect((x0 + 7, y1 - 10, x0 + 7 + (x1 - x0 - 14) * frac, y1 - 6), 2, fill=rgba(col))


def field_input(cv, box, placeholder):
    x0, y0, x1, y1 = box
    well(cv, box, 5)
    cv.paste(glyph("search", 18, GOLD_LINE, shadow=False), (x0 + 10, (y0 + y1) / 2 - 9))
    cv.text((x0 + 36, (y0 + y1) / 2), placeholder, T_BODY, rgba(DISABLED), "lm")


def grid_boxes(area, cols, rows, size, gap):
    x0, y0 = area[0], area[1]
    return [(x0 + c * (size + gap), y0 + r * (size + gap), x0 + c * (size + gap) + size, y0 + r * (size + gap) + size) for r in range(rows) for c in range(cols)]


# ======================================================================================================== sample contents
PACK_ITEMS = [("rough_plank", 24, None), ("flint", 12, None), ("plant_fibre", 70, None), ("clay", 24, None), ("twine", 9, None), ("leaves", 20, None),
              ("bone", 4, None), ("raw_meat", 2, None), ("potato", 6, None), ("hide", 3, None), ("rope", 2, None), ("bandage", 5, None),
              ("bucket", 1, 0.8), ("clay_jug", 1, None), ("stone_knife", 1, 0.45), ("herbal_tea", 2, None)] + [None] * 14
HOTBAR = [("stone_axe", 0.9), ("stone_pickaxe", 0.7), ("wooden_spear", 0.25), ("torch", None), ("wooden_spade", None), None,
          ("campfire_kit", None), ("roast_fish", None), None, None]
TABS = ["all", "axe", "spear", "house", "anvil", "flame", "bowl", "leaf", "tunic", "chest", "planks"]
RECIPES = [("Bucket", "bucket", True, None), ("Fishing rod", "fishing_rod", True, None), ("Stone axe", "stone_axe", True, None),
           ("Stone hammer", "stone_hammer", True, None), ("Stone hoe", "stone_hoe", False, None), ("Stone knife", "stone_knife", True, None),
           ("Stone pickaxe", "stone_pickaxe", False, None), ("Stone spade", "stone_spade", True, None), ("Torch", "torch", True, None),
           ("Wooden hammer", "wooden_hammer", True, None), ("Wooden hoe", "wooden_hoe", True, None), ("Wooden spade", "wooden_spade", True, None),
           ("Iron spade", "iron_spade", False, ("anvil", "Forge")), ("Iron hoe", "iron_hoe", False, ("anvil", "Forge")),
           ("Bronze hammer", "bronze_hammer", False, ("anvil", "Forge")), ("Obsidian knife", "obsidian_knife", False, ("bench", "Workbench"))]
SELECTED_SLOT = 12


def wanted_icons():
    out = {r[0] for r in PACK_ITEMS + HOTBAR if r} | {r[1] for r in RECIPES}
    return out | {"linen_shirt", "backpack", "hide_boots", "twine", "stone_axe"}


# ======================================================================================================== the three columns
def draw_pack(cv):
    panel(cv, PACK)
    title_plate(cv, L["pack.plate"], "PACK")
    field_input(cv, L["pack.search"], "Search the pack")
    s = L["pack.sort"]
    raised(cv, s, 5)
    cv.paste(glyph("sort", 20, ENGRAVE), (s[0] + 9, s[1] + 8))
    wb = L["pack.weight"]
    cy = (wb[1] + wb[3]) / 2
    cv.text((wb[0] + 2, cy), "Carrying", T_BODY, rgba(DIM), "lm")
    cv.text((wb[0] + 72, cy), "38.4 of 52 kg", T_BODY_SB, rgba(CREAM), "lm")
    bar(cv, (wb[0] + 200, cy - 4, wb[2], cy + 4), 38.4 / 52.0, BRASS)
    hb = L["pack.hotbar"]
    raised(cv, (hb[0] - 6, hb[1] - 6, hb[2] + 6, hb[3] + 6), 6)
    for k, box in enumerate(grid_boxes(hb, 10, 1, HOT, HOT_GAP)):
        it = HOTBAR[k]
        well(cv, box, 4, selected=(k == 0))
        if it:
            draw_icon(cv, it[0], box)
            if it[1] is not None:
                wear_bar(cv, box, it[1])
        cv.text((box[0] + 5, box[1] + 2), str((k + 1) % 10), T_KEY, rgba(HEADING), "la", stroke=1)
    for n, box in enumerate(grid_boxes(L["pack.grid"], 6, 5, SLOT, SLOT_GAP)):
        it = PACK_ITEMS[n]
        well(cv, box, 4, hover=(n == SELECTED_SLOT))
        if it:
            draw_icon(cv, it[0], box)
            if it[2] is not None:
                wear_bar(cv, box, it[2])
            number(cv, (box[2] - 7, box[3] - 8 - (6 if it[2] is not None else 0)), str(it[1]))
    info = L["pack.info"]
    ornament_rule(cv, info[0] + 8, info[2] - 8, info[1] - 12)
    ibox = (info[0], info[1] + 4, info[0] + SLOT, info[1] + 4 + SLOT)
    well(cv, ibox, 4)
    draw_icon(cv, "bucket", ibox)
    tx = info[0] + 120
    cv.text((tx, info[1] + 4), "Bucket", T_NAME, rgba(HEADING))
    cv.text((tx, info[1] + 48), "A wooden bucket bound with cord.", T_BODY, rgba(CREAM))
    cv.text((tx, info[1] + 72), "Holds eight litres of water.", T_BODY, rgba(CREAM))
    x = tx
    for lab, val in [("Empty", ""), ("Holds", "8 L"), ("Wear", "80 %")]:
        cv.text((x, info[1] + 104), lab, T_BODY, rgba(DIM))
        x += cv.text_width(lab, T_BODY) + 6
        if val:
            cv.text((x, info[1] + 104), val, T_BODY_SB, rgba(CREAM))
            x += cv.text_width(val, T_BODY_SB)
        x += 26
    # the actions as key hints on the item strip, not boxed buttons
    k = L["pack.keys"]
    x = k[0] + 4
    for key, lab, ok in [("E", "Use", True), ("D", "Drop", True), ("S", "Split", False), ("R", "Repair", True), ("1–0", "Put on hotbar", True)]:
        x += keycap(cv, x, k[1] + 2, key) + 8
        cv.text((x, k[1] + 15), lab, T_BODY, rgba(CREAM if ok else DISABLED), "lm")
        x += cv.text_width(lab, T_BODY) + 24


def figure(cv, box):
    # stands in for the live 3D character: key light top left, rim light, ground shadow, warm pool of light behind
    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2
    cv.layer(lambda d: d.ellipse(sbox((cx - 130, y0 + 40, cx + 130, y1 - 30)), fill=(120, 82, 44, 75)), blur=40)
    cv.layer(lambda d: d.ellipse(sbox((cx - 84, y1 - 34, cx + 84, y1 - 8)), fill=(0, 0, 0, 210)), blur=6)
    n = 4
    w, h = sc(x1 - x0) * n, sc(y1 - y0) * n
    m = Image.new("L", (w, h), 0)
    g = ImageDraw.Draw(m)
    u = w / 196.0

    def E(a, b, c, d):
        g.ellipse((a * u, b * u, c * u, d * u), fill=255)

    def R(a, b, c, d, r):
        g.rounded_rectangle((a * u, b * u, c * u, d * u), int(r * u), fill=255)

    def Pg(*pts):
        g.polygon([(x * u, y * u) for x, y in pts], fill=255)

    E(74, 16, 122, 76)                                                     # head
    R(88, 70, 108, 96, 6)                                                  # neck
    Pg((62, 98), (134, 98), (142, 116), (132, 180), (126, 232), (132, 300), (64, 300), (70, 232), (64, 180), (54, 116))
    E(50, 98, 76, 128)                                                     # shoulders
    E(120, 98, 146, 128)
    R(36, 110, 56, 248, 10)                                                # arms, apart from the body
    R(140, 110, 160, 248, 10)
    E(33, 238, 59, 272)                                                    # hands
    E(137, 238, 163, 272)
    R(64, 286, 98, 516, 15)                                                # legs
    R(98, 286, 132, 516, 15)
    E(52, 500, 100, 530)                                                   # feet
    E(96, 500, 144, 530)
    m = m.resize((sc(x1 - x0), sc(y1 - y0)), Image.LANCZOS)
    body = gradient(m.width, m.height, (128, 108, 90), (56, 44, 34))
    shade = gradient(m.width, m.height, (255, 255, 255), (0, 0, 0), diagonal=True).getchannel("R").point(lambda v: int(v * 0.35))
    lit = Image.new("RGBA", m.size, (255, 236, 200, 255))
    lit.putalpha(ImageChops.multiply(shade, m))
    body.putalpha(m)
    rim = ImageChops.subtract(m, ImageChops.offset(m, -sc(3), 0)).filter(ImageFilter.GaussianBlur(S))
    rl = Image.new("RGBA", m.size, (255, 214, 140, 255))
    rl.putalpha(rim.point(lambda v: int(v * 0.85)))
    # what is equipped shows on the model: the linen shirt, the hide boots, the backpack's straps, the axe in hand
    def region(y_top, y_bottom, x_left=0, x_right=196):
        r = Image.new("L", m.size, 0)
        ImageDraw.Draw(r).rectangle((sc(x_left), sc(y_top), sc(x_right), sc(y_bottom)), fill=255)
        return ImageChops.multiply(r, m)

    def dress(mask, top, bottom):
        cloth = gradient(m.width, m.height, top, bottom)
        cloth.putalpha(mask)
        body.alpha_composite(cloth)

    shirt = ImageChops.lighter(region(96, 254, 58, 138), region(98, 180, 30, 166))
    dress(shirt, (186, 164, 120), (112, 96, 70))
    dress(region(470, 532), (112, 76, 48), (58, 38, 24))
    sg = ImageDraw.Draw(body)
    for a, b in (((70, 100), (80, 236)), ((126, 100), (116, 236))):
        sg.line((sc(a[0]), sc(a[1]), sc(b[0]), sc(b[1])), fill=(74, 46, 26, 255), width=sc(8))
    sg.line((sc(64), sc(236), sc(132), sc(236)), fill=(74, 46, 26, 255), width=sc(7))
    body.alpha_composite(lit)
    body.putalpha(ImageChops.multiply(body.getchannel("A"), m))
    body.alpha_composite(rl)
    cv.paste(body, (x0, y0))
    if "stone_axe" in ICONS:
        axe = ICONS["stone_axe"].resize((sc(112), sc(112)), Image.LANCZOS).rotate(70, resample=Image.BICUBIC)
        cv.paste(axe, (x0 + 100, y0 + 176))
    cv.text((cx, y1 + 14), "Live character, as equipped", T_BODY, rgba(DIM), "mm")


def draw_you(cv):
    panel(cv, YOU)
    title_plate(cv, L["you.plate"], "ALDWIN OF THE FORD", centred=True, room=YOU[2] - YOU[0] - 2 * (FRAME + AIR) - 40)
    figure(cv, L["you.figure"])
    gs = 96
    step = (L["you.gear_left"][3] - L["you.gear_left"][1] - gs) / 3
    left = [("helmet", None), ("tunic", "linen_shirt"), ("trousers", None), ("boot", "hide_boots")]
    right = [("glove", None), ("pack", "backpack"), ("hand_axe", "stone_axe"), ("shield", None)]
    for col, names in [(L["you.gear_left"], left), (L["you.gear_right"], right)]:
        for i, (ghost, item) in enumerate(names):
            box = (col[0], col[1] + i * step, col[0] + gs, col[1] + i * step + gs)
            well(cv, box, 4)
            if item:
                draw_icon(cv, item, box)
            else:
                cv.paste(glyph(ghost, 52, GHOST), (box[0] + 22, box[1] + 22))
    st = L["you.stats"]
    ornament_rule(cv, st[0] + 8, st[2] - 8, st[1] - 20)
    vals = [("Health", "heart", 0.92, "92"), ("Exertion", "bolt", 0.18, "18 %"), ("Energy", "moon", 0.74, "74"),
            ("Temperature", "flame", 0.66, "36.8 °C"), ("Food", "bread", 0.81, "81 %"), ("Water", "drop", 0.58, "58 %")]
    for i, (nm, gl, v, label) in enumerate(vals):
        y = st[1] + i * 52
        cv.paste(glyph(gl, 26, ENGRAVE), (st[0] + 2, y + 6))
        cv.text((st[0] + 40, y + 19), nm, T_BODY, rgba(CREAM), "lm")
        bar(cv, (st[0] + 150, y + 14, st[2] - 88, y + 24), v, STAT_FILL[nm])
        number(cv, (st[2], y + 19), label, T_BODY_SB, CREAM, "rm")


def draw_craft(cv):
    panel(cv, CRAFT)
    title_plate(cv, L["craft.plate"], "CRAFT")
    cv.text((CRAFT[2] - 34, 53), "By hand", T_BODY_SB, rgba(CREAM), "rm")
    tb = L["craft.tabs"]
    for i, gl in enumerate(TABS):
        box = (tb[0], tb[1] + i * 54, tb[2], tb[1] + i * 54 + 48)
        sel = i == 1
        raised(cv, box, 5, lit=sel, shadow=not sel)
        if sel:
            cv.rect(box, 5, outline=rgba(GOLD_BRIGHT), width=1.5)
        cv.paste(glyph(gl, 28, HEADING if sel else CREAM), (box[0] + 10, box[1] + 10))
    field_input(cv, L["craft.search"], "Search tools")
    lst = L["craft.list"]
    y = lst[1]
    for nm, icon, ok, station in RECIPES:
        h = 64 if station else 44
        if y + h > lst[3]:
            break
        box = (lst[0], y, lst[2], y + h)
        sel = nm == "Stone axe"
        if sel:
            raised(cv, box, 4, lit=True, shadow=False)
            cv.paste(gradient(sc(4), sc(h - 4), BRASS_HI, BRASS_LO), (box[0], box[1] + 2))
        draw_icon(cv, icon, (box[0] + 10, y + 6, box[0] + 42, y + 38), 1.0, alpha=1.0 if ok else 0.45)
        cv.text((box[0] + 52, y + 22), nm, T_BODY_SB if sel else T_BODY, rgba(HEADING if sel else (CREAM if ok else DISABLED)), "lm")
        if station:
            cv.paste(glyph(station[0], 20, DIM), (box[0] + 52, y + 36))
            cv.text((box[0] + 78, y + 47), "needs " + station[1], T_BODY, rgba(DIM), "lm")
        if not sel:
            cv.line([(box[0] + 8, y + h + 1.5), (box[2] - 8, y + h + 1.5)], rgba((52, 39, 27)), 1)
        y += h + 3
    card = L["craft.card"]
    raised(cv, card, 6)
    ib = L["craft.icon"]
    well(cv, ib, 5, selected=True)
    draw_icon(cv, "stone_axe", ib)
    nm = L["craft.name"]
    cv.text((nm[0], nm[1]), "Stone axe", T_NAME, rgba(HEADING))
    cv.text((nm[0], nm[1] + 44), "Tools", T_BODY, rgba(DIM))
    cv.text((nm[0], nm[1] + 68), "By hand  ·  10 s", T_BODY, rgba(DIM))
    de = L["craft.desc"]
    cv.text((de[0], de[1]), "A stone bound to a handle. Fells trees,", T_BODY, rgba(CREAM))
    cv.text((de[0], de[1] + 24), "breaks rock and works wood.", T_BODY, rgba(CREAM))
    stt = L["craft.stats"]
    for i, (lab, val) in enumerate([("Chop", "1.0"), ("Dig", "1.0"), ("Lasts", "900 uses"), ("Mends with", "stick, twine")]):
        yy = stt[1] + i * 26
        cv.text((stt[0], yy), lab, T_BODY, rgba(DIM))
        number(cv, (stt[2], yy), val, T_BODY_SB, CREAM, "ra")
        cv.line([(stt[0] + cv.text_width(lab, T_BODY) + 8, yy + 15), (stt[2] - cv.text_width(val, T_BODY_SB) - 8, yy + 15)], rgba((70, 54, 38)), 1)
    ne = L["craft.needs"]
    cv.text((ne[0], ne[1]), "Needs", T_HEAD, rgba(HEADING))
    cv.line([(ne[0] + 82, ne[1] + 14), (ne[2], ne[1] + 14)], rgba(GOLD_LINE, 170), 1)
    needs = [("stone", "Stone", "3", "1", True, False), ("stick", "Stick", "12", "1", True, True), ("twine", "Twine", "1", "2", False, False)]
    for i, (icon, label, have, need, ok, chest) in enumerate(needs):
        box = (ne[0] + i * 96, ne[1] + 38, ne[0] + i * 96 + 80, ne[1] + 118)
        well(cv, box, 4)
        draw_icon(cv, icon, box)
        if chest:
            cv.paste(glyph("chest", 22, ENGRAVE), (box[2] - 25, box[1] + 3))
        cv.text(((box[0] + box[2]) / 2, box[3] + 16), label, T_BODY, rgba(CREAM), "mm")
        number(cv, ((box[0] + box[2]) / 2, box[3] + 40), have + " / " + need, T_BODY_SB, CREAM if ok else BAD, "mm")
    q = L["craft.qty"]
    cv.text((q[0], (q[1] + q[3]) / 2), "Make", T_BODY, rgba(CREAM), "lm")
    for bx, lab in [((q[0] + 66, q[1], q[0] + 110, q[3]), "–"), ((q[0] + 204, q[1], q[0] + 248, q[3]), "+")]:
        raised(cv, bx, 5)
        cv.text(((bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2), lab, T_BUTTON, rgba(CREAM), "mm")
    well(cv, (q[0] + 118, q[1], q[0] + 196, q[3]), 5)
    number(cv, (q[0] + 157, (q[1] + q[3]) / 2), "1", T_BUTTON, CREAM, "mm")
    raised(cv, (q[0] + 260, q[1], q[2], q[3]), 5)
    cv.text(((q[0] + 260 + q[2]) / 2, (q[1] + q[3]) / 2), "Most", T_BODY_SB, rgba(CREAM), "mm")
    sh = L["craft.short"]
    cv.text((sh[0], (sh[1] + sh[3]) / 2), "Short 1 twine: Craft makes it first from fibre.", T_BODY, rgba(BAD), "lm")
    # Made at, and Used in (recipes that take this item; the stone axe is kept as their tool)
    for key, head in (("craft.made_at", "Made at"), ("craft.used_in", "Used in")):
        bx = L[key]
        cv.text((bx[0], bx[1]), head, T_HEAD, rgba(HEADING))
        hw = cv.text_width(head, T_HEAD)
        cv.line([(bx[0] + hw + 12, bx[1] + 14), (bx[2], bx[1] + 14)], rgba(GOLD_LINE, 170), 1)
    ma = L["craft.made_at"]
    cv.paste(glyph("glove", 22, ENGRAVE), (ma[0], ma[1] + 34))
    cv.text((ma[0] + 30, ma[1] + 45), "By hand, anywhere", T_BODY, rgba(CREAM), "lm")
    ui = L["craft.used_in"]
    x = ui[0]
    for i, name in enumerate(["Log seat", "Small wooden blocks"]):
        cv.text((x, ui[1] + 45), name, T_BODY_SB, rgba(HEADING), "lm")
        w = cv.text_width(name, T_BODY_SB)
        cv.line([(x, ui[1] + 55), (x + w, ui[1] + 55)], rgba(GOLD_LINE), 1)
        x += w
        cv.text((x + 7, ui[1] + 45), "·", T_BODY, rgba(DIM), "lm")
        x += 20
    cv.text((x, ui[1] + 45), "+1 more", T_BODY, rgba(DIM), "lm")
    qu = L["craft.queue"]
    ornament_rule(cv, qu[0] + 4, qu[2] - 4, qu[1] - 16)
    cv.text((qu[0], (qu[1] + qu[3]) / 2), "Making", T_BODY, rgba(DIM), "lm")
    for i in range(2):
        box = (qu[0] + 76 + i * 64, qu[1], qu[0] + 132 + i * 64, qu[3])
        well(cv, box, 4)
        draw_icon(cv, "twine", box)
        if i == 0:
            cv.d.arc(sbox((box[0] + 4, box[1] + 4, box[2] - 4, box[3] - 4)), -90, 130, fill=rgba(GOLD_BRIGHT), width=sc(3))
    b = L["craft.button"]
    # brass, with a faint glow because it is ready
    cv.layer(lambda d: d.rounded_rectangle(sbox((b[0] - 4, b[1] - 4, b[2] + 4, b[3] + 4)), sc(10), fill=(255, 200, 100, 90)), blur=10)
    w, h = sc(b[2] - b[0]), sc(b[3] - b[1])
    face = brass_fill(w, h, diagonal=False)
    face.putalpha(round_mask(w, h, sc(6)))
    cv.paste(face, (b[0], b[1]))
    cv.rect(b, 6, outline=rgba(BRASS_DARK), width=1.5)
    cv.line([(b[0] + 6, b[1] + 2), (b[2] - 6, b[1] + 2)], rgba((255, 236, 180)), 1)
    cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2 + 1
    cv.text((cx, cy + 1), "CRAFT", T_BUTTON, rgba((250, 226, 160), 150), "mm", track=4)
    cv.text((cx, cy), "CRAFT", T_BUTTON, rgba(INK), "mm", track=4)
    # the hold ring, smooth, engraved into the left end
    ring = (b[0] + 18, b[1] + 14, b[0] + 54, b[1] + 50)
    cv.d.ellipse(sbox(ring), outline=rgba(BRASS_LO), width=sc(4))
    cv.d.arc(sbox(ring), -90, 140, fill=rgba(INK), width=sc(4))


def measured(img):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(os.path.join(FONTS, "EBGaramond-SemiBold.ttf"), 18)
    for box in [PACK, YOU, CRAFT]:
        d.rectangle(box, outline="#FF4FD8", width=2)
        d.text((box[0] + 6, box[3] + 2), "%d x %d" % (box[2] - box[0], box[3] - box[1]), font=f, fill="#FF4FD8")
    for key, box in L.items():
        d.rectangle(box, outline="#4FE3FF", width=1)
        d.text((box[0] + 3, box[1] + 1), "%s %dx%d" % (key, box[2] - box[0], box[3] - box[1]), font=f, fill="#4FE3FF")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--icons", default="")
    ap.add_argument("--measured", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    load_icons(a.icons, wanted_icons())
    cv = Canvas()
    backdrop(cv)
    draw_pack(cv)
    draw_you(cv)
    draw_craft(cv)
    out = cv.img.resize((W, H), Image.LANCZOS).convert("RGB")
    out.save(os.path.join(a.out, "inventory_redesign_1920_v3.png"), optimize=True)
    if a.measured:
        m = out.copy()
        measured(m)
        m.save(os.path.join(a.out, "inventory_redesign_1920_v3_measured.png"), optimize=True)


if __name__ == "__main__":
    main()
