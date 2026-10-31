#!/usr/bin/env python3
"""Playthrough helper: writes world_items.json with one of each listed item in a row on the ground, DIST m north of x,z, SPACING m apart.
   rig_row_seed.py OUT_FILE ID,ID,... X GROUND_Y Z DIST SPACING"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from item_numbers import load_numbers
out, ids, x, y, z, dist, sp = sys.argv[1], sys.argv[2].split(","), float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6]), float(sys.argv[7])
nums = load_numbers()
rows = []
for n, i in enumerate(ids):
    if i not in nums:
        print("no such item (skipped): " + i); continue
    rows.append([int(nums[i]), 1, x + (n - (len(ids) - 1) / 2.0) * sp, y, z - dist, 99999.0])
json.dump({"version": 1, "next_id": 1000, "boulders": {}, "picked": {}, "taken": [], "items": rows}, open(out, "w"))
