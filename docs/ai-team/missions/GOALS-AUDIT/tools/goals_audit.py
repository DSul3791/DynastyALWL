#!/usr/bin/env python3
"""GOALS-AUDIT pass-1/2 static analysis (audit tooling only; reads data, writes nothing outside --out).

Parses docs/design/PLAYER_GOALS_REWARDS_DRAFT.md into one record per goal, cross-checks every
craft/build goal against data/items (recipes, blueprints, structures, items, groups), builds the
producer graph and an obtainability fixed point, and writes JSON for the ledger/report builders.

Usage: python3 goals_audit.py <repo_root> <out_dir>
"""
import json, re, sys, os, collections

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = sys.argv[2] if len(sys.argv) > 2 else "."
DRAFT = os.path.join(ROOT, "docs/design/PLAYER_GOALS_REWARDS_DRAFT.md")
D = lambda p: json.load(open(os.path.join(ROOT, "data", p)))

items_doc = D("items/items.json")["items"]
gathered = D("items/gathered.json")["items"]
ITEMS = dict(items_doc)
for k, v in gathered.items():
    ITEMS.setdefault(k, dict(v, _table="gathered"))
RECIPES = D("items/recipes.json")["recipes"]
BPS = D("items/blueprints.json")["blueprints"]
STRUCTS = D("items/structures.json")["structures"]
WOOD = D("items/wood_species.json")
GROUPS = {g: [g] + m for g, m in WOOD["ingredient_groups"].items() if isinstance(m, list)}
GROUP_LABELS = WOOD.get("group_labels", {})
HAMMER_TIER = {v["tier"]: k for k, v in items_doc.items() if v.get("tool_class") == "hammer"}

def iname(i):
    if i in GROUP_LABELS:
        return GROUP_LABELS[i]
    return ITEMS.get(i, {}).get("name", i)

def live_item(i):
    e = ITEMS.get(i)
    return bool(e) and not e.get("retired") and not e.get("future")

# ---------------------------------------------------------------- draft parsing
ROW = re.compile(r"^\| \*\*(?P<title>.+?)\*\* — (?P<how>.*?)\s*<!-- (?P<marker>[^>]*?) -->\s*\| (?P<rtext>.*?) <!-- coin_copper:(?P<cc>-?\d+) --> \|\s*$")
goals = []
section = sub = ""
for ln, line in enumerate(open(DRAFT, encoding="utf-8"), 1):
    if line.startswith("## "):
        section = line[3:].strip(); sub = ""
    elif line.startswith("### "):
        sub = line[4:].strip()
    if not line.startswith("| **"):
        continue
    m = ROW.match(line.rstrip("\n"))
    if not m:
        raise SystemExit("unparsed goal row at line %d" % ln)
    parts = [p.strip() for p in m["marker"].split(";")]
    kind, key = parts[0].split(":", 1)
    ref = dict(p.split(":", 1) for p in parts[1:])
    gid = key if kind == "existing" else "%s:%s" % (kind, key)
    route = "MAIN" if section.startswith("1.") else "ADDITIONAL"
    lvl = re.search(r"dependency level (\d+)", sub)
    goals.append(dict(goal_id=gid, line=ln, title=m["title"], how=m["how"], kind=kind, key=key, ref=ref,
                      route=route, section=sub or section, dep_level=int(lvl.group(1)) if lvl else None,
                      reward_text=m["rtext"].strip(), coin_copper=int(m["cc"])))

# reward text must agree with coin_copper
DEN = {"copper": 1, "bronze": 10, "silver": 100, "gold": 1000}
def text_value(t):
    return sum(int(n) * DEN[d] for n, d in re.findall(r"(\d+) (copper|bronze|silver|gold)", t))

def canonical_text(cc):
    out = []
    for d in ("gold", "silver", "bronze", "copper"):
        n, cc = divmod(cc, DEN[d])
        if n: out.append("%d %s" % (n, d))
    return " + ".join(out) or "0 copper"

# ---------------------------------------------------------------- producer graph
producers = collections.defaultdict(list)   # item -> list of producer dicts
for rk, r in RECIPES.items():
    if r.get("retired"):
        continue
    producers[r["gives"][0]].append(dict(type="recipe", ref=rk, needs=r["needs"], keeps=r.get("keeps", []),
                                         station=r.get("station", ""), level=r.get("station_level", 1),
                                         gives=r["gives"][1], locked=bool(r.get("locked")), known=bool(r.get("known"))))
