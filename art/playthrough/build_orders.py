#!/usr/bin/env python3
"""Playthrough build orders: for each milestone a new player aims at (first axe, fire, shelter, bed, bench, forge...), expands the recipe tree from
data/items/recipes.json to raw materials and craft seconds, converts the raw materials to gathering seconds with the parameters below (which come from
the server constants and drops.json, or are marked as assumptions), and writes PLAYTHROUGH_BUDGET.md.
    python art/playthrough/build_orders.py
Change a parameter in PARAMS and re-run to see how a tuning change moves every milestone."""
import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
R = {k: v for k, v in json.load(open(os.path.join(ROOT, "data/items/recipes.json"), encoding="utf8"))["recipes"].items() if not v.get("retired")}
GIVES = {}
for k, v in R.items():
    GIVES.setdefault(v["gives"][0], []).append(k)

# Seconds of the player's time per unit, walking included. SOURCE column says where the number comes from.
PARAMS = {
    "plant_fibre": (1.0, "nettle 1-2 fibre per plant (drops.json), about 1.5 s a plant incl. a step (assumption)"),
    "thatch": (0.4, "tall grass 4 thatch a plant (drops.json), 1.5 s a plant (assumption); tall grass is now within 50 m of the spawn"),
    "bedding": (0.25, "fern 6 bedding a plant (drops.json), 1.5 s a plant (assumption)"),
    "stone": (6.0, "loose stone every ~10 m of walking at 1.4-2 m/s (assumption; spawn boost 1-2 extra per 32 m cell)"),
    "clay": (1.0, "spade dig 0.7 s a stroke (DIG_COOLDOWN_MS) giving 1-3 shovelfuls (digging.json); needs wet soil (assumption)"),
    "hide": (60.0, "one rabbit: find, strike (0.6 s cooldown), dress 4 blows (carcass.json): about a minute (assumption)"),
    "log": (7.0, "fell 13 blows x 0.4 s (HIT_COOLDOWN_MS) + 3 blows x 0.45 s a log (PROCESS_COOLDOWN_MS) + walking (assumption: a 0.3 m trunk)"),
    "sinew": (60.0, "carcass part (assumption)"),
    "bone": (60.0, "carcass part (assumption)"),
    "feather": (90.0, "grouse or duck kill (assumption)"),
}
TREE_BATCH_S = 15.0            # one tree: 13 fell blows (5.2 s) + 3 branch blows (1.4 s) + walking 8 s
TREE_STICKS = 6.0              # drops.json trunk.branch: 1-3 sticks a blow x 3 blows
TREE_LEAVES = 6.0              # 1-3 leaves a blow x 3 blows
DEFAULT_S = 5.0

MILESTONES = [
    ("First stone axe", [("stone_axe", 1)]),
    ("Fire laid and lit (kit + 1 tinder)", [("campfire_kit", 1), ("plant_fibre", 1)]),
    ("Lean-to", [("lean_to_kit", 1)]),
    ("Rough bed (bedding route)", [("rough_bed_bedding", 1)]),
    ("Workbench", [("workbench_kit", 1)]),
    ("Tool rack (bench level 2)", [("tool_rack_kit", 1)]),
    ("Stone hammer", [("stone_hammer", 1)]),
    ("Stone pickaxe", [("stone_pickaxe", 1)]),
    ("Wooden bow + 4 fibre arrows", [("wooden_bow", 1), ("fibre_arrow", 4)]),
    ("Stone spear", [("spear", 1)]),
    ("Stone knife", [("stone_knife", 1)]),
    ("Thatch house: floor + 4 walls + roof + doorway", [("thatch_floor_kit", 1), ("thatch_wall_kit", 4), ("thatch_roof_kit", 1), ("thatch_doorway_kit", 1)]),
    ("Stone forge (blueprint: 36 stone, 10 clay, 2 hide; bench level 2 first)", [("stone", 36), ("clay", 10), ("hide", 2), ("workbench_kit", 1), ("tool_rack_kit", 1), ("stone_hammer", 1)]),
]


def expand(item, qty, raw, secs, kept):
    """Recursively turns item x qty into raw materials and craft seconds; a recipe's 'keeps' items are needed once."""
    options = [g for g in GIVES.get(item, []) if g in R]

    if not options or item in PARAMS or item in ("stone", "stick", "leaves"):
        raw[item] = raw.get(item, 0) + qty
        return

    rid = "rough_bed_bedding" if item == "rough_bed_kit" and "rough_bed_bedding" in R else options[0]
    r = R[rid]
    crafts = math.ceil(qty / r["gives"][1])
    secs[0] += crafts * float(r.get("craft_s", 3.0))

    for need, n in r["needs"]:
        expand(need, n * crafts, raw, secs, kept)

    for need, n in r.get("keeps", []):
        if need not in kept:
            kept.add(need)
            expand(need, n, raw, secs, kept)


