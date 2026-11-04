#!/usr/bin/env python3
"""First-day economy model (Sal, 1 Nov 2026). Prints the markdown table used in docs/ECONOMY_FIRST_DAY.md.
Rates are ASSUMED picks per minute of full-time gathering (nobody has timed them); change RATES and rerun."""
import json, math, sys
I = json.load(open("data/items/items.json"))["items"]
C = json.load(open("data/items/coins.json"))["trade"]
HOURS = float(sys.argv[1]) if len(sys.argv) > 1 else 4.0
# item: (assumed picks per minute, sell_lot)
RATES = {"stone": (6, 30), "stick": (12, 60), "leaves": (12, 60), "plant_fibre": (10, 50), "bark": (6, 30), "nettles": (8, 40),
         "feather": (1, 6), "soil": (4, 20), "clay": (4, 20), "sand": (4, 20), "gravel": (4, 20), "wheat_seeds": (3, 15),
         "firewood_soft": (3, 12), "wooden_pin": (3, 12), "nails": (3, 15)}
mult = C["buy_discount"]
rows = []
for k, (rate, lot) in RATES.items():
    v = I[k]["value"]
    per_lot = max(math.floor(v * mult + 0.0001), 1)   # the code pays one unit price per lot: the 1-copper minimum at value 1
    cpm = rate / lot * per_lot
    rows.append((k, rate, lot, cpm, cpm * 60 * HOURS))
print("| item | picks/min (assumed) | sell_lot | copper/min | copper in %.0f h |\n|---|---|---|---|---|" % HOURS)
for r in rows:
    print("| %s | %d | %d | %.2f | %.0f |" % (r[0], r[1], r[2], r[3], r[4]))
buy = C["sell_markup"]
print()
for name, k in (("meal", "roast_forage"), ("waterskin", "waterskin"), ("clothing", "hide_cloak"), ("basic iron tool", "iron_spade")):
    print("%s (%s): value %d, trader price about %d" % (name, k, I[k]["value"], math.ceil(I[k]["value"] * buy)))
