#!/usr/bin/env python3
"""Progression check: walk every crafting chain in the data, from bare hands to steel, and list what breaks it.

Coordinator brief, 23 Nov 2026 (thread "Walk the crafting progression end to end", for Dave's roadmap layer 2, a full crafting and survival
playthrough): build the dependency graph from the data files and report dead ends, unreachable items, circular needs, recipes whose inputs
nothing produces, items nothing uses and stations with no way to be built. Dave 23 Nov 2026: "we are not gate keeping by limiting resources",
so it also lists chains held back by stingy yields.

It reuses the reach model of tools/encyclopedia_reach.py (what a player starting with empty hands can get, the server's rules for stations,
levels, tools and smelting) and the stage model of tools/goal_stage_audit.py (stone, copper, bronze, iron, steel). Report only: it edits nothing.

    python3 tools/progression_check.py            # the report (markdown) on stdout
    python3 tools/progression_check.py --check    # exit 1 on a hard break: an unknown id, an active row that can never run, a station
                                                  # short of the level asked, a circular need (all 0 on dev 2aa2ea24)
    python3 tools/progression_check.py --unmarked # exit 1 when an unused material's player text does not say "Nothing uses it yet." (section 11)

Sections:
  1 unknown ids       a recipe, blueprint, smelting job, crop, cooking row or goal names an id no data file defines
  2 unreached         live items (not retired, not future) nobody can get, with what each source lacks
  3 dead rows         active (not locked, not retired) recipes and blueprints that can never run, and why
  4 stations         every station an active row asks for: the best level a player can build, against the level asked
  5 circular needs    unreached items whose only sources need each other
  6 unused            reached live materials that no recipe, blueprint, smelter, fuel, kiln, crop or cooking row takes
  7 stage order       an item with a metal in its name or material that is first reached after a later metal stage
  8 skill gates       recipes, blueprints and stations with a skill need (none expected: skills are speed factors, skills.json)
  9 stingy yields     a recipe or blueprint needing more of a limited gathered input (a plant's harvest, a carcass part, a seed) than
                      two gathers of its best source give; plentiful inputs (stone, clay, wood, fibre) are effort, not scarcity
 10 farming seasons   every crop has a sowing season and a reachable seed
 11 unmarked          section 6 items whose description (what the pack shows) does not end with "Nothing uses it yet."
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import encyclopedia_reach as er   # noqa: E402
import goal_stage_audit as gsa    # noqa: E402

METALS = ["stone", "copper", "bronze", "iron", "steel"]
STINGY_GATHERS = 2    # a craft needing more gathers than this of its best limited source is listed in section 9
# Inputs whose source does not run out: a boulder holds hundreds of stones (boulders.json yield, 1 a pick blow), clay and sand dig without end,
# trees stand everywhere. Needing many of them costs effort and time, not scarcity, so section 9 leaves them out (Dave 23 Nov 2026: "we are not
# gate keeping by limiting resources" is about scarce inputs).
PLENTIFUL = {"stone", "clay", "sand", "soil", "gravel", "peat", "stick", "log", "firewood", "wooden_block", "leaves", "plant_fibre", "water",
             "sea_water", "kindling", "thatch", "straw", "cobblestone"}
SEASONS = {"spring", "summer", "autumn", "winter"}


def known_ids(r):
    ids = set(r.all)
    ids |= {g for g in r.wood.get("ingredient_groups", {}) if g != "note"}
    return ids


def rows(lst):
    return [row for row in lst or [] if isinstance(row, list) and row]


def recipe_inputs(rec):
    return [row[0] for k in ["needs", "keeps"] for row in rows(rec.get(k))]


def active(row):
    return not row.get("locked") and not row.get("retired") and not row.get("removed")


def unknown_ids(r):
    ids = known_ids(r)
    out = []
    for rid, rec in r.recipes.items():
        if rec.get("retired"):
            continue
        for iid in recipe_inputs(rec) + [rec.get("gives", [""])[0]]:
            if iid not in ids:
                out.append("recipe %s names %s" % (rid, iid))
    for bid, b in r.blueprints_all.items():
        if b.get("retired") or b.get("removed"):
            continue
        for row in rows(b.get("cost")):
            if row[0] not in ids:
                out.append("blueprint %s cost names %s" % (bid, row[0]))
        if b.get("structure") not in r.structures:
            out.append("blueprint %s builds unknown structure %s" % (bid, b.get("structure")))
    for jid, job in r.smelting.get("jobs", {}).items():
        for iid in [row[0] for row in rows(job.get("in"))] + [job.get("out", [""])[0]]:
            if iid not in ids:
                out.append("smelting job %s names %s" % (jid, iid))
    for cid, c in r.crops.items():
        for iid in [c.get("seed")] + [row[0] for row in rows(c.get("yields"))]:
            if iid and iid not in ids:
                out.append("crop %s names %s" % (cid, iid))
    for raw, cooked in r.cooking.get("cooks_into", {}).items():
        for iid in [raw, cooked]:
            if iid not in ids:
                out.append("cooking %s -> %s names %s" % (raw, cooked, iid))
    for gfile in ["starter_goals.json", "camp_goals.json"]:
        for g in er.read(gfile).get("goals", []):
            ch = g.get("check", {})
            for k in ["made_item", "got_item", "have_item"]:
                if ch.get(k) and ch[k] not in ids:
                    out.append("goal %s %s names %s" % (g.get("id"), k, ch[k]))
            for k in ["made_item_any", "have_item_any", "stored_item_any"]:
                for iid in ch.get(k, []):
                    if iid not in ids:
                        out.append("goal %s %s names %s" % (g.get("id"), k, iid))
            if ch.get("event") == "placed":
                for kind in ([ch["what"]] if ch.get("what") else ch.get("what_any", [])):
                    if kind not in r.structures:
                        out.append("goal %s places unknown structure %s" % (g.get("id"), kind))
    return out


def unreached(r):
    out = []
    for iid, it in sorted(r.all.items()):
        if it.get("retired") or it.get("future") or r.has(iid):
            continue
        if r.piece_removed(iid):
            continue
        out.append((iid, it.get("name", ""), "; ".join(r.blocked(iid))))
    return out


def dead_rows(r):
    """Active rows that never run in the final reach state. A row whose output is reached another way is still listed: it is an offer a player
    sees and cannot use."""
    out = []
    for rid, rec in sorted(r.recipes.items()):
        if not active(rec):
            continue
        lack = [i for i in recipe_inputs(rec) if not r.fills(i)]
        st = rec.get("station", "")
        if st and r.station_level(st) < int(rec.get("station_level", 1)):
            lack.append("station %s L%d (best L%d)" % (st, int(rec.get("station_level", 1)), r.station_level(st)))
        if lack:
            out.append(("recipe", rid, rec.get("name", ""), ", ".join(lack)))
    hammer = max([int(r.all[h].get("tier", 1) or 1) for h in r.all if r.all[h].get("tool_class") == "hammer" and r.has(h)] or [0])
    chisel = max([int(v.get("tier", 0) or 0) for k, v in r.all.items() if v.get("tool_class") == "chisel" and r.has(k)] or [0])
    for bid, b in sorted(r.blueprints_all.items()):
        if not active(b) or b.get("structure") not in r.structures:
            continue
        lack = [c[0] for c in rows(b.get("cost")) if not r.fills(c[0])]
        if b.get("tool") == "knife":
            if not r.tool("knife"):
                lack.append("a knife")
        elif hammer < int(b.get("hammer", 1)):
            lack.append("hammer tier %s (best %d)" % (b.get("hammer"), hammer))
        if int(b.get("chisel", 0) or 0) > chisel:
            lack.append("chisel tier %s (best %d)" % (b.get("chisel"), chisel))
        for key, lvl in [("station", "station_level"), ("near", "near_level")]:
            if b.get(key) and r.station_level(b[key]) < int(b.get(lvl, 1)):
                lack.append("%s %s L%d (best L%d)" % (key, b[key], int(b.get(lvl, 1)), r.station_level(b[key])))
        if lack:
            out.append(("blueprint", bid, b.get("name", ""), ", ".join(lack)))
    return out


def stations(r):
    want = {}
    for rid, rec in r.recipes.items():
        if active(rec) and rec.get("station"):
            st = rec["station"]
            want.setdefault(st, [0, []])
            want[st][0] = max(want[st][0], int(rec.get("station_level", 1)))
            want[st][1].append("r" + rid)
    for bid, b in r.blueprints_all.items():
        if active(b):
            for key, lvl in [("station", "station_level"), ("near", "near_level")]:
                if b.get(key):
                    st = b[key]
                    want.setdefault(st, [0, []])
                    want[st][0] = max(want[st][0], int(b.get(lvl, 1)))
                    want[st][1].append("b" + bid)
    out = []
    for st, (lvl, users) in sorted(want.items()):
        best = r.station_level(st)
        builders = sorted({k for k, d in r.structures.items() if d.get("station") == st or st in d.get("also", {}) or d.get("addon_of") == st})
        out.append((st, lvl, best, len(users), builders))
    return out


def circular(r, unreached_ids):
    """Unreached items whose recipe inputs lead back to themselves through other unreached items (Tarjan's SCCs on the unreached graph)."""
    graph = {}
    for rid, rec in r.recipes.items():
        if not active(rec):   # a locked row is no circle a player meets
            continue
        g = rec.get("gives", [""])[0]
        if g in unreached_ids:
            graph.setdefault(g, set()).update(i for i in recipe_inputs(rec) if i in unreached_ids)
    index, low, stack, on, sccs, n = {}, {}, [], set(), [], [0]

    def visit(v):
        index[v] = low[v] = n[0]
        n[0] += 1
        stack.append(v)
        on.add(v)
        for w in graph.get(v, ()):
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1 or v in graph.get(v, ()):
                sccs.append(sorted(comp))

    for v in list(graph):
        if v not in index:
            visit(v)
    return sccs


def consumers(r):
    used = set()
    for rec in r.recipes.values():
        if active(rec):
            used.update(recipe_inputs(rec))
    for b in r.blueprints_all.values():
        if active(b):
            used.update(c[0] for c in rows(b.get("cost")))
    for job in r.smelting.get("jobs", {}).values():
        used.update(row[0] for row in rows(job.get("in")))
    used.update(r.smelting.get("fuel", []))
    kilns = er.read("structures.json").get("kilns", {})
    used.update(kilns.get("yield", {}).keys() if isinstance(kilns.get("yield"), dict) else [])
    for d in r.structures.values():
        for k in ["fuel", "takes"]:
            v = d.get(k)
            if isinstance(v, list):
                used.update(x for x in v if isinstance(x, str))
            elif isinstance(v, dict):
                used.update(v.keys())
    for c in r.crops.values():
        used.add(c.get("seed"))
    used.update(r.cooking.get("cooks_into", {}).keys())
    # Everything else a data file names (eating, sickness, comfort, fuels, worn, goals, shops): a use the code reads, not a recipe. The files that only
    # describe or draw an item are left out, so an item named only there is still unused.
    describe = {"items.json", "gathered.json", "encyclopedia.json", "looks.json", "weights.json", "descriptions_voice.json", "gathered_text.json",
                "item_uses.json", "renames.json", "id_renames.json", "design_names.json", "hints.json", "look_placeholders.json", "showroom.json",
                "recipes.json", "blueprints.json", "structures.json", "drops.json", "digging.json", "carcass.json", "nests.json", "shore_nodes.json",
                "fishing.json", "fish_schools.json", "boulders.json", "crops.json"}
    folder = os.path.join(er.ROOT, "data", "items")
    for name in sorted(os.listdir(folder)):
        if name.endswith(".json") and name not in describe and not name.startswith("inner_voice"):
            with open(os.path.join(folder, name), encoding="utf-8") as f:
                used.update(re.findall(r'"([a-z0-9_]+)"', f.read()))
    for d in r.structures.values():   # a laid run or placed piece whose item is the piece itself (Copper - Pipe, Copper - Tap)
        if d.get("item") == d.get("kit"):
            used.add(d.get("item"))
    used.update(k for k in r.all if k.endswith("_bush"))   # dug-up bushes are planted again (ACT_PLANT_BUSH)
    used.update(r.drops.get("trunk", {}).get("felled_seeds", {}).get("by_species", {}).values())   # tree seeds plant as saplings (ACT_PLANT_BUSH)
    groups = r.wood.get("ingredient_groups", {})
    for gid, members in groups.items():
        if gid in used and isinstance(members, list):
            used.update(members)
    return used


# Uses the code or a source file gives that consumers() cannot see; each with its reason.
CODE_USES = {
    "compost": "spread on a tilled bed (server_items.gd crop compost)",
    "fishing_bait": "bait for the rod (fishing.json)",
    "copper_pipe": "laid from the hand (PLUMBING_DESIGN s9)", "copper_tap": "laid from the hand (PLUMBING_DESIGN s9)",
    "copper_drip_head": "laid from the hand (PLUMBING_DESIGN s9)",
    "agate": "sold", "amethyst": "sold", "garnet": "sold", "gold_nugget": "sold", "silver_ore": "sold",   # sell-only finds (#1469)
    "claw": "sold", "soap": "sold",
}


def unused(r):
    used = consumers(r) | set(CODE_USES)
    notes = er.read("item_uses.json").get("uses", {})
    out = []
    for iid, it in sorted(r.all.items()):
        if it.get("retired") or not r.has(iid) or iid in used:
            continue
        kind = it.get("kind")
        if kind not in ("material", None) and iid not in r.gathered:
            continue   # food, tools, clothing, weapons, structures and gear have their own use
        if it.get("fuel") or it.get("ammo_class") or it.get("tool_class"):
            continue
        if kind is None and iid in r.gathered and r.gathered[iid].get("kind") not in ("material",):
            continue
        out.append((iid, it.get("name", ""), notes.get(iid, "")))
    return out


NO_USE_MARK = "Nothing uses it yet."   # said in the player's own text (the pack tooltip shows the description) for an item with no use yet


def unmarked(r, unused_rows):
    """Unused reached materials whose player text does not say they have no use yet: a tester who finds one doing nothing would file a bug
    (coordinator 23 Nov 2026: mark it honestly where the player sees it). Give it a use, or end its description with NO_USE_MARK."""
    out = []
    for iid, name, _note in unused_rows:
        text = str(r.all.get(iid, {}).get("description", "")) or str(r.gathered.get(iid, {}).get("description", ""))
        if NO_USE_MARK not in text:
            out.append((iid, name))
    return out


def stage_order(items_stage):
    data = er.read("items.json")["items"]
    out = []
    for iid, st in sorted(items_stage.items()):
        it = data.get(iid, {})
        mat = it.get("material", "")
        named = next((m for m in METALS if iid.startswith(m + "_")), "")
        metal = mat if mat in METALS else named
        if metal and METALS.index(st) > METALS.index(metal):
            out.append((iid, it.get("name", ""), metal, st))
    return out


def skill_gates(r):
    out = []
    for name, table in [("recipe", r.recipes), ("blueprint", r.blueprints_all), ("structure", r.structures)]:
        for k, v in table.items():
            for key in v:
                if "skill" in key and not key.startswith("note"):
                    out.append("%s %s has %s" % (name, k, key))
    return out


def yields(r):
    """Best average gathered count per action for each item from the world sources (one E, blow or dig)."""
    best = {}

    def add(iid, avg, how):
        if iid and avg > best.get(iid, (0, ""))[0]:
            best[iid] = (avg, how)

    d = r.drops
    for group in ["by_species", "by_kind"]:
        for key, rs in d.get(group, {}).items():
            for row in rs:
                if len(row) >= 3:
                    add(row[0], (row[1] + row[2]) / 2.0, "gather %s" % key)
    scale = d.get("yield_scale", {}).get("min", 1.0)
    for key in ["harvest_yield", "berry_yield"]:
        for k, row in d.get(key, {}).items():
            for rr in row.get("by_season", {}).values() or [row]:
                add(rr.get("item"), float(rr.get("count", 0)) * scale, "%s %s" % (key.split("_")[0], k))
    for k, row in d.get("seed_drops", {}).items():
        if isinstance(row, dict):
            for rr in row.get("rows", []):
                add(rr[0], (rr[1] + rr[2]) / 2.0, "seeds %s" % k)
    for row in d.get("stump", {}).get("final", []):
        add(row[0], (row[1] + row[2]) / 2.0, "stump")
    for row in d.get("shrub_work", {}).get("axe_gives", []):
        add(row[0], (row[1] + row[2]) / 2.0, "axe on a bush")
    for row in d.get("trunk", {}).get("branch", []):
        add(row[0], (row[1] + row[2]) / 2.0 * d.get("trunk", {}).get("branch_blows", 1), "felled tree branches")
    for mat, rs in r.digging.get("yield", {}).items():
        for row in rs:
            add(row[0], (row[1] + row[2]) / 2.0, "dig %s" % mat)
    for sp, dd in r.carcass.get("species", {}).items():
        for row in dd.get("parts", []):
            add(row[0], (row[1] + row[2]) / 2.0, "%s carcass" % sp)
    for iid in er.code_sources():
        add(iid, 1.0, "picked up")
    return best


def stingy(r):
    best = yields(r)
    made = {rec.get("gives", [""])[0] for rec in r.recipes.values() if active(rec)}
    out = []

    def look(row_id, row_name, lst):
        for row in rows(lst):
            iid, n = row[0], int(row[1]) if len(row) > 1 else 1
            if iid in made or iid not in best or iid in PLENTIFUL or iid.startswith("log_"):
                continue
            avg, how = best[iid]
            if avg > 0 and n / avg > STINGY_GATHERS:
                out.append((row_id, row_name, iid, n, how, avg, n / avg))

    for rid, rec in r.recipes.items():
        if active(rec):
            look("recipe " + rid, rec.get("name", ""), rec.get("needs"))
    for bid, b in r.blueprints_all.items():
        if active(b):
            look("blueprint " + bid, b.get("name", ""), b.get("cost"))
    return sorted(out, key=lambda x: -x[6])


def farming(r):
    out = []
    for cid, c in sorted(r.crops.items()):
        seasons = set(c.get("sow_seasons") or [c.get("sow_season")])
        bad = [s for s in seasons if s not in SEASONS]
        if not seasons - {None} or bad:
            out.append("crop %s: sow seasons %s" % (cid, sorted(map(str, seasons))))
        if not r.has(c.get("seed")):
            out.append("crop %s: seed %s not reached (%s)" % (cid, c.get("seed"), "; ".join(r.blocked(c.get("seed")))))
    return out


def main(argv):
    r = er.Reach().run()
    items_stage, built_stage = gsa.first_stages()
    sec = {}
    sec["unknown"] = unknown_ids(r)
    sec["unreached"] = unreached(r)
    sec["dead"] = dead_rows(r)
    sec["stations"] = stations(r)
    sec["circular"] = circular(r, {i for i, _, _ in sec["unreached"]})
    sec["unused"] = unused(r)
    sec["stage"] = stage_order(items_stage)
    sec["skill"] = skill_gates(r)
    sec["stingy"] = stingy(r)
    sec["farming"] = farming(r)
    st_bad = [s for s in sec["stations"] if s[2] < s[1]]

    p = print
    live = [i for i, it in r.all.items() if not it.get("retired")]
    p("# Progression check\n")
    p("Reach model: %d of %d live items reached from empty hands; %d structures buildable; %d active recipes, %d active blueprints.\n"
      % (sum(1 for i in live if r.has(i)), len(live), len(r.built), sum(1 for x in r.recipes.values() if active(x)),
         sum(1 for x in r.blueprints_all.values() if active(x))))
    p("| Check | Count |\n|---|---|")
    for title, n in [("1 unknown ids", len(sec["unknown"])), ("2 unreached live items", len(sec["unreached"])),
                     ("3 dead active rows", len(sec["dead"])), ("4 stations short of the level asked", len(st_bad)),
                     ("5 circular needs", len(sec["circular"])), ("6 unused reached materials", len(sec["unused"])),
                     ("7 stage order", len(sec["stage"])), ("8 skill gates", len(sec["skill"])),
                     ("9 stingy yields (> %d gathers a craft)" % STINGY_GATHERS, len(sec["stingy"])), ("10 farming", len(sec["farming"]))]:
        p("| %s | %d |" % (title, n))
    p("\n## 1 Unknown ids")
    for x in sec["unknown"]:
        p("- " + x)
    p("\n## 2 Unreached live items")
    for iid, name, why in sec["unreached"]:
        p("- `%s` %s: %s" % (iid, name, why))
    p("\n## 3 Dead active rows")
    for kind, rid, name, why in sec["dead"]:
        p("- %s %s %s: lacks %s" % (kind, rid, name, why))
    p("\n## 4 Stations (asked level, best buildable level, rows using it, structures giving it)")
    for st, lvl, best, n, builders in sec["stations"]:
        p("- %s`%s` asked L%d, best L%d, %d rows; %s" % ("**SHORT** " if best < lvl else "", st, lvl, best, n, ", ".join(builders) or "no structure"))
    p("\n## 5 Circular needs")
    for comp in sec["circular"]:
        p("- " + " <-> ".join(comp))
    p("\n## 6 Unused reached materials (no active row, smelter, fuel, kiln, crop or cooking row takes them; item_uses.json line if any)")
    for iid, name, note in sec["unused"]:
        p("- `%s` %s%s" % (iid, name, (": " + note) if note else ""))
    p("\n## 7 Stage order (item, its metal, first stage reached)")
    for iid, name, metal, st in sec["stage"]:
        p("- `%s` %s: %s, first reached at %s" % (iid, name, metal, st))
    p("\n## 8 Skill gates")
    for x in sec["skill"]:
        p("- " + x)
    p("\n## 9 Stingy yields (row, input, amount, best source, per action, actions a craft). Ore, ingots, crops and felled-trunk drops are not"
      " in this table (tools/progression_effort.py counts them per stage); the oak's Tannin bark is per felled tree")
    for rid, name, iid, n, how, avg, acts in sec["stingy"]:
        p("- %s %s: %d `%s`; best %s gives %.1f an action: %.0f actions" % (rid, name, n, iid, how, avg, acts))
    p("\n## 10 Farming")
    for x in sec["farming"]:
        p("- " + x)
    sec["unmarked"] = unmarked(r, sec["unused"])
    p("\n## 11 Unused and not marked (no use, and the player's text does not say \"%s\")" % NO_USE_MARK)
    for iid, name in sec["unmarked"]:
        p("- `%s` %s" % (iid, name))
    if "--unmarked" in argv:
        return 1 if sec["unmarked"] else 0
    hard = len(sec["unknown"]) + len(sec["dead"]) + len(st_bad) + len(sec["circular"])
    return 1 if "--check" in argv and hard else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