bp_by_struct = collections.defaultdict(list)
for bk, b in BPS.items():
    bp_by_struct[b["structure"]].append(bk)

# stations: station id -> list of (structure kind, level)
station_providers = collections.defaultdict(list)
for sk, s in STRUCTS.items():
    if s.get("retired"):
        continue
    if s.get("station"):
        station_providers[s["station"]].append((sk, s.get("station_level", 1)))
    for st, lv in (s.get("also") or {}).items():
        station_providers[st].append((sk, lv))
# campfire is a fire entity (structures.json top-level 'campfire'), placed from campfire_kit
station_providers["campfire"].append(("campfire", 1))
addon_of = {sk: s["addon_of"] for sk, s in STRUCTS.items() if s.get("addon_of") and not s.get("retired")}

def struct_routes(sk):
    """How a structure kind gets into the world: live blueprints and/or placing its kit/item."""
    out = []
    for bk in bp_by_struct.get(sk, []):
        b = BPS[bk]
        if not b.get("retired"):
            out.append(dict(type="blueprint", ref=bk, needs=b["cost"], hammer=b.get("hammer", 1),
                            locked=bool(b.get("locked")), known=bool(b.get("known")), near=b.get("near"), near_level=b.get("near_level")))
    s = STRUCTS.get(sk, {})
    for it in {s.get("kit"), s.get("item")} - {None, ""}:
        if any(not producers_is_retired(p) for p in producers.get(it, [])):
            out.append(dict(type="place_item", ref=it, needs=[[it, 1]]))
    return out

def producers_is_retired(p):
    return False

# ---------------------------------------------------------------- raw acquisition evidence (data mentions)
SKIP = {"items/items.json", "items/gathered.json", "items/recipes.json", "items/blueprints.json", "items/encyclopedia.json",
        "items/looks.json", "items/look_placeholders.json", "items/weights.json", "items/descriptions_voice.json",
        "items/gathered_text.json", "items/wood_species.json", "items/renames.json", "items/showroom.json",
        "items/structures.json", "items/starter_goals.json", "items/camp_goals.json", "items/design_names.json",
        "items/hints.json", "items/item_uses.json", "items/spoilage.json", "items/food_effects.json", "items/worn.json",
        "items/clothing.json", "items/protection.json", "items/warmth.json", "items/comfort.json", "items/building_wear.json",
        "items/eat_memory.json", "items/inner_voice.json", "items/inner_voice_sets.json", "items/inner_voice_classes.json"}
mentions = collections.defaultdict(list)
def walk(o, path, fname):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ITEMS and not k.startswith("_") and fname not in ("tables/biomes.json",):
                mentions[k].append("%s:%s" % (fname, path + "/" + k + "(key)"))
            walk(v, path + "/" + str(k), fname)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, path + "[%d]" % i, fname)
    elif isinstance(o, str) and o in ITEMS:
        mentions[o].append("%s:%s" % (fname, path))
for sub_dir in ("items", "tables"):
    for f in sorted(os.listdir(os.path.join(ROOT, "data", sub_dir))):
        rel = "%s/%s" % (sub_dir, f)
        if not f.endswith(".json") or rel in SKIP:
            continue
        try:
            walk(json.load(open(os.path.join(ROOT, "data", rel))), "", rel)
        except Exception:
            pass

# ---------------------------------------------------------------- obtainability fixed point
# Base: items with a non-recipe data mention (candidate world source). Verified separately by the acquisition workstream;
# this pass reports 'candidate' vs 'none'.
raw_candidates = {i for i in ITEMS if mentions.get(i) and live_item(i)}
obtain = {}            # item -> depth
built = {}             # structure -> depth
stations = {}          # station -> {level: depth}
def have_station(st, lv):
    return min([d for l, d in stations.get(st, {}).items() if l >= lv], default=None)
def have_any(i):
    ids = GROUPS.get(i, [i])
    ds = [obtain[x] for x in ids if x in obtain]
    return min(ds) if ds else None
for i in raw_candidates:
    obtain[i] = 0
