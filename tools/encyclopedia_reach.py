#!/usr/bin/env python3
"""Recompute data/items/encyclopedia.json obtainable_now (and status) from the game's real sources.

Rerun this after any data change instead of hand-editing obtainable_now:

    python3 tools/encyclopedia_reach.py           # print what would flip, change nothing
    python3 tools/encyclopedia_reach.py --write   # rewrite encyclopedia.json
    python3 tools/encyclopedia_reach.py --why ID  # show how an item is reached (or why not)
    python3 tools/encyclopedia_reach.py --check   # exit 1 when encyclopedia.json is out of date

An item is obtainable now when a player can get it today, starting with empty hands:
  * a world source the data names (flora yields, harvest and berry rows, tree, stump and shrub drops, felled tree seeds, digging, boulders,
    flint, shore nodes, fishing and fish schools, carcass parts, nests, the validator's CODE_SOURCES), gated on the tool
    the code asks for where that tool might not exist yet (a pick of the right material for ore, a spade to dig, a hoe
    and the seed to farm, an axe to fell);
  * a recipe that is not locked or retired, at a station a player can build to the level the recipe asks for
    (structures.json station + station_level, +1 per add-on kind, "also" stations), with every need and kept tool
    obtainable;
  * a hammer blueprint (not locked or retired) whose cost, hammer tier, station and "near" piece are all reachable
    builds its structure, and so its station;
  * cooking.json cooks_into from a raw item at a fire, spoilage rotten_item, doused_item/relit_item twins, and an
    ingredient group when any member is.

The "future" flag in items.json is NOT a source here (validate_items.gd counts future materials so it can check the
recipe graph; that is a different question). The script lists items whose future flag disagrees with what it finds.

status: "planned" when the item is not obtainable now, "retired" when items.json retires it (a kit row excepted: it stands for its
piece), removed when it is obtainable; retired items are never obtainable.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = os.path.join(ROOT, "data", "items")
ENC = os.path.join(ITEMS, "encyclopedia.json")

# World facts the data files cannot show. Each names who said so and when; remove a row when the world changes.
ORE_NOT_IN_WORLD = {
    "iron": "both iron bodies on the nine baked tiles lie under the sea (Sonny, 10 Nov 2026); land iron comes from bog iron (digging.json, #996)",
}


def read(name, folder=ITEMS):
    with open(os.path.join(folder, name), encoding="utf-8") as f:
        return json.load(f)


def code_sources():
    """The validator's CODE_SOURCES: items the code hands out with no data row (stone, stick, bark ...)."""
    with open(os.path.join(ROOT, "src", "worldgen", "tools", "validate_items.gd"), encoding="utf-8") as f:
        m = re.search(r"const CODE_SOURCES := \[([^\]]*)\]", f.read())
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


