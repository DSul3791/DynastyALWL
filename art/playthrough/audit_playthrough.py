#!/usr/bin/env python3
"""Playthrough audit (read-only): walks every item, recipe, structure and station in data/ and reports, per tier:
  - which items have a world source (ground, plant, trunk, dig, carcass, fish, trade, recipe) and whether the recipe chain is
    makeable NOW (known / open recipes only) or only if every recipe were known ("potential"),
  - which recipes are blocked and why (not known, ingredient with no source, station not obtainable, station level not reachable),
  - which items have no look, a grey placeholder look ("chunk" shape #8a8a8a), or an ART_OVERRIDES row that basic_look.gd ignores,
  - which structures have no look key, no footprint, no placement path (kit recipe or hammer blueprint) or no station level source.
Run from the repo root:  python art/playthrough/audit_playthrough.py   (writes art/playthrough/audit.json and audit.md)
"""
import json
import os
import re
import sys
from collections import defaultdict, OrderedDict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = os.path.join(ROOT, "data", "items")


def load(path):
    with open(os.path.join(ROOT, path), encoding="utf8") as f:
        return json.load(f)


items = {}
for fn in ("items.json", "gathered.json"):
    items.update(load("data/items/" + fn)["items"])
live_items = {k: v for k, v in items.items() if not v.get("retired")}
recipes_all = load("data/items/recipes.json")["recipes"]
recipes = {k: v for k, v in recipes_all.items() if not v.get("retired")}
open_ids = set(load("data/items/open_recipes.json")["open"])
structures = load("data/items/structures.json")["structures"]
blueprints = {k: v for k, v in load("data/items/blueprints.json")["blueprints"].items() if not v.get("retired")}
drops = load("data/items/drops.json")
digging = load("data/items/digging.json")
carcass = load("data/items/carcass.json")
looks = load("data/items/looks.json")["items"]
flora = {e["name"]: e for e in load("data/tables/flora.json")["entries"]}
basic_look_src = open(os.path.join(ROOT, "src/client/basic_look.gd"), encoding="utf8").read()
override_ids = set(re.findall(r'^\t"([a-z_0-9]+)": \{"shape"', basic_look_src, re.M))
look_table_src = open(os.path.join(ROOT, "src/client/look_table.gd"), encoding="utf8").read()
look_table_keys = set(re.findall(r'^\t"([a-z_0-9]+)": \{"builder', look_table_src, re.M))


def strings(node, skip_notes=True):
    """Every string value in a json tree, plus dict keys, except note fields."""
    if isinstance(node, dict):
        for k, v in node.items():
            if skip_notes and "note" in str(k):
                continue
            yield str(k)
            yield from strings(v, skip_notes)
    elif isinstance(node, list):
        for v in node:
            yield from strings(v, skip_notes)
    elif isinstance(node, str):
        yield node


# ---------------------------------------------------------------- natural sources
sources = defaultdict(set)   # item -> {labels}
gated = {}                   # item -> tool class needed to gather it
tool_rules = drops["tool_rules"]["suffixes"]


def tool_for(item_id):
    for cls, words in tool_rules.items():
        for w in words:
            if item_id.endswith(w):
                return cls
    return None


def add(item_id, label):
    if item_id in items:
        sources[item_id].add(label)
        t = tool_for(item_id) if label.startswith("plant") else None
        if t:
            gated[item_id] = t


for sp, rows in drops["by_species"].items():
    for row in rows:
        add(row[0], "plant:" + sp)
for row in drops["by_kind"].get("shrub", []):
    add(row[0], "plant:any shrub")
for sp, row in drops["harvest_yield"].items():
    add(row["item"], "plant:" + sp)
for sp, row in drops["berry_yield"].items():
    add(row["item"], "plant:" + sp)
# The server (server_items.gd gather()) also gives one random in-season yield from the plant's flora.json yields for any plant WITHOUT a
# harvest_yield or berry_yield row, if that yield exists as an item (natural yield). Taught here by Sal, 2026-10-31.
for e in flora.values():
    if e["kind"] in ("plant", "shrub") and e["name"] not in drops["harvest_yield"] and e["name"] not in drops["berry_yield"]:
        for y in e.get("yields", []):
            add(y, "plant:" + e["name"] + " (natural yield)")