changed = True
while changed:
    changed = False
    for it, plist in producers.items():
        for p in plist:
            if p["locked"]:
                continue
            ds = [have_any(n[0]) for n in p["needs"] + p["keeps"]]
            if None in ds:
                continue
            sd = 0
            if p["station"]:
                sd = have_station(p["station"], p["level"])
                if sd is None:
                    continue
            d = max(ds + [sd]) + 1
            if obtain.get(it, 10**9) > d:
                obtain[it] = d; changed = True
    for sk in STRUCTS:
        if STRUCTS[sk].get("retired"):
            continue
        for r in struct_routes(sk):
            ds = [have_any(n[0]) for n in r["needs"]]
            if r["type"] == "blueprint":
                ds.append(have_any(HAMMER_TIER.get(r["hammer"], "wooden_hammer")))
                if r.get("near"):
                    ds.append(have_station(r["near"], r.get("near_level") or 1))
            if None in ds or (r.get("locked")):
                continue
            d = max(ds) + 1
            if built.get(sk, 10**9) > d:
                built[sk] = d; changed = True
            s = STRUCTS[sk]
            provs = [(s["station"], s.get("station_level", 1))] if s.get("station") else []
            provs += list((s.get("also") or {}).items())
            if sk == "campfire":
                provs = [("campfire", 1)]
            for st, lv in provs:
                cur = stations.setdefault(st, {})
                if cur.get(lv, 10**9) > d:
                    cur[lv] = d; changed = True
    # add-ons raise station level by one per kind (server_items station_level_of) unless adds_level false
    for ak, host in addon_of.items():
        if ak in built and STRUCTS[ak].get("adds_level", True) is not False:
            for sk, s in STRUCTS.items():
                if s.get("station") == host and sk in built:
                    lv = s.get("station_level", 1) + 1
                    d = max(built[ak], built[sk]) + 1
                    cur = stations.setdefault(host, {})
                    if cur.get(lv, 10**9) > d:
                        cur[lv] = d; changed = True
    if have_any("campfire_kit") is not None:
        d = have_any("campfire_kit") + 1
        if stations.setdefault("campfire", {}).get(1, 10**9) > d:
            stations["campfire"][1] = d; built["campfire"] = d; changed = True

# ---------------------------------------------------------------- per-goal static checks
MAT = re.compile(r"Materials: (.*?)\.(?: |$)")
UNITS = re.compile(r"This recipe produces (\d+) units")
KEEP = re.compile(r"Keep available \(not consumed\): (.*?)\.(?: |$)")
def parse_list(s):
    out = []
    for part in s.split(", "):
        m = re.match(r"(\d+) (.+)", part.strip())
        if m: out.append((m.group(2).strip(), int(m.group(1))))
    return sorted(out)
def needs_names(needs):
    return sorted((iname(i), n) for i, n in needs)
def needs_keynames(needs):
    return sorted((ITEMS.get(i, {}).get("name", i), n) for i, n in needs)
def same_list(stated, needs):
    """'exact' when the draft uses the in-game cost label; 'keyname' when it names a group by its key item (Spruce log for Softwood log)."""
    if stated == needs_names(needs): return "exact"
    if stated == needs_keynames(needs): return "keyname"
    return ""

name_to_ids = collections.defaultdict(set)
for k, v in ITEMS.items():
    name_to_ids[v.get("name", "")].add(k)

