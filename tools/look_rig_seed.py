#!/usr/bin/env python3
"""Look rig helper: writes world_items.json with N of an item lying on the ground DIST m north of x,z (default 1.0).
   look_rig_seed.py OUT_FILE ITEM_ID COUNT X GROUND_Y Z [DIST]"""
import json, sys

out, item, count, x, y, z = sys.argv[1], sys.argv[2], int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
dist = float(sys.argv[7]) if len(sys.argv) > 7 else 1.0


def find(o, k):
    if isinstance(o, dict):
        if k in o and isinstance(o[k], dict) and "number" in o[k]:
            return o[k]["number"]
        for v in o.values():
            r = find(v, k)
            if r is not None:
                return r


number = None
for table in ("items", "gathered"):
    number = find(json.load(open("data/items/%s.json" % table, encoding="utf-8")), item)
    if number is not None:
        break
if number is None:
    sys.exit("no such item: " + item)
json.dump({"version": 1, "next_id": 1000, "boulders": {}, "picked": {}, "taken": [], "items": [[int(number), count, x, y, z - dist, 99999.0]]}, open(out, "w"))
