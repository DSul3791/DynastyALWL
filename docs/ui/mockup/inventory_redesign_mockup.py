#!/usr/bin/env python3
# Inventory and crafting redesign mockup (docs/ui/inventory_crafting_redesign.md; Kathleen, 9 Nov 2026).
# Draws the measured layout on the 1920 x 1080 design canvas (Dave, 9 Nov 2026: "our screen design size is 1920x1080") from the numbers
# below and nothing else, so the picture and the doc cannot drift apart. Every rectangle is in canvas px.
#
#   python3 docs/ui/mockup/inventory_redesign_mockup.py --out DIR [--icons item_icon_sheet.png] [--scene screenshot.png] [--all]
#
# Writes DIR/inventory_redesign_1920.png: pack, you, craft (by hand).
# --all also writes inventory_redesign_chest_1920.png (a chest open) and inventory_redesign_measured_1920.png (every box outlined and sized).
# --icons: the icon bake sheet (tools/icon_bake.gd --sheet); its icons fill the slots as stand-ins. Without it the slots get plain shapes.
# --scene: a game screenshot shown behind the panels (the world stays visible in the margins).

import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FONTS = os.path.join(ROOT, "assets", "ui", "fonts")

W, H = 1920, 1080

# Colours: src/client/ui/dynasty_theme.gd, as hex.
WOOD_DARK = "#1F130D"
WOOD = "#402617"
WOOD_LIT = "#5C361C"
GOLD = "#DBA84C"
GOLD_DIM = "#8C6933"
GOLD_BRIGHT = "#FFD67A"
CREAM = "#F5E6BD"
HEADING = "#F2C76B"
SLOT_BG = "#140D09"
BAD = "#BF2E24"
GOOD = "#6BA84C"
BAR_COLOURS = {"Health": "#D93333", "Exertion": "#F2CC40", "Energy": "#9973E6", "Warmth": "#73CCF2", "Food": "#E68C33", "Water": "#4D99F2"}

# Type: Cinzel for titles and headings, EB Garamond for everything read. Nothing under 18 px.
T_TITLE = ("Cinzel-Bold.ttf", 30)
T_HEAD = ("Cinzel-Regular.ttf", 22)
T_KEY = ("Cinzel-Bold.ttf", 18)
T_BODY = ("EBGaramond-Regular.ttf", 20)
T_SMALL = ("EBGaramond-Regular.ttf", 18)
T_COUNT = ("EBGaramond-SemiBold.ttf", 24)
T_NAME = ("Cinzel-Bold.ttf", 30)
T_BUTTON = ("Cinzel-Bold.ttf", 26)

# ---- the layout (canvas px) ----
MARGIN = 32
GUTTER = 24
PAD = 10            # inside each panel: a 6 px carved edge and 4 px of air
SLOT = 100
SLOT_GAP = 12       # 6 x 100 + 5 x 12 = 660 = the column's inside
HOT = 60            # hotbar slot: the ten keys (1 to 9 and 0) fit the same 660
HOT_GAP = 6
CARD = 4            # every slot's corner radius

PACK = (32, 32, 712, 1048)
YOU = (736, 32, 1184, 1048)
CRAFT = (1208, 32, 1888, 1048)

