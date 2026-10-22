"""Writes data/items/looks.json (stage-one basic looks, src/client/basic_look.gd) from rules on item ids and kinds.

Run: python3 tools/gen_looks.py. Items with their own model are left out on purpose (stick, stone, driftwood, log, species logs, tools,
placeables, structures). Edit the rules or add a SPECIAL entry; do not hand-edit looks.json.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
items = json.load(open(os.path.join(ROOT, "data/items/items.json")))
items = items.get("items", items)

WOOD = {
    "oak": "#8a6a3d", "beech": "#b79869", "birch": "#d9c7a3", "scots_pine": "#c99a5b", "spruce": "#d3b583", "alder": "#b5733f",
    "willow": "#c9b486", "coconut_palm": "#a98a5a", "tropical_hardwood": "#6b3f27", "acacia": "#9a6a3a", "mangrove": "#7a4a2c",
    "rowan": "#c08e63", "wild_apple": "#b47f55", "wild_pear": "#c4936a", "wild_cherry": "#a85a3a", "sweet_chestnut": "#a67b45",
    "walnut": "#5c3b24", "date_palm": "#b39465", "mirrorbark": "#9fa6a8", "wardpine": "#8f7a4f", "hearthwood": "#a0452b",
    "everember": "#c4683a", "witness_tree": "#7b6a56", "balsam_fir": "#cdb78b", "maple": "#d0a46f",
}
SPECIAL = {
    "plant_fibre": ("bundle", "#b7ac6a", 0.8), "cordage": ("coil", "#b8a46a", 0.8), "rope": ("coil", "#a98f52", 1.0),
    "bark": ("bark", "#5a4330", 1.0), "leaves": ("leaves", "#5a8a3a", 1.0), "seed_bundle": ("pouch" if False else "sack", "#a08a52", 0.6),
    "tree_roots": ("bundle", "#6a4a2e", 1.0), "firewood": ("bundle", "#8a5e36", 1.0), "lumber": ("planks", "#b98d57", 1.0),
    "iron_ingot": ("ingot", "#6c6f75", 1.0), "steel_ingot": ("ingot", "#9aa3ad", 1.0),
    "soil": ("pile", "#4a3322", 1.0), "clay": ("pile", "#a0603c", 1.0), "sand": ("pile", "#d6c18b", 1.0), "gravel": ("pile", "#8d8a84", 1.0),
    "hide": ("hide", "#8a6a4a", 1.0), "bone": ("bone", "#e6e0cf", 1.0), "sinew": ("bundle", "#d0b898", 0.6), "animal_fat": ("chunk", "#f1ead2", 0.8),
    "feather": ("feather", "#b9b4a8", 1.0), "rotten_food": ("pile", "#4f5a2c", 0.8), "backpack": ("sack", "#7a5a3a", 1.5),
    "poultice": ("bowl", "#5f7a3a", 0.7), "bandage": ("coil", "#d8ccaa", 0.8), "medicine": ("bottle", "#7a4b2a", 0.8),
    "energy_bar": ("loaf", "#8a6a3a", 0.6), "herbal_tea": ("bottle", "#6a8a3a", 0.8), "magic_tonic": ("bottle", "#8a5ad0", 0.8),
    "stomach_tea": ("bottle", "#9aa05a", 0.8), "chamomile_tea": ("bottle", "#d8c860", 0.8), "willow_bark_tea": ("bottle", "#a07a4a", 0.8),
    "raw_meat": ("meat", "#a8403a", 1.0), "roast_meat": ("meat", "#6a3c24", 1.0), "roast_forage": ("bowl", "#7a8a4a", 0.9),
    "trout": ("fish", "#8a9a7a", 1.0), "perch": ("fish", "#6f8a4a", 0.9), "carp": ("fish", "#a09060", 1.2), "pike": ("fish", "#5a7a3a", 1.4),
    "roast_fish": ("fish", "#a8703a", 1.0), "smoked_fish": ("fish", "#6e4a2a", 1.0), "herb_fish": ("fish", "#9a7a3a", 1.0),
    "berry_compote": ("bowl", "#7a2a4a", 0.9), "nut_paste": ("bowl", "#8a6a3a", 0.9), "roast_roots": ("bundle", "#7a5a3a", 0.7),
    "acorn_mash": ("bowl", "#7a6a3a", 0.9), "baked_apples": ("fruit", "#b0602a", 1.0), "mushroom_skewer": ("skewer", "#c8b890", 1.0),
    "garlic_meat": ("meat", "#7a4a2a", 1.0), "chestnut_cakes": ("loaf", "#a0703a", 0.8), "fruit_leather": ("cloth", "#8a3a4a", 0.7),
    "hunters_stew": ("bowl", "#6a3a22", 1.0), "forager_stew": ("bowl", "#5a6a2a", 1.0), "fish_stew": ("bowl", "#a07a4a", 1.0),
    "trail_bread": ("loaf", "#b08a50", 1.0), "hearty_pottage": ("bowl", "#9a7a3a", 1.0), "feast_roast": ("meat", "#7a3a1e", 1.5),
    "grass_skirt": ("cloth", "#8aa04a", 1.0), "grass_cloak": ("cloth", "#7a9a45", 1.2), "fibre_sandals": ("cloth", "#b8a468", 0.7),
    "hide_cloak": ("cloth", "#7a5a3c", 1.2), "hide_boots": ("cloth", "#6a4a30", 0.8), "hide_hood": ("cloth", "#7a5a3c", 0.8),
    "hide_mittens": ("cloth", "#6a4a30", 0.6), "hide_leggings": ("cloth", "#7a5a3c", 1.0),
    "coin_copper": ("coin", "#b0653a", 1.0), "coin_bronze": ("coin", "#9c7a3a", 1.0), "coin_silver": ("coin", "#c4c8cc", 1.0), "coin_gold": ("coin", "#e0b83a", 1.0),
    "spear": ("shaft", "#8d8d90", 1.0), "wooden_spear": ("shaft", "#6a4a2a", 1.0),
}
SKIP = {"stone", "stick", "driftwood", "log"}

out = {}
for item_id, entry in items.items():
    kind = entry.get("kind", "")
    if item_id in SKIP or item_id.startswith("log_") or kind in ("structure", "placeable", "container"):
        continue
    if item_id in SPECIAL:
        shape, color, size = SPECIAL[item_id]
    elif item_id.startswith("lumber_") or item_id.startswith("beam_"):
        species = item_id.split("_", 1)[1]
        shape, color, size = ("planks" if item_id.startswith("lumber_") else "beams"), WOOD.get(species, "#a07a4a"), 1.0
    elif kind == "tool":
        continue
    elif kind in ("material", "food", "medicine", "clothing", "gear", "coin", "weapon"):
        shape, color, size = "chunk", "#8a8a8a", 1.0
        print("no rule for", item_id, kind)
    else:
        continue
    out[item_id] = {"shape": shape, "color": color, "size": size}

doc = {"_about": "Stage-one basic looks, written by tools/gen_looks.py (src/client/basic_look.gd draws them). Client only: editing needs no server restart. Remove an entry when an item gets a real model.", "items": out}
with open(os.path.join(ROOT, "data/items/looks.json"), "w") as f:
    json.dump(doc, f, indent=1)
print(len(out), "looks")
