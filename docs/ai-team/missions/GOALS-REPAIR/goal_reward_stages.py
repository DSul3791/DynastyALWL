# GOALS-REPAIR A-42 (Dave 14 Nov 2026 06:19-06:22Z: "all goals only payout coins"; "+5cp for low level stuff and as you progress the amount
# increases a small simple amount"): the coin reward of every catalog goal from its progression stage. The scale, assumed on Dave's behalf by
# the coordinator: one flat amount per stage, no bonuses and no exceptions:
#   stone  5 copper   (start, stone tools, Crude)
#   bronze 10 copper  (Copper, Bronze, Improved)
#   iron   15 copper  (Iron, Refined, Advanced)
#   steel  20 copper  (Steel, Fortified, Master)
# A goal's stage is the highest metal its target needs, found by the static reach model of r9_reach_with_smelters.py run with the later metals
# withheld: the target reachable with no ingots at all is stone, with copper, tin and bronze ingots is bronze, with iron as well is iron, else steel.
# A goal with no item or structure target (an event) takes the stage in EVENT_STAGES. Static read of the data, not play.
# Usage: python3 docs/ai-team/missions/GOALS-REPAIR/goal_reward_stages.py <repo root> [--write]
# shortcut: a mission tool, not a repo tool; retire it with r9_reach_with_smelters.py.
import csv
import importlib.util
import io
import json
import os
import sys

ROOT = sys.argv[1]
WRITE = "--write" in sys.argv
STAGES = [("stone", 5, {"copper_ingot", "tin_ingot", "bronze_ingot", "iron_ingot", "steel_ingot"}), ("bronze", 10, {"iron_ingot", "steel_ingot"}),
    ("iron", 15, {"steel_ingot"}), ("steel", 20, set())]
COPPER = {name: c for name, c, _ban in STAGES}
# The stage names of the live goal data (data/items/goal_rewards.json, #1121): what each row's `stage` column holds.
STAGE_KEY = {"stone": "start", "bronze": "copper_bronze", "iron": "iron", "steel": "steel"}
# Events with no item or structure to trace: the stage of what the event needs (the tool, station or skill named).
EVENT_STAGES = {
    "drink": "stone", "tree_felled": "stone", "fire_lit": "stone", "ate_food": "stone", "sold": "stone", "fish_caught": "stone", "wanted_order": "stone",
    "carcass_worked": "stone", "worn_warmth": "stone", "talked": "stone", "moved_lit_night": "stone", "path_laid": "stone", "fire_tier": "stone",
    "map_surveyed": "stone", "map_redrawn": "stone",
    "bellows_iron": "iron",          # iron ore smelted at the Improved smelter's bellows
    "tempered": "steel",             # tempering steel at the Master smithy
    "station_repaired": "stone",     # a hammer repair of a worn smithy; the Primitive smithy (stone_forge, stone stage) already wears (test_smithy_repair)
    # The 26 audit ADD goals (approved by Dave 14 Nov 2026 06:26Z) whose events are not built yet: done by hand at the start.
    "cooked_on_fire": "stone", "seed_sown": "stone", "crop_harvested": "stone", "tool_repaired": "stone", "slept_night": "stone",
    "stored_item": "stone", "bought": "stone", "meal_effect": "stone", "foraged_new": "stone", "fish_kind_caught": "stone",
}
# New events that need a tool, item or station: the easiest stage of any one of them (items by id, structures by kind).
EVENT_NEEDS = {
    "bed_tilled": ["wooden_hoe", "stone_hoe", "iron_hoe", "steel_hoe"], "bush_replanted": ["wooden_spade", "stone_spade", "iron_spade", "steel_spade"],
    "snare_set": ["snare"], "tool_sharpened": ["whetstone", "grindstone"], "building_repaired": ["wooden_hammer", "stone_hammer"],
    "container_locked": ["chest", "plank_chest", "crude_chest", "wooden_crate", "iron_chest"], "handcart_hauled": ["handcart"],
    "masterwork_made": ["master_forge"], "kiln_charcoal": ["kiln"], "jar_matured": ["preserving_jar"], "platter_served": ["serving_platter"],
    "torch_placed": ["torch"], "ore_mined": ["stone_pickaxe", "copper_pickaxe", "bronze_pickaxe", "iron_pickaxe", "steel_pickaxe"],
}

spec = importlib.util.spec_from_file_location("er", os.path.join(ROOT, "tools", "encyclopedia_reach.py"))
er = importlib.util.module_from_spec(spec)
argv = sys.argv
sys.argv = [argv[0]]
spec.loader.exec_module(er)
sys.argv = argv
Reach = [v for v in vars(er).values() if isinstance(v, type) and hasattr(v, "step") and hasattr(v, "run")][0]
cfg = json.load(open(os.path.join(ROOT, "data", "items", "structures.json")))["smelting"]
orig_step = Reach.step
orig_give = Reach.give


def step(self):
    changed = orig_step(self)
    fuel = any(self.has(f) for f in cfg["fuel"])

    for kind in list(self.built):
        d = self.structures[kind]

        if d.get("use") != "smelt" or not fuel:
            continue

        for j in d["smelt"]["jobs"]:
            job = cfg["jobs"][j]

            if all(self.has(i[0]) for i in job["in"]):
                changed |= self.give(job["out"][0], "smelting job %s at %s" % (j, kind))

    return changed


def give(self, iid, how, kit=False):
    if iid in getattr(self, "banned", ()):
        return False
    return orig_give(self, iid, how, kit)