L = {
    # pack: inside 42..702
    "pack.title": (42, 42, 702, 90),
    "pack.search": (414, 48, 654, 84),
    "pack.sort": (666, 48, 702, 84),
    "pack.weight": (42, 96, 702, 120),
    "pack.hotbar": (45, 134, 699, 194),
    "pack.grid": (42, 214, 702, 762),
    "pack.info": (42, 782, 702, 1038),
    "pack.actions": (42, 990, 702, 1038),
    # you: inside 746..1174
    "you.title": (746, 42, 1174, 90),
    "you.slots_left": (746, 98, 846, 598),
    "you.figure": (858, 98, 1062, 598),
    "you.slots_right": (1074, 98, 1174, 598),
    "you.stats": (746, 630, 1174, 908),
    # craft: inside 1218..1878
    "craft.title": (1218, 42, 1878, 90),
    "craft.tabs": (1218, 98, 1266, 686),
    "craft.search": (1274, 98, 1470, 134),
    "craft.list": (1274, 142, 1470, 1038),
    "craft.detail": (1486, 98, 1878, 1038),
    "craft.icon": (1486, 98, 1614, 226),
    "craft.name": (1630, 104, 1878, 226),
    "craft.desc": (1486, 242, 1878, 306),
    "craft.stats": (1486, 316, 1878, 460),
    "craft.req_head": (1486, 476, 1878, 500),
    "craft.req": (1486, 508, 1842, 640),
    "craft.qty": (1486, 664, 1878, 712),
    "craft.queue": (1486, 896, 1878, 956),
    "craft.button": (1486, 974, 1878, 1038),
    # chest (the right column when a container is open)
    "chest.title": (1218, 42, 1878, 90),
    "chest.bar": (1218, 98, 1878, 146),
    "chest.grid": (1218, 158, 1878, 706),
    "chest.tools": (1218, 722, 1878, 770),
}


def font(spec):
    return ImageFont.truetype(os.path.join(FONTS, spec[0]), spec[1])


def text(d, xy, s, spec, fill=CREAM, anchor="la"):
    d.text(xy, s, font=font(spec), fill=fill, anchor=anchor)


def outlined(d, xy, s, spec, fill=CREAM, anchor="rs"):
    d.text(xy, s, font=font(spec), fill=fill, anchor=anchor, stroke_width=2, stroke_fill="#000000")


# ---- icons from the bake sheet ----
ICON_CELL = (172, 136)
ICON_PX = 128
ICONS = {}


def sheet_order(sheet_path):
    # The bake sheet holds every item in data/items/items.json, sorted by id, minus the ones listed in NEEDS_PAINTING.txt beside it.
    import json
    with open(os.path.join(ROOT, "data", "items", "items.json")) as f:
        items = json.load(f)["items"]
    missing = set()
    needs = os.path.join(os.path.dirname(sheet_path), "NEEDS_PAINTING.txt")
    if os.path.exists(needs):
        with open(needs) as f:
            missing = {ln.strip() for ln in f if ln.strip() and not ln.startswith("#")}
    return {item_id: n for n, item_id in enumerate(i for i in sorted(items) if i not in missing)}


def load_icons(path, wanted):
    if not path or not os.path.exists(path):
        return
    order = sheet_order(path)
    sheet = Image.open(path).convert("RGBA")
    bg = (20, 13, 9)
    for item_id in wanted:
        if item_id not in order:
            continue
        n = order[item_id]
        x = (n % 10) * ICON_CELL[0] + 4
        y = (n // 10) * ICON_CELL[1] + 4
        if y + ICON_PX > sheet.height:
            continue
        icon = sheet.crop((x, y, x + ICON_PX, y + ICON_PX))
        px = icon.load()
        for j in range(ICON_PX):
            for i in range(ICON_PX):
                r, g, b, a = px[i, j]
                if abs(r - bg[0]) < 6 and abs(g - bg[1]) < 6 and abs(b - bg[2]) < 6:
                    px[i, j] = (0, 0, 0, 0)
        ICONS[item_id] = icon


def paste_icon(img, n, box, share=0.8, alpha=1.0):
    x0, y0, x1, y1 = box
    side = int(round(min(x1 - x0, y1 - y0) * share))
    if n in ICONS:
        icon = ICONS[n].resize((side, side), Image.LANCZOS)
        if alpha < 1.0:
            icon.putalpha(icon.getchannel("A").point(lambda v: int(v * alpha)))
        img.alpha_composite(icon, (x0 + (x1 - x0 - side) // 2, y0 + (y1 - y0 - side) // 2))
    else:
        d = ImageDraw.Draw(img)
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        r = side // 3
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD_DIM)


# ---- pieces ----
def panel(img, box):
    x0, y0, x1, y1 = box
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x0 + 4, y0 + 10, x1 + 4, y1 + 10), 8, fill=(0, 0, 0, 160))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12)))
    d = ImageDraw.Draw(img)
    # carved wood edge (6 px), a 1 px gold line inside it, the solid dark field
    d.rounded_rectangle(box, 8, fill=WOOD)
    d.rounded_rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), 7, outline=WOOD_LIT, width=1)
    d.rounded_rectangle((x0 + 5, y0 + 5, x1 - 5, y1 - 5), 6, outline=GOLD_DIM, width=1)
    d.rounded_rectangle((x0 + 6, y0 + 6, x1 - 6, y1 - 6), 5, fill=WOOD_DARK)
    # brass corner caps, 32 px
    for cx, cy in [(x0 - 2, y0 - 2), (x1 - 30, y0 - 2), (x0 - 2, y1 - 30), (x1 - 30, y1 - 30)]:
        d.rounded_rectangle((cx, cy, cx + 32, cy + 32), 4, fill=GOLD_DIM)
        d.rounded_rectangle((cx + 3, cy + 3, cx + 29, cy + 29), 3, fill=GOLD)
        d.ellipse((cx + 12, cy + 12, cx + 20, cy + 20), fill=GOLD_DIM)


