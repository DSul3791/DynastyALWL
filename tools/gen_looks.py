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
items = dict(items, **{k: v for k, v in gathered.get("items", gathered).items() if k in ("raspberries", "blackberries", "blueberries", "strawberries", "sloes")})   # gathered plant yields that have a look of their own

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
    "soil": ("clump", "#4a3322", 1.0), "clay": ("clump", "#a0603c", 1.0), "sand": ("grit", "#d6c18b", 1.0), "gravel": ("grit", "#8d8a84", 1.0),
    "hide": ("hide", "#8a6a4a", 1.0), "bone": ("bone", "#b3a98f", 1.0), "sinew": ("bundle", "#d0b898", 0.6), "animal_fat": ("chunk", "#f1ead2", 0.8),
    "feather": ("feather", "#b9b4a8", 1.0), "rotten_food": ("pile", "#4f5a2c", 0.8), "backpack": ("sack", "#7a5a3a", 1.5),
    "poultice": ("bowl", "#0e9488", 0.7), "bandage": ("coil", "#f4f4f4", 0.8), "medicine": ("bottle", "#e01e1e", 0.8),
    "energy_bar": ("loaf", "#3d5afe", 0.6), "herbal_tea": ("bottle", "#b6e61a", 0.8), "magic_tonic": ("bottle", "#9b30ff", 0.8),
    "stomach_tea": ("bottle", "#18d0d0", 0.8), "chamomile_tea": ("bottle", "#ffd800", 0.8), "willow_bark_tea": ("bottle", "#8a4b1e", 0.8),
    "raw_meat": ("meat", "#a8403a", 1.0), "roast_meat": ("meat", "#6a3c24", 1.0), "roast_forage": ("bowl", "#a4de02", 0.9),
    "trout": ("fish", "#8a9a7a", 1.0), "perch": ("fish", "#6f8a4a", 0.9), "carp": ("fish", "#a09060", 1.2), "pike": ("fish", "#5a7a3a", 1.4),
    "roast_fish": ("fish", "#a8703a", 1.0), "smoked_fish": ("fish", "#6e4a2a", 1.0), "herb_fish": ("fish", "#9a7a3a", 1.0),
    "wooden_block": ("block", "#a67c4a", 0.9), "wooden_pin": ("rod", "#a88255", 0.35), "rough_plank": ("planks", "#a8875a", 1.0),
    "fine_board": ("planks", "#d4b57a", 1.0), "nails": ("needle", "#5e6166", 0.5), "hinges": ("ingot", "#4f5359", 0.45),
    "tar": ("pile", "#1c1814", 0.8), "cobblestone": ("chunk", "#8b8982", 0.8), "stone_shingle": ("chunk", "#6d7076", 0.7),
    "raspberries": ("berries", "#8e0f1c", 1.0), "blackberries": ("berries", "#2a1830", 1.0),
    "blueberries": ("round_berries", "#27335c", 1.0), "strawberries": ("berries", "#c8202a", 1.0), "sloes": ("round_berries", "#2a2c46", 1.0),
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


# Goal 1c (Kathleen, 24 Oct): looks for every gathered item. One row per item: (shape, colour, size[, bits]). bits[0] = the second colour (flower centre, mushroom stem).
# Real-world reference per family (art/MODEL_INVENTORY.md): flowers 2-4 cm heads, roots 8-20 cm, nuts 1-4 cm, mushroom caps 4-10 cm, leaves 5-20 cm.
def _rows(shape, size, colours, bits=None):
    return {k: ((shape, c, size, bits) if bits else (shape, c, size)) for k, c in colours.items()}

GATHERED = {}
GATHERED.update(_rows("flower", 1.0, {
    "arnica_flowers": "#f2b01e", "chamomile_flowers": "#f4f1e6", "dandelion_flowers": "#f7d117", "duskmallow_flowers": "#7a4aa8", "elderflowers": "#f1ecd8",
    "feverfew": "#f1efe2", "frostglass_petals": "#bfe6f2", "hawthorn_blossom": "#f7ece8", "honey_flowers": "#f0c24a", "lavender_flowers": "#8f77c4",
    "meadowsweet_flowers": "#f1e8c6", "mournbloom_petals": "#3a2a4a", "nightcrown_blooms": "#3a2e6a", "owlpetals": "#c9b8d8", "rose_petals": "#d4476a",
    "sevenyear_blossoms": "#e9a3c2", "stillwater_petals": "#7ec8d9", "wispbloom_heads": "#a8f0e0", "quenchbell_heads": "#4a7ad0", "gloomthistle_heads": "#6a3a7a",
    "gloaming_star": "#e8e0ff", "brinebells": "#6aa0d8", "st_johns_wort": "#f2d11a", "yarrow": "#f1efe2"}, ["#e0b020"]))
