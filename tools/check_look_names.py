#!/usr/bin/env python3
"""Every structures.json "look" must be one the client can draw: a key of src/client/look_table.gd LOOKS or a case of the
dispatcher match in src/client/inventory_view.gd (_model_for_state). Rows of the structures.json "look_names" table marked
"planned": true are for pieces not in the game yet and are not demanded. Run from the repo root; exit 1 lists the problems.
Called from tools/merge_check.py (no Godot needed)."""
import json, re, sys

structures = json.load(open("data/items/structures.json"))
table = open("src/client/look_table.gd", encoding="utf-8").read()
view = open("src/client/inventory_view.gd", encoding="utf-8").read()
known = set(re.findall(r'^\t"(\w+)": \{"builder"', table, re.M))
start = view.index("func _model_for_state")
known |= set(re.findall(r'^\t\t"(\w+)":\s*$', view[start:start + 6000], re.M))
DRAWN_AS_BLOCK = {"chopping_block"}   # the dispatcher falls through to a plain block for these on purpose
problems = []

for kind, row in structures["structures"].items():
    look = row.get("look", "")
    if look and look not in known and look not in DRAWN_AS_BLOCK:
        problems.append("structures.json %s: look '%s' has no entry in look_table.gd or the dispatcher" % (kind, look))

for name, row in structures.get("look_names", {}).items():
    if name != "note" and not row.get("planned", False) and name not in known:
        problems.append("structures.json look_names %s: not planned and not drawable" % name)

if problems:
    print("look names: %d problems" % len(problems))
    print("\n".join(problems))
    sys.exit(1)

print("look names: all %d structure looks are drawable" % len({r.get("look") for r in structures["structures"].values()}))
