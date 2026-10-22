"""Adds an item to data/items/gathered.json for every flora yield that has none yet.

Numbers are append-only (never renumbered). Run from the repo root:  python3 tools/gen_gathered_items.py
"""
import json

flora = json.load(open("data/tables/flora.json"))["entries"]
core = set(json.load(open("data/items/items.json"))["items"])
path = "data/items/gathered.json"
table = json.load(open(path))
known = table["items"]
next_number = int(table["next_number"])

display = {e["name"]: e["display"] for e in flora}


def inspect_fields(entry):
    """Inspection mode data for an item: how well known it is and what it gets mistaken for."""
    return {"familiarity": int(entry.get("familiarity", 50)), "look_alikes": [display.get(n, n.replace("_", " ").capitalize()) for n in entry.get("look_alikes", [])]}


for entry in flora:
    if entry.get("retired"):
        continue

    for name in entry["yields"]:
        if name not in known and name not in core:
            known[name] = {"number": next_number, "name": name.replace("_", " ").capitalize(), "kind": "material", "stack": 20, **inspect_fields(entry)}
            next_number += 1
            print("added", name)

# Items made before inspection data existed get it from the first species that yields them.
for entry in flora:
    for name in entry["yields"]:
        item = known.get(name)

        if item is not None and "familiarity" not in item:
            item.update(inspect_fields(entry))

table["next_number"] = next_number
json.dump(table, open(path, "w"), indent="\t")
