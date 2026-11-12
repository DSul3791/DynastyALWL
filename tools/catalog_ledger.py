#!/usr/bin/env python3
"""Mission 001 implementation ledger for the approved master items catalog (Draft 18, commit 0707384).

  python3 -I tools/catalog_ledger.py --init    # write docs/design/catalog_ledger.json once (refuses to overwrite)
  python3 -I tools/catalog_ledger.py --check   # verify the ledger against the catalog totals and data/items/items.json

The ledger is the one machine-readable record of every catalog entry's implementation state. After --init it is
edited by hand (or by small scripts) as work lands; --check keeps it honest. Existing rows come from Appendix A of
docs/design/DYNASTY_MASTER_ITEMS.md (itself generated from items.json at 7f8aabf4); new rows are listed below by
catalog section, in catalog order, with names exactly as the catalog writes them (house-style renames happen when the
row is created, decision 71).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "docs/design/DYNASTY_MASTER_ITEMS.md"
ITEMS = ROOT / "data/items/items.json"
LEDGER = ROOT / "docs/design/catalog_ledger.json"

STATES = ["NOT STARTED", "IN DEVELOPMENT", "IMPLEMENTED - UNVERIFIED", "TESTED - ACCEPTED",
          "RETIRED - MIGRATION VERIFIED", "FUTURE-GATED", "BLOCKED",
          # Two baseline states for rows the catalog does not change, so every one of the 889 rows is accounted for:
          "NO CHANGE",           # catalog KEEP: covered only by regression checks
          "RETIRED BEFORE CATALOG"]  # already retired before Draft 18, kept for its number only

# Catalog section -> implementation phase (CATALOG_IMPLEMENTATION_PLAN.md). 11 is outside Mission 001.
SECTION_PHASE = {"3.1": "2c", "3.2": "2a", "3.3": "2b", "3.4": "2b", "3.5": "3", "3.6": "4b", "3.7": "4b", "3.8": "4b",
                 "3.9": "5", "3.10": "11", "3.11": "10", "3.12": "6", "3.13": "9", "3.14": "6", "3.15": "8", "3.16": "7"}

# Existing FUTURE rows: Steel ingot goes live with the Blast Furnace (s3.3 "Goes live: steel (recipe 193)").
# Q1 (resolved by the mission lead under Dave's 12 Nov 05:42Z autonomy direction; STATE.md): the other FUTURE rows whose
# station and materials go live in Mission 001 are switched on in that phase, as plan rule 3 does for new rows.
ACTIVATE = {"steel_ingot": "2b", "steel_pickaxe": "2c", "steel_spade": "2c", "steel_hoe": "2c", "steel_hammer": "2c",
            "steel_chisel": "2c", "bronze_sword": "4b", "bronze_mace": "4b", "bronze_shield": "4b", "iron_sword": "4b",
            "iron_mace": "4b", "iron_shield": "4b", "steel_sword": "4b", "steel_mace": "4b", "steel_shield": "4b",
            "bronze_helm": "4b", "iron_helm": "4b", "mail_shirt": "4b", "steel_helm": "4b", "plate_cuirass": "4b",
            "bronze_scale_shirt": "4b", "copper_pot": "6", "fish_soup": "6", "meatballs": "6"}

# (section, kind, names, extra) -- kind ADD or FUTURE (a new row that lands inactive). extra: phase override / deps / note.
NEW_ROWS = [
    ("3.1", "ADD", ["Iron - Axe", "Steel - Axe", "Iron - Knife", "Steel - Knife", "Steel - Saw", "Bronze - Sickle",
                    "Iron - Sickle", "Steel - Sickle", "Bronze - Scythe", "Steel - Scythe"], {}),
    ("3.1", "ADD", ["Grindstone"], {}),
    ("3.2", "ADD", ["Hardwood board"], {}),
    ("3.3", "ADD", ["Smelter"], {}),
    ("3.3", "ADD", ["Bellows", "Quenching Trough"], {"note": "Smithy add-ons, not stations"}),
    ("3.4", "ADD", ["Leatherworking Table", "Tailor's Table", "Thread"], {}),
    ("3.5", "ADD", ["Crude - Chest", "Fine - Chest", "Crude - Chair", "Ornate - Chair", "Crude - Table",
                    "Ornate - Table"], {}),
    ("3.6", "ADD", ["Iron - Shortsword", "Steel - Shortsword", "Iron - Greatsword", "Steel - Greatsword",
                    "Steel - Rapier", "Steel - Scimitar", "Iron - Battleaxe", "Steel - Battleaxe", "Iron - Greataxe",
                    "Steel - Greataxe", "Iron - Warhammer", "Steel - Warhammer", "Steel - Maul", "Quarterstaff",
                    "Bronze - Spear", "Iron - Spear", "Steel - Spear", "Iron - Pike", "Iron - Halberd",
                    "Steel - Halberd", "Iron - Trident", "Light crossbow", "Heavy crossbow", "Iron - Buckler",
                    "Bronze - Arrow", "Iron - Arrow", "Steel - Arrow", "Wooden bolt", "Iron bolt"], {}),
    ("3.6", "FUTURE", ["Steel bolt", "Iron - Lance"], {}),
    ("3.7", "ADD", ["Iron - Brigandine", "Iron - Breastplate", "Iron - Mail hauberk", "Steel - Half plate",
                    "Steel - Plate harness", "Iron - Mail coif", "Iron - Gauntlets", "Steel - Gauntlets",
                    "Bronze - Greaves", "Iron - Mail chausses", "Iron - Greaves", "Steel - Greaves",
                    "Iron - Sabatons", "Steel - Sabatons"], {}),
    ("3.8", "ADD", ["Linen - Trousers", "Linen - Skirt", "Linen - Dress", "Wool - Dress", "Wool - Cloak",
                    "Wool - Coat", "Wool - Robe", "Oilcloth - Cloak", "Linen - Apron", "Leather - Apron", "Tabard",
                    "Linen - Headwrap", "Leather - Broad-brim hat", "Fur - Mittens", "Leather - Shoes",
                    "Wool - Socks", "Wool - Scarf"], {}),
    ("3.9", "ADD", ["Fibre - Shoulder bag", "Wicker - Pack basket", "Leather - Satchel", "Belt pouch", "Tool roll",
                    "Traveller's Rucksack", "Wooden - Pack frame", "Weapon scabbard", "Utility bandolier"], {}),
    ("3.10", "ADD", ["Rope Halter", "Leather Bridle", "Riding Saddle", "Traveller's Saddle", "War Saddle",
                     "Pack Saddle", "Leather Saddlebags", "Wicker Panniers", "Cargo Lashings", "Light Draft Harness",
                     "Heavy Horse Collar Harness", "Double Heavy Draft Harness", "Double Ox Yoke",
                     "Iron Horseshoes (Set)", "Padded Horse Blanket", "Feedbag", "Grooming Kit", "Padded Barding",
                     "Iron Mail Barding", "Steel Plate Barding"], {"gated": "animal keeping (phase 11, [D17])"}),
    ("3.10", "FUTURE", ["Riding - Boots"], {"gated": "mounted gear (phase 11)"}),
    ("3.11", "ADD", ["Handcart", "Wooden Cart Wheel", "Axle Assembly"], {}),
    ("3.11", "ADD", ["Light Cargo Cart", "Passenger Gig", "Cargo Sled", "Farm Wagon", "Timber Flatbed Wagon",
                     "Covered Merchant Wagon", "Traveller's Wagon", "Passenger Carriage", "Passenger Sleigh"],
     {"phase": "11", "gated": "animal draft (phase 11, [D17]: only the Handcart before)"}),
    ("3.11", "ADD", ["Reinforced Wagon Wheel"],
     {"phase": "11", "gated": "serves only the animal wagons and carriages (coordinator ENGINEERING call, M001)"}),
    ("3.12", "ADD", ["Food Preparation Table", "Clay Griddle", "Campfire Roasting Spit", "Iron Grill Grate",
                     "Iron Frying Pan", "Iron Cauldron", "Fireplace Cooking Crane"], {}),
    ("3.12", "ADD", ["Unbaked Flatbread", "Unbaked Rye Flatbread", "Unbaked Garlic Flatbread", "Unbaked Honey Loaf",
                     "Unbaked Trail Bread", "Unbaked Oatcakes", "Unbaked Chestnut Cakes", "Unbaked Apple Pie",
                     "Unbaked Fish Pie", "Unbaked Venison Pie", "Uncooked Sausages",
                     "Uncooked Meat Skewers", "Uncooked Mushroom Skewers", "Uncooked Crab Cakes",
                     "Banana Fritter Batter"], {}),
    ("3.12", "ADD", ["Uncooked Meatballs"], {"note": "goes live together with Meatballs #837 (s3.12 DELEGATED)"}),
    ("3.13", "ADD", ["Large Wooden Chest", "Wardrobe", "Dresser", "Bookcase", "Apothecary Cabinet",
                     "Bottle & Jar Rack", "Tool Cabinet", "Open Storage Bin", "Firewood Rack", "Log Rack",
                     "Lumber Rack", "Mason's Pallet", "Ore & Metal Rack", "Storage Sign / Ledger"], {}),
    ("3.13", "ADD", ["Warehouse Crate", "Warehouse Desk"], {"note": "rows and locks in phase 9; loaded-crate movement in phase 10"}),
    ("3.14", "ADD", ["Smoked Meat", "Dried Mushrooms"], {}),
    ("3.15", "ADD", ["Seafood Platter", "Roast Platter", "Mixed Grill Platter", "Charcuterie Board",
                     "Harvest Platter", "Tavern Supper Board", "Breakfast Platter", "Dessert Platter",
                     "Serving Platter"], {}),
    ("3.15", "FUTURE", ["Ploughman's Board"], {"gated": "dairy (Cheese #418) and Pickled Vegetables #834 are FUTURE"}),
]

# Headline totals of Draft 18 (master catalog header and Appendix A).
EXPECT = {"ADD": 176, "NEW FUTURE": 4, "KEEP": 499, "UPDATE": 61, "RETIRE": 23, "FUTURE": 53, "RETIRED": 253}
EXPECT_ADD_BY_SECTION = {"3.1": 11, "3.2": 1, "3.3": 3, "3.4": 3, "3.5": 6, "3.6": 29, "3.7": 14, "3.8": 17,
                         "3.9": 9, "3.10": 20, "3.11": 13, "3.12": 23, "3.13": 16, "3.14": 2, "3.15": 9}


def appendix_rows(text: str) -> list:
    rows, cat = [], None
    body = text.split("## Appendix A.", 1)[1]
    for line in body.splitlines():
        m = re.match(r"### A\.(\w+)", line)
        if m:
            cat = m.group(1)
            continue
        m = re.match(r"\| (\d+) \| `([^`]+)` \| ([^|]*) \|[^|]*\|[^|]*\| (\w+) \| (.*) \|$", line)
        if m and cat:
            rows.append({"number": int(m.group(1)), "id": m.group(2), "name": m.group(3).strip(), "category": cat,
                         "catalog": m.group(4), "note": m.group(5).strip()})
    return rows


def section_texts(text: str) -> dict:
    out = {}
    for m in re.finditer(r"^### (3\.\d+) .*?(?=^### |^## 4\.)", text, re.S | re.M):
        out[m.group(1)] = m.group(0)
    return out


# Rows the s3 tables name only by number or in a family line (checked by hand against s3.1, s3.2 and s3.5).
SECTION_BY_HAND = {"bronze_chisel": "3.1", "plank_chest": "3.5", "chair": "3.5", "canopy_bed": "3.5",
                   "iron_bench": "3.5", "iron_chair": "3.5", "iron_table": "3.5", "wooden_shelf": "3.5",
                   "wooden_cupboard": "3.5", "wooden_barrel": "3.5", "weapon_rack": "3.5", "armour_stand": "3.5",
                   "iron_chest": "3.5"}


def phase_of_existing(row: dict, sections: dict):
    if row["id"] in SECTION_BY_HAND:
        return SECTION_BY_HAND[row["id"]], SECTION_PHASE[SECTION_BY_HAND[row["id"]]]
    if re.match(r"(lumber|beam)_", row["id"]):   # s3.2 "101-174 (16 rows) lumber_oak ... beam_walnut"
        return "3.2", "2a"
    # The first s3 section that names the row's id (as a word or in backticks) or its number beside its name.
    for sec, body in sections.items():
        if re.search(r"(?<![\w-])" + re.escape(row["id"]) + r"(?![\w-])", body):
            return sec, SECTION_PHASE[sec]
    return None, None


def build() -> dict:
    text = MASTER.read_text(encoding="utf-8")
    sections = section_texts(text)
    entries = []
    for row in appendix_rows(text):
        sec, phase = phase_of_existing(row, sections)
        state = {"KEEP": "NO CHANGE", "RETIRED": "RETIRED BEFORE CATALOG", "FUTURE": "FUTURE-GATED"}.get(row["catalog"], "NOT STARTED")
        note = ""
        live_phase = phase if row["catalog"] in ("UPDATE", "RETIRE") else None
        if row["id"] in ACTIVATE:
            live_phase, state = ACTIVATE[row["id"]], "NOT STARTED"
            note = {"steel_ingot": "switched on by s3.3 (Blast Furnace steel)",
                    "meatballs": "goes live with Uncooked Meatballs (s3.12 DELEGATED)"}.get(row["id"], "FUTURE row switched on (Q1, STATE.md)")
        entries.append({"key": row["id"], "number": row["number"], "name": row["name"], "category": row["category"],
                        "catalog": row["catalog"], "section": sec, "phase": live_phase,
                        "depends": [], "state": state, "tests": [], "accepted_commit": None, "note": note})
    # Appendix A lists only live rows; the 253 rows retired before the catalog come from items.json.
    listed = {e["key"] for e in entries}
    for iid, r in json.loads(ITEMS.read_text(encoding="utf-8"))["items"].items():
        if iid not in listed and int(r["number"]) < 896:
            entries.append({"key": iid, "number": int(r["number"]), "name": r.get("name", ""), "category": r.get("kind"),
                            "catalog": "RETIRED" if r.get("retired") else "UNLISTED", "section": None, "phase": None,
                            "depends": [], "state": "RETIRED BEFORE CATALOG" if r.get("retired") else "BLOCKED",
                            "tests": [], "accepted_commit": None, "note": ""})
    entries.sort(key=lambda e: e["number"])
    for sec, kind, names, extra in NEW_ROWS:
        phase = extra.get("phase", SECTION_PHASE[sec])
        gated = extra.get("gated")
        for name in names:
            future = kind == "FUTURE" or gated is not None or phase == "11"
            entries.append({"key": "new:" + name, "number": None, "name": name, "category": None,
                            "catalog": "ADD" if kind == "ADD" else "NEW FUTURE", "section": sec,
                            "phase": None if kind == "FUTURE" else phase, "depends": [],
                            "state": "FUTURE-GATED" if future else "NOT STARTED", "tests": [], "accepted_commit": None,
                            "note": "; ".join(x for x in (extra.get("note"), ("gated: " + gated) if gated else None) if x)})
    return {"catalog": "docs/design/DYNASTY_MASTER_ITEMS.md Draft 18 (commit 0707384, approved by Dave 12 Nov 2026, Mission 001)",
            "states": STATES, "entries": entries}


def check(ledger: dict) -> list:
    errors = []
    entries = ledger["entries"]
    count = {}
    for e in entries:
        count[e["catalog"]] = count.get(e["catalog"], 0) + 1
        if e["state"] not in STATES:
            errors.append("%s: unknown state %r" % (e["key"], e["state"]))
        if e["state"] == "TESTED - ACCEPTED" and not e["accepted_commit"]:
            errors.append("%s: accepted with no accepted_commit" % e["key"])
        if e["catalog"] in ("UPDATE", "RETIRE") and e["phase"] is None:
            errors.append("%s (%s): no phase; name its s3 section by hand" % (e["key"], e["catalog"]))
    for k, n in EXPECT.items():
        if count.get(k, 0) != n:
            errors.append("catalog %s: ledger has %d, Draft 18 says %d" % (k, count.get(k, 0), n))
    by_sec = {}
    for e in entries:
        if e["catalog"] == "ADD":
            by_sec[e["section"]] = by_sec.get(e["section"], 0) + 1
    if by_sec != EXPECT_ADD_BY_SECTION:
        errors.append("ADD rows by section %s differ from %s" % (by_sec, EXPECT_ADD_BY_SECTION))
    keys = [e["key"] for e in entries]
    if len(keys) != len(set(keys)):
        errors.append("duplicate keys")
    # Every existing items.json row is in the ledger once, and a new row that has a number must exist in items.json.
    items = json.loads(ITEMS.read_text(encoding="utf-8"))["items"]
    by_number = {int(r["number"]): i for i, r in items.items()}
    old = [e for e in entries if not e["key"].startswith("new:")]
    if sorted(e["number"] for e in old) != sorted(n for n in by_number if n < 896):
        errors.append("existing rows differ from items.json numbers below 896")
    for e in old:
        if by_number.get(e["number"]) != e["key"]:
            errors.append("%s: items.json has number %s as %s" % (e["key"], e["number"], by_number.get(e["number"])))
    for e in entries:
        if e["key"].startswith("new:") and e["number"] is not None and e["number"] not in by_number:
            errors.append("%s: number %s is not in items.json" % (e["key"], e["number"]))
    return errors


def main() -> int:
    if "--init" in sys.argv:
        if LEDGER.exists():
            print("ledger exists; edit it, do not regenerate it")
            return 1
        ledger = build()
        LEDGER.write_text(json.dumps(ledger, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        print("wrote %d entries" % len(ledger["entries"]))
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    errors = check(ledger)
    for e in errors:
        print("FAIL:", e)
    states = {}
    for e in ledger["entries"]:
        states[e["state"]] = states.get(e["state"], 0) + 1
    print("entries %d; states %s" % (len(ledger["entries"]), json.dumps(states)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
