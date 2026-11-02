#!/usr/bin/env python3
"""Carry-weight audit: flag live recipes whose ingredients weigh more than a player can carry.

Cap = carry_kg_per_body_kg x body kg (75 kg default). Warn above the free-carry
limit (free_ratio x cap); fail above the cap. Weights: weights.json by_id,
then by_suffix, then default_kg. Usage: python tools/carry_audit.py [--body 75]
Exit 1 if any live recipe exceeds the cap.
"""
import json, sys, pathlib
D = pathlib.Path(__file__).resolve().parent.parent / "data" / "items"
body = float(sys.argv[sys.argv.index("--body") + 1]) if "--body" in sys.argv else 75.0
w = json.load(open(D / "weights.json", encoding="utf8"))
items = json.load(open(D / "items.json", encoding="utf8")).get("items", {})
recipes = json.load(open(D / "recipes.json", encoding="utf8"))["recipes"]
cap = w["carry_kg_per_body_kg"] * body
free = w["free_ratio"] * cap

def kg(i):
    if i in w["by_id"]:
        return w["by_id"][i]
    for s, v in w.get("by_suffix", {}).items():
        if i.endswith(s):
            return v
    return w["default_kg"]

over, slow = [], []
for k, r in recipes.items():
    if r.get("retired") or r.get("locked"):
        continue
    if any(items.get(g, {}).get("future") for g in [r["gives"][0]]):
        continue
    t = sum(kg(i) * n for i, n in r["needs"])
    row = (t, k, r["number"], r["needs"])
    if t > cap:
        over.append(row)
    elif t > free:
        slow.append(row)
print("cap %.1f kg, free carry %.1f kg (body %g kg)" % (cap, free, body))
for title, rows in (("OVER CAP (cannot be made)", over), ("SLOWING (over free carry)", slow)):
    print("\n%s: %d" % (title, len(rows)))
    for t, k, n, needs in sorted(rows, reverse=True):
        print("  %7.1f kg  recipe %d %s  %s" % (t, n, k, " + ".join("%d %s" % (c, i) for i, c in needs)))
sys.exit(1 if over else 0)
