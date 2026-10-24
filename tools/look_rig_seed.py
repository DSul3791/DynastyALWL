#!/usr/bin/env python3
"""Look rig helper: writes world_items.json with N of an item lying on the ground DIST m north of x,z (default 1.0).
   look_rig_seed.py OUT_FILE ITEM_ID COUNT X GROUND_Y Z [DIST]"""
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from item_numbers import load_numbers

out, item, count, x, y, z = sys.argv[1], sys.argv[2], int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
dist = float(sys.argv[7]) if len(sys.argv) > 7 else 1.0


try:
    number = load_numbers().get(item)
except ValueError as error:
    sys.exit("item table error: %s" % error)

if number is None:
    sys.exit("no such item: " + item)
json.dump({"version": 1, "next_id": 1000, "boulders": {}, "picked": {}, "taken": [], "items": [[int(number), count, x, y, z - dist, 99999.0]]}, open(out, "w"))