def rule(d, x0, x1, y):
    d.line((x0, y, x1, y), fill=GOLD_DIM, width=1)


def slot(img, box, icon=None, count=None, wear=None, key=None, selected=False, hover=False, ghost=None, alpha=1.0):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    if hover:
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle((x0 - 4, y0 - 4, x1 + 4, y1 + 4), 8, fill=(255, 179, 77, 120))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5)))
        d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, CARD, fill=SLOT_BG, outline=GOLD_BRIGHT if (selected or hover) else GOLD_DIM, width=2 if (selected or hover) else 1)
    d.line((x0 + 2, y0 + 2, x1 - 3, y0 + 2), fill="#0A0604", width=1)
    d.line((x0 + 2, y0 + 2, x0 + 2, y1 - 3), fill="#0A0604", width=1)
    d.line((x0 + 3, y1 - 2, x1 - 2, y1 - 2), fill="#3A2416", width=1)
    d.line((x1 - 2, y0 + 3, x1 - 2, y1 - 2), fill="#3A2416", width=1)
    if ghost:
        d.text(((x0 + x1) // 2, (y0 + y1) // 2), ghost, font=font(T_SMALL), fill="#5A4A3A", anchor="mm")
    if icon is not None:
        paste_icon(img, icon, box, alpha=alpha)
        d = ImageDraw.Draw(img)
    if count:
        outlined(d, (x1 - 7, y1 - 8), str(count), T_COUNT if (x1 - x0) >= 80 else T_SMALL)
    if wear is not None:
        w = int((x1 - x0 - 14) * wear)
        d.rectangle((x0 + 7, y1 - 10, x1 - 7, y1 - 7), fill="#0A0604")
        d.rectangle((x0 + 7, y1 - 10, x0 + 7 + w, y1 - 7), fill=GOOD if wear > 0.6 else (GOLD if wear > 0.3 else BAD))
    if key is not None:
        d.text((x0 + 5, y0 + 2), key, font=font(T_KEY), fill=HEADING)


def button(d, box, label, spec=T_SMALL, accent=False, enabled=True):
    d.rounded_rectangle(box, 5, fill=WOOD_LIT if accent else WOOD, outline=GOLD_BRIGHT if accent else GOLD_DIM, width=2 if accent else 1)
    x0, y0, x1, y1 = box
    d.text(((x0 + x1) // 2, (y0 + y1) // 2), label, font=font(spec), fill=(HEADING if accent else CREAM) if enabled else "#7A6E5C", anchor="mm")


def field(d, box, placeholder):
    d.rounded_rectangle(box, 5, fill=SLOT_BG, outline=GOLD_DIM, width=1)
    x0, y0, x1, y1 = box
    cx, cy = x0 + 17, (y0 + y1) // 2 - 1
    d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), outline=GOLD_DIM, width=2)
    d.line((cx + 5, cy + 5, cx + 10, cy + 10), fill=GOLD_DIM, width=2)
    d.text((x0 + 34, (y0 + y1) // 2), placeholder, font=font(T_SMALL), fill="#7A6E5C", anchor="lm")


def grid_boxes(area, cols, rows, size, gap):
    x0, y0 = area[0], area[1]
    return [(x0 + c * (size + gap), y0 + r * (size + gap), x0 + c * (size + gap) + size, y0 + r * (size + gap) + size) for r in range(rows) for c in range(cols)]


# Sample contents (item ids; the 9 Nov bake sheet's icons stand in until the painted ones exist).
# log, stick and stone have no icon yet (NEEDS_PAINTING.txt), so the sample pack leaves them out.
PACK_ITEMS = [("rough_plank", 24, None), ("flint", 12, None), ("plant_fibre", 70, None), ("clay", 24, None), ("twine", 9, None), ("leaves", 20, None),
              ("bone", 4, None), ("raw_meat", 2, None), ("potato", 6, None), ("hide", 3, None), ("rope", 2, None), ("bandage", 5, None),
              ("bucket", 1, 0.8), ("clay_jug", 1, None), ("stone_knife", 1, 0.45), ("herbal_tea", 2, None), None, None] + [None] * 12
HOTBAR = [("stone_axe", 0.9), ("stone_pickaxe", 0.7), ("wooden_spear", 0.25), ("torch", None), ("wooden_spade", None), None,
          ("campfire_kit", None), ("roast_fish", None), None, None]
CHEST_ITEMS = [("rough_plank", 40), ("flint", 22), ("clay", 30), ("potato", 14), ("wheat", 25), ("hide", 6), ("dried_berries", 8), ("leather", 5)] + [None] * 22
TABS = [("All", None), ("Tools", "stone_axe"), ("Weapons", "wooden_spear"), ("Building", "log_wall_kit"), ("Stations", "workbench_kit"),
        ("Fire", "campfire_kit"), ("Food", "apple_pie"), ("Medicine", "herb_salve"), ("Clothing", "hide_tunic"), ("Storage", "chest_kit"),
        ("Materials", "rough_plank")]
RECIPES = [("Bucket", "bucket", True, None), ("Fishing rod", "fishing_rod", True, None), ("Stone axe", "stone_axe", True, None),
           ("Stone hammer", "stone_hammer", True, None), ("Stone hoe", "stone_hoe", False, None), ("Stone knife", "stone_knife", True, None),
           ("Stone pickaxe", "stone_pickaxe", False, None), ("Stone spade", "stone_spade", True, None), ("Torch", "torch", True, None),
           ("Wooden hammer", "wooden_hammer", True, None), ("Wooden hoe", "wooden_hoe", True, None), ("Wooden spade", "wooden_spade", True, None),
           ("Iron spade", "iron_spade", False, "F"), ("Iron hoe", "iron_hoe", False, "F"), ("Bronze hammer", "bronze_hammer", False, "F"),
           ("Bronze knife", "bronze_knife", False, "F"), ("Obsidian knife", "obsidian_knife", False, "W"), ("Steel hoe", "steel_hoe", False, "F")]
SELECTED = 12


def wanted_icons():
    out = set()
    for row in PACK_ITEMS + HOTBAR + CHEST_ITEMS:
        if row:
            out.add(row[0])
    out |= {r[1] for r in RECIPES} | {t[1] for t in TABS if t[1]} | {"linen_shirt", "backpack", "hide_boots", "flint", "twine", "plant_fibre"}
    return out


def draw_pack(img):
    d = ImageDraw.Draw(img)
    panel(img, PACK)
    t = L["pack.title"]
    text(d, (t[0] + 30, (t[1] + t[3]) // 2), "Pack", T_TITLE, HEADING, "lm")
    field(d, L["pack.search"], "Search the pack")
    s = L["pack.sort"]
    d.rounded_rectangle(s, 5, fill=WOOD, outline=GOLD_DIM, width=1)
    for i, w in enumerate([20, 14, 8]):
        d.line((s[0] + 8, s[1] + 11 + i * 7, s[0] + 8 + w, s[1] + 11 + i * 7), fill=GOLD, width=3)
    wb = L["pack.weight"]
    text(d, (wb[0] + 4, (wb[1] + wb[3]) // 2), "Carrying 38.4 of 52 kg", T_SMALL, CREAM, "lm")
    bx0, bx1, by = wb[0] + 210, wb[2], (wb[1] + wb[3]) // 2
    d.rounded_rectangle((bx0, by - 3, bx1, by + 3), 3, fill=SLOT_BG)
    d.rounded_rectangle((bx0, by - 3, bx0 + int((bx1 - bx0) * 38.4 / 52.0), by + 3), 3, fill=GOLD)
    hb = L["pack.hotbar"]
    d.rounded_rectangle((hb[0] - 3, hb[1] - 4, hb[2] + 3, hb[3] + 4), 6, fill="#2A1A11", outline=GOLD, width=1)
    for k, box in enumerate(grid_boxes(hb, 10, 1, HOT, HOT_GAP)):
        it = HOTBAR[k]
        slot(img, box, icon=it[0] if it else None, wear=it[1] if it else None, key=str((k + 1) % 10), selected=(k == 0))
    for n, box in enumerate(grid_boxes(L["pack.grid"], 6, 5, SLOT, SLOT_GAP)):
        it = PACK_ITEMS[n]
        slot(img, box, icon=it[0] if it else None, count=it[1] if it else None, wear=it[2] if it else None, hover=(n == SELECTED))
    d = ImageDraw.Draw(img)
    # the information strip: what the pointer is on (or the selected slot); never a floating card over the grid
    info = L["pack.info"]
    rule(d, info[0], info[2], info[1] - 10)
    slot(img, (info[0], info[1], info[0] + SLOT, info[1] + SLOT), icon=PACK_ITEMS[SELECTED][0])
    d = ImageDraw.Draw(img)
    text(d, (info[0] + 116, info[1] + 2), "Bucket", T_NAME, HEADING)
    text(d, (info[0] + 116, info[1] + 46), "A wooden bucket bound with cord.", T_BODY)
    text(d, (info[0] + 116, info[1] + 72), "Holds eight litres of water.", T_BODY)
    text(d, (info[0] + 116, info[1] + 106), "Empty      holds 8 L      wear 80 %", T_SMALL)
    a = L["pack.actions"]
    w = (a[2] - a[0] - 3 * 12) // 4
    for i, lab in enumerate(["Use  (E)", "Drop  (D)", "Split  (S)", "Repair  (R)"]):
        button(d, (a[0] + i * (w + 12), a[1], a[0] + i * (w + 12) + w, a[3]), lab, T_BODY, enabled=(i != 2))


def draw_you(img):
    d = ImageDraw.Draw(img)
    panel(img, YOU)
    t = L["you.title"]
    text(d, ((t[0] + t[2]) // 2, (t[1] + t[3]) // 2), "Aldwin of the Ford", T_TITLE, HEADING, "mm")
    fig = L["you.figure"]
    d.rounded_rectangle(fig, 6, fill="#26180F")
    cx, top = (fig[0] + fig[2]) // 2, fig[1]
    body = "#5A4636"
    d.ellipse((cx - 30, top + 40, cx + 30, top + 106), fill=body)
    d.rounded_rectangle((cx - 52, top + 112, cx + 52, top + 300), 20, fill=body)
    d.rounded_rectangle((cx - 74, top + 120, cx - 56, top + 290), 9, fill=body)
    d.rounded_rectangle((cx + 56, top + 120, cx + 74, top + 290), 9, fill=body)
    d.rounded_rectangle((cx - 46, top + 296, cx - 6, top + 450), 12, fill=body)
    d.rounded_rectangle((cx + 6, top + 296, cx + 46, top + 450), 12, fill=body)
    d.text((cx, fig[3] - 8), "your character, live", font=font(T_SMALL), fill="#8A7660", anchor="ms")
    left = [("Head", None), ("Body", "linen_shirt"), ("Legs", None), ("Feet", "hide_boots")]
    right = [("Hands", None), ("Back", "backpack"), ("Right", "stone_axe"), ("Left", None)]
    step = SLOT + 33
    for col, names in [(L["you.slots_left"], left), (L["you.slots_right"], right)]:
        for i, (nm, icon) in enumerate(names):
            box = (col[0], col[1] + i * step, col[0] + SLOT, col[1] + i * step + SLOT)
            slot(img, box, icon=icon, ghost=None if icon is not None else nm)
    d = ImageDraw.Draw(img)
    st = L["you.stats"]
    rule(d, st[0], st[2], st[1] - 14)
    vals = [("Health", 0.92, "92"), ("Exertion", 0.18, "18 %"), ("Energy", 0.74, "74"), ("Warmth", 0.66, "36.8 °C"), ("Food", 0.81, "81 %"), ("Water", 0.58, "58 %")]
    for i, (nm, v, label) in enumerate(vals):
        y = st[1] + i * 48
        d.ellipse((st[0] + 2, y + 7, st[0] + 26, y + 31), fill=BAR_COLOURS[nm])
        text(d, (st[0] + 36, y + 19), nm, T_BODY, CREAM, "lm")
        bx0, bx1 = st[0] + 140, st[2] - 82
        d.rounded_rectangle((bx0, y + 14, bx1, y + 24), 5, fill=SLOT_BG)
        d.rounded_rectangle((bx0, y + 14, bx0 + int((bx1 - bx0) * v), y + 24), 5, fill=BAR_COLOURS[nm])
        text(d, (st[2], y + 19), label, T_BODY, CREAM, "rm")


def draw_craft(img):
    d = ImageDraw.Draw(img)
    panel(img, CRAFT)
    t = L["craft.title"]
    text(d, (t[0] + 30, (t[1] + t[3]) // 2), "Craft", T_TITLE, HEADING, "lm")
    text(d, (t[2] - 34, (t[1] + t[3]) // 2), "By hand", T_BODY, CREAM, "rm")
    tb = L["craft.tabs"]
    for i, (nm, icon) in enumerate(TABS):
        box = (tb[0], tb[1] + i * 54, tb[2], tb[1] + i * 54 + 48)
        sel = i == 1
        d.rounded_rectangle(box, 5, fill=WOOD_LIT if sel else WOOD, outline=GOLD_BRIGHT if sel else GOLD_DIM, width=2 if sel else 1)
        if icon is None:
            d.text(((box[0] + box[2]) // 2, (box[1] + box[3]) // 2), "All", font=font(("Cinzel-Bold.ttf", 18)), fill=HEADING if sel else CREAM, anchor="mm")
        else:
            paste_icon(img, icon, (box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6), 1.0, alpha=1.0 if sel else 0.75)
            d = ImageDraw.Draw(img)
    field(d, L["craft.search"], "Search tools")
    lst = L["craft.list"]
    for i, (nm, icon, ok, station) in enumerate(RECIPES):
        y = lst[1] + i * 48
        if y + 44 > lst[3]:
            break
        box = (lst[0], y, lst[2], y + 44)
        sel = nm == "Stone axe"
        d.rounded_rectangle(box, 4, fill=WOOD_LIT if sel else "#28190F", outline=GOLD_BRIGHT if sel else None, width=1)
        if ok:
            d.rectangle((box[0], box[1] + 6, box[0] + 3, box[3] - 6), fill=GOLD)
        paste_icon(img, icon, (box[0] + 8, y + 6, box[0] + 40, y + 38), 1.0, alpha=1.0 if ok else 0.45)
        d = ImageDraw.Draw(img)
        text(d, (box[0] + 48, y + 22), nm, T_SMALL, CREAM if ok else "#8C826B", "lm")
        if station:
            d.rounded_rectangle((box[2] - 28, y + 11, box[2] - 6, y + 33), 4, outline=GOLD_DIM, width=1)
            d.text((box[2] - 17, y + 22), station, font=font(("Cinzel-Bold.ttf", 18)), fill=GOLD_DIM, anchor="mm")
    slot(img, L["craft.icon"], icon="stone_axe")
    d = ImageDraw.Draw(img)
    nm = L["craft.name"]
    text(d, (nm[0], nm[1]), "Stone axe", T_NAME, HEADING)
    text(d, (nm[0], nm[1] + 46), "Tools  ·  by hand  ·  10 s", T_SMALL, CREAM)
    de = L["craft.desc"]
    text(d, (de[0], de[1]), "A stone bound to a handle. Fells trees,", T_BODY)
    text(d, (de[0], de[1] + 26), "breaks rock and works wood.", T_BODY)
    stt = L["craft.stats"]
    for i, line in enumerate(["Chop  1.0", "Dig  1.0", "Lasts  900 uses", "Mend with a stick and twine"]):
        text(d, (stt[0], stt[1] + i * 26), line, T_BODY)
    rh = L["craft.req_head"]
    text(d, (rh[0], rh[1]), "Needs", T_HEAD, HEADING)
    rule(d, rh[0] + 84, rh[2], rh[1] + 13)
    rq = L["craft.req"]
    needs = [("stone", "Stone", "3 / 1", True, False), ("stick", "Stick", "12 / 1", True, True), ("twine", "Twine", "1 / 2", False, False)]
    for i, (icon, label, have, ok, chest) in enumerate(needs):
        box = (rq[0] + i * 92, rq[1], rq[0] + i * 92 + 80, rq[1] + 80)
        slot(img, box, icon=icon)
        d = ImageDraw.Draw(img)
        if chest:
            cx0, cy0 = box[2] - 24, box[1] + 4
            d.rounded_rectangle((cx0, cy0, cx0 + 20, cy0 + 16), 3, fill=WOOD_LIT, outline=GOLD, width=1)
            d.line((cx0, cy0 + 6, cx0 + 20, cy0 + 6), fill=GOLD, width=1)
        text(d, ((box[0] + box[2]) // 2, box[3] + 16), label, T_SMALL, CREAM, "mm")
        text(d, ((box[0] + box[2]) // 2, box[3] + 40), have, T_SMALL, CREAM if ok else BAD, "mm")
    q = L["craft.qty"]
    text(d, (q[0], (q[1] + q[3]) // 2), "Make", T_BODY, CREAM, "lm")
    button(d, (q[0] + 70, q[1], q[0] + 118, q[3]), "–", T_BUTTON)
    d.rounded_rectangle((q[0] + 126, q[1], q[0] + 206, q[3]), 5, fill=SLOT_BG, outline=GOLD_DIM, width=1)
    d.text((q[0] + 166, (q[1] + q[3]) // 2), "1", font=font(T_BUTTON), fill=CREAM, anchor="mm")
    button(d, (q[0] + 214, q[1], q[0] + 262, q[3]), "+", T_BUTTON)
    button(d, (q[0] + 274, q[1], q[2], q[3]), "Most", T_BODY)
    text(d, (q[0], q[3] + 24), "Short 1 twine: Craft makes it first from fibre.", T_SMALL, BAD, "lm")
    qu = L["craft.queue"]
    rule(d, qu[0], qu[2], qu[1] - 8)
    text(d, (qu[0], (qu[1] + qu[3]) // 2), "Making", T_SMALL, CREAM, "lm")
    for i, icon in enumerate(["twine", "twine"]):
        slot(img, (qu[0] + 80 + i * 66, qu[1], qu[0] + 140 + i * 66, qu[3]), icon=icon)
    d = ImageDraw.Draw(img)
    b = L["craft.button"]
    button(d, b, "Craft", T_BUTTON, accent=True)
    d.arc((b[0] + 16, b[1] + 12, b[0] + 56, b[1] + 52), -90, 150, fill=GOLD_BRIGHT, width=5)


def draw_chest(img):
    d = ImageDraw.Draw(img)
    panel(img, CRAFT)
    t = L["chest.title"]
    text(d, (t[0] + 30, (t[1] + t[3]) // 2), "Woven chest", T_TITLE, HEADING, "lm")
    for i, (nm, sel) in enumerate([("Chest", True), ("Craft", False)]):
        box = (t[2] - 270 + i * 122, t[1] + 6, t[2] - 152 + i * 122, t[3] - 6)
        d.rounded_rectangle(box, 5, fill=WOOD_LIT if sel else WOOD, outline=GOLD_BRIGHT if sel else GOLD_DIM, width=2 if sel else 1)
        d.text(((box[0] + box[2]) // 2, (box[1] + box[3]) // 2), nm, font=font(T_HEAD), fill=HEADING if sel else CREAM, anchor="mm")
    bar = L["chest.bar"]
    d.rounded_rectangle((bar[0] + 2, bar[1] + 12, bar[0] + 26, bar[1] + 36), 4, fill=SLOT_BG, outline=GOLD_DIM, width=1)
    text(d, (bar[0] + 36, (bar[1] + bar[3]) // 2), "Keep out of crafting", T_BODY, CREAM, "lm")
    button(d, (bar[2] - 312, bar[1], bar[2] - 162, bar[3]), "Take all", T_BODY)
    button(d, (bar[2] - 150, bar[1], bar[2], bar[3]), "Store all", T_BODY)
    for n, box in enumerate(grid_boxes(L["chest.grid"], 6, 5, SLOT, SLOT_GAP)):
        it = CHEST_ITEMS[n]
        slot(img, box, icon=it[0] if it else None, count=it[1] if it else None)
    d = ImageDraw.Draw(img)
    tl = L["chest.tools"]
    button(d, (tl[0], tl[1], tl[0] + 200, tl[3]), "Sort both", T_BODY)
    button(d, (tl[0] + 212, tl[1], tl[0] + 472, tl[3]), "Stack into my chests", T_BODY)
    text(d, (tl[0], tl[3] + 30), "Shift-click or drag moves a stack between the pack and the chest.", T_SMALL, CREAM, "lm")


def measured(img):
    d = ImageDraw.Draw(img)
    for box in [PACK, YOU, CRAFT]:
        d.rectangle(box, outline="#FF4FD8", width=2)
        d.text((box[0] + 6, box[3] + 2), "%d x %d" % (box[2] - box[0], box[3] - box[1]), font=font(("EBGaramond-SemiBold.ttf", 20)), fill="#FF4FD8")
    for key, box in L.items():
        if key.startswith("chest."):
            continue
        d.rectangle(box, outline="#4FE3FF", width=1)
        d.text((box[0] + 3, box[1] + 1), "%s %dx%d" % (key, box[2] - box[0], box[3] - box[1]), font=font(("EBGaramond-SemiBold.ttf", 18)), fill="#4FE3FF")


def scene(path):
    img = Image.new("RGBA", (W, H), "#2B2F2A")
    if path and os.path.exists(path):
        img = Image.open(path).convert("RGBA").resize((W, H), Image.LANCZOS)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--icons", default="")
    ap.add_argument("--scene", default="")
    ap.add_argument("--all", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    load_icons(a.icons, wanted_icons())

    craft = scene(a.scene)
    draw_pack(craft)
    draw_you(craft)
    draw_craft(craft)
    craft.convert("RGB").save(os.path.join(a.out, "inventory_redesign_1920.png"), optimize=True)

    if a.all:
        chest = scene(a.scene)
        draw_pack(chest)
        draw_you(chest)
        draw_chest(chest)
        chest.convert("RGB").save(os.path.join(a.out, "inventory_redesign_chest_1920.png"), optimize=True)
        m = craft.copy()
        measured(m)
        m.convert("RGB").save(os.path.join(a.out, "inventory_redesign_measured_1920.png"), optimize=True)


if __name__ == "__main__":
    main()
