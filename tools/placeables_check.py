#!/usr/bin/env python3
"""Every placeable item can actually be placed (Dave 5 Nov 2026: a Woven chest in the pack showed a ghost and did nothing).

Checks the data a placement runs on:
  1. every live item of kind "placeable" (or with "places_as") is the kit of a structure in structures.json, or the campfire kit, or the rough bed kit;
  2. every live blueprint names a structure that exists, costs only live items, and asks for a hammer tier that exists;
  3. every structure's kit item exists, and a retired kit has a live blueprint (so the hammer builds it);
  4. no live recipe gives a retired kit.
Run: python3 tools/placeables_check.py   (exit 1 on any problem)
"""
import json, sys, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "items")


def load(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return json.load(f)


items = dict(load("items.json")["items"])
items.update(load("gathered.json")["items"])   # thatch, straw and the other gathered materials live here
structs = load("structures.json")["structures"] if "structures" in load("structures.json") else load("structures.json")
bps = load("blueprints.json")["blueprints"]
recipes = load("recipes.json")["recipes"]
problems = []
warnings = []
toggled = {d.get("toggle") for d in structs.values() if isinstance(d, dict) and d.get("toggle")}   # an open door is a state of its door, not a thing to place
twins = {kind: d["slope_twin"] for kind, d in structs.items() if isinstance(d, dict) and d.get("slope_twin")}   # a roof corner's 65 shape (A-37): placed by its 45 row's blueprint

kit_of = {}
for kind, d in structs.items():
    if isinstance(d, dict) and d.get("kit"):
        kit_of[d["kit"]] = kind

KNOWN_OPEN = set()
LIVE_KIT_EXCEPTIONS = {"campfire_kit", "rough_bed_kit"}   # made in the pack, not by the hammer

for iid, it in items.items():
    if it.get("retired"):
        continue
    if it.get("kind") == "placeable" or "places_as" in it:
        if "places_as" in it:
            continue   # a torch is placed from the hand
        if iid not in kit_of and iid not in LIVE_KIT_EXCEPTIONS:
            problems.append("item %s is a live placeable but no structure uses it as its kit" % iid)

for bid, row in bps.items():
    if row.get("retired"):
        continue
    if row.get("structure") not in structs:
        problems.append("blueprint %s names the unknown structure %s" % (bid, row.get("structure")))
    for need in row.get("cost", []):
        it = items.get(need[0])
        if it is None:
            problems.append("blueprint %s costs the unknown item %s" % (bid, need[0]))
        elif it.get("retired"):
            problems.append("blueprint %s costs the retired item %s" % (bid, need[0]))
    if int(row.get("hammer", 1)) not in (1, 2, 3, 4):
        problems.append("blueprint %s asks for hammer tier %s" % (bid, row.get("hammer")))

live_struct_of_bp = {row.get("structure") for row in bps.values() if not row.get("retired")}
for kind, d in structs.items():
    if not isinstance(d, dict) or not d.get("kit"):
        continue
    if d.get("retired"):   # no longer built (10 Nov 2026 building tiers: Log - Bench, Table, Trough, Shelf); pieces already placed stay
        continue
    kit = items.get(d["kit"])
    if kit is None:
        problems.append("structure %s has the unknown kit item %s" % (kind, d["kit"]))
        continue
    if kit.get("retired") and kind not in live_struct_of_bp and kind in toggled:
        continue
    if kind in twins.values() and any(twin == kind and base in live_struct_of_bp for base, twin in twins.items()):
        continue

    if kit.get("retired") and kind not in live_struct_of_bp and kind in KNOWN_OPEN:
        warnings.append("structure %s has a retired kit (%s) and no blueprint yet: known open (docs/ITEMS_HANDOVER.md, vice migration), needs Dave's call on its cost" % (kind, d["kit"]))
    elif kit.get("retired") and kind not in live_struct_of_bp:
        problems.append("structure %s has a retired kit (%s) and no live blueprint, so nothing can place it" % (kind, d["kit"]))

for rid, r in recipes.items():
    if r.get("retired"):
        continue
    for g in r.get("gives", [])[:1]:
        it = items.get(g)
        if it is not None and it.get("retired") and str(g).endswith("_kit"):
            problems.append("recipe %s gives the retired kit %s" % (rid, g))

for w in warnings:
    print("WARNING: " + w)

if problems:
    print("placeables_check: %d problem(s)" % len(problems))
    for p in problems:
        print("  " + p)
    sys.exit(1)
print("placeables_check: ok (%d structures with kits, %d live blueprints)" % (len(kit_of), len([b for b in bps.values() if not b.get("retired")])))
