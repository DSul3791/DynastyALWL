#!/usr/bin/env python3
"""Goal stage audit: every goal must be reachable with the metals of its own stage, no later.

Dave 21 Nov 2026: "make sure stations and required materials are available for each item at every stage of the goals".
tools/goal_station_audit.py checks that a goal's stations are built by earlier goals; this one checks the metal ladder. It reruns the reach model of
tools/encyclopedia_reach.py once per metal stage, with the ores of the later stages taken out of the world:

    stone   no ore at all (coal, salt and limestone stay: they are not metals)
    copper  + Copper ore
    bronze  + Tin ore
    iron    + Iron ore and Bog iron ore (and their ingots)
    steel   everything

and gives each item and structure the first stage that reaches it. A goal's target (its made, got or have item, or its placed structure; for an
"any" list, the easiest member) must be reached by the goal's own stage (goal_rewards.json stages: start = stone, copper_bronze = bronze, iron, steel).
A blueprint's chisel tier is honoured (the reach model does not read it): a piece needing a Bronze chisel is not built before bronze.

shortcut: one goal stage covers copper and bronze together, so a copper_bronze goal that needs tin passes; the stage list above is the finer one.

Run: python3 tools/goal_stage_audit.py      (prints each goal's stage and the stage that reaches it; exit 1 on a goal that comes too early)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import encyclopedia_reach as er   # noqa: E402

STAGES = ["stone", "copper", "bronze", "iron", "steel"]
ORES = {   # the raw metal and what it is smelted into: off the map before its stage
    "copper_ore": "copper", "copper_ingot": "copper", "tin_ore": "bronze", "tin_ingot": "bronze", "bronze_ingot": "bronze",
    "iron_ore": "iron", "bog_iron_ore": "iron", "iron_ingot": "iron", "iron_chunk": "iron", "steel_ingot": "steel",
}
GOAL_STAGE = {"start": "stone", "copper_bronze": "bronze", "iron": "iron", "steel": "steel"}


class StageReach(er.Reach):
    def __init__(self, stage):
        super().__init__()
        self.top = STAGES.index(stage)
        self.all_blueprints = self.blueprints

    def give(self, iid, how, kit=False):
        if iid in ORES and STAGES.index(ORES[iid]) > self.top:
            return False
        return super().give(iid, how, kit)

    def step(self):
        chisel = max([int(v.get("tier", 0) or 0) for k, v in self.all.items() if v.get("tool_class") == "chisel" and self.has(k)] or [0])
        self.blueprints = {k: v for k, v in self.all_blueprints.items() if int(v.get("chisel", 0) or 0) <= chisel}
        return super().step()


def first_stages():
    items, built = {}, {}
    for stage in STAGES:
        r = StageReach(stage).run()
        for iid in r.why:
            items.setdefault(iid, stage)
        for kind in r.built:
            built.setdefault(kind, stage)
    return items, built


def targets(check):
    if check.get("event") == "placed":
        return ("built", [check["what"]] if check.get("what") else list(check.get("what_any", [])))
    for k in ["made_item", "got_item", "have_item"]:
        if check.get(k):
            return ("items", [check[k]])
    if check.get("made_item_all"):   # a set needs every item, so it is reached at its latest one
        return ("all", list(check["made_item_all"]))
    for k in ["made_item_any", "have_item_any", "stored_item_any"]:
        if check.get(k):
            return ("items", list(check[k]))
    return (None, [])


def main():
    items, built = first_stages()
    goals = er.read("starter_goals.json")["goals"] + er.read("camp_goals.json")["goals"]
    bad = 0
    for g in goals:
        kind, ids = targets(g.get("check", {}))
        if not ids:
            continue
        table = built if kind == "built" else items
        reached = [STAGES.index(table[i]) for i in ids if i in table]
        want = STAGES.index(GOAL_STAGE.get(str(g.get("stage", "")), "steel"))
        got = (max(reached) if len(reached) == len(ids) else None) if kind == "all" else (min(reached) if reached else None)
        late = got is None or got > want
        bad += late
        print("%-4s %-18s stage %-13s reached at %s" % ("LATE" if late else "ok", g["id"], g.get("stage"), STAGES[got] if got is not None else "never"))
    print("%d goal(s) need a later stage than their own" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
