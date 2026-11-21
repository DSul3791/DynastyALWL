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
QUALITY_PACK = ((24, 12, 6), (78, 42, 22), (150, 92, 54))   # the backpack tiers (Dave 15 Nov 2026): Quality a deeper, darker leather
ADVANCED_PACK = ((18, 14, 12), (66, 50, 40), (132, 112, 96))   # Advanced: dark leather with a cool steel cast from its frame
LAMP_OIL = ((36, 22, 6), (150, 112, 40), (236, 204, 128))
BOG_IRON = ((40, 14, 6), (122, 58, 28), (196, 112, 52))   # Bog iron ore (Dave 19 Nov 2026): the Iron ore lumps in red-brown and rust   # lamp oil (B4): the oil bottle in a deeper amber, as basic_look draws it (#9a7a32)
METEORITE = ((14, 12, 11), (62, 56, 52), (150, 150, 154))   # Iron chunk (Dave 21 Nov 2026): the Iron ore lumps as dark meteorite iron with bright worn metal
HARDWOOD = ((34, 18, 8), (110, 70, 40), (184, 136, 92))   # Hardwood board (Dave 21 Nov 2026): the Plank icon in a darker oak brown

RECOLOURS = {
	"leather_trousers": ("hide_trousers", LEATHER),
	"leather_boots": ("hide_boots", LEATHER),
	"leather_gloves": ("hide_gloves", LEATHER),
	"improved_backpack": ("simple_backpack", LEATHER),
	"quality_backpack": ("simple_backpack", QUALITY_PACK),
	"advanced_backpack": ("simple_backpack", ADVANCED_PACK),
	"leather_quiver": ("quiver", LEATHER),
	"lamp_oil": ("oil", LAMP_OIL),
	"bog_iron_ore": ("iron_ore", BOG_IRON),
	"iron_chunk": ("iron_ore", METEORITE),
	"hardwood_board": ("lumber", HARDWOOD),
}
# A metal tier of a tool that shares its sibling's look (basic_look.gd: the same shape, a different colour) while no bake has drawn it
# (Dave 21 Nov 2026: "how does the copper pickaxe not have an icon"): the sibling's icon with only its metal recoloured. The metal is
# where the sibling and a third tier of the same shape differ (the haft and outline are alike); each channel is scaled by target over
# sibling colour, to the power GAIN so the step from bronze reads at 32 px. A real bake (tools/icon_bake.gd) of the item replaces it.
METAL_TIERS = {
	"copper_pickaxe": ("bronze_pickaxe", "iron_pickaxe", "#b87333", "#b5803a"),
}
GAIN = 2.5
NAMES = tuple(RECOLOURS) + tuple(METAL_TIERS)


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


def metal_tier(source, other, target_hex, source_hex):
	base = np.asarray(Image.open(source).convert("RGBA")).astype(float)
	diff = np.abs(base[..., :3] - np.asarray(Image.open(other).convert("RGBA")).astype(float)[..., :3]).sum(-1)
	weight = np.clip((diff - 10.0) / 30.0, 0.0, 1.0)[..., None]
	ratio = (np.array(_rgb(target_hex)) / np.array(_rgb(source_hex))) ** GAIN
	out = base.copy()
	out[..., :3] = base[..., :3] * (1.0 - weight) + np.clip(base[..., :3] * ratio, 0.0, 255.0) * weight
	return Image.fromarray(out.round().astype(np.uint8), "RGBA")


def _rgb(hex_colour):
	return tuple(int(hex_colour[k:k + 2], 16) for k in (1, 3, 5))


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

	for name, (source, other, target_hex, source_hex) in METAL_TIERS.items():
		if only and name not in only:
			continue

		path = os.path.join(args.out, name + ".png")
		metal_tier(os.path.join(args.out, source + ".png"), os.path.join(args.out, other + ".png"), target_hex, source_hex).save(path)
		print("recoloured the metal of", path, "from", source)


if __name__ == "__main__":
	main()
