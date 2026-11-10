#!/usr/bin/env python3
"""Make an icon of a material version from its sibling's icon by a gradient map (Kathleen, 10 Nov 2026).

The leather clothes (item system C1, #933) are the hide clothes cut in leather: the same shapes, darker, redder and smoother. So each
leather icon is its hide sibling's icon with its shading kept and its colours mapped onto the leather ramp, and the family reads as
one set. Run after the sources are baked or painted.

    python3 tools/recolour_icons.py [--out assets/ui/item_icons] [--only id,id]
"""
import argparse
import os

import numpy as np
from PIL import Image

LEATHER = ((30, 16, 9), (94, 52, 28), (172, 110, 66))   # shadow, middle, light: tanned leather (Leather - Jerkin's warm brown, a little deeper)

RECOLOURS = {
	"leather_trousers": ("hide_trousers", LEATHER),
	"leather_boots": ("hide_boots", LEATHER),
	"leather_gloves": ("hide_gloves", LEATHER),
	"leather_backpack": ("backpack", LEATHER),
	"leather_quiver": ("quiver", LEATHER),
}
NAMES = tuple(RECOLOURS)


def _ramp(ramp, v):
	low, mid, high = ramp
	t = v / 255.0
	a, b, u = (low, mid, t * 2.0) if t < 0.5 else (mid, high, t * 2.0 - 1.0)
	return tuple(int(round(x + (y - x) * u)) for x, y in zip(a, b))


def recolour(source, ramp):
	image = Image.open(source).convert("RGBA")
	grey = image.convert("L")
	lo, hi = grey.getextrema()   # stretch the source's own light range over the whole ramp
	span = max(1, hi - lo)
	table = [_ramp(ramp, max(0, min(255, (v - lo) * 255 // span))) for v in range(256)]
	rgb = np.array(table, dtype=np.uint8)[np.asarray(grey)]
	return Image.fromarray(np.dstack([rgb, np.asarray(image.getchannel("A"))]), "RGBA")


def main():
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui", "item_icons"))
	parser.add_argument("--only", default="")
	args = parser.parse_args()
	only = set(filter(None, args.only.split(",")))

	for name, (source, ramp) in RECOLOURS.items():
		if only and name not in only:
			continue

		path = os.path.join(args.out, name + ".png")
		recolour(os.path.join(args.out, source + ".png"), ramp).save(path)
		print("recoloured", path, "from", source)


if __name__ == "__main__":
	main()
