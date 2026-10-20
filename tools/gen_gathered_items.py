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

for entry in flora:
    if entry.get("retired"):
        continue

    for name in entry["yields"]:
        if name not in known and name not in core:
            known[name] = {"number": next_number, "name": name.replace("_", " ").capitalize(), "kind": "material", "stack": 20, "look_alikes": []}
            next_number += 1
            print("added", name)

table["next_number"] = next_number
json.dump(table, open(path, "w"), indent="\t")