rows = []
for name, parts in MILESTONES:
    raw, secs, kept = {}, [0.0], set()

    for item, qty in parts:
        if item in R and item not in GIVES:   # a recipe id given directly
            expand(R[item]["gives"][0], qty, raw, secs, kept)
        else:
            expand(item, qty, raw, secs, kept)

    sticks = raw.pop("stick", 0)
    leaves = raw.pop("leaves", 0)
    trees = math.ceil(max(sticks / TREE_STICKS, leaves / TREE_LEAVES)) if (sticks or leaves) else 0
    gather = max(sticks / TREE_STICKS, leaves / TREE_LEAVES) * TREE_BATCH_S   # proportional: a few sticks come off the ground or one branch, not a whole tree
    detail = []

    if trees:
        detail.append("%d sticks, %d leaves = %d trees" % (sticks, leaves, trees))

    for item, n in sorted(raw.items()):
        per = PARAMS.get(item, (DEFAULT_S, "default"))[0]
        gather += n * per
        detail.append("%d %s" % (n, item))

    rows.append((name, detail, gather, secs[0]))

out = ["# PLAYTHROUGH_BUDGET: how long each milestone takes a new player", "",
       "Generated by `art/playthrough/build_orders.py` from the recipe data (raw materials and craft seconds are exact) and the parameters below (gathering seconds are estimates, each with its source). Change a parameter and re-run to see every milestone move.", "",
       "## Milestones (a milestone's own materials only, nothing carried over)", "",
       "| milestone | raw materials | gather (min) | craft (min) | hands-on total (min) |", "|---|---|---|---|---|"]
total = 0.0

for name, detail, g, c in rows:
    out.append("| %s | %s | %.1f | %.1f | %.1f |" % (name, ", ".join(detail), g / 60.0, c / 60.0, (g + c) / 60.0))

out += ["", "## Cumulative order of play (what the first-30-minutes script does)", "", "| after step | cumulative hands-on minutes |", "|---|---|"]
order = ["First stone axe", "Fire laid and lit (kit + 1 tinder)", "Lean-to", "Rough bed (bedding route)", "Workbench", "Stone spear", "Stone knife"]
lookup = {r[0]: r for r in rows}
cum = 0.0

for n in order:
    cum += (lookup[n][2] + lookup[n][3]) / 60.0
    out.append("| %s | %.1f |" % (n, cum))

# Supply against demand: plants the whole early build order needs, against what the flora placer puts within walking distance of the spawn.
try:
    survey = json.load(open(os.path.join(ROOT, "art/playthrough/spawn_survey.json"), encoding="utf8"))
except Exception:
    survey = None

if survey:
    total_fibre = sum(float(dict((d.split(" ", 1)[1], int(d.split(" ", 1)[0])) for d in detail if d.split(" ", 1)[0].isdigit() and "=" not in d).get("plant_fibre", 0)) for name, detail, g, c in rows if name in order)
    house = [r for r in rows if r[0].startswith("Thatch house")][0]
    house_fibre = float(dict((d.split(" ", 1)[1], int(d.split(" ", 1)[0])) for d in house[1] if d.split(" ", 1)[0].isdigit() and "=" not in d).get("plant_fibre", 0))
    house_thatch = float(dict((d.split(" ", 1)[1], int(d.split(" ", 1)[0])) for d in house[1] if d.split(" ", 1)[0].isdigit() and "=" not in d).get("thatch", 0))
    out += ["", "## Supply against demand around the spawn (probe_spawn.gd, real flora placer)", "",
            "Demand = the cumulative order of play above (%.0f plant fibre) plus the thatch house (%.0f fibre, %.0f thatch). A nettle gives about 1.5 fibre, a tall grass plant 2 fibre and 4 thatch (drops.json, size 1; bigger patches give up to 3 times). Each plant is picked once and regrows after 3 game days." % (total_fibre, house_fibre, house_thatch), "",
            "| within | nettles | tall grass | reeds | ferns | fibre if nettles only | thatch if tall grass only | enough for order of play | enough for the house |", "|---|---|---|---|---|---|---|---|---|"]

    for ring, c in zip(survey["rings_m"], survey["counts"]):
        net, tg, reeds, fern = c.get("nettle", 0), c.get("tall_grass", 0), c.get("reeds", 0), c.get("fern", 0)
        fibre_supply = net * 1.5 + tg * 2.0
        thatch_supply = tg * 4.0 + reeds * 8.0
        ok1 = "yes" if fibre_supply >= total_fibre else "NO"
        ok2 = "yes" if fibre_supply >= total_fibre + house_fibre and thatch_supply >= house_thatch else "NO"
        out.append("| %d m | %d | %d | %d | %d | %.0f | %.0f | %s | %s |" % (ring, net, tg, reeds, fern, fibre_supply, thatch_supply, ok1, ok2))

out += ["", "## Parameters", "", "| item | seconds per unit | source |", "|---|---|---|"]

for k, (v, s) in PARAMS.items():
    out.append("| %s | %s | %s |" % (k, v, s))

out.append("| tree batch | %.0f s for about %d sticks and %d leaves | fell and branch blows (HIT_COOLDOWN_MS 400, PROCESS_COOLDOWN_MS 450) plus walking |" % (TREE_BATCH_S, TREE_STICKS, TREE_LEAVES))
out.append("| default raw item | %.0f s | assumption |" % DEFAULT_S)
open(os.path.join(ROOT, "PLAYTHROUGH_BUDGET.md"), "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")
print("\n".join(out[:30]))
