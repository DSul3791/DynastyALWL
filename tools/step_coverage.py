#!/usr/bin/env python3
"""Footstep surface coverage audit: every ground material, rock, ore and built floor has steps for each gait.

Run: python3 tools/step_coverage.py [--md]     --md writes /mnt/project-files/sound/STEP_COVERAGE.md
Reads the tables in src/client/sound_stage.gd (SOIL_SURFACE, ROCK_STEP, ORE_STEP, FLOOR_SURFACES, the surface names the footstep code
assigns), data/tables (soils, rocks, resources), data/sound/step_levels.json and the step files, and reports gaps:
  - a soil/rock id with no surface entry (falls back to dirt / its rock default)
  - a surface with no left/right step files (recorded or generated), or only one foot
  - a surface or floor missing from step_levels.json (loudness) for the three gaits
Exit status 1 when a gap remains.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
STAGE = open(os.path.join(ROOT, "src", "client", "sound_stage.gd"), encoding="utf-8").read()


def gd_dict(name):
    m = re.search(r"const %s := \{(.*?)\n\}" % name, STAGE, re.S) or re.search(r"const %s := \{(.*?)\}" % name, STAGE, re.S)
    return m.group(1) if m else ""


def table(name):
    with open(os.path.join(ROOT, "data", "tables", name + ".json"), encoding="utf-8") as f:
        return {e["id"]: e for e in json.load(f)["entries"] if not e.get("retired")}


def step_files(surface):
    found = {}

    for foot in ("left", "right"):
        n_rec = len([f for f in os.listdir(os.path.join(AUDIO, "recorded")) if re.match(r"^step_%s_%s_\d+\.ogg$" % (surface, foot), f)])
        gen_dirs = [AUDIO, os.path.join(AUDIO, "floors")]
        n_gen = sum(len([f for f in os.listdir(d) if os.path.isdir(d) and re.match(r"^step_%s(_%s)?_\d+\.ogg$" % (surface, foot), f)]) for d in gen_dirs if os.path.isdir(d))
        found[foot] = (n_rec, n_gen)

    return found


def main():
    soil_surface = {int(k): v for k, v in re.findall(r"(\d+):\s*\"(\w+)\"", gd_dict("SOIL_SURFACE"))}
    rock_step = {int(k): (s, float(d), float(p)) for k, s, d, p in re.findall(r"(\d+):\s*\[\"(\w+)\",\s*(-?[\d.]+),\s*([\d.]+)\]", gd_dict("ROCK_STEP"))}
    ore_step = {int(k): s for k, s, _d, _p in re.findall(r"(\d+):\s*\[\"(\w+)\",\s*(-?[\d.]+),\s*([\d.]+)\]", gd_dict("ORE_STEP"))}
    ore_metal = [int(x) for x in re.findall(r"\d+", re.search(r"const ORE_METAL := \[(.*?)\]", STAGE).group(1))]
    floors = dict(re.findall(r"\"(\w+)\":\s*(-?[\d.]+)", re.search(r"const FLOOR_SURFACES := \{(.*?)\}", STAGE).group(1)))
    assigned = set(re.findall(r"surface = \"(\w+)\"", STAGE))
    levels = json.load(open(os.path.join(ROOT, "data", "sound", "step_levels.json")))
    soils, rocks, resources = table("soils"), table("rocks"), table("resources")
    gaps, rows = [], []

    used = set(soil_surface.values()) | {v[0] for v in rock_step.values()} | set(ore_step.values()) | assigned | set(floors) | {"grass", "grass_tall", "bushes", "snow", "water", "mud"}
    used.discard("")

    for sid, entry in sorted(soils.items()):
        if sid == 0:
            continue

        if sid not in soil_surface:
            gaps.append("soil %d %s has no entry in SOIL_SURFACE (plays dirt)" % (sid, entry["name"]))

        rows.append(("soil", sid, entry["name"], soil_surface.get(sid, "dirt (default)")))

    for rid, entry in sorted(rocks.items()):
        if rid == 0:
            continue

        if rid not in rock_step:
            gaps.append("rock %d %s has no entry in ROCK_STEP (plays stone)" % (rid, entry["name"]))

        rows.append(("rock", rid, entry["name"], "%s %+.0f dB x%.2f" % rock_step[rid] if rid in rock_step else "stone (default)"))

    for oid, entry in sorted(resources.items()):
        if entry.get("category") in ("none", None) or oid == 0:
            continue

        how = ore_step[oid] if oid in ore_step else ("rings (metal)" if oid in ore_metal else "rock steps")
        rows.append(("ore", oid, entry["name"], how))

    surface_rows = []

    for surface in sorted(used):
        files = step_files(surface)
        left, right = files["left"], files["right"]
        text = "left %d rec + %d gen, right %d rec + %d gen" % (left[0], left[1], right[0], right[1])

        if sum(left) == 0 or sum(right) == 0:
            gaps.append("surface %s has no %s step file (%s)" % (surface, "left" if sum(left) == 0 else "right", text))

        in_levels = surface in levels["surface_db"] or surface in levels["floor_db"]

        if not in_levels:
            gaps.append("surface %s is not in data/sound/step_levels.json" % surface)

        surface_rows.append((surface, text, "yes" if in_levels else "NO"))

    for key, want in (("gait_db", 3), ("gait_pitch", 3)):
        if len(levels[key]) != want:
            gaps.append("step_levels.json %s has %d entries, 3 gaits wanted" % (key, len(levels[key])))

    print("step coverage: %d soils, %d rocks, %d surfaces, %d gaps" % (len([r for r in rows if r[0] == "soil"]), len([r for r in rows if r[0] == "rock"]), len(surface_rows), len(gaps)))

    for g in gaps:
        print("GAP  " + g)

    if "--md" in sys.argv:
        out = ["# Footstep coverage (tools/step_coverage.py)", "", "Every soil, rock, ore and built floor and the step surface it plays. %d gaps." % len(gaps), ""]
        out += ["## Gaps", ""] + (["- " + g for g in gaps] or ["none"]) + ["", "## Surfaces (step files and loudness table)", "", "| surface | files | in step_levels.json |", "|---|---|---|"]
        out += ["| %s | %s | %s |" % r for r in surface_rows]
        out += ["", "## Materials", "", "| kind | id | name | plays |", "|---|---|---|---|"] + ["| %s | %d | %s | %s |" % r for r in rows]
        out += ["", "Gaits: every surface uses the three gaits (walk, jog, run) from `gait_db` and `gait_pitch` in step_levels.json, so a surface that has files and a loudness row covers all gaits."]
        with open("/mnt/project-files/sound/STEP_COVERAGE.md", "w") as f:
            f.write("\n".join(out) + "\n")

    sys.exit(1 if gaps else 0)


if __name__ == "__main__":
    main()