GATHERED.update(_rows("frond", 1.0, {
    "belladonna_leaves": "#4a7a30", "comfrey_leaves": "#4d7a35", "dandelion_leaves": "#5a9a35", "foxglove_leaves": "#4f8a45", "henbane_leaves": "#6b8a45",
    "plantain_leaves": "#4f8f3a", "raspberry_leaves": "#5a8a3a", "sorrel_leaves": "#6aa03a", "sunsilver_leaves": "#c4ccd4", "truthsage_leaves": "#8aa07a",
    "witness_leaves": "#7b8a56", "wild_garlic_leaves": "#3f8a3a", "hushfern_fronds": "#3a7a4a", "tideglass_fronds": "#7ac4c0", "whisperfern_fronds": "#5a8a6a",
    "fiddleheads": "#6a9a3a", "watercress": "#3f8a3a", "greens": "#4f9a30", "herbs": "#6a8a3a", "mint": "#4f9a45", "sage": "#8a9a7a", "marjoram": "#6f8f4a",
    "thyme": "#6a7a4a", "rosemary": "#4a6a3a", "mugwort": "#7a8a6a", "samphire": "#5a9a5a", "everember_needles": "#c4683a"}))
GATHERED.update(_rows("frond", 1.6, {"banana_leaves": "#3f8a2a", "palm_fronds": "#3f8a3a"}))
GATHERED.update(_rows("root", 1.0, {
    "angelica_roots": "#d8c9a0", "burdock_roots": "#6a4a30", "comfrey_roots": "#3a2a20", "dandelion_roots": "#8a6a48", "duskmallow_roots": "#7a5a8a",
    "emberroots": "#d4501e", "heartroots": "#b02a3a", "marrowroots": "#e8dcc0", "valerian_roots": "#9a7a50", "wild_carrot_roots": "#f0e0d0",
    "wolfsbane_roots": "#5a4a3a", "wild_garlic_bulbs": "#efe7d8", "sevenyear_bulbs": "#d8b080"}))
GATHERED.update(_rows("nut", 1.0, {
    "acorns": "#8a6a34", "beechnuts": "#7a5028", "chestnuts": "#6a3a1c", "hazelnuts": "#b8864a", "walnuts": "#8a6a44", "walnut_husks": "#4f7a32"}))
GATHERED["coconuts"] = ("nut", "#5a3c22", 2.2)
GATHERED.update(_rows("round_berries", 1.0, {
    "belladonna_berries": "#1a1020", "cranberries": "#b01c2e", "crowberries": "#15101c", "drakethorn_berries": "#a82a2a", "elderberries": "#2a1a3a",
    "haws": "#b0221e", "juniper_berries": "#3a4a6a", "lingonberries": "#c0202a", "rowan_berries": "#e0481e", "sea_buckthorn_berries": "#f0961e",
    "sleetberries": "#9ac4e0", "sunberries": "#f2c21e", "tidecrown_pearls": "#e8f0f4"}))
GATHERED["cloudberries"] = ("berries", "#f0a030", 1.0)
GATHERED.update({
    "bananas": ("fruit", "#f2d34a", 1.3), "cherries": ("fruit", "#a0102a", 0.6), "crab_apples": ("fruit", "#c8a02e", 0.7), "dates": ("fruit", "#6a3a1e", 0.5),
    "prickly_pears": ("fruit", "#c0402e", 0.9), "wild_pears": ("fruit", "#b8c04a", 0.9), "rose_hips": ("fruit", "#d4381e", 0.5)})
GATHERED.update(_rows("cap", 1.0, {
    "chanterelles": "#e0a028", "cinderfoot_caps": "#8a2a1a", "fly_agaric_caps": "#d02a1e", "lumencap_caps": "#7ad8c0", "mirrorcap_caps": "#c4ccd0",
    "morels": "#8a6a3a", "porcini": "#8a5a34", "puffball": "#f0ead8", "rimecap_caps": "#a8d4e4"}, ["#efe6d0"]))
GATHERED.update(_rows("bark", 1.0, {
    "birch_bark": "#e8dcc0", "hagwillow_bark": "#5a4a3a", "mirrorbark_bark": "#9fa6a8", "tannin_bark": "#6a4a2a", "willow_bark": "#8a7a52", "witness_bark": "#7b6a56"}))
GATHERED.update(_rows("beams", 1.0, {
    "cherry_wood": "#a85a3a", "everember_wood": "#c4683a", "fine_wood": "#b99062", "hard_wood": "#7a5230", "hardwood": "#7a5230", "mirrorbark_wood": "#9fa6a8",
    "palm_wood": "#b39465", "softwood": "#d3b583", "thorny_wood": "#5a3a24", "timber": "#a67c4a", "wardpine_wood": "#8f7a4f", "wood": "#a07a4a"}))
