"""Writes data/items/looks.json (stage-one basic looks, src/client/basic_look.gd) from rules on item ids and kinds.

Run: python3 tools/gen_looks.py. Items with their own model are left out on purpose (stick, stone, driftwood, log, species logs, structures).
Tools, kits and containers get a loose-on-the-ground look here (their in-hand models are separate). Edit the rules or add a SPECIAL entry; do not hand-edit looks.json.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
items = json.load(open(os.path.join(ROOT, "data/items/items.json")))
items = items.get("items", items)
gathered = json.load(open(os.path.join(ROOT, "data/items/gathered.json")))
items = dict(items, **{k: v for k, v in gathered.get("items", gathered).items() if k in ("raspberries",)})   # gathered plant yields that have a look of their own

WOOD = {
    "oak": "#8a6a3d", "beech": "#b79869", "birch": "#d9c7a3", "scots_pine": "#c99a5b", "spruce": "#d3b583", "alder": "#b5733f",
    "willow": "#c9b486", "coconut_palm": "#a98a5a", "tropical_hardwood": "#6b3f27", "acacia": "#9a6a3a", "mangrove": "#7a4a2c",
    "rowan": "#c08e63", "wild_apple": "#b47f55", "wild_pear": "#c4936a", "wild_cherry": "#a85a3a", "sweet_chestnut": "#a67b45",
    "walnut": "#5c3b24", "date_palm": "#b39465", "mirrorbark": "#9fa6a8", "wardpine": "#8f7a4f", "hearthwood": "#a0452b",
    "everember": "#c4683a", "witness_tree": "#7b6a56", "balsam_fir": "#cdb78b", "maple": "#d0a46f",
}
SPECIAL = {
    "plant_fibre": ("bundle", "#b7ac6a", 0.8), "twine": ("coil", "#b8a46a", 0.8), "rope": ("coil", "#a98f52", 1.0),
    "bark": ("bark", "#5a4330", 1.0), "leaves": ("leaves", "#5a8a3a", 1.0), "seed_bundle": ("pouch" if False else "sack", "#a08a52", 0.6),
    "tree_roots": ("bundle", "#6a4a2e", 1.0), "firewood": ("bundle", "#8a5e36", 1.0), "lumber": ("planks", "#b98d57", 1.0),
    "iron_ingot": ("ingot", "#6c6f75", 1.0), "steel_ingot": ("ingot", "#9aa3ad", 1.0),
    "soil": ("pile", "#4a3322", 1.0), "clay": ("pile", "#a0603c", 1.0), "sand": ("pile", "#d6c18b", 1.0), "gravel": ("pile", "#8d8a84", 1.0),
    "hide": ("hide", "#8a6a4a", 1.0), "bone": ("bone", "#b3a98f", 1.0), "sinew": ("bundle", "#d0b898", 0.6), "animal_fat": ("chunk", "#f1ead2", 0.8),
    "feather": ("feather", "#b9b4a8", 1.0), "rotten_food": ("pile", "#4f5a2c", 0.8), "backpack": ("sack", "#7a5a3a", 1.5),
    "poultice": ("bowl", "#0e9488", 0.7), "bandage": ("coil", "#f4f4f4", 0.8), "medicine": ("bottle", "#e01e1e", 0.8),
    "energy_bar": ("loaf", "#3d5afe", 0.6), "herbal_tea": ("bottle", "#b6e61a", 0.8), "magic_tonic": ("bottle", "#9b30ff", 0.8),
    "stomach_tea": ("bottle", "#18d0d0", 0.8), "chamomile_tea": ("bottle", "#ffd800", 0.8), "willow_bark_tea": ("bottle", "#8a4b1e", 0.8),
    "raw_meat": ("meat", "#a8403a", 1.0), "roast_meat": ("meat", "#6a3c24", 1.0), "roast_forage": ("bowl", "#a4de02", 0.9),
    "trout": ("fish", "#8a9a7a", 1.0), "perch": ("fish", "#6f8a4a", 0.9), "carp": ("fish", "#a09060", 1.2), "pike": ("fish", "#5a7a3a", 1.4),
    "roast_fish": ("fish", "#a8703a", 1.0), "smoked_fish": ("fish", "#6e4a2a", 1.0), "herb_fish": ("fish", "#9a7a3a", 1.0),
    "raspberries": ("berries", "#8e0f1c", 1.0),
    "berry_compote": ("bowl", "#e84393", 0.9), "nut_paste": ("bowl", "#e67e22", 0.9), "roast_roots": ("bundle", "#ff9f1c", 0.7),
    "acorn_mash": ("bowl", "#8e44ad", 0.9), "baked_apples": ("fruit", "#ff5a36", 1.0), "mushroom_skewer": ("skewer", "#f5e6ff", 1.0),
    "garlic_meat": ("meat", "#7a4a2a", 1.0), "chestnut_cakes": ("loaf", "#5d3a1a", 0.8), "fruit_leather": ("cloth", "#00a8a8", 0.7),
    "hunters_stew": ("bowl", "#d62828", 1.0), "forager_stew": ("bowl", "#2ecc71", 1.0), "fish_stew": ("bowl", "#2e86de", 1.0),
    "trail_bread": ("loaf", "#e8b96a", 1.0), "hearty_pottage": ("bowl", "#f4d03f", 1.0), "feast_roast": ("meat", "#ff2e63", 1.5),
    "grass_skirt": ("cloth", "#8aa04a", 1.0), "grass_cloak": ("cloth", "#7a9a45", 1.2), "fibre_sandals": ("cloth", "#b8a468", 0.7),
    "hide_cloak": ("cloth", "#7a5a3c", 1.2), "hide_boots": ("cloth", "#6a4a30", 0.8), "hide_hood": ("cloth", "#7a5a3c", 0.8),
    "hide_mittens": ("cloth", "#6a4a30", 0.6), "hide_leggings": ("cloth", "#7a5a3c", 1.0),
    "coin_copper": ("coin", "#b0653a", 1.0), "coin_bronze": ("coin", "#9c7a3a", 1.0), "coin_silver": ("coin", "#c4c8cc", 1.0), "coin_gold": ("coin", "#e0b83a", 1.0),
    "spear": ("shaft", "#b8bcc4", 1.0), "wooden_spear": ("shaft", "#d8b070", 1.0),
}
TOOLS = {
    "stone_axe": ("axe", "#7d7a74", 1.6), "stone_knife": ("knife", "#8a8680", 1.0), "torch": ("torch", "#e08a2a", 1.0),
    "wooden_spade": ("spade", "#8a6a3a", 1.0), "stone_spade": ("spade", "#7d7a74", 1.0), "iron_spade": ("spade", "#6c6f75", 1.0),
    "steel_spade": ("spade", "#9aa3ad", 1.0), "iron_pickaxe": ("pick", "#6c6f75", 1.0), "steel_pickaxe": ("pick", "#9aa3ad", 1.0),
    # Medium and large spades: the same shape, a longer shaft and a wider blade (size 1.25 and 1.5 of the small one).
    "wooden_spade_medium": ("spade", "#8a6a3a", 1.25), "wooden_spade_large": ("spade", "#8a6a3a", 1.5),
    "stone_spade_medium": ("spade", "#7d7a74", 1.25), "stone_spade_large": ("spade", "#7d7a74", 1.5),
    "iron_spade_medium": ("spade", "#6c6f75", 1.25), "iron_spade_large": ("spade", "#6c6f75", 1.5),
    "steel_spade_medium": ("spade", "#9aa3ad", 1.25), "steel_spade_large": ("spade", "#9aa3ad", 1.5),
    "wooden_hoe": ("hoe", "#8a6a3a", 1.2), "stone_hoe": ("hoe", "#7d7a74", 1.2), "iron_hoe": ("hoe", "#6c6f75", 1.2), "steel_hoe": ("hoe", "#9aa3ad", 1.2),
    "sewing_needle": ("needle", "#c8c8cc", 1.2), "fishing_rod": ("rod", "#9a9a9e", 1.0),
    "wooden_bowl": ("bowl", "#9a6b38", 1.3), "clay_pot": ("pot", "#ff7f11", 1.0), "bucket": ("bucket", "#b88a50", 1.0),
    "waterskin": ("skin", "#ff4fa3", 1.0),
    "campfire_kit": ("kit", "#6a4a2a", 1.0), "lean_to_kit": ("kit", "#6a8a3a", 1.0), "chest_kit": ("kit", "#9a7a45", 1.0),
    "plank_chest_kit": ("kit", "#a07a45", 1.0), "workbench_kit": ("kit", "#8a6a3a", 1.0),
    "tool_rack_kit": ("kit", "#7a5a35", 1.0), "vice_kit": ("kit", "#7a5a35", 1.0), "log_workbench_kit": ("kit", "#6a4a2a", 1.0),
    "stone_forge_kit": ("kit", "#7d7a74", 1.0), "blacksmithy_kit": ("kit", "#6c6f75", 1.0), "large_forge_kit": ("kit", "#5c5f65", 1.0),
    "master_forge_kit": ("kit", "#44474d", 1.0), "wall_section_kit": ("kit", "#9a7a45", 1.2), "floor_section_kit": ("kit", "#a98350", 1.2),
    "roof_section_kit": ("kit", "#6a4a2a", 1.2), "foundation_section_kit": ("kit", "#7d7a74", 1.2), "doorway_section_kit": ("kit", "#8a6a3a", 1.2),
    "window_section_kit": ("kit", "#8a6a3a", 1.2),
}
SPECIAL.update(TOOLS)
# Dave 2026-10-22: look at what the real things look like. Soups and stews sit in the one shared wooden bowl with their food visible in it.
CARROT, GREEN, POTATO, MUSHROOM, MEAT = "#f07f13", "#4f9a2c", "#f2e3b5", "#a98467", "#8c4a2f"
SPECIAL.update({
    "plant_fibre": ("fibre", "#c9bb7a", 1.0),
    "roast_forage": ("stew", "#b5793a", 1.4, [CARROT, GREEN, POTATO, MUSHROOM, "#d8352a"]),
    "hunters_stew": ("stew", "#6b3a1e", 1.4, [MEAT, MEAT, CARROT, POTATO]),
    "forager_stew": ("stew", "#7a9a3a", 1.4, ["#2f7a2a", "#e8dcb0", MUSHROOM, "#2f7a2a"]),
    "fish_stew": ("stew", "#e8c870", 1.4, ["#f4b5a0", "#f4b5a0", "#3f9a3a", POTATO]),
    "hearty_pottage": ("stew", "#d9a640", 1.4, ["#7a5a2a", "#f0e0a0", "#7a5a2a"]),
    "berry_compote": ("stew", "#9a1f3f", 1.4, ["#4a1030", "#c0204a", "#4a1030"]),
    "acorn_mash": ("mound", "#8a6a3a", 1.4, ["#6a4a22", "#a98a55"]),
    "nut_paste": ("mound", "#b08a55", 1.4, ["#6a4a22", "#d8b27a"]),
    "poultice": ("mound", "#4f7a3a", 1.4, ["#2f6a2a", "#7a9a3a"]),
    "energy_bar": ("bar", "#c9a15b", 1.0, ["#6b4423", "#4a1f4a", "#e9e2c8", "#c0392b", "#f4d03f"]),
    "roast_meat": ("joint", "#6e3a1c", 0.9),
    "garlic_meat": ("joint", "#6a3c20", 0.9),
    "feast_roast": ("joint", "#62301a", 1.5),
    "backpack": ("backpack", "#8a6a4a", 1.4),
    "wooden_bowl": ("bowl", "#9a6b38", 1.3),
})
SPECIAL.update({
    "cut_stone_block": ("block", "#8a8780", 1.5),
    "brick": ("brick", "#a8452e", 1.4),
    "mortar": ("pile", "#a89c85", 1.0),
})
SKIP = {"stone", "stick", "driftwood", "log"}

out = {}
for item_id, entry in items.items():
    kind = entry.get("kind", "")
    if item_id in SKIP or item_id.startswith("log_") or kind == "structure":
        continue
    bits = None
    if item_id in SPECIAL:
        shape, color, size, *rest = SPECIAL[item_id]
        bits = rest[0] if rest else None
    elif item_id.startswith("lumber_") or item_id.startswith("beam_"):
        species = item_id.split("_", 1)[1]
        shape, color, size = ("planks" if item_id.startswith("lumber_") else "beams"), WOOD.get(species, "#a07a4a"), 1.0
    elif kind in ("material", "food", "medicine", "clothing", "gear", "coin", "weapon"):
        shape, color, size = "chunk", "#8a8a8a", 1.0
        print("no rule for", item_id, kind)
    else:
        continue
    out[item_id] = {"shape": shape, "color": color, "size": size}
    if bits:
        out[item_id]["bits"] = bits

doc = {"_about": "Stage-one basic looks, written by tools/gen_looks.py (src/client/basic_look.gd draws them). Client only: editing needs no server restart. Remove an entry when an item gets a real model.", "items": out}
with open(os.path.join(ROOT, "data/items/looks.json"), "w") as f:
    json.dump(doc, f, indent=1)
print(len(out), "looks")
