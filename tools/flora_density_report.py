#!/usr/bin/env python3
"""Turns flora_density.gd JSON into per-biome tables (items per km2, per hectare for trees)."""
import json, sys
d = json.load(open(sys.argv[1]))
area, counts, kinds = d["area_km2"], d["counts"], d["kinds"]
berries = {"raspberry","bramble","blueberry","blackthorn","wild_strawberry","lingonberry","cranberry","crowberry","cloudberry","elder","juniper"}
fibre = {"nettle","flax","tall_grass","reeds","riverbraid","tanglewort","thatch_grass"}
print("sampled km2 by biome:", {b: round(a, 2) for b, a in sorted(area.items(), key=lambda x: -x[1])})
print("%-20s %7s %8s %8s %8s %8s %8s %8s" % ("biome", "km2", "trees", "shrubs", "berry", "fibre", "tall_gr", "plants"))
for b, a in sorted(area.items(), key=lambda x: -x[1]):
    c = counts.get(b, {})
    if a < 0.05: continue
    t = sum(n for s, n in c.items() if kinds.get(s) == "tree")
    sh = sum(n for s, n in c.items() if kinds.get(s) == "shrub")
    pl = sum(n for s, n in c.items() if kinds.get(s) == "plant")
    be = sum(n for s, n in c.items() if s in berries)
    fi = sum(n for s, n in c.items() if s in fibre)
    print("%-20s %7.2f %8.0f %8.0f %8.0f %8.0f %8.0f %8.0f" % (b, a, t/a, sh/a, be/a, fi/a, c.get("tall_grass", 0)/a, pl/a))
if len(sys.argv) > 2:
    b = sys.argv[2]; a = area[b]
    for s, n in sorted(counts[b].items(), key=lambda x: -x[1])[:40]:
        print("  %-18s %-6s %9.0f /km2" % (s, kinds.get(s), n/a))