class Reach:
    def __init__(self):
        self.items = read("items.json")["items"]
        self.gathered = read("gathered.json")["items"]
        self.all = dict(self.items)
        self.all.update(self.gathered)
        self.recipes = read("recipes.json")["recipes"]
        self.blueprints = read("blueprints.json")["blueprints"]
        self.structures = read("structures.json")["structures"]
        self.smelting = read("structures.json").get("smelting", {})
        self.drops = read("drops.json")
        self.digging = read("digging.json")
        self.boulders = read("boulders.json")
        self.shore = read("shore_nodes.json")
        self.carcass = read("carcass.json")
        self.cooking = read("cooking.json")
        self.spoilage = read("spoilage.json")
        self.fishing = read("fishing.json")
        self.schools = read("fish_schools.json")
        self.nests = read("nests.json")
        self.crops = read("crops.json")["crops"]
        self.wood = read("wood_species.json")
        self.flora = read("flora.json", os.path.join(ROOT, "data", "tables"))["entries"]
        self.why = {}          # item id -> how it was first reached
        self.built = {}        # structure kind -> how it was first built

    def live(self, iid):
        return iid in self.all and not self.all[iid].get("retired")

    def give(self, iid, how, kit=False):
        # A kit row is retired (Dave 4 Nov 2026: no kits, the hammer builds from the pack) but stays the encyclopedia's entry for its piece.
        if iid and iid not in self.why and (self.live(iid) or (kit and iid in self.all)):
            self.why[iid] = how
            return True
        return False

    def has(self, iid):
        return iid in self.why

    def fills(self, iid):
        """A cost or need is met by the item itself or, for a group id (wood_species.json ingredient_groups), by any member."""
        members = self.wood.get("ingredient_groups", {}).get(iid, [])
        return self.has(iid) or (isinstance(members, list) and any(self.has(m) for m in members))

    def tool(self, tool_class, materials=None, min_tier=0):
        for iid, it in self.all.items():
            if it.get("tool_class") == tool_class and self.has(iid):
                if materials is not None and it.get("material") not in materials:
                    continue
                if int(it.get("tier", 1) or 1) < min_tier:
                    continue
                return iid
        return None

    # A station's best level from the structures built so far (server_items.gd station_level_of + _addon_kinds).
    def station_level(self, station):
        if station == "campfire" and self.has("campfire_kit"):
            best = 1
        else:
            best = 0
        addons = sum(1 for k in self.built if self.structures[k].get("addon_of") == station)
        for kind in self.built:
            d = self.structures[kind]
            if d.get("station") == station:
                best = max(best, int(d.get("station_level", 1)) + addons)
            best = max(best, int(d.get("also", {}).get(station, 0)))
        return best

    def seed(self):
        twins = {it.get("doused_item") for it in self.all.values() if it.get("doused_item")}
        for iid in code_sources():
            if iid not in twins:   # a doused twin (torch_doused, the dark lanterns) comes only from its lit item, below
                self.give(iid, "handed out by the code (CODE_SOURCES)")
        yields = {str(y) for e in self.flora for y in e.get("yields", [])}
        for iid in self.gathered:
            if iid in yields:
                self.give(iid, "a flora yield")
        for key, row in self.drops.get("harvest_yield", {}).items():
            self.give(row.get("item"), "harvested from %s" % key)
        for key, row in self.drops.get("berry_yield", {}).items():
            self.give(row.get("item"), "picked from %s" % key)
        for row in self.drops.get("stump", {}).get("chip", []) + self.drops.get("stump", {}).get("final", []):
            self.give(row[0], "chopped from a stump")
        for row in self.drops.get("shrub_work", {}).get("axe_gives", []):
            self.give(row[0], "an axe on a bush")
        for key, row in self.drops.get("seed_drops", {}).items():
            if isinstance(row, dict):
                for r in row.get("rows", []):
                    self.give(r[0], "seeds from %s" % key)
        for r in self.shore.get("nodes", []):
            self.give(r.get("item"), "a shore node (%s)" % r.get("kind"))
        self.give(self.shore.get("sea_water_item"), "filled at the sea")
        for water, rows in self.fishing.get("species", {}).items():
            for r in rows:
                self.give(r[0], "fished in a %s" % water)
        for kind, rows in self.schools.get("species_by_kind", {}).items():
            for r in rows:
                self.give(r[0], "a %s fish school" % kind)
        for sp, d in self.carcass.get("species", {}).items():
            for r in d.get("parts", []):
                self.give(r[0], "from a %s carcass" % sp)
        for kind, d in self.nests.get("kinds", {}).items():
            self.give(d.get("item"), "a %s nest" % kind)
            if d.get("extra"):
                self.give(d["extra"][0], "a %s nest" % kind)
        self.give(self.boulders.get("flint", {}).get("item"), "a flint nodule")

    def step(self):
        changed = False
        g = self.give
        axe = self.tool("axe")
        if axe:
            for group in ["by_species", "by_kind"]:
                for key, rows in self.drops.get(group, {}).items():
                    for r in rows:
                        changed |= g(r[0], "felled %s (%s)" % (key, axe))
            # server_items.gd _log_number: a felled tree gives log_<species>, or the plain Log when that item is missing or retired;
            # _wood_item: stump firewood is the species' class firewood (wood_species.json class_items).
            for e in self.flora:
                if e.get("kind") == "tree":
                    log = "log_" + e["name"]
                    changed |= g(log if self.live(log) else "log", "a felled %s (%s)" % (e["name"], axe))
                    cls = self.wood.get("species", {}).get(e["name"], self.wood.get("default", {})).get("class", "hardwood")
                    changed |= g(self.wood.get("class_items", {}).get(cls, {}).get("firewood"), "a %s stump (%s)" % (e["name"], axe))
            trunk = self.drops.get("trunk", {})
            if trunk.get("roots"):
                changed |= g(trunk["roots"][0], "the root ball of a felled tree")
            for sp, rows in trunk.get("by_species", {}).items():
                for r in rows:
                    changed |= g(r[0], "a felled %s trunk" % sp)
            for r in trunk.get("branch", []):
                changed |= g(r[0], "a felled trunk's branches")
            for sp, seed in trunk.get("felled_seeds", {}).get("by_species", {}).items():   # every felled tree drops 1 to 5 of its seed (server_items._felled_seeds)
                changed |= g(seed, "the seeds of a felled %s" % sp)
        pick = self.tool("pick")
        if pick and self.drops.get("shrub_work", {}).get("dig_suffix"):
            for e in self.flora:
                if e.get("kind") == "shrub":
                    changed |= g(e["name"] + self.drops["shrub_work"]["dig_suffix"], "a shrub dug up whole (%s)" % pick)
        spade = self.tool("spade")
        if spade:
            dig = self.digging
            for mat, rows in dig.get("yield", {}).items():
                for r in rows:
                    changed |= g(r[0], "dug from %s (%s)" % (mat, spade))
            for r in dig.get("default", []):
                changed |= g(r[0], "dug (%s)" % spade)
            for mat, r in dig.get("under", {}).items():
                changed |= g(r[0], "dug under %s (%s)" % (mat, spade))
            for f in dig.get("finds", []):
                changed |= g(f.get("item"), "found digging (%s)" % spade)
            bog = dig.get("bog_iron")
            if isinstance(bog, dict):
                changed |= g(bog.get("item"), "bog iron dug in wetland mud (%s)" % spade)
        ore = self.boulders.get("ore", {})
        for name, iid in ore.get("items", {}).items():
            if name in ORE_NOT_IN_WORLD:
                continue
            p = self.tool(ore.get("tool_class", "pick"), ore.get("needs_material", {}).get(name))
            if p:
                changed |= g(iid, "a boulder over a %s body (%s)" % (name, p))
        for name, iid in ore.get("rocks", {}).items():
            p = self.tool(ore.get("tool_class", "pick"))
            if p:
                changed |= g(iid, "a boulder over %s bedrock (%s)" % (name, p))
        hoe = self.tool("hoe")
        if hoe:
            for cid, c in self.crops.items():
                if self.has(c.get("seed")):
                    for r in c.get("yields", []):
                        changed |= g(r[0], "grown from %s (%s)" % (c.get("seed"), hoe))
                    if c.get("seeds_back"):
                        changed |= g(c["seeds_back"][0], "seeds back from %s" % cid)
        if self.station_level("campfire") >= 1:
            for raw, cooked in self.cooking.get("cooks_into", {}).items():
                if self.has(raw):
                    changed |= g(cooked, "%s cooked at a fire" % raw)
            if self.cooking.get("gives"):
                changed |= g(self.cooking["gives"], "forage roasted at a fire")
        if any(self.has(i) for i in self.spoilage.get("by_id", {})):
            changed |= g(self.spoilage.get("rotten_item"), "what food rots into")
        for iid, it in self.all.items():
            if self.has(iid):
                for k in ["doused_item", "relit_item"]:
                    if it.get(k):
                        changed |= g(it[k], "%s (%s)" % (k.split("_")[0], iid))
        # A group head with no recipe of its own (plain Log, Vegetable, Fuel) stands for any member; one that is a real made item
        # (Nails, Hinges: iron, made at the brick forge) is reached only by its own recipe, though a cost asking for it takes any member.
        made = {r.get("gives", [""])[0] for r in self.recipes.values() if not r.get("retired")}
        for gid, members in self.wood.get("ingredient_groups", {}).items():
            if gid != "note" and gid not in made and isinstance(members, list) and any(self.has(m) for m in members):
                changed |= g(gid, "any member of the group")
        # Blueprints build structures (and their stations); a built structure's item and blocks count.
        hammer_tier = max([int(self.all[h].get("tier", 1) or 1) for h in self.all
                           if self.all[h].get("tool_class") == "hammer" and self.has(h)] or [0])
        for bid, b in self.blueprints.items():
            kind = b.get("structure")
            if kind in self.built or b.get("locked") or b.get("retired") or kind not in self.structures:
                continue
            if hammer_tier < int(b.get("hammer", 1)):
                continue
            if b.get("station") and self.station_level(b["station"]) < int(b.get("station_level", 1)):
                continue
            if b.get("near") and self.station_level(b["near"]) < int(b.get("near_level", 1)):
                continue
            if all(self.fills(c[0]) for c in b.get("cost", [])):
                self.built[kind] = "blueprint %s" % bid
                changed = True
        for kind, d in self.structures.items():
            if kind not in self.built and d.get("kit") and self.has(d["kit"]):
                self.built[kind] = "placed from %s" % d["kit"]
                changed = True
        # Pieces the code lays down itself: a hoe tills a bed or wears a path, a kill leaves a carcass, a death leaves remains.
        code_laid = {"carcass": "an animal killed" if self.carcass.get("species") else None, "remains": "what a death leaves"}
        if hoe:
            code_laid.update({"tilled_bed": "ground tilled with a %s" % hoe, "path_patch": "a path laid with a %s" % hoe})
        for kind, how in code_laid.items():
            if how and kind in self.structures and kind not in self.built:
                self.built[kind] = how
                changed = True
        # A built piece: its placed item, and its kit row (the encyclopedia's entry for the piece, "Build with a hammer").
        for kind in list(self.built):
            d = self.structures[kind]
            changed |= g(d.get("item"), "the placed %s (%s)" % (kind, self.built[kind]))
            changed |= g(d.get("kit"), "built: %s" % self.built[kind], True)
        # server_smelter.gd: a built Smelter does its jobs by itself (structures.json "smelting"; the old smelt recipes retired in PR #1092):
        # a job's ingot is reached when its ores and a hopper fuel (and, for steel, the carbon, also Coal or Charcoal) are.
        fuel = any(self.has(f) for f in self.smelting.get("fuel", []))
        for kind in list(self.built):
            sm = self.structures[kind].get("smelt", {}) if self.structures[kind].get("use") == "smelt" else {}
            for jid in sm.get("jobs", []) if fuel else []:
                job = self.smelting.get("jobs", {}).get(jid, {})
                if job.get("out") and all(self.has(row[0]) for row in job.get("in", [])):
                    changed |= g(job["out"][0], "smelted at the %s (job %s)" % (kind, jid))
        # server_items.gd: a log chopped on the ground with an axe gives wooden blocks (large from a shoulder log) of its class.
        if axe and self.has("log"):
            for cls, steps in self.wood.get("class_items", {}).items():
                for step in ["block", "block_large"]:
                    if isinstance(steps, dict) and steps.get(step):
                        changed |= g(steps[step], "a %s log chopped on the ground (%s)" % (cls, axe))
        for rid, r in self.recipes.items():
            gives = r.get("gives", [""])[0]
            if self.has(gives) or r.get("locked") or r.get("retired"):
                continue
            st = r.get("station", "")
            if st and self.station_level(st) < int(r.get("station_level", 1)):
                continue
            if all(self.fills(row[0]) for lst in ["needs", "keeps"] for row in r.get(lst, [])):
                changed |= g(gives, "recipe %s" % rid + (" at %s L%d" % (st, int(r.get("station_level", 1))) if st else ""))
        return changed

    def run(self):
        self.seed()
        while self.step():
            pass
        return self

    def blocked(self, iid):
        """Why an item is not reached: the recipes that make it and what each one lacks."""
        out = []
        for rid, r in self.recipes.items():
            if r.get("gives", [""])[0] != iid:
                continue
            if r.get("retired"):
                out.append("recipe %s: retired" % rid)
                continue
            if r.get("locked"):
                out.append("recipe %s: locked" % rid)
                continue
            lack = [row[0] for lst in ["needs", "keeps"] for row in r.get(lst, []) if not self.fills(row[0])]
            st = r.get("station", "")
            if st and self.station_level(st) < int(r.get("station_level", 1)):
                lack.append("station %s L%d (have L%d)" % (st, int(r.get("station_level", 1)), self.station_level(st)))
            out.append("recipe %s lacks %s" % (rid, ", ".join(lack) or "nothing?"))
        for kind, d in self.structures.items():
            if iid not in (d.get("kit"), d.get("item")):
                continue
            for bid, b in self.blueprints.items():
                if b.get("structure") != kind:
                    continue
                if b.get("retired") or b.get("locked"):
                    out.append("blueprint %s: %s" % (bid, "retired" if b.get("retired") else "locked"))
                    continue
                lack = [c[0] for c in b.get("cost", []) if not self.fills(c[0])]
                for key, lvl in [("station", "station_level"), ("near", "near_level")]:
                    if b.get(key) and self.station_level(b[key]) < int(b.get(lvl, 1)):
                        lack.append("%s %s L%d" % (key, b[key], int(b.get(lvl, 1))))
                out.append("blueprint %s lacks %s" % (bid, ", ".join(lack) or "a hammer of tier %s" % b.get("hammer", 1)))
        for jid, job in self.smelting.get("jobs", {}).items():
            if job.get("out", [""])[0] == iid:
                at = [k for k, d in self.structures.items() if d.get("use") == "smelt" and jid in d.get("smelt", {}).get("jobs", [])]
                lack = [row[0] for row in job.get("in", []) if not self.has(row[0])]
                lack += [] if any(self.has(f) for f in self.smelting.get("fuel", [])) else ["fuel (%s)" % ", ".join(self.smelting.get("fuel", []))]
                lack += [] if any(k in self.built for k in at) else ["a built %s" % " or ".join(at)]
                out.append("smelting job %s lacks %s" % (jid, ", ".join(lack) or "nothing?"))
        return out or ["no recipe and no world source"]


