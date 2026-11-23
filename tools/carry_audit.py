#!/usr/bin/env python3
"""Carry-weight audit: list live recipes whose ingredients weigh more than a player can carry at once.

Cap = carry_kg_per_body_kg x body kg (75 kg default). Lists recipes above the
free-carry limit (free_ratio x cap) and above the cap. Weights: weights.json by_id,
then by_suffix, then default_kg. Usage: python tools/carry_audit.py [--body 75]
A recipe over the cap can still be made: a craft takes its ingredients from the pack,
loose stacks on the ground within LOOSE_STOCK_M and the player's own containers within
CRAFT_REACH_M (src/shared/craft_stock.gd; Dave 10 Nov 2026: "or they are within 12m of
you"), so the player brings the load over in trips. Exit 1 only with --strict and a
recipe over the cap.
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
for title, rows in (("OVER CAP (made from stock within 12 m: the ground or your chests by you)", over), ("SLOWING (over free carry)", slow)):
    print("\n%s: %d" % (title, len(rows)))
    for t, k, n, needs in sorted(rows, reverse=True):
        packs = sorted((float(v["carry_bonus_kg"]), v.get("name", p)) for p, v in items.items() if v.get("carry_bonus_kg"))
        fit = next((name for bonus, name in packs if w["carry_kg_per_body_kg"] * (body + bonus) >= t), "")
        print("  %7.1f kg  recipe %d %s  %s%s" % (t, n, k, " + ".join("%d %s" % (c, i) for i, c in needs), ("  (carried with a %s)" % fit) if fit and t > cap else ""))
sys.exit(1 if over and "--strict" in sys.argv else 0)
