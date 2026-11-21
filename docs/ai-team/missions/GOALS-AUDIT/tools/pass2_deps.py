#!/usr/bin/env python3
"""GOALS-AUDIT pass 2: instructional dependency graph over the 651 draft goals.

For every craft/build goal: which goals teach each consumed input, retained tool, station (at level) and hammer tier.
For the MAIN route: whether each dependency is taught EARLIER in the main route (else: later, only in ADDITIONAL, or by no goal).
Usage: python3 pass2_deps.py <repo_root> <work_dir>   (needs work/goals_parsed.json from goals_audit.py)
"""
import json, os, sys, collections
ROOT, W = sys.argv[1], sys.argv[2]
D = lambda p: json.load(open(os.path.join(ROOT, "data", p)))
goals = json.load(open(os.path.join(W, "goals_parsed.json")))
R = D("items/recipes.json")["recipes"]; B = D("items/blueprints.json")["blueprints"]; S = D("items/structures.json")["structures"]
I = D("items/items.json")["items"]; I.update({k: v for k, v in D("items/gathered.json")["items"].items() if k not in I})
WD = D("items/wood_species.json")
GROUPS = {k: [k] + v for k, v in WD["ingredient_groups"].items() if isinstance(v, list)}
HAMMER = {v["tier"]: k for k, v in I.items() if v.get("tool_class") == "hammer"}
MEMBER_OF = collections.defaultdict(set)
for gk, ms in GROUPS.items():
    for m in ms: MEMBER_OF[m].add(gk)

# legacy goals -> what they teach (from starter_goals/camp_goals checks)
LEGACY_TEACH = {"fibre": ["plant_fibre"], "twine": ["twine"], "axe": ["stone_axe"], "hammer": ["wooden_hammer"], "hoe": ["wooden_hoe"],
                "spear": ["spear"], "torch_night": ["torch"], "candle": ["candle"], "smoke_fish": ["smoked_fish"], "dry_berries": ["dried_berries"],
                "jerky": ["jerky"], "salted_fish": ["salted_fish"], "fish": GROUPS["fish"], "fell": [], "knife": [], "drink": [],
                "fire": [], "path": [], "berries": [], "sell": [], "order": [], "winter_store": [], "fur_for_winter": [], "story": [], "night_walk": []}
LEGACY_BUILD = {"shelter": "lean_to", "bed": "rough_bed", "workbench": "workbench"}
pos = {g["goal_id"]: i for i, g in enumerate(goals)}
main_pos = {g["goal_id"]: i for i, g in enumerate([g for g in goals if g["route"] == "MAIN"])}

teach_item = collections.defaultdict(list)    # item -> goal ids teaching how to obtain it
teach_struct = collections.defaultdict(list)  # structure kind -> goal ids
for g in goals:
    k = g["kind"]
    if k in ("craft", "gather"): teach_item[g["key"]].append(g["goal_id"])
    elif k == "build": teach_struct[g["ref"].get("structure", g["key"])].append(g["goal_id"])
    elif k == "existing":
        for it in LEGACY_TEACH.get(g["key"], []): teach_item[it].append(g["goal_id"])
        if g["key"] in LEGACY_BUILD: teach_struct[LEGACY_BUILD[g["key"]]].append(g["goal_id"])
teach_struct["campfire"] += ["activity:place_campfire"]
teach_struct["chopping_block"] += ["activity:place_chopping_block"]
for sk, s in S.items():   # hand-placed structures are also taught by the goal that makes their item
    for it in {s.get("kit"), s.get("item")} - {None, ""}:
        if sk not in ("campfire",) and teach_item.get(it): teach_struct[sk] += [x for x in teach_item[it] if x not in teach_struct[sk]]

station_structs = collections.defaultdict(list)   # station -> [(kind, level)]
for sk, s in S.items():
    if s.get("retired"): continue
    if s.get("station"): station_structs[s["station"]].append((sk, s.get("station_level", 1)))
    for st, lv in (s.get("also") or {}).items(): station_structs[st].append((sk, lv))
station_structs["campfire"].append(("campfire", 1))