def main(argv):
    reach = Reach().run()
    if "--why" in argv:
        iid = argv[argv.index("--why") + 1]
        print(iid, "->", reach.why.get(iid) or "; ".join(reach.blocked(iid)))
        return 0
    with open(ENC, encoding="utf-8") as f:
        text = f.read()
    enc = json.loads(text)
    on, off, future_live, live_unreached = [], [], [], []
    for iid, e in enc["items"].items():
        now = reach.has(iid)
        was = bool(e.get("obtainable_now"))
        if now != was:
            (on if now else off).append(iid)
        e["obtainable_now"] = now
        it = reach.all.get(iid, {})
        if now:
            e.pop("status", None)
        elif it.get("retired") and not iid.endswith("_kit"):
            e["status"] = "retired"   # replaced by another item (Greens by Nettles, Salt by Sea salt): no source is coming
        else:
            e["status"] = "planned"
        if it.get("retired"):
            continue
        if now and it.get("future"):
            future_live.append(iid)
        if not now and not it.get("future"):
            live_unreached.append(iid)

    def show(title, ids, reason):
        print("%s (%d)" % (title, len(ids)))
        for iid in sorted(ids):
            print("  %-28s %-28s %s" % (iid, enc["items"][iid].get("name", ""), reason(iid)))

    show("Now obtainable (false -> true)", on, lambda i: reach.why[i])
    show("No longer obtainable (true -> false)", off, lambda i: "; ".join(reach.blocked(i)))
    show("Reached but items.json says future", future_live, lambda i: reach.why[i])
    show("Not reached and not future", live_unreached, lambda i: "; ".join(reach.blocked(i)))
    if "--check" in argv and (on or off):
        print("encyclopedia.json is out of date: run python3 tools/encyclopedia_reach.py --write")
        return 1
    if "--write" in argv:
        out = json.dumps(enc, indent="\t", ensure_ascii=False) + "\n"
        if out != text:
            with open(ENC, "w", encoding="utf-8") as f:
                f.write(out)
            print("wrote", os.path.relpath(ENC, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
