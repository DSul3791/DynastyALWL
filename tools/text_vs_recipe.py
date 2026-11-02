#!/usr/bin/env python3
"""Find numbers in player-facing item text that disagree with the recipe.

For every encyclopedia how_to_get line of an item, any "<N> <ingredient name>"
must match the needs of a recipe that makes that item.
Heuristic: prints warnings, exit code 1 if any. Usage: python tools/text_vs_recipe.py
"""
import json, re, sys, pathlib
D = pathlib.Path(__file__).resolve().parent.parent / "data" / "items"
items = json.load(open(D / "items.json", encoding="utf8"))
items = items.get("items", items)
recipes = list(json.load(open(D / "recipes.json", encoding="utf8"))["recipes"].values())
name = {k: v["name"].lower() for k, v in items.items() if isinstance(v, dict) and "name" in v}
by_result = {}
for r in recipes:
    by_result.setdefault(r["name"].lower(), []).append(r)
# Encyclopedia how_to_get lines are checked against the recipe that makes that exact item.
by_id = {}
for r in recipes:
    by_id.setdefault(r["gives"][0], []).append(r)
TEXT = ["encyclopedia.json"]

def strings(o, path=""):
    if isinstance(o, str):
        yield path, o
    elif isinstance(o, dict):
        for k, v in o.items():
            yield from strings(v, path + "/" + str(k))
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from strings(v, path + "/" + str(i))

def plural_forms(n):
    return {n, n + "s", n + "es", n[:-1] + "ies" if n.endswith("y") else n}

bad = 0
for f in TEXT:
    p = D / f
    if not p.exists():
        continue
    for path, s in strings(json.load(open(p, encoding="utf8"))):
        low = s.lower()
        m0 = re.match(r"/items/([^/]+)/how_to_get", path)
        if not m0 or m0.group(1) not in by_id:
            continue
        for rname, rs in [(m0.group(1), by_id[m0.group(1)])]:
            ok = {}
            for r in rs:
                for ing, n in r["needs"]:
                    ok.setdefault(name.get(ing, ing).lower(), set()).add(n)
            for ing, ns in ok.items():
                for form in plural_forms(ing):
                    for m in re.finditer(r"\b(\d+)\s+" + re.escape(form) + r"\b", low):
                        if int(m.group(1)) not in ns:
                            bad += 1
                            print("%s %s: '%s' says %s %s but recipe '%s' needs %s" % (f, path, s[:70], m.group(1), ing, rname, sorted(ns)))
print("%d mismatch(es)" % bad)
sys.exit(1 if bad else 0)
