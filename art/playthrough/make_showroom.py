#!/usr/bin/env python3
"""Playthrough helper: writes a TEMPORARY data/items/showroom.json that lays out every live item (not the structure pseudo-items) in rows of 10,
grouped by chapter, so `rig.sh --showroom all` photographs the whole item table in one run. Restore with: git checkout data/items/showroom.json
   make_showroom.py [--per-row 10]"""
import json, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
def load(p): return json.load(open(os.path.join(ROOT, p), encoding="utf8"))
core = load("data/items/items.json")["items"]
gath = load("data/items/gathered.json")["items"]
rec = load("data/items/recipes.json")["recipes"]
struct = set(load("data/items/structures.json")["structures"])
cat_of = {}
for k, v in rec.items():
    if not v.get("retired"): cat_of.setdefault(v["gives"][0], v.get("category", "Other"))
per = int(sys.argv[sys.argv.index("--per-row") + 1]) if "--per-row" in sys.argv else 14
groups = {}
def put(g, i): groups.setdefault(g, []).append(i)
for i, v in sorted({**core, **gath}.items(), key=lambda x: x[1].get("number", 0)):
    if v.get("retired") or i in struct or i in ("remains", "carcass"): continue
    if i in cat_of: g = "2 crafted: " + cat_of[i]
    elif i in gath:
        n = i
        g = "1b plant: " + next((w for w in ("leaves","flowers","roots","berries","nuts","caps","bark","wood","petals","fronds","seeds","bulbs","stems") if n.endswith(w) or w in n), "other")
    else: g = "1a raw and misc: " + v.get("kind", "material")
    put(g, i)
rows = []; idx = 0
for g in sorted(groups):
    ids = groups[g]
    for n in range(0, len(ids), per):
        rows.append({"label": "R%02d %s" % (idx + 1, g), "start": [8.0 + 3.0 * (idx // 3), 40.0 * (idx % 3) - 50.0], "step": [0, 1.5], "items": [[i, 1] for i in ids[n:n + per]]})
        idx += 1
json.dump({"note": "TEMPORARY playthrough showroom", "rows": rows}, open(os.path.join(ROOT, "data/items/showroom.json"), "w"), indent=1)
print(len(rows), "rows,", sum(len(r["items"]) for r in rows), "items")

os.makedirs(os.path.join(ROOT, "art/playthrough/showroom"), exist_ok=True)
json.dump({i[0]: r["label"].lower().replace(" ", "_").replace(":", "") for r in rows for i in r["items"]}, open(os.path.join(ROOT, "art/playthrough/showroom/rows.json"), "w"), indent=0)
