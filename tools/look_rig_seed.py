#!/usr/bin/env python3
"""Look rig helper: writes world_items.json with N of an item lying on the ground 2.2 m north of x,z.
   look_rig_seed.py OUT_FILE ITEM_ID COUNT X GROUND_Y Z"""
import json, sys

out, item, count, x, y, z = sys.argv[1], sys.argv[2], int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
data = json.load(open("data/items/items.json", encoding="utf-8"))


def find(o, k):
    if isinstance(o, dict):
        if k in o and isinstance(o[k], dict) and "number" in o[k]:
            return o[k]["number"]
        for v in o.values():
            r = find(v, k)
            if r is not None:
                return r


number = find(data, item)
if number is None:
    sys.exit("no such item: " + item)
json.dump({"next_id": 2, "items": [[int(number), count, x, y, z - 2.2, 99999.0]]}, open(out, "w"))