Reach.step = step
Reach.give = give
reach = []

for name, _c, ban in STAGES:
    r = Reach()
    r.banned = ban
    r.run()
    reach.append((name, r))


def stage_of_item(iid):
    for name, r in reach:
        if r.has(iid):
            return name
    return None


# Kinds the reach model never builds (a locked blueprint, or a row whose check names no kind): the stage of its blueprint's
# materials, the highest tier of anything it requires.
KIND_OF_ROW = {"activity:place_campfire": "campfire_kit"}


def stage_of_kind(kind):
    for name, r in reach:
        if kind in r.built:
            return name

    bp = reach[0][1].blueprints.get(kind)

    if bp:
        for name, r in reach:
            if all(r.fills(str(c[0])) for c in bp["cost"]):
                return name

    return None


def stage_of(row):
    try:
        check = json.loads(row["runtime_check"])
    except ValueError:
        check = {}

    if "made_item" in check or "got_item" in check:
        return stage_of_item(str(check.get("made_item", check.get("got_item"))))

    if "made_item_any" in check or "have_item_any" in check:
        found = [stage_of_item(str(i)) for i in check.get("made_item_any", check.get("have_item_any", []))]
        found = [s for s in found if s]
        return min(found, key=lambda s: COPPER[s]) if found else None   # any one of them completes it: the easiest

    if row["id"] in KIND_OF_ROW and KIND_OF_ROW[row["id"]].endswith("_kit"):
        return stage_of_item(KIND_OF_ROW[row["id"]])

    if check.get("event") == "placed":
        kinds = [KIND_OF_ROW[row["id"]]] if row["id"] in KIND_OF_ROW else check.get("what_any", [check.get("what", "")])
        found = [stage_of_kind(str(k)) for k in kinds]
        found = [s for s in found if s]
        return min(found, key=lambda s: COPPER[s]) if found else None

    event = str(check.get("event", ""))

    if event in EVENT_NEEDS:
        found = [stage_of_item(i) or stage_of_kind(i) for i in EVENT_NEEDS[event]]
        found = [s for s in found if s]
        return min(found, key=lambda s: COPPER[s]) if found else None

    return EVENT_STAGES.get(event)


path = os.path.join(ROOT, "docs", "design", "PLAYER_GOALS_CATALOG_CORRECTED.csv")
raw = open(path, newline="", encoding="utf-8").read()
term = "\r\n" if "\r\n" in raw.splitlines(True)[0] else "\n"
rd = csv.DictReader(io.StringIO(raw, newline=""))
rows = list(rd)
fields = list(rd.fieldnames)

if "stage" not in fields:
    fields.insert(fields.index("reward_text") + 1, "stage")
unplaced = []
counts = {name: 0 for name, _c, _b in STAGES}


def text(copper):
    b, c = divmod(copper, 10)
    parts = (["%d bronze" % b] if b else []) + (["%d copper" % c] if c else [])
    return " + ".join(parts)


# A row that names its stage (the coordinator's scale: "<Tier> - X", a metal, or a station tier in its title) pays at least that stage; the data can
# only raise it (a goal never pays less than the stage needed to do it). Rows where the data raises a named stage are listed.
NAMED = {"Crude": "stone", "Copper": "bronze", "Bronze": "bronze", "Improved": "bronze", "Iron": "iron", "Refined": "iron", "Advanced": "iron",
    "Steel": "steel", "Fortified": "steel", "Master": "steel"}
raised = []


def named_stage(title):
    found = [NAMED[w.strip("(),.;:")] for w in title.replace("-", " ").split() if w.strip("(),.;:") in NAMED]
    return max(found, key=lambda s: COPPER[s]) if found else None


for row in rows:
    if row["status"] == "MERGED":   # folded into another goal (A-43): no reward of its own
        row["stage"] = ""
        continue

    data_stage = stage_of(row)
    name_stage = named_stage(row["title"])
    stage = max([s for s in (data_stage, name_stage) if s], key=lambda s: COPPER[s]) if (data_stage or name_stage) else None

    if name_stage and data_stage and COPPER[data_stage] > COPPER[name_stage]:
        raised.append("%s (%s by name, %s by data)" % (row["id"], name_stage, data_stage))

    if stage is None:
        unplaced.append(row["id"])
        continue

    counts[stage] += 1
    row["reward_copper"] = str(COPPER[stage])
    row["reward_text"] = text(COPPER[stage])
    row["stage"] = STAGE_KEY[stage]

assert len({r["id"] for r in rows}) == len(rows), "duplicate goal ids"
total = sum(int(r["reward_copper"] or 0) for r in rows)
assert all(r["reward_copper"] in ("5", "10", "15", "20") for r in rows if r["status"] != "MERGED"), "a reward off the scale"
print(json.dumps({"stages": counts, "total_copper": total, "total_original": sum(int(r["reward_copper"] or 0) for r in rows if r["status"] == "ORIGINAL"), "unplaced": unplaced, "raised_above_name": raised}, indent=1))

if WRITE:
    out = io.StringIO(newline="")
    w = csv.DictWriter(out, fieldnames=fields, lineterminator=term)
    w.writeheader()
    w.writerows(rows)
    open(path, "w", newline="", encoding="utf-8").write(out.getvalue())

if "--probe" in sys.argv:
    for iid in sys.argv[sys.argv.index("--probe") + 1].split(","):
        print(iid, stage_of_item(iid), [(n, r.why.get(iid)) for n, r in reach][:4])
