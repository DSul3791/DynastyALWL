"""Cuts Dave's crop pictures (19 Nov 2026) into the game's crop art: the growing plants' cards in assets/crops/ (src/client/crop_look.gd draws
them) and the picked vegetables' item icons in assets/ui/item_icons/ (128 x 128, as tools/import_item_icons.py expects; it keeps NAMES as painted).

An art tool, not part of the game build, kept so the art can be cut again from the same pictures (the pictures live in the project Library,
crop-pictures/). Needs Pillow, numpy and scipy; `grains` also rembg (`pip install "rembg[cpu]" scipy`), which downloads its isnet-general-use
model on first use.

  python3 tools/cut_crop_pictures.py grains <wheat, barley, oats, rye picture> assets/crops      # photo background, name plaques below
  python3 tools/cut_crop_pictures.py vegetables <ten growing vegetables picture> assets/crops    # white background, each on a soil mound
  python3 tools/cut_crop_pictures.py produce <ten picked vegetables picture> assets/ui/item_icons # white background
New icons also need their .import file: python3 tools/import_item_icons.py --imports-only
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

GRAIN_SPANS = {'wheat': (0, 458), 'barley': (458, 888), 'oats': (888, 1314), 'rye': (1314, 1774)}   # in the 1774 x 887 picture; rows below 760 are name plaques
GRAIN_SCRAPS = {'barley': [(265, 690, 430, 760)]}   # a clod of soil the cut-out kept
NAMES = ('carrot', 'potato', 'turnip', 'cabbage', 'onion', 'peas', 'beet', 'radish', 'lettuce', 'parsnip')   # the item icons `produce` writes
PRODUCE_SPANS = {'carrot': (0, 215), 'potato': (205, 440), 'turnip': (430, 620), 'cabbage': (590, 850), 'onion': (810, 1000), 'peas': (990, 1195),
                 'beet': (1150, 1400), 'radish': (1385, 1575), 'lettuce': (1555, 1825), 'parsnip': (1790, 2000)}   # at 2000 px wide; the picture is 2172
ICON_PX = 128
ICON_FILL = 108                     # the vegetable's longer side, as the painted icons fill about 80 %
OUTLINE = (20, 12, 8)               # the icon rig's 2 px dark outline (tools/icon_bake.gd)
VEG_SPANS = {'carrot': (0, 200), 'potato': (185, 410), 'turnip': (395, 598), 'cabbage': (570, 852), 'onion': (785, 985), 'peas': (970, 1170),
             'beet': (1160, 1380), 'radish': (1355, 1585), 'lettuce': (1565, 1815), 'parsnip': (1780, 2000)}   # at 2000 px wide; the picture is 2172


def grains(src, dst):
    from rembg import remove, new_session
    session = new_session('isnet-general-use')
    picture = Image.open(src).convert('RGB')

    for name, (x0, x1) in GRAIN_SPANS.items():
        a = np.array(remove(picture.crop((x0, 0, x1, 760)), session=session).convert('RGBA')).astype(np.float32)
        raw = a[..., 3].copy()

        for sx0, sy0, sx1, sy1 in GRAIN_SCRAPS.get(name, []):
            raw[sy0:sy1, sx0:sx1] = 0

        edge = raw < 235   # soft pixels carry some sky: blue no higher than the red-green mean
        a[..., 2] = np.where(edge, np.minimum(a[..., 2], (a[..., 0] + a[..., 1]) * 0.5), a[..., 2])
        a[..., 3] = np.where(raw >= 128, 255, 0)   # a hard edge: the cards are drawn alpha-scissor
        out = Image.fromarray(np.uint8(np.clip(a, 0, 255)))
        box = out.getchannel('A').getbbox()
        out = out.crop((max(box[0] - 2, 0), max(box[1] - 2, 0), min(box[2] + 2, out.width), box[3]))
        out = out.resize((round(out.width * 512 / out.height), 512), Image.LANCZOS)
        out.putalpha(out.getchannel('A').point(lambda v: 255 if v >= 128 else 0))
        out.save(f'{dst}/{name}.png', optimize=True)


def vegetables(src, dst):
    from scipy import ndimage
    im = np.array(Image.open(src).convert('RGB')).astype(np.int32)
    k = im.shape[1] / 2000

    for name, (a, b_) in VEG_SPANS.items():
        x0, x1 = int(a * k), min(int(b_ * k), im.shape[1])
        p = im[:, x0:x1]
        r, g, b = p[..., 0], p[..., 1], p[..., 2]
        ink = (np.minimum(np.minimum(r, g), b) < 235) | (np.abs(r - g) + np.abs(g - b) > 24)
        soil = ink & (r < 130) & (g <= r + 4) & (b <= g + 4) & (r - g < 35)   # dark brown earth (not the purple turnip or red beet stems)
        top = int(np.nonzero(soil.sum(axis=1) > 40)[0].min())   # the plant stops where its mound starts
        ink[top:] = False
        lab, n = ndimage.label(ink, structure=np.ones((3, 3)))
        sizes = ndimage.sum(ink, lab, range(1, n + 1))
        keep = ndimage.binary_dilation(lab == (np.argmax(sizes) + 1), iterations=1) & ink   # the plant, not a neighbour's leaf tip
        keep = ndimage.binary_erosion(keep, iterations=1)   # off with the white fringe
        ys, xs = np.nonzero(keep)
        rgba = np.dstack([p, np.where(keep, 255, 0)]).astype(np.uint8)[ys.min():top, xs.min():xs.max() + 1]
        out = Image.fromarray(rgba, 'RGBA')
        out.crop(out.getchannel('A').getbbox()).save(f'{dst}/{name}.png', optimize=True)


def produce(src, dst):
    from scipy import ndimage
    im = np.array(Image.open(src).convert('RGB')).astype(np.int32)
    k = im.shape[1] / 2000

    for name, (a, b_) in PRODUCE_SPANS.items():
        x0, x1 = int(a * k), min(int(b_ * k), im.shape[1])
        p = im[:, x0:x1]
        sat = np.max(p, -1) - np.min(p, -1)
        ink = ((np.min(p, -1) < 150) | (sat > 30)) & ~((np.mean(p, -1) > 185) & (sat < 60))   # coloured or dark: not the white ground or its pale shadow
        ink = ndimage.binary_fill_holes(ndimage.binary_opening(ink, iterations=1))   # fill the shine on an onion or turnip
        lab, n = ndimage.label(ink, structure=np.ones((3, 3)))
        sizes = ndimage.sum(ink, lab, range(1, n + 1))
        centres = ndimage.center_of_mass(ink, lab, range(1, n + 1))
        w = x1 - x0
        keep = np.isin(lab, [i + 1 for i in range(n) if sizes[i] > 40 and 0.08 * w < centres[i][1] < 0.92 * w])   # every piece of this one, not a neighbour's
        keep = ndimage.binary_erosion(keep, iterations=1)
        ys, xs = np.nonzero(keep)
        cut = Image.fromarray(np.dstack([p, np.where(keep, 255, 0)]).astype(np.uint8)[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 'RGBA')
        scale = ICON_FILL / max(cut.width, cut.height)
        cut = cut.resize((max(round(cut.width * scale), 1), max(round(cut.height * scale), 1)), Image.LANCZOS)
        icon = Image.new('RGBA', (ICON_PX, ICON_PX), OUTLINE + (0,))
        at = ((ICON_PX - cut.width) // 2, (ICON_PX - cut.height) // 2)
        shape = Image.new('L', (ICON_PX, ICON_PX), 0)
        shape.paste(cut.getchannel('A'), at)
        icon.putalpha(shape.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(0.6)))   # the outline, 2 px round the silhouette
        icon.alpha_composite(cut, at)
        icon.save(f'{dst}/{name}.png', optimize=True)


if __name__ == '__main__':
    {'grains': grains, 'vegetables': vegetables, 'produce': produce}[sys.argv[1]](sys.argv[2], sys.argv[3])
