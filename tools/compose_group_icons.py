#!/usr/bin/env python3
"""Compose the icons of the ingredient groups from their members' icons (Kathleen, 10 Nov 2026).

A group (data/items/wood_species.json ingredient_groups: fish, mushrooms, nuts, berries, fuel, pitch, knife, fruit) is never given itself, but a
recipe that asks for it shows it in its Needs well, so it needs an icon or the well shows the "?" tile. A group's icon is two or
three of its members' own icons fanned from the back left to the front right, each at 70 %, the ones behind a little darker, so it
reads as "any of these" and always matches the members' art. Run after the members are painted or baked.

    python3 tools/compose_group_icons.py [--out assets/ui/item_icons] [--only id,id]
"""
import argparse
import os

from PIL import Image, ImageEnhance

GROUPS = {
	"fish": ("herring", "pike", "trout"),
	"mushrooms": ("morels", "chanterelles", "porcini"),
	"nuts": ("walnuts", "chestnuts", "hazelnuts"),
	"berries": ("cloudberries", "blueberries", "raspberries"),
	"fuel": ("coal", "charcoal"),
	"pitch": ("animal_fat", "resin", "pine_tar"),
	"knife": ("stone_knife", "obsidian_knife", "bronze_knife"),   # any knife (#941)
	"fruit": ("plums", "pear_summer", "apple_summer"),   # any juicy fruit or berry (#940)
	"vegetable": ("cabbage", "beet", "carrot"),   # any root or cabbage-type vegetable (#955)
}
NAMES = tuple(GROUPS)
SIZE = 128
SHARE = 0.7


def compose(folder, members):
	canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
	side = int(SIZE * SHARE)
	room = SIZE - side
	steps = len(members) - 1

	for k, member in enumerate(members):
		icon = Image.open(os.path.join(folder, member + ".png")).convert("RGBA").resize((side, side), Image.LANCZOS)

		if k < steps:   # behind: a little darker, so the front one reads first
			alpha = icon.getchannel("A")
			icon = ImageEnhance.Brightness(icon.convert("RGB")).enhance(0.8 + 0.2 * k / max(steps, 1)).convert("RGBA")
			icon.putalpha(alpha)

		at = int(round(room * k / max(steps, 1)))
		canvas.alpha_composite(icon, (at, at))

	return canvas


def main():
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui", "item_icons"))
	parser.add_argument("--only", default="")
	args = parser.parse_args()
	only = set(filter(None, args.only.split(",")))

	for name, members in GROUPS.items():
		if only and name not in only:
			continue

		path = os.path.join(args.out, name + ".png")
		compose(args.out, members).save(path)
		print("composed", path, "from", ", ".join(members))


if __name__ == "__main__":
	main()