for g in goals:
    f = []; ev = []
    g["materials"] = g["tools"] = g["station"] = ""
    if g["kind"] == "craft":
        rks = [x for x in g["ref"].get("recipes", "").split(",") if x]
        g["listed_recipes"] = rks
        stated_m = parse_list(MAT.search(g["how"]).group(1)) if MAT.search(g["how"]) else []
        hand = "hand-crafting" in g["how"]
        match = [x for x in rks if x in RECIPES and same_list(stated_m, RECIPES[x]["needs"]) and (not RECIPES[x].get("station")) == hand]
        match = match or [x for x in rks if x in RECIPES and same_list(stated_m, RECIPES[x]["needs"])]
        rk = match[0] if match else (rks[0] if rks else "")
        if any(x not in RECIPES for x in rks): f.append("LISTED_RECIPE_MISSING")
        if any(RECIPES.get(x, {}).get("retired") for x in rks): f.append("LISTED_RECIPE_RETIRED")
        r = RECIPES.get(rk)
        ev.append("recipes.json:%s" % rk)
        if not r:
            f.append("REF_MISSING_RECIPE")
        else:
            if r.get("retired"): f.append("RECIPE_RETIRED")
            if r.get("locked"): f.append("RECIPE_LOCKED")
            if r["gives"][0] != g["key"]: f.append("RECIPE_GIVES_OTHER:%s" % r["gives"][0])
            stated = parse_list(MAT.search(g["how"]).group(1)) if MAT.search(g["how"]) else []
            sm = same_list(stated, r["needs"])
            if not sm: f.append("MATERIALS_MISMATCH")
            elif sm == "keyname": f.append("GROUP_SHOWN_AS_KEY_ITEM")
            u = UNITS.search(g["how"]); n_out = r["gives"][1]
            if (int(u.group(1)) if u else 1) != n_out: f.append("UNITS_MISMATCH:data=%d" % n_out)
            k = KEEP.search(g["how"])
            kl = parse_list(k.group(1)) if k else []
            km = same_list(kl, r.get("keeps", [])) if (kl or r.get("keeps")) else "exact"
            if not km: f.append("KEEPS_MISMATCH")
            elif km == "keyname": f.append("GROUP_SHOWN_AS_KEY_ITEM")
            st = r.get("station", "")
            if st and STRUCTS.get(st, {}).get("retired") is True and st not in station_providers: pass
            if st and not station_providers.get(st): f.append("STATION_NO_LIVE_PROVIDER:%s" % st)
            if st and have_station(st, r.get("station_level", 1)) is None: f.append("STATION_UNREACHABLE:%s@%d" % (st, r.get("station_level", 1)))
            if not st and "hand-crafting" not in g["how"]: f.append("HANDCRAFT_NOT_STATED")
            if st and "hand-crafting" in g["how"]: f.append("STATION_TEXT_SAYS_HAND")
            g["materials"] = "; ".join("%s x%d" % (i, n) for i, n in r["needs"])
            g["tools"] = "; ".join("%s x%d (kept)" % (i, n) for i, n in r.get("keeps", []))
            g["station"] = ("%s L%d" % (st, r.get("station_level", 1))) if st else "hand"
            alts = [p["ref"] for p in producers.get(g["key"], []) if p["ref"] != rk]
            g["alt_recipes"] = alts
        it = ITEMS.get(g["key"])
        if not it: f.append("ITEM_MISSING")
        else:
            if it.get("retired"): f.append("ITEM_RETIRED")
            if it.get("future"): f.append("ITEM_FUTURE")
            tname = re.sub(r"^(Craft|Make an?|Make) ", "", g["title"])
            if tname != it["name"]: f.append("TITLE_NAME_DIFFERS:%s" % it["name"])
        if g["key"] not in obtain: f.append("OUTPUT_NOT_OBTAINABLE_STATIC")
    elif g["kind"] == "build":
        sk = g["ref"].get("structure", g["key"])
        ev.append("structures.json:%s" % sk)
        s = STRUCTS.get(sk)
        bks = [b for b in bp_by_struct.get(sk, [])]
        live = [b for b in bks if not BPS[b].get("retired")]
        if not s: f.append("STRUCT_MISSING")
        elif s.get("retired"): f.append("STRUCT_RETIRED")
        if not live:
            f.append("NO_LIVE_BLUEPRINT")
        else:
            b = BPS[g["key"]] if g["key"] in BPS and not BPS[g["key"]].get("retired") else BPS[live[0]]
            bk = g["key"] if g["key"] in BPS else live[0]
            ev.append("blueprints.json:%s" % bk)
            if b.get("locked"): f.append("BLUEPRINT_LOCKED")
            if not b.get("known"): f.append("BLUEPRINT_NOT_KNOWN")
            stated = parse_list(MAT.search(g["how"]).group(1)) if MAT.search(g["how"]) else []
            sm = same_list(stated, b["cost"]) if stated else "exact"
            if not sm: f.append("MATERIALS_MISMATCH")
            elif sm == "keyname": f.append("GROUP_SHOWN_AS_KEY_ITEM")
            if not stated: f.append("MATERIALS_NOT_STATED")
            h = b.get("hammer", 1)
            if "metal hammer" in g["how"] and h < 3: f.append("HAMMER_TEXT_METAL_BUT_TIER%d" % h)
            if "building hammer" in g["how"] and h >= 3: f.append("HAMMER_TEXT_ANY_BUT_TIER%d" % h)
            tname = re.sub(r"^Build (an? )?", "", g["title"])
            if tname != b["name"]: f.append("TITLE_NAME_DIFFERS:%s" % b["name"])
            if len(live) > 1: g["alt_recipes"] = live
            g["materials"] = "; ".join("%s x%d" % (i, n) for i, n in b["cost"])
            g["tools"] = "%s (hammer tier >= %d)" % (HAMMER_TIER.get(h, "?"), h)
            g["station"] = ("near %s L%s" % (b["near"], b.get("near_level", 1))) if b.get("near") else "none (hammer placement)"
        if sk not in built: f.append("STRUCT_NOT_BUILDABLE_STATIC")
    elif g["kind"] == "gather":
        it = ITEMS.get(g["key"])
        if not it: f.append("ITEM_MISSING")
        g["materials"] = "(gathered)"
        if g["key"] not in raw_candidates: f.append("NO_DATA_SOURCE_MENTION")
    if g["kind"] == "craft": g["recipe_used"] = rk
    g["static_flags"] = f
    g["evidence"] = ev
    g["obtain_depth"] = obtain.get(g["key"]) if g["kind"] in ("craft", "gather") else built.get(g["ref"].get("structure", g["key"]))
    tv = text_value(g["reward_text"])
    g["reward_text_ok"] = tv == g["coin_copper"]
    g["reward_text_canonical"] = canonical_text(g["coin_copper"]) == g["reward_text"]