# wood_species.json ingredient_groups: a recipe asking for a group id (plain log) is filled by any member (code half pending, data half done)
for gid, members in load("data/items/wood_species.json").get("ingredient_groups", {}).items():
    if gid != "note" and any(m in items for m in members):
        add(gid, "ingredient group " + gid)
for i in ("stone", "stick"):
    add(i, "ground scatter")
add("driftwood", "ground scatter (water bank)")
add("stone", "boulder")
for sect in ("trunk", "stump"):
    for s in strings(drops[sect]):
        add(s, "tree:" + sect)
for sp, rows in drops["trunk"].get("by_species", {}).items():
    for row in rows:
        add(row[0], "tree:" + sp)
add("thatch", "tree:birch/spruce/pine bark")
for s in strings(digging["yield"]):
    add(s, "dig")
for s in strings(digging):
    pass
for sp, row in carcass["species"].items():
    for part in row["parts"]:
        add(part[0], "carcass:" + sp)
fishing = load("data/items/fishing.json")
for s_ in list(fishing.get("species", {}).keys()) + list(strings(load("data/items/fish_schools.json")["species_by_kind"])):
    add(s_, "fishing")
for s_ in strings(fishing.get("net", {})):
    add(s_, "fishing")
# server literals (server_items.gd): a felled log is log_<species>, chopped logs give wooden_block, split blocks firewood
for i in ("wooden_block", "wooden_block_soft", "firewood", "firewood_soft", "bark", "seed_bundle"):
    add(i, "tree:log chain")
for e in flora.values():
    if e["kind"] == "tree":
        add("log_" + e["name"] if ("log_" + e["name"]) in items else "log", "tree:log chain (shoulder, one at a time)" if ("log_" + e["name"]) in items else "tree:log chain")
# produced by server code: roasting at a fire (cooking.json gives / cooks_into), spoilage (rotten_food), roasted carcass meat
cooking = load("data/items/cooking.json")
add(cooking.get("gives", ""), "cooking at a fire")
for v_ in cooking.get("cooks_into", {}).values():
    add(v_, "cooking at a fire")
add("rotten_food", "spoilage")
# trade and npc data
for fn in ("data/npcs/npcs.json",):
    try:
        for s in strings(load(fn)):
            add(s, "npc")
    except Exception:
        pass

# ---------------------------------------------------------------- stations
kit_of = {v["kit"]: k for k, v in structures.items() if v.get("kit")}


def provided(sname, spec):
    """List of (station, level) a placed structure gives."""
    out = []
    if spec.get("station"):
        out.append((spec["station"], int(spec.get("station_level", 1))))
    for st, lv in spec.get("also", {}).items():
        out.append((st, int(lv)))
    return out


def run_closure(only_known):
    have = set(i for i in sources if not gated.get(i))
    tools = set()                    # tool classes available
    made = OrderedDict()             # recipe -> wave
    built = OrderedDict()            # structure -> wave
    have.add("water")
    wave = 0
    changed = True

    def station_ok(name, level):
        if name == "campfire":
            return True
        for sname, sw in built.items():
            for st, lv in provided(sname, structures[sname]):
                if st == name and lv >= level:
                    return True
        # add-ons (level = 1 + distinct add-on kinds near)
        if level > 1:
            addons = [a for a, sp in structures.items() if sp.get("addon_of") == name and a in built]
            base = [s for s, sp in structures.items() if s in built and any(p[0] == name for p in provided(s, sp))]
            if base and 1 + len(addons) >= level:
                return True
        return False

    def refresh_tools():
        for i in have:
            c = items.get(i, {}).get("tool_class")
            if c:
                tools.add(c)
        for i in list(items):
            if i not in have and gated.get(i) in tools and i in sources:
                have.add(i)

    while changed:
        changed = False
        wave += 1
        refresh_tools()
        for k, v in recipes.items():
            if k in made:
                continue
            if only_known and not (v.get("known") or k in open_ids):
                continue
            need = [i for i, _ in v["needs"]] + [i for i, _ in v.get("keeps", [])]
            if not all(i in have for i in need):
                continue
            if v.get("station") and not station_ok(v["station"], int(v.get("station_level", 1))):
                continue
            made[k] = wave
            have.add(v["gives"][0])
            changed = True
        refresh_tools()
        for sname, spec in structures.items():
            if sname in built:
                continue
            ok = False
            if spec.get("kit") and spec["kit"] in have:
                ok = True
            for bp in blueprints.values():
                if bp["structure"] == sname:
                    if all(i in have for i, _ in bp["cost"]) and ("hammer" in tools) and (not bp.get("station") or station_ok(bp["station"], int(bp.get("station_level", 1)))):
                        ok = True
            if sname in ("campfire", "remains", "carcass", "path_patch", "door_open"):
                ok = ok or sname == "path_patch"
            if ok:
                built[sname] = wave
                changed = True
    return have, tools, made, built