GATHERED.update(_rows("bundle", 1.0, {
    "bedding": "#c9b46a", "fodder": "#b8a85a", "straw": "#d8c070", "thatch": "#c4a860", "kindling": "#a8845a", "poles": "#8a6a3a", "withies": "#9a8a52",
    "hagwillow_withies": "#6a5a3a", "thorny_canes": "#4a3322", "spines": "#6a5a44", "hearthwood_logs": "#a0452b", "reed_stems": "#b8a860", "riverbraid_stems": "#6a9a8a",
    "stormreed_stalks": "#8a8a6a", "tanglewort_vines": "#4f7a3a", "angelica_stems": "#9ab45a", "honeyspindle_pods": "#b8a050", "fibre": "#c9bb7a"}))
GATHERED["kindling"] = ("bundle", "#a8845a", 0.6)
GATHERED.update(_rows("pile", 1.0, {
    "stuffing": "#e8e0d0", "tinder": "#a89878", "gloomthistle_down": "#cfc8d8", "echo_moss": "#6a8a8a", "staunchmoss": "#4f7a3a", "pine_tar": "#2a2018", "potash": "#c8c4b8"}))
GATHERED.update(_rows("chunk", 0.8, {
    "amadou": "#a8825a", "tinder_fungus": "#8a7a5a", "cactus_pads": "#4f8a4a", "burrs": "#7a5a3a", "charcoal_wood": "#2a2826", "resin": "#c98a2a", "gum": "#c9a05a",
    "wardpine_resin": "#7a9a5a"}))
GATHERED.update(_rows("bottle", 0.8, {
    "dye": "#8a2a6a", "oil": "#c9a82a", "water": "#5a9ad4", "pilgrims_cup_water": "#5a9ad4", "lantern_dew": "#a8f0e0", "sap": "#c9a05a", "everember_sap": "#e0602a",
    "honeyspindle_nectar": "#f0c24a"}))
GATHERED.update({"pilgrims_cup_pitchers": ("bottle", "#8aa04a", 1.0), "aloe_gel": ("bowl", "#a8e0a0", 0.8), "food": ("bowl", "#c9a05a", 0.9)})
GATHERED.update(_rows("grit", 0.8, {"seeds": "#c9b57a", "linseed": "#7a4a2a", "henbane_seeds": "#4a3a2a", "stillwater_seeds": "#7ec8d9"}))

GATHERED.update({
    "firewood_soft": ("bundle", "#9a7a4a", 1.0), "wooden_block_soft": ("block", "#b8905a", 0.9), "saw_blade": ("bar", "#8f9296", 1.6), "water_wheel": ("coil", "#7a5a36", 1.4),
    "saw_mill_kit": ("kit", "#8a6a3a", 1.2), "woodworking_table_kit": ("kit", "#7a5430", 1.0), "rock_pile": ("pile", "#7d7a74", 1.8)})
SKIP = {"stone", "stick", "driftwood", "log"}

out = {}
generic = []
ALL = dict(items, **{k: v for k, v in gathered.get("items", gathered).items() if k not in items})
for item_id, entry in ALL.items():
    kind = entry.get("kind", "")
    if item_id in SKIP or item_id.startswith("log_") or kind == "structure":
        continue
    bits = None
    if item_id in SPECIAL or item_id in GATHERED:
        shape, color, size, *rest = SPECIAL.get(item_id) or GATHERED[item_id]
        bits = rest[0] if rest else None
    elif item_id.startswith("lumber_") or item_id.startswith("beam_"):
        species = item_id.split("_", 1)[1]
        shape, color, size = ("planks" if item_id.startswith("lumber_") else "beams"), WOOD.get(species, "#a07a4a"), 1.0
    elif kind in ("material", "food", "medicine", "clothing", "gear", "coin", "weapon"):
        shape, color, size = "chunk", "#8a8a8a", 1.0
        print("GENERIC (no rule):", item_id, kind)
        generic.append(item_id)
    else:
        continue
    out[item_id] = {"shape": shape, "color": color, "size": size}
    if bits:
        out[item_id]["bits"] = bits

doc = {"_about": "Stage-one basic looks, written by tools/gen_looks.py (src/client/basic_look.gd draws them). Client only: editing needs no server restart. Remove an entry when an item gets a real model.", "items": out}
with open(os.path.join(ROOT, "data/items/looks.json"), "w") as f:
    json.dump(doc, f, indent=1)
print(len(out), "looks;", len(generic), "GENERIC remaining")
if generic:
    raise SystemExit("GENERIC ids without a rule: " + ", ".join(generic))