def best(ids, ref_goal):
    """earliest teaching goal: prefer MAIN route position, then document order"""
    if not ids: return None
    return sorted(set(ids), key=lambda x: (0 if x in main_pos else 1, main_pos.get(x, 0), pos.get(x, 10**6)))[0]

def item_teacher(i):
    ids = []
    for m in GROUPS.get(i, [i]): ids += teach_item.get(m, [])
    return best(ids, None)

def station_teacher(st, lv):
    ids = []
    for sk, l in station_structs.get(st, []):
        if l >= lv: ids += teach_struct.get(sk, [])
    return best(ids, None), [sk for sk, l in station_structs.get(st, []) if l >= lv]

out = {}
for g in goals:
    deps = []   # (role, target, teacher goal or None)
    if g["kind"] == "craft" and g.get("recipe_used") in R:
        r = R[g["recipe_used"]]
        for i, n in r["needs"]: deps.append(("input", "%s x%d" % (i, n), item_teacher(i)))
        for i, n in r.get("keeps", []): deps.append(("tool", i, item_teacher(i)))
        if r.get("station"):
            t, kinds = station_teacher(r["station"], r.get("station_level", 1))
            deps.append(("station", "%s L%d (%s)" % (r["station"], r.get("station_level", 1), "/".join(kinds) or "NO STRUCTURE"), t))
    elif g["kind"] == "build":
        bk = g["key"] if g["key"] in B else None
        if bk:
            b = B[bk]
            for i, n in b["cost"]: deps.append(("input", "%s x%d" % (i, n), item_teacher(i)))
            h = b.get("hammer", 1)
            hs = [HAMMER[t] for t in HAMMER if t >= h]
            deps.append(("hammer", "tier>=%d" % h, best(sum((teach_item.get(x, []) for x in hs), []), None)))
            if b.get("near"):
                t, kinds = station_teacher(b["near"], b.get("near_level", 1)) if b["near"] in station_structs else (best(teach_struct.get(b["near"], []), None), [b["near"]])
                deps.append(("near", b["near"], t))
    rec = {"deps": deps, "dep_goal_ids": sorted({d[2] for d in deps if d[2]}, key=lambda x: pos.get(x, 0)),
           "untaught": [f"{d[0]}:{d[1]}" for d in deps if not d[2]]}
    if g["route"] == "MAIN":
        me = main_pos[g["goal_id"]]
        rec["main_later"] = [f"{d[0]}:{d[1]}->{d[2]}" for d in deps if d[2] in main_pos and main_pos[d[2]] > me]
        rec["main_only_additional"] = [f"{d[0]}:{d[1]}->{d[2]}" for d in deps if d[2] and d[2] not in main_pos]
    out[g["goal_id"]] = rec

json.dump(out, open(os.path.join(W, "pass2_deps.json"), "w"), indent=1)
# report
mains = [g for g in goals if g["route"] == "MAIN"]
print("MAIN-ROUTE ORDER / COVERAGE DEFECTS")
for g in mains:
    r = out[g["goal_id"]]
    bad = r["untaught"] + r.get("main_later", []) + r.get("main_only_additional", [])
    if bad: print(" %3d %-32s untaught=%s later=%s additional_only=%s" % (main_pos[g["goal_id"]] + 1, g["goal_id"], r["untaught"], r["main_later"], r["main_only_additional"]))
cnt = collections.Counter()
for gid, r in out.items():
    for u in r["untaught"]: cnt[u.split(" x")[0].split(" (")[0]] += 1
print("\nUNTAUGHT DEPENDENCIES ACROSS ALL GOALS (no goal teaches it):")
for k, v in cnt.most_common(): print("  %-40s %d" % (k, v))
# additional goals whose deps appear AFTER them in document order (later section)
late = []
for g in goals:
    if g["route"] != "ADDITIONAL": continue
    for d in out[g["goal_id"]]["deps"]:
        if d[2] and d[2] not in main_pos and pos[d[2]] > pos[g["goal_id"]]: late.append((g["goal_id"], d[0], d[1], d[2]))
print("\nADDITIONAL goals listed BEFORE a goal that teaches their dependency (document order):", len(late))
for x in late[:400]: print("  ", x)
