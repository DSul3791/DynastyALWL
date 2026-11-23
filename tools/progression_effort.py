#!/usr/bin/env python3
"""Progression effort: what one player must gather and do to equip themselves at each metal stage.

Coordinator, 23 Nov 2026 (thread "Walk the crafting progression end to end"): "for each tier, count the real effort a player needs (trees felled,
animals killed, ore pieces, minutes at stations) to equip one player with the tier's basic tools, a weapon, storage and clothing, and flag steps
where the count is absurd for either reason, stingy yields or grind, with the numbers." Dave 23 Nov 2026: "we are not gate keeping by limiting
resources".

For each stage (stone, copper, bronze, iron, steel) a KIT (below) is expanded through the recipes the reach model of tools/encyclopedia_reach.py
first reaches each item by, down to raw world inputs. Stations and kept tools are built once and carried to later stages (a player keeps their
smithy). Raw inputs become actions with the RATES below (each names its data source); every rate is an average, not a roll. Report only.

    python3 tools/progression_effort.py          # markdown on stdout
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import encyclopedia_reach as er   # noqa: E402

KITS = {
    "stone": {"items": ["stone_axe", "stone_pickaxe", "stone_knife", "stone_hammer", "stone_saw", "wooden_shovel", "wooden_hoe", "wooden_spear",
                        "hide_tunic", "hide_trousers", "hide_boots"], "pieces": ["wicker_basket"]},
    "copper": {"items": ["copper_axe", "copper_pickaxe", "copper_knife", "copper_hammer", "copper_saw", "copper_shovel", "copper_hoe",
                         "leather_jerkin", "leather_trousers", "leather_boots"], "pieces": ["small_chest"]},
    "bronze": {"items": ["bronze_axe", "bronze_pickaxe", "bronze_knife", "bronze_hammer", "bronze_saw", "bronze_shovel", "bronze_hoe", "bronze_sword",
                         "bronze_helm"], "pieces": ["plank_chest"]},
    "iron": {"items": ["iron_axe", "iron_pickaxe", "iron_knife", "iron_hammer", "hand_saw", "iron_shovel", "iron_hoe", "iron_sword", "mail_shirt",
                       "iron_helm"], "pieces": ["fine_chest"]},
    "steel": {"items": ["steel_axe", "steel_pickaxe", "steel_knife", "steel_hammer", "steel_saw", "steel_shovel", "steel_hoe", "steel_sword",
                        "plate_cuirass", "steel_helm"], "pieces": ["iron_chest"]},
}

# What one action gives on average. A felled 15 m tree: 5 logs (log_length_m 3), about 30 sticks and 100 leaves (drops.json trunk crown_scatter
# note); a deer is the common hunt (carcass.json); ore: one piece a pick blow, about half ore on an outcrop (boulders.json ore piece_share), a loose
# river piece is one (copper_rocks, tin_rocks, iron_rocks). Bog iron: dig rows of digging.json bog_iron.
RATES = {
    "log": (5.0, "trees felled"), "stick": (30.0, "trees felled (or about 1 a ground pick)"), "leaves": (100.0, "trees felled"),
    "firewood": (24.0, "logs split (24 a log, W-3)"), "wooden_block": (6.0, "logs sawn (6 a log, W-3)"),
    "plant_fibre": (2.0, "plants picked"), "stone": (1.0, "stones picked or pick blows"), "clay": (2.0, "shovel digs"), "sand": (2.0, "shovel digs"),
    "hide": (1.5, "deer killed"), "sinew": (8.0, "deer killed"), "animal_fat": (2.0, "deer killed"), "bone": (5.5, "deer killed"),
    "raw_meat": (7.0, "deer killed"), "fur": (1.5, "foxes or wolves killed"), "feather": (18.0, "geese killed"),
    "tannin_bark": (12.0, "oaks felled"), "bark": (2.75, "trees felled (bark_chance 0.55 a log)"),
    "copper_ore": (0.5, "pick blows on a copper outcrop (or loose pieces picked)"), "tin_ore": (0.5, "pick blows on a tin outcrop (or loose pieces)"),
    "iron_ore": (0.5, "pick blows on an iron outcrop (or loose river stones)"), "bog_iron_ore": (1.0, "shovel digs in bog"),
    "coal": (0.5, "pick blows on a coal seam"), "water": (1.0, "fills"), "flint": (12.5, "stones broken off (flint 0.08 by water)"),
}


def rate_of(iid):
    if iid.startswith("log_"):
        return RATES["log"]
    return RATES.get(iid)


class Effort:
    def __init__(self):
        self.r = er.Reach().run()
        self.recipe_of = {}
        for iid, how in self.r.why.items():
            if how.startswith("recipe "):
                self.recipe_of[iid] = how.split()[1]
        self.recipe_of["twine"] = "twine"   # Twine from plant fibre, the guide's way (the model first meets Bark twine)
        for iid in ["copper_ingot", "tin_ingot", "bronze_ingot", "iron_ingot", "steel_ingot"]:
            self.recipe_of.pop(iid, None)   # ingots come from the smelters (smelt_job), not an iron chunk
        self.groups = self.r.wood.get("ingredient_groups", {})
        self.built = set()       # station kinds built so far (carried across stages)
        self.owned = set()       # kept tools made so far

    def member(self, iid):
        members = self.groups.get(iid)
        if isinstance(members, list) and iid not in self.recipe_of and not self.smelt_job(iid):
            return next((m for m in members if self.r.has(m)), iid)
        return iid

    def smelt_job(self, iid):
        # the plain ore job (rock Iron ore 1 to 1, not bog iron or a meteorite chunk), so the smelter that tier's goals lead to is counted
        for jid in ["copper", "tin", "bronze", "iron", "steel"]:
            job = self.r.smelting.get("jobs", {}).get(jid, {})
            if job.get("out", [""])[0] == iid:
                return job
        return None

    def station_kind(self, station, level):
        best = None
        for kind, how in self.r.built.items():
            d = self.r.structures[kind]
            lvl = int(d.get("station_level", 1)) if d.get("station") == station else int(d.get("also", {}).get(station, 0))
            if lvl >= level and (best is None or lvl < best[1]):
                best = (kind, lvl)
        return best[0] if best else None

    def blueprint(self, kind):
        return next((b for b in self.r.blueprints_all.values() if b.get("structure") == kind and not b.get("retired") and not b.get("locked")), None)

    def build(self, kind, tally):
        if kind in self.built:
            return
        self.built.add(kind)
        tally["builds"].append(self.r.structures[kind].get("item", kind))
        b = self.blueprint(kind)
        for row in (b or {}).get("cost", []):
            self.make(row[0], int(row[1]), tally)

    def make(self, iid, n, tally):
        iid = self.member(iid)
        rid = self.recipe_of.get(iid)
        if rid:
            rec = self.r.recipes[rid]
            crafts = math.ceil(n / float(rec.get("gives", [iid, 1])[1]))
            tally["craft_s"] += float(rec.get("craft_s", 10.0)) * crafts
            tally["crafts"] += crafts
            if rec.get("station"):
                kind = self.station_kind(rec["station"], int(rec.get("station_level", 1)))
                if kind:
                    self.build(kind, tally)
            for row in rec.get("keeps", []):
                tool = self.member(row[0])
                if tool not in self.owned:
                    self.owned.add(tool)
                    self.make(tool, 1, tally)
            for row in rec.get("needs", []):
                self.make(row[0], int(row[1]) * crafts, tally)
            return
        job = self.smelt_job(iid)
        if job:
            per = float(job["out"][1])
            jobs = math.ceil(n / per)
            tally["smelt_s"] += 20.0 * jobs
            kinds = [k for k, d in self.r.structures.items() if d.get("use") == "smelt" and any(
                self.r.smelting["jobs"].get(j) is job for j in d.get("smelt", {}).get("jobs", []))]
            if kinds and not (set(kinds) & self.built):
                self.build(min(kinds, key=lambda k: len(self.r.structures[k].get("smelt", {}).get("jobs", []))), tally)
            ore = 0
            for row in job.get("in", []):
                self.make(row[0], int(row[1]) * jobs, tally)
                ore += int(row[1]) * jobs
            self.make("charcoal", int(job.get("carbon", 0)) * jobs + ore, tally)   # fuel_per_ore 1, plus the carbon
            return
        if iid == "charcoal":   # a kiln: 100 a log (structures.json kilns yield); a campfire leaves less
            if "kiln" not in self.built:
                self.build("kiln", tally)
            tally["raw"]["log"] = tally["raw"].get("log", 0) + math.ceil(n / 100.0)
            return
        tally["raw"][iid] = tally["raw"].get(iid, 0) + n


def main():
    e = Effort()
    out = ["# Progression effort (one player, each stage's kit; stations carried forward)\n"]
    for stage, kit in KITS.items():
        t = {"raw": {}, "builds": [], "craft_s": 0.0, "crafts": 0, "smelt_s": 0.0}
        for iid in kit["items"]:
            if not e.r.has(iid):
                out.append("- %s: `%s` NOT REACHED (%s)" % (stage, iid, "; ".join(e.r.blocked(iid))))
                continue
            e.owned.add(iid)
            e.make(iid, 1, t)
        for kind in kit["pieces"]:
            e.build(kind, t)
        acts = {}
        for iid, n in sorted(t["raw"].items()):
            rt = rate_of(iid)
            if rt:
                acts.setdefault(rt[1], 0.0)
                acts[rt[1]] += n / rt[0]
        out.append("\n## %s\n" % stage)
        out.append("Kit: %s; pieces: %s." % (", ".join(kit["items"]), ", ".join(kit["pieces"])))
        out.append("New stations and pieces built: %s." % (", ".join(t["builds"]) or "none"))
        out.append("Crafts: %d, %.0f minutes at stations or by hand; smelting %.0f minutes.\n" % (t["crafts"], t["craft_s"] / 60.0, t["smelt_s"] / 60.0))
        out.append("| Raw input | Amount |\n|---|---|")
        for iid, n in sorted(t["raw"].items(), key=lambda x: -x[1]):
            out.append("| %s | %d |" % (iid, n))
        out.append("\n| Actions | Count |\n|---|---|")
        for what, n in sorted(acts.items(), key=lambda x: -x[1]):
            out.append("| %s | %.0f |" % (what, math.ceil(n)))
    print("\n".join(out))


if __name__ == "__main__":
    main()