have_now, tools_now, made_now, built_now = run_closure(True)
have_pot, tools_pot, made_pot, built_pot = run_closure(False)

# ---------------------------------------------------------------- reports
rep = {}
rep["counts"] = {"items": len(live_items), "recipes": len(recipes), "recipes_known_or_open": sum(1 for k, v in recipes.items() if v.get("known") or k in open_ids),
                 "structures": len(structures), "blueprints": len(blueprints)}

stations_pot = set(p for s in built_pot for p in provided(s, structures[s]))
recipe_rows = []
for k, v in sorted(recipes.items(), key=lambda x: x[1]["number"]):
    why = []
    known = bool(v.get("known") or k in open_ids)
    if not known:
        why.append("not known (no learn system)")
    miss_now = [i for i, _ in v["needs"] + v.get("keeps", []) if i not in have_pot]
    if miss_now:
        why.append("no source anywhere for " + ",".join(miss_now))
    if v.get("station") and v["station"] != "campfire" and not any(st == v["station"] and lv >= int(v.get("station_level", 1)) for st, lv in stations_pot):
        why.append("station %s level %s not obtainable" % (v["station"], v.get("station_level", 1)))
    recipe_rows.append({"id": k, "number": v["number"], "category": v.get("category"), "gives": v["gives"][0], "station": v.get("station", ""),
                        "station_level": v.get("station_level", 1), "known": known, "wave_now": made_now.get(k), "wave_potential": made_pot.get(k), "blocked_by": why, "future": bool(items.get(v["gives"][0], {}).get("future", False))})
rep["recipes"] = recipe_rows

item_rows = []
giver = defaultdict(list)
for k, v in recipes.items():
    giver[v["gives"][0]].append(k)
for k, v in sorted(live_items.items(), key=lambda x: x[1].get("number", 0)):
    look = looks.get(k)
    if k in override_ids:
        lk = "override look"   # basic_look.entry(): the override wins over a missing row or the grey placeholder row
    elif look is None:
        lk = "NO LOOK (structure or kit-less item: drawn by structure look)" if k in structures else "NO LOOK ENTRY"
    elif look.get("shape") == "chunk" and look.get("color") == "#8a8a8a":
        lk = "PLACEHOLDER grey chunk"
    else:
        lk = "ok (%s)" % look.get("shape")
    src = sorted(sources.get(k, []))
    if k in giver:
        src.append("recipe:" + ",".join(giver[k]))
    if k in have_now:
        obtain = "now"
    elif k in have_pot:
        obtain = "potential"
    elif k in structures or k in ("remains", "carcass"):
        obtain = "structure"
    elif k in giver or k in [b.get("recipe") for b in blueprints.values()] or (k.endswith("_kit") and k[:-4] in structures):
        obtain = "RECIPE BLOCKED"
    else:
        obtain = "ORPHAN"
    item_rows.append({"id": k, "number": v.get("number"), "kind": v.get("kind"), "sources": src, "obtainable": obtain, "look": lk, "future": bool(v.get("future", False))})
rep["items"] = item_rows

struct_rows = []
for k, v in structures.items():
    bp = [b for b in blueprints.values() if b["structure"] == k]
    problems = []
    if not v.get("footprint_x") and k not in ("campfire",):
        problems.append("no footprint")
    if not v.get("look") and k not in ("campfire",):
        problems.append("no look key")
    if v.get("kit") and v["kit"] not in giver and not bp:
        problems.append("kit '%s' has no recipe and no blueprint" % v["kit"])
    if v.get("kit") and v["kit"] in giver:
        gk = giver[v["kit"]][0]
        if not (recipes[gk].get("known") or gk in open_ids):
            problems.append("kit recipe %s not known" % gk)
    if k not in built_pot and k not in ("campfire", "remains", "carcass", "door_open"):
        problems.append("not obtainable even if all recipes known")
    elif k not in built_now and k not in ("campfire", "remains", "carcass", "door_open"):
        problems.append("not obtainable today (known/open recipes only)")
    struct_rows.append({"id": k, "state": v.get("state"), "station": v.get("station", ""), "station_level": v.get("station_level"), "also": v.get("also", {}),
                        "addon_of": v.get("addon_of", ""), "footprint": [v.get("footprint_x"), v.get("footprint_z")], "cap": v.get("cap_per_chunk"),
                        "built_wave_now": built_now.get(k), "built_wave_potential": built_pot.get(k), "problems": problems})
