#!/usr/bin/env python3
"""Goal station audit: every goal must come after the goals that build the stations it needs.

Dave 17 Nov 2026: "It says make a Hoe but it didnt have us make the workstations required to make the materials or the hoe."
For each goal in data/items/starter_goals.json then data/items/camp_goals.json (the authored order the server reads), this works out the
crafting stations the goal's item needs, through its materials, and fails when a station is not built by an EARLIER goal (a `placed` goal for
a structure of that station at that level or higher). An item no recipe makes is gathered. Where an item has several recipes, the one needing
the fewest stations is taken (the player picks the easy road). Blueprints count their own station and their costs' stations.

shortcut: an item that has a recipe is taken as made, never gathered, so a raw item that also has a station-only recipe would read as needing
that station; none does today (stick, stone, plant fibre, clay have no recipe). Revisit if one appears. Also not checked: a blueprint's
hammer or hand tool (the hammer and knife goals come first today) and `what_any` placed goals (the bed).

Run: python3 tools/goal_station_audit.py         (prints every gap, exit 1 when any)
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ITEMS = ROOT / "data" / "items"


def load(name):
    return json.loads((ITEMS / name).read_text(encoding="utf-8"))


def goals():
    out = list(load("starter_goals.json")["goals"])
    camp = ITEMS / "camp_goals.json"
    if camp.exists():
        out += json.loads(camp.read_text(encoding="utf-8"))["goals"]
    return out


class Chain:
    def __init__(self):
        self.recipes = {}   # item id -> [recipe rows that give it]
        for rid, r in load("recipes.json")["recipes"].items():
            if r.get("retired") or r.get("locked"):
                continue
            self.recipes.setdefault(str(r["gives"][0]), []).append(r)
        self.structures = load("structures.json")["structures"]
        self.blueprints = {}   # structure kind -> blueprint row
        for b in load("blueprints.json")["blueprints"].values():
            if not b.get("retired") and not b.get("locked") and b.get("structure"):
                self.blueprints.setdefault(str(b["structure"]), b)
        self.groups = {}       # group id -> member ids (wood_species.json "ingredient_groups", as ItemTable.load_groups): any one member will do
        for gid, members in load("wood_species.json").get("ingredient_groups", {}).items():
            if isinstance(members, list):
                self.groups[str(gid)] = [str(m) for m in members]
        self._memo = {}

    # Stations (frozenset of (station, level)) the cheapest road to `item` needs; None when nothing makes it and it is not gathered either.
    def item(self, item, seen=()):
        if item in self._memo:
            return self._memo[item]
        if item in seen:
            return None   # a loop: this road does not lead anywhere
        seen = seen + (item,)
        roads = []
        for r in self.recipes.get(item, []):
            roads.append(self._row(r, seen))
        for member in self.groups.get(item, []):
            if member != item:
                roads.append(self.item(member, seen))
        if not self.recipes.get(item) and not self.groups.get(item):
            roads.append(frozenset())   # nothing makes it: gathered, mined, hunted or bought
        roads = [x for x in roads if x is not None]
        best = min(roads, key=lambda x: (len(x), sorted(x))) if roads else None
        if len(seen) == 1:
            self._memo[item] = best
        return best

    def _row(self, r, seen):
        need = set()
        if r.get("station"):
            need.add((str(r["station"]), int(r.get("station_level", 1))))
        for part in list(r.get("needs", [])) + list(r.get("keeps", [])):
            sub = self.item(str(part[0]), seen)
            if sub is None:
                return None
            need |= sub
        return frozenset(need)

    # A structure the player places: its blueprint's station and costs, else its kit item's recipe.
    def structure(self, kind):
        b = self.blueprints.get(kind)
        if b:
            need = set()
            if b.get("station"):
                need.add((str(b["station"]), int(b.get("station_level", 1))))
            for part in b.get("cost", []):
                need |= self.item(str(part[0])) or set()
            return frozenset(need)
        kit = str(self.structures.get(kind, {}).get("kit", kind))
        return self.item(kit) or frozenset()

    def provides(self, kind):
        s = self.structures.get(kind, {})
        return (str(s["station"]), int(s.get("station_level", 1))) if s.get("station") else None


def goal_needs(chain, g):
    c = g.get("check", {})
    if c.get("event") == "placed":
        return chain.structure(str(c.get("what", "")))
    ids = [c[k] for k in ("made_item", "have_item", "got_item") if c.get(k)]
    if ids:
        return chain.item(str(ids[0])) or frozenset()
    anyof = c.get("made_item_any") or c.get("have_item_any") or []
    roads = [chain.item(str(i)) for i in anyof]
    roads = [x for x in roads if x is not None]
    return min(roads, key=len) if roads else frozenset()


def audit():
    chain = Chain()
    built = []   # (station, level) placed by goals so far, in the authored order
    gaps = []
    for g in goals():
        for station, level in sorted(goal_needs(chain, g)):
            if not any(s == station and lv >= level for s, lv in built):
                gaps.append((str(g["id"]), station, level))
        c = g.get("check", {})
        if c.get("event") == "fire_lit" or (c.get("event") == "placed" and c.get("what") == "campfire"):
            built.append(("campfire", 1))   # a laid fire is the "campfire" station (clay pots, plain roasting); not a structures.json station
        elif c.get("event") == "placed":
            got = chain.provides(str(c.get("what", "")))
            if got:
                built.append(got)
    return gaps


def main():
    gaps = audit()
    for gid, station, level in gaps:
        print("goal %s needs a %s (level %d) that no earlier goal builds" % (gid, station, level))
    print("%d gap(s)" % len(gaps))
    return 1 if gaps else 0


if __name__ == "__main__":
    sys.exit(main())
