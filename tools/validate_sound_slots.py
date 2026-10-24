"""Checks data/sound/batch1_slots.json: every file exists, is under 1 MB and has a CREDITS.csv row; prints the empty-slot count from art/SOUND_MANIFEST.md-style groups.

Run: python3 tools/validate_sound_slots.py   (exit 1 on any error)
"""
import csv
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
slots = json.load(open(os.path.join(ROOT, "data/sound/batch1_slots.json")))["slots"]
credits = open(os.path.join(ROOT, "assets/audio/CREDITS.csv"), encoding="utf-8").read()
errors = 0
filled = 0

for name, slot in slots.items():
    for res in slot["files"]:
        path = os.path.join(ROOT, res.replace("res://", ""))

        if not os.path.exists(path):
            print("MISSING", res)
            errors += 1
        elif os.path.getsize(path) > 1_000_000:
            print("TOO BIG", res)
            errors += 1

        if os.path.basename(res) not in credits and "batch1/*" not in credits:
            print("NO CREDITS ROW", res)
            errors += 1

    if slot["status"] == "filled" and slot["files"]:
        filled += 1

empty = [n for n, s in slots.items() if s["status"] != "filled" or not s["files"]]
print("slots: %d filled, empty slots: %d" % (filled, len(empty)))
sys.exit(1 if errors else 0)