rep["structures"] = struct_rows
rep["tools_now"] = sorted(tools_now)
rep["tools_potential"] = sorted(tools_pot)
rep["stations_potential"] = sorted(set(p for s in built_pot for p in provided(s, structures[s])))
rep["stations_now"] = sorted(set(p for s in built_now for p in provided(s, structures[s])))

with open(os.path.join(ROOT, "art/playthrough/audit.json"), "w", encoding="utf8") as f:
    json.dump(rep, f, indent=1)

# ---------------------------------------------------------------- markdown
out = []
out.append("# Playthrough audit (generated by art/playthrough/audit_playthrough.py)\n")
out.append("Counts: %s\n" % rep["counts"])
out.append("Tools reachable now: %s. Tools reachable if every recipe were known: %s.\n" % (rep["tools_now"], rep["tools_potential"]))
out.append("Stations reachable now: %s\n\nStations reachable if every recipe were known: %s\n" % (rep["stations_now"], rep["stations_potential"]))
nr = [r for r in recipe_rows if r["blocked_by"]]
out.append("\n## Recipes blocked (%d of %d)\n\n| # | recipe | gives | category | station | wave if known | blocked by |\n|---|---|---|---|---|---|---|" % (len(nr), len(recipe_rows)))
for r in nr:
    out.append("| %d | %s | %s | %s | %s %s | %s | %s | %s |" % (r["number"], r["id"], r["gives"], r["category"], r["station"], r["station_level"] if r["station"] else "", r["wave_potential"], "yes" if r["future"] else "NO", "; ".join(r["blocked_by"])))
bad = [r for r in item_rows if r["obtainable"] == "ORPHAN"]
out.append("\n## ORPHAN items: no recipe makes them and nothing gathers, drops, digs, fishes or trades them: %d (F = marked future:true in items.json, by design for now)\n" % len(bad))
for r in bad:
    out.append("- `%s` (%s)%s look: %s" % (r["id"], r["kind"], " F" if r["future"] else " **NOT marked future**", r["look"]))
rb = [r for r in item_rows if r["obtainable"] == "RECIPE BLOCKED"]
out.append("\n## Items whose only recipe is blocked even if every recipe were known (an ingredient is an orphan or a station cannot be built): %d\n" % len(rb))
out.append(", ".join("`%s`%s" % (r["id"], "" if r["future"] else "*") for r in rb) + "\n\n(* = not marked future)")
pot = [r for r in item_rows if r["obtainable"] == "potential"]
out.append("\n## Items obtainable only if blocked recipes became known: %d\n" % len(pot))
out.append(", ".join("`%s`" % r["id"] for r in pot))
lk = [r for r in item_rows if not r["look"].startswith("ok") and r["look"] != "override look"]
out.append("\n## Item looks that are missing or placeholders: %d\n\n| item | look status |\n|---|---|" % len(lk))
for r in lk:
    out.append("| %s | %s |" % (r["id"], r["look"]))
out.append("\n## Structures\n\n| structure | state | station (lvl) | add-on of | footprint | built wave now / if known | problems |\n|---|---|---|---|---|---|---|")
for r in struct_rows:
    out.append("| %s | %s | %s %s | %s | %s | %s / %s | %s |" % (r["id"], r["state"], r["station"], r["station_level"] or "", r["addon_of"], r["footprint"], r["built_wave_now"], r["built_wave_potential"], "; ".join(r["problems"])))
with open(os.path.join(ROOT, "art/playthrough/audit.md"), "w", encoding="utf8") as f:
    f.write("\n".join(out) + "\n")
print("wrote art/playthrough/audit.md and audit.json")
unflagged = [r for r in nr if not r["future"]]
print("recipes blocked and NOT flagged future:", len(unflagged), [r["id"] for r in unflagged])
print("recipes blocked:", len(nr), "of", len(recipe_rows), "| orphan items:", len(bad), "| recipe-blocked items:", len(rb), "| placeholder looks:", len(lk))