# ---------------------------------------------------------------- coverage: eligible craft/build outputs not in goals
goal_craft = {g["key"] for g in goals if g["kind"] in ("craft", "gather")}
goal_build = {g["ref"].get("structure", g["key"]) for g in goals if g["kind"] == "build"}
uncovered_items = sorted(i for i, pl in producers.items() if live_item(i) and i not in goal_craft and any(not p["locked"] for p in pl))
uncovered_structs = sorted(sk for sk in STRUCTS if not STRUCTS[sk].get("retired") and any(r["type"] == "blueprint" and not r.get("locked") for r in struct_routes(sk)) and sk not in goal_build)

# items referenced by goals that have no live producer and no data mention
unsourced = collections.Counter()
for g in goals:
    if g["kind"] == "craft" and g.get("recipe_used") in RECIPES:
        for i, n in RECIPES[g["recipe_used"]]["needs"] + RECIPES[g["recipe_used"]].get("keeps", []):
            if have_any(i) is None: unsourced[i] += 1
    if g["kind"] == "build" and g["key"] in BPS:
        for i, n in BPS[g["key"]]["cost"]:
            if have_any(i) is None: unsourced[i] += 1

summary = dict(goal_count=len(goals), main=sum(g["route"] == "MAIN" for g in goals),
               additional=sum(g["route"] == "ADDITIONAL" for g in goals),
               by_kind=collections.Counter(g["kind"] for g in goals),
               total_copper=sum(g["coin_copper"] for g in goals),
               main_copper=sum(g["coin_copper"] for g in goals if g["route"] == "MAIN"),
               reward_text_bad=[g["goal_id"] for g in goals if not g["reward_text_ok"]],
               reward_text_noncanonical=[g["goal_id"] for g in goals if not g["reward_text_canonical"]],
               flag_counts=collections.Counter(fl.split(":")[0] for g in goals for fl in g["static_flags"]),
               uncovered_items=uncovered_items, uncovered_structs=uncovered_structs,
               unsourced_inputs=unsourced.most_common(),
               unreachable_stations=sorted(st for st in station_providers if st not in stations),
               station_levels={st: sorted(v) for st, v in stations.items()})
os.makedirs(OUT, exist_ok=True)
json.dump(goals, open(os.path.join(OUT, "goals_parsed.json"), "w"), indent=1)
json.dump(summary, open(os.path.join(OUT, "pass1_summary.json"), "w"), indent=1, default=list)
json.dump({i: mentions[i][:12] for i in sorted(mentions)}, open(os.path.join(OUT, "source_mentions.json"), "w"), indent=1)
json.dump(dict(obtain=obtain, built=built, stations=stations), open(os.path.join(OUT, "obtainability.json"), "w"), indent=1)
print(json.dumps({k: v for k, v in summary.items() if k not in ("uncovered_items",)}, indent=1, default=list)[:6000])
print("uncovered items:", len(uncovered_items))
